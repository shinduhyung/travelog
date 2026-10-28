import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:jidoapp/services/ad_service.dart';
import 'package:jidoapp/services/subscription_service.dart';

enum RewardedUnlockResult { unlocked, unavailable, dismissed }

/// Locked statistics stay open for the rest of the app session once the user
/// has watched a rewarded video for them. Nothing is persisted on purpose:
/// the unlock is a taste of premium, not a permanent entitlement.
class RewardedUnlockService extends ChangeNotifier {
  RewardedUnlockService._();

  static final RewardedUnlockService instance = RewardedUnlockService._();

  // rewarded_main — separate units for Android and iOS.
  static const String _androidAdUnitId =
      'ca-app-pub-3945470636956441/3552803597';
  static const String _iosAdUnitId = 'ca-app-pub-3945470636956441/7035398704';

  static String get _adUnitId =>
      Platform.isIOS ? _iosAdUnitId : _androidAdUnitId;

  /// False when this platform has no rewarded unit configured.
  static bool get isSupported => _adUnitId.isNotEmpty;

  final Set<String> _unlocked = {};
  RewardedAd? _ad;
  bool _loading = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;
  static const List<int> _retryDelaysSec = [10, 30, 60];

  bool get isReady => _ad != null;
  bool get isLoading => _loading;

  bool isUnlocked(String statKey) =>
      SubscriptionService.instance.isPremium || _unlocked.contains(statKey);

  /// Starts loading the next rewarded ad if none is ready. Safe to call often.
  void preload() {
    if (!isSupported) return;
    if (SubscriptionService.instance.isPremium) return;
    if (_ad != null || _loading) return;
    // Consent (UMP) and MobileAds.initialize must finish before any request.
    if (!AdService.instance.adsInitialized) return;

    _loading = true;
    _retryTimer?.cancel();
    notifyListeners();

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          _retryAttempt = 0;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _loading = false;
          debugPrint('[RewardedUnlock] failed to load: $error');
          if (_retryAttempt < _retryDelaysSec.length) {
            _retryTimer = Timer(
              Duration(seconds: _retryDelaysSec[_retryAttempt++]),
              preload,
            );
          }
          notifyListeners();
        },
      ),
    );
  }

  /// Shows the rewarded ad and unlocks [statKey] if the user earns the reward.
  Future<RewardedUnlockResult> watchToUnlock(String statKey) async {
    final ad = _ad;
    if (ad == null) {
      preload();
      return RewardedUnlockResult.unavailable;
    }
    _ad = null;

    final completer = Completer<RewardedUnlockResult>();
    var earned = false;

    // Keep the timed interstitial from firing on top of the rewarded video.
    AdService.instance.setUiOverlayActive();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        AdService.instance.clearUiOverlayActive();
        preload();
        if (!completer.isCompleted) {
          completer.complete(
            earned
                ? RewardedUnlockResult.unlocked
                : RewardedUnlockResult.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[RewardedUnlock] failed to show: $error');
        ad.dispose();
        AdService.instance.clearUiOverlayActive();
        preload();
        if (!completer.isCompleted) {
          completer.complete(RewardedUnlockResult.unavailable);
        }
      },
    );

    await ad.show(
      onUserEarnedReward: (_, __) {
        earned = true;
        _unlocked.add(statKey);
        notifyListeners();
      },
    );
    return completer.future;
  }

  @visibleForTesting
  void unlockForTest(String statKey) {
    _unlocked.add(statKey);
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _unlocked.clear();
    notifyListeners();
  }
}
