// 실시간 대결 화면의 모든 단계(대기실, 3-2-1, 문제, 정답 공개, 결과)를
// 7가지 문제 유형 × 휴대폰 크기 × 큰 글씨로 그려서 레이아웃 오류가 없는지 확인한다.
//
//   flutter test test/duel_game_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/models/duel.dart';
import 'package:jidoapp/social/screens/duel_game_screen.dart';

import 'fixtures.dart';

const _clock = 1800000000000;

Duel _at(
  Duel base, {
  String? status,
  int? round,
  int? startMs,
  Map<int, DuelRound>? rounds,
  String? createdBy,
  int? createdMs,
  String? forfeitBy,
}) => Duel(
  id: base.id,
  players: base.players,
  createdBy: createdBy ?? base.createdBy,
  status: status ?? base.status,
  mode: base.mode,
  difficulty: base.difficulty,
  scoring: base.scoring,
  questions: base.questions,
  rounds: rounds ?? base.rounds,
  scores: base.scores,
  round: round ?? base.round,
  roundStartMs: startMs ?? base.roundStartMs,
  roundEndsMs: (startMs ?? base.roundStartMs!) + base.timeLimitMs,
  timeLimitMs: base.timeLimitMs,
  winner: base.winner,
  forfeitBy: forfeitBy,
  createdMs: createdMs ?? base.createdMs,
);

void main() {
  final layoutErrors = <String>[];

  setUpAll(() async {
    await setUpTestWorld();
    DuelGameScreen.offlineImages = true;
  });

  setUp(() => collectLayoutErrors(layoutErrors));

  final base = testDuel('g1', 'me', 'f1', status: 'playing', round: 0, scoring: 'speed');
  final states = <String, Duel>{
    'lobby-mine': _at(base, status: 'invited', createdMs: _clock - 1000),
    'lobby-incoming': _at(base, status: 'invited', createdBy: 'f1', createdMs: _clock - 1000),
    'declined': _at(base, status: 'declined'),
    'countdown': _at(base, round: 0, startMs: _clock + 2500, rounds: const {}),
    for (var i = 0; i < testDuelTypes.length; i++) ...{
      'question-${testDuelTypes[i]}': _at(
        base,
        round: i,
        startMs: _clock - 3000,
        rounds: {
          i: const DuelRound(answered: {'f1'}),
        },
      ),
      'reveal-${testDuelTypes[i]}': _at(
        base,
        round: i + 1,
        startMs: _clock + 2000,
        rounds: {
          i: DuelRound(
            answered: const {'me', 'f1'},
            answer: 1,
            detail: testQuestion(testDuelTypes[i]).choices.length == 2
                ? const ['12,345 km', '1,993 km']
                : const ['110K people', '216.4M people', '102.3M people', '34.4M people'],
            picks: const {
              'me': DuelPick(choice: 0, ms: 2000, ok: false, points: 0),
              'f1': DuelPick(choice: 1, ms: 3000, ok: true, points: 850),
            },
            closedMs: _clock - 500,
          ),
        },
      ),
    },
    'results': testDuel('g2', 'me', 'f1'),
    'results-forfeit': _at(testDuel('g3', 'me', 'f1'), forfeitBy: 'f1'),
    'results-legacy': testDuel('g4', 'me', 'f1', legacy: true),
  };

  for (final entry in states.entries) {
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('${entry.key} ${size.width.toInt()}w x$scale', (tester) async {
          final controller = StreamController<Duel>();
          await pumpScreen(
            tester,
            DuelGameScreen(matchId: entry.value.id, debugStream: controller.stream, debugClock: () => _clock),
            size,
            scale,
          );
          controller.add(entry.value);
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }
          await scrollThrough(tester);
          // 문제 단계에서는 보기를 하나 눌러 본다
          if (entry.key.startsWith('question')) {
            final tiles = find.byType(GestureDetector).hitTestable();
            if (tiles.evaluate().isNotEmpty) await tester.tap(tiles.last, warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
          }
          expect(layoutErrors, isEmpty, reason: layoutErrors.toSet().join('\n---\n'));
          await tester.pumpWidget(const SizedBox());
          unawaited(controller.close());
          tester.view.reset();
        });
      }
    }
  }
}
