import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';
import 'package:jidoapp/main.dart' show navigatorKey;

class AdService {
  AdService._() {
    AdServiceSubscriptionBridge.instance.register(
      onActivated: _onPremiumActivated,
      onDeactivated: _onPremiumDeactivated,
    );
  }

  static final AdService instance = AdService._();

  InterstitialAd? _interstitialAd;

  int _touchCount = 0;
  int _dismissCount = 0;
  DateTime? _lastShownAt;
  Timer? _timerAdTimer;

  bool _isTutorialActive = false;
  bool _isOnboardingActive = false;
  bool _isPremium = false;

  static const int _showEveryTouches = 30;
  static const int _timerIntervalMinutes = 2;
  static const int _cooldownSeconds = 30;

  // Show subscription sheet every 3 ad dismissals
  static const int _subscriptionPromptEvery = 3;

  static const String _realInterstitialAdUnitId =
      'ca-app-pub-3945470636956441/8397434180';

  String get _adUnitId => _realInterstitialAdUnitId;

  void _onPremiumActivated() {
    _isPremium = true;
    _timerAdTimer?.cancel();
    _interstitialAd?.dispose();
    _interstitialAd = null;
    debugPrint('[AdService] premium activated - ads disabled');
  }

  void _onPremiumDeactivated() {
    _isPremium = false;
    loadInterstitialAd();
    _startTimerAd();
    debugPrint('[AdService] premium deactivated - ads resumed');
  }

  void setTutorialActive() {
    _isTutorialActive = true;
    _timerAdTimer?.cancel();
  }

  void clearTutorialActive() {
    _isTutorialActive = false;
    _touchCount = 0;
    _lastShownAt = null;
    if (!_isPremium) _startTimerAd();
  }

  void setOnboardingActive() {
    _isOnboardingActive = true;
    _timerAdTimer?.cancel();
    debugPrint('[AdService] onboarding started - ads paused');
  }

  void clearOnboardingActive() {
    _isOnboardingActive = false;
    _touchCount = 0;
    _lastShownAt = null;
    if (!_isPremium && !_isTutorialActive) _startTimerAd();
    debugPrint('[AdService] onboarding ended - ads resumed');
  }

  void initialize() {
    _isPremium = SubscriptionService.instance.isPremium;
    if (!_isPremium) {
      loadInterstitialAd();
    } else {
      debugPrint('[AdService] premium user - skipping ad load');
    }
  }

  void _startTimerAd() {
    _timerAdTimer?.cancel();
    _timerAdTimer = Timer.periodic(
      const Duration(minutes: _timerIntervalMinutes),
          (_) => _showAdIfReady(),
    );
  }

  void loadInterstitialAd() {
    if (_isPremium) return;
    if (_interstitialAd != null) return;

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (InterstitialAd ad) {
                  ad.dispose();
                  _interstitialAd = null;
                  loadInterstitialAd();

                  // Show subscription sheet every N dismissals
                  _dismissCount++;
                  if (_dismissCount % _subscriptionPromptEvery == 0) {
                    final ctx = navigatorKey.currentContext;
                    if (ctx != null) {
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (ctx.mounted) SubscriptionSheet.show(ctx);
                      });
                    }
                  }
                },
                onAdFailedToShowFullScreenContent:
                    (InterstitialAd ad, AdError error) {
                  ad.dispose();
                  _interstitialAd = null;
                  loadInterstitialAd();
                },
              );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          debugPrint('[AdService] ad failed to load: $error');
        },
      ),
    );
  }

  void _showAdIfReady() {
    if (_isPremium) return;
    if (_isTutorialActive) return;
    if (_isOnboardingActive) return;

    final now = DateTime.now();
    final bool cooldownOk = _lastShownAt == null ||
        now.difference(_lastShownAt!).inSeconds >= _cooldownSeconds;

    if (!cooldownOk) return;

    if (_interstitialAd == null) {
      loadInterstitialAd();
      return;
    }

    _lastShownAt = now;
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  void recordGlobalTouch() {
    if (_isPremium) return;
    if (_isTutorialActive) return;
    if (_isOnboardingActive) return;

    _touchCount++;
    if (_touchCount % _showEveryTouches == 0) {
      _showAdIfReady();
    }
  }
}