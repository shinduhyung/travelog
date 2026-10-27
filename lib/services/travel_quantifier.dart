// lib/services/travel_quantifier.dart

import 'dart:math';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/travel_persona/travel_features.dart';

class TravelQuantifier {
  final CountryProvider countryProvider;
  final CityProvider cityProvider;
  final AirlineProvider airlineProvider;
  final AirportProvider airportProvider;

  TravelQuantifier({
    required this.countryProvider,
    required this.cityProvider,
    required this.airlineProvider,
    required this.airportProvider,
  });

  /// Missing records must not become neutral/negative evidence for a type.
  Set<String> get observedAxes {
    final countries = _getValidCountries();
    final cities = _getValidCities();
    final flights = airlineProvider.allFlightLogs.where((log) => !log.isCanceled).toList();
    final axes = <String>{};
    if (countries.isNotEmpty) {
      axes.addAll(['continentDistribution', 'countryDistribution']);
      final stats = _calculateRatingStats(countries, cities);
      for (final entry in {
        'countryWealth': _countryWealthScores,
        'countryType': _countryTypeScores,
        'countryNightlife': _countryNightlifeScores,
      }.entries) {
        if (countries.any((name) => entry.value.containsKey(countryProvider.countryNameToIsoMap[name]) &&
            _getWeight(countryProvider.visitDetails[name]?.rating ?? 0, stats) != 0)) {
          axes.add(entry.key);
        }
      }
    }
    if (cities.isNotEmpty) axes.add('cityDistribution');
    if (airportProvider.visitedAirports.isNotEmpty) {
      axes.addAll(['airportDistribution', 'transferAirportScore']);
    }
    if (flights.isNotEmpty) axes.addAll(['airlineDistribution', 'transferFlightScore']);
    if (flights.any((log) => airlineProvider.parseDuration(log.duration) > 0 && log.times > 0)) {
      axes.add('airlineTime');
    }
    return axes;
  }

  TravelFeatures quantify() {
    final validCountries = _getValidCountries();
    final validCities = _getValidCities();
    final flightLogs = airlineProvider.allFlightLogs.where((log) => !log.isCanceled).toList();

    // 0. Rating 통계 계산 (sigma=0 예외 처리 포함)
    final ratingStats = _calculateRatingStats(validCountries, validCities);

    // 1. Distribution (데이터 부족 시 0.0 반환 로직이 _calcEntropyScore에 포함됨)
    final double continentDist = _calcEntropyScore(_getContinentCounts(validCountries));
    final double countryDist = _calcEntropyScore(_getCountryCounts(validCountries));
    final double cityDist = _calcEntropyScore(_getCityCounts(validCities));
    final double airportDist = _calcEntropyScore(_getAirportCounts());
    final double airlineDist = _calcEntropyScore(_getAirlineCounts(flightLogs));

    // 2. Traits (Wealth, Type, Nightlife)
    final double cWealth = _calcWeightedTraitScore(validCountries, _countryWealthScores, ratingStats);
    final double cType = _calcWeightedTraitScore(validCountries, _countryTypeScores, ratingStats);
    final double cNight = _calcWeightedTraitScore(validCountries, _countryNightlifeScores, ratingStats);

    // City Traits (데이터 부족으로 0.0)
    final double cityW = 0.0;
    final double cityT = 0.0;
    final double cityN = 0.0;

    // 3. Flight Patterns (데이터 부족 시 0.0 반환 로직이 각 함수에 포함됨)
    final double airTime = _calcAirlineTimeScore(flightLogs);
    final double transAirport = _calcTransferAirportScore();
    final double transFlight = _calcTransferFlightScore(flightLogs);

    // 4. Return - 랜드마크 축 이름 수정
    return TravelFeatures(
      continentDistribution: continentDist,
      countryDistribution: countryDist,
      cityDistribution: cityDist,
      airportDistribution: airportDist,
      airlineDistribution: airlineDist,
      countryWealth: cWealth,
      cityWealth: cityW,
      countryType: cType,
      cityType: cityT,
      countryNightlife: cNight,
      cityNightlife: cityN,
      airlineTime: airTime,
      transferAirportScore: transAirport,
      transferFlightScore: transFlight,

      // ✅ 랜드마크 축 이름 수정 (CamelCase 사용)
      landmarkCultureNature: 0.0,
      landmarkAncientModern: 0.0,
      landmarkUrbanRural: 0.0,
      landmarkAdventureRelax: 0.0,
      landmarkArtScience: 0.0,
      landmarkSpiritualSecular: 0.0,
      landmarkCrowd: 0.0,
      landmarkBudgetLuxury: 0.0,
      landmarkLocalTourist: 0.0,
      landmarkCalmNightlife: 0.0,

      // Personality (DNA)
      soloSocial: 0.0,
      relaxedIntense: 0.0,
      plannedSpontaneous: 0.0,
      urbanNature: 0.0,
      cultureFun: 0.0,
      personalityBudgetLuxury: 0.0,
      morningNight: 0.0,
      documenterLive: 0.0,
    );
  }

  // --- Helpers ---

  List<String> _getValidCountries() {
    final homeIso = countryProvider.homeCountryIsoA3;
    return countryProvider.visitDetails.entries
        .where((e) => e.value.isVisited)
        .where((e) => countryProvider.countryNameToIsoMap[e.key] != homeIso)
        .where((e) => !e.value.hasLived)
        .map((e) => e.key)
        .toList();
  }

  List<String> _getValidCities() {
    final homeCity = cityProvider.homeCityName;
    return cityProvider.visitDetails.entries
        .where((e) => cityProvider.isVisited(e.key))
        .where((e) => e.key != homeCity)
        .where((e) => !e.value.hasLived)
        .map((e) => e.key)
        .toList();
  }

  _RatingStats _calculateRatingStats(List<String> countries, List<String> cities) {
    List<double> ratings = [];
    for (var c in countries) {
      final r = countryProvider.visitDetails[c]?.rating ?? 0.0;
      if (r > 0) ratings.add(r);
    }
    for (var c in cities) {
      final r = cityProvider.visitDetails[c]?.rating ?? 0.0;
      if (r > 0) ratings.add(r);
    }

    if (ratings.isEmpty) return _RatingStats(0, 1);

    double sum = ratings.reduce((a, b) => a + b);
    double mean = sum / ratings.length;

    double sumSq = ratings.map((r) => pow(r - mean, 2)).reduce((a, b) => a + b).toDouble();
    double stdDev = sqrt(sumSq / ratings.length);

    return _RatingStats(mean, stdDev == 0 ? 1 : stdDev);
  }

  double _getWeight(double rating, _RatingStats stats) {
    if (rating <= 0) return 1.0;

    double z = (rating - stats.mean) / stats.stdDev;

    if (z >= 2.0) return 2.0;
    if (z >= 1.0) return 1.5;
    if (z <= -2.0) return -2.0;
    if (z <= -1.0) return 0.0;
    return 1.0;
  }

  Map<String, int> _getContinentCounts(List<String> countries) {
    Map<String, int> counts = {};
    for (var cName in countries) {
      final country = countryProvider.allCountries.firstWhere(
              (c) => c.name == cName,
          orElse: () => countryProvider.allCountries.first
      );
      final continent = country.continent ?? 'Unknown';
      counts[continent] = (counts[continent] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> _getCountryCounts(List<String> countries) {
    Map<String, int> counts = {};
    for (var cName in countries) {
      counts[cName] = countryProvider.visitDetails[cName]?.visitCount ?? 1;
    }
    return counts;
  }

  Map<String, int> _getCityCounts(List<String> cities) {
    Map<String, int> counts = {};
    for (var cName in cities) {
      counts[cName] = cityProvider.visitDetails[cName]?.visitDateRanges.length ?? 0;
    }
    return counts;
  }

  Map<String, int> _getAirportCounts() {
    Map<String, int> counts = {};
    airportProvider.visitedAirports.forEach((iata) {
      counts[iata] = airportProvider.getVisitCount(iata);
    });
    return counts;
  }

  Map<String, int> _getAirlineCounts(List<dynamic> logs) {
    Map<String, int> counts = {};
    for (var log in logs) {
      final name = log.airlineName ?? 'Unknown';
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  double _calcEntropyScore(Map<String, int> counts) {
    if (counts.isEmpty) return -1.0;

    double total = counts.values.fold(0, (sum, count) => sum + count).toDouble();

    if (total == 0) return 0.0;

    double entropy = 0.0;
    for (var count in counts.values) {
      if (count > 0) {
        double p = count / total;
        entropy -= p * (log(p) / log(2));
      }
    }

    int k = counts.length;
    if (k <= 1) return -1.0;

    double maxEntropy = log(k) / log(2);
    if (maxEntropy == 0) return 0.0;

    double normalized = entropy / maxEntropy;
    return (normalized * 2) - 1;
  }

  double _calcWeightedTraitScore(List<String> items, Map<String, double> scoreMap, _RatingStats stats) {
    double weightedSum = 0.0;
    double totalWeight = 0.0;

    for (var name in items) {
      final iso = countryProvider.countryNameToIsoMap[name];
      if (iso == null) continue;

      double traitScore = scoreMap[iso] ?? 0.0;

      double rating = 0.0;
      if (countryProvider.visitDetails.containsKey(name)) {
        rating = countryProvider.visitDetails[name]!.rating;
      }

      double weight = _getWeight(rating, stats);

      weightedSum += traitScore * weight;
      totalWeight += weight.abs();
    }

    if (totalWeight == 0) return 0.0;

    return (weightedSum / totalWeight).clamp(-1.0, 1.0);
  }

  double _calcAirlineTimeScore(List<dynamic> logs) {
    double totalHours = 0;
    int count = 0;

    for (var log in logs) {
      int minutes = airlineProvider.parseDuration(log.duration);
      if (minutes > 0) {
        double hours = minutes / 60.0;
        final flightCount = (log.times as num).toInt();
        totalHours += hours * flightCount;
        count += flightCount;
      }
    }

    if (count == 0) return 0.0;
    double avgT = totalHours / count;

    if (avgT <= 1.0) return -1.0;
    if (avgT <= 1.5) return -0.8;
    if (avgT <= 2.0) return -0.6;
    if (avgT <= 2.5) return -0.4 + ((avgT - 2.0) / 0.5) * 0.4;
    if (avgT <= 3.0) return 0.0 + ((avgT - 2.5) / 0.5) * 0.2;
    if (avgT <= 4.0) return 0.2;
    if (avgT <= 6.0) return 0.4;
    if (avgT <= 8.0) return 0.6;
    if (avgT <= 10.0) return 0.8;
    return 1.0;
  }

  double _calcTransferAirportScore() {
    int totalAirports = airportProvider.visitedAirports.length;
    if (totalAirports == 0) return 0.0;

    int transferAirports = 0;
    for (var iata in airportProvider.visitedAirports) {
      final entries = airportProvider.getVisitEntries(iata);
      if (entries.any((e) => e.isTransfer || e.isLayover || e.isStopover)) {
        transferAirports++;
      }
    }

    double p = (transferAirports / totalAirports) * 100;

    if (p <= 0) return -1.0;
    if (p <= 5) return -0.8;
    if (p <= 10) return -0.6;
    if (p <= 15) return -0.4;
    if (p <= 18) return -0.2;
    if (p <= 22) return 0.0;
    if (p <= 25) return 0.2;
    if (p <= 30) return 0.4;
    if (p <= 40) return 0.6;
    if (p <= 50) return 0.8;
    return 1.0;
  }

  double _calcTransferFlightScore(List<dynamic> logs) {
    int totalSegments = logs.length;
    if (totalSegments == 0) return 0.0;

    int transferSegments = 0;
    final connections = airlineProvider.flightConnections;

    Set<String> transferLogIds = {};
    for (var conn in connections) {
      transferLogIds.addAll(conn.flightLogIds);
    }

    for (var log in logs) {
      if (transferLogIds.contains(log.id)) {
        transferSegments++;
      }
    }

    double q = (transferSegments / totalSegments) * 100;

    if (q <= 0) return -1.0;
    if (q <= 5) return -0.8;
    if (q <= 10) return -0.6;
    if (q <= 20) return -0.4;
    if (q <= 25) return -0.2;
    if (q <= 28) return 0.0;
    if (q <= 30) return 0.2;
    if (q <= 35) return 0.4;
    if (q <= 45) return 0.6;
    if (q <= 55) return 0.8;
    return 1.0;
  }

  // --- DATA MAPS ---

  static const Map<String, double> _countryWealthScores = {
    "ABW": 0.3, "AFG": -0.8, "AGO": 0.0, "AIA": 0.0, "ALA": 0.0, "ALB": 0.1, "AND": 0.0, "ARE": 0.6,
    "ARG": 0.1, "ARM": 0.0, "ASM": 0.0, "ATG": 0.0, "AUS": 0.7, "AUT": 0.6, "AZE": 0.0, "BDI": 0.0,
    "BEL": 0.6, "BEN": 0.0, "BFA": 0.0, "BGD": -0.3, "BGR": 0.2, "BHR": 0.4, "BHS": 0.3, "BIH": 0.1,
    "BLM": 0.0, "BLR": 0.0, "BLZ": 0.0, "BMU": 0.9, "BOL": -0.2, "BRA": 0.1, "BRB": 0.0, "BRN": 0.5,
    "BTN": 0.0, "BWA": 0.0, "CAF": -0.7, "CAN": 0.6, "CHE": 0.9, "CHL": 0.3, "CHN": 0.0, "CIV": -0.3,
    "CMR": -0.4, "COD": -0.7, "COG": 0.0, "COK": 0.0, "COL": 0.0, "COM": 0.0, "CPV": 0.0, "CRI": 0.2,
    "CUB": 0.0, "CUW": 0.0, "CYM": 0.9, "CYP": 0.4, "CZE": 0.3, "DEU": 0.6, "DJI": 0.0, "DMA": 0.0,
    "DNK": 0.7, "DOM": 0.0, "DZA": 0.0, "ECU": 0.0, "EGY": -0.3, "ERI": 0.0, "ESH": 0.0, "ESP": 0.4,
    "EST": 0.3, "ETH": -0.4, "FIN": 0.6, "FJI": 0.0, "FLK": 0.0, "FRA": 0.6, "FRO": 0.0, "FSM": 0.0,
    "GAB": 0.0, "GBR": 0.6, "GEO": 0.0, "GGY": 0.5, "GHA": -0.3, "GIB": 0.0, "GIN": 0.0, "GMB": 0.0,
    "GNB": 0.0, "GNQ": 0.0, "GRC": 0.2, "GRD": 0.0, "GRL": 0.0, "GTM": -0.2, "GUM": 0.0, "GUY": 0.0,
    "HKG": 0.6, "HND": -0.2, "HRV": 0.3, "HTI": -0.6, "HUN": 0.3, "IDN": -0.1, "IMN": 0.5, "IND": -0.5,
    "IRL": 0.8, "IRN": 0.0, "IRQ": 0.0, "ISL": 0.8, "ISR": 0.5, "ITA": 0.5, "JAM": 0.0, "JEY": 0.5,
    "JOR": -0.1, "JPN": 0.6, "KAZ": 0.1, "KEN": -0.3, "KGZ": -0.4, "KHM": -0.3, "KIR": 0.0, "KNA": 0.0,
    "KOR": 0.5, "KOS": 0.0, "KWT": 0.4, "LAO": -0.3, "LBN": 0.0, "LBR": 0.0, "LBY": 0.0, "LCA": 0.0,
    "LIE": 0.9, "LKA": -0.2, "LSO": 0.0, "LTU": 0.3, "LUX": 0.9, "LVA": 0.3, "MAC": 0.6, "MAF": 0.0,
    "MAR": -0.2, "MCO": 1.0, "MDA": -0.2, "MDG": -0.5, "MDV": 0.2, "MEX": 0.1, "MHL": 0.0, "MKD": 0.1,
    "MLI": 0.0, "MLT": 0.4, "MMR": -0.3, "MNE": 0.1, "MNG": -0.4, "MUS": 0.2, "MNP": 0.0, "MOZ": -0.5,
    "MRT": 0.0, "MSR": 0.0, "MWI": 0.0, "MYS": 0.1, "NAM": 0.0, "NCL": 0.0, "NER": 0.0, "NFK": 0.0,
    "NGA": -0.3, "NIC": -0.2, "NIU": 0.0, "NLD": 0.7, "NOR": 0.8, "NPL": -0.3, "NRU": 0.0, "NZL": 0.6,
    "OMN": 0.3, "PAK": -0.3, "PAN": 0.2, "PCN": 0.0, "PER": 0.0, "PHL": -0.1, "PLW": 0.0, "PNG": 0.0,
    "POL": 0.3, "PRI": 0.0, "PRK": -0.9, "PRT": 0.3, "PRY": -0.2, "PSE": 0.0, "PYF": 0.0, "QAT": 0.7,
    "ROU": 0.2, "RUS": 0.0, "RWA": 0.0, "SAU": 0.4, "SDN": 0.0, "SEN": -0.3, "SGP": 0.8, "SLB": 0.0,
    "SLE": 0.0, "SLV": -0.2, "SML": 0.0, "SMR": 0.5, "SOM": -0.8, "SPM": 0.0, "SRB": 0.1, "SSD": -0.8,
    "STP": 0.0, "SUR": 0.0, "SVK": 0.3, "SVN": 0.3, "SWE": 0.7, "SWZ": 0.0, "SXM": 0.0, "SYR": -0.8,
    "SYC": 0.2, "TCA": 0.3, "TCD": 0.0, "TGO": 0.0, "THA": -0.1, "TJK": -0.4, "TKM": 0.0, "TLS": 0.0,
    "TON": 0.0, "TTO": 0.0, "TUN": -0.1, "TUR": -0.2, "TUV": 0.0, "TWN": 0.4, "TZA": -0.3, "UGA": -0.4,
    "UKR": -0.2, "URY": 0.3, "USA": 0.7, "UZB": -0.4, "VAT": 0.5, "VCT": 0.0, "VEN": 0.0, "VGB": 0.3,
    "VIR": 0.3, "VNM": -0.2, "VUT": 0.0, "WLF": 0.0, "WSM": 0.0, "YEM": -0.8, "ZAF": 0.1, "ZMB": -0.4,
    "ZWE": -0.4
  };

  static const Map<String, double> _countryTypeScores = {
    "ABW": -0.8, "AFG": -0.5, "AGO": -0.6, "AIA": -0.8, "ALA": -0.9, "ALB": -0.3, "AND": -0.5, "ARE": 0.9,
    "ARG": -0.3, "ARM": 0.4, "ASM": -0.8, "ATG": -0.8, "AUS": -0.6, "AUT": 0.3, "AZE": 0.1, "BDI": -0.7,
    "BEL": 0.7, "BEN": 0.2, "BFA": -0.2, "BGD": -0.4, "BGR": 0.1, "BHR": 0.6, "BHS": -0.9, "BIH": 0.2,
    "BLM": -0.7, "BLR": 0.0, "BLZ": -0.7, "BMU": -0.7, "BOL": -0.6, "BRA": -0.5, "BRB": -0.7, "BRN": 0.2,
    "BTN": -0.5, "BWA": -0.9, "CAF": -0.8, "CAN": -0.7, "CHE": -0.4, "CHL": -0.6, "CHN": -0.2, "CIV": -0.3,
    "CMR": -0.6, "COD": -0.8, "COG": -0.8, "COK": -0.9, "COL": -0.2, "COM": -0.8, "CPV": -0.6, "CRI": -0.8,
    "CUB": 0.3, "CUW": -0.5, "CYM": -0.6, "CYP": -0.2, "CZE": 0.8, "DEU": 0.6, "DJI": -0.5, "DMA": -0.9,
    "DNK": 0.4, "DOM": -0.6, "DZA": -0.3, "ECU": -0.5, "EGY": 0.8, "ERI": -0.2, "ESH": -0.7, "ESP": 0.6,
    "EST": 0.2, "ETH": 0.1, "FIN": -0.4, "FJI": -0.9, "FLK": -1.0, "FRA": 0.7, "FRO": -1.0, "FSM": -0.9,
    "GAB": -0.8, "GBR": 0.7, "GEO": -0.2, "GGY": -0.3, "GHA": 0.0, "GIB": 0.5, "GIN": -0.7, "GMB": -0.5,
    "GNB": -0.6, "GNQ": -0.5, "GRC": 0.6, "GRD": -0.8, "GRL": -1.0, "GTM": 0.1, "GUM": -0.6, "GUY": -0.9,
    "HKG": 0.9, "HND": -0.4, "HRV": -0.1, "HTI": -0.5, "HUN": 0.6, "IDN": -0.6, "IMN": -0.2, "IND": 0.5,
    "IRL": -0.4, "IRN": 0.5, "IRQ": 0.6, "ISL": -1.0, "ISR": 0.7, "ITA": 0.8, "JAM": -0.6, "JEY": -0.1,
    "JOR": 0.4, "JPN": 0.3, "KAZ": -0.5, "KEN": -0.8, "KGZ": -0.8, "KHM": 0.4, "KIR": -0.9, "KNA": -0.7,
    "KOR": 0.4, "KOS": 0.1, "KWT": 0.8, "LAO": -0.4, "LBN": 0.3, "LBR": -0.7, "LBY": -0.3, "LCA": -0.8,
    "LIE": -0.4, "LKA": -0.3, "LSO": -0.8, "LTU": 0.1, "LUX": 0.6, "LVA": 0.1, "MAC": 0.9, "MAF": -0.6,
    "MAR": 0.4, "MCO": 1.0, "MDA": 0.0, "MDG": -0.9, "MDV": -1.0, "MEX": 0.0, "MHL": -0.9, "MKD": 0.1,
    "MLI": -0.4, "MLT": 0.7, "MMR": 0.2, "MNE": -0.3, "MNG": -0.9, "MUS": -0.7, "MNP": -0.8, "MOZ": -0.7,
    "MRT": -0.7, "MSR": -0.9, "MWI": -0.7, "MYS": -0.1, "NAM": -0.9, "NCL": -0.7, "NER": -0.7, "NFK": -0.8,
    "NGA": -0.2, "NIC": -0.5, "NIU": -0.9, "NLD": 0.6, "NOR": -0.8, "NPL": -0.9, "NRU": -0.9, "NZL": -0.8,
    "OMN": -0.4, "PAK": -0.2, "PAN": -0.1, "PCN": -0.8, "PER": 0.3, "PHL": -0.6, "PLW": -0.9, "PNG": -0.9,
    "POL": 0.3, "PRI": -0.2, "PRK": 0.1, "PRT": 0.2, "PRY": -0.4, "PSE": 0.7, "PYF": -0.9, "QAT": 0.9,
    "ROU": 0.1, "RUS": 0.0, "RWA": -0.6, "SAU": -0.2, "SDN": 0.1, "SEN": -0.3, "SGP": 1.0, "SLB": -0.8,
    "SLE": -0.6, "SLV": -0.3, "SML": -0.5, "SMR": 0.8, "SOM": -0.5, "SPM": -0.7, "SRB": 0.2, "SSD": -0.9,
    "STP": -0.8, "SUR": -0.9, "SVK": 0.4, "SVN": -0.2, "SWE": 0.2, "SWZ": -0.7, "SXM": -0.4, "SYR": 0.7,
    "SYC": -0.9, "TCA": -0.8, "TCD": -0.8, "TGO": -0.4, "THA": -0.2, "TJK": -0.7, "TKM": -0.4, "TLS": -0.7,
    "TON": -0.9, "TTO": -0.5, "TUN": 0.3, "TUR": 0.1, "TUV": -0.9, "TWN": 0.3, "TZA": -0.8, "UGA": -0.7,
    "UKR": 0.2, "URY": -0.2, "USA": -0.1, "UZB": 0.5, "VAT": 0.6, "VCT": -0.8, "VEN": -0.5, "VGB": -0.8,
    "VIR": -0.7, "VNM": -0.3, "VUT": -0.9, "WLF": -0.9, "WSM": -0.8, "YEM": 0.4, "ZAF": -0.4, "ZMB": -0.7,
    "ZWE": -0.6
  };

  static const Map<String, double> _countryNightlifeScores = {
    "ABW": 0.5, "AFG": -1.0, "AGO": -0.3, "AIA": -0.2, "ALA": -0.6, "ALB": 0.2, "AND": 0.1, "ARE": 0.6,
    "ARG": 0.7, "ARM": 0.0, "ASM": -0.5, "ATG": 0.1, "AUS": 0.6, "AUT": 0.4, "AZE": 0.1, "BDI": -0.7,
    "BEL": 0.6, "BEN": -0.4, "BFA": -0.5, "BGD": -0.9, "BGR": 0.5, "BHR": 0.3, "BHS": 0.4, "BIH": 0.3,
    "BLM": 0.2, "BLR": 0.1, "BLZ": 0.1, "BMU": 0.2, "BOL": 0.1, "BRA": 0.9, "BRB": 0.4, "BRN": -0.9,
    "BTN": -0.9, "BWA": -0.4, "CAF": -0.8, "CAN": 0.6, "CHE": 0.1, "CHL": 0.5, "CHN": 0.2, "CIV": -0.2,
    "CMR": -0.3, "COD": -0.5, "COG": -0.4, "COK": -0.6, "COL": 0.8, "COM": -0.9, "CPV": 0.1, "CRI": 0.4,
    "CUB": 0.6, "CUW": 0.5, "CYM": 0.3, "CYP": 0.7, "CZE": 0.7, "DEU": 0.9, "DJI": -0.6, "DMA": -0.2,
    "DNK": 0.5, "DOM": 0.7, "DZA": -0.8, "ECU": 0.3, "EGY": -0.3, "ERI": -0.8, "ESH": -0.9, "ESP": 1.0,
    "EST": 0.4, "ETH": -0.5, "FIN": 0.3, "FJI": 0.0, "FLK": -0.7, "FRA": 0.6, "FRO": -0.8, "FSM": -0.7,
    "GAB": -0.4, "GBR": 0.9, "GEO": 0.4, "GGY": -0.2, "GHA": 0.1, "GIB": 0.2, "GIN": -0.5, "GMB": 0.0,
    "GNB": -0.6, "GNQ": -0.6, "GRC": 0.8, "GRD": 0.1, "GRL": -0.5, "GTM": 0.2, "GUM": 0.3, "GUY": -0.1,
    "HKG": 0.7, "HND": 0.0, "HRV": 0.7, "HTI": -0.6, "HUN": 0.7, "IDN": -0.2, "IMN": -0.2, "IND": -0.4,
    "IRL": 0.8, "IRN": -0.9, "IRQ": -0.8, "ISL": 0.2, "ISR": 0.8, "ITA": 0.6, "JAM": 0.6, "JEY": 0.1,
    "JOR": -0.3, "JPN": 0.7, "KAZ": 0.1, "KEN": -0.2, "KGZ": -0.4, "KHM": 0.3, "KIR": -0.8, "KNA": 0.1,
    "KOR": 0.8, "KOS": 0.1, "KWT": -0.9, "LAO": 0.1, "LBN": 0.5, "LBR": -0.5, "LBY": -0.9, "LCA": 0.1,
    "LIE": -0.2, "LKA": -0.5, "LSO": -0.6, "LTU": 0.3, "LUX": 0.2, "LVA": 0.3, "MAC": 0.7, "MAF": 0.3,
    "MAR": -0.3, "MCO": 0.7, "MDA": 0.1, "MDG": -0.5, "MDV": -0.7, "MEX": 0.8, "MHL": -0.7, "MKD": 0.2,
    "MLI": -0.7, "MLT": 0.7, "MMR": -0.4, "MNE": 0.4, "MNG": -0.3, "MUS": -0.1, "MNP": -0.2, "MOZ": -0.4,
    "MRT": -0.9, "MSR": -0.5, "MWI": -0.6, "MYS": 0.2, "NAM": -0.3, "NCL": 0.0, "NER": -0.7, "NFK": -0.8,
    "NGA": 0.2, "NIC": 0.1, "NIU": -0.8, "NLD": 0.8, "NOR": 0.4, "NPL": -0.8, "NRU": -0.9, "NZL": 0.2,
    "OMN": -0.6, "PAK": -0.8, "PAN": 0.5, "PCN": -0.8, "PER": 0.5, "PHL": 0.6, "PLW": -0.5, "PNG": -0.6,
    "POL": 0.5, "PRI": 0.7, "PRK": -1.0, "PRT": 0.7, "PRY": 0.2, "PSE": -0.7, "PYF": -0.2, "QAT": 0.1,
    "ROU": 0.5, "RUS": 0.5, "RWA": -0.3, "SAU": -0.9, "SDN": -0.9, "SEN": -0.2, "SGP": 0.6, "SLB": -0.6,
    "SLE": -0.5, "SLV": 0.2, "SML": -0.9, "SMR": -0.1, "SOM": -1.0, "SPM": -0.5, "SRB": 0.6, "SSD": -0.9,
    "STP": -0.5, "SUR": 0.1, "SVK": 0.4, "SVN": 0.3, "SWE": 0.5, "SWZ": -0.5, "SXM": 0.5, "SYR": -0.8,
    "SYC": -0.3, "TCA": 0.1, "TCD": -0.7, "TGO": -0.4, "THA": 1.0, "TJK": -0.6, "TKM": -0.7, "TLS": -0.5,
    "TON": -0.7, "TTO": 0.4, "TUN": -0.2, "TUR": 0.3, "TUV": -0.9, "TWN": 0.6, "TZA": -0.2, "UGA": -0.1,
    "UKR": 0.3, "URY": 0.5, "USA": 0.9, "UZB": -0.2, "VAT": -1.0, "VCT": 0.1, "VEN": 0.1, "VGB": 0.2,
    "VIR": 0.4, "VNM": 0.4, "VUT": -0.5, "WLF": -0.8, "WSM": -0.6, "YEM": -1.0, "ZAF": 0.5, "ZMB": -0.3,
    "ZWE": -0.4
  };
}

class _RatingStats {
  final double mean;
  final double stdDev;
  _RatingStats(this.mean, this.stdDev);
}
