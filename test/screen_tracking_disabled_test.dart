import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/services/screen_tracking.dart';

void main() {
  testWidgets(
    'kill switch keeps tabs and navigation functional without events',
    (tester) async {
      final events = <String>[];
      final tracker = ScreenTracking.forTesting(
        sink: (event, data) async {
          events.add(event);
        },
        now: () => Duration.zero,
      );
      ScreenTracking.debugInstance = tracker;
      addTearDown(() {
        tracker.dispose();
        ScreenTracking.debugInstance = null;
      });
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [ScreenTrackingObserver()],
          home: const DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: TabBar(
                tabs: [
                  Tab(text: 'One'),
                  Tab(text: 'Two'),
                ],
              ),
              body: AnalyticsTabBarView(
                names: ['profile', 'settings'],
                children: [Text('first'), Text('second')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('next')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      tracker.adVisible(true);
      tracker.adVisible(false);
      expect(events, isEmpty);
      expect(tester.takeException(), isNull);
    },
    skip: ScreenTracking.enabled,
  );
}
