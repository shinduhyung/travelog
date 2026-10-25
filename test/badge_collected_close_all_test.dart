import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/screens/badge_collected_screen.dart';

Achievement _badge() => Achievement(
  id: 't',
  name: 'Test',
  description: 'Visit Test.',
  difficulty: AchievementDifficulty.values.first,
  points: 1,
  imagePath: 'assets/none.png',
  category: AchievementCategory.Country,
);

// FirebaseBadgeImage needs Firebase, which is not initialised in widget tests.
void _drain(WidgetTester t) {
  while (t.takeException() != null) {}
}

Future<String?> _open(WidgetTester tester, int pending, {bool tapAll = false}) async {
  String? result = 'unset';
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (ctx) => ElevatedButton(
        onPressed: () async {
          result = await showDialog<String>(
            context: ctx,
            builder: (_) => BadgeCollectedScreen(achievement: _badge(), pendingCount: pending),
          );
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump(const Duration(milliseconds: 400));
  _drain(tester);
  if (tapAll) {
    await tester.tap(find.textContaining('Close All'));
    await tester.pump(const Duration(milliseconds: 400));
    _drain(tester);
  }
  return result;
}

void main() {
  testWidgets('shows Close All only when several badges are pending and returns "all"', (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    expect(await _open(tester, 1), 'unset');
    expect(find.textContaining('Close All'), findsNothing);
    Navigator.of(tester.element(find.byType(BadgeCollectedScreen))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    _drain(tester);

    final r = await _open(tester, 30, tapAll: true);
    expect(r, 'all');
  });
}
