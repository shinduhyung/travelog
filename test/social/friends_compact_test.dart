// 친구 화면: 작은 "Add friend" 버튼 → 시트(Invite / Enter code), 통계 칸 → 프로필
//
//   flutter test test/friends_compact_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/screens/friends_screen.dart';
import 'package:jidoapp/social/screens/profile_screen.dart';

import 'fixtures.dart';

void main() {
  final layoutErrors = <String>[];

  setUpAll(setUpTestWorld);

  setUp(() => collectLayoutErrors(layoutErrors));

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('add friend sheet ${size.width.toInt()}w x$scale', (tester) async {
        await pumpScreen(tester, const FriendsScreen(), size, scale);
        addTearDown(tester.view.reset);
        expect(find.text('Add friends'), findsNothing);
        await tester.tap(find.text('Add friend'));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('Invite'), findsOneWidget);
        expect(find.text('Enter code'), findsOneWidget);
        expect(layoutErrors, isEmpty, reason: layoutErrors.toSet().join('\n---\n'));
      });
    }
  }

  testWidgets('stat tile opens profile', (tester) async {
    await pumpScreen(tester, const FriendsScreen(), sizes.first, 1.3);
    addTearDown(tester.view.reset);
    await tester.tap(find.byIcon(Icons.expand_more).hitTestable().first);
    await tester.pump(const Duration(milliseconds: 400));
    final tile = find.text('landmarks').hitTestable();
    await tester.ensureVisible(find.text('landmarks').first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(tile.first);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
