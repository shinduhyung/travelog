// lib/providers/subregion_provider.dart

import 'package:jidoapp/services/country_region_access.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jidoapp/models/admin_region.dart';

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

  static const String _syncedAtKey = 'visited_subregions_synced_at';
  // 로컬 기록이 어느 계정 것인지 ('' = 게스트). 같은 기기에서 계정을
  // 바꿨을 때 이전 계정의 지역 기록이 새 계정에 섞이는 것을 막는다.
  static const String _ownerUidKey = 'visited_subregions_owner_uid';

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
          (key, value) =>
              MapEntry(key, Set<String>.from(value as List<dynamic>)),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Error loading local subregions: $e');
        _visitedSubregions = {};
      }
    }

    // 1-2. 서버 데이터 로드
    if (user != null) {
      // 로컬 데이터가 다른 계정(또는 게스트) 것이면 신뢰하지 않는다.
      // owner 기록이 없는 예전 데이터(null)는 판단 불가로 보고 그대로 둔다.
      final String? localOwner = prefs.getString(_ownerUidKey);
      final bool localIsOtherAccount =
          localOwner != null && localOwner != user.uid;
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('visited_subregions')) {
          // CityProvider와 동일한 안전장치: 서버가 로컬보다 최신이거나 이 기기에
          // 동기화 기록이 없을 때만 서버 값으로 덮어쓴다. (서버 저장이 실패했던
          // 경우, 재로드 한 번에 방금 체크한 지역이 사라지는 것을 방지)
          final int localSyncedAtMs = localIsOtherAccount
              ? 0
              : (prefs.getInt(_syncedAtKey) ?? 0);
          final dynamic rawTimestamp = doc.data()!['lastUpdated'];
          final int remoteMs = (rawTimestamp is Timestamp)
              ? rawTimestamp.millisecondsSinceEpoch
              : 0;

          if (remoteMs >= localSyncedAtMs) {
            final String serverJson = doc.data()!['visited_subregions'];
            await prefs.setString('visited_subregions', serverJson);
            await prefs.setInt(_syncedAtKey, remoteMs);
            await prefs.setString(_ownerUidKey, user.uid);

            final Map<String, dynamic> decodedMap = json.decode(serverJson);
            _visitedSubregions = decodedMap.map(
              (key, value) =>
                  MapEntry(key, Set<String>.from(value as List<dynamic>)),
            );
          } else if (kDebugMode) {
            debugPrint(
              '[SubregionProvider] Local subregions are newer than server — keeping local copy.',
            );
          }
        } else if (localIsOtherAccount) {
          // 이 계정은 서버에 지역 기록이 없음 → 이전 계정의 로컬 기록이 섞이지 않게 비운다.
          _visitedSubregions = {};
          await prefs.remove('visited_subregions');
          await prefs.remove(_syncedAtKey);
          await prefs.setString(_ownerUidKey, user.uid);
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
    await prefs.setInt(_syncedAtKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_ownerUidKey, user?.uid ?? '');

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

  // ─── Admin-1 지역 (CountryDetail 지역 지도) ────────────────────────────
  // 저장 키는 ISO 3166-2 코드(예: "US-CA"). 이름은 국가 내 중복이 있어서
  // 키로 쓰지 않는다. 단, 예전 US 프로토타입(CountrySubregionsScreen)은
  // 이름("California")으로 저장했으므로 조회 시 이름도 함께 인정한다.

  bool isRegionVisited(String countryIsoA3, AdminRegion region) {
    if (region.isWholeArea) return false;
    final visited = _visitedSubregions[countryIsoA3];
    if (visited == null) return false;
    return visited.contains(region.stableKey) || visited.contains(region.name);
  }

  int visitedRegionCount(String countryIsoA3, Iterable<AdminRegion> regions) {
    return regions.where((r) => isRegionVisited(countryIsoA3, r)).length;
  }

  void _applyRegionVisit(
    String countryIsoA3,
    AdminRegion region,
    bool visited,
  ) {
    if (region.isWholeArea ||
        !CountryRegionAccess.isUnlocked(region.countryIsoA2))
      return;
    final set = _visitedSubregions.putIfAbsent(countryIsoA3, () => {});
    if (visited) {
      set.add(region.stableKey);
    } else {
      set
        ..remove(region.stableKey)
        ..remove(region.name);
    }
  }

  void setRegionVisited(String countryIsoA3, AdminRegion region, bool visited) {
    if (region.isWholeArea ||
        !CountryRegionAccess.isUnlocked(region.countryIsoA2))
      return;
    _applyRegionVisit(countryIsoA3, region, visited);
    _saveVisitedSubregions();
    notifyListeners();
  }

  /// Apply one selection screen draft with a single local/server save.
  void setRegionVisits(Map<String, Map<AdminRegion, bool>> changes) {
    final allowed = <String, Map<AdminRegion, bool>>{};
    for (final country in changes.entries) {
      final regions = Map<AdminRegion, bool>.fromEntries(
        country.value.entries.where(
          (entry) =>
              !entry.key.isWholeArea &&
              CountryRegionAccess.isUnlocked(entry.key.countryIsoA2),
        ),
      );
      if (regions.isNotEmpty) allowed[country.key] = regions;
    }
    if (allowed.isEmpty) return;
    for (final country in allowed.entries) {
      for (final region in country.value.entries) {
        _applyRegionVisit(country.key, region.key, region.value);
      }
    }
    _saveVisitedSubregions();
    notifyListeners();
  }

  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. 메모리 + 로컬 초기화
    _visitedSubregions = {};
    await prefs.remove('visited_subregions');
    await prefs.remove(_syncedAtKey);
    await prefs.remove(_ownerUidKey);

    // 2. Firestore에서 새로 로드
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('visited_subregions')) {
          final String serverJson = doc.data()!['visited_subregions'];
          await prefs.setString('visited_subregions', serverJson);
          final Map<String, dynamic> decodedMap = json.decode(serverJson);
          _visitedSubregions = decodedMap.map(
            (key, value) =>
                MapEntry(key, Set<String>.from(value as List<dynamic>)),
          );
        }
      } catch (e) {
        if (kDebugMode)
          debugPrint("Failed to reload subregions from server: $e");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveVisitedSubregions();
  }
}
