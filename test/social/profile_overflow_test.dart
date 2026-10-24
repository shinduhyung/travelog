// 프로필 화면(나/친구/새 사용자)을 휴대폰 크기와 큰 글씨로 그려서 레이아웃 오류가 없는지 확인한다.
//
//   flutter test test/profile_overflow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/screens/profile_screen.dart';

import 'fixtures.dart';

void main() {
  final layoutErrors = <String>[];

  setUpAll(setUpTestWorld);

  setUp(() => collectLayoutErrors(layoutErrors));

  for (final uid in ['me', 'f1', 'f3']) {
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('profile $uid ${size.width.toInt()}w x$scale', (tester) async {
          await pumpScreen(tester, ProfileScreen(uid: uid), size, scale);
          addTearDown(tester.view.reset);
          await scrollThrough(tester);
          expect(layoutErrors, isEmpty, reason: layoutErrors.toSet().join('\n---\n'));
        });
      }
    }
  }

  testWidgets('profile f1 map modes and shading 360w x1.3', (tester) async {
    await pumpScreen(tester, const ProfileScreen(uid: 'f1'), sizes.first, 1.3);
    addTearDown(tester.view.reset);

    Future<void> tapVisible(Finder f) async {
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Cities'), findsWidgets);
    for (final label in ['Cities', 'Landmarks', 'Countries']) {
      final seg = find.descendant(of: find.byWidgetPredicate((w) => w is SegmentedButton), matching: find.text(label));
      await tapVisible(seg);
      await tapVisible(find.byType(Switch).first);
      await tapVisible(find.byType(Switch).first);
      await tapVisible(find.byType(Switch).first);
    }
    await scrollThrough(tester);
    expect(layoutErrors, isEmpty, reason: layoutErrors.toSet().join('\n---\n'));
  });
}
