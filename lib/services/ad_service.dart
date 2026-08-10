import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
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

  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  InterstitialAd? _interstitialAd;

  int _touchCount = 0;
  int _dismissCount = 0;
  DateTime? _lastShownAt;
  Timer? _timerAdTimer;

  bool _isTutorialActive = false;
  bool _isOnboardingActive = false;
  bool _isCountrySelectionActive = false;
  bool _isUiOverlayActive = false;  // 로그인/구독/프로필 시트 표시 중
  bool _isPremium = false;

  // ─── Interstitial 기준 (기존 유지) ───────────────────────────────────────
  static const int _showEveryTouches = 30;
  static const int _timerIntervalMinutes = 4;
  static const int _cooldownSeconds = 120;

  // 초기 유저 판별 기준 (광고 10회 노출 전까지는 초기 유저로 간주)
  static const int _earlyUserThreshold = 10;
  int _totalAdsShown = 0;

  // 초기 유저 여부
  bool get _isEarlyUser => _totalAdsShown < _earlyUserThreshold;

  // 초기 유저는 60회, 일반 유저는 30회마다 광고
  int get _effectiveTouchThreshold =>
      _isEarlyUser ? _showEveryTouches * 2 : _showEveryTouches;

  // 초기 유저는 8분, 일반 유저는 4분 주기
  int get _effectiveTimerMinutes =>
      _isEarlyUser ? _timerIntervalMinutes * 2 : _timerIntervalMinutes;

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
    if (!_isPremium && !_isOnboardingActive && !_isCountrySelectionActive && !_isUiOverlayActive) {
      _startTimerAd();
    }
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

  void setCountrySelectionActive() {
    _isCountrySelectionActive = true;
    _timerAdTimer?.cancel();
    debugPrint('[AdService] country selection started - ads paused');
  }

  void clearCountrySelectionActive() {
    _isCountrySelectionActive = false;
    _touchCount = 0;
    _lastShownAt = null;
    if (!_isPremium && !_isTutorialActive && !_isOnboardingActive) _startTimerAd();
    debugPrint('[AdService] country selection ended - ads resumed');
  }

  /// 로그인/구독/프로필 화면 표시 시 호출 — 터치·타이머 광고 일시정지
  void setUiOverlayActive() {
    _isUiOverlayActive = true;
    _timerAdTimer?.cancel();
    debugPrint('[AdService] UI overlay started - ads paused');
  }

  void clearUiOverlayActive() {
    _isUiOverlayActive = false;
    if (!_isPremium && !_isTutorialActive && !_isOnboardingActive && !_isCountrySelectionActive) {
      _startTimerAd();
    }
    debugPrint('[AdService] UI overlay ended - ads resumed');
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
      Duration(minutes: _effectiveTimerMinutes),
          (_) => _showAdIfReady(),
    );
  }

  // ─── Interstitial ────────────────────────────────────────────────────────

  void loadInterstitialAd() {
    if (_isPremium) return;
    if (_interstitialAd != null) return;

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;

          ad.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
            final double revenue = valueMicros / 1000000.0;
            _facebookAppEvents.logEvent(
              name: 'AdImpression',
              parameters: {
                '_valueToSum': revenue,
                'fb_currency': currencyCode,
                'ad_platform': 'admob',
              },
            );
          };

          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (InterstitialAd ad) {
                  ad.dispose();
                  _interstitialAd = null;
                  loadInterstitialAd();

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
          debugPrint('[AdService] interstitial failed to load: $error');
        },
      ),
    );
  }

  void _showAdIfReady() {
    if (_isPremium) return;
    if (_isTutorialActive) return;
    if (_isOnboardingActive) return;
    if (_isCountrySelectionActive) return;
    if (_isUiOverlayActive) return;

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
    _totalAdsShown++;
  }

  void recordGlobalTouch() {
    if (_isPremium) return;
    if (_isTutorialActive) return;
    if (_isOnboardingActive) return;
    if (_isCountrySelectionActive) return;
    if (_isUiOverlayActive) return;

    _touchCount++;
    if (_touchCount % _effectiveTouchThreshold == 0) {
      _showAdIfReady();
    }
  }

}