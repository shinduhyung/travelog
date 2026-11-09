import 'dart:math';

class DiscoverPlace {
  final Map<String, dynamic> data;
  DiscoverPlace(this.data);
  String get id => data['id'] as String;
  String get kind => data['kind'] as String;
  String get name => data['name'] as String;
  String get country => data['country'] as String;
  bool get candidate => data['candidate'] == true;
  double get visitRate => (data['visit_rate'] as num? ?? 0).toDouble();
  Map<String, double> get scores => (data['scores'] as Map).map(
    (k, v) => MapEntry(k as String, (v as num).toDouble()),
  );
}

class DiscoverVisit {
  final String key;
  final Map<String, double> scores;
  final double rating;
  const DiscoverVisit(this.key, this.scores, this.rating);
}

class DiscoverMatch {
  final DiscoverPlace place;
  final double compatibility, popularityBonus, coverage, rankScore;
  const DiscoverMatch(
    this.place,
    this.compatibility,
    this.popularityBonus,
    this.coverage,
    this.rankScore,
  );
}

class DiscoverResult {
  final int ratedCount;
  final Map<String, double> preferences;
  final List<DiscoverMatch> matches;
  bool get hasEnoughRatings => ratedCount >= 5;
  const DiscoverResult(this.ratedCount, this.preferences, this.matches);
}

/// Pure Dart, using only reviewed source-backed axes. No API calls at runtime.
class DiscoverRecommender {
  final List<DiscoverPlace> places;
  final Map<String, dynamic> policy;
  final Map<String, List<DiscoverPlace>> _lookup = {};
  late final Set<String> _excludedNames =
      (policy['excluded_catalog_names'] as List? ?? [])
          .cast<String>()
          .map(_key)
          .toSet();
  late final Set<String> _excludedTags =
      (policy['excluded_attributes'] as List? ?? []).cast<String>().toSet();
  late final Map<String, Set<String>> _allowlists = {
    for (final tag in ['Lake', 'Island'])
      tag: (policy['${tag.toLowerCase()}_allowlist'] as List? ?? [])
          .cast<String>()
          .map(_key)
          .toSet(),
  };
  final Map<String, List<DiscoverPlace>> _candidates = {};
  final Map<String, Map<String, double>> _scales = {};
  DiscoverRecommender(Map<String, dynamic> data)
    : policy = Map<String, dynamic>.from(data['eligibility'] as Map? ?? {}),
      places = (data['places'] as List)
          .map((r) => DiscoverPlace(Map<String, dynamic>.from(r as Map)))
          .toList() {
    if (data['schema_version'] != 1) {
      throw const FormatException('Discover schema');
    }
    for (final p in places) {
      for (final alias
          in (p.data['aliases'] as List).cast<String>().map(_key).toSet()) {
        _lookup.putIfAbsent('${p.kind}|$alias', () => []).add(p);
      }
    }
  }
  static double _axisScale(List<DiscoverPlace> candidates, String axis) {
    final values = [
      for (final p in candidates)
        if (p.scores.containsKey(axis)) p.scores[axis]!,
    ];
    if (values.length < 2) return .25;
    final mean = values.reduce((a, b) => a + b) / values.length;
    return max(
      .25,
      sqrt(
        values.fold<double>(0, (sum, x) => sum + pow(x - mean, 2)) /
            values.length,
      ),
    );
  }

  static String _key(String s) =>
      s.toLowerCase().trim().split(RegExp(r'\s+')).join(' ');

  bool isEligibleLandmark(String name, List<String> tags) {
    if (tags.any(_excludedTags.contains)) {
      return false;
    }
    final key = _key(name);
    if (_excludedNames.contains(key)) return false;
    for (final tag in ['Lake', 'Island']) {
      if (tags.contains(tag) && !_allowlists[tag]!.contains(key)) return false;
    }
    return true;
  }

  DiscoverPlace? resolve(
    String kind,
    String name, {
    String? country,
    double? latitude,
    double? longitude,
  }) {
    if (kind == 'country' && country != null) {
      final found = places
          .where((p) => p.kind == kind && p.country == country)
          .toList();
      return found.length == 1 ? found.single : null;
    }
    var found = (_lookup['$kind|${_key(name)}'] ?? <DiscoverPlace>[])
        .where((p) => country == null || p.country == country)
        .toList();
    if (latitude != null && longitude != null) {
      double km(DiscoverPlace p) {
        const rad = pi / 180;
        final lat = (p.data['latitude'] as num).toDouble();
        final lon = (p.data['longitude'] as num).toDouble();
        final h =
            pow(sin((lat - latitude) * rad / 2), 2) +
            cos(lat * rad) *
                cos(latitude * rad) *
                pow(sin((lon - longitude) * rad / 2), 2);
        return 12742 * asin(sqrt(h.clamp(0, 1)));
      }

      found = found.where((p) => km(p) < (kind == 'landmark' ? 1 : 20)).toList()
        ..sort((a, b) => km(a).compareTo(km(b)));
      if (found.isNotEmpty) return found.first;
    }
    return found.length == 1 ? found.single : null;
  }

  static Map<String, double> surveyAxes(String kind, Map<int, int> responses) {
    // These are explicit questionnaire anchors, not mappings of unrelated DNA axes.
    final anchors = <String, Map<int, double>>{
      if (kind == 'landmark')
        'natural_built': {13: -1, 14: 1, 15: 1, 16: -1, 30: -1, 41: 1}
      else
        'nature_culture': {13: -1, 14: 1, 16: -1, 30: -1, 47: -1},
      'activity': {2: -1, 13: -1, 16: 1, 26: 1, 29: 1, 33: -1, 36: -1, 41: 1},
      if (kind != 'landmark')
        'cost': {1: -1, 2: 1, 3: -1, 19: -1, 20: 1, 39: 1},
      if (kind != 'landmark') 'difficulty': {24: 1},
      // The survey has no direct historic/modern question; learn it from records.
    };
    final result = <String, double>{};
    for (final axis in anchors.entries) {
      double total = 0, weight = 0;
      for (final anchor in axis.value.entries) {
        final answer = responses[anchor.key];
        if (answer == null || answer < 1 || answer > 7) continue;
        total += (answer - 4) / 3 * anchor.value;
        weight += anchor.value.abs();
      }
      if (weight > 0) result[axis.key] = total / weight;
    }
    return result;
  }

  DiscoverResult recommend(
    String kind,
    List<DiscoverVisit> evidence,
    Map<int, int> responses, {
    Set<String> excludedIds = const {},
    int limit = 3,
    bool includeVisited = false,
    bool applyPopularity = true,
    int minimumRatings = 5,
    List<DiscoverVisit>? preferenceEvidence,
    // Score just this place (used by detail modals). It bypasses the candidate
    // and visited filters but uses the same preferences, scales and formula.
    DiscoverPlace? only,
  }) {
    final unique = {for (final v in evidence) v.key: v};
    final visits = unique.values.toList();
    final taste = preferenceEvidence == null
        ? visits
        : {for (final v in preferenceEvidence) v.key: v}.values.toList();
    final rated = taste
        .where((v) => v.rating.isFinite && v.rating >= 1 && v.rating <= 5)
        .length;
    if (rated < minimumRatings)
      return DiscoverResult(rated, const {}, const []);
    final survey = surveyAxes(kind, responses);
    final weights = kind == 'landmark'
        ? {'natural_built': 1.5, 'historic_modern': 1.0, 'activity': 1.0}
        : {
            'nature_culture': 1.5,
            'activity': 1.0,
            'cost': 1.0,
            'difficulty': .6,
          };
    final prefs = <String, double>{};
    for (final axis in weights.keys) {
      final known = taste
          .map((v) {
            final scores = Map<String, double>.from(v.scores);
            if (axis == 'nature_culture' &&
                !scores.containsKey(axis) &&
                scores.containsKey('natural_built')) {
              scores[axis] = scores['natural_built']!;
            }
            if (axis == 'natural_built' &&
                !scores.containsKey(axis) &&
                scores.containsKey('nature_culture')) {
              scores[axis] = scores['nature_culture']!;
            }
            return DiscoverVisit(v.key, scores, v.rating);
          })
          .where((v) => v.scores.containsKey(axis))
          .toList();
      double numerator = 0, denominator = 0;
      if (survey.containsKey(axis)) {
        numerator += survey[axis]!;
        denominator++;
      }
      if (known.isNotEmpty) {
        numerator +=
            known.fold<double>(0, (sum, v) => sum + v.scores[axis]!) /
            known.length;
        denominator++;
      }
      double ratingSum = 0, ratingMass = 0;
      for (final visit in known) {
        if (!visit.rating.isFinite || visit.rating < 1 || visit.rating > 5) {
          continue;
        }
        final centered = (visit.rating - 3) / 2;
        ratingSum += centered * visit.scores[axis]!;
        ratingMass += centered.abs();
      }
      if (ratingMass > 0) {
        numerator += 4 * ratingSum / ratingMass;
        denominator += 4;
      }
      if (denominator > 0) {
        prefs[axis] = (numerator / denominator).clamp(-1.0, 1.0);
      }
    }
    if (limit <= 0) return DiscoverResult(rated, prefs, const []);
    final candidates = _candidates.putIfAbsent(
      kind,
      () => places
          .where(
            (p) =>
                p.kind == kind &&
                p.candidate &&
                (kind != 'landmark' ||
                    ((p.data['recommendation_rank'] as num? ?? 0) > 0 &&
                        (p.data['recommendation_rank'] as num? ?? 0) <= 500 &&
                        isEligibleLandmark(
                          p.name,
                          (p.data['attributes'] as List? ?? []).cast<String>(),
                        ))),
          )
          .toList(),
    );
    // Standardize each axis by the actual candidate spread. The old raw
    // distance compressed most near-average places into the high 90s.
    final scales = _scales.putIfAbsent(
      kind,
      () => {
        for (final axis in weights.keys) axis: _axisScale(candidates, axis),
      },
    );
    final maxRate = candidates.fold<double>(0, (m, p) => max(m, p.visitRate));
    final results = <DiscoverMatch>[];
    for (final p in only != null ? [only] : candidates) {
      if (only == null &&
          ((!includeVisited && unique.containsKey(p.id)) ||
              excludedIds.contains(p.id)))
        continue;
      final scores = p.scores;
      final shared = weights.keys
          .where((a) => prefs.containsKey(a) && scores.containsKey(a))
          .toList();
      if (shared.length < 2) continue;
      final mass = shared.fold<double>(0, (s, a) => s + weights[a]!);
      final allMass = weights.values.reduce((a, b) => a + b);
      final distance =
          shared.fold<double>(
            0,
            (sum, axis) =>
                sum +
                weights[axis]! *
                    (prefs[axis]! - scores[axis]!).abs() /
                    scales[axis]!,
          ) /
          mass;
      final fit = exp(-1.5 * distance);
      final coverage = mass / allMass;
      final bonus = applyPopularity && kind == 'country' && maxRate > 0
          ? .12 * sqrt(p.visitRate / maxRate)
          : 0.0;
      results.add(
        DiscoverMatch(
          p,
          fit,
          bonus,
          coverage,
          (fit + bonus * (1 - fit)) * (.75 + .25 * coverage),
        ),
      );
    }
    results.sort((a, b) {
      var result = b.rankScore.compareTo(a.rankScore);
      if (result == 0 && applyPopularity)
        result = b.place.visitRate.compareTo(a.place.visitRate);
      return result == 0 ? a.place.id.compareTo(b.place.id) : result;
    });
    return DiscoverResult(rated, prefs, results.take(limit).toList());
  }
}
