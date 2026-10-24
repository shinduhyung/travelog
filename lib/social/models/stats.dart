import 'dart:math' as math;

import '../data/geo_data.dart';
import 'social_profile.dart';

/// 한 사람의 프로필에서 GeoData를 붙여 계산하는 파생 통계.
class ProfileStats {
  ProfileStats(this.p) : geo = GeoData.I;

  final SocialProfile p;
  final GeoData geo;

  late final List<CountryMeta> countryMetas =
      p.countries.map(geo.countryByName).whereType<CountryMeta>().toList();

  late final Set<String> iso3s = countryMetas.map((c) => c.iso3).toSet();

  /// 대륙 -> 방문한 나라 수
  late final Map<String, int> continents = () {
    final m = <String, int>{};
    for (final c in countryMetas) {
      final ct = c.continent;
      if (ct == null || c.iso2 == null) continue;
      m[ct] = (m[ct] ?? 0) + 1;
    }
    return m;
  }();

  int get continentCount => continents.keys.where((c) => c != 'Seven seas (open ocean)' && c != 'Antarctica').length;

  /// 세계 나라 대비 %
  double get worldPercent => geo.totalCountries == 0 ? 0 : p.countryCount / geo.totalCountries;

  /// 방문한 나라 면적 / 전체 면적
  late final double areaPercent = () {
    final total = geo.countries.values.fold<int>(0, (s, c) => s + (c.area ?? 0));
    final mine = countryMetas.fold<int>(0, (s, c) => s + (c.area ?? 0));
    return total == 0 ? 0.0 : mine / total;
  }();

  late final double populationPercent = () {
    final total = geo.countries.values.fold<int>(0, (s, c) => s + (c.population ?? 0));
    final mine = countryMetas.fold<int>(0, (s, c) => s + (c.population ?? 0));
    return total == 0 ? 0.0 : mine / total;
  }();

  late final List<CityMeta> cityMetas = p.cities.map((k) => geo.cities[k]).whereType<CityMeta>().toList();

  int get capitalCount => cityMetas.where((c) => c.isCapital).length;

  CityMeta? get biggestCity => cityMetas.isEmpty
      ? null
      : cityMetas.reduce((a, b) => a.population >= b.population ? a : b);

  /// 나라 iso3 -> 방문 도시 수
  late final Map<String, int> citiesByCountry = () {
    final m = <String, int>{};
    for (final c in cityMetas) {
      final iso3 = geo.countryByIso2(c.iso2)?.iso3;
      if (iso3 != null) m[iso3] = (m[iso3] ?? 0) + 1;
    }
    return m;
  }();

  late final List<LandmarkMeta> landmarkMetas =
      p.landmarks.map((n) => geo.landmarks[n]).whereType<LandmarkMeta>().toList();

  /// 랜드마크 분류 -> 개수
  late final Map<String, int> landmarkCategories = () {
    final m = <String, int>{};
    for (final l in landmarkMetas) {
      final c = l.category ?? 'Other';
      m[c] = (m[c] ?? 0) + 1;
    }
    return m;
  }();

  /// 세계 순위가 있는 랜드마크 중 가장 유명한 것들
  late final List<LandmarkMeta> famousLandmarks = (landmarkMetas.where((l) => l.rank > 0).toList()
        ..sort((a, b) => a.rank.compareTo(b.rank)));

  late final Map<String, int> unescoTypes = () {
    final m = <String, int>{};
    for (final n in p.unesco) {
      final t = geo.unesco[n]?.type ?? 'Other';
      m[t] = (m[t] ?? 0) + 1;
    }
    return m;
  }();

  /// 연도 -> 그 해 처음 간 나라 수
  late final Map<int, int> newCountriesByYear = () {
    final m = <int, int>{};
    for (final name in p.countries) {
      final y = p.countryInfo[name]?.firstYear;
      if (y != null) m[y] = (m[y] ?? 0) + 1;
    }
    return m;
  }();

  /// 연도 -> 그 해까지 누적 나라 수 (연도 정보 있는 나라만)
  Map<int, int> cumulativeCountries() {
    final years = newCountriesByYear.keys.toList()..sort();
    var sum = 0;
    return {for (final y in years) y: sum += newCountriesByYear[y]!};
  }

  /// 연도 -> 그 해 여행한 나라 수 (재방문 포함)
  late final Map<int, int> activeCountriesByYear = () {
    final m = <int, int>{};
    for (final info in p.countryInfo.values) {
      for (final y in info.years) {
        m[y] = (m[y] ?? 0) + 1;
      }
    }
    return m;
  }();

  List<MapEntry<String, PlaceInfo>> get topRatedCountries =>
      (p.countryInfo.entries.where((e) => e.value.rating > 0).toList()
        ..sort((a, b) => b.value.rating.compareTo(a.value.rating)));

  List<MapEntry<String, PlaceInfo>> get mostVisitedCountries =>
      (p.countryInfo.entries.where((e) => e.value.visits > 1).toList()
        ..sort((a, b) => b.value.visits.compareTo(a.value.visits)));

  // ── 항공 ──────────────────────────────────────────────────────────

  double routeKm(FlightRoute r) {
    final a = geo.airports[r.from];
    final b = geo.airports[r.to];
    if (a == null || b == null) return 0;
    return haversineKm(a.lat, a.lng, b.lat, b.lng);
  }

  late final double totalFlightKm =
      p.flights.routes.fold(0.0, (s, r) => s + routeKm(r) * r.times);

  FlightRoute? get longestRoute {
    FlightRoute? best;
    var bestKm = 0.0;
    for (final r in p.flights.routes) {
      final km = routeKm(r);
      if (km > bestKm) {
        bestKm = km;
        best = r;
      }
    }
    return best;
  }

  /// 지구 둘레 대비
  double get earthLaps => totalFlightKm / 40075;

  MapEntry<String, int>? get topAirline => p.flights.airlines.isEmpty
      ? null
      : p.flights.airlines.entries.reduce((a, b) => a.value >= b.value ? a : b);

  MapEntry<String, int>? get topAirport =>
      p.airports.isEmpty ? null : p.airports.entries.reduce((a, b) => a.value >= b.value ? a : b);
}

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// 두 집합 비교
class SetCompare<T> {
  SetCompare(Iterable<T> mine, Iterable<T> theirs)
      : mine = mine.toSet(),
        theirs = theirs.toSet();

  final Set<T> mine;
  final Set<T> theirs;

  late final Set<T> both = mine.intersection(theirs);
  late final Set<T> onlyMine = mine.difference(theirs);
  late final Set<T> onlyTheirs = theirs.difference(mine);
  late final Set<T> union = mine.union(theirs);

  /// 자카드 유사도 0~1
  double get jaccard => union.isEmpty ? 0 : both.length / union.length;
}

/// 카테고리 하나의 승부
class CategoryResult {
  const CategoryResult(this.label, this.emoji, this.mine, this.theirs, {this.unit = ''});

  final String label;
  final String emoji;
  final num mine;
  final num theirs;
  final String unit;

  int get winner => mine == theirs ? 0 : (mine > theirs ? 1 : -1);
}

/// 나 vs 친구 전체 비교
class Comparison {
  Comparison(this.me, this.friend)
      : mine = ProfileStats(me),
        theirs = ProfileStats(friend);

  final SocialProfile me;
  final SocialProfile friend;
  final ProfileStats mine;
  final ProfileStats theirs;

  late final countries = SetCompare(me.countries, friend.countries);
  late final cities = SetCompare(me.cities, friend.cities);
  late final landmarks = SetCompare(me.landmarks, friend.landmarks);
  late final unesco = SetCompare(me.unesco, friend.unesco);
  late final airports = SetCompare(me.airports.keys, friend.airports.keys);
  late final airlines = SetCompare(me.flights.airlines.keys, friend.flights.airlines.keys);
  late final wishOverlap = SetCompare(me.countryWish, friend.countryWish).both;

  /// 친구는 가봤고 나는 아직 + 내 위시리스트에 있으면 우선
  List<String> get recommendForMe {
    final wish = me.countryWish.toSet();
    final list = countries.onlyTheirs.toList()
      ..sort((a, b) {
        final wa = wish.contains(a) ? 0 : 1;
        final wb = wish.contains(b) ? 0 : 1;
        if (wa != wb) return wa - wb;
        final ra = friend.countryInfo[a]?.rating ?? 0;
        final rb = friend.countryInfo[b]?.rating ?? 0;
        return rb.compareTo(ra);
      });
    return list;
  }

  /// DNA 유사도 0~1 (둘 다 검사했을 때만)
  double? get dnaSimilarity {
    final keys = me.dna.keys.where(friend.dna.containsKey).toList();
    if (keys.isEmpty) return null;
    final diff = keys.fold(0.0, (s, k) => s + (me.dna[k]! - friend.dna[k]!).abs()) / keys.length;
    return (1 - diff / 100).clamp(0.0, 1.0);
  }

  /// 여행 궁합 0~100
  int get compatibility {
    final parts = <(double, double)>[
      (countries.jaccard, 0.35),
      if (cities.union.isNotEmpty) (cities.jaccard, 0.15),
      if (landmarks.union.isNotEmpty) (landmarks.jaccard, 0.1),
      (_continentSimilarity, 0.15),
      if (dnaSimilarity != null) (dnaSimilarity!, 0.25),
    ];
    final weight = parts.fold(0.0, (s, p) => s + p.$2);
    if (weight == 0) return 0;
    final raw = parts.fold(0.0, (s, p) => s + p.$1 * p.$2) / weight;
    // 자카드는 값이 작게 나와서 체감에 맞게 끌어올림
    return (math.sqrt(raw) * 100).round().clamp(0, 100);
  }

  double get _continentSimilarity {
    final keys = {...mine.continents.keys, ...theirs.continents.keys};
    if (keys.isEmpty) return 0;
    var dot = 0.0, a = 0.0, b = 0.0;
    for (final k in keys) {
      final x = (mine.continents[k] ?? 0).toDouble();
      final y = (theirs.continents[k] ?? 0).toDouble();
      dot += x * y;
      a += x * x;
      b += y * y;
    }
    return (a == 0 || b == 0) ? 0 : dot / math.sqrt(a * b);
  }

  late final List<CategoryResult> categories = [
    CategoryResult('Countries', '🌍', me.countryCount, friend.countryCount),
    CategoryResult('Continents', '🗺️', mine.continentCount, theirs.continentCount),
    CategoryResult('Cities', '🏙️', me.cityCount, friend.cityCount),
    CategoryResult('Landmarks', '🗼', me.landmarkCount, friend.landmarkCount),
    CategoryResult('UNESCO', '🏛️', me.unescoCount, friend.unescoCount),
    CategoryResult('Airports', '🛫', me.airportCount, friend.airportCount),
    CategoryResult('Flights', '✈️', me.flights.total, friend.flights.total),
    CategoryResult('Badges', '🎖️', me.badgeCount, friend.badgeCount),
    CategoryResult('Quiz wins', '🧠', me.quizNormal.correct + me.quizExpert.correct,
        friend.quizNormal.correct + friend.quizExpert.correct),
  ];

  int get myWins => categories.where((c) => c.winner == 1).length;
  int get theirWins => categories.where((c) => c.winner == -1).length;

  /// 레이더 차트 축: 라벨, 내 값 0~1, 친구 값 0~1
  List<(String, double, double)> get radar {
    (String, double, double) axis(String label, num a, num b) {
      final m = math.max(a, b).toDouble();
      return (label, m == 0 ? 0 : a / m, m == 0 ? 0 : b / m);
    }

    return [
      axis('Countries', me.countryCount, friend.countryCount),
      axis('Cities', me.cityCount, friend.cityCount),
      axis('Landmarks', me.landmarkCount, friend.landmarkCount),
      axis('UNESCO', me.unescoCount, friend.unescoCount),
      axis('Flights', me.flights.total, friend.flights.total),
      axis('Quiz', me.quizNormal.correct + me.quizExpert.correct,
          friend.quizNormal.correct + friend.quizExpert.correct),
    ];
  }

  /// 둘 다 가본 나라 중 평점이 가장 다른 곳
  List<(String, double, double)> get ratingGaps {
    final list = <(String, double, double)>[];
    for (final c in countries.both) {
      final a = me.countryInfo[c]?.rating ?? 0;
      final b = friend.countryInfo[c]?.rating ?? 0;
      if (a > 0 && b > 0) list.add((c, a, b));
    }
    list.sort((x, y) => (y.$2 - y.$3).abs().compareTo((x.$2 - x.$3).abs()));
    return list;
  }

  /// 같은 해에 같은 나라를 여행한 기록
  List<(String, int)> get sameYearTrips {
    final out = <(String, int)>[];
    for (final c in countries.both) {
      final a = me.countryInfo[c]?.years.toSet() ?? const {};
      final b = friend.countryInfo[c]?.years ?? const [];
      for (final y in b) {
        if (a.contains(y)) out.add((c, y));
      }
    }
    out.sort((x, y) => y.$2.compareTo(x.$2));
    return out;
  }
}

/// 여행 DNA 축 설명 (왼쪽 = 0, 오른쪽 = 100)
const dnaAxes = {
  'budget_luxury': ('Budget', 'Luxury', '💸', '💎'),
  'relaxed_intensive': ('Relaxed', 'Packed', '🏖️', '🏃'),
  'planned_spontaneous': ('Planner', 'Spontaneous', '📋', '🎲'),
  'nature_culture': ('Nature', 'Culture', '🌲', '🏛️'),
  'solo_social': ('Solo', 'Social', '🧍', '👯'),
  'morning_night': ('Early bird', 'Night owl', '🌅', '🌙'),
  'documenter_minimalist': ('Documenter', 'Minimalist', '📸', '🎒'),
  'transit_drive': ('Transit', 'Driving', '🚆', '🚗'),
};

/// 랭크 이미지 (assets/badges)
String? rankAsset(String? rank) {
  if (rank == null) return null;
  const known = {'rookie', 'explorer', 'nomad', 'adventurer', 'globetrotter', 'worldmaster', 'legend'};
  final k = rank.toLowerCase();
  return known.contains(k) ? 'assets/badge_levels/$k.png' : null;
}

const rankLabel = {
  'Rookie': 'Rookie',
  'Explorer': 'Explorer',
  'Nomad': 'Nomad',
  'Adventurer': 'Adventurer',
  'Globetrotter': 'Globetrotter',
  'Worldmaster': 'Worldmaster',
  'Legend': 'Legend',
};
