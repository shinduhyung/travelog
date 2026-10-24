import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// profiles/{uid} 문서 (v2). 친구에게 공개되는 요약만 담는다.
/// 원본(users/{uid} 등)은 본인만 읽을 수 있으므로, 이 앱이 본인 데이터를 읽어서
/// [ProfileSummaryBuilder]로 요약한 뒤 여기에 쓴다.
class SocialProfile {
  const SocialProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.homeCountryIso3,
    this.countries = const [],
    this.countryInfo = const {},
    this.countryWish = const [],
    this.cities = const [],
    this.cityInfo = const {},
    this.cityWish = const [],
    this.landmarks = const [],
    this.landmarkWish = const [],
    this.landmarkInfo = const {},
    this.unesco = const [],
    this.unescoInfo = const {},
    this.subregionCount = 0,
    this.airports = const {},
    this.airportInfo = const {},
    this.flights = const FlightStats(),
    this.flightLog = const [],
    this.dna = const {},
    this.badgeIds = const [],
    this.badgeRank,
    this.plan = 'none',
    this.quizNormal = const QuizStats(),
    this.quizExpert = const QuizStats(),
    this.gameBest = const {},
    this.privacy = const PrivacySettings(),
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? homeCountryIso3;

  /// 방문한 나라 이름 (Travelog country_visits_v2 키 = custom.geo.json name, 정렬됨)
  final List<String> countries;
  final Map<String, PlaceInfo> countryInfo;
  final List<String> countryWish;

  /// 방문한 도시 키 ("(n)" 접미사 포함)
  final List<String> cities;
  final Map<String, PlaceInfo> cityInfo;
  final List<String> cityWish;

  final List<String> landmarks;
  final List<String> landmarkWish;

  /// 랜드마크/유산별 방문 기록 (횟수, 날짜, 별점)
  final Map<String, PlaceInfo> landmarkInfo;
  final List<String> unesco;
  final Map<String, PlaceInfo> unescoInfo;
  final int subregionCount;

  /// IATA -> 방문 횟수
  final Map<String, int> airports;
  final Map<String, PlaceInfo> airportInfo;
  final FlightStats flights;

  /// 최근 비행 기록 (날짜 내림차순, 최대 300개)
  final List<FlightEntry> flightLog;

  /// 여행 DNA 8축 (0~100). 비어 있으면 아직 검사 안 함.
  final Map<String, double> dna;

  final List<String> badgeIds;
  final String? badgeRank;

  /// 유료 등급: lifetime | yearly | monthly | none (서버가 결제 기록으로 정함)
  final String plan;

  bool get isPremium => plan != 'none';
  final QuizStats quizNormal;
  final QuizStats quizExpert;

  /// 미니게임 최고 점수. 키는 Travelog의 저장 키 (예: flag_guess_scores_hard)
  final Map<String, num> gameBest;
  final PrivacySettings privacy;
  final DateTime? updatedAt;

  int get countryCount => countries.length;
  int get cityCount => cities.length;
  int get landmarkCount => landmarks.length;
  int get unescoCount => unesco.length;
  int get badgeCount => badgeIds.length;
  int get airportCount => airports.length;

  Iterable<String> get livedCountries =>
      countryInfo.entries.where((e) => e.value.lived).map((e) => e.key);

  String? get homeCity =>
      cityInfo.entries.where((e) => e.value.home).map((e) => e.key).firstOrNull;

  factory SocialProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SocialProfile.fromMap(doc.id, doc.data() ?? const {});

  factory SocialProfile.fromMap(String uid, Map<String, dynamic> d) {
    List<String> strings(String key) =>
        (d[key] as List?)?.map((e) => e.toString()).toList() ?? const [];

    Map<String, PlaceInfo> places(String key) => ((d[key] as Map?) ?? const {})
        .map((k, v) => MapEntry(k.toString(), PlaceInfo.fromMap(v)));

    return SocialProfile(
      uid: uid,
      displayName: d['displayName']?.toString() ?? 'Traveler',
      photoUrl: d['photoUrl']?.toString(),
      homeCountryIso3: d['homeCountryIso3']?.toString(),
      countries: strings('countries'),
      countryInfo: places('countryInfo'),
      countryWish: strings('countryWish'),
      cities: strings('cities'),
      cityInfo: places('cityInfo'),
      cityWish: strings('cityWish'),
      landmarks: strings('landmarks'),
      landmarkWish: strings('landmarkWish'),
      landmarkInfo: places('landmarkInfo'),
      unesco: strings('unesco'),
      unescoInfo: places('unescoInfo'),
      subregionCount: (d['subregionCount'] as num?)?.toInt() ?? 0,
      airports: ((d['airports'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 1)),
      airportInfo: places('airportInfo'),
      flights: FlightStats.fromMap(d['flights']),
      flightLog: [
        for (final f in (d['flightLog'] as List? ?? const []))
          if (f is Map) FlightEntry.fromMap(f),
      ],
      dna: ((d['dna'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 50)),
      badgeIds: strings('badgeIds'),
      badgeRank: d['badgeRank']?.toString(),
      plan: d['plan']?.toString() ?? 'none',
      quizNormal: QuizStats.fromMap(d['quizNormal']),
      quizExpert: QuizStats.fromMap(d['quizExpert']),
      gameBest: ((d['gameBest'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v is num ? v : 0)),
      privacy: PrivacySettings.fromMap(d['privacy']),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// displayName/photoUrl/privacy는 사용자가 이 앱에서 정하므로 요약 동기화 때는 쓰지 않는다.
  /// 공개를 끈 항목은 빈 값으로 덮어써서 예전에 올라간 값도 지운다.
  Map<String, dynamic> toSummaryFields(PrivacySettings p) {
    Map<String, dynamic> placeMap(Map<String, PlaceInfo> m) =>
        {for (final e in m.entries) if (!e.value.isDefault) e.key: e.value.toMap()};

    return {
      'v': 2,
      'homeCountryIso3': homeCountryIso3,
      'countries': countries,
      'countryInfo': placeMap(countryInfo),
      'countryWish': p.wishlist ? countryWish : const <String>[],
      'cities': p.cities ? cities : const <String>[],
      'cityInfo': p.cities ? placeMap(cityInfo) : const <String, dynamic>{},
      'cityWish': p.cities && p.wishlist ? cityWish : const <String>[],
      'landmarks': landmarks,
      'landmarkWish': p.wishlist ? landmarkWish : const <String>[],
      'landmarkInfo': placeMap(landmarkInfo),
      'unesco': unesco,
      'unescoInfo': placeMap(unescoInfo),
      'subregionCount': subregionCount,
      'airports': p.flights ? airports : const <String, int>{},
      'flights': p.flights ? flights.toMap() : const FlightStats().toMap(),
      'airportInfo': p.flights ? placeMap(airportInfo) : const <String, dynamic>{},
      'flightLog': p.flights ? [for (final f in flightLog) f.toMap()] : const <Map<String, dynamic>>[],
      'dna': p.dna ? dna : const <String, double>{},
      'badgeIds': badgeIds,
      'badgeRank': badgeRank,
      'quizNormal': quizNormal.toMap(),
      'quizExpert': quizExpert.toMap(),
      'gameBest': gameBest,
      // 목록/랭킹에서 문서를 다 풀지 않고 쓰는 숫자
      'countryCount': countryCount,
      'cityCount': p.cities ? cityCount : 0,
      'landmarkCount': landmarkCount,
      'unescoCount': unescoCount,
      'badgeCount': badgeCount,
      'flightCount': p.flights ? flights.total : 0,
    };
  }
}

/// 나라/도시 하나에 대한 기록
class PlaceInfo {
  const PlaceInfo({
    this.rating = 0,
    this.visits = 0,
    this.lived = false,
    this.home = false,
    this.years = const [],
    this.first,
    this.last,
  });

  final double rating; // 0 = 평가 안 함, 1~5
  final int visits;
  final bool lived;
  final bool home;
  final List<int> years; // 방문한 해 (오름차순, 중복 없음)

  /// 처음/마지막 방문일. "2019-04-01", "2019-04", "2019"처럼 아는 만큼만.
  final String? first;
  final String? last;

  int? get firstYear => years.isEmpty ? null : years.first;

  bool get isDefault => rating == 0 && visits <= 1 && !lived && !home && years.isEmpty && first == null && last == null;

  factory PlaceInfo.fromMap(dynamic raw) {
    if (raw is! Map) return const PlaceInfo();
    return PlaceInfo(
      rating: (raw['r'] as num?)?.toDouble() ?? 0,
      visits: (raw['c'] as num?)?.toInt() ?? 0,
      lived: raw['l'] == true,
      home: raw['h'] == true,
      years: (raw['y'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      first: raw['d0']?.toString(),
      last: raw['d1']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        if (rating > 0) 'r': rating,
        if (visits > 1) 'c': visits,
        if (lived) 'l': true,
        if (home) 'h': true,
        if (years.isNotEmpty) 'y': years,
        if (first != null) 'd0': first,
        if (last != null && last != first) 'd1': last,
      };
}

/// 비행 한 번 (Travelog saved_airlines_data의 logs)
class FlightEntry {
  const FlightEntry({this.date, required this.from, required this.to, this.airline, this.number});

  final String? date; // "2024-05-03" 등 아는 만큼
  final String from;
  final String to;
  final String? airline; // 항공사 코드
  final String? number; // 편명

  factory FlightEntry.fromMap(Map raw) => FlightEntry(
        date: raw['d']?.toString(),
        from: raw['f']?.toString() ?? '',
        to: raw['t']?.toString() ?? '',
        airline: raw['a']?.toString(),
        number: raw['no']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        if (date != null) 'd': date,
        'f': from,
        't': to,
        if (airline != null) 'a': airline,
        if (number != null && number!.isNotEmpty) 'no': number,
      };
}

class FlightRoute {
  const FlightRoute(this.from, this.to, this.times);

  final String from; // IATA
  final String to;
  final int times;
}

class FlightStats {
  const FlightStats({
    this.total = 0,
    this.airlines = const {},
    this.routes = const [],
    this.aircraft = const {},
    this.seatClasses = const {},
  });

  final int total;
  final Map<String, int> airlines; // 항공사 코드 -> 탑승 횟수
  final List<FlightRoute> routes;
  final Map<String, int> aircraft;
  final Map<String, int> seatClasses;

  factory FlightStats.fromMap(dynamic raw) {
    if (raw is! Map) return const FlightStats();
    Map<String, int> counts(String key) => ((raw[key] as Map?) ?? const {})
        .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    return FlightStats(
      total: (raw['n'] as num?)?.toInt() ?? 0,
      airlines: counts('al'),
      routes: [
        for (final r in (raw['rt'] as List? ?? const []))
          if (r is Map && r['f'] != null && r['t'] != null)
            FlightRoute('${r['f']}', '${r['t']}', (r['n'] as num?)?.toInt() ?? 1),
      ],
      aircraft: counts('ac'),
      seatClasses: counts('cls'),
    );
  }

  Map<String, dynamic> toMap() => {
        'n': total,
        'al': airlines,
        // Firestore는 배열 안의 배열을 저장하지 못해서 맵으로
        'rt': [for (final r in routes) {'f': r.from, 't': r.to, 'n': r.times}],
        'ac': aircraft,
        'cls': seatClasses,
      };
}

class QuizStats {
  const QuizStats({this.solved = 0, this.correct = 0, this.days = const {}});

  final int solved;
  final int correct;

  /// "20261018" -> 맞혔는지 (최근 1년치)
  final Map<String, bool> days;

  double get accuracy => solved == 0 ? 0 : correct / solved;

  /// 오늘(또는 어제)까지 연속으로 푼 날 수
  int streak(DateTime today) {
    var day = DateTime(today.year, today.month, today.day);
    if (!days.containsKey(_key(day))) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while (days.containsKey(_key(day))) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get bestStreak {
    final sorted = days.keys.map(_parse).whereType<DateTime>().toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  static String _key(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parse(String s) {
    if (!RegExp(r'^\d{8}$').hasMatch(s)) return null;
    return DateTime(int.parse(s.substring(0, 4)), int.parse(s.substring(4, 6)), int.parse(s.substring(6, 8)));
  }

  static String keyOf(DateTime d) => _key(d);

  factory QuizStats.fromMap(dynamic raw) {
    if (raw is! Map) return const QuizStats();
    return QuizStats(
      solved: (raw['solved'] as num?)?.toInt() ?? 0,
      correct: (raw['correct'] as num?)?.toInt() ?? 0,
      days: ((raw['days'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), v == 1 || v == true)),
    );
  }

  /// quiz_history 문서들 (문서 id = "yyyyMMdd")
  factory QuizStats.fromHistory(Iterable<MapEntry<String, Map<String, dynamic>>> docs, {DateTime? now}) {
    var solved = 0;
    var correct = 0;
    final days = <String, bool>{};
    final cutoff = QuizStats.keyOf((now ?? DateTime.now()).subtract(const Duration(days: 366)));
    for (final d in docs) {
      solved++;
      final ok = d.value['isCorrect'] == true;
      if (ok) correct++;
      if (d.key.compareTo(cutoff) > 0) days[d.key] = ok;
    }
    return QuizStats(solved: solved, correct: correct, days: days);
  }

  Map<String, dynamic> toMap() => {
        'solved': solved,
        'correct': correct,
        'days': days.map((k, v) => MapEntry(k, v ? 1 : 0)),
      };
}

/// 친구에게 무엇을 보여줄지. 나라·랜드마크·UNESCO·퀴즈·게임은 항상 공개.
class PrivacySettings {
  const PrivacySettings({this.cities = true, this.flights = true, this.dna = true, this.wishlist = true});

  final bool cities;
  final bool flights;
  final bool dna;
  final bool wishlist;

  factory PrivacySettings.fromMap(dynamic raw) {
    if (raw is! Map) return const PrivacySettings();
    return PrivacySettings(
      cities: raw['cities'] != false,
      flights: raw['flights'] != false,
      dna: raw['dna'] != false,
      wishlist: raw['wishlist'] != false,
    );
  }

  PrivacySettings copyWith({bool? cities, bool? flights, bool? dna, bool? wishlist}) => PrivacySettings(
        cities: cities ?? this.cities,
        flights: flights ?? this.flights,
        dna: dna ?? this.dna,
        wishlist: wishlist ?? this.wishlist,
      );

  Map<String, dynamic> toMap() => {'cities': cities, 'flights': flights, 'dna': dna, 'wishlist': wishlist};
}

/// Travelog 원본 데이터 → 친구 공개용 요약.
/// 필드 의미는 travelogdata/lib/services/travel_data_parser.dart, jidoapp 모델과 같다.
class ProfileSummaryBuilder {
  static const gameScorePrefixes = [
    'which_is_farther_scores_',
    'border_chain_scores_',
    'flag_guess_scores_',
    'timezone_impostor_scores_',
    'higher_or_lower_scores_',
  ];

  static const maxRoutes = 300;

  static SocialProfile build({
    required String uid,
    required String displayName,
    Map<String, dynamic>? user,
    Map<String, dynamic>? badges,
    Map<String, dynamic>? gameScores,
    Iterable<MapEntry<String, Map<String, dynamic>>> quizNormal = const [],
    Iterable<MapEntry<String, Map<String, dynamic>>> quizExpert = const [],
    DateTime? now,
  }) {
    final u = user ?? const {};
    final badgeIds = badges?['badgeIds'];
    final countries = _places(u['country_visits_v2'], visited: (v) => v['isVisited'] == true);
    final cities = _places(u['city_visit_details_v3'], visited: (v) => v['isWishlisted'] != true);

    return SocialProfile(
      uid: uid,
      displayName: displayName,
      homeCountryIso3: (u['selectedPassportIso'] ?? u['homeCountryIso3'])?.toString(),
      countries: countries.visited.keys.toList()..sort(),
      countryInfo: countries.visited,
      countryWish: countries.wish..sort(),
      cities: cities.visited.keys.toList()..sort(),
      cityInfo: cities.visited,
      cityWish: cities.wish..sort(),
      landmarks: _strings(u['visited_landmarks'])..sort(),
      landmarkWish: _strings(u['wishlisted_landmarks'])..sort(),
      landmarkInfo: _history(u['landmark_visit_history'], u['landmark_ratings']),
      unesco: _strings(u['unesco_visited_sites'])..sort(),
      unescoInfo: _history(u['unesco_history'], u['unesco_ratings']),
      subregionCount: _subregionCount(u['visited_subregions']),
      airports: _airports(u['airport_visit_history']),
      airportInfo: _history(u['airport_visit_history'], u['airport_ratings']),
      flights: _flights(u['saved_airlines_data']),
      flightLog: _flightLog(u['saved_airlines_data']),
      dna: u['dna_is_calculated'] == false ? const {} : _dna(u['dna_final_scores']),
      badgeIds: badgeIds is List ? badgeIds.map((e) => e.toString()).toList() : const [],
      badgeRank: badges?['currentRank']?.toString(),
      quizNormal: QuizStats.fromHistory(quizNormal, now: now),
      quizExpert: QuizStats.fromHistory(quizExpert, now: now),
      gameBest: _gameBest(gameScores ?? const {}),
    );
  }

  static dynamic _decode(dynamic raw) {
    if (raw is String) {
      try {
        return json.decode(raw);
      } catch (_) {
        return null;
      }
    }
    return raw;
  }

  static List<String> _strings(dynamic raw) {
    final list = _decode(raw);
    return list is List ? list.map((e) => e.toString()).toList() : <String>[];
  }

  /// country_visits_v2 / city_visit_details_v3 공통: 키 -> {isVisited|isWishlisted, hasLived,
  /// isHome, rating, visitCount, visitDateRanges[{arrival}]}
  static ({Map<String, PlaceInfo> visited, List<String> wish}) _places(
    dynamic raw, {
    required bool Function(Map v) visited,
  }) {
    final map = _decode(raw);
    final out = <String, PlaceInfo>{};
    final wish = <String>[];
    if (map is! Map) return (visited: out, wish: wish);
    map.forEach((key, v) {
      if (v is! Map) return;
      if (!visited(v)) {
        if (v['isWishlisted'] == true) wish.add(key.toString());
        return;
      }
      final ranges = v['visitDateRanges'];
      final years = <int>{
        if (ranges is List)
          for (final r in ranges)
            if (r is Map) ?_year(r['arrival'] ?? r['arrivalDate']),
        ?_year(v['arrivalDate']),
      }.toList()
        ..sort();
      final dates = <String>[
        if (ranges is List)
          for (final r in ranges)
            if (r is Map) ?dateOf(r['arrival'] ?? r['arrivalDate']),
        ?dateOf(v['arrivalDate']),
      ]..sort();
      out[key.toString()] = PlaceInfo(
        rating: (v['rating'] as num?)?.toDouble() ?? 0,
        visits: (v['visitCount'] as num?)?.toInt() ?? (ranges is List ? ranges.length : 1),
        lived: v['hasLived'] == true,
        home: v['isHome'] == true,
        years: years,
        first: dates.firstOrNull,
        last: dates.lastOrNull,
      );
    });
    return (visited: out, wish: wish);
  }

  /// 날짜 표현을 "YYYY-MM-DD" / "YYYY-MM" / "YYYY"로. 모르면 null.
  /// ISO 문자열, "2024.5.3", {year, month, day} 맵을 받는다.
  static String? dateOf(dynamic raw) {
    int? y, m, d;
    if (raw is Map) {
      y = (raw['year'] as num?)?.toInt();
      m = (raw['month'] as num?)?.toInt();
      d = (raw['day'] as num?)?.toInt();
    } else if (raw is String) {
      final match = RegExp(r'^(\d{4})(?:[-./](\d{1,2}))?(?:[-./](\d{1,2}))?').firstMatch(raw.trim());
      if (match == null) return null;
      y = int.parse(match.group(1)!);
      m = match.group(2) == null ? null : int.parse(match.group(2)!);
      d = match.group(3) == null ? null : int.parse(match.group(3)!);
    }
    if (y == null || y < 1900 || y > 2200) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    if (m == null || m < 1 || m > 12) return '$y';
    if (d == null || d < 1 || d > 31) return '$y-${two(m)}';
    return '$y-${two(m)}-${two(d)}';
  }

  /// 이름 -> [{year, month, day, ...}] 형태의 방문 기록 (랜드마크, UNESCO, 공항)
  static Map<String, PlaceInfo> _history(dynamic raw, dynamic ratingsRaw) {
    final map = _decode(raw);
    final ratings = _decode(ratingsRaw);
    final out = <String, PlaceInfo>{};
    if (map is Map) {
      map.forEach((key, visits) {
        if (visits is! List) return;
        final dates = visits.map(dateOf).whereType<String>().toList()..sort();
        final years = dates.map((d) => int.parse(d.substring(0, 4))).toSet().toList()..sort();
        out[key.toString()] = PlaceInfo(
          visits: visits.length,
          years: years,
          first: dates.firstOrNull,
          last: dates.lastOrNull,
        );
      });
    }
    if (ratings is Map) {
      ratings.forEach((key, r) {
        if (r is! num || r <= 0) return;
        final cur = out[key.toString()] ?? const PlaceInfo();
        out[key.toString()] = PlaceInfo(
          rating: r.toDouble(),
          visits: cur.visits,
          years: cur.years,
          first: cur.first,
          last: cur.last,
        );
      });
    }
    return out;
  }

  static const maxFlightLog = 300;

  static List<FlightEntry> _flightLog(dynamic raw) {
    final list = _decode(raw);
    if (list is! List) return const [];
    final out = <FlightEntry>[];
    for (final a in list) {
      if (a is! Map) continue;
      final code = (a['code']?.toString().isNotEmpty == true ? a['code'] : a['code3'])?.toString();
      for (final log in (a['logs'] as List? ?? const [])) {
        if (log is! Map || log['isCanceled'] == true) continue;
        final dep = log['departureIata']?.toString();
        final arr = log['arrivalIata']?.toString();
        if (dep == null || arr == null || dep.isEmpty || arr.isEmpty) continue;
        out.add(FlightEntry(
          date: dateOf(log['date']),
          from: dep,
          to: arr,
          airline: code,
          number: log['flightNumber']?.toString(),
        ));
      }
    }
    out.sort((x, y) => (y.date ?? '').compareTo(x.date ?? ''));
    return out.take(maxFlightLog).toList();
  }

  static int? _year(dynamic raw) {
    if (raw is! String || raw.length < 4) return null;
    final y = int.tryParse(raw.substring(0, 4));
    return (y != null && y > 1900 && y < 2200) ? y : null;
  }

  static int _subregionCount(dynamic raw) {
    final map = _decode(raw);
    if (map is! Map) return 0;
    return map.values.fold(0, (n, v) => n + (v is List ? v.length : 0));
  }

  static Map<String, int> _airports(dynamic raw) {
    final map = _decode(raw);
    if (map is! Map) return const {};
    return {
      for (final e in map.entries)
        if (e.value is List && (e.value as List).isNotEmpty) e.key.toString(): (e.value as List).length,
    };
  }

  /// saved_airlines_data: [{code, code3, logs: [{times, departureIata, arrivalIata, aircraft, seatClass, isCanceled}]}]
  static FlightStats _flights(dynamic raw) {
    final list = _decode(raw);
    if (list is! List) return const FlightStats();
    var total = 0;
    final airlines = <String, int>{};
    final routes = <String, int>{};
    final aircraft = <String, int>{};
    final classes = <String, int>{};
    for (final a in list) {
      if (a is! Map) continue;
      final code = (a['code']?.toString().isNotEmpty == true ? a['code'] : a['code3'])?.toString();
      for (final log in (a['logs'] as List? ?? const [])) {
        if (log is! Map || log['isCanceled'] == true) continue;
        final times = ((log['times'] as num?)?.toInt() ?? 1).clamp(1, 1000);
        total += times;
        if (code != null && code.isNotEmpty) airlines[code] = (airlines[code] ?? 0) + times;
        final dep = log['departureIata']?.toString();
        final arr = log['arrivalIata']?.toString();
        if (dep != null && arr != null && dep.length == 3 && arr.length == 3) {
          routes['$dep-$arr'] = (routes['$dep-$arr'] ?? 0) + times;
        }
        final ac = log['aircraft']?.toString();
        if (ac != null && ac.isNotEmpty) aircraft[ac] = (aircraft[ac] ?? 0) + times;
        final cls = log['seatClass']?.toString();
        if (cls != null && cls.isNotEmpty) classes[cls] = (classes[cls] ?? 0) + times;
      }
    }
    final sortedRoutes = routes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return FlightStats(
      total: total,
      airlines: airlines,
      routes: [
        for (final e in sortedRoutes.take(maxRoutes))
          FlightRoute(e.key.substring(0, 3), e.key.substring(4), e.value),
      ],
      aircraft: aircraft,
      seatClasses: classes,
    );
  }

  static Map<String, double> _dna(dynamic raw) {
    final map = _decode(raw);
    if (map is! Map) return const {};
    return {
      for (final e in map.entries)
        if (e.value is num) e.key.toString(): (e.value as num).toDouble(),
    };
  }

  /// 각 게임 저장 키의 값은 점수 기록 리스트(JSON 문자열). 모든 게임이
  /// 높은 점수가 좋은 방식이라 최댓값만 남긴다.
  static Map<String, num> _gameBest(Map<String, dynamic> gameScores) {
    final best = <String, num>{};
    gameScores.forEach((key, raw) {
      if (!gameScorePrefixes.any(key.startsWith)) return;
      final records = _decode(raw);
      if (records is! List) return;
      num? top;
      for (final r in records) {
        final score = r is Map ? r['score'] : null;
        if (score is num && (top == null || score > top)) top = score;
      }
      if (top != null) best[key] = top;
    });
    return best;
  }
}
