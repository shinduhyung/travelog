// 모든 화면을 휴대폰 크기(360/412px)와 큰 글씨(1.3배)로 그려서
// RenderFlex overflow 같은 레이아웃 오류가 없는지 확인한다.
//
//   flutter test test/overflow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/screens/compare/compare_screen.dart';
import 'package:jidoapp/social/screens/duels_screen.dart';
import 'package:jidoapp/social/screens/friends_screen.dart';
import 'package:jidoapp/social/models/global_stats.dart';
import 'package:jidoapp/social/screens/leaderboard_screen.dart';
import 'package:jidoapp/social/screens/stats_screen.dart';
import 'package:jidoapp/social/services/global_stats_service.dart';

import 'fixtures.dart';

void main() {
  final layoutErrors = <String>[];

  setUpAll(setUpTestWorld);

  setUp(() {
    collectLayoutErrors(layoutErrors);
    GlobalStatsService.instance.debugLoader = () async => GlobalStats.fromMap({
          'updatedAt': '2026-10-27',
          'metrics': {
            for (final k in ['countries_total', 'countries_asia', 'gawc_cities', 'flights'])
              k: {'mean': 8.4, 'median': 6, 'hist': {'1': 5, '3': 9, '6': 7, '12': 4, '40': 1}},
          },
        });
  });

  tearDown(() => GlobalStatsService.instance.debugLoader = null);

  final screens = <String, Widget Function()>{
    'friends': () => const FriendsScreen(),
    'duels': () => const DuelsScreen(),
    'leaderboard': () => const LeaderboardScreen(),
    'stats': () => const StatsScreen(),
    for (var t = 0; t < CompareScreen.tabs.length; t++) 'compare-tab$t': () => CompareScreen(friendUid: 'f1', initialTab: t),
    for (var t = 0; t < CompareScreen.tabs.length; t++) 'compare-sparse-tab$t': () => CompareScreen(friendUid: 'f3', initialTab: t),
  };

  // 친구 순위 줄을 모두 펼친 상태
  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('friends-expanded ${size.width.toInt()}w x$scale', (tester) async {
        await pumpScreen(tester, const FriendsScreen(), size, scale);
        addTearDown(tester.view.reset);
        for (var i = 0; i < 6; i++) {
          final chevrons = find.byIcon(Icons.expand_more).hitTestable();
          if (chevrons.evaluate().isEmpty) break;
          await tester.tap(chevrons.first);
          await tester.pump(const Duration(milliseconds: 400));
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
          await tester.pump(const Duration(milliseconds: 300));
        }
        await scrollThrough(tester);
        expect(layoutErrors, isEmpty, reason: layoutErrors.toSet().join('\n---\n'));
      });
    }
  }

  for (final entry in screens.entries) {
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('${entry.key} ${size.width.toInt()}w x$scale', (tester) async {
          await pumpScreen(tester, entry.value(), size, scale);
          await scrollThrough(tester);
          addTearDown(tester.view.reset);
          expect(layoutErrors, isEmpty, reason: layoutErrors.toSet().join('\n---\n'));
        });
      }
    }
  }
}
