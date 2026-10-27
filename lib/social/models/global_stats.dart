import 'dart:math' as math;

/// 전체 유저 대비 비교에 쓰는 집계 항목. [key]는 서버 문서(public_stats/user_distributions)의 키와 같다.
enum StatMetric {
  countriesTotal('countries_total', '🌍', 'Countries visited'),
  countriesAsia('countries_asia', '🌏', 'Asia'),
  countriesEurope('countries_europe', '🏰', 'Europe'),
  countriesAfrica('countries_africa', '🦁', 'Africa'),
  countriesNorthAmerica('countries_north_america', '🗽', 'North America'),
  countriesSouthAmerica('countries_south_america', '🦜', 'South America'),
  countriesOceania('countries_oceania', '🏝️', 'Oceania'),
  gawcCities('gawc_cities', '🏙️', 'GaWC cities'),
  top250Landmarks('top250_landmarks', '🗼', 'Top 250 landmarks'),
  unesco('unesco', '🏛️', 'UNESCO sites'),
  airports('airports', '🛬', 'Airports'),
  airlines('airlines', '🛩️', 'Airlines'),
  flights('flights', '✈️', 'Flights logged');

  const StatMetric(this.key, this.emoji, this.label);

  final String key;
  final String emoji;
  final String label;

  /// 서버 대륙 이름 -> 대륙별 항목
  static const byContinent = {
    'Asia': countriesAsia,
    'Europe': countriesEurope,
    'Africa': countriesAfrica,
    'North America': countriesNorthAmerica,
    'South America': countriesSouthAmerica,
    'Oceania': countriesOceania,
  };
}

/// 한 항목의 전체 유저 분포: 값 -> 그 값을 가진 유저의 비율 (인원 수는 담지 않는다).
/// 평균/중앙값은 서버 스크립트가 계산한 값을 그대로 쓰고, 없으면 분포에서 구한다.
class MetricDistribution {
  MetricDistribution({required this.hist, double? mean, double? median})
      : n = hist.values.fold(0.0, (a, b) => a + b),
        _mean = mean,
        _median = median;

  /// 값 -> 유저 수
  final Map<int, double> hist;
  final double n;
  final double? _mean;
  final double? _median;

  factory MetricDistribution.fromMap(Map raw) {
    final hist = <int, double>{};
    ((raw['hist'] as Map?) ?? const {}).forEach((k, v) {
      final value = int.tryParse('$k');
      final count = (v as num?)?.toDouble() ?? 0;
      if (value != null && count > 0) hist[value] = count;
    });
    return MetricDistribution(
      hist: hist,
      mean: (raw['mean'] as num?)?.toDouble(),
      median: (raw['median'] as num?)?.toDouble(),
    );
  }

  bool get isEmpty => n == 0;

  double get mean {
    if (_mean != null) return _mean;
    if (n == 0) return 0;
    return hist.entries.fold(0.0, (s, e) => s + e.key * e.value) / n;
  }

  double get median {
    if (_median != null) return _median;
    if (n == 0) return 0;
    final keys = hist.keys.toList()..sort();
    var seen = 0.0;
    for (final k in keys) {
      seen += hist[k]!;
      if (seen >= n / 2) return k.toDouble();
    }
    return keys.last.toDouble();
  }

  /// "상위 X%": 나와 같거나 더 큰 값을 가진 유저의 비율 (집계 스크립트의 top_percent와 같은 정의).
  /// 값이 0이면 모수에서 빠진 유저일 수 있어 null. 분포가 없어도 null.
  double? topPercent(int value) {
    if (n == 0 || value <= 0) return null;
    var atLeast = 0.0;
    hist.forEach((k, c) {
      if (k >= value) atLeast += c;
    });
    return math.max(0.1, (atLeast * 1000 / n).round() / 10).clamp(0.1, 100.0);
  }

  /// 나보다 값이 작은 유저의 비율 (0~100). 막대 그래프용.
  double belowPercent(int value) {
    if (n == 0) return 0;
    var below = 0.0;
    hist.forEach((k, c) {
      if (k < value) below += c;
    });
    return below * 100 / n;
  }
}

/// 번들된 전체 유저 통계 (assets/user_stats.json)
class GlobalStats {
  GlobalStats({required this.distributions, this.cities = const [], this.landmarks = const [], this.updatedAt});

  final Map<String, MetricDistribution> distributions;

  /// 방문율 순 (많이 간 순)
  final List<VisitRate> cities;
  final List<VisitRate> landmarks;
  final String? updatedAt;

  MetricDistribution? of(StatMetric m) => distributions[m.key];

  bool get hasDistributions => distributions.values.any((d) => !d.isEmpty);

  factory GlobalStats.fromMap(Map raw) {
    final dist = <String, MetricDistribution>{};
    (raw['metrics'] as Map? ?? const {}).forEach((k, v) {
      if (v is Map) dist['$k'] = MetricDistribution.fromMap(v);
    });
    List<VisitRate> rates(String key) => [
          for (final r in (raw[key] as List? ?? const []))
            if (r is List && r.length >= 2) VisitRate(r[0].toString(), (r[1] as num).toDouble()),
        ];
    return GlobalStats(
      distributions: dist,
      cities: rates('cities'),
      landmarks: rates('landmarks'),
      updatedAt: raw['updatedAt']?.toString(),
    );
  }
}

/// 도시/랜드마크 하나를 가 본 유저 비율(%)
class VisitRate {
  const VisitRate(this.name, this.percent);

  final String name;
  final double percent;
}

/// 순위표 카드 한 줄. [iso2]가 있으면 국기, [sub]는 이름 아래 작은 글씨.
class RankRow {
  const RankRow({required this.label, this.sub, this.iso2, required this.value, required this.valueText});

  final String label;
  final String? sub;
  final String? iso2;
  final double value;
  final String valueText;
}

/// 순위표 카드 한 장의 내용 (제목 두 줄 + 설명 + 10줄)
class RankingData {
  const RankingData({required this.titleTop, required this.titleBottom, required this.subtitle, required this.rows});

  final String titleTop;
  final String titleBottom;
  final String subtitle;
  final List<RankRow> rows;
}
