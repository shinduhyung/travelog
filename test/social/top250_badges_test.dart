// Top 250 landmarks and badges screens at phone sizes and large text: no layout errors.
//
//   flutter test test/top250_badges_test.dart
//
// Note: fixture badgeIds are 'b0', 'b1', ... which are not real catalog ids, so they
// exercise the "generic badge" path (counted, shown with a fallback icon).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/screens/badges_screen.dart';
import 'package:jidoapp/social/widgets/top_landmarks.dart';

import 'fixtures.dart';

void main() {
  final layoutErrors = <String>[];

  setUpAll(setUpTestWorld);

  setUp(() => collectLayoutErrors(layoutErrors));

  final screens = <String, Widget Function()>{
    'top250 me': () => const TopLandmarksScreen(uids: ['me']),
    'top250 me+f1': () => const TopLandmarksScreen(uids: ['me', 'f1']),
    'top250 f3': () => const TopLandmarksScreen(uids: ['f3']),
    'badges me': () => const BadgesScreen(uid: 'me'),
    'badges f1': () => const BadgesScreen(uid: 'f1'),
    'badges f3': () => const BadgesScreen(uid: 'f3'),
  };

  for (final e in screens.entries) {
    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets('${e.key} ${size.width.toInt()}w x$scale', (tester) async {
          await pumpScreen(tester, e.value(), size, scale);
          addTearDown(tester.view.reset);
          await scrollThrough(tester);
          expect(layoutErrors, isEmpty, reason: layoutErrors.toSet().join('\n---\n'));
        });
      }
    }
  }

  testWidgets('top250 filters 360w x1.3', (tester) async {
    await pumpScreen(tester, const TopLandmarksScreen(uids: ['me', 'f1']), sizes.first, 1.3);
    addTearDown(tester.view.reset);
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(ChoiceChip).at(i));
      await tester.pump(const Duration(milliseconds: 300));
      await scrollThrough(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 100000));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(layoutErrors, isEmpty, reason: layoutErrors.toSet().join('\n---\n'));
  });

  testWidgets('badges categories and sheet 360w x1.3', (tester) async {
    await pumpScreen(tester, const BadgesScreen(uid: 'f1'), sizes.first, 1.3);
    addTearDown(tester.view.reset);
    expect(find.textContaining('/ '), findsWidgets);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(ChoiceChip).at(i));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.descendant(of: find.byType(SliverGrid), matching: find.byType(InkWell)).first);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(layoutErrors, isEmpty, reason: layoutErrors.toSet().join('\n---\n'));
  });
}
