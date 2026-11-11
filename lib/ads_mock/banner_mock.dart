// BANNER PLACEMENT MOCK — decision-making build only. Never ship.
//
// Enabled only with `--dart-define=BANNER_MOCK=true`. Uses Google's official
// TEST banner unit; the app's real ad units are never touched.
// Banner visibility is toggled at runtime by the presence of the file
// `<app files dir>/banner_on` (adb shell run-as <pkg> touch files/banner_on),
// so BEFORE / AFTER screenshots come from the same build, data and scroll.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';

const bool kBannerMock = bool.fromEnvironment('BANNER_MOCK');

/// Official Google test unit: Android adaptive banner.
const String kTestBannerUnit = 'ca-app-pub-3940256099942544/9214589741';

enum BannerPlacement { bottom, aboveNav, inline, result, none }

/// screen name -> placement. Screens not listed get [BannerPlacement.bottom]
/// through the global slot only if listed here as bottom; unknown => none.
const Map<String, BannerPlacement> kPlacements = {
  // main tabs: above the bottom nav (handled in MainScreen)
  'my_trips_tab': BannerPlacement.aboveNav,
  'countries_menu': BannerPlacement.aboveNav,
  'cities_menu': BannerPlacement.aboveNav,
  'explore_menu': BannerPlacement.aboveNav,
  'flights_menu': BannerPlacement.aboveNav,
};

class BannerMock {
  BannerMock._();
  static final ValueNotifier<bool> enabled = ValueNotifier(false);
  static final ValueNotifier<String?> currentScreen = ValueNotifier(null);
  static final ValueNotifier<String?> overrideScreen = ValueNotifier(null);
  /// Game screens: true while the game-over / result view is showing.
  static final ValueNotifier<bool> resultShowing = ValueNotifier(false);
  static Timer? _poll;

  static String? _lastScreen;
  static void start() {
    if (!kBannerMock || _poll != null) return;
    // A game-over flag belongs to one screen visit only.
    currentScreen.addListener(() {
      if (currentScreen.value != _lastScreen) {
        _lastScreen = currentScreen.value;
        resultShowing.value = false;
      }
    });
    getApplicationSupportDirectory().then((dir) {
      final flag = File('${dir.path}/banner_on');
      _poll = Timer.periodic(const Duration(milliseconds: 400), (_) {
        final on = flag.existsSync();
        if (on != enabled.value) enabled.value = on;
      });
    });
  }

  static BannerPlacement placementFor(String? name) {
    if (name == null) return BannerPlacement.none;
    return kPlacements[name] ?? kExtraPlacements[name] ?? BannerPlacement.none;
  }
}

/// Filled in per screen (pushed screens default to bottom anchored).
final Map<String, BannerPlacement> kExtraPlacements = {
  for (final n in kBottomScreens) n: BannerPlacement.bottom,
  for (final n in kInlineScreens) n: BannerPlacement.inline,
  for (final n in kResultScreens) n: BannerPlacement.result,
};

const List<String> kBottomScreens = [
  'cities', 'country_detail', 'countries_map', 'country_selection',
  'top_landmarks', 'countrydex', 'landmarks_list', 'top_cities',
  'unesco_sites', 'landmark_visit_log', 'landmark_cities', 'trip_dna',
  'flight_log_list', 'badges', 'capitals', 'landmarks_menu', 'flight_hub',
  'daily_quiz', 'trip_log_list', 'traveler_type_selector', 'airlines_list',
  'activities_menu', 'natural_menu', 'settings', 'top_picks_menu',
  'landmark_map', 'unesco_map', 'passport', 'airports',
  'city_overview_stats', 'calendar', 'visa', 'favorites',
  'travelog_games', 'discover', 'discover_quiz', 'country_twin',
  'tourist_local', 'travelog_polls', 'travelog_poll_history',
  'travelog_poll_result',
  'flag_guess_difficulty', 'which_is_farther_difficulty',
  'border_chain_difficulty', 'respawn_mode',
  'timezone_impostor_difficulty', 'higher_or_lower_mode',
  'higher_or_lower_difficulty',
  'flag_guess_lobby', 'which_is_farther_lobby', 'border_chain_lobby',
  'timezone_impostor_lobby', 'higher_or_lower_lobby',
];
/// Active game screens: banner only on the game-over / result view.
const List<String> kResultScreens = [
  'flag_guess_game', 'which_is_farther_game', 'border_chain_game',
  'respawn_game', 'timezone_impostor_game', 'higher_or_lower_game',
];
const List<String> kInlineScreens = [];

/// True when the banner for [placement] should be visible right now.
bool bannerVisibleFor(BannerPlacement placement) {
  if (!kBannerMock || !BannerMock.enabled.value) return false;
  final name = BannerMock.overrideScreen.value ?? BannerMock.currentScreen.value;
  final p = BannerMock.placementFor(name);
  if (placement == BannerPlacement.bottom && p == BannerPlacement.result) {
    return BannerMock.resultShowing.value;
  }
  return p == placement;
}

/// A banner using the TEST unit. Falls back to a labeled placeholder of the
/// real size if no test ad fills.
class MockBanner extends StatefulWidget {
  const MockBanner({super.key, this.inline = false});
  final bool inline;
  @override
  State<MockBanner> createState() => _MockBannerState();
}

class _MockBannerState extends State<MockBanner> {
  BannerAd? _ad;
  AdSize? _size;
  bool _loaded = false;
  bool _failed = false;
  int _tries = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_size == null && _ad == null) _load();
  }

  Future<void> _load() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size = widget.inline
        ? AdSize.banner
        : await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width) ??
            AdSize.banner;
    if (!mounted) return;
    _size = size;
    _ad = BannerAd(
      adUnitId: kTestBannerUnit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('[BannerMock] test banner failed: ${err.code} ${err.message}');
          ad.dispose();
          _ad = null;
          _tries++;
          if (!mounted) return;
          setState(() => _failed = _tries >= 4);
          // Retry (network hiccups); after 4 failures keep the sized placeholder.
          if (_tries < 4) {
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted && _ad == null) _load();
            });
          }
        },
      ),
    )..load();
    setState(() {});
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size ?? AdSize.banner;
    final h = size.height.toDouble();
    if (_loaded && _ad != null) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        height: h,
        child: SizedBox(width: size.width.toDouble(), height: h, child: AdWidget(ad: _ad!)),
      );
    }
    return Container(
      height: h,
      color: const Color(0xFFEDEDED),
      alignment: Alignment.center,
      child: Text(
        _failed
            ? 'Test Ad placeholder · ${size.width}×${size.height}'
            : 'Loading test ad…',
        style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF777777),
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w400,
            fontFamily: 'Roboto'),
      ),
    );
  }
}

/// Inline slot: renders a banner only while the current screen is inline.
class InlineBannerSlot extends StatelessWidget {
  const InlineBannerSlot({super.key});
  @override
  Widget build(BuildContext context) {
    if (!kBannerMock) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge(
          [BannerMock.enabled, BannerMock.currentScreen, BannerMock.overrideScreen, BannerMock.resultShowing]),
      builder: (context, _) => bannerVisibleFor(BannerPlacement.inline)
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: MockBanner(inline: true),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Slot above the main bottom navigation bar.
class AboveNavBannerSlot extends StatelessWidget {
  const AboveNavBannerSlot({super.key});
  @override
  Widget build(BuildContext context) {
    if (!kBannerMock) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge(
          [BannerMock.enabled, BannerMock.currentScreen, BannerMock.overrideScreen, BannerMock.resultShowing]),
      builder: (context, _) => bannerVisibleFor(BannerPlacement.aboveNav)
          ? const MockBanner()
          : const SizedBox.shrink(),
    );
  }
}

/// Wraps the whole Navigator: bottom-anchored banner above the safe area for
/// pushed screens whose placement is [BannerPlacement.bottom].
class GlobalBottomBannerSlot extends StatelessWidget {
  const GlobalBottomBannerSlot({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!kBannerMock) return child;
    return AnimatedBuilder(
      animation: Listenable.merge(
          [BannerMock.enabled, BannerMock.currentScreen, BannerMock.overrideScreen, BannerMock.resultShowing]),
      child: child,
      builder: (context, child) {
        final show = bannerVisibleFor(BannerPlacement.bottom);
        if (!show) return child!;
        final mq = MediaQuery.of(context);
        return ColoredBox(
          color: Colors.white,
          child: Column(
            children: [
              Expanded(
                child: MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(bottom: 0),
                    viewPadding: mq.viewPadding.copyWith(bottom: 0),
                  ),
                  child: child!,
                ),
              ),
              const MockBanner(),
              SizedBox(height: mq.padding.bottom),
            ],
          ),
        );
      },
    );
  }
}
