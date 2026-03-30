// lib/providers/visa_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/models/user_visa_model.dart';
import 'dart:convert'; // jsonEncode 사용을 위해

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VisaProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<UserVisaInfo> _visas = [];

  List<UserVisaInfo> get visas => _visas;

  VisaProvider() {
    _loadVisas();
  }

  // 1. 비자 불러오기 (로컬 + 서버)
  Future<void> _loadVisas() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1-1. 로컬 데이터 로드
    if (prefs.containsKey('user_visas_list')) {
      final List<String>? jsonList = prefs.getStringList('user_visas_list');
      if (jsonList != null) {
        try {
          _visas = jsonList.map((item) => UserVisaInfo.fromJson(item)).toList();
        } catch (e) {
          print('Error loading local visas: $e');
        }
      }
    }

    // 1-2. 서버 데이터 로드
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('user_visas')) {
          final List<dynamic> serverList = doc.data()!['user_visas'];
          final List<String> stringList = serverList.cast<String>();

          // 서버 데이터 파싱
          _visas = stringList.map((item) => UserVisaInfo.fromJson(item)).toList();

          // 로컬 동기화
          await prefs.setStringList('user_visas_list', stringList);
        } else if (_visas.isNotEmpty) {
          // 서버에 데이터 없는데 로컬에 있으면 업로드
          await _saveVisas();
        }
      } catch (e) {
        print("Failed to load visas from server: $e");
      }
    }
    notifyListeners();
  }

  // 2. 비자 저장 (로컬 + 서버)
  Future<void> _saveVisas() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    final List<String> jsonList = _visas.map((visa) => visa.toJson()).toList();

    // 2-1. 로컬 저장
    await prefs.setStringList('user_visas_list', jsonList);

    // 2-2. 서버 저장
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'user_visas': jsonList,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print("Failed to save visas to server: $e");
      }
    }
  }

  Future<void> addVisa(UserVisaInfo visa) async {
    _visas.add(visa);
    await _saveVisas();
    notifyListeners();
  }

  Future<void> removeVisa(int index) async {
    if (index >= 0 && index < _visas.length) {
      _visas.removeAt(index);
      await _saveVisas();
      notifyListeners();
    }
  }

  Future<void> updateVisa(int index, UserVisaInfo newVisa) async {
    if (index >= 0 && index < _visas.length) {
      _visas[index] = newVisa;
      await _saveVisas();
      notifyListeners();
    }
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. 메모리 + 로컬 초기화
    _visas = [];
    await prefs.remove('user_visas_list');

    // 2. Firestore에서 새로 로드
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('user_visas')) {
          final List<dynamic> serverList = doc.data()!['user_visas'];
          final List<String> stringList = serverList.cast<String>();
          _visas = stringList.map((item) => UserVisaInfo.fromJson(item)).toList();
          await prefs.setStringList('user_visas_list', stringList);
        }
      } catch (e) {
        print("Failed to reload visas from server: $e");
      }
    }
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveVisas();
  }

}