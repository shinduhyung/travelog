import 'dart:math';

class TouristCityVisit {
  final String name;
  final double ratio;
  final int visits;
  final String country;
  const TouristCityVisit(
    this.name,
    this.ratio,
    this.visits, {
    this.country = '',
  });
}

class TouristLocalResult {
  final double tourist;
  double get local => 100 - tourist;
  final List<TouristCityVisit> covered;
  final int total;
  final Map<String, double> percentiles;
  const TouristLocalResult(
    this.tourist,
    this.covered,
    this.total, {
    this.percentiles = const {},
  });
}

class TouristLocalModel {
  static TouristLocalResult combine(
    TouristLocalResult? cities,
    double surveyLocal,
  ) {
    final behaviorTourist = 100 - surveyLocal.clamp(0.0, 100.0);
    final cityWeight = cities == null
        ? 0.0
        : .35 * min(1.0, cities.covered.length / 5);
    final tourist =
        behaviorTourist * (1 - cityWeight) +
        (cities?.tourist ?? behaviorTourist) * cityWeight;
    return TouristLocalResult(
      tourist,
      cities?.covered ?? const [],
      cities?.total ?? 0,
      percentiles: cities?.percentiles ?? const {},
    );
  }

  static TouristLocalResult? score(
    List<double> reference,
    List<TouristCityVisit> visits,
    int total,
  ) {
    final known = reference.where((v) => v.isFinite && v > 0).toList()..sort();
    final unique = {
      for (final city in visits)
        if (city.ratio.isFinite && city.ratio > 0 && city.visits > 0)
          city.name: city,
    };
    if (known.length < 2 || unique.isEmpty || known.first == known.last)
      return null;
    double sum = 0, mass = 0;
    final percentiles = <String, double>{};
    for (final city in unique.values) {
      final below = known.where((v) => v < city.ratio).length;
      final equal = known.where((v) => v == city.ratio).length;
      final percentile = (below + equal / 2) / known.length;
      percentiles[city.name] = percentile;
      final weight = min(2.0, sqrt(city.visits));
      sum += percentile * weight;
      mass += weight;
    }
    final covered = unique.values.toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
    return TouristLocalResult(
      100 * sum / mass,
      covered,
      total,
      percentiles: percentiles,
    );
  }
}
