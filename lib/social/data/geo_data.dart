import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// assets/data/*.json (tool/build_assets.py로 Travelog 원본에서 만든 경량 데이터) 조회.
/// 키는 Travelog가 Firestore에 저장하는 키와 같다:
///   나라 = custom.geo.json의 name, 도시 = 이름(+"(n)"), 랜드마크/유산 = 이름.
class GeoData {
  GeoData._(this.countries, this.cities, this.landmarks, this.unesco, this.airports, this.airlines, this.badges) {
    for (final c in countries.values) {
      _byName[c.name] = c;
      if (c.iso2 != null) _byIso2[c.iso2!] = c;
    }
  }

  final Map<String, CountryMeta> countries; // iso3 ->
  final Map<String, CityMeta> cities; // 도시 키 ->
  final Map<String, LandmarkMeta> landmarks;
  final Map<String, UnescoMeta> unesco;
  final Map<String, AirportMeta> airports;
  final Map<String, AirlineMeta> airlines;

  /// Travelog 뱃지 정의 (assets/data/badges.json, tool/build_badges.py)
  final Map<String, BadgeMeta> badges;
  final _byName = <String, CountryMeta>{};
  final _byIso2 = <String, CountryMeta>{};

  static GeoData? _instance;
  static GeoData get I => _instance!;
  static bool get isLoaded => _instance != null;

  static Future<void> load() async {
    if (_instance != null) return;
    const files = ['geo', 'cities', 'landmarks', 'unesco', 'airports', 'airlines', 'badges'];
    final raws = await Future.wait(files.map((f) => rootBundle.loadString('assets/social/$f.json')));
    _instance = await compute(_parse, raws);
  }

  /// 테스트용
  @visibleForTesting
  static void setForTest(GeoData data) => _instance = data;

  static GeoData fromJsonStrings(List<String> raws) => _parse(raws);

  CountryMeta? countryByName(String name) => _byName[name];
  CountryMeta? countryByIso2(String? iso2) => iso2 == null ? null : _byIso2[iso2];
  CountryMeta? countryByIso3(String? iso3) => iso3 == null ? null : countries[iso3];

  CountryMeta? countryOfCity(String cityKey) => countryByIso2(cities[cityKey]?.iso2);

  CountryMeta? countryOfLandmark(String name) => countryByIso3(landmarks[name]?.iso3);

  CountryMeta? countryOfUnesco(String name) => countryByIso3(unesco[name]?.iso3);

  /// 대륙별 나라 수 (진행률 분모)
  late final Map<String, int> continentTotals = () {
    final totals = <String, int>{};
    for (final c in countries.values) {
      if (c.continent == null || c.iso2 == null) continue;
      totals[c.continent!] = (totals[c.continent!] ?? 0) + 1;
    }
    return totals;
  }();

  late final int totalCountries = continentTotals.values.fold(0, (a, b) => a + b);

  /// Travelog "Top 250" 랜드마크 (1위부터)
  late final List<LandmarkMeta> topLandmarks = (landmarks.values.where((l) => l.rank > 0).toList()
    ..sort((a, b) => a.rank.compareTo(b.rank)));
}

GeoData _parse(List<String> raws) {
  Map<String, dynamic> j(int i) => json.decode(raws[i]) as Map<String, dynamic>;

  final countries = <String, CountryMeta>{};
  j(0).forEach((iso3, raw) {
    final m = raw as Map<String, dynamic>;
    countries[iso3] = CountryMeta(
      iso3: iso3,
      name: m['n'] as String,
      longName: m['nl'] as String?,
      iso2: m['a2'] as String?,
      continent: m['ct'] as String?,
      subregion: m['sr'] as String?,
      capital: m['cap'] as String?,
      population: (m['pop'] as num?)?.toInt(),
      area: (m['area'] as num?)?.toInt(),
      polygons: [
        for (final ring in (m['p'] as List? ?? const []))
          Float32List.fromList((ring as List).map((e) => (e as num).toDouble()).toList()),
      ],
    );
  });

  final cities = <String, CityMeta>{};
  j(1).forEach((key, raw) {
    final v = raw as List;
    cities[key] = CityMeta(
      key: key,
      iso2: v[0] as String?,
      lat: (v[1] as num).toDouble(),
      lng: (v[2] as num).toDouble(),
      population: (v[3] as num).toInt(),
      isCapital: v[4] == 1,
    );
  });

  final landmarks = <String, LandmarkMeta>{};
  j(2).forEach((name, raw) {
    final v = raw as List;
    landmarks[name] = LandmarkMeta(
      name: name,
      iso3: v[0] as String?,
      city: v[1] as String?,
      lat: (v[2] as num).toDouble(),
      lng: (v[3] as num).toDouble(),
      rank: (v[4] as num?)?.toInt() ?? 0,
      category: v[5] as String?,
      imagePath: v.length > 6 ? v[6] as String? : null,
    );
  });

  final unesco = <String, UnescoMeta>{};
  j(3).forEach((name, raw) {
    final v = raw as List;
    unesco[name] = UnescoMeta(
      name: name,
      iso3: v[0] as String?,
      type: v[1] as String?,
      lat: (v[2] as num).toDouble(),
      lng: (v[3] as num).toDouble(),
      year: int.tryParse('${v[4]}'),
    );
  });

  final airports = <String, AirportMeta>{};
  j(4).forEach((iata, raw) {
    final v = raw as List;
    airports[iata] = AirportMeta(
      iata: iata,
      name: v[0]?.toString() ?? iata,
      city: v[1]?.toString(),
      iso2: v[2]?.toString(),
      lat: (v[3] as num).toDouble(),
      lng: (v[4] as num).toDouble(),
    );
  });

  final airlines = <String, AirlineMeta>{};
  j(5).forEach((code, raw) {
    final v = raw as List;
    airlines[code] = AirlineMeta(code: code, name: v[0] as String, colorHex: v[1] as String?);
  });

  final badges = <String, BadgeMeta>{};
  if (raws.length > 6) {
    j(6).forEach((id, raw) {
      final m = raw as Map<String, dynamic>;
      badges[id] = BadgeMeta(
        id: id,
        name: m['n']?.toString() ?? id,
        description: m['d']?.toString() ?? '',
        level: m['lv']?.toString(),
        category: m['cat']?.toString(),
        points: (m['pt'] as num?)?.toInt() ?? 0,
        image: (m['img']?.toString().isEmpty ?? true) ? null : 'assets/social/badge_thumbs/${m['img']}',
      );
    });
  }

  return GeoData._(countries, cities, landmarks, unesco, airports, airlines, badges);
}

class CountryMeta {
  CountryMeta({
    required this.iso3,
    required this.name,
    String? longName,
    this.iso2,
    this.continent,
    this.subregion,
    this.capital,
    this.population,
    this.area,
    this.polygons = const [],
  }) : longName = longName ?? name;

  final String iso3;

  /// Travelog 키 (custom.geo.json name, 예: "St. Vin. & Gren.")
  final String name;

  /// 화면 표시용 (name_long, 예: "Saint Vincent and the Grenadines")
  final String longName;
  final String? iso2;
  final String? continent;
  final String? subregion;
  final String? capital;
  final int? population;
  final int? area;

  /// [lng, lat, lng, lat, ...] 바깥 고리들
  final List<Float32List> polygons;
}

class CityMeta {
  const CityMeta({
    required this.key,
    this.iso2,
    required this.lat,
    required this.lng,
    this.population = 0,
    this.isCapital = false,
  });

  final String key;
  final String? iso2;
  final double lat;
  final double lng;
  final int population;
  final bool isCapital;

  String get displayName => displayCityName(key);
}

class LandmarkMeta {
  const LandmarkMeta({
    required this.name,
    this.iso3,
    this.city,
    required this.lat,
    required this.lng,
    this.rank = 0,
    this.category,
    this.imagePath,
  });

  final String name;
  final String? iso3;
  final String? city;
  final double lat;
  final double lng;
  final int rank; // 1 = 세계 1위, 0 = 순위 없음
  final String? category;

  /// Storage 안 경로 (예: new_countrydex/fra_eiffel_tower.webp). 사진이 없으면 null.
  final String? imagePath;
}

class UnescoMeta {
  const UnescoMeta({
    required this.name,
    this.iso3,
    this.type,
    required this.lat,
    required this.lng,
    this.year,
  });

  final String name;
  final String? iso3;
  final String? type; // Cultural | Natural | Mixed
  final double lat;
  final double lng;
  final int? year;
}

class AirportMeta {
  const AirportMeta({
    required this.iata,
    required this.name,
    this.city,
    this.iso2,
    required this.lat,
    required this.lng,
  });

  final String iata;
  final String name;
  final String? city;
  final String? iso2;
  final double lat;
  final double lng;
}

class AirlineMeta {
  const AirlineMeta({required this.code, required this.name, this.colorHex});

  final String code;
  final String name;
  final String? colorHex;
}

class BadgeMeta {
  const BadgeMeta({
    required this.id,
    required this.name,
    this.description = '',
    this.level,
    this.category,
    this.points = 0,
    this.image,
  });

  final String id;
  final String name;
  final String description;
  final String? level; // Rookie | Explorer | Nomad | Adventurer | Globetrotter | Worldmaster
  final String? category; // Country | City | Landmarks | Flight
  final int points;

  /// 번들 썸네일 경로 (assets/badges/thumbs/...)
  final String? image;
}

/// "Chinatown(1)" -> "Chinatown"
String displayCityName(String key) {
  final match = RegExp(r'^(.*)\(\d+\)$').firstMatch(key);
  return match?.group(1) ?? key;
}

/// "KR" -> 🇰🇷
String flagEmoji(String? iso2) {
  if (iso2 == null || !RegExp(r'^[A-Z]{2}$').hasMatch(iso2)) return '🏳️';
  return String.fromCharCodes(iso2.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
}

const continentNames = {
  'Asia': 'Asia',
  'Europe': 'Europe',
  'Africa': 'Africa',
  'North America': 'N. America',
  'South America': 'S. America',
  'Oceania': 'Oceania',
  'Antarctica': 'Antarctica',
  'Seven seas (open ocean)': 'Other',
};

const continentEmoji = {
  'Asia': '🌏',
  'Europe': '🏰',
  'Africa': '🦁',
  'North America': '🗽',
  'South America': '🦜',
  'Oceania': '🏝️',
  'Antarctica': '🐧',
  'Seven seas (open ocean)': '🌊',
};

String continentLabel(String? continent) => continentNames[continent] ?? continent ?? 'Other';
