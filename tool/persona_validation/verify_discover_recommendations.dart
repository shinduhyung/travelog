import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../lib/services/discover_recommender.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Map<String, dynamic> row(
  String id, {
  String kind = 'landmark',
  double value = 1,
  int rank = 1,
  List<String> tags = const [],
  double rate = 0,
}) => {
  'id': id,
  'kind': kind,
  'name': id,
  'country': 'XX',
  'aliases': [id],
  'candidate': true,
  'global_rank': rank,
  'recommendation_rank': rank,
  'attributes': tags,
  'visit_rate': rate,
  'scores': kind == 'landmark'
      ? {'natural_built': value, 'historic_modern': value, 'activity': value}
      : {
          'nature_culture': value,
          'activity': value,
          'cost': value,
          'difficulty': value,
        },
};

void main() {
  final policy = jsonDecode(
    File('assets/traveler_type/landmark_eligibility.json').readAsStringSync(),
  );
  final fixture = DiscoverRecommender({
    'schema_version': 1,
    'eligibility': policy,
    'places': [
      row('built'),
      row('nature', value: -1),
      row('too_low', rank: 501),
      row('unranked', rank: 0),
      row('excluded', tags: ['Sea', 'Amusement Park']),
      row('food', tags: ['Restaurant']),
      row('unknown_lake', tags: ['Lake']),
      row('popular', kind: 'country', value: .8, rate: .5),
      row('rare', kind: 'country', value: .8, rate: .001),
      row('guided_city', kind: 'city', value: -1),
    ],
  });
  List<DiscoverVisit> visits(double rating, {int count = 5}) => List.generate(
    count,
    (i) => DiscoverVisit('visited$i', {
      'natural_built': 1,
      'historic_modern': 1,
      'activity': 1,
    }, rating),
  );
  check(
    !fixture.recommend('landmark', visits(5, count: 4), {}).hasEnoughRatings,
    '4 ratings must be gated',
  );
  check(
    !fixture.recommend('landmark', [
      ...visits(5, count: 4),
      ...visits(5, count: 4),
    ], {}).hasEnoughRatings,
    'duplicate records must not unlock',
  );
  final fromLandmarks = fixture.recommend('city', const [], {}, preferenceEvidence: visits(5));
  check(fromLandmarks.hasEnoughRatings && fromLandmarks.matches.isNotEmpty,
      'Five combined ratings must unlock Soul City without any city rating');
  check(!fromLandmarks.preferences.containsKey('cost') && !fromLandmarks.preferences.containsKey('difficulty'),
      'Unknown city cost or difficulty must not be invented from landmarks');
  final stillLocked = fixture.recommend('city', const [], {}, preferenceEvidence: visits(5, count: 4));
  check(!stillLocked.hasEnoughRatings, 'Four combined ratings must remain locked');
  final liked = fixture.recommend('landmark', visits(5), {});
  final disliked = fixture.recommend('landmark', visits(1), {});
  check(
    liked.matches.first.place.id == 'built',
    'liked built experiences should favor built',
  );
  check(
    disliked.matches.first.place.id == 'nature',
    '1-star built experiences should repel built',
  );
  check(
    liked.matches.every((m) => ['built', 'nature'].contains(m.place.id)),
    'Top500 and exclusion intersection',
  );
  final neutral = fixture.recommend('landmark', visits(3), {});
  check(
    neutral.preferences['natural_built'] == 1,
    '3-star does not add signed rating preference',
  );
  final more = fixture.recommend('landmark', [
    ...visits(3),
    const DiscoverVisit('unrated', {
      'natural_built': -1,
      'historic_modern': -1,
      'activity': -1,
    }, 0),
  ], {});
  check(
    more.preferences['natural_built']! < neutral.preferences['natural_built']!,
    'unrated visits must contribute',
  );
  final country = fixture.recommend(
    'country',
    List.generate(
      5,
      (i) => DiscoverVisit('c$i', {
        'nature_culture': .8,
        'activity': .8,
        'cost': .8,
        'difficulty': .8,
      }, 5),
    ),
    {},
  );
  check(
    country.matches.first.place.id == 'popular',
    'country visit rate must affect ranking',
  );
  check(
    country.matches.first.compatibility == country.matches.last.compatibility,
    'popularity must not inflate compatibility',
  );
  check(
    country.matches.every((m) => m.popularityBonus <= .12),
    'country popularity cap',
  );
  check(
    DiscoverRecommender.surveyAxes('country', {13: 7})['nature_culture'] == -1,
    'nature/culture polarity',
  );
  check(
    DiscoverRecommender.surveyAxes('country', {1: 7})['cost'] == -1,
    'budget polarity',
  );
  check(
    !DiscoverRecommender.surveyAxes('landmark', {
      14: 7,
    }).containsKey('historic_modern'),
    'no invented historic/modern survey dimension',
  );

  final data =
      jsonDecode(
            File(
              'assets/traveler_type/discover_profiles.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final model = DiscoverRecommender(data);
  final cities = model.places
      .where((p) => p.kind == 'city' && p.candidate)
      .toList();
  check(cities.length == 202, 'City Prep must contain exactly 202 candidates');
  final namesakes = DiscoverRecommender({
    'schema_version': 1,
    'places': [
      {
        ...row('twin1', kind: 'city'),
        'aliases': ['Twin'],
        'country': 'US',
        'latitude': 40.0,
        'longitude': -70.0,
      },
      {
        ...row('twin2', kind: 'city'),
        'aliases': ['Twin'],
        'country': 'FR',
        'latitude': 48.0,
        'longitude': 2.0,
      },
    ],
  });
  check(
    namesakes.resolve('city', 'Twin') == null,
    'ambiguous city names must not guess',
  );
  check(
    namesakes
            .resolve('city', 'Twin', country: 'FR', latitude: 48, longitude: 2)
            ?.id ==
        'twin2',
    'country and coordinates resolve namesakes',
  );
  check(
    namesakes.resolve(
          'city',
          'Twin',
          country: 'FR',
          latitude: 0,
          longitude: 0,
        ) ==
        null,
    'wrong coordinates must not fall back to names',
  );

  final random = Random(30);
  final scenarios = <Map<String, dynamic>>[];
  for (final kind in ['country', 'city', 'landmark']) {
    final known = model.places
        .where((p) => p.kind == kind && p.scores.length >= 2)
        .toList();
    for (var run = 0; run < 10; run++) {
      known.shuffle(random);
      final history = known.take(15).toList();
      final evidence = [
        for (var i = 0; i < history.length; i++)
          DiscoverVisit(
            history[i].id,
            history[i].scores,
            i < 5 ? (1 + (i + run) % 5).toDouble() : 0,
          ),
      ];
      final responses = {
        for (var id in [
          1,
          2,
          13,
          14,
          15,
          16,
          19,
          20,
          24,
          26,
          29,
          30,
          33,
          36,
          39,
          41,
          47,
        ])
          id: 1 + random.nextInt(7),
      };
      final result = model.recommend(kind, evidence, responses);
      check(
        result.hasEnoughRatings && result.matches.isNotEmpty,
        'real data should produce eligible matches',
      );
      check(result.matches.length <= 3, 'default limit is three');
      for (var i = 1; i < result.matches.length; i++) {
        check(result.matches[i-1].rankScore >= result.matches[i].rankScore,
            'visible recommendation scores must be descending');
      }
      check(result.matches.every((m) => m.rankScore >= 0 && m.rankScore <= 1),
          'displayed recommendation score is bounded');

      final twin = model.recommend(kind, evidence, responses,
          includeVisited: true, applyPopularity: false);
      check(twin.matches.every((m) => m.popularityBonus == 0),
          'personality matching must not add popularity');
      final insight = model.recommend(kind, evidence, responses, limit: 0);
      check(insight.matches.isEmpty && insight.preferences.isNotEmpty,
          'insight extraction must not rank candidates');
      for (final m in result.matches) {
        check(m.place.candidate, 'out-of-scope candidate');
        check(
          !evidence.any((v) => v.key == m.place.id),
          'already visited recommended',
        );
        check(m.compatibility >= 0 && m.compatibility <= 1, 'invalid score');
        check(
          m.place.scores.keys.where(result.preferences.containsKey).length >= 2,
          'missing axes became neutral',
        );
      }
      scenarios.add({
        'kind': kind,
        'run': run,
        'rated': result.ratedCount,
        'preferences': result.preferences,
        'matches': [
          for (final m in result.matches)
            {
              'name': m.place.name,
              'country': m.place.country,
              'fit': m.compatibility,
              'rank_score': m.rankScore,
              'bonus': m.popularityBonus,
              'coverage': m.coverage,
            },
        ],
      });
    }
  }
  File(
    'tool/persona_validation/out/discover_scenarios.json',
  ).writeAsStringSync(jsonEncode(scenarios));
  print(
    'PASS: thresholds, signed ratings, unrated evidence, popularity cap, missing axes, namesakes, candidate scope; 30 real-catalog scenarios.',
  );
}
