import 'package:flutter/material.dart';
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/services/ai_service.dart';
import 'package:jidoapp/services/storage_service.dart';
import 'package:jidoapp/services/aero_data_box_service.dart';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class TripLogProvider with ChangeNotifier {
  final AiService _aiService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, String> _countryNameToIsoMap = {};

  List<TripLogEntry> _entries = [];
  bool _isLoading = true;

  List<TripLogEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  TripLogProvider(this._aiService) {
    _loadEntries();
  }

  void updateCountryData(Map<String, String> newMap) {
    _countryNameToIsoMap = newMap;
  }

  // 1. 여행기 불러오기 (로컬 + 서버 동기화)
  Future<void> _loadEntries() async {
    _isLoading = true;
    notifyListeners();

    try {
      _entries = await StorageService.instance.readAllLogs();

      final user = _auth.currentUser;
      if (user != null) {
        await _syncWithServer(user.uid);
      }
    } catch (e) {
      debugPrint("Error loading trip logs: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // [SYNC] 서버 동기화
  Future<void> _syncWithServer(String uid) async {
    try {
      final collectionRef = _firestore.collection('users').doc(uid).collection('trip_logs');
      final snapshot = await collectionRef.get();

      final remoteLogs = snapshot.docs.map((doc) {
        final data = doc.data();
        final sanitizedData = _firestoreToModelMap(doc.id, data);
        return TripLogEntry.fromMap(sanitizedData);
      }).toList();

      bool isChanged = false;
      final localMap = {for (var e in _entries) e.id: e};

      // 1. 서버 -> 로컬
      for (var remoteLog in remoteLogs) {
        if (!localMap.containsKey(remoteLog.id)) {
          _entries.add(remoteLog);
          await StorageService.instance.create(remoteLog);
          isChanged = true;
        }
      }

      // 2. 로컬 -> 서버
      final remoteIds = remoteLogs.map((e) => e.id).toSet();
      for (var localLog in _entries) {
        if (!remoteIds.contains(localLog.id)) {
          await collectionRef.doc(localLog.id).set(localLog.toMap());
        }
      }

      if (isChanged) {
        _entries.sort((a, b) => b.date.compareTo(a.date));
      }
    } catch (e) {
      debugPrint("Sync error: $e");
    }
  }

  // 2. 여행기 추가
  Future<void> addEntry({
    required String title,
    required String content,
  }) async {
    try {
      final summary = await _aiService.getSummaryFromText(
        content,
        _countryNameToIsoMap,
        AeroDataBoxService(),
      );

      final newEntry = TripLogEntry(
        id: const Uuid().v4(),
        title: title,
        content: content,
        date: DateTime.now(),
        summary: summary,
      );

      await StorageService.instance.create(newEntry);
      _entries.insert(0, newEntry);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('trip_logs')
            .doc(newEntry.id)
            .set(newEntry.toMap());
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error adding entry: $e");
      rethrow;
    }
  }

  // 3. 여행기 수정 (에러 해결됨: 화면에서 사용하는 id, title, content 파라미터 지원)
  Future<void> updateEntry({
    required String id,
    required String title,
    required String content,
  }) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final oldEntry = _entries[index];

    // 기존 날짜와 요약 정보는 유지하고 제목/내용만 수정
    final updatedEntry = TripLogEntry(
      id: oldEntry.id,
      title: title,
      content: content,
      date: oldEntry.date,
      summary: oldEntry.summary,
      generatedItinerary: oldEntry.generatedItinerary,
    );

    await _updateEntryInternal(updatedEntry);
  }

  // 내부용 업데이트 함수 (객체 전체 업데이트)
  Future<void> _updateEntryInternal(TripLogEntry updatedEntry) async {
    final index = _entries.indexWhere((e) => e.id == updatedEntry.id);
    if (index != -1) {
      await StorageService.instance.update(updatedEntry);
      _entries[index] = updatedEntry;

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('trip_logs')
            .doc(updatedEntry.id)
            .update(updatedEntry.toMap());
      }
      notifyListeners();
    }
  }

  // 4. 여행기 삭제
  Future<void> deleteEntry(String id) async {
    try {
      await StorageService.instance.delete(id);
      _entries.removeWhere((e) => e.id == id);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).collection('trip_logs').doc(id).delete();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting entry: $e");
    }
  }

  // 5. 일정 생성 (화면 호출용)
  Future<String> getOrGenerateItinerary(String entryId) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return "Error: Log not found";

    final entry = _entries[index];
    if (entry.generatedItinerary != null && entry.generatedItinerary!.isNotEmpty) {
      return entry.generatedItinerary!;
    }

    return await regenerateItinerary(entryId);
  }

  // 일정 재생성
  Future<String> regenerateItinerary(String entryId) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return "";

    final entry = _entries[index];
    final itinerary = await _aiService.getItineraryFromText(entry.content, entry.title);

    // 기존 필드 유지하면서 일정만 업데이트
    final updatedEntry = TripLogEntry(
      id: entry.id,
      title: entry.title,
      content: entry.content,
      date: entry.date,
      summary: entry.summary,
      generatedItinerary: itinerary,
    );

    await _updateEntryInternal(updatedEntry);

    return itinerary;
  }

  // 사용자 편집 일정 저장
  Future<void> saveUserEditedItinerary(String entryId, String newItinerary) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final entry = _entries[index];
    final updatedEntry = TripLogEntry(
      id: entry.id,
      title: entry.title,
      content: entry.content,
      date: entry.date,
      summary: entry.summary,
      generatedItinerary: newItinerary,
    );

    await _updateEntryInternal(updatedEntry);
  }

  // AI Summary만 업데이트
  Future<void> updateEntrySummary(String entryId, AiSummary newSummary) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final entry = _entries[index];
    final updatedEntry = TripLogEntry(
      id: entry.id,
      title: entry.title,
      content: entry.content,
      date: entry.date,
      summary: newSummary,
      generatedItinerary: entry.generatedItinerary,
    );

    await _updateEntryInternal(updatedEntry);
  }

  // Firestore 데이터 변환 헬퍼
  Map<String, dynamic> _firestoreToModelMap(String docId, Map<String, dynamic> data) {
    final Map<String, dynamic> map = Map.from(data);
    map['id'] = docId;

    if (map['date'] is Timestamp) {
      map['date'] = (map['date'] as Timestamp).toDate().toIso8601String();
    }

    return map;
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    await _loadEntries();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  // TripLogProvider는 로컬(SQLite)과 Firestore를 addEntry 시 항상 같이 저장하므로
  // 현재 로컬 entries를 순회하며 Firestore에 없는 것만 업로드
  Future<void> uploadLocalToFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final collectionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('trip_logs');
    for (final entry in _entries) {
      await collectionRef.doc(entry.id).set(entry.toMap());
    }
  }

}