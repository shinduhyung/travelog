import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/widgets/my_match_badge.dart';

void main() {
  testWidgets('Compact percentage opens a short explanation on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MatchScoreChip(percent: 28))),
    );
    expect(find.text('28'), findsOneWidget);
    expect(find.text('28%'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.textContaining('My match'), findsNothing);
    expect(tester.getSize(find.byType(MatchScoreChip)).width, lessThan(65));
    await tester.tap(find.text('28'));
    await tester.pumpAndSettle();
    expect(find.text('Your travel match'), findsOneWidget);
    expect(find.textContaining('visited and rated'), findsOneWidget);
    await tester.tap(find.text('Keep exploring'));
    await tester.pumpAndSettle();
    expect(find.byType(MatchExplanationSheet), findsNothing);
  });

  testWidgets(
    'Percentage shares a narrow modal action row without adding height',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () {}, child: const Text('Cancel')),
                  const MatchScoreChip(percent: 100, onDark: true),
                  FilledButton(onPressed: () {}, child: const Text('Done')),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.text('100')).dy,
        tester.getCenter(find.text('Cancel')).dy,
      );
    },
  );
}
