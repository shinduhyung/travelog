// lib/providers/city_provider.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
      item['iso_a2'] as String: item['continent'] as String
  };
}

// Parse Largest Cities Map
Map<String, String> _parseLargestCitiesMap(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  return {
    for (var item in parsedJson)
      item['country'] as String: item['name'] as String
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
  final Map<String, String> continentMap = Map<String, String>.from(message['continentMap']);

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
      String uniqueName = (group.length > 1 && i > 0) ? '$cityName($i)' : cityName;

      City? statData;
      if (i == 0) {
        statData = statsMap[cityName];
      }

      if (statData != null) {
        mergedList.add(City(
          name: uniqueName,
          country: statData.country,
          countryIsoA2: statData.countryIsoA2,
          continent: statData.continent,
          population: (item['population'] as num?)?.toInt() ?? statData.population,
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
        ));
      } else {
        mergedList.add(City.fromMapJson(item, continentMap).copyWith(name: uniqueName));
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

  bool _isLoading = true;
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
  List<City> get countryNameIdenticalToCapital => _countryNameIdenticalToCapital;
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

  List<Map<String, dynamic>> get financialIndexRawData => _financialIndexRawData;

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
  Map<String, int> get totalCapitalCountsByContinent => _totalCapitalCountsByContinent;
  int get totalVisitedCapitals => _totalVisitedCapitals;
  int get totalCapitals => _totalCapitals;
  int get totalVisitedCount => _visitDetails.keys.length;

  CityProvider() {
    print('🔥🔥🔥 [CityProvider] Constructor called. Initializing...');
    _initializeData();
  }

  String _getOriginalCityName(String cityName) {
    return cityName.replaceFirst(RegExp(r'\(\d+\)$'), '');
  }

  void updateCountryProvider(CountryProvider countryProvider) {
    _countryProvider = countryProvider;
    // When CountryProvider is updated, sync city country names
    _syncCityCountryNames();
    _calculateCitiesMenuStats({});
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
      print('🔥🔥🔥 [CityProvider] Synced city country names (Merged: ${!includeTerritories})');
      notifyListeners();
    }
  }

  String getLargestCityName(String countryName) {
    return _largestCitiesOverrideMap[countryName] ?? '';
  }

  Future<String> _loadJsonFromStorage(String fileName) async {
    final url = 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/json%2F$fileName?alt=media';
    try {
      // 오프라인 상태일 때 무한 대기하지 않도록 timeout 설정
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      print('🔥 [CityProvider] Network error or timeout loading $fileName: $e. Falling back to local asset.');
    }
    // 실패 시(오프라인, 타임아웃, statusCode 오류 등) 로컬 fallback
    return await rootBundle.loadString('assets/$fileName');
  }

  // ===========================================================================
  // Initialization Logic
  // ===========================================================================

  Future<void> _initializeData() async {
    print('🔥🔥🔥 [CityProvider] Starting _initializeData...');
    try {
      // 1. Essential Data Load (Map & Basic Cities) - JSON Parsing
      final String continentJsonStr = await rootBundle.loadString('assets/continent.json');
      final Map<String, String> countryToContinentMap = await compute(_parseContinents, continentJsonStr);

      final String cities15000JsonStr = await _loadJsonFromStorage('cities15000.json');
      final String citiesJsonStr = await rootBundle.loadString('assets/cities.json');

      final Map<String, dynamic> message = {
        'cities15000Json': cities15000JsonStr,
        'citiesJson': citiesJsonStr,
        'continentMap': countryToContinentMap,
      };

      _allCities = await compute(_mergeAndProcessCities, message);
      print('🔥🔥🔥 [CityProvider] Merged ${_allCities.length} standard cities.');

      // 2. Custom Cities Load (User added) - Firebase Integrated
      await _loadCustomCities();
      print('🔥🔥🔥 [CityProvider] Custom cities loaded.');

      // 3. Theme Data Load
      await _loadThemeData(countryToContinentMap);

      // 3.1 Special Stats Load (Instagram, Transportation, etc.)
      await _loadSpecialStats();

      // 4. Additional Info 1: Tourist Ratio
      final String touristRatioJsonStr = await rootBundle.loadString('assets/city_tourist_ratio.json');
      _touristRatioData = await compute(_parseTouristRatioJson, touristRatioJsonStr);
      _applyTouristRatioToAllLists();

      // 5. Additional Info 2: Financial Index
      final String financialIndexJsonStr = await rootBundle.loadString('assets/financial_index.json');
      _financialIndexRawData = (json.decode(financialIndexJsonStr) as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();

      // 6. Visit History Load - Firebase Integrated
      await _loadVisitDetails();
      print('🔥🔥🔥 [CityProvider] Visited details loaded: ${_visitDetails.length} cities.');

      // 7. Settings Load - Firebase Integrated
      await _loadSettings();
      await _loadHomeCity();

      // Attempt to sync country names if CountryProvider is already available
      if (_countryProvider != null) {
        _syncCityCountryNames();
      }

      _calculateCitiesMenuStats(countryToContinentMap);

      // --- DEBUG SECTION: CHECK MISSING CITIES FROM USER LIST ---
      final List<String> userCityList = [
        "Kinshasa",
        "Brazzaville",
        "Malmö",
        "Copenhagen",
        "Tallinn",
        "Helsinki",
        "Buenos Aires",
        "Montevideo",
        "Vienna",
        "Bratislava",
        "Singapore",
        "Johor Bahru",
        "Detroit",
        "Windsor",
        "Hong Kong",
        "Macau",
        "San Diego",
        "Tijuana"
      ];

      await debugCheckCityListMissing(userCityList);
      // -----------------------------------------------------------

      print('🔥🔥🔥 [CityProvider] Initialization COMPLETED.');
    } catch (e, stackTrace) {
      _error = 'Failed to load city data: $e';
      print('🔥🔥🔥 [CityProvider] FATAL ERROR: $_error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Special Stats (Instagram, Transportation, etc.) ---
  Future<void> _loadSpecialStats() async {
    try {
      final String statsJsonStr = await rootBundle.loadString('assets/city_stats.json');
      final Map<String, dynamic> statsJson = json.decode(statsJsonStr);

      _instagramCities = _matchCitiesFromStats(statsJson['top_cities_instagram']);
      _majorFilmFestivalCities = _matchCitiesFromStats(statsJson['major_film_festival_cities']);
      _deFactoCapitals = _matchCitiesFromStats(statsJson['de_facto_capitals']);
      _countryNameIdenticalToCapital = _matchCitiesFromStats(statsJson['country_name_identical_to_capital']);
      _capitalsWithCityInName = _matchCitiesFromStats(statsJson['capitals_with_city_in_name']);
      _countryCapitalHighSimilarity = _matchCitiesFromStats(statsJson['country_capital_high_similarity']);
      _cityStates = _matchCitiesFromStats(statsJson['city_states']);

      // Handle former capital relocations specially (using 'old_city')
      if (statsJson['former_capital_relocations'] != null) {
        List<dynamic> rawList = statsJson['former_capital_relocations'];
        // Remap to match _matchCitiesFromStats expectation
        List<Map<String, dynamic>> mappedList = rawList.map((item) {
          return {
            'city': item['old_city'],
            'iso2': item['iso2']
          };
        }).toList();
        _formerCapitalRelocations = _matchCitiesFromStats(mappedList);
      }

      _plannedCapitals = _matchCitiesFromStats(statsJson['planned_capitals']);
      _capitalsNoAirportCities = _matchCitiesFromStats(statsJson['capitals_without_international_airport']);
      _allTransitCities = _matchCitiesFromStats(statsJson['cities_all_urban_transit_modes']);
      _capitalsBelowSeaLevel = _matchCitiesFromStats(statsJson['capitals_below_sea_level']);
      _capitalsOnMajorRivers = _matchCitiesFromStats(statsJson['capitals_on_major_rivers']);
      _capitalsAbove1000m = _matchCitiesFromStats(statsJson['capitals_above_1000m']);
      _capitalsOnTropicOfCancer = _matchCitiesFromStats(statsJson['capitals_on_tropic_of_cancer']);
      _capitalsHotDesertClimate = _matchCitiesFromStats(statsJson['capitals_hot_desert_climate']);
      _capitalsNoSeasonalSnowfall = _matchCitiesFromStats(statsJson['capitals_no_seasonal_snowfall']);
      _capitalsInTwoHemispheres = _matchCitiesFromStats(statsJson['capitals_in_two_hemispheres']);
      _transcontinentalCities = _matchCitiesFromStats(statsJson['transcontinental_cities']);

    } catch (e) {
      print('🔥 [CityProvider] Error loading city_stats.json: $e');
    }
  }

  // Helper method to match stats JSON with existing City objects
  List<City> _matchCitiesFromStats(dynamic jsonList) {
    if (jsonList == null || jsonList is! List) return [];
    List<City> matched = [];

    for (var item in jsonList) {
      final String name = item['city'] ?? '';
      final String iso = item['iso2'] ?? '';

      final city = _allCities.firstWhereOrNull((c) =>
      c.name.toLowerCase() == name.toLowerCase() &&
          c.countryIsoA2.toLowerCase() == iso.toLowerCase()
      );

      if (city != null) {
        matched.add(city);
      }
    }
    return matched;
  }

  // --- DEBUG: Check for major cities missing from map data ---
  Future<void> debugFindMissingMajorCities() async {
    print('🔥 [CityProvider] Checking for missing major cities...');
    try {
      final String infoString = await rootBundle.loadString('assets/country_info.json');
      final Map<String, dynamic> infoJson = json.decode(infoString);

      List<String> missing = [];
      final Set<String> existingCityNames = _allCities
          .map((c) => _getOriginalCityName(c.name).toLowerCase().trim())
          .toSet();

      infoJson.forEach((key, value) {
        if (value is Map && value['majorCities'] is List) {
          final List<dynamic> majorCities = value['majorCities'];
          for (var item in majorCities) {
            if (item is Map && item['name'] != null) {
              String cityName = item['name'].toString();
              String normalizedInfoName = cityName.toLowerCase().trim();

              if (!existingCityNames.contains(normalizedInfoName)) {
                missing.add('$cityName ($key)');
              }
            }
          }
        }
      });

      if (missing.isNotEmpty) {
        print('🔥 [CityProvider] Found ${missing.length} major cities missing from loaded data.');
      }
    } catch (e) {
      print('🔥 [CityProvider] Error checking missing cities: $e');
    }
  }

  // --- DEBUG: Check for stats cities unused due to missing map coordinates ---
  Future<void> debugPrintUnusedCitiesStats() async {
    print('🔥 [CityProvider] Checking for cities in cities.json but NOT in cities15000.json...');
    try {
      final String citiesJsonStr = await rootBundle.loadString('assets/cities.json');
      final String cities15000JsonStr = await rootBundle.loadString('assets/cities15000.json');

      final List<dynamic> statsList = json.decode(citiesJsonStr);
      final List<dynamic> baseList = json.decode(cities15000JsonStr);

      final Set<String> statsNames = statsList.map((e) => e['name'] as String).toSet();
      final Set<String> baseNames = baseList.map((e) => e['name'] as String).toSet();

      final List<String> unused = statsNames.where((name) => !baseNames.contains(name)).toList();

      if (unused.isNotEmpty) {
        print('🔥 [CityProvider] Found ${unused.length} cities in cities.json that are NOT being used.');
      }
    } catch (e) {
      print('🔥 [CityProvider] Error checking unused stats: $e');
    }
  }

  String _normalizeCityKey(String raw) {
    var s = raw.trim().toLowerCase();
    s = _getOriginalCityName(s);
    s = s
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r"[’'`´]"), "")
        .replaceAll(RegExp(r"[.,/\\\-]"), " ")
        .replaceAll(RegExp(r"\s+"), " ")
        .trim();
    return s;
  }

  String _applyCityAliases(String raw) {
    final key = _normalizeCityKey(raw);
    const aliasMap = <String, String>{
      "st petersburg": "saint petersburg",
      "washington dc": "washington d c",
      "washington d c": "washington d c",
      "vatican": "vatican city",
    };
    return aliasMap[key] ?? key;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (int i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        curr[j + 1] = [
          curr[j] + 1,
          prev[j + 1] + 1,
          prev[j] + cost,
        ].reduce(min);
      }
      for (int j = 0; j < curr.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  Future<void> debugCheckCityListMissing(List<String> inputCities) async {
    print('🧪 [CityProvider] debugCheckCityListMissing: start');
    final Map<String, List<String>> keyToOriginalNames = {};
    for (final c in _allCities) {
      final key = _applyCityAliases(c.name);
      keyToOriginalNames.putIfAbsent(key, () => []).add(c.name);
    }
    final keys = keyToOriginalNames.keys.toList();

    final List<String> missing = [];
    final Map<String, List<String>> suggestions = {};

    for (final raw in inputCities) {
      if (raw.trim().isEmpty) continue;
      final q = _applyCityAliases(raw);
      if (keyToOriginalNames.containsKey(q)) continue;

      missing.add(raw);
      final scored = <MapEntry<String, int>>[];
      for (final k in keys) {
        final d = _levenshtein(q, k);
        scored.add(MapEntry(k, d));
      }
      scored.sort((a, b) => a.value.compareTo(b.value));
      final top = scored.take(3).map((e) {
        final anyOriginal = keyToOriginalNames[e.key]?.first ?? e.key;
        return '$anyOriginal (key="${e.key}", dist=${e.value})';
      }).toList();
      suggestions[raw] = top;
    }

    if (missing.isNotEmpty) {
      print('❌ [CityProvider] Missing cities count = ${missing.length}');
      for (final m in missing) {
        print('   - $m');
        final sug = suggestions[m];
        if (sug != null && sug.isNotEmpty) {
          for (final s in sug) {
            print('         * $s');
          }
        }
      }
    }
    print('🧪 [CityProvider] debugCheckCityListMissing: done');
  }

  Future<void> _loadThemeData(Map<String, String> continentMap) async {
    _summerOlympicsCities = await _loadList('assets/summer_olympics_cities.json', _parseCities);
    _winterOlympicsCities = await _loadList('assets/winter_olympics_cities.json', _parseCities);
    _nhlCities = await _loadList('assets/nhl_cities.json', _parseCities);
    _nbaCities = await _loadList('assets/nba_cities.json', _parseCities);
    _mlbCities = await _loadList('assets/mlb_cities.json', _parseCities);
    _nflCities = await _loadList('assets/nfl_cities.json', _parseCities);
    _mlsCities = await _loadList('assets/mls_cities.json', _parseCities);
    _starbucksCities = await _loadList('assets/starbucks.json', _parseCities);
    _millionaireCities = await _loadList('assets/millionaire.json', _parseCities);
    _transportationCities = await _loadList('assets/transportation.json', _parseCities);
    _stationCities = await _loadList('assets/stations.json', _parseStationsJson);
    _oldestCities = await _loadList('assets/oldest.json', _parseOldestCitiesJson);
    _studentCities = await _loadList('assets/student.json', _parseStudentCitiesJson);
    _safetyCities = await _loadList('assets/safety.json', _parseSafetyJson);
    _liveabilityCities = await _loadList('assets/liveability.json', _parseLiveabilityJson);
    _surveillanceCities = await _loadList('assets/surveillance.json', _parseSurveillanceJson);
    _skyscraperCities = await _loadList('assets/skyscraper.json', _parseSkyscraperJson);
    _pollutionCities = await _loadList('assets/pollution.json', _parsePollutionJson);
    _homicideCities = await _loadList('assets/city_homicide_rate.json', _parseHomicideJson);
    _trafficCities = await _loadList('assets/traffic.json', _parseTrafficJson);
    _hollywoodCities = await _loadList('assets/hollywood.json', _parseHollywoodJson);
    _gawcCities = await _loadList('assets/gawc.json', _parseGaWCJson);

    final String largestJsonStr = await rootBundle.loadString('assets/largest.json');
    _largestCities = await compute(_parseCities, largestJsonStr);
    _largestCitiesOverrideMap = await compute(_parseLargestCitiesMap, largestJsonStr);
  }

  Future<List<City>> _loadList(String path, List<City> Function(String) parser) async {
    try {
      final String jsonStr = await rootBundle.loadString(path);
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
          cityTouristRatio: _touristRatioData[originalName] ?? originalCity.cityTouristRatio,
        );
      }
    }
  }

  void _calculateCitiesMenuStats(Map<String, String> countryToContinentMap) {
    const List<String> continentFullNames = [
      'Asia', 'Europe', 'Africa', 'North America', 'South America', 'Oceania',
    ];

    _cityContinentCounts = {for (var name in continentFullNames) name: 0};
    _capitalContinentCounts = {for (var name in continentFullNames) name: 0};
    _totalCapitalCountsByContinent = {for (var name in continentFullNames) name: 0};
    _totalVisitedCapitals = 0;
    _totalCapitals = 0;
    _totalVisitedCount = _visitDetails.keys.length;

    final bool includeTerritories = _countryProvider?.includeTerritories ?? false;

    for (var city in _allCities) {
      bool isCapital = (city.capitalStatus == CapitalStatus.capital) ||
          (city.capitalStatus == CapitalStatus.territory && includeTerritories);

      if (isCapital) {
        _totalCapitals++;
        if (continentFullNames.contains(city.continent)) {
          _totalCapitalCountsByContinent.update(city.continent, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }

    for (var visitedCityName in _visitDetails.keys) {
      City? cityDetail = getCityDetail(visitedCityName);

      if (cityDetail != null) {
        if (continentFullNames.contains(cityDetail.continent)) {
          _cityContinentCounts.update(cityDetail.continent, (v) => v + 1, ifAbsent: () => 1);
        }

        bool isCapital = (cityDetail.capitalStatus == CapitalStatus.capital) ||
            (cityDetail.capitalStatus == CapitalStatus.territory && includeTerritories);

        if (isCapital) {
          _totalVisitedCapitals++;
          if (continentFullNames.contains(cityDetail.continent)) {
            _capitalContinentCounts.update(cityDetail.continent, (v) => v + 1, ifAbsent: () => 1);
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
      return _allCities.firstWhereOrNull((c) => _getOriginalCityName(c.name) == originalName);
    }
    return null;
  }

  // ===========================================================================
  // Custom Cities (Firebase Integrated)
  // ===========================================================================

  void addCustomCity(String name, double latitude, double longitude, String countryIsoA2, String continent, int population) {
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
      final List<Map<String, dynamic>> jsonList = _customCities.map((city) => {
        'name': city.name,
        'country_iso': city.countryIsoA2,
        'continent': city.continent,
        'population': city.population,
        'latitude': city.latitude,
        'longitude': city.longitude,
      }).toList();

      final String encoded = json.encode(jsonList);
      await prefs.setString('saved_custom_cities', encoded);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'saved_custom_cities': encoded,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('🔥🔥🔥 [CityProvider] ERROR saving custom cities: $e');
    }
  }

  Future<void> _loadCustomCities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      String? jsonStr = prefs.getString('saved_custom_cities');

      if (user != null) {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data()!.containsKey('saved_custom_cities')) {
            jsonStr = doc.data()!['saved_custom_cities'];
          }
        } catch (e) {
          print("🔥🔥🔥 [CityProvider] Failed to fetch custom cities from server: $e");
        }
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
      print('🔥🔥🔥 [CityProvider] ERROR loading custom cities: $e');
    }
  }

  // ===========================================================================
  // User Data & Visit Details (Firebase Integrated)
  // ===========================================================================

  Future<void> _loadVisitDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      String? detailsString = prefs.getString('city_visit_details_v3');

      if (user != null) {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data()!.containsKey('city_visit_details_v3')) {
            detailsString = doc.data()!['city_visit_details_v3'];
            await prefs.setString('city_visit_details_v3', detailsString!);
          } else if (detailsString != null) {
            await _saveVisitDetails();
          }
        } catch (e) {
          print("🔥🔥🔥 [CityProvider] Failed to fetch visit details from server: $e");
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
      print('🔥🔥🔥 [CityProvider] FATAL ERROR loading visit details: $e');
    }
    notifyListeners();
  }

  Future<void> _saveVisitDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedMap = json.encode(
          _visitDetails.map((key, value) => MapEntry(key, value.toJson()))
      );
      await prefs.setString('city_visit_details_v3', encodedMap);

      final user = _auth.currentUser;
      if (user != null) {
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'city_visit_details_v3': encodedMap,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          print("🔥🔥🔥 [CityProvider] Failed to save visit details to server: $e");
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;
    _useDefaultCityRankingBarColor = prefs.getBool('useDefaultCityRankingBarColor') ?? false;

    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('useDefaultCityRankingBarColor')) {
          _useDefaultCityRankingBarColor = doc.data()!['useDefaultCityRankingBarColor'];
          await prefs.setBool('useDefaultCityRankingBarColor', _useDefaultCityRankingBarColor);
        }
      } catch (e) {
        print('[CityProvider] Error loading settings from server: $e');
      }
    }
  }

  Future<void> _loadHomeCity() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;
    _homeCityName = prefs.getString('homeCityName');

    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('homeCityName')) {
          _homeCityName = doc.data()!['homeCityName'];
          if (_homeCityName != null) {
            await prefs.setString('homeCityName', _homeCityName!);
          } else {
            await prefs.remove('homeCityName');
          }
        }
      } catch (e) {
        print('[CityProvider] Error loading home city from server: $e');
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
        'useDefaultCityRankingBarColor': value
      }, SetOptions(merge: true));
    }
    notifyListeners();
  }

  void setCityHomeStatus(String cityName, bool isHome) async {
    if (_homeCityName != null && _visitDetails.containsKey(_homeCityName)) {
      _visitDetails[_homeCityName!] = _visitDetails[_homeCityName!]!.copyWith(isHome: false);
    }

    if (isHome) {
      if (!_visitDetails.containsKey(cityName)) {
        _visitDetails[cityName] = CityVisitDetail(name: cityName, isHome: true, hasLived: true);
      } else {
        _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(isHome: true, hasLived: true);
      }
      _homeCityName = cityName;
    } else {
      _homeCityName = null;
      if (_visitDetails.containsKey(cityName)) {
        _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(isHome: false);
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
        'homeCityName': _homeCityName
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
      _visitDetails[cityName] = CityVisitDetail(name: cityName, isWishlisted: true);
    } else {
      final detail = _visitDetails[cityName]!;
      _visitDetails[cityName] = detail.copyWith(isWishlisted: !detail.isWishlisted);
      final updatedDetail = _visitDetails[cityName]!;

      if (!updatedDetail.hasLived && updatedDetail.visitDateRanges.isEmpty && !updatedDetail.isWishlisted && updatedDetail.rating == 0.0) {
        _visitDetails.remove(cityName);
      }
    }
    await _saveVisitDetails();
    notifyListeners();
  }

  void setVisitedStatus(String cityName, bool isVisited) async {
    if (isVisited) {
      if (!_visitDetails.containsKey(cityName) || _visitDetails[cityName]!.visitDateRanges.isEmpty) {
        _visitDetails[cityName] = (_visitDetails[cityName] ?? CityVisitDetail(name: cityName))
            .copyWith(visitDateRanges: [DateRange()]);
      }
    } else {
      final detail = _visitDetails[cityName];
      if (detail != null) {
        final updatedDetail = detail.copyWith(visitDateRanges: []);
        if (!updatedDetail.hasLived && !updatedDetail.isWishlisted && updatedDetail.rating == 0.0) {
          _visitDetails.remove(cityName);
        } else {
          _visitDetails[cityName] = updatedDetail;
        }
      }
    }
    await _saveVisitDetails();
    _calculateCitiesMenuStats({});
    notifyListeners();
  }

  void clearVisitHistory(String cityName) async {
    if (_visitDetails.containsKey(cityName)) {
      final detail = _visitDetails[cityName]!;
      final updatedDetail = detail.copyWith(visitDateRanges: []);
      if (!updatedDetail.hasLived && !updatedDetail.isWishlisted && updatedDetail.rating == 0.0) {
        _visitDetails.remove(cityName);
      } else {
        _visitDetails[cityName] = updatedDetail;
      }
      await _saveVisitDetails();
      _calculateCitiesMenuStats({});
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
    final detail = _visitDetails.putIfAbsent(cityName, () => CityVisitDetail(name: cityName));

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
        _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(isHome: false);
        if (_homeCityName == cityName) {
          _homeCityName = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('homeCityName');

          final user = _auth.currentUser;
          if (user != null) {
            _firestore.collection('users').doc(user.uid).set({
              'homeCityName': null
            }, SetOptions(merge: true));
          }
        }
      }

      final updatedDetail = _visitDetails[cityName]!;
      if (!updatedDetail.hasLived && updatedDetail.visitDateRanges.isEmpty && !updatedDetail.isWishlisted && updatedDetail.rating == 0.0) {
        _visitDetails.remove(cityName);
      }
    }
    await _saveVisitDetails();
    _calculateCitiesMenuStats({});
    notifyListeners();
  }

  void setCityRating(String cityName, double rating) async {
    if (_visitDetails.containsKey(cityName)) {
      _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(rating: rating);
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
      final newRanges = List<DateRange>.from(detail.visitDateRanges)..add(DateRange());
      _visitDetails[cityName] = detail.copyWith(visitDateRanges: newRanges);
    } else {
      _visitDetails[cityName] = CityVisitDetail(name: cityName, visitDateRanges: [DateRange()]);
    }
    await _saveVisitDetails();
    notifyListeners();
  }

  void updateCityDateRange(String cityName, int index, DateRange newRange) async {
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
        final newRanges = List<DateRange>.from(detail.visitDateRanges)..removeAt(index);

        if (newRanges.isEmpty && !detail.hasLived && !detail.isWishlisted && detail.rating == 0.0) {
          _visitDetails.remove(cityName);
        } else {
          _visitDetails[cityName] = detail.copyWith(visitDateRanges: newRanges);
        }
        await _saveVisitDetails();
        notifyListeners();
      }
    }
  }

  void updateCityMemoAndPhotos(String cityName, String memo, List<String> photos) async {
    if (_visitDetails.containsKey(cityName)) {
      _visitDetails[cityName] = _visitDetails[cityName]!.copyWith(memo: memo, photos: photos);
    } else {
      _visitDetails[cityName] = CityVisitDetail(name: cityName, memo: memo, photos: photos);
    }
    await _saveVisitDetails();
    notifyListeners();
  }

  Future<void> addVisitWithDetails(String cityName, {DateTime? arrival, DateTime? departure, int? userDefinedDuration}) async {
    final detail = _visitDetails[cityName] ?? CityVisitDetail(name: cityName);
    final newRange = DateRange(
      arrival: arrival,
      departure: departure,
      userDefinedDuration: userDefinedDuration,
      isDurationUnknown: userDefinedDuration == null && (arrival == null || departure == null),
    );
    final updatedRanges = List<DateRange>.from(detail.visitDateRanges)..add(newRange);
    _visitDetails[cityName] = detail.copyWith(visitDateRanges: updatedRanges);
    await _saveVisitDetails();
    _calculateCitiesMenuStats({});
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