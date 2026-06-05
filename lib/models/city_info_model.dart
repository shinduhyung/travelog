// lib/models/city_info_model.dart

class CityInfo {
  final String population;
  final int? areaKm2;
  final String? gdp;
  final String? timezone;
  final bool isCapital;
  final bool isLargestCity;
  final int costLevel;           // 1(cheap) ~ 5(expensive)
  final List<String> geography;
  final List<String> history;
  final List<String> transportation;
  final List<String> tips;
  final List<String> tags;
  final List<String> highlights; // landmark names in desired order

  CityInfo({
    required this.population,
    this.areaKm2,
    this.gdp,
    this.timezone,
    required this.isCapital,
    required this.isLargestCity,
    required this.costLevel,
    required this.geography,
    required this.history,
    required this.transportation,
    required this.tips,
    required this.tags,
    required this.highlights,
  });

  factory CityInfo.fromJson(Map<String, dynamic> json) {
    return CityInfo(
      population: json['population'] as String? ?? 'N/A',
      areaKm2: json['area_km2'] as int?,
      gdp: json['gdp'] as String?,
      timezone: json['timezone'] as String?,
      isCapital: json['is_capital'] as bool? ?? false,
      isLargestCity: json['is_largest'] as bool? ?? false,
      costLevel: json['cost_level'] as int? ?? 0,
      geography: List<String>.from(json['geography'] as List<dynamic>? ?? []),
      history: List<String>.from(json['history'] as List<dynamic>? ?? []),
      transportation: List<String>.from(json['transportation'] as List<dynamic>? ?? []),
      tips: List<String>.from(json['tips'] as List<dynamic>? ?? []),
      tags: List<String>.from(json['tags'] as List<dynamic>? ?? []),
      highlights: List<String>.from(json['highlights'] as List<dynamic>? ?? []),
    );
  }
}