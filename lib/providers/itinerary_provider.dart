// lib/providers/itinerary_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jidoapp/models/itinerary_entry_model.dart';
import 'package:jidoapp/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ItineraryProvider with ChangeNotifier {
  final AiService _aiService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ItineraryEntry> _entries = [];
  bool _isLoading = true;

  List<ItineraryEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  ItineraryProvider(this._aiService) {
    _loadEntries();
  }

  // 1. 일정 로드 (서버 + 로컬 동기화)
  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1-1. 로컬 로드
    final String? localJson = prefs.getString('saved_itineraries');
    if (localJson != null) {
      try {
        final List<dynamic> jsonList = json.decode(localJson);
        _entries = jsonList.map((j) => ItineraryEntry.fromJson(j)).toList();
      } catch (e) {
        debugPrint("Error parsing local itineraries: $e");
      }
    }

    // 1-2. 서버 로드
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('saved_itineraries')) {
          final String serverJson = doc.data()!['saved_itineraries'];
          // 서버 데이터 파싱
          final List<dynamic> jsonList = json.decode(serverJson);
          _entries = jsonList.map((j) => ItineraryEntry.fromJson(j)).toList();

          // 로컬 동기화
          await prefs.setString('saved_itineraries', serverJson);
        } else if (localJson != null) {
          // 서버에 없지만 로컬에 있으면 업로드 (첫 동기화)
          await _saveEntries();
        }
      } catch (e) {
        debugPrint("Failed to load itineraries from server: $e");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // 2. 일정 저장 (서버 + 로컬)
  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    try {
      final jsonString = json.encode(_entries.map((e) => e.toJson()).toList());

      // 2-1. 로컬 저장
      await prefs.setString('saved_itineraries', jsonString);

      // 2-2. 서버 저장
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'saved_itineraries': jsonString,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error saving itineraries: $e");
    }
  }

  Future<void> addEntry({required String title, required String content}) async {
    final generatedItinerary = await _aiService.getItineraryFromText(content, title);
    final now = DateTime.now();
    final startDate = DateTime.utc(now.year, now.month, now.day);
    final dailyPlans = ItineraryEntry.parseFromText(generatedItinerary, startDate);

    // ID 생성 (현재 시간 밀리초 사용)
    final newId = DateTime.now().millisecondsSinceEpoch;

    final newEntry = ItineraryEntry(
      id: newId,
      title: title,
      content: content,
      generatedItinerary: generatedItinerary,
      date: startDate,
      dailyPlans: dailyPlans,
    );

    _entries.insert(0, newEntry);
    await _saveEntries(); // 저장 및 동기화
    notifyListeners();
  }

  Future<void> updateEntry({required int id, required String title, required String content}) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      final oldEntry = _entries[index];
      final generatedItinerary = await _aiService.getItineraryFromText(content, title);
      final dailyPlans = ItineraryEntry.parseFromText(generatedItinerary, oldEntry.date);

      final updatedEntry = ItineraryEntry(
        id: id,
        title: title,
        content: content,
        generatedItinerary: generatedItinerary,
        date: oldEntry.date,
        dailyPlans: dailyPlans,
      );

      _entries[index] = updatedEntry;
      await _saveEntries(); // 저장 및 동기화
      notifyListeners();
    }
  }

  Future<void> deleteEntry(int id) async {
    _entries.removeWhere((entry) => entry.id == id);
    await _saveEntries(); // 저장 및 동기화
    notifyListeners();
  }

  Future<void> saveUserEditedItinerary(int id, String newItineraryText) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index != -1) {
      final oldEntry = _entries[index];
      final newDailyPlans = ItineraryEntry.parseFromText(newItineraryText, oldEntry.date);

      final updatedEntry = ItineraryEntry(
        id: id,
        title: oldEntry.title,
        content: oldEntry.content,
        generatedItinerary: newItineraryText,
        date: oldEntry.date,
        dailyPlans: newDailyPlans,
      );

      _entries[index] = updatedEntry;
      await _saveEntries(); // 저장 및 동기화
      notifyListeners();
    }
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    await _loadEntries();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveEntries();
  }

}