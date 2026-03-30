// lib/providers/unesco_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:jidoapp/models/unesco_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UnescoProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<UnescoSite> _allSites = [];
  Set<String> _visitedSites = {};
  Set<String> _wishlistedSites = {};
  Map<String, Set<String>> _visitedSubLocations = {};

  static const int _notProvided = -9999;

  bool get isLoading => _isLoading;
  List<UnescoSite> get allSites => _allSites;
  Set<String> get visitedSites => _visitedSites;
  Set<String> get wishlistedSites => _wishlistedSites;

  int get totalCount => _allSites.length;

  UnescoProvider() {
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final String response = await rootBundle.loadString('assets/unesco_landmarks.json');
      final data = await json.decode(response);
      _allSites = (data as List).map((json) => UnescoSite.fromJson(json)).toList();

      await _loadUserData();

    } catch (e) {
      if (kDebugMode) {
        print('Error loading UNESCO sites: $e');
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. 먼저 로컬 데이터를 불러옵니다.
    _loadFromLocal(prefs);

    if (user != null) {
      try {
        // 🔥 FIX: 네트워크 불안정/오프라인 시 무한 대기 방지를 위해 get()에 timeout 설정
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            // 2. 서버 데이터를 로컬 데이터와 병합(Merge)합니다.
            // 단순히 덮어씌우는 것이 아니라, 양쪽 데이터를 합쳐 데이터 유실을 방지합니다.

            if (data.containsKey('unesco_visited_sites')) {
              final serverVisited = List<String>.from(data['unesco_visited_sites']);
              _visitedSites.addAll(serverVisited);
            }
            if (data.containsKey('unesco_wishlisted_sites')) {
              final serverWishlisted = List<String>.from(data['unesco_wishlisted_sites']);
              _wishlistedSites.addAll(serverWishlisted);
            }
            if (data.containsKey('unesco_sub_locations')) {
              final decoded = json.decode(data['unesco_sub_locations']) as Map<String, dynamic>;
              decoded.forEach((key, value) {
                if (!_visitedSubLocations.containsKey(key)) {
                  _visitedSubLocations[key] = {};
                }
                _visitedSubLocations[key]!.addAll(Set<String>.from(value));
              });
            }
            if (data.containsKey('unesco_ratings')) {
              final ratingsMap = Map<String, dynamic>.from(json.decode(data['unesco_ratings']));
              for (var site in _allSites) {
                if (ratingsMap.containsKey(site.name)) {
                  site.rating = (ratingsMap[site.name] as num).toDouble();
                }
              }
            }
            if (data.containsKey('unesco_history')) {
              final historyMap = Map<String, dynamic>.from(json.decode(data['unesco_history']));
              for (var site in _allSites) {
                if (historyMap.containsKey(site.name)) {
                  final List<dynamic> serverVisits = historyMap[site.name];
                  final List<VisitDate> parsedVisits = serverVisits
                      .map((v) => VisitDate.fromJson(v as Map<String, dynamic>))
                      .toList();

                  // 중복을 피하기 위해 날짜와 제목이 같은 기록이 없을 때만 추가하거나,
                  // 서버 데이터를 우선하여 리스트를 재구성합니다.
                  if (site.visitDates.isEmpty) {
                    site.visitDates = parsedVisits;
                  }
                }
              }
            }

            // 3. 병합된 최신 데이터를 로컬과 서버에 다시 저장하여 상태를 동기화합니다.
            await _saveToLocal(prefs);
            await _syncAllToFirestore(); // 내부적으로 await 하지 않고 백그라운드 처리됨
          }
        } else {
          // 서버에 문서가 없으면 로컬 데이터를 서버에 최초 업로드합니다.
          await _syncAllToFirestore();
        }
      } catch (e) {
        if (kDebugMode) print("Failed to sync UNESCO data (Offline or Error): $e");
      }
    }
  }

  void _loadFromLocal(SharedPreferences prefs) {
    final visited = prefs.getStringList('visited_unesco_sites');
    if (visited != null) _visitedSites.addAll(visited);

    final wishlisted = prefs.getStringList('wishlisted_unesco_sites');
    if (wishlisted != null) _wishlistedSites.addAll(wishlisted);

    final subData = prefs.getString('visited_unesco_sub_locations');
    if (subData != null) {
      try {
        final decoded = json.decode(subData) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (!_visitedSubLocations.containsKey(key)) {
            _visitedSubLocations[key] = {};
          }
          _visitedSubLocations[key]!.addAll(Set<String>.from(value));
        });
      } catch (e) {}
    }

    final ratingsJson = prefs.getString('unesco_site_ratings');
    if (ratingsJson != null) {
      final ratingsMap = Map<String, dynamic>.from(json.decode(ratingsJson));
      for (var site in _allSites) {
        if (ratingsMap.containsKey(site.name)) {
          site.rating = (ratingsMap[site.name] as num).toDouble();
        }
      }
    }

    final historyJson = prefs.getString('unesco_site_visit_history');
    if (historyJson != null) {
      final historyMap = Map<String, dynamic>.from(json.decode(historyJson));
      for (var site in _allSites) {
        if (historyMap.containsKey(site.name)) {
          site.visitDates = (historyMap[site.name] as List)
              .map((visitJson) => VisitDate.fromJson(visitJson as Map<String, dynamic>))
              .toList();
        }
      }
    }
  }

  // 로컬 저장소를 한 번에 업데이트하는 헬퍼 메서드
  Future<void> _saveToLocal(SharedPreferences prefs) async {
    await prefs.setStringList('visited_unesco_sites', _visitedSites.toList());
    await prefs.setStringList('wishlisted_unesco_sites', _wishlistedSites.toList());

    final subLocsEncoded = _visitedSubLocations.map((key, value) => MapEntry(key, value.toList()));
    await prefs.setString('visited_unesco_sub_locations', json.encode(subLocsEncoded));

    final ratingsMap = { for (var site in _allSites) if (site.rating != null && site.rating! > 0) site.name: site.rating! };
    await prefs.setString('unesco_site_ratings', json.encode(ratingsMap));

    final historyMap = {
      for (var site in _allSites)
        if (site.visitDates.isNotEmpty)
          site.name: site.visitDates.map((d) => d.toJson()).toList()
    };
    await prefs.setString('unesco_site_visit_history', json.encode(historyMap));
  }

  // 모든 유저 데이터를 하나의 Map으로 묶어 Firestore에 단일 호출로 저장합니다.
  Future<void> _syncAllToFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await _saveToLocal(prefs); // 로컬 저장까지는 확실하게 완료를 대기

    final subLocsEncoded = _visitedSubLocations.map((key, value) => MapEntry(key, value.toList()));
    final ratingsMap = { for (var site in _allSites) if (site.rating != null && site.rating! > 0) site.name: site.rating! };
    final historyMap = {
      for (var site in _allSites)
        if (site.visitDates.isNotEmpty)
          site.name: site.visitDates.map((d) => d.toJson()).toList()
    };

    try {
      // 🔥 FIX: await 제거!
      // Firestore의 쓰기(set) 작업은 오프라인일 때 무한 대기하므로, 완료를 기다리지 않고 Firebase 백그라운드 큐에 맡깁니다.
      _firestore.collection('users').doc(user.uid).set({
        'unesco_visited_sites': _visitedSites.toList(),
        'unesco_wishlisted_sites': _wishlistedSites.toList(),
        'unesco_sub_locations': json.encode(subLocsEncoded),
        'unesco_ratings': json.encode(ratingsMap),
        'unesco_history': json.encode(historyMap),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        if (kDebugMode) print("Firestore background sync error: $e");
      });
    } catch (e) {
      if (kDebugMode) print("Firestore sync dispatch failed: $e");
    }
  }

  // 기존 개별 저장 메서드들이 이제 공통 동기화 로직을 호출하도록 변경합니다.
  Future<void> _saveAllUserData() async {
    await _syncAllToFirestore();
  }

  bool isSubLocationVisited(String siteName, String subLocName) {
    return _visitedSubLocations[siteName]?.contains(subLocName) ?? false;
  }

  int getVisitedSubLocationCount(String siteName) {
    return _visitedSubLocations[siteName]?.length ?? 0;
  }

  void toggleSubLocation(String siteName, String subLocName) {
    if (!_visitedSubLocations.containsKey(siteName)) {
      _visitedSubLocations[siteName] = {};
    }

    final subLocs = _visitedSubLocations[siteName]!;
    bool isAdding = false;

    if (subLocs.contains(subLocName)) {
      subLocs.remove(subLocName);
    } else {
      subLocs.add(subLocName);
      isAdding = true;
    }

    if (subLocs.isNotEmpty) {
      _visitedSites.add(siteName);
      if (isAdding) {
        final site = _allSites.firstWhere((s) => s.name == siteName);
        if (site.visitDates.isEmpty) {
          addVisitDate(siteName, initialSubLocations: [subLocName]);
          return; // addVisitDate 내부에서 sync 호출됨
        }
      }
    }

    _syncAllToFirestore();
    notifyListeners();
  }

  void toggleWishlistStatus(String siteName) {
    if (_wishlistedSites.contains(siteName)) {
      _wishlistedSites.remove(siteName);
    } else {
      _wishlistedSites.add(siteName);
    }
    _syncAllToFirestore();
    notifyListeners();
  }

  void toggleVisitedStatus(String siteName) {
    if (_visitedSites.contains(siteName)) {
      final site = _allSites.firstWhere((l) => l.name == siteName);
      site.visitDates.clear();
      _visitedSites.remove(siteName);
      _visitedSubLocations.remove(siteName);

      _syncAllToFirestore();
      notifyListeners();
    } else {
      addVisitDate(siteName);
    }
  }

  Future<void> updateLandmarkRating(String siteName, double newRating) async {
    try {
      final site = _allSites.firstWhere((l) => l.name == siteName);
      site.rating = (newRating == 0.0) ? null : newRating;
      await _syncAllToFirestore();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error updating rating: $e');
    }
  }

  Future<void> addVisitDate(String siteName, {List<String>? initialSubLocations, DateTime? date}) async {
    try {
      final site = _allSites.firstWhere((l) => l.name == siteName);
      final targetDate = date ?? DateTime.now();

      final newVisit = VisitDate(
        year: targetDate.year,
        month: targetDate.month,
        day: targetDate.day,
        title: '',
        memo: null,
        photos: [],
        visitedDetails: initialSubLocations ?? [],
      );

      site.visitDates.insert(0, newVisit);
      _visitedSites.add(siteName);

      await _syncAllToFirestore();
      notifyListeners();

    } catch (e) {
      if (kDebugMode) print('Error adding visit date: $e');
    }
  }

  Future<void> removeVisitDate(String siteName, int index) async {
    try {
      final site = _allSites.firstWhere((l) => l.name == siteName);
      if (index >= 0 && index < site.visitDates.length) {
        site.visitDates.removeAt(index);

        if (site.visitDates.isEmpty && getVisitedSubLocationCount(siteName) == 0) {
          _visitedSites.remove(siteName);
        }
        await _syncAllToFirestore();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error removing visit date: $e');
    }
  }

  Future<void> updateLandmarkVisit(String siteName, int index, {
    int? year = _notProvided,
    int? month = _notProvided,
    int? day = _notProvided,
    String? title,
    String? memo,
    List<String>? photos,
    List<String>? visitedDetails,
  }) async {
    try {
      final site = _allSites.firstWhere((l) => l.name == siteName);
      if (index >= 0 && index < site.visitDates.length) {
        final visit = site.visitDates[index];
        bool dateChanged = false;

        if (year != _notProvided) { visit.year = year; dateChanged = true; }
        if (month != _notProvided) { visit.month = month; dateChanged = true; }
        if (day != _notProvided) { visit.day = day; dateChanged = true; }
        if (title != null) visit.title = title;
        if (memo != null) visit.memo = memo.trim().isNotEmpty ? memo.trim() : null;
        if (photos != null) visit.photos = photos;
        if (visitedDetails != null) visit.visitedDetails = visitedDetails;

        if (dateChanged) {
          site.visitDates.sort((a, b) {
            final dateA = DateTime(a.year ?? 1900, a.month ?? 1, a.day ?? 1);
            final dateB = DateTime(b.year ?? 1900, b.month ?? 1, b.day ?? 1);
            return dateB.compareTo(dateA);
          });
        }
        await _syncAllToFirestore();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error updating visit: $e');
    }
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    // 방문 데이터 초기화 후 서버에서 재로드
    _visitedSites.clear();
    _wishlistedSites.clear();
    _visitedSubLocations.clear();
    for (var site in _allSites) {
      site.visitDates.clear();
      site.rating = null;
    }
    await _loadUserData();
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _syncAllToFirestore();
  }

}