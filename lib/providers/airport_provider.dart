// lib/providers/airport_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/airport_visit_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const int _notProvided = -9999;

class AirportProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _error;
  List<Airport> _allAirports = [];

  Map<String, List<AirportVisitEntry>> _airportVisitHistory = {};
  Map<String, double> _airportRatings = {};
  Map<String, bool> _airportHubs = {};
  Map<String, bool> _airportFavorites = {};

  Map<String, String> _airportMemos = {};
  Map<String, List<String>> _airportPhotos = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Airport> get allAirports => _allAirports;

  List<AirportVisitEntry> getVisitEntries(String iataCode) => _airportVisitHistory[iataCode] ?? [];
  int getVisitCount(String iataCode) => getVisitEntries(iataCode).length;
  bool isVisited(String iataCode) => getVisitCount(iataCode) > 0;

  Set<String> get visitedAirports => _airportVisitHistory.keys.toSet();

  double getRating(String iataCode) => _airportRatings[iataCode] ?? 0.0;

  bool isHub(String iataCode) => _airportHubs[iataCode] ?? false;
  bool isFavorite(String iataCode) => _airportFavorites[iataCode] ?? false;

  String getMemo(String iataCode) => _airportMemos[iataCode] ?? '';
  List<String> getPhotos(String iataCode) => _airportPhotos[iataCode] ?? [];

  int getLoungeVisitCount(String iataCode) {
    final entries = getVisitEntries(iataCode);
    return entries.where((e) => e.isLoungeUsed).length;
  }

  double getAverageLoungeRating(String iataCode) {
    final entries = getVisitEntries(iataCode);
    final ratedVisits = entries.where((e) => e.isLoungeUsed && e.loungeRating != null && e.loungeRating! > 0).toList();
    if (ratedVisits.isEmpty) {
      return 0.0;
    }
    final sum = ratedVisits.fold<double>(0, (prev, e) => prev + e.loungeRating!);
    return sum / ratedVisits.length;
  }

  AirportProvider() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final String jsonStr = await rootBundle.loadString('assets/airports.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonStr);

      _allAirports = jsonMap.values
          .map((json) => Airport.fromJson(json))
          .where((airport) => airport.iataCode.isNotEmpty)
          .toList();

      await _loadAirportData();

    } catch (e) {
      _error = 'Failed to load airport data: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Synchronization Logic (Local + Firestore) ---

  Future<void> _loadAirportData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. Load from Local
    _loadFromLocal(prefs);

    // 2. Load from Server
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            bool serverHasData = false;

            if (data.containsKey('airport_visit_history')) {
              final String historyJson = data['airport_visit_history'];
              await prefs.setString('airport_visit_history', historyJson);
              _parseHistory(historyJson);
              serverHasData = true;
            }

            if (data.containsKey('airport_ratings')) {
              final String ratingsJson = data['airport_ratings'];
              await prefs.setString('airport_ratings', ratingsJson);
              _parseRatings(ratingsJson);
              serverHasData = true;
            }

            if (data.containsKey('airport_hubs')) {
              final String hubsJson = data['airport_hubs'];
              await prefs.setString('airport_hubs', hubsJson);
              _parseHubs(hubsJson);
              serverHasData = true;
            }

            if (data.containsKey('airport_favorites')) {
              final String favoritesJson = data['airport_favorites'];
              await prefs.setString('airport_favorites', favoritesJson);
              _parseFavorites(favoritesJson);
              serverHasData = true;
            }

            if (data.containsKey('airport_memos')) {
              final String memosJson = data['airport_memos'];
              await prefs.setString('airport_memos', memosJson);
              _airportMemos = Map<String, String>.from(json.decode(memosJson));
              serverHasData = true;
            }

            if (data.containsKey('airport_photos')) {
              final String photosJson = data['airport_photos'];
              await prefs.setString('airport_photos', photosJson);
              _parsePhotos(photosJson);
              serverHasData = true;
            }

            if (!serverHasData && (_airportVisitHistory.isNotEmpty || _airportRatings.isNotEmpty)) {
              await _saveAirportData();
            }
          }
        } else {
          await _saveAirportData();
        }
      } catch (e) {
        if (kDebugMode) print("Failed to load airport data from server: $e");
      }
    }
  }

  void _loadFromLocal(SharedPreferences prefs) {
    final savedHistoryJson = prefs.getString('airport_visit_history');
    if (savedHistoryJson != null) _parseHistory(savedHistoryJson);

    final savedRatingsJson = prefs.getString('airport_ratings');
    if (savedRatingsJson != null) _parseRatings(savedRatingsJson);

    final savedHubsJson = prefs.getString('airport_hubs');
    if (savedHubsJson != null) _parseHubs(savedHubsJson);

    final savedFavoritesJson = prefs.getString('airport_favorites');
    if (savedFavoritesJson != null) _parseFavorites(savedFavoritesJson);

    final savedMemosJson = prefs.getString('airport_memos');
    if (savedMemosJson != null) {
      _airportMemos = Map<String, String>.from(json.decode(savedMemosJson));
    }

    final savedPhotosJson = prefs.getString('airport_photos');
    if (savedPhotosJson != null) _parsePhotos(savedPhotosJson);
  }

  void _parseHistory(String jsonStr) {
    Map<String, dynamic> decodedHistory = json.decode(jsonStr);
    _airportVisitHistory = decodedHistory.map((iata, visitsJson) {
      final List<dynamic> visitsList = visitsJson as List<dynamic>;
      return MapEntry(
        iata,
        visitsList.map((v) => AirportVisitEntry.fromJson(v)).toList(),
      );
    });
  }

  void _parseRatings(String jsonStr) {
    Map<String, dynamic> decodedRatings = json.decode(jsonStr);
    _airportRatings = decodedRatings.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  void _parseHubs(String jsonStr) {
    Map<String, dynamic> decodedHubs = json.decode(jsonStr);
    _airportHubs = decodedHubs.map((key, value) => MapEntry(key, value as bool));
  }

  void _parseFavorites(String jsonStr) {
    Map<String, dynamic> decodedFavorites = json.decode(jsonStr);
    _airportFavorites = decodedFavorites.map((key, value) => MapEntry(key, value as bool));
  }

  void _parsePhotos(String jsonStr) {
    Map<String, dynamic> decodedPhotos = json.decode(jsonStr);
    _airportPhotos = decodedPhotos.map((iata, photoListJson) {
      return MapEntry(iata, List<String>.from(photoListJson));
    });
  }

  Future<void> _saveAirportData() async {
    final prefs = await SharedPreferences.getInstance();

    final historyJson = json.encode(_airportVisitHistory.map((iata, visits) {
      return MapEntry(iata, visits.map((v) => v.toJson()).toList());
    }));
    await prefs.setString('airport_visit_history', historyJson);

    final ratingsJson = json.encode(_airportRatings);
    await prefs.setString('airport_ratings', ratingsJson);

    final hubsJson = json.encode(_airportHubs);
    await prefs.setString('airport_hubs', hubsJson);

    final favoritesJson = json.encode(_airportFavorites);
    await prefs.setString('airport_favorites', favoritesJson);

    final memosJson = json.encode(_airportMemos);
    await prefs.setString('airport_memos', memosJson);

    final photosJson = json.encode(_airportPhotos);
    await prefs.setString('airport_photos', photosJson);

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'airport_visit_history': historyJson,
          'airport_ratings': ratingsJson,
          'airport_hubs': hubsJson,
          'airport_favorites': favoritesJson,
          'airport_memos': memosJson,
          'airport_photos': photosJson,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) print("Failed to save airport data to server: $e");
      }
    }
  }

  // --- Public Methods ---

  void addVisitEntry(String iataCode, {int? year, int? month, int? day, bool isTransfer = false, bool isLayover = false, bool isStopover = false}) {
    final now = DateTime.now();
    if (!_airportVisitHistory.containsKey(iataCode)) {
      _airportVisitHistory[iataCode] = [];
    }
    _airportVisitHistory[iataCode]!.add(
      AirportVisitEntry(
          year: year ?? now.year,
          month: month ?? now.month,
          day: day ?? now.day,
          isTransfer: isTransfer,
          isLayover: isLayover,
          isStopover: isStopover
      ),
    );
    _saveAirportData();
    notifyListeners();
  }

  void updateVisitEntry(String iataCode, int index, {
    int? year = _notProvided, int? month = _notProvided, int? day = _notProvided,
    bool? isTransfer, bool? isLayover, bool? isStopover,
    bool? isLoungeUsed, double? loungeRating,
    String? loungeMemo, List<String>? loungePhotos, int? loungeDurationInMinutes
  }) {
    final entries = _airportVisitHistory[iataCode];
    if (entries != null && index >= 0 && index < entries.length) {
      final entry = entries[index];

      if (year != _notProvided) entry.year = year;
      if (month != _notProvided) entry.month = month;
      if (day != _notProvided) entry.day = day;

      if (isTransfer != null) entry.isTransfer = isTransfer;
      if (isLayover != null) entry.isLayover = isLayover;
      if (isStopover != null) entry.isStopover = isStopover;

      if (isLoungeUsed != null) {
        entry.isLoungeUsed = isLoungeUsed;
        if (!isLoungeUsed) {
          entry.loungeRating = null;
          entry.loungeMemo = null;
          entry.loungePhotos = [];
          entry.loungeDurationInMinutes = null;
        }
      }

      if (loungeRating != null) entry.loungeRating = loungeRating;

      if (loungeMemo != null) {
        entry.loungeMemo = loungeMemo.trim().isNotEmpty ? loungeMemo.trim() : null;
      }
      if (loungePhotos != null) {
        entry.loungePhotos = loungePhotos;
      }
      if (loungeDurationInMinutes != _notProvided) {
        entry.loungeDurationInMinutes = loungeDurationInMinutes;
      }

      _saveAirportData();
      notifyListeners();
    }
  }

  void removeVisitEntry(String iataCode, int index) {
    final entries = _airportVisitHistory[iataCode];
    if (entries != null && index >= 0 && index < entries.length) {
      entries.removeAt(index);
      if (entries.isEmpty) {
        _airportVisitHistory.remove(iataCode);
        _airportHubs.remove(iataCode);
        _airportFavorites.remove(iataCode);
        _airportMemos.remove(iataCode);
        _airportPhotos.remove(iataCode);
      }
      _saveAirportData();
      notifyListeners();
    }
  }

  void updateRating(String iataCode, double rating) {
    _airportRatings[iataCode] = rating;
    _saveAirportData();
    notifyListeners();
  }

  void updateHubStatus(String iataCode, bool isHub) {
    if (isHub) {
      _airportHubs[iataCode] = true;
    } else {
      _airportHubs.remove(iataCode);
    }
    _saveAirportData();
    notifyListeners();
  }

  void updateFavoriteStatus(String iataCode, bool isFavorite) {
    if (isFavorite) {
      _airportFavorites[iataCode] = true;
    } else {
      _airportFavorites.remove(iataCode);
    }
    _saveAirportData();
    notifyListeners();
  }

  void updateMemoAndPhotos(String iataCode, String memo, List<String> photos) {
    if (memo.trim().isNotEmpty) {
      _airportMemos[iataCode] = memo.trim();
    } else {
      _airportMemos.remove(iataCode);
    }

    if (photos.isNotEmpty) {
      _airportPhotos[iataCode] = photos;
    } else {
      _airportPhotos.remove(iataCode);
    }

    _saveAirportData();
    notifyListeners();
  }

  Future<Map<String, dynamic>> getAirportFrequencyStats(String pattern) async {
    if (_airportVisitHistory.isEmpty) {
      return {'distribution': {}, 'most_frequent': 'N/A', 'count': 0};
    }

    final Map<String, int> periodCounts = {};
    final format = DateFormat(pattern);

    final allEntries = _airportVisitHistory.values.expand((entries) => entries);

    for (var entry in allEntries) {
      final date = entry.date;
      if (date != null) {
        String period = format.format(date);
        periodCounts[period] = (periodCounts[period] ?? 0) + 1;
      }
    }

    if (periodCounts.isEmpty) {
      return {'distribution': {}, 'most_frequent': 'N/A', 'count': 0};
    }

    final sortedPeriods = periodCounts.keys.toList()
      ..sort((a, b) => periodCounts[b]!.compareTo(periodCounts[a]!));

    final mostFrequentPeriod = sortedPeriods.first;
    final mostFrequentCount = periodCounts[mostFrequentPeriod]!;

    return {'distribution': periodCounts, 'most_frequent': mostFrequentPeriod, 'count': mostFrequentCount};
  }

  bool isDuplicateVisit(String iataCode, DateTime date) {
    final entries = _airportVisitHistory[iataCode];
    if (entries == null || entries.isEmpty) {
      return false;
    }
    return entries.any((entry) {
      return entry.year == date.year &&
          entry.month == date.month &&
          entry.day == date.day;
    });
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  // 로컬 데이터를 먼저 완전히 비운 후 Firestore에서 새로 로드
  Future<void> reloadFromServer() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 메모리 초기화
    _airportVisitHistory = {};
    _airportRatings = {};
    _airportHubs = {};
    _airportFavorites = {};
    _airportMemos = {};
    _airportPhotos = {};

    // 2. 로컬(prefs) 관련 키 초기화
    await prefs.remove('airport_visit_history');
    await prefs.remove('airport_ratings');
    await prefs.remove('airport_hubs');
    await prefs.remove('airport_favorites');
    await prefs.remove('airport_memos');
    await prefs.remove('airport_photos');

    // 3. Firestore에서 새로 로드
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data.containsKey('airport_visit_history')) {
            final String historyJson = data['airport_visit_history'];
            await prefs.setString('airport_visit_history', historyJson);
            _parseHistory(historyJson);
          }
          if (data.containsKey('airport_ratings')) {
            final String ratingsJson = data['airport_ratings'];
            await prefs.setString('airport_ratings', ratingsJson);
            _parseRatings(ratingsJson);
          }
          if (data.containsKey('airport_hubs')) {
            final String hubsJson = data['airport_hubs'];
            await prefs.setString('airport_hubs', hubsJson);
            _parseHubs(hubsJson);
          }
          if (data.containsKey('airport_favorites')) {
            final String favoritesJson = data['airport_favorites'];
            await prefs.setString('airport_favorites', favoritesJson);
            _parseFavorites(favoritesJson);
          }
          if (data.containsKey('airport_memos')) {
            final String memosJson = data['airport_memos'];
            await prefs.setString('airport_memos', memosJson);
            _airportMemos = Map<String, String>.from(json.decode(memosJson));
          }
          if (data.containsKey('airport_photos')) {
            final String photosJson = data['airport_photos'];
            await prefs.setString('airport_photos', photosJson);
            _parsePhotos(photosJson);
          }
        }
      } catch (e) {
        if (kDebugMode) print("Failed to reload airport data from server: $e");
      }
    }
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveAirportData();
  }

}