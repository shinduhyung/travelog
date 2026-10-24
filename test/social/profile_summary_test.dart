import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/data/geo_data.dart';
import 'package:jidoapp/social/models/social_profile.dart';
import 'package:jidoapp/social/models/stats.dart';

GeoData _geo() => GeoData.fromJsonStrings([
      jsonEncode({
        'JPN': {'n': 'Japan', 'a2': 'JP', 'ct': 'Asia', 'p': [], 'area': 100, 'pop': 10},
        'FRA': {'n': 'France', 'a2': 'FR', 'ct': 'Europe', 'p': [], 'area': 100, 'pop': 10},
        'KOR': {'n': 'South Korea', 'a2': 'KR', 'ct': 'Asia', 'p': [], 'area': 100, 'pop': 10},
        'BRA': {'n': 'Brazil', 'a2': 'BR', 'ct': 'South America', 'p': [], 'area': 700, 'pop': 70},
      }),
      jsonEncode({
        'Tokyo': ['JP', 35.7, 139.7, 37000000, 1],
        'Paris': ['FR', 48.9, 2.35, 2000000, 1],
        'Paris(1)': ['US', 33.7, -95.6, 25000, 0],
      }),
      jsonEncode({'Eiffel Tower': ['FRA', 'Paris', 48.9, 2.3, 1, 'Tower']}),
      jsonEncode({'Historic Kyoto': ['JPN', 'Cultural', 35.0, 135.8, '1994']}),
      jsonEncode({
        'ICN': ['Incheon', 'Seoul', 'KR', 37.46, 126.44],
        'CDG': ['Charles de Gaulle', 'Paris', 'FR', 49.01, 2.55],
      }),
      jsonEncode({'KE': ['Korean Air', '#00A0DE']}),
    ]);

void main() {
  setUp(() => GeoData.setForTest(_geo()));

  test('Travelog 원본 데이터를 친구 공개용 요약으로 만든다', () {
    final profile = ProfileSummaryBuilder.build(
      uid: 'u1',
      displayName: 'me',
      now: DateTime(2026, 10, 19),
      user: {
        'selectedPassportIso': 'KOR',
        'country_visits_v2': jsonEncode({
          'Japan': {
            'isVisited': true,
            'rating': 4.5,
            'visitCount': 3,
            'visitDateRanges': [
              {'arrival': '2019-04-01T00:00:00.000'},
              {'arrival': '2023-08-10T00:00:00.000'},
            ],
          },
          'France': {'isVisited': true, 'hasLived': true},
          'Brazil': {'isVisited': false, 'isWishlisted': true},
        }),
        'city_visit_details_v3': jsonEncode({
          'Tokyo': {'isWishlisted': false, 'isHome': true, 'rating': 5},
          'Paris': {},
          'Rio de Janeiro': {'isWishlisted': true},
        }),
        'visited_landmarks': ['Eiffel Tower'],
        'unesco_visited_sites': ['Historic Kyoto'],
        'visited_subregions': jsonEncode({'Japan': ['Kanto', 'Kansai'], 'France': ['Île-de-France']}),
        'airport_visit_history': jsonEncode({'ICN': [{}, {}], 'CDG': [{}]}),
        'saved_airlines_data': jsonEncode([
          {
            'code': 'KE',
            'logs': [
              {'times': 2, 'departureIata': 'ICN', 'arrivalIata': 'CDG', 'seatClass': 'Economy'},
              {'times': 1, 'departureIata': 'ICN', 'arrivalIata': 'CDG', 'isCanceled': true},
            ],
          },
        ]),
        'dna_final_scores': jsonEncode({'budget_luxury': 30.0, 'morning_night': 80}),
      },
      badges: {'badgeIds': ['a', 'b', 'c'], 'currentRank': 'Explorer'},
      gameScores: {
        'flag_guess_scores_hard': jsonEncode([{'score': 12.5}, {'score': 30}]),
        'insane_trial_used_flag': true,
      },
      quizNormal: [
        MapEntry('20261019', {'isCorrect': true}),
        MapEntry('20261018', {'isCorrect': false}),
        MapEntry('20261016', {'isCorrect': true}),
      ],
    );

    expect(profile.countries, ['France', 'Japan']);
    expect(profile.countryWish, ['Brazil']);
    expect(profile.countryInfo['Japan']!.years, [2019, 2023]);
    expect(profile.countryInfo['Japan']!.rating, 4.5);
    expect(profile.countryInfo['Japan']!.visits, 3);
    expect(profile.livedCountries, ['France']);
    expect(profile.cities, ['Paris', 'Tokyo']);
    expect(profile.cityWish, ['Rio de Janeiro']);
    expect(profile.homeCity, 'Tokyo');
    expect(profile.subregionCount, 3);
    expect(profile.airports, {'ICN': 2, 'CDG': 1});
    expect(profile.flights.total, 2); // 취소된 비행 제외
    expect(profile.flights.airlines, {'KE': 2});
    expect(profile.flights.routes.single.from, 'ICN');
    expect(profile.dna['morning_night'], 80);
    expect(profile.badgeCount, 3);
    expect(profile.gameBest, {'flag_guess_scores_hard': 30});
    expect(profile.quizNormal.correct, 2);
    expect(profile.quizNormal.streak(DateTime(2026, 10, 19)), 2);
    expect(profile.quizNormal.bestStreak, 2);
  });

  test('Firestore 왕복과 공개 범위', () {
    final p = ProfileSummaryBuilder.build(
      uid: 'u',
      displayName: 'x',
      user: {
        'country_visits_v2': jsonEncode({'Japan': {'isVisited': true, 'rating': 4}}),
        'city_visit_details_v3': jsonEncode({'Tokyo': {}}),
        'dna_final_scores': jsonEncode({'budget_luxury': 30}),
      },
    );
    final open = SocialProfile.fromMap('u', p.toSummaryFields(const PrivacySettings()));
    expect(open.countryInfo['Japan']!.rating, 4);
    expect(open.cities, ['Tokyo']);
    expect(open.dna, isNotEmpty);

    final closed = SocialProfile.fromMap('u', p.toSummaryFields(const PrivacySettings(cities: false, dna: false)));
    expect(closed.cities, isEmpty);
    expect(closed.dna, isEmpty);
    expect(closed.countries, ['Japan']);
  });

  test('비교: 겹치는 나라, 궁합, 카테고리 승부', () {
    SocialProfile make(String uid, List<String> countries, {Map<String, double> dna = const {}}) =>
        SocialProfile(uid: uid, displayName: uid, countries: countries, dna: dna);
    final me = make('me', ['Japan', 'France'], dna: {'budget_luxury': 30, 'morning_night': 80});
    final friend = make('f', ['Japan', 'Brazil', 'South Korea'], dna: {'budget_luxury': 40, 'morning_night': 70});
    final cmp = Comparison(me, friend);

    expect(cmp.countries.both, {'Japan'});
    expect(cmp.countries.onlyMine, {'France'});
    expect(cmp.countries.onlyTheirs, {'Brazil', 'South Korea'});
    expect(cmp.dnaSimilarity, closeTo(0.9, 0.001));
    expect(cmp.compatibility, inInclusiveRange(1, 100));
    expect(cmp.categories.first.winner, -1); // 나라 수는 친구가 더 많음
    expect(cmp.mine.continentCount, 2);
    expect(cmp.recommendForMe.toSet(), {'Brazil', 'South Korea'});
  });

  test('도시 키 "(n)" 접미사와 국기', () {
    expect(displayCityName('Paris(1)'), 'Paris');
    expect(GeoData.I.countryOfCity('Paris(1)'), isNull); // US는 테스트 데이터에 없음
    expect(GeoData.I.countryOfCity('Tokyo')!.name, 'Japan');
    expect(flagEmoji('KR'), '🇰🇷');
  });

  test('Firestore에 저장할 수 있는 형태 (배열 안의 배열 금지)', () {
    final p = ProfileSummaryBuilder.build(
      uid: 'u',
      displayName: 'x',
      user: {
        'saved_airlines_data': jsonEncode([
          {
            'code': 'KE',
            'logs': [
              {'times': 2, 'departureIata': 'ICN', 'arrivalIata': 'CDG'},
              {'times': 1, 'departureIata': 'CDG', 'arrivalIata': 'ICN'},
            ],
          },
        ]),
        'country_visits_v2': jsonEncode({
          'Japan': {'isVisited': true, 'visitDateRanges': [{'arrival': '2020-01-01'}]},
        }),
      },
    );
    final fields = p.toSummaryFields(const PrivacySettings());

    void check(dynamic v, String path, {bool insideList = false}) {
      if (v is List) {
        expect(insideList, isFalse, reason: 'nested array at $path');
        for (var i = 0; i < v.length; i++) {
          check(v[i], '$path[$i]', insideList: true);
        }
      } else if (v is Map) {
        v.forEach((k, x) => check(x, '$path.$k'));
      } else if (v is double) {
        expect(v.isFinite, isTrue, reason: 'non-finite number at $path');
      }
    }

    check(fields, 'profile');
    // 왕복해도 노선이 그대로
    final back = SocialProfile.fromMap('u', fields);
    expect(back.flights.routes.length, 2);
    expect(back.flights.routes.first.times, 2);
  });

  test('방문 날짜: 여러 형식을 읽고 처음/마지막을 남긴다', () {
    expect(ProfileSummaryBuilder.dateOf('2019-04-01T00:00:00.000'), '2019-04-01');
    expect(ProfileSummaryBuilder.dateOf('2024.5.3'), '2024-05-03');
    expect(ProfileSummaryBuilder.dateOf({'year': 2020, 'month': 7}), '2020-07');
    expect(ProfileSummaryBuilder.dateOf({'year': 2021}), '2021');
    expect(ProfileSummaryBuilder.dateOf('unknown'), isNull);

    final p = ProfileSummaryBuilder.build(
      uid: 'u',
      displayName: 'x',
      user: {
        'country_visits_v2': jsonEncode({
          'Japan': {
            'isVisited': true,
            'visitDateRanges': [
              {'arrival': '2023-08-10T00:00:00.000'},
              {'arrival': '2019-04-01T00:00:00.000'},
            ],
          },
        }),
        'landmark_visit_history': jsonEncode({
          'Eiffel Tower': [
            {'year': 2018, 'month': 6, 'day': 2},
            {'year': 2022, 'month': 1, 'day': 15},
          ],
        }),
        'landmark_ratings': jsonEncode({'Eiffel Tower': 4.5}),
        'airport_visit_history': jsonEncode({'ICN': [{'year': 2023, 'month': 3, 'day': 1}]}),
        'saved_airlines_data': jsonEncode([
          {
            'code': 'KE',
            'logs': [
              {'date': '2023-03-01', 'departureIata': 'ICN', 'arrivalIata': 'CDG', 'flightNumber': 'KE901'},
              {'date': '2024-01-09', 'departureIata': 'CDG', 'arrivalIata': 'ICN'},
            ],
          },
        ]),
      },
    );
    expect(p.countryInfo['Japan']!.first, '2019-04-01');
    expect(p.countryInfo['Japan']!.last, '2023-08-10');
    expect(p.landmarkInfo['Eiffel Tower']!.visits, 2);
    expect(p.landmarkInfo['Eiffel Tower']!.first, '2018-06-02');
    expect(p.landmarkInfo['Eiffel Tower']!.rating, 4.5);
    expect(p.airportInfo['ICN']!.first, '2023-03-01');
    expect(p.flightLog.first.date, '2024-01-09'); // 최신순
    expect(p.flightLog.last.number, 'KE901');

    // 저장 후 다시 읽어도 그대로
    final back = SocialProfile.fromMap('u', p.toSummaryFields(const PrivacySettings()));
    expect(back.landmarkInfo['Eiffel Tower']!.last, '2022-01-15');
    expect(back.flightLog.length, 2);
    expect(back.countryInfo['Japan']!.first, '2019-04-01');
  });

  test('비행 거리', () {
    final p = SocialProfile(
      uid: 'u',
      displayName: 'u',
      flights: const FlightStats(total: 2, routes: [FlightRoute('ICN', 'CDG', 2)]),
    );
    final km = ProfileStats(p).totalFlightKm;
    expect(km, closeTo(2 * 8960, 200)); // 인천-파리 약 8,960km
  });
}
