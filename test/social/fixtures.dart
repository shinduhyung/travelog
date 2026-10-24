// 화면 테스트 공용: 가짜 프로필/대결 데이터, 휴대폰 크기로 그리기, 레이아웃 오류 수집.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/data/geo_data.dart';
import 'package:jidoapp/social/models/duel.dart';
import 'package:jidoapp/social/social_hub.dart';
import 'package:jidoapp/social/models/social_profile.dart';
import 'package:jidoapp/social/services/social_store.dart';
import 'package:jidoapp/social/theme.dart';
import 'package:jidoapp/social/widgets/cards.dart';

const sizes = [Size(360, 740), Size(412, 915)];
const scales = [1.0, 1.3];

late SocialStore store;

SocialProfile testProfile(String uid, String name, int seed, {bool rich = true, String plan = 'none', String home = 'KOR'}) {
  final geo = GeoData.I;
  final rnd = Random(seed);
  List<T> pick<T>(List<T> all, int n) => (List.of(all)..shuffle(rnd)).take(n).toList();

  final countryNames = geo.countries.values.where((c) => c.iso2 != null).map((c) => c.name).toList();
  final countries = pick(countryNames, rich ? 60 + rnd.nextInt(30) : 3)..sort();
  final cityKeys = geo.cities.keys.where((k) => geo.cities[k]!.population > 500000).toList();
  final cities = pick(cityKeys, rich ? 120 : 2)..sort();
  final landmarks = pick(geo.landmarks.values.where((l) => l.rank > 0 && l.rank < 120).map((l) => l.name).toList(), rich ? 25 : 0);
  final unesco = pick(geo.unesco.keys.toList(), rich ? 30 : 0);
  final airports = pick(['ICN', 'NRT', 'CDG', 'JFK', 'LHR', 'SIN', 'BKK', 'DXB', 'LAX', 'SYD', 'HKG', 'FRA'], rich ? 10 : 0);

  return SocialProfile(
    uid: uid,
    displayName: name,
    homeCountryIso3: home,
    plan: plan,
    countries: countries,
    countryInfo: {
      for (final c in countries)
        c: () {
          final y = 2010 + rnd.nextInt(16);
          final m = 1 + rnd.nextInt(12);
          return PlaceInfo(
            rating: rnd.nextInt(6).toDouble(),
            visits: 1 + rnd.nextInt(4),
            lived: rnd.nextInt(15) == 0,
            years: [y, if (rnd.nextBool()) y + 1],
            first: '$y-${m.toString().padLeft(2, '0')}-0${1 + rnd.nextInt(9)}',
            last: rnd.nextBool() ? '${y + 1}-0${1 + rnd.nextInt(9)}' : null,
          );
        }(),
    },
    countryWish: pick(countryNames.where((c) => !countries.contains(c)).toList(), rich ? 12 : 0),
    cities: cities,
    cityInfo: {
      if (cities.isNotEmpty) cities.first: const PlaceInfo(home: true, rating: 5),
      for (final c in cities.skip(1).take(20)) c: PlaceInfo(rating: rnd.nextInt(6).toDouble(), first: '2019-0${1 + rnd.nextInt(9)}'),
    },
    cityWish: pick(cityKeys, rich ? 8 : 0),
    landmarks: landmarks,
    landmarkWish: pick(geo.landmarks.keys.toList(), rich ? 6 : 0),
    landmarkInfo: {
      for (final l in landmarks)
        l: PlaceInfo(
          visits: 1 + rnd.nextInt(3),
          first: '201${rnd.nextInt(10)}-0${1 + rnd.nextInt(9)}-1${rnd.nextInt(10)}',
          rating: rnd.nextInt(6).toDouble(),
        ),
    },
    unesco: unesco,
    unescoInfo: {for (final u in unesco.take(10)) u: PlaceInfo(visits: 1, first: '2021-0${1 + rnd.nextInt(9)}')},
    subregionCount: rich ? 37 : 0,
    airports: {for (final a in airports) a: 1 + rnd.nextInt(9)},
    airportInfo: {
      for (final a in airports)
        a: PlaceInfo(visits: 1 + rnd.nextInt(9), first: '2015-0${1 + rnd.nextInt(9)}-01', last: '2025-1${rnd.nextInt(3)}-20'),
    },
    flightLog: rich
        ? [
            for (var i = 0; i < 40; i++)
              FlightEntry(
                date: '202${5 - i ~/ 10}-${(12 - i % 12).toString().padLeft(2, '0')}-1${i % 10}',
                from: const ['ICN', 'NRT', 'CDG', 'JFK', 'SIN'][i % 5],
                to: const ['LHR', 'SYD', 'BKK', 'DXB', 'LAX'][i % 5],
                airline: const ['KE', 'OZ', 'SQ', 'XX9'][i % 4],
                number: i.isEven ? 'KE90$i' : null,
              ),
          ]
        : const [],
    flights: rich
        ? FlightStats(
            total: 212,
            airlines: const {'KE': 80, 'OZ': 40, 'SQ': 22, 'LH': 12, 'AF': 9, 'EK': 7, 'TG': 5, 'NH': 4},
            routes: const [
              FlightRoute('ICN', 'NRT', 20),
              FlightRoute('ICN', 'CDG', 6),
              FlightRoute('ICN', 'JFK', 4),
              FlightRoute('SIN', 'SYD', 2),
              FlightRoute('LHR', 'LAX', 1),
              FlightRoute('DXB', 'BKK', 3),
            ],
            aircraft: const {'Boeing 787-9 Dreamliner': 30, 'Airbus A380-800': 12, 'Airbus A321neo': 8},
            seatClasses: const {'Economy': 180, 'Premium Economy': 20, 'Business': 12},
          )
        : const FlightStats(),
    dna: rich
        ? {
            for (final k in const [
              'budget_luxury',
              'relaxed_intensive',
              'planned_spontaneous',
              'nature_culture',
              'solo_social',
              'morning_night',
              'documenter_minimalist',
              'transit_drive',
            ])
              k: rnd.nextInt(101).toDouble(),
          }
        : const {},
    badgeIds: [for (var i = 0; i < (rich ? 87 : 1); i++) 'b$i'],
    badgeRank: rich ? 'Globetrotter' : 'Rookie',
    quizNormal: QuizStats(
      solved: 240,
      correct: 190,
      days: {
        for (var d = 0; d < 120; d++)
          if (rnd.nextInt(4) != 0) QuizStats.keyOf(DateTime.now().subtract(Duration(days: d))): rnd.nextBool(),
      },
    ),
    quizExpert: const QuizStats(solved: 40, correct: 21),
    gameBest: rich
        ? const {
            'flag_guess_scores_insane': 18450.5,
            'border_chain_scores_hard': 42,
            'higher_or_lower_scores_population_insane': 31,
            'which_is_farther_scores_expert': 2210,
            'timezone_impostor_scores_insane': 17,
          }
        : const {},
    updatedAt: DateTime(2026, 10, 19, 14, 30),
  );
}

/// 유형별 대표 문제 (긴 이름으로 넘침 확인)
DuelQuestion testQuestion(String type) {
  const countries = [
    DuelChoice(label: 'Saint Vincent and the Grenadines', flag: 'VC'),
    DuelChoice(label: 'Brazil', flag: 'BR'),
    DuelChoice(label: 'Democratic Republic of the Congo', flag: 'CD'),
    DuelChoice(label: 'Peru', flag: 'PE'),
  ];
  return switch (type) {
    'flag' => const DuelQuestion(
      type: 'flag',
      prompt: 'Which country is this flag?',
      flag: 'BR',
      choices: [
        DuelChoice(label: 'Saint Vincent and the Grenadines'),
        DuelChoice(label: 'Brazil'),
        DuelChoice(label: 'Democratic Republic of the Congo'),
        DuelChoice(label: 'Peru'),
      ],
    ),
    'capital' => const DuelQuestion(
      type: 'capital',
      prompt: 'What is the capital of Saint Vincent and the Grenadines?',
      flag: 'VC',
      subject: 'Saint Vincent and the Grenadines',
      choices: [
        DuelChoice(label: 'Kingstown'),
        DuelChoice(label: 'Sri Jayawardenepura Kotte'),
        DuelChoice(label: 'Brasília'),
        DuelChoice(label: 'Lima'),
      ],
    ),
    'landmark' => const DuelQuestion(
      type: 'landmark',
      prompt: 'Which country is this landmark in?',
      image: 'https://example.com/x.webp',
      subject: 'Christ the Redeemer of Rio de Janeiro',
      choices: countries,
    ),
    'farther' => const DuelQuestion(
      type: 'farther',
      prompt: 'Which is farther from Ouagadougou?',
      flag: 'BF',
      subject: 'Ouagadougou',
      choices: [
        DuelChoice(label: 'Santa Cruz de la Sierra', flag: 'BO'),
        DuelChoice(label: 'Brazzaville', flag: 'CG'),
      ],
    ),
    'population' || 'area' => DuelQuestion(type: type, prompt: 'Which country has the most people?', choices: countries),
    _ => const DuelQuestion(
      type: 'city',
      prompt: 'Which country is Thiruvananthapuram in?',
      subject: 'Thiruvananthapuram',
      choices: countries,
    ),
  };
}

const testDuelTypes = ['flag', 'capital', 'landmark', 'farther', 'population', 'area', 'city'];

Duel testDuel(
  String id,
  String me,
  String friend, {
  String status = 'finished',
  String? createdBy,
  String mode = 'mixed',
  String scoring = 'speed',
  String difficulty = 'hard',
  int round = 10,
  int? roundStartMs,
  bool legacy = false,
}) {
  final questions = [for (var i = 0; i < 10; i++) testQuestion(testDuelTypes[i % testDuelTypes.length])];
  final now = DateTime.now().millisecondsSinceEpoch;
  final rounds = <int, DuelRound>{
    for (var i = 0; i < round && i < 10; i++)
      i: DuelRound(
        answered: {me, friend},
        answer: 1,
        detail: questions[i].type == 'farther'
            ? const ['12,345 km', '1,993 km']
            : (questions[i].type == 'population' ? const ['110K people', '216.4M people', '102.3M people', '34.4M people'] : null),
        picks: {
          me: DuelPick(choice: 1, ms: 2300, ok: true, points: 885),
          if (i.isEven) friend: const DuelPick(choice: 0, ms: 5100, ok: false, points: 0),
        },
        closedMs: 1000 + i,
      ),
  };
  return Duel(
    id: id,
    players: [me, friend],
    createdBy: createdBy ?? me,
    status: status,
    mode: mode,
    difficulty: difficulty,
    scoring: scoring,
    questions: questions,
    rounds: rounds,
    scores: {me: 885 * round.clamp(0, 10), friend: 0},
    round: round.clamp(0, 9),
    roundStartMs: roundStartMs ?? now - 2000,
    roundEndsMs: (roundStartMs ?? now - 2000) + 10000,
    timeLimitMs: 10000,
    winner: status == 'finished' ? me : null,
    createdMs: status == 'invited' ? now - 1000 : DateTime(2026, 10, 19).millisecondsSinceEpoch,
    legacy: legacy,
  );
}

Future<void> pumpScreen(WidgetTester tester, Widget screen, Size size, double scale) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: SocialScope(store: store, child: child!),
      ),
      home: screen,
    ),
  );
  // 애니메이션(링, 게이지)과 지연 레이아웃 정리
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// 스크롤해 가며 화면 끝까지 그려 본다 (ListView는 보이는 부분만 만든다)
Future<void> scrollThrough(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  for (var i = 0; i < 25; i++) {
    final target = scrollables.evaluate().where((e) {
      final s = e.widget as Scrollable;
      return s.axisDirection == AxisDirection.down;
    }).toList();
    if (target.isEmpty) return;
    await tester.dragFrom(const Offset(180, 500), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// 모든 화면 테스트가 같은 데이터로 시작하도록
Future<void> setUpTestWorld() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  useGoogleFonts = false;
  LandmarkImage.offline = true;
  await GeoData.load();
  final me = testProfile('me', 'ahndoong', 1, plan: 'lifetime');
  final friends = [
    testProfile('f1', 'Alexandria Montgomery-Smith the Third', 2, plan: 'yearly', home: 'AUS'),
    testProfile('f2', 'Min', 3, plan: 'monthly', home: 'AUT'),
    testProfile('f3', 'NewUser', 4, rich: false),
  ];
  store = SocialStore.test(
    uid: 'me',
    me: me,
    friends: friends,
    duels: [
      testDuel('d1', 'me', 'f1', status: 'invited', createdBy: 'f1', mode: 'farther', difficulty: 'insane'),
      testDuel('d2', 'me', 'f2', status: 'invited', mode: 'landmark'),
      testDuel('d5', 'me', 'f2', status: 'playing', round: 3, mode: 'population', scoring: 'first'),
      testDuel('d3', 'me', 'f1', mode: 'population'),
      testDuel('d4', 'me', 'f3', mode: 'flag', legacy: true),
    ],
  );
  SocialHub.debugStore = store;
}

/// 각 테스트 전에 호출: 레이아웃 오류를 [errors]에 모은다
void collectLayoutErrors(List<String> errors) {
  errors.clear();
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed') ||
        msg.contains('RenderFlex') ||
        msg.contains('BoxConstraints') ||
        msg.contains('unbounded') ||
        msg.contains('was not laid out')) {
      errors.add(
        '${msg.split('\n').first}\n'
        '${details.informationCollector?.call().take(4).map((e) => e.toString()).join('\n') ?? ''}',
      );
    } else {
      errors.add('OTHER: $msg');
    }
  };
}
