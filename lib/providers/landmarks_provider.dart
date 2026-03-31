// lib/providers/landmarks_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LandmarksProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Landmark> _allLandmarks = [];
  Set<String> _visitedLandmarks = {};
  Set<String> _visitedSubLocations = {};
  Set<String> _wishlistedLandmarks = {};
  CountryProvider? _countryProvider;
  CityProvider? _cityProvider;

  static const int _notProvided = -9999;

  String? _selectedCountryIsoA3;

  bool get isLoading => _isLoading;
  List<Landmark> get allLandmarks => _allLandmarks;
  Set<String> get visitedLandmarks => _visitedLandmarks;
  Set<String> get visitedSubLocations => _visitedSubLocations;
  Set<String> get wishlistedLandmarks => _wishlistedLandmarks;

  String? get selectedCountryIsoA3 => _selectedCountryIsoA3;

  List<Landmark> get landmarksBySelectedCountry {
    if (_selectedCountryIsoA3 == null) {
      return _allLandmarks;
    }
    return getLandmarksByCountry (_selectedCountryIsoA3!);
  }

  List<Landmark> getLandmarksByCountry (String countryIsoA3) {
    return _allLandmarks.where ((landmark) {
      return landmark.countriesIsoA3.contains (countryIsoA3);
    }).toList ();
  }

  List<Landmark> getLandmarksByAttributes (List<String> attributes) {
    if (attributes.isEmpty) {
      return _allLandmarks;
    }
    return _allLandmarks.where ((landmark) {
      return attributes.any ((attr) => landmark.attributes.contains (attr));
    }).toList ();
  }

  LandmarksProvider () {
    _loadAllData ();
  }

  void updateProviders (CountryProvider countryProvider, CityProvider cityProvider) {
    _countryProvider = countryProvider;
    _cityProvider = cityProvider;
  }

  void selectCountryFilter (String? countryIsoA3) {
    _selectedCountryIsoA3 = countryIsoA3;
    notifyListeners ();
  }

  Future<void> _loadAllData () async {
    print ('[DEBUG_LANDMARKS] _loadAllData started. Setting _isLoading = true');
    _isLoading = true;
    notifyListeners ();

    List<dynamic> globalRankData = [];

    try {
      // 1. 기본 랜드마크 데이터 로드
      print ('[DEBUG_LANDMARKS] Loading all_landmarks.json...');
      final String response = await rootBundle.loadString ('assets/all_landmarks.json');
      final data = await json.decode (response);

      _allLandmarks = (data as List).map ((json) => Landmark.fromJson (json)).toList ();
      print ('[DEBUG_LANDMARKS] Loaded ${_allLandmarks.length} landmarks info.');

      // 2. 새로운 Global Rank 데이터 로드 및 적용
      try {
        print ('[DEBUG_LANDMARKS] Loading global_rank.json...');
        final String globalRankResponse = await rootBundle.loadString ('assets/global_rank.json');
        globalRankData = json.decode (globalRankResponse);

        // 기존 랭크 초기화
        for (var l in _allLandmarks) {
          l.global_rank = 0;
        }

        List<String> missingFromAllLandmarks = [];
        int updateCount = 0;

        for (var item in globalRankData) {
          final String? targetName = item['name'];
          final int? newRank = item['rank'];

          if (targetName != null && newRank != null) {
            try {
              final landmark = _allLandmarks.firstWhere ((l) => l.name == targetName);
              landmark.global_rank = newRank;
              updateCount++;
            } catch (_) {
              missingFromAllLandmarks.add (targetName);
            }
          }
        }

        // 불일치 리스트 출력
        print ('\n[Global Rank Name Mismatch Check]');
        if (missingFromAllLandmarks.isEmpty) {
          print ('결과: global_rank.json의 모든 랜드마크가 all_landmarks.json에 존재합니다.');
        } else {
          print ('결과: 총 ${missingFromAllLandmarks.length}개의 랜드마크가 all_landmarks.json에서 발견되지 않았습니다 (스펠링 확인 필요):');
          for (var name in missingFromAllLandmarks) {
            print ('- $name');
          }
        }
        print ('[DEBUG_LANDMARKS] Successfully updated $updateCount landmarks with new global ranks.');
      } catch (e) {
        print ('[DEBUG_LANDMARKS] Warning: Could not load or apply global_rank.json: $e');
      }

      // 3. 디버그 로그 및 Local Rank 매핑
      try {
        final bracketLandmarks = _allLandmarks.where ((l) => l.name.contains ('(') || l.name.contains (')')).toList ();
        print ('\n[Landmarks with Parentheses in Name Check]');
        if (bracketLandmarks.isEmpty) {
          print ('결과: 이름에 괄호가 포함된 랜드마크가 데이터셋에 하나도 없습니다.');
        } else {
          print ('총 ${bracketLandmarks.length}개 발견:');
          for (var l in bracketLandmarks) {
            print ('- ${l.name}');
          }
        }
      } catch (e) {
        print ('Error during parentheses check: $e');
      }

      final Map<String, Landmark> landmarkMap = {
        for (var l in _allLandmarks) l.name: l
      };

      try {
        final String rankResponse = await rootBundle.loadString ('assets/local_rank.json');
        final rankData = await json.decode (rankResponse) as List;

        print ('\n[Local Rank Missing Landmarks Check]');
        List<String> missingLocalLandmarks = [];

        for (var countryGroup in rankData) {
          final String? countryCode = countryGroup['country'];
          final List? items = countryGroup['items'];

          if (countryCode != null && items != null) {
            for (var item in items) {
              final String? landmarkName = item['name'];
              final int? rank = item['local_rank'];

              if (landmarkName != null && rank != null) {
                if (landmarkMap.containsKey (landmarkName)) {
                  landmarkMap[landmarkName]!.localRanks[countryCode] = rank;
                } else {
                  missingLocalLandmarks.add ('[$countryCode] Rank $rank: $landmarkName');
                }
              }
            }
          }
        }

        if (missingLocalLandmarks.isEmpty) {
          print ('결과: local_rank.json의 모든 랜드마크가 존재합니다.');
        } else {
          print ('결과: 총 ${missingLocalLandmarks.length}개의 랜드마크가 누락되었습니다:');
          for (var msg in missingLocalLandmarks) {
            print (msg);
          }
        }

      } catch (e) {
        print ('Error loading local ranks: $e');
      }

      await _loadUserData ();
      printLandmarksByCityCount ();
      checkSpecifiedLandmarks ();
      printTopUniversities (); // 대학교 체크 함수 호출

      if (globalRankData.isNotEmpty) {
        printGlobalRankEmptyCityCheck (globalRankData);
      }

    } catch (e, stackTrace) {
      print ('CRITICAL ERROR in _loadAllData: $e');
      print ('StackTrace: $stackTrace');
    }

    _isLoading = false;
    print ('[DEBUG_LANDMARKS] _loadAllData finished. _isLoading = false');
    notifyListeners ();
  }

  // 수정된 함수: attribute_rank를 사용하고 대소문자 구분 없이 'university' 속성을 확인합니다.
  void printTopUniversities () {
    print ('\n[Top Universities Check - Attribute Rank <= 100]');

    final topUniversities = _allLandmarks.where ((l) {
      final isUniversity = l.attributes.any((attr) => attr.toLowerCase() == 'university');
      return isUniversity &&
          l.attribute_rank > 0 &&
          l.attribute_rank <= 100;
    }).toList ();

    // attribute_rank 순으로 오름차순 정렬
    topUniversities.sort ((a, b) => a.attribute_rank.compareTo (b.attribute_rank));

    if (topUniversities.isEmpty) {
      print ('결과: 조건에 맞는 대학교 랜드마크가 없습니다.');
    } else {
      print ('총 ${topUniversities.length}개 발견:');
      for (var l in topUniversities) {
        print ('- Attribute Rank ${l.attribute_rank}: ${l.name}');
      }
    }
  }

  void printGlobalRankEmptyCityCheck (List<dynamic> globalRankData) {
    print ('\n[Global Rank - Empty City Check]');
    int count = 0;

    for (var item in globalRankData) {
      final String? targetName = item['name'];
      final int? newRank = item['rank'];

      if (targetName != null && newRank != null) {
        try {
          final landmark = _allLandmarks.firstWhere ((l) => l.name == targetName);

          String cityVal = 'null';
          try {
            final dynamic c = (landmark as dynamic).city;
            if (c != null) {
              cityVal = c.toString();
            }
          } catch (_) {}

          String checkVal = cityVal.trim().toLowerCase();

          if (checkVal.isEmpty ||
              checkVal == 'null' ||
              checkVal.contains('unknown') ||
              checkVal == 'n/a' ||
              checkVal == 'none' ||
              checkVal == '-' ||
              checkVal == 'not specified') {
            print ('Rank: $newRank | Name: $targetName | 현재 도시값: "$cityVal"');
            count++;
          }
        } catch (_) {
          // 무시
        }
      }
    }

    if (count == 0) {
      print ('결과: global_rank.json에 정의된 랜드마크 중 도시명이 비어있는 항목이 없습니다.');
    } else {
      print ('결과: 총 $count 개의 랜드마크의 도시명이 비어있거나 확인 불가 상태입니다.');
    }
  }

  void checkSpecifiedLandmarks () {
    if (_allLandmarks.isEmpty) return;

    final List<String> targetNames = [
      'Colosseum', "St. Peter's Basilica", 'Trevi Fountain', 'Pantheon', 'Roman Forum', 'Spanish Steps', 'Piazza Navona',
      'The Grand Palace', 'Wat Arun', 'Wat Pho', 'Wat Phra Kaew', 'Damnoen Saduak Floating Market', 'Chatuchak Weekend Market', 'Lumpini Park',
      'Sagrada Familia', 'Park Güell', 'La Rambla', 'Casa Batlló', 'Gothic Quarter', 'Casa Milà', 'Magic Fountain of Montjuïc',
      'Burj Khalifa', 'Dubai Mall', 'Palm Jumeirah', 'Dubai Fountain', 'Burj Al Arab', 'Museum of the Future', 'The Dubai Frame',
      'Sydney Opera House', 'Sydney Harbour Bridge', 'Bondi Beach', 'Darling Harbour', 'The Rocks', 'Taronga Zoo Sydney', 'Royal Botanic Garden Sydney',
      'Hollywood Sign', 'Griffith Observatory', 'Santa Monica Beach', 'Hollywood Walk of Fame', 'The Getty Center', 'Venice Beach', 'Walt Disney Concert Hall',
      'The Bund', 'Yu Garden', 'Oriental Pearl Tower', 'Shanghai Tower', 'Nanjing Road', 'People\'s Square', 'Shanghai Museum',
      'Anne Frank House', 'Van Gogh Museum', 'Rijksmuseum', 'Canal Ring', 'Red Light District', 'Dam Square', 'Vondelpark',
      'Charles Bridge', 'Prague Castle', 'Old Town Square', 'St. Vitus Cathedral', 'Jewish Quarter', 'Wenceslas Square', 'Petřín Lookout Tower',
      'Prado Museum', 'Royal Palace of Madrid', 'Plaza Mayor', 'Retiro Park', 'Puerta del Sol', 'Gran Vía', 'Puerta de Alcalá',
      'Taipei 101', 'National Palace Museum', 'Chiang Kai-shek Memorial Hall', 'Shilin Night Market', 'Longshan Temple', 'Ximending', 'Dihua Street',
      'Hungarian Parliament Building', 'Buda Castle', 'Fisherman\'s Bastion', 'Széchenyi Chain Bridge', 'St. Stephen\'s Basilica', 'Heroes\' Square', 'Széchenyi Thermal Baths',
      'Belém Tower', 'Jerónimos Monastery', 'São Jorge Castle', 'Praça do Comércio', 'Alfama District', 'Padrão dos Descobrimentos', 'Santa Justa Lift',
      'Parthenon', 'Acropolis Museum', 'Plaka', 'Ancient Agora of Athens', 'Temple of Olympian Zeus', 'Syntagma Square', 'Panathenaic Stadium',
      'Marienplatz', 'English Garden', 'BMW Welt & Museum', 'Nymphenburg Palace', 'Munich Residenz', 'Deutsches Museum', 'Allianz Arena',
      'CN Tower', 'Royal Ontario Museum', 'Distillery District', 'Ripley\'s Aquarium of Canada', 'St. Lawrence Market', 'Art Gallery of Ontario', 'Casa Loma',
      'Petronas Towers', 'Batu Caves', 'Merdeka Square', 'Bukit Bintang', 'KL Tower', 'Thean Hou Temple', 'Islamic Arts Museum Malaysia',
      'Nyhavn', 'Tivoli Gardens', 'The Little Mermaid', 'Amalienborg', 'Rosenborg Castle', 'Christiansborg Palace', 'The Round Tower',
      'Vasa Museum', 'Gamla Stan', 'Stockholm Palace', 'Stockholm City Hall', 'Skansen', 'ABBA The Museum', 'Stockholm Metro Art',
      'Cloud Gate', 'Art Institute of Chicago', 'Willis Tower', 'Magnificent Mile', 'Chicago Theatre', 'Chicago Architecture Tour', 'Lincoln Park Zoo'
    ];

    print ('\n[Database Name Matching Check]');
    final Set<String> dbNames = _allLandmarks.map ((l) => l.name).toSet ();

    for (var name in targetNames) {
      if (dbNames.contains (name)) {
        print ('[O] $name');
      } else {
        print ('[X] MISSING: $name');
      }
    }
  }

  void printLandmarksByCityCount () {
    if (_allLandmarks.isEmpty) return;

    final Map<String, List<Landmark>> cityGroups = {};

    for (var landmark in _allLandmarks) {
      final city = landmark.city;
      if (!cityGroups.containsKey (city)) {
        cityGroups[city] = [];
      }
      cityGroups[city]!.add (landmark);
    }

    final sortedEntries = cityGroups.entries.toList ()
      ..sort ((a, b) => b.value.length.compareTo (a.value.length));

    print ('\n[Landmarks Count by City Rank (Top 50)]');
    for (var entry in sortedEntries.take (50)) {
      final cityName = entry.key;
      final count = entry.value.length;
      final landmarkNames = entry.value.map ((l) => l.name).join (', ');

      print ('$cityName ($count) $landmarkNames');
    }
  }

  Future<void> _loadUserData () async {
    final prefs = await SharedPreferences.getInstance ();
    final user = _auth.currentUser;

    if (user != null) {
      try {
        final doc = await _firestore.collection ('users').doc (user.uid).get ();
        if (doc.exists) {
          final data = doc.data ();
          if (data != null) {
            if (data.containsKey ('landmark_ratings')) {
              await prefs.setString ('landmark_ratings', data['landmark_ratings']);
            }
            if (data.containsKey ('visited_landmarks')) {
              final List<dynamic> visitedList = data['visited_landmarks'];
              await prefs.setStringList ('visited_landmarks', visitedList.cast<String> ());
            }
            if (data.containsKey ('visited_landmark_sublocations')) {
              final List<dynamic> subLocList = data['visited_landmark_sublocations'];
              await prefs.setStringList ('visited_landmark_sublocations', subLocList.cast<String> ());
            }
            if (data.containsKey ('wishlisted_landmarks')) {
              final List<dynamic> wishList = data['wishlisted_landmarks'];
              await prefs.setStringList ('wishlisted_landmarks', wishList.cast<String> ());
            }
            if (data.containsKey ('landmark_visit_history')) {
              await prefs.setString ('landmark_visit_history', data['landmark_visit_history']);
            }
            _loadFromLocal (prefs);
          }
        } else {
          // Firestore에 데이터 없으면 로컬도 읽지 않음 (빈 상태 유지)
          _loadFromLocal (prefs);
        }
      } catch (e) {
        print ('Error loading user data from Firestore: $e');
        _loadFromLocal (prefs);
      }
    } else {
      // 비로그인 상태면 로컬 데이터 읽기
      _loadFromLocal (prefs);
    }
  }

  void _loadFromLocal (SharedPreferences prefs) {
    final ratingsJson = prefs.getString ('landmark_ratings');
    if (ratingsJson != null) {
      final ratingsMap = Map<String, double>.from (json.decode (ratingsJson));
      for (var landmark in _allLandmarks) {
        if (ratingsMap.containsKey (landmark.name)) {
          landmark.rating = ratingsMap[landmark.name];
        }
      }
    }

    final visited = prefs.getStringList ('visited_landmarks');
    if (visited != null) _visitedLandmarks = visited.toSet ();

    final visitedSub = prefs.getStringList ('visited_landmark_sublocations');
    if (visitedSub != null) _visitedSubLocations = visitedSub.toSet ();

    final wishlisted = prefs.getStringList ('wishlisted_landmarks');
    if (wishlisted != null) _wishlistedLandmarks = wishlisted.toSet ();

    final historyJson = prefs.getString ('landmark_visit_history');
    if (historyJson != null) {
      final historyMap = Map<String, List<dynamic>>.from (json.decode (historyJson));
      for (var landmark in _allLandmarks) {
        if (historyMap.containsKey (landmark.name)) {
          landmark.visitDates = historyMap[landmark.name]!
              .map ((visitJson) => VisitDate.fromJson (visitJson as Map<String, dynamic>))
              .toList ();
        }
      }
    }

    _visitedLandmarks.clear ();
    for (var landmark in _allLandmarks) {
      if (landmark.visitDates.isNotEmpty) {
        _visitedLandmarks.add (landmark.name);
      }
    }
  }

  Future<void> _saveAllUserData () async {
    await _saveLandmarkRatings ();
    await _saveVisitedLandmarks ();
    await _saveVisitedSubLocations ();
    await _saveWishlistedLandmarks ();
    await _saveVisitHistory ();
  }

  Future<void> _saveVisitedLandmarks () async {
    final prefs = await SharedPreferences.getInstance ();
    final list = _visitedLandmarks.toList ();
    await prefs.setStringList ('visited_landmarks', list);

    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection ('users').doc (user.uid).set ({
        'visited_landmarks': list,
        'lastUpdated': FieldValue.serverTimestamp (),
      }, SetOptions (merge: true));
    }
  }

  Future<void> _saveVisitedSubLocations () async {
    final prefs = await SharedPreferences.getInstance ();
    final list = _visitedSubLocations.toList ();
    await prefs.setStringList ('visited_landmark_sublocations', list);

    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection ('users').doc (user.uid).set ({
        'visited_landmark_sublocations': list,
      }, SetOptions (merge: true));
    }
  }

  Future<void> _saveWishlistedLandmarks () async {
    final prefs = await SharedPreferences.getInstance ();
    final list = _wishlistedLandmarks.toList ();
    await prefs.setStringList ('wishlisted_landmarks', list);

    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection ('users').doc (user.uid).set ({
        'wishlisted_landmarks': list,
      }, SetOptions (merge: true));
    }
  }

  Future<void> _saveLandmarkRatings () async {
    final prefs = await SharedPreferences.getInstance ();
    final ratingsMap = {
      for (var landmark in _allLandmarks)
        if (landmark.rating != null && landmark.rating! > 0)
          landmark.name: landmark.rating!
    };
    final jsonStr = json.encode (ratingsMap);
    await prefs.setString ('landmark_ratings', jsonStr);

    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection ('users').doc (user.uid).set ({
        'landmark_ratings': jsonStr,
      }, SetOptions (merge: true));
    }
  }

  Future<void> _saveVisitHistory () async {
    final prefs = await SharedPreferences.getInstance ();
    final historyMap = {
      for (var landmark in _allLandmarks)
        if (landmark.visitDates.isNotEmpty)
          landmark.name: landmark.visitDates.map ((d) => d.toJson ()).toList ()
    };
    final jsonStr = json.encode (historyMap);
    await prefs.setString ('landmark_visit_history', jsonStr);

    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection ('users').doc (user.uid).set ({
        'landmark_visit_history': jsonStr,
      }, SetOptions (merge: true));
    }
  }

  void toggleWishlistStatus (String landmarkName) {
    if (_wishlistedLandmarks.contains (landmarkName)) {
      _wishlistedLandmarks.remove (landmarkName);
    } else {
      _wishlistedLandmarks.add (landmarkName);
    }
    _saveWishlistedLandmarks ();
    notifyListeners ();
  }

  Future<void> updateLandmarkRating (String landmarkName, double newRating) async {
    try {
      final landmark = _allLandmarks.firstWhere ((l) => l.name == landmarkName);
      landmark.rating = (newRating == 0.0) ? null : newRating;
      await _saveLandmarkRatings ();
      notifyListeners ();
    } catch (e) {
      print ('Error updating landmark rating: $e');
    }
  }

  Future<void> addVisitDate (String landmarkName, {DateTime? date}) async {
    try {
      final landmark = _allLandmarks.firstWhere ((l) => l.name == landmarkName);
      final targetDate = date ?? DateTime.now ();

      final newVisit = VisitDate (
        year: targetDate.year,
        month: targetDate.month,
        day: targetDate.day,
        title: '',
        memo: null,
        photos: [],
        visitedDetails: [],
      );

      landmark.visitDates.insert (0, newVisit);
      _visitedLandmarks.add (landmarkName);
      await _saveVisitHistory ();
      await _saveVisitedLandmarks ();
      notifyListeners ();

    } catch (e) {
      print ('Error adding visit date: $e');
    }
  }

  Future<void> removeVisitDate (String landmarkName, int index) async {
    try {
      final landmark = _allLandmarks.firstWhere ((l) => l.name == landmarkName);
      if (index >= 0 && index < landmark.visitDates.length) {
        landmark.visitDates.removeAt (index);
        if (landmark.visitDates.isEmpty) {
          _visitedLandmarks.remove (landmarkName);
        }
        await _saveVisitHistory ();
        await _saveVisitedLandmarks ();
        notifyListeners ();
      }
    } catch (e) {
      print ('Error removing visit date: $e');
    }
  }

  Future<void> updateLandmarkVisit (String landmarkName, int index, {
    int? year = _notProvided,
    int? month = _notProvided,
    int? day = _notProvided,
    String? title,
    String? memo,
    List<String>? photos,
    List<String>? visitedDetails,
  }) async {
    try {
      final landmark = _allLandmarks.firstWhere ((l) => l.name == landmarkName);
      if (index >= 0 && index < landmark.visitDates.length) {
        final visit = landmark.visitDates[index];
        bool dateChanged = false;

        if (year != _notProvided) {
          visit.year = year;
          dateChanged = true;
        }
        if (month != _notProvided) {
          visit.month = month;
          dateChanged = true;
        }
        if (day != _notProvided) {
          visit.day = day;
          dateChanged = true;
        }
        if (title != null) visit.title = title;
        if (memo != null) visit.memo = memo.trim ().isNotEmpty ? memo.trim () : null;
        if (photos != null) visit.photos = photos;
        if (visitedDetails != null) visit.visitedDetails = visitedDetails;

        if (dateChanged) {
          landmark.visitDates.sort ((a, b) {
            final dateA = DateTime (a.year ?? 1900, a.month ?? 1, a.day ?? 1);
            final dateB = DateTime (b.year ?? 1900, b.month ?? 1, b.day ?? 1);
            return dateB.compareTo (dateA);
          });
        }
        await _saveVisitHistory ();
        notifyListeners ();
      }
    } catch (e) {
      print ('Error updating landmark visit: $e');
    }
  }

  void toggleVisitedStatus (String landmarkName) {
    if (_visitedLandmarks.contains (landmarkName)) {
      final landmark = _allLandmarks.firstWhere ((l) => l.name == landmarkName);
      landmark.visitDates.clear ();
      _visitedLandmarks.remove (landmarkName);

      if (landmark.locations != null) {
        for (var loc in landmark.locations!) {
          _visitedSubLocations.remove ('${landmarkName}_${loc.name}');
        }
        _saveVisitedSubLocations ();
      }

      _saveVisitHistory ();
      _saveVisitedLandmarks ();
      notifyListeners ();
    } else {
      addVisitDate (landmarkName);
    }
  }

  String _getSubLocationKey (String parentName, String subLocationName) {
    return '${parentName}_$subLocationName';
  }

  bool isSubLocationVisited (String parentName, String subLocationName) {
    return _visitedSubLocations.contains (_getSubLocationKey (parentName, subLocationName));
  }

  void toggleSubLocation (String parentName, String subLocationName) {
    final key = _getSubLocationKey (parentName, subLocationName);
    if (_visitedSubLocations.contains (key)) {
      _visitedSubLocations.remove (key);
    } else {
      _visitedSubLocations.add (key);
      if (!_visitedLandmarks.contains (parentName)) {
        addVisitDate (parentName);
      }
    }
    _saveVisitedSubLocations ();
    notifyListeners ();
  }

  int getVisitedSubLocationCount (String parentName) {
    final landmark = _allLandmarks.firstWhere ((l) => l.name == parentName);
    if (landmark.locations == null || landmark.locations!.isEmpty) return 0;

    int count = 0;
    for (var loc in landmark.locations!) {
      if (isSubLocationVisited (parentName, loc.name)) {
        count++;
      }
    }
    return count;
  }

  String getCountryNames (List<String> isoA3Codes) {
    if (_countryProvider == null) return isoA3Codes.join (', ');

    return isoA3Codes.map ((code) {
      final matches = _countryProvider!.allCountries.where ((c) => c.isoA3 == code);
      return matches.isNotEmpty ? matches.first.name : code;
    }).join (', ');
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. 메모리 + 로컬 초기화
    _visitedLandmarks = {};
    _visitedSubLocations = {};
    _wishlistedLandmarks = {};
    for (var landmark in _allLandmarks) {
      landmark.visitDates.clear();
      landmark.rating = null;
    }
    await prefs.remove('visited_landmarks');
    await prefs.remove('visited_landmark_sublocations');
    await prefs.remove('wishlisted_landmarks');
    await prefs.remove('landmark_ratings');
    await prefs.remove('landmark_visit_history');

    // 2. Firestore에서 새로 로드
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data.containsKey('landmark_ratings')) {
            await prefs.setString('landmark_ratings', data['landmark_ratings']);
          }
          if (data.containsKey('visited_landmarks')) {
            final List<dynamic> visitedList = data['visited_landmarks'];
            await prefs.setStringList('visited_landmarks', visitedList.cast<String>());
          }
          if (data.containsKey('visited_landmark_sublocations')) {
            final List<dynamic> subLocList = data['visited_landmark_sublocations'];
            await prefs.setStringList('visited_landmark_sublocations', subLocList.cast<String>());
          }
          if (data.containsKey('wishlisted_landmarks')) {
            final List<dynamic> wishList = data['wishlisted_landmarks'];
            await prefs.setStringList('wishlisted_landmarks', wishList.cast<String>());
          }
          if (data.containsKey('landmark_visit_history')) {
            await prefs.setString('landmark_visit_history', data['landmark_visit_history']);
          }
          _loadFromLocal(prefs);
        }
      } catch (e) {
        print('Error reloading landmarks from server: $e');
      }
    }
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveAllUserData();
  }

}