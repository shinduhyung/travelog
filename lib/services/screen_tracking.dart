import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef TrackingSink =
    Future<void> Function(String event, Map<String, Object> data);

/// One visit can contain many dwell chunks. Count views, never dwell chunks.
/// This class has no dependency on navigation, wall-clock time, or Firebase.
class ScreenVisitLedger {
  ScreenVisitLedger({required this.sink, required this.now});
  final TrackingSink sink;
  final Duration Function() now;
  final Set<String> _pauses = {};
  Object? _owner;
  String? _name;
  String? _group;
  String? _visit;
  Duration? _started;
  int _sequence = 0;
  final String _session = DateTime.now().microsecondsSinceEpoch.toRadixString(
    36,
  );

  void _send(String event, Map<String, Object> data) {
    // Analytics must never interrupt navigation or an ad callback, including
    // when the sink throws synchronously or the native plugin is unavailable.
    unawaited(
      Future<void>.sync(() => sink(event, data)).catchError((Object e) {
        if (kDebugMode) debugPrint('[ScreenTracking] $e');
      }),
    );
  }

  void show(Object? owner, String? name, String? group) {
    if (identical(owner, _owner) && name == _name) return;
    flush();
    _owner = owner;
    _name = name;
    _group = group;
    _visit = null;
    _startIfVisible();
  }

  void _startIfVisible() {
    if (_pauses.isNotEmpty || _name == null || _group == null) return;
    if (_visit == null) {
      _visit = '${_session}_${++_sequence}';
      _send('travelog_screen_view', {
        'analytics_screen': _name!,
        'screen_group': _group!,
        'visit_id': _visit!,
      });
    }
    _started ??= now();
  }

  void pause(String reason) {
    if (_pauses.contains(reason)) return;
    flush();
    _pauses.add(reason);
  }

  void resume(String reason) {
    if (!_pauses.remove(reason)) return;
    _startIfVisible();
  }

  void flush() {
    final started = _started;
    _started = null;
    if (started == null) return;
    final elapsed = now() - started;
    if (elapsed.inMilliseconds > 0 && _visit != null) {
      _send('travelog_screen_dwell', {
        'analytics_screen': _name!,
        'screen_group': _group!,
        'visit_id': _visit!,
        'duration_ms': elapsed.inMilliseconds,
      });
    }
  }

  void checkpoint() {
    flush();
    _startIfVisible();
  }
}

class ScreenTracking with WidgetsBindingObserver {
  ScreenTracking._() {
    _clock.start();
    ledger = ScreenVisitLedger(sink: _firebaseSink, now: () => _clock.elapsed);
  }
  static final ScreenTracking _instance = ScreenTracking._();
  static ScreenTracking get instance => debugInstance ?? _instance;
  @visibleForTesting
  static ScreenTracking? debugInstance;
  @visibleForTesting
  ScreenTracking.forTesting({
    required TrackingSink sink,
    required Duration Function() now,
  }) {
    ledger = ScreenVisitLedger(sink: sink, now: now);
  }
  static const enabled = bool.fromEnvironment(
    'TRAVELOG_SCREEN_TRACKING',
    defaultValue: true,
  );
  final Stopwatch _clock = Stopwatch();
  late final ScreenVisitLedger ledger;
  final Map<Object, _ScreenRegistration> _scopes = {};
  // Weak keys avoid retaining disposed routes when a whole Navigator remounts.
  final Expando<String> _routeNames = Expando<String>('analytics route names');
  Route<dynamic>? _top;
  Timer? _heartbeat;
  bool _scheduled = false;
  bool _disposed = false;

  static Future<void> _firebaseSink(
    String event,
    Map<String, Object> data,
  ) async {
    if (!enabled) return;
    final analytics = FirebaseAnalytics.instance;
    await analytics.logEvent(name: event, parameters: data);
    if (event == 'travelog_screen_view') {
      await analytics.logScreenView(
        screenName: data['analytics_screen'] as String,
        screenClass: data['analytics_screen'] as String,
      );
    }
  }

  void start() {
    if (!enabled || _disposed || _heartbeat != null) return;
    WidgetsBinding.instance.addObserver(this);
    didChangeAppLifecycleState(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    );
    _heartbeat = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ledger.checkpoint(),
    );
  }

  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    WidgetsBinding.instance.removeObserver(this);
    ledger.show(null, null, null);
    _top = null;
    _scopes.clear();
  }

  void adVisible(bool visible) {
    if (!enabled || _disposed) return;
    if (visible) {
      ledger.pause('ad');
    } else {
      ledger.resume('ad');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      ledger.resume('lifecycle');
    } else {
      ledger.pause('lifecycle');
    }
  }

  void _scheduleResolve() {
    if (!enabled || _disposed || _scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (_disposed) return;
      final baseName = _top == null ? null : _routeNames[_top!];
      _ScreenRegistration? best = baseName == null
          ? null
          : _ScreenRegistration(_top, baseName, 0);
      for (final scope in _scopes.values) {
        if (identical(scope.route, _top) &&
            (best == null || scope.priority > best.priority)) {
          best = scope;
        }
      }
      if (best != null) {
        ledger.show(_top, best.name, screenGroups[best.name]);
        ledger.resume('overlay');
      } else if (_top is PopupRoute) {
        // Unclassified dialogs/sheets suspend the underlying visit, without
        // inventing a screen name or counting another visit on dismissal.
        ledger.pause('overlay');
      } else {
        ledger.show(null, null, null);
        ledger.resume('overlay');
      }
    });
  }
}

class _ScreenRegistration {
  const _ScreenRegistration(this.route, this.name, this.priority);
  final Route<dynamic>? route;
  final String name;
  final int priority;
}

/// Independent of AdNavigatorObserver: observes only, never changes a route.
class ScreenTrackingObserver extends NavigatorObserver {
  ScreenTrackingObserver({this.resolve});
  final String? Function(Widget)? resolve;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    final tracker = ScreenTracking.instance;
    if (tracker._disposed || !ScreenTracking.enabled) return;
    tracker._top = topRoute;
    tracker._scheduleResolve();
    // subtreeContext is a public SDK API. Wait until the existing builder has
    // completed, then read only the root and the SDK's transparent wrappers.
    // No builder replay, layout changes, animation changes or full-tree search.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (tracker._disposed || !identical(tracker._top, topRoute)) return;
      if (topRoute is MaterialPageRoute && resolve != null) {
        tracker._routeNames[topRoute] = null;
        Element? node = topRoute.subtreeContext as Element?;
        for (var depth = 0; node != null && depth < 8; depth++) {
          final name = resolve!(node.widget);
          if (name != null) {
            tracker._routeNames[topRoute] = name;
            break;
          }
          if (node.widget is! RepaintBoundary &&
              node.widget is! Builder &&
              node.widget is! Semantics) {
            break;
          }
          final children = <Element>[];
          node.visitChildElements(children.add);
          node = children.length == 1 ? children.single : null;
        }
      }
      tracker._scheduleResolve();
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ScreenTracking.instance._routeNames[route] = null;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ScreenTracking.instance._routeNames[route] = null;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) ScreenTracking.instance._routeNames[oldRoute] = null;
  }
}

/// Transparent, layout-free registration of the visible part of one route.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    required this.name,
    required this.child,
    this.priority = 10,
  });
  final String? name;
  final Widget child;
  final int priority;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  void _register() {
    final tracker = ScreenTracking.instance;
    if (widget.name == null || !ScreenTracking.enabled || tracker._disposed) {
      tracker._scopes.remove(this);
    } else {
      tracker._scopes[this] = _ScreenRegistration(
        ModalRoute.of(context),
        widget.name!,
        widget.priority,
      );
    }
    tracker._scheduleResolve();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  @override
  void dispose() {
    ScreenTracking.instance._scopes.remove(this);
    ScreenTracking.instance._scheduleResolve();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Keeps the existing DefaultTabController, TabBar, children and swipe behavior.
class AnalyticsTabBarView extends StatefulWidget {
  const AnalyticsTabBarView({
    super.key,
    required this.names,
    required this.children,
    this.physics,
  });
  final List<String> names;
  final List<Widget> children;
  final ScrollPhysics? physics;
  @override
  State<AnalyticsTabBarView> createState() => _AnalyticsTabBarViewState();
}

class _AnalyticsTabBarViewState extends State<AnalyticsTabBarView> {
  TabController? _controller;
  int _index = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DefaultTabController.of(context);
    if (!identical(next, _controller)) {
      _controller?.removeListener(_changed);
      _controller = next;
      _index = next.index;
      next.addListener(_changed);
    }
  }

  void _changed() {
    final controller = _controller!;
    if (controller.indexIsChanging || controller.offset.abs() > 0.001) return;
    if (_index != controller.index && mounted) {
      setState(() => _index = controller.index);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnalyticsScreen(
    name: _index < widget.names.length ? widget.names[_index] : null,
    priority: 20,
    child: TabBarView(physics: widget.physics, children: widget.children),
  );
}

// The original 152-name taxonomy; no private IDs, titles, or travel data sent.
const Map<String, String> screenGroups = {
  'login_prompt': '0',
  'login': '0',
  'onboarding_tutorial': '0',
  'welcome': '0',
  'item_list': '0',
  'home_tab': '0',
  'loading': '0',
  'profile': '0',
  'settings': '0',
  'badges': '6',
  'badge_collected': '6',
  'badge_detail': '6',
  'badge_premium_pending': '6',
  'rank_collected': '6',
  'daily_quiz': '7',
  'travelog_games': '8',
  'calendar': '9',
  'edit_trip_log': '9',
  'my_journey': '9',
  'my_trips_tab': '9',
  'trip_dna': '9',
  'trip_log_detail': '9',
  'trip_log_list': '9',
  'trip_map': '9',
  'ai_itinerary_view': '9',
  'ai_summary': '9',
  'edit_itinerary': '9',
  'recommendations': '9',
  'traveler_type_ai': '9',
  'traveler_type_selector': '9',
  'passport': '9',
  'passport_visa_detail': '9',
  'visa_map': '9',
  'visa': '9',
  'world_discover': '9',
  'travel_features.dart': '9',
  'favorites': '9',
  'city_tiers': '9',
  'countries_share': '10',
  'cities_map_share': '10',
  'cities_share': '10',
  'flights_share': '10',
  'badge_share': '10',
  'countries_map': '1-1',
  'countries_menu': '1-1',
  'country_selection': '1-1',
  'country_subregions': '1-1',
  'flags': '1-1',
  'country_tiers': '1-2',
  'specific_countries_stats': '1-2',
  'countrydex': '1-2',
  'country_detail': '1-2',
  'alexander_empire_map': '1-2',
  'british_empire_map': '1-2',
  'french_empire_map': '1-2',
  'mongol_empire_map': '1-2',
  'ottoman_empire_map': '1-2',
  'roman_empire_map': '1-2',
  'historical_empire': '1-2',
  'area_stats': '1-2',
  'overview_stats': '1-2',
  'history_stats': '1-2',
  'military_stats': '1-2',
  'language_family_map': '1-2',
  'language_map': '1-2',
  'language_stats': '1-2',
  'religion_map': '1-2',
  'religion_stats': '1-2',
  'specials_stats': '1-2',
  'economy_stats': '1-2',
  'geography_stats': '1-2',
  'geolocation_stats': '1-2',
  'geopolitics_stats': '1-2',
  'society_stats': '1-2',
  'climate_map': '1-2',
  'climate_stats': '1-2',
  'sports_stats': '1-2',
  'continents_list': '1-2',
  'cities_menu': '2-1',
  'cities': '2-1',
  'city_overview_stats': '2-2',
  'city_stats_map': '2-2',
  'city_climate': '2-2',
  'city_economy': '2-2',
  'city_geography': '2-2',
  'city_history': '2-2',
  'city_map': '2-2',
  'city_society': '2-2',
  'city_specials': '2-2',
  'city_sports': '2-2',
  'city_transportation': '2-2',
  'top_cities': '2-2',
  'populations': '2-2',
  'population_stats': '2-2',
  'capitals': '2-2',
  'landmarks_list': '3-1',
  'landmarks_menu': '3-1',
  'landmark_map': '3-1',
  'explore_menu': '3-1',
  'home': '3-1',
  'natural_menu': '3-1',
  'activities_menu': '3-1',
  'top_activities_menu': '3-1',
  'aggregate_map': '3-1',
  'landmark_stats': '3-2',
  'landmark_cities': '3-2',
  'landmark_visit_log': '3-2',
  'top_bridges': '3-2',
  'top_buildings': '3-2',
  'top_falls': '3-2',
  'top_lakes': '3-2',
  'top_landmarks': '3-2',
  'top_mountains': '3-2',
  'top_museums': '3-2',
  'top_orchestras': '3-2',
  'top_paintings': '3-2',
  'top_picks_menu': '3-2',
  'top_public_squares': '3-2',
  'top_rivers': '3-2',
  'top_statues': '3-2',
  'top_universities': '3-2',
  'disneyland': '3-2',
  'universal_studios': '3-2',
  'tourism': '3-2',
  'world_wonders': '3-2',
  'film_festivals': '3-2',
  'instagram_ranking': '3-2',
  'activity_stats': '3-2',
  'champions_league_teams': '3-2',
  'unesco_map': '3-3',
  'unesco_sites': '3-3',
  'unesco_stats': '3-4',
  'add_flight_log': '5-1',
  'airlines_list': '5-1',
  'airline_detail': '5-1',
  'airports': '5-1',
  'flights_menu': '5-1',
  'flight_connection': '5-1',
  'flight_hub': '5-1',
  'flight_log_list': '5-1',
  'flight_route_map': '5-1',
  'aircraft_stats': '5-2',
  'airline_stats': '5-2',
  'airport_stats': '5-2',
  'flights_lounge_stats': '5-2',
  'flight_frequency_stats': '5-2',
  'flight_overview_stats': '5-2',
  'flight_records_stats': '5-2',
  'flight_transfer_stats': '5-2',
  'seat_class_stats': '5-2',
  'purchase_stats': '5-2',
  'CMakeLists.tx': 'unassigned',
};
