import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/services/screen_tracking.dart';
import 'package:jidoapp/services/screen_registry.dart';

class _Event {
  _Event(this.name, this.data);
  final String name;
  final Map<String, Object> data;
}

class _Clock {
  Duration time = Duration.zero;
  void seconds(int n) => time += Duration(seconds: n);
}

void main() {
  late _Clock clock;
  late List<_Event> events;
  late ScreenVisitLedger ledger;
  Future<void> sink(String name, Map<String, Object> data) async {
    events.add(_Event(name, data));
  }

  List<_Event> views() =>
      events.where((e) => e.name == 'travelog_screen_view').toList();
  int dwell(String name) => events
      .where(
        (e) =>
            e.name == 'travelog_screen_dwell' &&
            e.data['analytics_screen'] == name,
      )
      .fold(0, (n, e) => n + (e.data['duration_ms'] as int));

  setUp(() {
    clock = _Clock();
    events = [];
    ledger = ScreenVisitLedger(sink: sink, now: () => clock.time);
  });

  test(
    'original taxonomy has 152 unique entries; typed active map has 120',
    () {
      expect(screenGroups.length, 152);
      expect(screenWidgetNames.length, 120);
      expect(screenWidgetNames.values.toSet().length, 120);
      expect(screenWidgetNames.values.every(screenGroups.containsKey), isTrue);
      expect(screenGroups['population_stats'], '2-2');
      expect(screenWidgetNames.values, isNot(contains('countries_share')));
    },
  );

  test('A 50 minutes, B 20, A 50 totals 100 and 20 minutes', () {
    final a = Object(), b = Object();
    ledger.show(a, 'A', 'group');
    clock.seconds(3000);
    ledger.show(b, 'B', 'group');
    clock.seconds(1200);
    ledger.show(a, 'A', 'group');
    clock.seconds(3000);
    ledger.flush();
    expect(dwell('A'), 6000000);
    expect(dwell('B'), 1200000);
    expect(views().map((e) => e.data['analytics_screen']), ['A', 'B', 'A']);
  });

  test('rebuilds, reselections, checkpoints and resumes do not add views', () {
    final owner = Object();
    ledger.show(owner, 'A', 'group');
    for (var i = 0; i < 100; i++) {
      ledger.show(owner, 'A', 'group');
      clock.seconds(1);
      ledger.checkpoint();
    }
    ledger.pause('lifecycle');
    clock.seconds(60);
    ledger.resume('lifecycle');
    clock.seconds(5);
    ledger.flush();
    expect(views().length, 1);
    expect(dwell('A'), 105000);
    expect(events.map((e) => e.data['visit_id']).toSet().length, 1);
  });

  test('ad and lifecycle pauses overlap in both orders', () {
    for (final first in ['ad', 'lifecycle']) {
      events.clear();
      final other = first == 'ad' ? 'lifecycle' : 'ad';
      ledger.show(Object(), 'A', 'group');
      clock.seconds(10);
      ledger.pause(first);
      clock.seconds(5);
      ledger.pause(other);
      clock.seconds(5);
      ledger.resume(first);
      clock.seconds(100);
      ledger.checkpoint();
      ledger.resume(other);
      clock.seconds(7);
      ledger.flush();
      expect(dwell('A'), 17000);
      expect(views().length, 1);
    }
  });

  test('background navigation does not count a view until foreground', () {
    ledger.show(Object(), 'A', 'group');
    clock.seconds(3);
    ledger.pause('lifecycle');
    ledger.show(Object(), 'B', 'group');
    clock.seconds(100);
    expect(views().length, 1);
    ledger.resume('lifecycle');
    clock.seconds(4);
    ledger.flush();
    expect(dwell('B'), 4000);
    expect(views().length, 2);
  });

  test('same screen on a distinct route is a new visit', () {
    ledger.show(Object(), 'A', 'group');
    clock.seconds(2);
    ledger.show(Object(), 'A', 'group');
    clock.seconds(3);
    ledger.flush();
    expect(views().length, 2);
    expect(dwell('A'), 5000);
    expect(views().map((e) => e.data['visit_id']).toSet().length, 2);
  });

  test(
    'unknown pages are excluded rather than attributed to the last screen',
    () {
      ledger.show(Object(), 'A', 'group');
      clock.seconds(2);
      ledger.show(null, null, null);
      clock.seconds(100);
      ledger.checkpoint();
      ledger.show(Object(), 'A', 'group');
      clock.seconds(3);
      ledger.flush();
      expect(dwell('A'), 5000);
      expect(views().length, 2);
    },
  );

  test(
    'synchronous and asynchronous analytics failures are contained',
    () async {
      for (final asyncFailure in [false, true]) {
        final failing = ScreenVisitLedger(
          now: () => clock.time,
          sink: (n, d) {
            if (asyncFailure) return Future<void>.error(StateError('offline'));
            throw StateError('unavailable');
          },
        );
        expect(() {
          failing.show(Object(), 'A', 'group');
          clock.seconds(1);
          failing.checkpoint();
          failing.pause('ad');
          failing.resume('ad');
        }, returnsNormally);
        await Future<void>.delayed(Duration.zero);
      }
    },
  );

  late ScreenTracking tracker;
  void installTracker() {
    tracker = ScreenTracking.forTesting(sink: sink, now: () => clock.time);
    ScreenTracking.debugInstance = tracker;
    addTearDown(() {
      tracker.dispose();
      ScreenTracking.debugInstance = null;
    });
  }

  ThemeData theme(TargetPlatform platform) => ThemeData(platform: platform);
  ScreenTrackingObserver observer() => ScreenTrackingObserver(
    resolve: (widget) => const <Type, String>{
      _PageA: 'profile',
      _PageB: 'settings',
      _TabbedPage: 'overview_stats',
    }[widget.runtimeType],
  );

  testWidgets('dispose ignores late ad and lifecycle callbacks', (
    tester,
  ) async {
    installTracker();
    tracker.ledger.show(Object(), 'profile', '0');
    clock.seconds(2);
    tracker.adVisible(true);
    tracker.dispose();
    final count = events.length;
    tracker.adVisible(false);
    tracker.didChangeAppLifecycleState(AppLifecycleState.resumed);
    clock.seconds(30);
    tracker.ledger.checkpoint();
    await tester.pump();
    expect(events.length, count);
  });

  testWidgets(
    'IndexedStack reselection and back restore only the selected main tab',
    (tester) async {
      installTracker();
      final nav = GlobalKey<NavigatorState>();
      late StateSetter change;
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [observer()],
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return AnalyticsScreen(
                name: ['my_trips_tab', 'countries_menu'][index],
                child: Scaffold(
                  body: IndexedStack(
                    index: index,
                    children: const [
                      Text('my trips body'),
                      Text('countries body'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views().map((e) => e.data['analytics_screen']), ['my_trips_tab']);
      change(() => index = 1);
      await tester.pumpAndSettle();
      change(() => index = 1);
      await tester.pumpAndSettle();
      expect(views().map((e) => e.data['analytics_screen']), [
        'my_trips_tab',
        'countries_menu',
      ]);
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const _PageB()),
      );
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(views().last.data['analytics_screen'], 'countries_menu');
      expect(find.text('countries body'), findsOneWidget);
    },
  );

  testWidgets(
    'bottom sheet uses its explicit screen and keeps builder execution once',
    (tester) async {
      installTracker();
      final nav = GlobalKey<NavigatorState>();
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [observer()],
          home: const _PageA(),
        ),
      );
      await tester.pumpAndSettle();
      clock.seconds(2);
      showModalBottomSheet<void>(
        context: nav.currentContext!,
        builder: (_) {
          builds++;
          return const AnalyticsScreen(
            name: 'country_selection',
            child: SizedBox(height: 200, child: Text('select')),
          );
        },
      );
      await tester.pumpAndSettle();
      clock.seconds(3);
      expect(builds, 1);
      expect(views().last.data['analytics_screen'], 'country_selection');
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(views().map((e) => e.data['analytics_screen']), [
        'profile',
        'country_selection',
        'profile',
      ]);
      expect(dwell('country_selection'), 3000);
    },
  );

  testWidgets(
    'iOS edge swipe cancellation does not count a view; completed swipe pops',
    (tester) async {
      installTracker();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: theme(TargetPlatform.iOS),
          navigatorObservers: [observer()],
          home: const _PageA(),
        ),
      );
      await tester.pumpAndSettle();
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const _PageB()),
      );
      await tester.pumpAndSettle();
      final count = views().length;
      final gesture = await tester.startGesture(const Offset(1, 200));
      await gesture.moveTo(const Offset(130, 200));
      await tester.pump();
      await gesture.moveTo(const Offset(2, 200));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(views().length, count);
      await tester.dragFrom(const Offset(1, 200), const Offset(790, 0));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(views().last.data['analytics_screen'], 'profile');
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'real route content, push/pop and builders preserved on $platform',
      (tester) async {
        installTracker();
        final nav = GlobalKey<NavigatorState>();
        var builderCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: nav,
            theme: theme(platform),
            navigatorObservers: [observer()],
            home: const _PageA(),
          ),
        );
        await tester.pumpAndSettle();
        expect(views().map((e) => e.data['analytics_screen']), ['profile']);
        clock.seconds(5);
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) {
              builderCalls++;
              return const _PageB();
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(builderCalls, 1);
        expect(find.text('B'), findsOneWidget);
        clock.seconds(7);
        nav.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget);
        expect(views().map((e) => e.data['analytics_screen']), [
          'profile',
          'settings',
          'profile',
        ]);
        expect(dwell('profile'), 5000);
        expect(dwell('settings'), 7000);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unknown modal pauses without adding a return visit; classified modal counts',
    (tester) async {
      installTracker();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: theme(TargetPlatform.android),
          navigatorObservers: [observer()],
          home: const _PageA(),
        ),
      );
      await tester.pumpAndSettle();
      clock.seconds(5);
      showDialog<void>(
        context: nav.currentContext!,
        builder: (_) => const AlertDialog(content: Text('unknown')),
      );
      await tester.pumpAndSettle();
      clock.seconds(100);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      clock.seconds(3);
      expect(views().length, 1);
      showDialog<void>(
        context: nav.currentContext!,
        builder: (_) => const AnalyticsScreen(
          name: 'badge_collected',
          child: AlertDialog(content: Text('badge')),
        ),
      );
      await tester.pumpAndSettle();
      clock.seconds(4);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(views().map((e) => e.data['analytics_screen']), [
        'profile',
        'badge_collected',
        'profile',
      ]);
      expect(dwell('profile'), 8000);
      expect(dwell('badge_collected'), 4000);
    },
  );

  testWidgets(
    'tabs keep selected state through rebuilds, push/pop, taps and swipe',
    (tester) async {
      installTracker();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: theme(TargetPlatform.android),
          navigatorObservers: [observer()],
          home: const _TabbedPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(views().map((e) => e.data['analytics_screen']), [
        'overview_stats',
      ]);
      await tester.tap(find.text('Economy'));
      await tester.pumpAndSettle();
      expect(views().last.data['analytics_screen'], 'economy_stats');
      final count = views().length;
      await tester.tap(find.text('Economy'));
      await tester.pumpAndSettle();
      expect(views().length, count);
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const _PageB()),
      );
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(views().last.data['analytics_screen'], 'economy_stats');
      await tester.drag(find.byType(TabBarView), const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(views().last.data['analytics_screen'], 'overview_stats');
      expect(tester.takeException(), isNull);
    },
  );
}

class _PageA extends StatelessWidget {
  const _PageA();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('A'));
}

class _PageB extends StatelessWidget {
  const _PageB();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('B'));
}

class _TabbedPage extends StatelessWidget {
  const _TabbedPage();
  @override
  Widget build(BuildContext context) => const DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: TabBar(
        tabs: [
          Tab(text: 'Overview'),
          Tab(text: 'Economy'),
        ],
      ),
      body: AnalyticsTabBarView(
        names: ['overview_stats', 'economy_stats'],
        children: [
          Center(child: Text('overview body')),
          Center(child: Text('economy body')),
        ],
      ),
    ),
  );
}
