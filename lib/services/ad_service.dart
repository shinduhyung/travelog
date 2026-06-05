import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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

  int _totalAdsShown = 0; // 누적 광고 표시 횟수 (SharedPreferences 영구 저장)
  static const String _prefKeyTotalAds = 'total_ads_shown';

  bool _isTutorialActive = false;
  bool _isOnboardingActive = false;
  bool _isCountrySelectionActive = false;
  bool _isPremium = false;

  static const int _showEveryTouches = 30;
  static const int _timerIntervalMinutes = 4;
  static const int _cooldownSeconds = 120;
  static const int _earlyUserThreshold = 10; // 처음 10회까지 완화 적용

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

  void initialize() {
    _isPremium = SubscriptionService.instance.isPremium;
    _loadTotalAdsShown();
    if (!_isPremium) {
      loadInterstitialAd();
    } else {
      debugPrint('[AdService] premium user - skipping ad load');
    }
  }

  Future<void> _loadTotalAdsShown() async {
    final prefs = await SharedPreferences.getInstance();
    _totalAdsShown = prefs.getInt(_prefKeyTotalAds) ?? 0;
    debugPrint('[AdService] totalAdsShown loaded: $_totalAdsShown');
  }

  Future<void> _incrementTotalAdsShown() async {
    _totalAdsShown++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyTotalAds, _totalAdsShown);
  }

  // 현재 유저가 초기 유저인지 여부
  bool get _isEarlyUser => _totalAdsShown < _earlyUserThreshold;

  int get _effectiveTouchThreshold =>
      _isEarlyUser ? _showEveryTouches * 2 : _showEveryTouches;

  int get _effectiveTimerMinutes =>
      _isEarlyUser ? _timerIntervalMinutes * 2 : _timerIntervalMinutes;

  void _startTimerAd() {
    _timerAdTimer?.cancel();
    _timerAdTimer = Timer.periodic(
      Duration(minutes: _effectiveTimerMinutes),
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
    if (_isCountrySelectionActive) return;

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
    _incrementTotalAdsShown().then((_) {
      // 10회 도달 시 타이머 간격을 정상으로 재시작
      if (_totalAdsShown == _earlyUserThreshold) {
        debugPrint('[AdService] early user period ended - resuming normal ad frequency');
        if (!_isPremium && !_isTutorialActive && !_isOnboardingActive && !_isCountrySelectionActive) {
          _startTimerAd();
        }
      }
    });
  }

  void recordGlobalTouch() {
    if (_isPremium) return;
    if (_isTutorialActive) return;
    if (_isOnboardingActive) return;
    if (_isCountrySelectionActive) return;

    _touchCount++;
    if (_touchCount % _effectiveTouchThreshold == 0) {
      _showAdIfReady();
    }
  }
}