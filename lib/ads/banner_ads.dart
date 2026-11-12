// lib/ads/banner_ads.dart
//
// Anchored adaptive banners, placed per screen (see the banner placement
// report). The banner ad units are served through AdMob mediation (AdMob,
// Meta Audience Network and Unity Ads bidding), the same way as the
// interstitial. Debug/profile builds always request Google's TEST unit so a
// developer device never requests live ads.
import 'dart:async';
import 'dart:io';

import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jidoapp/services/ad_service.dart';
import 'package:jidoapp/services/screen_tracking.dart';
import 'package:jidoapp/services/subscription_service.dart';

enum BannerPlacement { bottom, aboveNav, result, none }

class BannerAds {
  BannerAds._();

  // Live banner ad units (mediation groups: banner_android_bidding / banner_ios_bidding).
  static const String _androidUnit = 'ca-app-pub-3945470636956441/1715747127'; // banner_main
  static const String _iosUnit = 'ca-app-pub-3945470636956441/2182650980'; // travelog_apple_banner

  // Google's official test banner units.
  static const String _androidTestUnit = 'ca-app-pub-3940256099942544/9214589741';
  static const String _iosTestUnit = 'ca-app-pub-3940256099942544/2435281174';

  static String get unitId {
    if (kReleaseMode) return Platform.isIOS ? _iosUnit : _androidUnit;
    return Platform.isIOS ? _iosTestUnit : _androidTestUnit;
  }

  /// Set by game screens while their game-over / result view is showing.
  static final ValueNotifier<bool> resultShowing = ValueNotifier(false);

  /// Height of the banner currently shown above the main nav bar (0 when none).
  /// Main tabs add it to their bottom spacer so the last items can scroll clear.
  static final ValueNotifier<double> aboveNavHeight = ValueNotifier(0);

  /// True once consent is done and the Mobile Ads SDK is ready.
  static final ValueNotifier<bool> ready = ValueNotifier(false);

  static String? _lastScreen;
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    ScreenTracking.currentScreen.addListener(() {
      final name = ScreenTracking.currentScreen.value;
      if (name != _lastScreen) {
        _lastScreen = name;
        resultShowing.value = false;
      }
    });
    AdService.instance.consentFlowDone.then((_) {
      ready.value = AdService.instance.mobileAdsInitialized;
    });
  }

  static BannerPlacement placementFor(String? name) {
    if (name == null) return BannerPlacement.none;
    if (_aboveNav.contains(name)) return BannerPlacement.aboveNav;
    if (_result.contains(name)) return BannerPlacement.result;
    if (_bottom.contains(name)) return BannerPlacement.bottom;
    return BannerPlacement.none;
  }

  static bool visibleFor(BannerPlacement slot) {
    if (!ready.value || SubscriptionService.instance.isPremium) return false;
    final p = placementFor(ScreenTracking.currentScreen.value);
    if (slot == BannerPlacement.bottom && p == BannerPlacement.result) {
      return resultShowing.value;
    }
    return p == slot;
  }

  static final Listenable _changes = Listenable.merge([
    ready,
    resultShowing,
    ScreenTracking.currentScreen,
    SubscriptionService.instance,
  ]);

  // Main tabs: banner sits right above the bottom navigation bar.
  static const Set<String> _aboveNav = {
    'my_trips_tab', 'countries_menu', 'cities_menu', 'explore_menu', 'flights_menu',
  };

  // Active game screens: banner only on the game-over / result view.
  static const Set<String> _result = {
    'flag_guess_game', 'which_is_farther_game', 'border_chain_game',
    'respawn_game', 'timezone_impostor_game', 'higher_or_lower_game',
  };

  // Pushed screens: banner anchored at the bottom, above the safe area.
  static const Set<String> _bottom = {
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
    'social_profile', 'social_badges', 'social_category_list', 'social_friends',
    'social_leaderboard', 'social_compare', 'social_duels', 'social_stats',
    'social_friend_stats', 'social_site_image', 'social_board_locked',
  };
}

/// One anchored adaptive banner. A fresh ad is requested each time it is
/// built for a new screen; AdMob refreshes it on the ad unit's interval.
class TravelogBanner extends StatefulWidget {
  const TravelogBanner({super.key, this.reportHeight});

  /// Receives the banner slot height while this banner is on screen.
  final ValueNotifier<double>? reportHeight;
  @override
  State<TravelogBanner> createState() => _TravelogBannerState();
}

class _TravelogBannerState extends State<TravelogBanner> {
  static final FacebookAppEvents _fb = FacebookAppEvents();
  BannerAd? _ad;
  AdSize? _size;
  bool _loaded = false;
  int _width = 0;
  int _retries = 0;
  Timer? _retry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (w != _width) {
      _width = w;
      _load();
    }
  }

  Future<void> _load() async {
    _retry?.cancel();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(_width);
    if (!mounted || size == null) return;
    final old = _ad;
    final ad = BannerAd(
      adUnitId: BannerAds.unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          _retries = 0;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[Banner] load failed: ${error.code} ${error.message}');
          ad.dispose();
          if (!mounted) return;
          if (identical(_ad, ad)) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
          if (_retries++ < 3) _retry = Timer(Duration(seconds: 15 * _retries), _load);
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          _fb.logEvent(name: 'AdImpression', parameters: {
            '_valueToSum': valueMicros / 1000000.0,
            'fb_currency': currencyCode,
            'ad_platform': 'admob',
            'ad_format': 'banner',
            'ad_experiment_group': AdService.instance.experimentGroup,
          });
        },
      ),
    );
    setState(() {
      _ad = ad;
      _size = size;
      _loaded = false;
    });
    widget.reportHeight?.value = size.height.toDouble();
    old?.dispose();
    await ad.load();
  }

  @override
  void dispose() {
    final report = widget.reportHeight;
    if (report != null) {
      // Defer: dispose runs during a frame and listeners rebuild other widgets.
      WidgetsBinding.instance.addPostFrameCallback((_) => report.value = 0);
    }
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (size == null) return const SizedBox.shrink();
    // Reserve the slot while loading so content does not jump when the ad fills.
    return SizedBox(
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: _loaded && _ad != null ? AdWidget(ad: _ad!) : const SizedBox.shrink(),
    );
  }
}

/// Slot right above the main bottom navigation bar (main tabs).
class AboveNavBannerSlot extends StatelessWidget {
  const AboveNavBannerSlot({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: BannerAds._changes,
        builder: (context, _) => BannerAds.visibleFor(BannerPlacement.aboveNav)
            ? TravelogBanner(reportHeight: BannerAds.aboveNavHeight)
            : const SizedBox.shrink(),
      );
}

/// Bottom spacer for the main tabs' scroll views. The tabs draw under the
/// floating nav bar (Scaffold.extendBody), so they end with empty space that
/// lets the last card scroll clear of it. The space is the larger of:
///  - [height] plus the banner above the nav bar, and
///  - the real nav bar height (MediaQuery bottom padding, which includes the
///    banner and the system navigation bar) plus [gap].
/// The fixed 120 alone was too small on 3-button-navigation phones.
class NavBarBottomSpacer extends StatelessWidget {
  const NavBarBottomSpacer({super.key, this.height = 120, this.gap = 20});
  final double height;
  final double gap;
  @override
  Widget build(BuildContext context) {
    final navInset = MediaQuery.paddingOf(context).bottom;
    return ValueListenableBuilder<double>(
      valueListenable: BannerAds.aboveNavHeight,
      builder: (context, banner, _) => SizedBox(
        height: (height + banner) > (navInset + gap) ? height + banner : navInset + gap,
      ),
    );
  }
}

/// Wraps the app's Navigator: for pushed screens with a bottom placement the
/// screen is shortened by the banner height and the banner sits above the
/// bottom safe area, so FABs and map controls move up instead of being covered.
class GlobalBottomBannerSlot extends StatelessWidget {
  const GlobalBottomBannerSlot({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: BannerAds._changes,
        child: child,
        builder: (context, child) {
          if (!BannerAds.visibleFor(BannerPlacement.bottom)) return child!;
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
                const TravelogBanner(),
                SizedBox(height: mq.padding.bottom),
              ],
            ),
          );
        },
      );
}
