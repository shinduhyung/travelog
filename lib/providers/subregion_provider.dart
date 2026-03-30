// lib/providers/subregion_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubregionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Key: Country ISO A3, Value: Set of visited subregion names/codes
  Map<String, Set<String>> _visitedSubregions = {};

  bool _isLoading = true;
  bool get isLoading => _isLoading;
  Map<String, Set<String>> get visitedSubregions => _visitedSubregions;

  SubregionProvider() {
    _loadVisitedSubregions();
  }

  // 1. 데이터 로드 (로컬 + 서버 동기화)
  Future<void> _loadVisitedSubregions() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1-1. 로컬 데이터 로드
    final String? localJson = prefs.getString('visited_subregions');
    if (localJson != null) {
      try {
        final Map<String, dynamic> decodedMap = json.decode(localJson);
        _visitedSubregions = decodedMap.map(
              (key, value) => MapEntry(key, Set<String>.from(value as List<dynamic>)),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Error loading local subregions: $e');
        _visitedSubregions = {};
      }
    }

    // 1-2. 서버 데이터 로드
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('visited_subregions')) {
          // 서버 데이터가 있으면 가져와서 로컬에 덮어쓰기
          final String serverJson = doc.data()!['visited_subregions'];
          await prefs.setString('visited_subregions', serverJson);

          final Map<String, dynamic> decodedMap = json.decode(serverJson);
          _visitedSubregions = decodedMap.map(
                (key, value) => MapEntry(key, Set<String>.from(value as List<dynamic>)),
          );
        } else if (localJson != null) {
          // 서버에 데이터가 없고 로컬에는 있다면 (최초 연동 시) 업로드
          await _saveVisitedSubregions();
        }
      } catch (e) {
        if (kDebugMode) debugPrint("Failed to load subregions from server: $e");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // 2. 데이터 저장 (로컬 + 서버)
  Future<void> _saveVisitedSubregions() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // Convert Set<String> to List<String> for JSON encoding
    final Map<String, List<String>> encodableMap = _visitedSubregions.map(
          (key, value) => MapEntry(key, value.toList()),
    );
    final String jsonString = json.encode(encodableMap);

    // 2-1. 로컬 저장
    await prefs.setString('visited_subregions', jsonString);

    // 2-2. 서버 저장
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'visited_subregions': jsonString,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) debugPrint("Failed to save subregions to server: $e");
      }
    }
  }

  bool isSubregionVisited(String countryIsoA3, String subregionName) {
    return _visitedSubregions[countryIsoA3]?.contains(subregionName) ?? false;
  }

  void toggleVisitedStatus(String countryIsoA3, String subregionName) {
    if (!_visitedSubregions.containsKey(countryIsoA3)) {
      _visitedSubregions[countryIsoA3] = {};
    }

    if (isSubregionVisited(countryIsoA3, subregionName)) {
      _visitedSubregions[countryIsoA3]!.remove(subregionName);
    } else {
      _visitedSubregions[countryIsoA3]!.add(subregionName);
    }

    _saveVisitedSubregions();
    notifyListeners();
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    await _loadVisitedSubregions();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveVisitedSubregions();
  }

}