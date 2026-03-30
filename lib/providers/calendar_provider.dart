// lib/providers/calendar_provider.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/models/calendar_memo_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _keyCalendarMemos = 'calendarMemos';
  List<CalendarMemoModel> _memos = [];
  final Uuid _uuid = const Uuid();
  final ImagePicker _picker = ImagePicker();

  List<CalendarMemoModel> get memos => _memos;

  CalendarProvider() {
    _loadMemos();
  }

  // 1. 메모 로드 (서버 + 로컬 동기화)
  Future<void> _loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1-1. 로컬 로드
    final jsonString = prefs.getString(_keyCalendarMemos);
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      _memos = jsonList.map((json) => CalendarMemoModel.fromJson(json)).toList();
    }

    // 1-2. 서버 로드
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey(_keyCalendarMemos)) {
          final String serverJson = doc.data()![_keyCalendarMemos];
          // 서버 데이터로 업데이트
          final List<dynamic> jsonList = json.decode(serverJson);
          _memos = jsonList.map((json) => CalendarMemoModel.fromJson(json)).toList();

          // 로컬에도 최신 데이터 저장
          await prefs.setString(_keyCalendarMemos, serverJson);
        } else if (jsonString != null) {
          // 서버에 데이터가 없고 로컬에는 있는 경우 (최초 업로드)
          await _saveMemos();
        }
      } catch (e) {
        debugPrint("Failed to load calendar memos from server: $e");
      }
    }
    notifyListeners();
  }

  // 2. 메모 저장 (서버 + 로컬)
  Future<void> _saveMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    final jsonString = json.encode(_memos.map((memo) => memo.toJson()).toList());

    // 2-1. 로컬 저장
    await prefs.setString(_keyCalendarMemos, jsonString);

    // 2-2. 서버 저장
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          _keyCalendarMemos: jsonString,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Failed to save calendar memos to server: $e");
      }
    }
  }

  Future<String?> _saveImageLocally(XFile? imageFile) async {
    if (imageFile == null) return null;

    final appDocDir = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(p.join(appDocDir.path, 'memo_images'));
    if (!await imageDirectory.exists()) {
      await imageDirectory.create(recursive: true);
    }

    final fileName = '${_uuid.v4()}${p.extension(imageFile.name)}';
    final newPath = p.join(imageDirectory.path, fileName);
    final File localImage = await File(imageFile.path).copy(newPath);
    return localImage.path;
  }

  Future<void> addMemo(DateTime date, String? title, String content, XFile? imageFile) async {
    final imageUrl = await _saveImageLocally(imageFile);

    final newMemo = CalendarMemoModel(
      id: _uuid.v4(),
      date: date.toIso8601String().substring(0, 10),
      title: title,
      content: content,
      imageUrl: imageUrl,
    );
    _memos.add(newMemo);
    await _saveMemos(); // 자동 동기화
    notifyListeners();
  }

  Future<void> updateMemo(CalendarMemoModel oldMemo, String? newTitle, String newContent, XFile? newImageFile, {bool deleteExistingImage = false}) async {
    final index = _memos.indexWhere((memo) => memo.id == oldMemo.id);
    if (index != -1) {
      String? updatedImageUrl = oldMemo.imageUrl;

      if (deleteExistingImage && oldMemo.imageUrl != null) {
        try {
          final file = File(oldMemo.imageUrl!);
          if (await file.exists()) {
            await file.delete();
          }
          updatedImageUrl = null;
        } catch (e) {
          debugPrint('Failed to delete old image: $e');
        }
      }

      if (newImageFile != null) {
        updatedImageUrl = await _saveImageLocally(newImageFile);
      }

      final updatedMemo = oldMemo.copyWith(
        title: newTitle,
        content: newContent,
        imageUrl: updatedImageUrl,
      );

      _memos[index] = updatedMemo;
      await _saveMemos(); // 자동 동기화
      notifyListeners();
    }
  }

  Future<void> deleteMemo(String memoId) async {
    final memoToDelete = _memos.firstWhereOrNull((memo) => memo.id == memoId);
    if (memoToDelete != null) {
      if (memoToDelete.imageUrl != null) {
        try {
          final file = File(memoToDelete.imageUrl!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Failed to delete memo image: $e');
        }
      }
      _memos.removeWhere((memo) => memo.id == memoId);
      await _saveMemos(); // 자동 동기화
      notifyListeners();
    }
  }

  List<CalendarMemoModel> getMemosForDay(DateTime day) {
    final dateString = day.toIso8601String().substring(0, 10);
    return _memos.where((memo) => memo.date == dateString).toList();
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    await _loadMemos();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveMemos();
  }

}

extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}