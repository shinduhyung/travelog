// lib/services/game_ad_service.dart
//
// Ad system for the Travelog mini-games -- completely separate from the
// main app's AdService (touch/time experiment groups). Rules:
//
//   - Premium subscribers never see an ad from this service, ever, no
//     matter what.
//   - Entering the games hub PAUSES (not resets) the main app's AdService
//     touch/time counters via AdService.pauseForGames(); leaving the hub
//     resumes them exactly where they left off via AdService.resumeForGames().
//   - For every game EXCEPT Respawn: after every 3rd finished game --
//     any game type/difficulty mixed together -- an interstitial is shown
//     2 seconds after that game ends. If the player tries to start a new
//     game inside that 2-second window, the pending ad is shown
//     immediately first, and only then does the new game start.
//   - Respawn is a special case: NO ads at all while inside Respawn.
//     On leaving Respawn, one ad shows immediately, but only if at least
//     one respawn was actually drawn during that visit.

import 'package:jidoapp/ads_mock/banner_mock.dart' show kBannerMock, BannerMock;
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:jidoapp/services/ad_service.dart';
import 'package:jidoapp/services/subscription_service.dart';

class GameAdService {
  GameAdService._();

  static final GameAdService instance = GameAdService._();

  // 게임 전용 광고 단위. 메인 앱(AdService)과 같은 광고 단위를 쓰면 두
  // 서비스가 광고를 하나씩 따로 받아두게 되는데, Unity Ads는 한 placement에
  // 광고를 1개만 받아둘 수 있어서(오류 코드 108) 서로 충돌한다. 그래서 게임은
  // 별도 광고 단위를 쓰고, 이 단위는 미디에이션 그룹에 넣지 않아 AdMob
  // (default) 그룹 = AdMob Network만 받는다.
  // Android 게임 전용 광고 단위 (interstitial_games)
  static const String _androidAdUnitId =
      'ca-app-pub-3945470636956441/8926072590';

  // iOS 게임 전용 광고 단위 (travelog_apple_interstitial_games)
  static const String _iosAdUnitId = 'ca-app-pub-3945470636956441/7830493670';

  static String get _adUnitId =>
      Platform.isIOS ? _iosAdUnitId : _androidAdUnitId;

  static const int _gamesPerAd = 3;
  static const Duration _postGameDelay = Duration(seconds: 2);

  InterstitialAd? _interstitialAd;
  DateTime? _adLoadedAt;
  bool _isLoadingAd = false;

  // 받아둔 지 이만큼 지난 광고는 띄우지 않고 새로 받는다 (AdService와 동일 기준)
  static const Duration _maxAdAge = Duration(minutes: 50);

  // 로드 실패 시 20·60·120초 간격으로 최대 3회 재시도.
  static const List<int> _retryDelaysSec = [20, 60, 120];
  int _loadRetryAttempt = 0;
  Timer? _loadRetryTimer;

  int _finishedGamesCount = 0;
  Timer? _pendingAdTimer;

  bool _respawnPlayedThisVisit = false;

  bool get _isPremium => SubscriptionService.instance.isPremium;

  // ── Entering / leaving the games hub ────────────────────────────────────

  /// Call once when the games hub is opened.
  void enterGamesArea() {
    AdService.instance.pauseForGames();
    _preloadAd();
  }

  /// Call once when leaving the games hub back to the rest of the app.
  void exitGamesArea() {
    _pendingAdTimer?.cancel();
    _pendingAdTimer = null;
    _finishedGamesCount = 0;
    AdService.instance.resumeForGames();
  }

  // ── Respawn (special-cased: no ads inside, one on the way out) ─────────

  void enterRespawn() {
    _respawnPlayedThisVisit = false;
  }

  /// Call every time a respawn is actually drawn (a round played).
  void notifyRespawnPlayed() {
    _respawnPlayedThisVisit = true;
  }

  /// Call when leaving Respawn back to the games hub.
  Future<void> exitRespawn() async {
    final shouldShow = _respawnPlayedThisVisit && !_isPremium;
    _respawnPlayedThisVisit = false;
    if (shouldShow) {
      await _showAdNow();
    }
  }

  // ── Regular games (everything except Respawn) ───────────────────────────

  /// Call when a run/game ends (game over or completed), from every game
  /// EXCEPT Respawn.
  void notifyGameFinished() {
    if (_isPremium) return;
    _finishedGamesCount++;
    if (_finishedGamesCount % _gamesPerAd == 0) {
      _pendingAdTimer?.cancel();
      _pendingAdTimer = Timer(_postGameDelay, () {
        _pendingAdTimer = null;
        _showAdNow();
      });
    }
  }

  /// Call right before navigating into a new game round (from every game
  /// EXCEPT Respawn). If a post-game ad is still pending (the player acted
  /// faster than the 2s delay), it's shown right now, first -- only after
  /// it's dismissed does this return, so the caller can safely proceed to
  /// start the new game.
  Future<void> requestStartGame() async {
    if (_isPremium) return;
    if (_pendingAdTimer != null) {
      _pendingAdTimer!.cancel();
      _pendingAdTimer = null;
      await _showAdNow();
    }
  }

  // ── Ad loading / showing ─────────────────────────────────────────────────

  void _preloadAd() {
    if (kBannerMock) return;
    if (_isPremium || _interstitialAd != null || _isLoadingAd) return;
    // 동의(UMP)/MobileAds 초기화가 끝나기 전에는 요청하지 않는다.
    if (!AdService.instance.adsInitialized) return;
    _isLoadingAd = true;
    _loadRetryTimer?.cancel();

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _adLoadedAt = DateTime.now();
          _isLoadingAd = false;
          _loadRetryAttempt = 0;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isLoadingAd = false;
          debugPrint('[GameAdService] failed to load: $error');
          if (!_isPremium && _loadRetryAttempt < _retryDelaysSec.length) {
            final int seconds = _retryDelaysSec[_loadRetryAttempt++];
            _loadRetryTimer = Timer(Duration(seconds: seconds), _preloadAd);
          }
        },
      ),
    );
  }

  Future<void> _showAdNow() async {
    if (_isPremium) return;

    if (_interstitialAd != null &&
        _adLoadedAt != null &&
        DateTime.now().difference(_adLoadedAt!) > _maxAdAge) {
      // 너무 오래 묵은 광고 — 버리고 다음 번을 위해 새로 받는다.
      _interstitialAd!.dispose();
      _interstitialAd = null;
      _adLoadedAt = null;
    }

    if (_interstitialAd == null) {
      // No ad ready yet -- don't block gameplay waiting for a network
      // load; just kick off a fresh load for next time and move on.
      _preloadAd();
      return;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;
    _adLoadedAt = null;

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadAd();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _preloadAd();
        if (!completer.isCompleted) completer.complete();
      },
    );

    await ad.show();
    await completer.future;
  }
}
