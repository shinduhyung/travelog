// lib/providers/city_provider.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jidoapp/services/statistics_repository.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'package:collection/collection.dart';

// Firebase Packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==============================================================================
// 1. Parser Functions (Run in Background Isolate)
// ==============================================================================

// Parse Continent Info
Map<String, String> _parseContinents(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  return {
    for (var item in parsedJson)
      item['iso_a2'] as String: item['continent'] as String,
  };
}

// Parse Largest Cities Map
Map<String, String> _parseLargestCitiesMap(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  return {
    for (var item in parsedJson)
      item['country'] as String: item['name'] as String,
  };
}

// Parse General City List
List<City> _parseCities(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  return parsedJson.map((json) => City.fromJson(json)).toList();
}

// Parse Tourist Ratio
Map<String, double> _parseTouristRatioJson(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  Map<String, double> ratioMap = {};
  for (var item in parsedJson) {
    String name = item['name'] ?? '';
    double ratio = 0.0;
    if (item['city_tourist_ratio'] != null) {
      ratio = (item['city_tourist_ratio'] as num).toDouble();
    } else if (item['city_tour_ratio'] != null) {
      ratio = (item['city_tour_ratio'] as num).toDouble();
    }
    if (name.isNotEmpty) {
      ratioMap[name] = ratio;
    }
  }
  return ratioMap;
}

// Special Format Parsers
List<City> _parseStationsJson(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  return parsedJson.map((item) {
    final Map<String, dynamic> cityMap = Map<String, dynamic>.from(item);
    cityMap['name'] = item['city'];
    return City.fromJson(cityMap);
  }).toList();
}

List<City> _parseOldestCitiesJson(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  return parsedJson.map((item) {
    final Map<String, dynamic> cityMap = Map<String, dynamic>.from(item);
    cityMap['name'] = item['name'];
    cityMap['age'] = item['age'];
    return City.fromJson(cityMap);
  }).toList();
}

List<City> _parseStudentCitiesJson(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  return parsedJson.map((item) {
    final Map<String, dynamic> cityMap = Map<String, dynamic>.from(item);
    return City.fromJson(cityMap);
  }).toList();
}

// Other Special Parsers
List<City> _parseSafetyJson(String jsonStr) => _parseCities(jsonStr);
List<City> _parseLiveabilityJson(String jsonStr) => _parseCities(jsonStr);
List<City> _parseSurveillanceJson(String jsonStr) => _parseCities(jsonStr);
List<City> _parseSkyscraperJson(String jsonStr) => _parseCities(jsonStr);
List<City> _parsePollutionJson(String jsonStr) => _parseCities(jsonStr);
List<City> _parseHomicideJson(String jsonStr) => _parseCities(jsonStr);
List<City> _parseTrafficJson(String jsonStr) => _parseCities(jsonStr);
List<City> _parseHollywoodJson(String jsonStr) => _parseCities(jsonStr);

List<City> _parseGaWCJson(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  return parsedJson.map((item) {
    final Map<String, dynamic> cityMap = Map<String, dynamic>.from(item);
    // country_iso가 소문자로 저장된 경우 대문자로 정규화 (allCountries.isoA2와 매칭을 위해)
    if (cityMap['country_iso'] is String) {
      cityMap['country_iso'] = (cityMap['country_iso'] as String).toUpperCase();
    }
    return City.fromJson(cityMap);
  }).toList();
}

// Merge cities15000 (Map) and cities (Stats)
List<City> _mergeAndProcessCities(Map<String, dynamic> message) {
  final String cities15000Json = message['cities15000Json'];
  final String citiesJson = message['citiesJson'];
  final Map<String, String> continentMap = Map<String, String>.from(
    message['continentMap'],
  );

  final List<dynamic> statsList = json.decode(citiesJson);
  final Map<String, City> statsMap = {};
  for (var item in statsList) {
    final city = City.fromJson(item);
    statsMap[city.name] = city;
  }

  final List<dynamic> baseList = json.decode(cities15000Json);

  Map<String, List<Map<String, dynamic>>> cityGroups = {};
  for (var item in baseList) {
    String name = item['name'];
    cityGroups.putIfAbsent(name, () => []).add(item);
  }

  List<City> mergedList = [];

  for (String cityName in cityGroups.keys) {
    List<Map<String, dynamic>> group = cityGroups[cityName]!;

    group.sort((a, b) {
      int popA = (a['population'] as num?)?.toInt() ?? 0;
      int popB = (b['population'] as num?)?.toInt() ?? 0;
      return popB.compareTo(popA);
    });

    for (int i = 0; i < group.length; i++) {
      final item = group[i];
      String uniqueName = (group.length > 1 && i > 0)
          ? '$cityName($i)'
          : cityName;

      City? statData;
      if (i == 0) {
        statData = statsMap[cityName];
      }

      if (statData != null) {
        mergedList.add(
          City(
            name: uniqueName,
            country: statData.country,
            countryIsoA2: statData.countryIsoA2,
            continent: statData.continent,
            population:
                (item['population'] as num?)?.toInt() ?? statData.population,
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
            capitalStatus: statData.capitalStatus,
            annualVisitors: statData.annualVisitors,
            avgTemp: statData.avgTemp,
            avgPrecipitation: statData.avgPrecipitation,
            altitude: statData.altitude,
            gdpNominal: statData.gdpNominal,
            gdpPpp: statData.gdpPpp,
            starbucksCount: statData.starbucksCount,
            millionaires: statData.millionaires,
            billionaires: statData.billionaires,
            cityTouristRatio: statData.cityTouristRatio,
            stationsCount: statData.stationsCount,
            studentScore: statData.studentScore,
            safetyScore: statData.safetyScore,
            liveabilityScore: statData.liveabilityScore,
            surveillanceCameraCount: statData.surveillanceCameraCount,
            skyscraperCount: statData.skyscraperCount,
            pollutionScore: statData.pollutionScore,
            homicideRate: statData.homicideRate,
            trafficTimeMinutes: statData.trafficTimeMinutes,
            hollywoodScore: statData.hollywoodScore,
            gawcTier: statData.gawcTier,
          ),
        );
      } else {
        mergedList.add(
          City.fromMapJson(item, continentMap).copyWith(name: uniqueName),
        );
      }
    }
  }

  return mergedList;
}

// ==============================================================================
// 2. CityProvider Class
// ==============================================================================

class CityProvider with ChangeNotifier {
  // Firebase Instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // [DEBUG] 이 인스턴스를 다른 인스턴스와 로그에서 구분하기 위한 식별자.
  // 리마운트 테스트에서 "CityProvider가 몇 번 새로 생성됐는지" 셀 때 유용.
  static int _instanceCounter = 0;
  final int _instanceId = ++_instanceCounter;

  // ── 로딩 상태 ──────────────────────────────────────────────────────────
  // isLoading: 지도/도시 목록/방문기록 등 "핵심" 데이터. 이게 꺼지면 메인 화면 사용 가능.
  // isStatsLoading: 스타벅스/GAWC/할리우드 등 "부가 통계". Top Cities 등 상세 통계
  //                 화면에서만 의미가 있고, 메인 화면 진입을 막지 않는다.
  bool _isLoading = true;
  bool _isStatsLoading = true;
  String? _error;

  List<City> _allCities = [];
  List<City> _customCities = []; // For user added cities

  // Themed Lists
  List<City> _summerOlympicsCities = [];
  List<City> _winterOlympicsCities = [];
  List<City> _nhlCities = [];
  List<City> _nbaCities = [];
  List<City> _mlbCities = [];
  List<City> _nflCities = [];
  List<City> _mlsCities = [];
  List<City> _largestCities = [];

  List<City> _transportationCities = [];
  List<City> _starbucksCities = [];
  List<City> _millionaireCities = [];
  List<City> _stationCities = [];
  List<City> _oldestCities = [];
  List<City> _studentCities = [];
  List<City> _safetyCities = [];
  List<City> _liveabilityCities = [];
  List<City> _surveillanceCities = [];
  List<City> _skyscraperCities = [];
  List<City> _pollutionCities = [];
  List<City> _homicideCities = [];
  List<City> _trafficCities = [];
  List<City> _hollywoodCities = [];
  List<City> _gawcCities = [];

  // Special Stats Lists
  List<City> _instagramCities = [];
  List<City> _capitalsNoAirportCities = [];
  List<City> _allTransitCities = [];
  List<City> _majorFilmFestivalCities = [];
  List<City> _deFactoCapitals = [];
  List<City> _countryNameIdenticalToCapital = [];
  List<City> _capitalsWithCityInName = [];
  List<City> _countryCapitalHighSimilarity = [];
  List<City> _cityStates = [];
  List<City> _formerCapitalRelocations = [];
  List<City> _plannedCapitals = [];
  List<City> _capitalsBelowSeaLevel = [];
  List<City> _capitalsOnMajorRivers = [];
  List<City> _capitalsAbove1000m = [];
  List<City> _capitalsOnTropicOfCancer = [];
  List<City> _capitalsHotDesertClimate = [];
  List<City> _capitalsNoSeasonalSnowfall = [];
  List<City> _capitalsInTwoHemispheres = [];
  List<City> _transcontinentalCities = [];

  Map<String, double> _touristRatioData = {};
  List<Map<String, dynamic>> _financialIndexRawData = [];
  Map<String, String> _largestCitiesOverrideMap = {};

  final Map<String, CityVisitDetail> _visitDetails = {};
  bool _useDefaultCityRankingBarColor = false;
  String? _homeCityName;

  // Stats Variables
  Map<String, int> _cityContinentCounts = {};
  Map<String, int> _capitalContinentCounts = {};
  Map<String, int> _totalCapitalCountsByContinent = {};
  int _totalVisitedCapitals = 0;
  int _totalCapitals = 0;
  int _totalVisitedCount = 0;

  CountryProvider? _countryProvider;

  // Getters
  bool get isLoading => _isLoading;
  bool get isStatsLoading => _isStatsLoading;
  String? get error => _error;
  List<City> get allCities => _allCities;

  List<City> get summerOlympicsCities => _summerOlympicsCities;
  List<City> get winterOlympicsCities => _winterOlympicsCities;
  List<City> get nhlCities => _nhlCities;
  List<City> get nbaCities => _nbaCities;
  List<City> get mlbCities => _mlbCities;
  List<City> get nflCities => _nflCities;
  List<City> get mlsCities => _mlsCities;
  List<City> get largestCities => _largestCities;
  List<City> get transportationCities => _transportationCities;
  List<City> get starbucksCities => _starbucksCities;
  List<City> get millionaireCities => _millionaireCities;
  List<City> get stationCities => _stationCities;
  List<City> get oldestCities => _oldestCities;
  List<City> get studentCities => _studentCities;
  List<City> get safetyCities => _safetyCities;
  List<City> get liveabilityCities => _liveabilityCities;
  List<City> get surveillanceCities => _surveillanceCities;
  List<City> get skyscraperCities => _skyscraperCities;
  List<City> get pollutionCities => _pollutionCities;
  List<City> get homicideCities => _homicideCities;
  List<City> get trafficCities => _trafficCities;
  List<City> get hollywoodCities => _hollywoodCities;
  List<City> get gawcCities => _gawcCities;
  List<City> get instagramCities => _instagramCities;
  List<City> get capitalsNoAirportCities => _capitalsNoAirportCities;
  List<City> get allTransitCities => _allTransitCities;
  List<City> get majorFilmFestivalCities => _majorFilmFestivalCities;
  List<City> get deFactoCapitals => _deFactoCapitals;
  List<City> get countryNameIdenticalToCapital =>
      _countryNameIdenticalToCapital;
  List<City> get capitalsWithCityInName => _capitalsWithCityInName;
  List<City> get countryCapitalHighSimilarity => _countryCapitalHighSimilarity;
  List<City> get cityStates => _cityStates;
  List<City> get formerCapitalRelocations => _formerCapitalRelocations;
  List<City> get plannedCapitals => _plannedCapitals;
  List<City> get capitalsBelowSeaLevel => _capitalsBelowSeaLevel;
  List<City> get capitalsOnMajorRivers => _capitalsOnMajorRivers;
  List<City> get capitalsAbove1000m => _capitalsAbove1000m;
  List<City> get capitalsOnTropicOfCancer => _capitalsOnTropicOfCancer;
  List<City> get capitalsHotDesertClimate => _capitalsHotDesertClimate;
  List<City> get capitalsNoSeasonalSnowfall => _capitalsNoSeasonalSnowfall;
  List<City> get capitalsInTwoHemispheres => _capitalsInTwoHemispheres;
  List<City> get transcontinentalCities => _transcontinentalCities;

  List<Map<String, dynamic>> get financialIndexRawData =>
      _financialIndexRawData;

  Set<String> get visitedCities => _visitDetails.keys.toSet();
  Map<String, CityVisitDetail> get visitDetails => _visitDetails;
  bool get useDefaultCityRankingBarColor => _useDefaultCityRankingBarColor;
  String? get homeCityName => _homeCityName;

  bool getCityHomeStatus(String cityName) => _homeCityName == cityName;

  bool isVisited(String cityName) {
    final detail = _visitDetails[cityName];
    return detail != null && detail.visitDateRanges.isNotEmpty;
  }

  Map<String, int> get cityContinentCounts => _cityContinentCounts;
  Map<String, int> get capitalContinentCounts => _capitalContinentCounts;
  Map<String, int> get totalCapitalCountsByContinent =>
      _totalCapitalCountsByContinent;
  int get totalVisitedCapitals => _totalVisitedCapitals;
  int get totalCapitals => _totalCapitals;
  int get totalVisitedCount => _visitDetails.keys.length;

  CityProvider() {
    // [DEBUG] 언제, 어떤 유저 기준으로 이 인스턴스가 생성됐는지 추적.
    // 기존 계정으로 로그인(reload) 시 이 로그가 "새로" 한 번 더 찍혀야
    // 리마운트가 실제로 동작한 것. 계정 전환 테스트에서는 이 인스턴스ID가
    // 바뀌면서 uid도 기대한 계정으로 바뀌는지가 핵심 확인 포인트.
    debugPrint(
      '🆕 [CityProvider#$_instanceId] constructed (currentUser=${_auth.currentUser?.uid})',
    );
    _initializeData();
  }

  String _getOriginalCityName(String cityName) {
    return cityName.replaceFirst(RegExp(r'\(\d+\)$'), '');
  }

  void updateCountryProvider(CountryProvider countryProvider) {
    _countryProvider = countryProvider;
    // When CountryProvider is updated, sync city country names
    _syncCityCountryNames();
    _calculateCitiesMenuStats();
  }

  // Method to sync country names in cities based on CountryProvider settings (Handling Merged Territories)
  void _syncCityCountryNames() {
    if (_countryProvider == null) return;

    final isoA2ToA3 = _countryProvider!.isoA2ToIsoA3Map;
    final territoryMap = _countryProvider!.territoryToSovereignMap;
    final isoA3ToName = _countryProvider!.isoToCountryNameMap;
    final bool includeTerritories = _countryProvider!.includeTerritories;

    bool hasChanges = false;

    for (int i = 0; i < _allCities.length; i++) {
      final city = _allCities[i];

      // Skip invalid ISO codes
      if (city.countryIsoA2.isEmpty || city.countryIsoA2 == 'N/A') continue;

      String targetCountryName = city.country;

      // 1. Convert City's ISO A2 to ISO A3
      final String? cityIsoA3 = isoA2ToA3[city.countryIsoA2.toUpperCase()];

      if (cityIsoA3 != null) {
        // 2. Determine the final ISO A3 (Merge territory if needed)
        String finalIsoA3 = cityIsoA3;

        if (!includeTerritories && territoryMap.containsKey(cityIsoA3)) {
          // If merging is ON and this is a territory, use the Sovereign's ISO
          finalIsoA3 = territoryMap[cityIsoA3]!;
        }

        // 3. Get the Country Name associated with the Final ISO A3
        if (isoA3ToName.containsKey(finalIsoA3)) {
          targetCountryName = isoA3ToName[finalIsoA3]!;
        }
      }

      // 4. Update the city if the country name has changed
      if (city.country != targetCountryName) {
        _allCities[i] = city.copyWith(country: targetCountryName);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  String getLargestCityName(String countryName) {
    return _largestCitiesOverrideMap[countryName] ?? '';
  }

  Future<String> _loadJsonFromStorage(String fileName) async {
    final url =
        'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/json%2F$fileName?alt=media';
    try {
      // 오프라인 상태일 때 무한 대기하지 않도록 timeout 설정
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      print(
        '[CityProvider] Network error or timeout loading $fileName: $e. Falling back to local asset.',
      );
    }
    // 실패 시(오프라인, 타임아웃, statusCode 오류 등) 로컬 fallback
    return await StatisticsRepository.instance.loadLegacyString('assets/$fileName');
  }

  // cities15000.json은 매번 네트워크로 받으면 로딩이 느려지므로,
  // 로컬 캐시가 있으면 그걸로 즉시 진행하고, 최신본은 백그라운드에서
  // 조용히 받아서 "다음 실행부터" 반영되게 한다.
  static const String _cities15000CacheKey = 'cached_cities15000_json';

  Future<String> _loadCities15000WithCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cities15000CacheKey);

    if (cached != null && cached.isNotEmpty) {
      // 캐시로 즉시 진행하고, 최신본은 백그라운드에서 갱신 (fire-and-forget)
      _loadJsonFromStorage('cities15000.json')
          .then((fresh) {
            if (fresh.isNotEmpty) {
              prefs.setString(_cities15000CacheKey, fresh);
            }
          })
          .catchError((e) {
            print('[CityProvider] Background cities15000 refresh failed: $e');
          });
      return cached;
    }

    // 캐시가 없는 최초 실행에서만 어쩔 수 없이 기다린다.
    final fresh = await _loadJsonFromStorage('cities15000.json');
    if (fresh.isNotEmpty) {
      // ignore: unawaited_futures
      prefs.setString(_cities15000CacheKey, fresh);
    }
    return fresh;
  }

  // ===========================================================================
  // Initialization Logic
  // ===========================================================================

  Future<void> _initializeData() async {
    // [DEBUG] 이 provider 인스턴스 기준으로 초기화 시작을 기록. 여러 개의
    // CityProvider가 겹쳐서 존재할 수 있는 리마운트 전환 구간에서, 로그의
    // 인스턴스ID로 "어느 인스턴스가 초기화를 시작/완료했는지" 구분 가능.
    final stopwatch = Stopwatch()..start();
    debugPrint(
      '▶️ [CityProvider#$_instanceId] _initializeData START (user=${_auth.currentUser?.uid})',
    );
    try {
      // 1. 핵심 데이터 로드 (지도용 기본 도시 목록) — 최대한 병렬로
      final continentFuture = StatisticsRepository.instance.loadLegacyString('assets/continent.json')
          .then((s) => compute(_parseContinents, s));
      final citiesJsonFuture = StatisticsRepository.instance.loadLegacyString('assets/cities.json');
      final cities15000Future = _loadCities15000WithCache();

      final Map<String, String> countryToContinentMap = await continentFuture;
      final String citiesJsonStr = await citiesJsonFuture;
      final String cities15000JsonStr = await cities15000Future;

      _allCities = await compute(_mergeAndProcessCities, {
        'cities15000Json': cities15000JsonStr,
        'citiesJson': citiesJsonStr,
        'continentMap': countryToContinentMap,
      });

      // 2. 사용자 데이터 로드 — Firestore 문서를 한 번만 조회해서 재사용
      final user = _auth.currentUser;
      Map<String, dynamic>? remoteUserData;
      if (user != null) {
        try {
          final doc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 4));
          if (doc.exists) remoteUserData = doc.data();
        } catch (e) {
          print('[CityProvider] Firestore fetch failed: $e');
        }
      }

      await _loadCustomCities(remoteUserData);
      await _loadVisitDetails(remoteUserData);
      await _loadSettings(remoteUserData);
      await _loadHomeCity(remoteUserData);

      if (_countryProvider != null) {
        _syncCityCountryNames();
      }

      _calculateCitiesMenuStats();

      // ✅ 핵심 데이터(지도, 방문기록)가 준비됐으니 여기서 먼저 화면을 풀어준다.
      _isLoading = false;
      notifyListeners();
      // [DEBUG] 핵심 데이터(방문기록 포함) 준비 완료 시점 — 화면에 실제로
      // 데이터가 뜨는 시점과 거의 일치. 계정 전환 테스트에서 "이 시점의
      // visitedCities 개수"를 같이 로그로 남겨두면 어느 계정 데이터가
      // 실제로 반영됐는지 바로 확인 가능.
      debugPrint(
        '✅ [CityProvider#$_instanceId] core data ready (user=${_auth.currentUser?.uid}, '
        'visitedCities=${_visitDetails.length}, elapsedMs=${stopwatch.elapsedMilliseconds})',
      );

      // 3. 부가 통계 데이터 — 메인 화면 사용을 막지 않고 백그라운드로 이어서 로드
      await _loadThemeData(countryToContinentMap);
      await _loadSpecialStats();

      final String touristRatioJsonStr = await StatisticsRepository.instance.loadLegacyString(
        'assets/city_tourist_ratio.json',
      );
      _touristRatioData = await compute(
        _parseTouristRatioJson,
        touristRatioJsonStr,
      );
      _applyTouristRatioToAllLists();

      final String financialIndexJsonStr = await StatisticsRepository.instance.loadLegacyString(
        'assets/financial_index.json',
      );
      _financialIndexRawData =
          (json.decode(financialIndexJsonStr) as List<dynamic>)
              .map((item) => item as Map<String, dynamic>)
              .toList();

      _isStatsLoading = false;
      notifyListeners();
      debugPrint(
        '🏁 [CityProvider#$_instanceId] _initializeData DONE (user=${_auth.currentUser?.uid}, '
        'elapsedMs=${stopwatch.elapsedMilliseconds})',
      );
    } catch (e, stackTrace) {
      _error = 'Failed to load city data: $e';
      print('[CityProvider] FATAL ERROR: $_error\n$stackTrace');
      debugPrint(
        '💥 [CityProvider#$_instanceId] _initializeData FAILED (user=${_auth.currentUser?.uid}, elapsedMs=${stopwatch.elapsedMilliseconds})',
      );
      _isLoading = false;
      _isStatsLoading = false;
      notifyListeners();
    }
  }

  // --- Special Stats (Instagram, Transportation, etc.) ---
  Future<void> _loadSpecialStats() async {
    try {
      final String statsJsonStr = await StatisticsRepository.instance.loadLegacyString(
        'assets/city_stats.json',
      );
      final Map<String, dynamic> statsJson = json.decode(statsJsonStr);

      _instagramCities = _matchCitiesFromStats(
        statsJson['top_cities_instagram'],
      );
      _majorFilmFestivalCities = _matchCitiesFromStats(
        statsJson['major_film_festival_cities'],
      );
      _deFactoCapitals = _matchCitiesFromStats(statsJson['de_facto_capitals']);
      _countryNameIdenticalToCapital = _matchCitiesFromStats(
        statsJson['country_name_identical_to_capital'],
      );
      _capitalsWithCityInName = _matchCitiesFromStats(
        statsJson['capitals_with_city_in_name'],
      );
      _countryCapitalHighSimilarity = _matchCitiesFromStats(
        statsJson['country_capital_high_similarity'],
      );
      _cityStates = _matchCitiesFromStats(statsJson['city_states']);

      // Handle former capital relocations specially (using 'old_city')
      if (statsJson['former_capital_relocations'] != null) {
        List<dynamic> rawList = statsJson['former_capital_relocations'];
        // Remap to match _matchCitiesFromStats expectation
        List<Map<String, dynamic>> mappedList = rawList.map((item) {
          return {'city': item['old_city'], 'iso2': item['iso2']};
        }).toList();
        _formerCapitalRelocations = _matchCitiesFromStats(mappedList);
      }

      _plannedCapitals = _matchCitiesFromStats(statsJson['planned_capitals']);
      _capitalsNoAirportCities = _matchCitiesFromStats(
        statsJson['capitals_without_international_airport'],
      );
      _allTransitCities = _matchCitiesFromStats(
        statsJson['cities_all_urban_transit_modes'],
      );
      _capitalsBelowSeaLevel = _matchCitiesFromStats(
        statsJson['capitals_below_sea_level'],
      );
      _capitalsOnMajorRivers = _matchCitiesFromStats(
        statsJson['capitals_on_major_rivers'],
      );
      _capitalsAbove1000m = _matchCitiesFromStats(
        statsJson['capitals_above_1000m'],
      );
      _capitalsOnTropicOfCancer = _matchCitiesFromStats(
        statsJson['capitals_on_tropic_of_cancer'],
      );
      _capitalsHotDesertClimate = _matchCitiesFromStats(
        statsJson['capitals_hot_desert_climate'],
      );
      _capitalsNoSeasonalSnowfall = _matchCitiesFromStats(
        statsJson['capitals_no_seasonal_snowfall'],
      );
      _capitalsInTwoHemispheres = _matchCitiesFromStats(
        statsJson['capitals_in_two_hemispheres'],
      );
      _transcontinentalCities = _matchCitiesFromStats(
        statsJson['transcontinental_cities'],
      );
    } catch (e) {
      print('[CityProvider] Error loading city_stats.json: $e');
    }
  }

  // Helper method to match stats JSON with existing City objects
  List<City> _matchCitiesFromStats(dynamic jsonList) {
    if (jsonList == null || jsonList is! List) return [];
    List<City> matched = [];

    for (var item in jsonList) {
      final String name = item['city'] ?? '';
      final String iso = item['iso2'] ?? '';

      final city = _allCities.firstWhereOrNull(
        (c) =>
            c.name.toLowerCase() == name.toLowerCase() &&
            c.countryIsoA2.toLowerCase() == iso.toLowerCase(),
      );

      if (city != null) {
        matched.add(city);
      }
    }
    return matched;
  }

  Future<void> _loadThemeData(Map<String, String> continentMap) async {
    // 22개 theme 리스트를 병렬로 로드 (순차 await → Future.wait)
    final results = await Future.wait([
      _loadList('assets/summer_olympics_cities.json', _parseCities), // 0
      _loadList('assets/winter_olympics_cities.json', _parseCities), // 1
      _loadList('assets/nhl_cities.json', _parseCities), // 2
      _loadList('assets/nba_cities.json', _parseCities), // 3
      _loadList('assets/mlb_cities.json', _parseCities), // 4
      _loadList('assets/nfl_cities.json', _parseCities), // 5
      _loadList('assets/mls_cities.json', _parseCities), // 6
      _loadList('assets/starbucks.json', _parseCities), // 7
      _loadList('assets/millionaire.json', _parseCities), // 8
      _loadList('assets/transportation.json', _parseCities), // 9
      _loadList('assets/stations.json', _parseStationsJson), // 10
      _loadList('assets/oldest.json', _parseOldestCitiesJson), // 11
      _loadList('assets/student.json', _parseStudentCitiesJson), // 12
      _loadList('assets/safety.json', _parseSafetyJson), // 13
      _loadList('assets/liveability.json', _parseLiveabilityJson), // 14
      _loadList('assets/surveillance.json', _parseSurveillanceJson), // 15
      _loadList('assets/skyscraper.json', _parseSkyscraperJson), // 16
      _loadList('assets/pollution.json', _parsePollutionJson), // 17
      _loadList('assets/city_homicide_rate.json', _parseHomicideJson), // 18
      _loadList('assets/traffic.json', _parseTrafficJson), // 19
      _loadList('assets/hollywood.json', _parseHollywoodJson), // 20
      _loadList('assets/gawc.json', _parseGaWCJson), // 21
    ]);

    _summerOlympicsCities = results[0];
    _winterOlympicsCities = results[1];
    _nhlCities = results[2];
    _nbaCities = results[3];
    _mlbCities = results[4];
    _nflCities = results[5];
    _mlsCities = results[6];
    _starbucksCities = results[7];
    _millionaireCities = results[8];
    _transportationCities = results[9];
    _stationCities = results[10];
    _oldestCities = results[11];
    _studentCities = results[12];
    _safetyCities = results[13];
    _liveabilityCities = results[14];
    _surveillanceCities = results[15];
    _skyscraperCities = results[16];
    _pollutionCities = results[17];
    _homicideCities = results[18];
    _trafficCities = results[19];
    _hollywoodCities = results[20];
    _gawcCities = results[21];

    // largest는 같은 파일을 두 parser로 쓰므로 한 번만 로드 후 병렬 parse
    final String largestJsonStr = await StatisticsRepository.instance.loadLegacyString(
      'assets/largest.json',
    );
    final largestResults = await Future.wait([
      compute(_parseCities, largestJsonStr),
      compute(_parseLargestCitiesMap, largestJsonStr),
    ]);
    _largestCities = largestResults[0] as List<City>;
    _largestCitiesOverrideMap = largestResults[1] as Map<String, String>;
  }

  Future<List<City>> _loadList(
    String path,
    List<City> Function(String) parser,
  ) async {
    try {
      final String jsonStr = await StatisticsRepository.instance.loadLegacyString(path);
      return await compute(parser, jsonStr);
    } catch (e) {
      print('[CityProvider] Error loading $path: $e');
      return [];
    }
  }

  void _applyTouristRatioToAllLists() {
    _mergeTouristRatioData(_allCities);
    _mergeTouristRatioData(_summerOlympicsCities);
    _mergeTouristRatioData(_winterOlympicsCities);
    _mergeTouristRatioData(_nhlCities);
    _mergeTouristRatioData(_nbaCities);
    _mergeTouristRatioData(_mlbCities);
    _mergeTouristRatioData(_nflCities);
    _mergeTouristRatioData(_mlsCities);
    _mergeTouristRatioData(_largestCities);
    _mergeTouristRatioData(_millionaireCities);
    _mergeTouristRatioData(_starbucksCities);
    _mergeTouristRatioData(_stationCities);
    _mergeTouristRatioData(_studentCities);
    _mergeTouristRatioData(_safetyCities);
    _mergeTouristRatioData(_liveabilityCities);
    _mergeTouristRatioData(_surveillanceCities);
    _mergeTouristRatioData(_skyscraperCities);
    _mergeTouristRatioData(_pollutionCities);
    _mergeTouristRatioData(_homicideCities);
    _mergeTouristRatioData(_trafficCities);
    _mergeTouristRatioData(_hollywoodCities);
    _mergeTouristRatioData(_gawcCities);
    _mergeTouristRatioData(_instagramCities);
    _mergeTouristRatioData(_capitalsNoAirportCities);
    _mergeTouristRatioData(_allTransitCities);
    _mergeTouristRatioData(_majorFilmFestivalCities);
    _mergeTouristRatioData(_deFactoCapitals);
    _mergeTouristRatioData(_countryNameIdenticalToCapital);
    _mergeTouristRatioData(_capitalsWithCityInName);
    _mergeTouristRatioData(_countryCapitalHighSimilarity);
    _mergeTouristRatioData(_cityStates);
    _mergeTouristRatioData(_formerCapitalRelocations);
    _mergeTouristRatioData(_plannedCapitals);
    _mergeTouristRatioData(_capitalsBelowSeaLevel);
    _mergeTouristRatioData(_capitalsOnMajorRivers);
    _mergeTouristRatioData(_capitalsAbove1000m);
    _mergeTouristRatioData(_capitalsOnTropicOfCancer);
    _mergeTouristRatioData(_capitalsHotDesertClimate);
    _mergeTouristRatioData(_capitalsNoSeasonalSnowfall);
    _mergeTouristRatioData(_capitalsInTwoHemispheres);
    _mergeTouristRatioData(_transcontinentalCities);
  }

  void _mergeTouristRatioData(List<City> cities) {
    for (int i = 0; i < cities.length; i++) {
      final originalCity = cities[i];
      final originalName = _getOriginalCityName(originalCity.name);
      if (_touristRatioData.containsKey(originalName)) {
        cities[i] = originalCity.copyWith(
          cityTouristRatio:
              _touristRatioData[originalName] ?? originalCity.cityTouristRatio,
        );
      }
    }
  }

  void _calculateCitiesMenuStats() {
    const List<String> continentFullNames = [
      'Asia',
      'Europe',
      'Africa',
      'North America',
      'South America',
      'Oceania',
    ];

    _cityContinentCounts = {for (var name in continentFullNames) name: 0};
    _capitalContinentCounts = {for (var name in continentFullNames) name: 0};
    _totalCapitalCountsByContinent = {
      for (var name in continentFullNames) name: 0,
    };
    _totalVisitedCapitals = 0;
    _totalCapitals = 0;
    _totalVisitedCount = _visitDetails.keys.length;

    final bool includeTerritories =
        _countryProvider?.includeTerritories ?? false;

    for (var city in _allCities) {
      bool isCapital =
          (city.capitalStatus == CapitalStatus.capital) ||
          (city.capitalStatus == CapitalStatus.territory && includeTerritories);

      if (isCapital) {
        _totalCapitals++;
        if (continentFullNames.contains(city.continent)) {
          _totalCapitalCountsByContinent.update(
            city.continent,
            (v) => v + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    for (var visitedCityName in _visitDetails.keys) {
      City? cityDetail = getCityDetail(visitedCityName);

      if (cityDetail != null) {
        if (continentFullNames.contains(cityDetail.continent)) {
          _cityContinentCounts.update(
            cityDetail.continent,
            (v) => v + 1,
            ifAbsent: () => 1,
          );
        }

        bool isCapital =
            (cityDetail.capitalStatus == CapitalStatus.capital) ||
            (cityDetail.capitalStatus == CapitalStatus.territory &&
                includeTerritories);

        if (isCapital) {
          _totalVisitedCapitals++;
          if (continentFullNames.contains(cityDetail.continent)) {
            _capitalContinentCounts.update(
              cityDetail.continent,
              (v) => v + 1,
              ifAbsent: () => 1,
            );
          }
        }
      }
    }
    notifyListeners();
  }

  String getOriginalCityName(String cityName) {
    return _getOriginalCityName(cityName);
  }

  City? getCityDetail(String cityName) {
    final city = _allCities.firstWhereOrNull((c) => c.name == cityName);
    if (city != null) return city;

    final originalName = _getOriginalCityName(cityName);
    if (originalName != cityName) {
      return _allCities.firstWhereOrNull(
        (c) => _getOriginalCityName(c.name) == originalName,
      );
    }
    return null;
  }

  // ===========================================================================
  // Custom Cities (Firebase Integrated)
  // ===========================================================================

  void addCustomCity(
    String name,
    double latitude,
    double longitude,
    String countryIsoA2,
    String continent,
    int population,
  ) {
    final newCity = City(
      name: name,
      country: 'Unknown',
      countryIsoA2: countryIsoA2,
      continent: continent,
      population: population,
      latitude: latitude,
      longitude: longitude,
      capitalStatus: CapitalStatus.none,
    );

    _customCities.add(newCity);
    _allCities.add(newCity);

    _syncCityCountryNames();
    _saveCustomCities();
    notifyListeners();
  }

  Future<void> _saveCustomCities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = _customCities
          .map(
            (city) => {
              'name': city.name,
              'country_iso': city.countryIsoA2,
              'continent': city.continent,
              'population': city.population,
              'latitude': city.latitude,
              'longitude': city.longitude,
            },
          )
          .toList();

      final String encoded = json.encode(jsonList);
      await prefs.setString('saved_custom_cities', encoded);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'saved_custom_cities': encoded,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('[CityProvider] ERROR saving custom cities: $e');
    }
  }

  // remoteData: _initializeData / reloadFromServer에서 한 번만 조회한
  // users/{uid} 문서 데이터를 넘겨받는다. 이 함수 내부에서 별도로
  // Firestore를 조회하지 않는다 (읽기 횟수 절약 = 로딩 속도).
  Future<void> _loadCustomCities(Map<String, dynamic>? remoteData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('saved_custom_cities');

      if (remoteData != null && remoteData.containsKey('saved_custom_cities')) {
        jsonStr = remoteData['saved_custom_cities'];
      }

      if (jsonStr != null) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        _customCities = jsonList.map((item) {
          return City(
            name: item['name'],
            country: 'Unknown',
            countryIsoA2: item['country_iso'] ?? '',
            continent: item['continent'] ?? '',
            population: item['population'] ?? 0,
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
            capitalStatus: CapitalStatus.none,
          );
        }).toList();

        for (var customCity in _customCities) {
          if (!_allCities.any((c) => c.name == customCity.name)) {
            _allCities.add(customCity);
          }
        }
      }
    } catch (e) {
      print('[CityProvider] ERROR loading custom cities: $e');
    }
  }

  // ===========================================================================
  // User Data & Visit Details (Firebase Integrated)
  // ===========================================================================

  // 방문 기록에 대해 "로컬이 서버보다 최신이면 서버로 덮어쓰지 않는다"는
  // 안전장치. 저장 실패 등으로 서버가 뒤처져 있을 때, 재로그인/재로드
  // 한 번으로 방금 입력한 데이터가 사라지는 사고를 막기 위한 최소한의 보호.
  static const String _visitDetailsSyncedAtKey = 'city_visit_details_synced_at';

  Future<void> _loadVisitDetails(Map<String, dynamic>? remoteData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? detailsString = prefs.getString('city_visit_details_v3');
      final int localSyncedAtMs = prefs.getInt(_visitDetailsSyncedAtKey) ?? 0;

      if (remoteData != null &&
          remoteData.containsKey('city_visit_details_v3')) {
        final dynamic rawTimestamp = remoteData['lastUpdated'];
        final int remoteMs = (rawTimestamp is Timestamp)
            ? rawTimestamp.millisecondsSinceEpoch
            : 0;

        // 서버가 로컬보다 최신이거나, 로컬에 동기화 시각 기록이 아예 없는
        // 경우(예: 이 기기에서 처음 로그인)에만 서버 값으로 반영한다.
        if (remoteMs >= localSyncedAtMs) {
          detailsString = remoteData['city_visit_details_v3'];
          await prefs.setString('city_visit_details_v3', detailsString!);
          await prefs.setInt(_visitDetailsSyncedAtKey, remoteMs);
        } else {
          print(
            '[CityProvider] Local visit details are newer than server — keeping local copy.',
          );
        }
      }

      if (detailsString != null) {
        final Map<String, dynamic> decodedMap = json.decode(detailsString);
        _visitDetails.clear();
        decodedMap.forEach((key, value) {
          try {
            _visitDetails[key] = CityVisitDetail.fromJson(value);
          } catch (e) {
            print('[CityProvider] Error parsing visit detail: $key');
          }
        });
      }
    } catch (e) {
      print('[CityProvider] FATAL ERROR loading visit details: $e');
    }
    notifyListeners();
  }

  Future<void> _saveVisitDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedMap = json.encode(
        _visitDetails.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString('city_visit_details_v3', encodedMap);
      // 로컬에 저장한 시각을 기록 — 다음 로드 시 서버와 비교해서
      // "누가 더 최신인지" 판단하는 기준이 된다.
      await prefs.setInt(
        _visitDetailsSyncedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      final user = _auth.currentUser;
      if (user != null) {
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'city_visit_details_v3': encodedMap,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          // [DEBUG] 어느 계정 문서에 방문 기록이 실제로 저장됐는지 추적.
          // "다른 계정으로 전환했는데 이전 계정 데이터가 새 계정 문서에
          // 저장되는지"를 검증할 때 이 로그가 핵심 증거가 된다.
          debugPrint(
            '💾 [CityProvider#$_instanceId] visit details SAVED to Firestore '
            '(uid=${user.uid}, cityCount=${_visitDetails.length})',
          );
        } catch (e) {
          print('[CityProvider] Failed to save visit details to server: $e');
        }
      }
    } catch (e) {
      print('[CityProvider] Error saving visit details: $e');
    }
  }

  Future<void> saveVisitDetails() async {
    await _saveVisitDetails();
  }

  // ===========================================================================
  // Settings & Home City (Firebase Integrated)
  // ===========================================================================

  Future<void> _loadSettings(Map<String, dynamic>? remoteData) async {
    final prefs = await SharedPreferences.getInstance();
    _useDefaultCityRankingBarColor =
        prefs.getBool('useDefaultCityRankingBarColor') ?? false;

    if (remoteData != null &&
        remoteData.containsKey('useDefaultCityRankingBarColor')) {
      _useDefaultCityRankingBarColor =
          remoteData['useDefaultCityRankingBarColor'];
      await prefs.setBool(
        'useDefaultCityRankingBarColor',
        _useDefaultCityRankingBarColor,
      );
    }
  }

  Future<void> _loadHomeCity(Map<String, dynamic>? remoteData) async {
    final prefs = await SharedPreferences.getInstance();
    _homeCityName = prefs.getString('homeCityName');

    if (remoteData != null && remoteData.containsKey('homeCityName')) {
      _homeCityName = remoteData['homeCityName'];
      if (_homeCityName != null) {
        await prefs.setString('homeCityName', _homeCityName!);
      } else {
        await prefs.remove('homeCityName');
      }
    }
  }

  void setUseDefaultCityRankingBarColor(bool value) async {
    _useDefaultCityRankingBarColor = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useDefaultCityRankingBarColor', value);

    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).set({
        'useDefaultCityRankingBarColor': value,
      }, SetOptions(merge: true));
    }
    notifyListeners();
  }

  void setCityHomeStatus(String cityName, bool isHome) async {
    if (_homeCityName != null && _visitDetails.containsKey(_homeCityName)) {
      _visitDetails[_homeCityName!] = _visitDetails[_homeCityName!]!.copyWith(
        isHome: false,
      );
    }

    if (isHome) {
      if (!_visitDetails.containsKey(cityName)) {
        _visitDetails[cityName] = CityVisitDetail(
          name: cityName,
          isHome: true,
          hasLived: true,
        );
      } else {
        _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(
          isHome: true,
          hasLived: true,
        );
      }
      _homeCityName = cityName;
    } else {
      _homeCityName = null;
      if (_visitDetails.containsKey(cityName)) {
        _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(
          isHome: false,
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    if (_homeCityName == null) {
      await prefs.remove('homeCityName');
    } else {
      await prefs.setString('homeCityName', _homeCityName!);
    }

    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).set({
        'homeCityName': _homeCityName,
      }, SetOptions(merge: true));
    }

    await _saveVisitDetails();
    notifyListeners();
  }

  // ===========================================================================
  // Operations
  // ===========================================================================

  void toggleVisitedStatus(String cityName) {
    final isCurrentlyVisited = isVisited(cityName);
    setVisitedStatus(cityName, !isCurrentlyVisited);
  }

  void toggleCityWishlistStatus(String cityName) async {
    if (!_visitDetails.containsKey(cityName)) {
      _visitDetails[cityName] = CityVisitDetail(
        name: cityName,
        isWishlisted: true,
      );
    } else {
      final detail = _visitDetails[cityName]!;
      _visitDetails[cityName] = detail.copyWith(
        isWishlisted: !detail.isWishlisted,
      );
      final updatedDetail = _visitDetails[cityName]!;

      if (!updatedDetail.hasLived &&
          updatedDetail.visitDateRanges.isEmpty &&
          !updatedDetail.isWishlisted &&
          updatedDetail.rating == 0.0) {
        _visitDetails.remove(cityName);
      }
    }
    await _saveVisitDetails();
    notifyListeners();
  }

  void setVisitedStatus(String cityName, bool isVisited) async {
    if (isVisited) {
      if (!_visitDetails.containsKey(cityName) ||
          _visitDetails[cityName]!.visitDateRanges.isEmpty) {
        _visitDetails[cityName] =
            (_visitDetails[cityName] ?? CityVisitDetail(name: cityName))
                .copyWith(visitDateRanges: [DateRange()]);
      }
    } else {
      final detail = _visitDetails[cityName];
      if (detail != null) {
        final updatedDetail = detail.copyWith(visitDateRanges: []);
        if (!updatedDetail.hasLived &&
            !updatedDetail.isWishlisted &&
            updatedDetail.rating == 0.0) {
          _visitDetails.remove(cityName);
        } else {
          _visitDetails[cityName] = updatedDetail;
        }
      }
    }
    await _saveVisitDetails();
    _calculateCitiesMenuStats();
    notifyListeners();
  }

  void clearVisitHistory(String cityName) async {
    if (_visitDetails.containsKey(cityName)) {
      final detail = _visitDetails[cityName]!;
      final updatedDetail = detail.copyWith(visitDateRanges: []);
      if (!updatedDetail.hasLived &&
          !updatedDetail.isWishlisted &&
          updatedDetail.rating == 0.0) {
        _visitDetails.remove(cityName);
      } else {
        _visitDetails[cityName] = updatedDetail;
      }
      await _saveVisitDetails();
      _calculateCitiesMenuStats();
      notifyListeners();
    }
  }

  void updateCityMetrics(
    String cityName, {
    double? rating,
    double? affordability,
    double? safety,
    double? foodQuality,
    double? transport,
    double? englishProficiency,
    double? cleanliness,
    double? attractionDensity,
    double? vibrancy,
    double? accessibility,
  }) async {
    final detail = _visitDetails.putIfAbsent(
      cityName,
      () => CityVisitDetail(name: cityName),
    );

    _visitDetails[cityName] = detail.copyWith(
      rating: rating,
      affordability: affordability,
      safety: safety,
      foodQuality: foodQuality,
      transport: transport,
      englishProficiency: englishProficiency,
      cleanliness: cleanliness,
      attractionDensity: attractionDensity,
      vibrancy: vibrancy,
      accessibility: accessibility,
    );

    await _saveVisitDetails();
    notifyListeners();
  }

  void toggleCityLivedStatus(String cityName) async {
    if (!_visitDetails.containsKey(cityName)) {
      _visitDetails[cityName] = CityVisitDetail(name: cityName, hasLived: true);
    } else {
      final detail = _visitDetails[cityName]!;
      _visitDetails[cityName] = detail.copyWith(hasLived: !detail.hasLived);

      if (!detail.hasLived && detail.isHome) {
        _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(
          isHome: false,
        );
        if (_homeCityName == cityName) {
          _homeCityName = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('homeCityName');

          final user = _auth.currentUser;
          if (user != null) {
            _firestore.collection('users').doc(user.uid).set({
              'homeCityName': null,
            }, SetOptions(merge: true));
          }
        }
      }

      final updatedDetail = _visitDetails[cityName]!;
      if (!updatedDetail.hasLived &&
          updatedDetail.visitDateRanges.isEmpty &&
          !updatedDetail.isWishlisted &&
          updatedDetail.rating == 0.0) {
        _visitDetails.remove(cityName);
      }
    }
    await _saveVisitDetails();
    _calculateCitiesMenuStats();
    notifyListeners();
  }

  void setCityRating(String cityName, double rating) async {
    if (_visitDetails.containsKey(cityName)) {
      _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(
        rating: rating,
      );
      await _saveVisitDetails();
      notifyListeners();
    } else if (rating > 0.0) {
      _visitDetails[cityName] = CityVisitDetail(name: cityName, rating: rating);
      await _saveVisitDetails();
      notifyListeners();
    }
  }

  void addCityDateRange(String cityName) async {
    if (_visitDetails.containsKey(cityName)) {
      final detail = _visitDetails[cityName]!;
      final newRanges = List<DateRange>.from(detail.visitDateRanges)
        ..add(DateRange());
      _visitDetails[cityName] = detail.copyWith(visitDateRanges: newRanges);
    } else {
      _visitDetails[cityName] = CityVisitDetail(
        name: cityName,
        visitDateRanges: [DateRange()],
      );
    }
    await _saveVisitDetails();
    notifyListeners();
  }

  void updateCityDateRange(
    String cityName,
    int index,
    DateRange newRange,
  ) async {
    if (_visitDetails.containsKey(cityName)) {
      final detail = _visitDetails[cityName]!;
      if (index >= 0 && index < detail.visitDateRanges.length) {
        final newRanges = List<DateRange>.from(detail.visitDateRanges);
        newRanges[index] = newRange;
        _visitDetails[cityName] = detail.copyWith(visitDateRanges: newRanges);
        await _saveVisitDetails();
        notifyListeners();
      }
    }
  }

  void removeCityDateRange(String cityName, int index) async {
    if (_visitDetails.containsKey(cityName)) {
      final detail = _visitDetails[cityName]!;
      if (index >= 0 && index < detail.visitDateRanges.length) {
        final newRanges = List<DateRange>.from(detail.visitDateRanges)
          ..removeAt(index);

        if (newRanges.isEmpty &&
            !detail.hasLived &&
            !detail.isWishlisted &&
            detail.rating == 0.0) {
          _visitDetails.remove(cityName);
        } else {
          _visitDetails[cityName] = detail.copyWith(visitDateRanges: newRanges);
        }
        await _saveVisitDetails();
        notifyListeners();
      }
    }
  }

  void updateCityMemoAndPhotos(
    String cityName,
    String memo,
    List<String> photos,
  ) async {
    if (_visitDetails.containsKey(cityName)) {
      _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(
        memo: memo,
        photos: photos,
      );
    } else {
      _visitDetails[cityName] = CityVisitDetail(
        name: cityName,
        memo: memo,
        photos: photos,
      );
    }
    await _saveVisitDetails();
    notifyListeners();
  }

  Future<void> addVisitWithDetails(
    String cityName, {
    DateTime? arrival,
    DateTime? departure,
    int? userDefinedDuration,
  }) async {
    final detail = _visitDetails[cityName] ?? CityVisitDetail(name: cityName);
    final newRange = DateRange(
      arrival: arrival,
      departure: departure,
      userDefinedDuration: userDefinedDuration,
      isDurationUnknown:
          userDefinedDuration == null && (arrival == null || departure == null),
    );
    final updatedRanges = List<DateRange>.from(detail.visitDateRanges)
      ..add(newRange);
    _visitDetails[cityName] = detail.copyWith(visitDateRanges: updatedRanges);
    await _saveVisitDetails();
    _calculateCitiesMenuStats();
    notifyListeners();
  }

  void updateCityVisitDetail(String cityName, CityVisitDetail newDetail) async {
    _visitDetails[cityName] = newDetail;
    await _saveVisitDetails();
    notifyListeners();
  }

  CityVisitDetail? getCityVisitDetail(String cityName) {
    return _visitDetails[cityName];
  }

  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    // [DEBUG] main.dart의 리마운트 로직으로 이 함수는 이제 정상 흐름에서는
    // 호출되지 않아야 한다(대신 새 CityProvider 인스턴스가 생성됨). 만약
    // 이 로그가 찍힌다면 어딘가에서 여전히 구 경로로 reloadFromServer()를
    // 직접 부르고 있다는 뜻이므로 호출부를 찾아봐야 한다.
    debugPrint(
      '⚠️ [CityProvider#$_instanceId] reloadFromServer() called directly — '
      'expected path is now remount via main.dart, verify caller (user=${_auth.currentUser?.uid})',
    );
    final user = _auth.currentUser;
    Map<String, dynamic>? remoteData;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) remoteData = doc.data();
      } catch (e) {
        print('[CityProvider] reloadFromServer fetch failed: $e');
      }
    }

    await _loadVisitDetails(remoteData);
    await _loadSettings(remoteData);
    await _loadHomeCity(remoteData);
    await _loadCustomCities(remoteData);
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveVisitDetails();
    await _saveCustomCities();
    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).set({
        'useDefaultCityRankingBarColor': _useDefaultCityRankingBarColor,
        'homeCityName': _homeCityName,
      }, SetOptions(merge: true));
    }
  }
}

// Helper: CopyWith Extension
extension CityCopyWith on City {
  City copyWith({String? name, String? country, double? cityTouristRatio}) {
    return City(
      name: name ?? this.name,
      country: country ?? this.country,
      countryIsoA2: countryIsoA2,
      continent: continent,
      population: population,
      latitude: latitude,
      longitude: longitude,
      capitalStatus: capitalStatus,
      annualVisitors: annualVisitors,
      avgTemp: avgTemp,
      avgPrecipitation: avgPrecipitation,
      altitude: altitude,
      gdpNominal: gdpNominal,
      gdpPpp: gdpPpp,
      starbucksCount: starbucksCount,
      millionaires: millionaires,
      billionaires: billionaires,
      cityTouristRatio: cityTouristRatio ?? this.cityTouristRatio,
      stationsCount: stationsCount,
      studentScore: studentScore,
      safetyScore: safetyScore,
      liveabilityScore: liveabilityScore,
      surveillanceCameraCount: surveillanceCameraCount,
      skyscraperCount: skyscraperCount,
      pollutionScore: pollutionScore,
      homicideRate: homicideRate,
      trafficTimeMinutes: trafficTimeMinutes,
      hollywoodScore: hollywoodScore,
      gawcTier: gawcTier,
    );
  }
}
