import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';
import 'package:jidoapp/main.dart' show navigatorKey;

/// v5 실험 구성 — 연속값(랜덤 정수) 반응표면설계
///
/// 이전 v4(쿨다운 a/b/c × 터치 x/y/z 3단계)에서 "쿨다운(시간조건)이 진짜
/// 병목이고 터치조건은 거의 영향이 없다"는 게 확인됐지만, 3단계로는 최적점을
/// 못 찾음. 표본을 더 효율적으로 쓰기 위해 이산형 대신 연속값으로 전환.
///
/// 축1 — 시간조건(경과시간) — 101~130초 사이 정수, 기기별 완전 무작위 배정
/// 축2 — 국가 선택 화면 광고 노출 (1/2) — 계속 실험 중
///   1: 광고 차단 / 2: 광고 허용
/// 축3 — 터치조건 — 21~35회 사이 정수, 기기별 완전 무작위 배정
///
/// 시간조건과 터치조건은 동등한 자격의 OR 트리거 — 둘 중 뭐든 먼저
/// 충족되면 광고가 뜨고, 그 순간 둘 다 리셋됨(더 이상 "쿨다운"이라는
/// 별도의 최소간격 하한선 개념 없음).
///
/// 그룹 라벨은 "시간조건-국가-터치조건" 형식의 숫자 조합(예: "115-1-28").
/// 문자 기반이던 이전 라벨들(A-1-X, a-1-x)과 형식이 아예 달라서
/// 컬렉션 그대로 재사용해도 안 섞임. pref 키만 새 버전으로.
enum CountryAdGroup { block, allow }

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

  int _touchesSinceLastAd = 0; // 직전 노출 이후 터치 수 — 터치 트리거이자 계측용 겸용
  String? _pendingTriggerSource; // 이번 노출을 유발한 조건: 'touch' | 'timer'
  int? _pendingElapsedSeconds; // 직전 노출 이후 경과 시간(초)
  int? _pendingTouchesSinceLastAd; // 직전 노출 이후 터치 수 (캡처된 값)
  int _dismissCount = 0;
  DateTime? _lastShownAt;
  Timer? _timeTriggerTimer; // 경과시간 트리거용 — 광고 뜰 때마다 재시작(리셋)됨

  bool _isTutorialActive = false;
  bool _isOnboardingActive = false;
  bool _isCountrySelectionActive = false;
  bool _isUiOverlayActive = false;  // 로그인/구독/프로필 시트 표시 중
  bool _isPremium = false;

  // ─── 시간조건(101~130초 연속) × 국가선택(1/2) × 터치조건(21~35 연속) ─────
  // v4(이산형 3단계) 구조를 종료하고 v5(연속값)로 교체.
  static const String _prefKeyExperimentGroup = 'ad_experiment_group_v5';
  static const String _prefKeyAssignedAt = 'ad_experiment_group_v5_assigned_at';
  static const String _prefKeyDeviceId = 'ad_experiment_device_id';
  static const String _prefKeyAssignmentDocId = 'ad_experiment_assignment_doc_id';

  static const int _timeConditionMin = 101;
  static const int _timeConditionMax = 130; // inclusive
  static const int _touchConditionMin = 21;
  static const int _touchConditionMax = 35; // inclusive

  int _cooldownSeconds = 115; // 배정 완료 전까지만 쓰이는 임시 기본값 (범위 중간값)
  CountryAdGroup _countryAdGroup = CountryAdGroup.block;
  int _touchThreshold = 28; // 배정 완료 전까지만 쓰이는 임시 기본값 (범위 중간값)
  String _groupLabel = '115-1-28';
  DateTime? _assignedAt;

  /// 이 기기가 지금 버전 실험 그룹(v5)에 배정된 시각. subscription_service에서
  /// 구독/퍼널 이벤트에 같이 기록해서, "이 주문이 지금 실험 대상 유저 것인지"
  /// 구분하는 데 씀. 배정 전이면 null.
  DateTime? get assignedAt => _assignedAt;

  String? _deviceId;

  /// 기기별 고유 ID (앱 최초 실행 시 1회 생성, 영구 고정).
  /// "가입일 기준"/"노출 기준" 집계 모드에서 같은 유저의 이벤트를
  /// 하나로 묶어서 셀 수 있게 해줌. deviceId 도입 이전에 쌓인 데이터에는
  /// 없으므로, 그런 데이터는 계속 "당일 기준"으로만 정확히 집계됨.
  String? get deviceId => _deviceId;

  /// 현재 배정된 실험 그룹 라벨 (예: "115-1-28", "103-2-33"
  /// — "시간조건-국가-터치조건"). 구독 등 다른 서비스에서
  /// 매출-그룹 연결용으로 참조.
  String get experimentGroup => _groupLabel;

  bool get _countryScreenAdsEnabledForGroup =>
      _countryAdGroup == CountryAdGroup.allow;

  // Show subscription sheet every 3 ad dismissals
  static const int _subscriptionPromptEvery = 3;

  static const String _realInterstitialAdUnitId =
      'ca-app-pub-3945470636956441/8397434180'; // interstitial_main — mediation group 연결되어 정상 수익 확인됨

  String get _adUnitId => _realInterstitialAdUnitId;

  void _onPremiumActivated() {
    _isPremium = true;
    _timeTriggerTimer?.cancel();
    _interstitialAd?.dispose();
    _interstitialAd = null;
    debugPrint('[AdService] premium activated - ads disabled');
  }

  void _onPremiumDeactivated() {
    _isPremium = false;
    loadInterstitialAd();
    _refreshTimerState();
    debugPrint('[AdService] premium deactivated - ads resumed');
  }

  void setTutorialActive() {
    _isTutorialActive = true;
    _refreshTimerState();
  }

  void clearTutorialActive() {
    _isTutorialActive = false;
    _touchesSinceLastAd = 0;
    _lastShownAt = DateTime.now(); // 재개 시점부터 두 트리거 다 새로 카운트
    _refreshTimerState();
  }

  /// 온보딩 화면은 실험 축에서 제외 — 항상 광고 차단 (baseline 고정)
  void setOnboardingActive() {
    _isOnboardingActive = true;
    _refreshTimerState();
    debugPrint('[AdService] onboarding started - ads paused (non-experimental)');
  }

  void clearOnboardingActive() {
    _isOnboardingActive = false;
    _touchesSinceLastAd = 0;
    _lastShownAt = DateTime.now();
    _refreshTimerState();
    debugPrint('[AdService] onboarding ended - ads resumed');
  }

  void setCountrySelectionActive() {
    _isCountrySelectionActive = true;
    _refreshTimerState();
    debugPrint(
      '[AdService] country selection started - ads '
          '${_countryScreenAdsEnabledForGroup ? "kept on (group $_groupLabel)" : "paused"}',
    );
  }

  void clearCountrySelectionActive() {
    _isCountrySelectionActive = false;
    _touchesSinceLastAd = 0;
    _lastShownAt = DateTime.now();
    _refreshTimerState();
    debugPrint('[AdService] country selection ended - ads resumed');
  }

  /// 로그인/구독/프로필 시트 표시 시 호출 — 터치·타이머 광고 일시정지
  void setUiOverlayActive() {
    _isUiOverlayActive = true;
    _refreshTimerState();
    debugPrint('[AdService] UI overlay started - ads paused');
  }

  void clearUiOverlayActive() {
    _isUiOverlayActive = false;
    _refreshTimerState();
    debugPrint('[AdService] UI overlay ended - ads resumed');
  }

  /// 지금 광고를 멈춰야 하는 상태인지.
  bool get _shouldPauseAds {
    if (_isPremium) return true;
    if (_isTutorialActive) return true;
    if (_isUiOverlayActive) return true;
    if (_isOnboardingActive) return true;
    if (_isCountrySelectionActive && !_countryScreenAdsEnabledForGroup) return true;
    return false;
  }

  /// 경과시간 트리거를 다시 스케줄링 — 마지막 노출 시각(_lastShownAt) 기준으로
  /// "쿨다운값(_cooldownSeconds)이 지나는 그 시점"에 정확히 한 번 울리게 함.
  /// 광고가 뜰 때마다, 또는 일시정지 상태가 바뀔 때마다 반드시 다시 호출해서
  /// 리셋해야 함 — 터치/시간 둘 중 하나라도 충족되면 둘 다 리셋되는 설계라서.
  void _refreshTimerState() {
    _timeTriggerTimer?.cancel();
    if (_shouldPauseAds) return;

    final now = DateTime.now();
    final elapsed = _lastShownAt == null ? Duration.zero : now.difference(_lastShownAt!);
    final remaining = Duration(seconds: _cooldownSeconds) - elapsed;
    final wait = remaining.isNegative ? Duration.zero : remaining;

    _timeTriggerTimer = Timer(wait, () => _showAdIfReady('timer'));
  }

  Future<void> initialize() async {
    _isPremium = SubscriptionService.instance.isPremium;
    await _assignExperimentGroupIfNeeded();
    _logAppOpenEvent(); // 리텐션(D3/D7)·마지막 접속일 계측용 — 매 실행마다 1건

    // ─── GDPR/UMP consent 흐름 ────────────────────────────────────────────
    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
          () async {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint(
              '[Consent] form error: ${formError.errorCode} ${formError.message}',
            );
          }
          final canRequestAds =
          await ConsentInformation.instance.canRequestAds();
          debugPrint('[Consent] canRequestAds=$canRequestAds');
          if (canRequestAds) {
            _startAdsAfterConsent();
          }
        });
      },
          (formError) async {
        debugPrint(
          '[Consent] update error: ${formError.errorCode} ${formError.message}',
        );
        final canRequestAds =
        await ConsentInformation.instance.canRequestAds();
        if (canRequestAds) {
          _startAdsAfterConsent();
        }
      },
    );
  }

  void _startAdsAfterConsent() {
    if (!_isPremium) {
      loadInterstitialAd();
      _refreshTimerState();
    } else {
      debugPrint('[AdService] premium user - skipping ad load');
    }
  }

  /// 최초 1회, 완전 무작위로 3×2×3=18가지 조합 중 하나에 배정. 이후 영구 고정.
  /// pref 키가 v4로 바뀌었기 때문에 기존(v3) 배정 기기도 새로 배정됨.
  Future<void> _assignExperimentGroupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    String? deviceId = prefs.getString(_prefKeyDeviceId);
    final bool isNewDeviceId = deviceId == null;
    if (isNewDeviceId) {
      deviceId = _generateDeviceId();
      await prefs.setString(_prefKeyDeviceId, deviceId);
    }
    _deviceId = deviceId;

    String? saved = prefs.getString(_prefKeyExperimentGroup);

    if (saved == null) {
      final timeCondition =
          _timeConditionMin + Random().nextInt(_timeConditionMax - _timeConditionMin + 1); // 101~130
      final countryIndex = Random().nextInt(2); // 0~1 -> 1(block)/2(allow)
      final touchCondition =
          _touchConditionMin + Random().nextInt(_touchConditionMax - _touchConditionMin + 1); // 21~35
      saved = '$timeCondition-${countryIndex + 1}-$touchCondition';
      final now = DateTime.now();
      await prefs.setString(_prefKeyExperimentGroup, saved);
      await prefs.setString(_prefKeyAssignedAt, now.toIso8601String());
      _assignedAt = now;
      debugPrint('[AdService] new experiment group assigned: $saved');
      final docRef = await _logExperimentAssignment(saved);
      // 배정 문서 ID를 저장해둠 — 나중에 필드를 또 추가해야 할 때
      // (지금의 deviceId 케이스처럼) 이 기기의 배정 문서를 정확히 찾아서
      // 백필할 수 있게 하기 위함.
      if (docRef != null) {
        await prefs.setString(_prefKeyAssignmentDocId, docRef.id);
      }
    } else {
      final savedAt = prefs.getString(_prefKeyAssignedAt);
      _assignedAt = savedAt != null ? DateTime.tryParse(savedAt) : null;

      // 이미 배정된 기존 유저인데 deviceId가 이번에 처음 생겼다면
      // (=deviceId 도입 이전에 배정된 기기), 로컬에 저장된 배정 문서 ID가
      // 있는 경우에 한해 그 문서에 deviceId를 백필. 문서 ID가 없으면
      // (이 저장 로직 자체가 생기기 전에 배정된 아주 예전 기기) 어느 문서가
      // 내 것인지 특정할 방법이 없어서 백필 불가 — 그런 기기는 "당일 기준"
      // 모드로만 정확히 집계됨.
      if (isNewDeviceId) {
        final docId = prefs.getString(_prefKeyAssignmentDocId);
        if (docId != null) {
          _backfillDeviceIdToAssignment(docId);
        }
      }
    }

    _applyGroupLabel(saved);
  }

  /// deviceId 도입 이전에 배정된 기존 유저의 배정 문서에 deviceId/국가코드를
  /// 뒤늦게 채워 넣음. 실패해도 그룹 배정/광고 동작에는 영향 없음.
  Future<void> _backfillDeviceIdToAssignment(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ad_experiment_assignments_v3')
          .doc(docId)
          .update({
        'deviceId': _deviceId,
        'localeCountryCode':
        WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? 'unknown',
      });
      debugPrint('[AdService] backfilled deviceId onto assignment doc $docId');
    } catch (e) {
      debugPrint('[AdService] deviceId backfill error: $e');
    }
  }

  /// 32자리 랜덤 16진수 문자열 (128bit) — 기기별 고유 ID로 충분한 무작위성.
  String _generateDeviceId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 그룹별 모수(배정된 유저 수) 계산용 — 신규 배정 시 1회만 기록.
  /// 숫자 라벨(예: "115-1-28")이라 이전 실험들의 문자 기반 라벨(A-1-X,
  /// a-1-x)과 형식이 아예 달라서 컬렉션 그대로 재사용 가능.
  /// 실패해도 실제 그룹 배정/광고 동작에는 영향 주지 않음.
  /// 반환값(DocumentReference)의 id를 로컬에 저장해서, 나중에 필드를 또
  /// 추가해야 할 때 이 기기의 배정 문서를 정확히 찾아 백필할 수 있게 함.
  Future<DocumentReference<Map<String, dynamic>>?> _logExperimentAssignment(
      String groupLabel) async {
    try {
      return await FirebaseFirestore.instance.collection('ad_experiment_assignments_v3').add({
        'adExperimentGroup': groupLabel,
        'deviceId': _deviceId,
        // 기기 로케일 기준 국가코드 — 로그인 여부와 무관하게 전원한테 붙음.
        // GPS 아니라 시스템 설정값이라 대략치 (VPN/언어만 바꾼 유저는 부정확할 수 있음).
        'localeCountryCode': WidgetsBinding.instance.platformDispatcher.locale.countryCode ?? 'unknown',
        'assignedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AdService] assignment log error: $e');
      return null;
    }
  }

  void _applyGroupLabel(String label) {
    _groupLabel = label;
    final parts = label.split('-'); // ["115", "1", "28"]
    _cooldownSeconds = int.tryParse(parts.isNotEmpty ? parts[0] : '') ??
        ((_timeConditionMin + _timeConditionMax) ~/ 2);
    final countryDigit = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    _touchThreshold = int.tryParse(parts.length > 2 ? parts[2] : '') ??
        ((_touchConditionMin + _touchConditionMax) ~/ 2);

    _countryAdGroup =
    countryDigit == 2 ? CountryAdGroup.allow : CountryAdGroup.block;
  }

  // ─── Interstitial ────────────────────────────────────────────────────────

  void loadInterstitialAd() {
    if (_isPremium) return;
    if (_interstitialAd != null) return;

    _logAdRequestToFirestore(); // 실제 로드 요청 시점 기록 (fill rate 계산용)

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          final String adSourceName =
              ad.responseInfo?.mediationAdapterClassName ?? 'unknown';

          ad.onPaidEvent = (Ad ad, double valueMicros, PrecisionType precision, String currencyCode) {
            final double revenue = valueMicros / 1000000.0;

            _facebookAppEvents.logEvent(
              name: 'AdImpression',
              parameters: {
                '_valueToSum': revenue,
                'fb_currency': currencyCode,
                'ad_platform': 'admob',
                'ad_experiment_group': _groupLabel,
              },
            );

            _logAdRevenueToFirestore(
              revenue: revenue,
              currencyCode: currencyCode,
              precision: precision.toString(),
              adSourceName: adSourceName,
            );
          };

          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdImpression: (InterstitialAd ad) {
                  // 실제 노출이 몇 번 일어나는지 별도 기록 —
                  // onPaidEvent 발생 횟수와 비교해서 격차를 직접 확인하기 위함.
                  _logAdImpressionToFirestore();
                },
                onAdDismissedFullScreenContent: (InterstitialAd ad) {
                  ad.dispose();
                  _interstitialAd = null;
                  loadInterstitialAd();

                  _dismissCount++;
                  if (_dismissCount % _subscriptionPromptEvery == 0) {
                    final ctx = navigatorKey.currentContext;
                    if (ctx != null) {
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (ctx.mounted) {
                          SubscriptionSheet.show(ctx, triggerContext: 'ad_dismiss');
                        }
                      });
                    }
                  }
                },
                onAdFailedToShowFullScreenContent:
                    (InterstitialAd ad, AdError error) {
                  debugPrint('[AdService] failed to show: code=${error.code} '
                      'domain=${error.domain} msg=${error.message}');
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

  /// 앱을 켤 때마다 1건 기록 — 이 기록들의 날짜 분포로 리텐션(D3/D7)을
  /// 계산하고, "마지막으로 언제 켰는지"를 마지막 노출 시각과 비교해서
  /// 이탈(삭제 추정)을 근사할 수 있음. 앱이 실제로 삭제됐는지는 원천적으로
  /// 알 수 없어서 어디까지나 근사치.
  Future<void> _logAppOpenEvent() async {
    try {
      await FirebaseFirestore.instance.collection('app_open_events').add({
        'adExperimentGroup': _groupLabel,
        'deviceId': _deviceId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AdService] app open log error: $e');
    }
  }

  /// 광고 요청(load 시도) 횟수 기록 — 노출(impression)과 나눠서
  /// 그룹별 fill rate(노출/요청)를 계산할 수 있게 함.
  Future<void> _logAdRequestToFirestore() async {
    try {
      await FirebaseFirestore.instance.collection('ad_request_events').add({
        'adExperimentGroup': _groupLabel,
        'deviceId': _deviceId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AdService] request log error: $e');
    }
  }

  /// 실제 노출 횟수 기록용 (onPaidEvent 발생 횟수와 비교해서
  /// paid event 누락 격차를 직접 증명하기 위함). 실패해도 광고 흐름엔 영향 없음.
  /// triggerSource/elapsedSeconds/touchesSinceLastAd — 병목조건 비율, 평균
  /// 소요시간·터치수 계측용. _showAdIfReady()에서 캡처된 값을 그대로 씀.
  Future<void> _logAdImpressionToFirestore() async {
    try {
      await FirebaseFirestore.instance.collection('ad_impression_events').add({
        'adExperimentGroup': _groupLabel,
        'deviceId': _deviceId,
        'triggerSource': _pendingTriggerSource ?? 'unknown',
        'elapsedSecondsSinceLastAd': _pendingElapsedSeconds,
        'touchesSinceLastAd': _pendingTouchesSinceLastAd,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AdService] impression log error: $e');
    }
  }

  /// 그룹별 실제 광고 ARPU 계산용 원시 이벤트 기록.
  /// precision을 같이 남겨서 0원 이벤트가 estimated/unknown 때문인지 나중에 구분 가능.
  /// 실패해도 실제 광고 노출/과금 흐름에는 영향 주지 않음.
  Future<void> _logAdRevenueToFirestore({
    required double revenue,
    required String currencyCode,
    required String precision,
    required String adSourceName,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('ad_revenue_events').add({
        'adExperimentGroup': _groupLabel,
        'deviceId': _deviceId,
        'revenue': revenue,
        'currencyCode': currencyCode,
        'precision': precision,
        'adSourceName': adSourceName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AdService] revenue log error: $e');
    }
  }

  /// 터치임계값과 경과시간(쿨다운값) 중 하나라도 충족되면 호출됨 — 둘은
  /// 동등한 자격의 OR 트리거. 실제로 광고가 뜨면 두 카운터(터치/시간) 다
  /// 리셋되고, 시간트리거 타이머도 이 시점부터 다시 스케줄링됨.
  void _showAdIfReady(String triggerSource) {
    if (_shouldPauseAds) return;

    if (_interstitialAd == null) {
      loadInterstitialAd();
      return;
    }

    final now = DateTime.now();
    // 이번 노출을 유발한 조건(터치/시간)과, 직전 노출 이후 경과시간·터치수 캡처 —
    // onAdImpression에서 실제 노출 확정될 때 같이 기록됨.
    _pendingTriggerSource = triggerSource;
    _pendingElapsedSeconds =
    _lastShownAt == null ? null : now.difference(_lastShownAt!).inSeconds;
    _pendingTouchesSinceLastAd = _touchesSinceLastAd;

    _touchesSinceLastAd = 0;
    _lastShownAt = now;
    _interstitialAd!.show();
    _interstitialAd = null;

    _refreshTimerState(); // 시간트리거를 지금 시점부터 다시 카운트하게 재시작
  }

  void recordGlobalTouch() {
    if (_shouldPauseAds) return;

    _touchesSinceLastAd++;
    if (_touchesSinceLastAd >= _touchThreshold) {
      _showAdIfReady('touch');
    }
  }

}