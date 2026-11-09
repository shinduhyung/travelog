import 'ad_service.dart';
import 'rewarded_unlock_service.dart';
import 'subscription_service.dart';

/// One survey owns one frozen interval, including its optional rewarded video.
class SurveyAdSession {
  final Object Function() _pause;
  final void Function(Object) _resume;
  final bool Function() _needsAd;
  final Future<RewardedUnlockResult> Function(String) _watch;
  Object? _token;
  bool _busy = false;

  SurveyAdSession({
    required Object Function() pause,
    required void Function(Object) resume,
    required bool Function() needsAd,
    required Future<RewardedUnlockResult> Function(String) watch,
  }) : _pause = pause,
       _resume = resume,
       _needsAd = needsAd,
       _watch = watch;

  factory SurveyAdSession.live() => SurveyAdSession(
    pause: AdService.instance.pauseForPersonalityTest,
    resume: AdService.instance.resumeForPersonalityTest,
    needsAd: () =>
        !SubscriptionService.instance.isPremium &&
        RewardedUnlockService.isSupported,
    watch: RewardedUnlockService.instance.watchToUnlock,
  );

  bool get needsAd => _needsAd();
  void enter() {
    _token ??= _pause();
  }

  void leave() {
    final token = _token;
    _token = null;
    if (token != null) _resume(token);
  }

  Future<RewardedUnlockResult> unlock(String key) async {
    if (!needsAd) return RewardedUnlockResult.unlocked;
    if (_busy) return RewardedUnlockResult.dismissed;
    _busy = true;
    try {
      final result = await _watch(key);
      return needsAd ? result : RewardedUnlockResult.unlocked;
    } finally {
      _busy = false;
    }
  }
}
