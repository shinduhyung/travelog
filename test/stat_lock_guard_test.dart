import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jidoapp/services/rewarded_unlock_service.dart';
import 'package:jidoapp/widgets/stat_lock_guard.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() => RewardedUnlockService.instance.resetForTest());

  testWidgets('unlocked stat shows its content', (tester) async {
    await tester.pumpWidget(
      _host(
        const StatLockGuard(
          statKey: 'test.open',
          locked: false,
          child: Text('ranking list'),
        ),
      ),
    );
    expect(find.text('ranking list'), findsOneWidget);
    expect(find.byType(StatLockedPromo), findsNothing);
  });

  testWidgets('locked stat shows the promo instead of the content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const StatLockGuard(
          statKey: 'test.locked',
          locked: true,
          child: Text('ranking list'),
        ),
      ),
    );
    expect(find.text('ranking list'), findsNothing);
    expect(find.byType(StatLockedPromo), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });

  testWidgets('rewarded unlock reveals the content for that key only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            Expanded(
              child: StatLockGuard(
                statKey: 'test.a',
                locked: true,
                child: Text('A list'),
              ),
            ),
            Expanded(
              child: StatLockGuard(
                statKey: 'test.b',
                locked: true,
                child: Text('B list'),
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.text('A list'), findsNothing);

    RewardedUnlockService.instance.unlockForTest('test.a');
    await tester.pump();

    expect(find.text('A list'), findsOneWidget);
    expect(find.text('B list'), findsNothing);
  });
}
