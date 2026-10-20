import 'dart:async';
import 'package:jidoapp/services/screen_tracking.dart';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';
import 'package:jidoapp/main.dart' show navigatorKey;

/// v5 실험 구성 — 시간조건/터치조건 고정, 국가축만 계속 실험
///
/// [변경] 시간조건(경과시간)과 터치조건은 더 이상 랜덤 배정하지 않고
/// 각각 130초 / 40회로 고정. 표본을 국가 축(광고 차단 vs 허용) 하나에
/// 온전히 집중시키기 위함. 시간조건과 터치조건은 여전히 동등한 자격의
/// OR 트리거로 동작 — 둘 중 뭐든 먼저 충족되면 광고가 뜨고, 그 순간
/// 둘 다 리셋됨.
///
/// 축1 — 시간조건(경과시간) — 130초 고정
/// 축2 — 국가 선택 화면 광고 노출 (1/2) — 계속 실험 중
///   1: 광고 차단 / 2: 광고 허용
/// 축3 — 터치조건 — 40회 고정 (기존 35회에서 상향)
///
/// [추가] 튜토리얼 종료 직후 1회성 3분(180초) 유예 기간.
/// 온보딩 튜토리얼이 끝나는 순간부터 180초 동안은 터치 트리거를
/// 완전히 무시하고, 오직 시간 트리거(180초)만 동작한다. 그 180초가
/// 지나 첫 광고가 뜨면 유예가 해제되고, 그 다음부터는 평소의
/// 130초/40터치 OR 트리거 로직으로 정상 전환된다.
///
/// 그룹 라벨은 "시간조건-국가-터치조건" 형식의 숫자 조합(예: "130-1-40").
/// 이전 라벨 형식(A-1-X, a-1-x / 연속값 "115-1-28" 등)과 값이 겹치지
/// 않으므로 컬렉션 그대로 재사용해도 안 섞임. pref 키만 새 버전으로.
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
  String?
  _pendingTriggerSource; // 이번 노출을 유발한 조건: 'touch' | 'timer' (Firestore 계측용)
  int? _pendingElapsedSeconds; // 직전 노출 이후 경과 시간(초) (Firestore 계측용)
  int? _pendingTouchesSinceLastAd; // 직전 노출 이후 터치 수 (Firestore 계측용)
  int _dismissCount = 0;
  DateTime? _lastShownAt;
  Timer? _timeTriggerTimer; // 경과시간 트리거용 — 광고 뜰 때마다 재시작(리셋)됨

  // [추가] 화면 전환 시점까지 광고 노출을 미루기 위한 pending 상태.
  //
  // 130초/40터치 조건이 충족되는 순간 광고를 바로 show하지 않고, 여기에
  // "노출 대기 중"으로만 표시해둔다. 실제 노출은 오직 실제 PageRoute
  // 화면 전환이 감지되는 시점(onScreenTransition)에만 일어난다.
  //
  // _isAdPending이 true인 동안에는 새로운 touch/timer 트리거가 절대
  // 추가로 queue되지 않는다(광고는 한 번에 1개만 pending 가능) — 아래
  // recordGlobalTouch()/_refreshTimerState()의 가드 참고.
  bool _isAdPending = false;
  String? _queuedTriggerSource; // pending을 만든 최초 조건: 'touch' | 'timer'
  int?
  _queuedElapsedSeconds; // 조건 충족 "그 순간"의 경과 시간(초) — 화면 전환까지 기다린 시간은 포함하지 않음
  int? _queuedTouchesSinceLastAd; // 조건 충족 "그 순간"의 터치 수

  // 화면 전환이 감지된 직후, Navigator push/pop 애니메이션과 겹치지 않게
  // pending 광고를 보여주기 전에 두는 짧은 유예 시간. MaterialPageRoute의
  // 기본 전환 애니메이션 길이(300ms)에 맞춘 것으로, 불필요하게 길게
  // 기다리지 않으면서도 새 화면이 안정적으로 자리잡은 뒤에 광고가 뜨게 함.
  static const Duration _screenTransitionAdDelay = Duration(milliseconds: 300);

  bool _isTutorialActive = false;
  bool _isOnboardingActive = false;
  bool _isCountrySelectionActive = false;
  bool _isUiOverlayActive = false; // 로그인/구독/프로필 시트 표시 중
  bool _isPremium = false;

  // [추가] 게임 허브(Travelog Games) 진입 중에는 메인 앱의 터치/시간 광고 트리거를 완전히
  // 멈춰야 하되, 카운트는 리셋하지 않고 그대로 보존했다가 게임 밖으로
  // 나가는 순간 정확히 그 지점부터 다시 이어가야 함(게임 화면에서
  // GameAdService라는 별개의 광고 세계가 대신 돌아가는 동안, 메인 실험은
  // "그 시간만큼 얼어붙어 있던 것"처럼 취급). pauseForGames()/
  // resumeForGames() 참고.
  bool _isGamesActive = false;
  DateTime? _gamesPauseStartedAt;

  // [추가] 튜토리얼 종료 직후 딱 1회, 터치와 무관하게 180초 동안 광고를
  // 억제하기 위한 플래그. 이 유예 기간 중엔 터치 트리거가 완전히 무시되고
  // 시간 트리거만 180초짜리로 동작한다. 이 유예 기간 중 첫 광고가 뜨는
  // 순간 플래그가 꺼지고, 그 다음부터는 평소의 130초/40터치 OR 로직으로
  // 정상 전환된다.
  static const int _postTutorialGraceSeconds = 180; // 3분
  bool _isPostTutorialGraceActive = false;

  // ─── 시간조건(130초 고정) × 국가선택(1/2) × 터치조건(40회 고정) ─────────
  static const String _prefKeyExperimentGroup = 'ad_experiment_group_v5';
  static const String _prefKeyAssignedAt = 'ad_experiment_group_v5_assigned_at';
  static const String _prefKeyDeviceId = 'ad_experiment_device_id';
  static const String _prefKeyAssignmentDocId =
      'ad_experiment_assignment_doc_id';

  // [변경] 시간조건/터치조건 고정값. 더 이상 범위 랜덤 배정하지 않음.
  static const int _fixedTimeCondition = 130; // 초
  static const int _fixedTouchCondition = 40; // 회 (35 -> 40)

  int _cooldownSeconds = _fixedTimeCondition;
  CountryAdGroup _countryAdGroup = CountryAdGroup.block;
  int _touchThreshold = _fixedTouchCondition;
  String _groupLabel = '$_fixedTimeCondition-1-$_fixedTouchCondition';
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

  /// 현재 배정된 실험 그룹 라벨 (예: "130-1-40", "130-2-40"
  /// — "시간조건-국가-터치조건"). 구독 등 다른 서비스에서
  /// 매출-그룹 연결용으로 참조.
  String get experimentGroup => _groupLabel;

  bool get _countryScreenAdsEnabledForGroup =>
      _countryAdGroup == CountryAdGroup.allow;

  // Show subscription sheet every 3 ad dismissals
  static const int _subscriptionPromptEvery = 3;

  // Android 전용 인터스티셜 광고 단위 — mediation group 연결되어 정상 수익 확인됨
  static const String _realInterstitialAdUnitId =
      'ca-app-pub-3945470636956441/8397434180'; // interstitial_main

  // iOS 전용 인터스티셜 광고 단위 (travelog_apple_interstitial)
  static const String _iosInterstitialAdUnitId =
      'ca-app-pub-3945470636956441/5308407850';

  String get _adUnitId =>
      Platform.isIOS ? _iosInterstitialAdUnitId : _realInterstitialAdUnitId;

  void _onPremiumActivated() {
    _isPremium = true;
    _timeTriggerTimer?.cancel();
    _interstitialAd?.dispose();
    _interstitialAd = null;
    // pending 상태로 대기 중이던 광고가 있었더라도, 프리미엄으로 전환된
    // 이상 이후 화면 전환에서 튀어나오면 안 되므로 여기서 완전히 폐기한다.
    _clearPendingAd();
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

  /// [변경] 튜토리얼 종료 시 카운터 리셋뿐 아니라, 이후 3분(180초) 동안
  /// 터치와 무관하게 광고를 억제하는 1회성 유예 상태로 진입시킴.
  /// 유예 중엔 recordGlobalTouch()가 무시되고, _refreshTimerState()가
  /// 130초 대신 180초짜리 타이머를 건다. 유예 기간의 첫 광고가 뜨는
  /// 순간(_presentPendingAd) 플래그가 해제되며 평소 로직으로 복귀한다.
  void clearTutorialActive() {
    _isTutorialActive = false;
    _isPostTutorialGraceActive = true; // 튜토리얼 직후 1회성 3분 유예 시작
    _touchesSinceLastAd = 0;
    _lastShownAt = DateTime.now(); // 재개 시점부터 두 트리거 다 새로 카운트
    _refreshTimerState();
  }

  /// 온보딩 화면은 실험 축에서 제외 — 항상 광고 차단 (baseline 고정)
  void setOnboardingActive() {
    _isOnboardingActive = true;
    _refreshTimerState();
    debugPrint(
      '[AdService] onboarding started - ads paused (non-experimental)',
    );
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

  // [추가] 게임 허브(Travelog Games) 진입/이탈 훅. GameAdService가
  // 게임 허브에 들어오고 나갈 때 각각 호출함.
  //
  // setXxxActive/clearXxxActive들과 다르게, 여기서는 카운트를 절대
  // 리셋하지 않음 — 터치 카운트는 _shouldPauseAds가 true인 동안
  // recordGlobalTouch()가 그냥 통째로 무시되니 자연스럽게 "얼어붙고",
  // 시간 카운트(_lastShownAt 기준 경과시간)는 게임에 머문 시간만큼
  // _lastShownAt을 뒤로 밀어서(resumeForGames) 마치 그 시간이
  // 통째로 존재하지 않았던 것처럼 처리함 — 그래서 게임에서 나오는
  // 순간 "쌓여있던 그대로" 이어짐.
  void pauseForGames() {
    if (_isGamesActive) return;
    _isGamesActive = true;
    _gamesPauseStartedAt = DateTime.now();
    _refreshTimerState();
    debugPrint(
      '[AdService] games area entered - main ad triggers paused (preserved)',
    );
  }

  void resumeForGames() {
    if (!_isGamesActive) return;
    _isGamesActive = false;

    final pauseStart = _gamesPauseStartedAt;
    _gamesPauseStartedAt = null;

    if (pauseStart != null && _lastShownAt != null) {
      final pausedDuration = DateTime.now().difference(pauseStart);
      // 게임에 머문 시간만큼 기준 시각을 뒤로 밀어서, 그 구간이
      // 경과시간 계산에서 통째로 빠지도록 함 — 즉 시간 트리거를
      // "그 시간만큼 얼어붙어 있던 것"처럼 되돌림.
      _lastShownAt = _lastShownAt!.add(pausedDuration);
    }

    _refreshTimerState();
    debugPrint(
      '[AdService] games area exited - main ad triggers resumed (preserved)',
    );
  }

  /// 지금 광고를 멈춰야 하는 상태인지.
  bool get _shouldPauseAds {
    if (_isPremium) return true;
    if (_isTutorialActive) return true;
    if (_isUiOverlayActive) return true;
    if (_isOnboardingActive) return true;
    if (_isGamesActive) return true;
    if (_isCountrySelectionActive && !_countryScreenAdsEnabledForGroup)
      return true;
    return false;
  }

  /// 경과시간 트리거를 다시 스케줄링 — 마지막 노출 시각(_lastShownAt) 기준으로
  /// "쿨다운값이 지나는 그 시점"에 정확히 한 번 울리게 함.
  /// 광고가 뜰 때마다, 또는 일시정지 상태가 바뀔 때마다 반드시 다시 호출해서
  /// 리셋해야 함 — 터치/시간 둘 중 하나라도 충족되면 둘 다 리셋되는 설계라서.
  ///
  /// [변경] 튜토리얼 직후 유예 기간(_isPostTutorialGraceActive) 중에는
  /// 평소 쿨다운(_cooldownSeconds=130초) 대신 180초를 사용한다.
  void _refreshTimerState() {
    _timeTriggerTimer?.cancel();
    if (_shouldPauseAds) return;

    // 이미 pending 광고가 있으면 시간 트리거를 다시 돌 필요가 없다 — 조건은
    // 이미 충족되어 대기 중이고, 남은 건 화면 전환뿐이다. 이 가드가 없으면
    // pending 동안 _refreshTimerState()가 다시 호출될 때(예: 다른 pause
    // 상태 토글) _lastShownAt이 리셋되지 않은 채라 remaining이 계속
    // 음수(wait=0)로 계산되어 Timer가 0초 간격으로 재예약되는 문제가
    // 생길 수 있다.
    if (_isAdPending) return;

    final int cooldown = _isPostTutorialGraceActive
        ? _postTutorialGraceSeconds
        : _cooldownSeconds;

    final now = DateTime.now();
    final elapsed = _lastShownAt == null
        ? Duration.zero
        : now.difference(_lastShownAt!);
    final remaining = Duration(seconds: cooldown) - elapsed;
    final wait = remaining.isNegative ? Duration.zero : remaining;

    _timeTriggerTimer = Timer(wait, () => _queueAd('timer'));
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
          final canRequestAds = await ConsentInformation.instance
              .canRequestAds();
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
        final canRequestAds = await ConsentInformation.instance.canRequestAds();
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

  /// 최초 1회 배정. 시간조건/터치조건은 고정값(130초/40회)을 그대로 쓰고,
  /// 국가축(1=block/2=allow)만 완전 무작위로 배정. 이후 영구 고정.
  /// pref 키는 v5 그대로 유지 — 국가축만 계속 실험 중이므로 재배정할
  /// 필요가 없음(기존 v5 배정 기기는 그대로 유지됨).
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
      final countryIndex = Random().nextInt(2); // 0~1 -> 1(block)/2(allow)
      saved = '$_fixedTimeCondition-${countryIndex + 1}-$_fixedTouchCondition';
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
                WidgetsBinding.instance.platformDispatcher.locale.countryCode ??
                'unknown',
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
  /// 숫자 라벨(예: "130-1-40")이라 이전 실험들의 문자 기반 라벨(A-1-X,
  /// a-1-x)과 형식이 아예 달라서 컬렉션 그대로 재사용 가능.
  /// 실패해도 실제 그룹 배정/광고 동작에는 영향 주지 않음.
  /// 반환값(DocumentReference)의 id를 로컬에 저장해서, 나중에 필드를 또
  /// 추가해야 할 때 이 기기의 배정 문서를 정확히 찾아 백필할 수 있게 함.
  Future<DocumentReference<Map<String, dynamic>>?> _logExperimentAssignment(
    String groupLabel,
  ) async {
    try {
      return await FirebaseFirestore.instance
          .collection('ad_experiment_assignments_v3')
          .add({
            'adExperimentGroup': groupLabel,
            'deviceId': _deviceId,
            // 기기 로케일 기준 국가코드 — 로그인 여부와 무관하게 전원한테 붙음.
            // GPS 아니라 시스템 설정값이라 대략치 (VPN/언어만 바꾼 유저는 부정확할 수 있음).
            'localeCountryCode':
                WidgetsBinding.instance.platformDispatcher.locale.countryCode ??
                'unknown',
            'assignedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('[AdService] assignment log error: $e');
      return null;
    }
  }

  void _applyGroupLabel(String label) {
    _groupLabel = label;
    final parts = label.split('-'); // ["130", "1", "40"]
    _cooldownSeconds =
        int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? _fixedTimeCondition;
    final countryDigit = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    _touchThreshold =
        int.tryParse(parts.length > 2 ? parts[2] : '') ?? _fixedTouchCondition;

    _countryAdGroup = countryDigit == 2
        ? CountryAdGroup.allow
        : CountryAdGroup.block;
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

          ad.onPaidEvent =
              (
                Ad ad,
                double valueMicros,
                PrecisionType precision,
                String currencyCode,
              ) {
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

          _interstitialAd!
              .fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (InterstitialAd ad) {
              ScreenTracking.instance.adVisible(true);
            },
            onAdImpression: (InterstitialAd ad) {
              // 실제 노출이 몇 번 일어나는지 별도 기록 —
              // onPaidEvent 발생 횟수와 비교해서 격차를 직접 확인하기 위함.
              _logAdImpressionToFirestore();
            },
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ScreenTracking.instance.adVisible(false);
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
                  ScreenTracking.instance.adVisible(false);
                  debugPrint(
                    '[AdService] failed to show: code=${error.code} '
                    'domain=${error.domain} msg=${error.message}',
                  );
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
  /// 소요시간·터치수 계측용. _queueAd()에서 캡처되어 _presentPendingAd()가
  /// _pendingTriggerSource 등에 옮겨 담은 값을 그대로 씀.
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
  /// 동등한 자격의 OR 트리거.
  ///
  /// [변경] 조건이 충족돼도 더 이상 광고를 바로 show하지 않는다. 대신
  /// pending 상태로만 등록해두고, 실제 노출은 이후 실제 화면 전환이
  /// 감지될 때(onScreenTransition) 이루어진다. 카운터(_touchesSinceLastAd,
  /// _lastShownAt) 리셋도 이 시점에는 하지 않으며, 실제로 광고가 show되는
  /// 순간(_presentPendingAd)에만 수행한다.
  ///
  /// 광고는 한 번에 1개만 pending 가능 — 이미 pending 중이면(중복 호출,
  /// 또는 터치/시간 조건이 겹쳐서 만족되는 경우 등) 아무 것도 하지 않고
  /// 조용히 무시한다.
  void _queueAd(String triggerSource) {
    if (_shouldPauseAds) return;
    if (_isAdPending) return; // 이미 pending 중 — 중복 queue 금지

    final now = DateTime.now();
    _isAdPending = true;
    _queuedTriggerSource = triggerSource;
    // "조건을 만족한 바로 그 순간"의 값을 캡처 — 화면 전환을 기다리는 동안
    // 흐른 시간/터치는 이 계측값에 반영되지 않는다(원래 조건 충족 시점
    // 기준의 지표를 그대로 유지하기 위함).
    _queuedElapsedSeconds = _lastShownAt == null
        ? null
        : now.difference(_lastShownAt!).inSeconds;
    _queuedTouchesSinceLastAd = _touchesSinceLastAd;

    debugPrint(
      '[AdService] ad condition met ($triggerSource) - queued as pending, '
      'will show on next screen transition',
    );
  }

  /// pending 상태와 관련된 필드를 전부 초기화한다. 실제 노출 완료 시,
  /// 그리고 프리미엄 활성화처럼 pending 자체를 폐기해야 할 때 사용.
  void _clearPendingAd() {
    _isAdPending = false;
    _queuedTriggerSource = null;
    _queuedElapsedSeconds = null;
    _queuedTouchesSinceLastAd = null;
  }

  /// 화면 전환이 확인된 뒤 실제로 pending 광고를 노출 시도한다.
  /// 이 함수 호출 시점에는 이미 "지금 노출해도 되는 타이밍"이라는 게
  /// 전제되어 있어야 한다(딜레이/postFrameCallback은 onScreenTransition
  /// 쪽에서 처리).
  void _presentPendingAd() {
    if (!_isAdPending) return; // pending 없음 — 아무 것도 안 함

    if (_shouldPauseAds) {
      // pending은 유지한 채 그대로 대기 — 다음 번 pause 해제 후 화면
      // 전환에서 다시 시도된다.
      return;
    }

    if (_interstitialAd == null) {
      // 아직 로드가 안 된 상태 — pending은 삭제하지 않고 로드만 요청한다.
      // 지금 화면에서 갑자기 띄우지 않고, 다음 적절한 화면 전환을 기다린다.
      loadInterstitialAd();
      return;
    }

    final String triggerSource = _queuedTriggerSource ?? 'timer';
    final now = DateTime.now();

    // Firestore 계측용 필드 — 화면 전환 시점이 아니라 조건을 처음 만족한
    // "그 순간" 캡처된 값을 그대로 사용해서 triggerSource/경과시간/터치수가
    // 화면 전환 대기로 인해 왜곡되지 않게 한다.
    _pendingTriggerSource = triggerSource;
    _pendingElapsedSeconds = _queuedElapsedSeconds;
    _pendingTouchesSinceLastAd = _queuedTouchesSinceLastAd;

    _clearPendingAd();

    _touchesSinceLastAd = 0;
    _lastShownAt = now;
    _isPostTutorialGraceActive = false; // 유예 기간의 첫 광고 노출 → 이후 평소 로직으로 전환
    _interstitialAd!.show();
    _interstitialAd = null;

    _refreshTimerState(); // 시간트리거를 지금 시점부터 다시 카운트하게 재시작
  }

  /// [추가] 실제 PageRoute 화면 전환(push/pop/replace, 필요시 탭 전환)이
  /// 완료된 직후 호출되는 public 진입점.
  ///
  /// pending 광고가 없으면 아무 것도 하지 않는다. pending이 있고 지금
  /// 노출 가능한 상태라면, Navigator 전환 애니메이션과 겹치지 않도록
  /// 새 프레임이 그려진 뒤 짧은 유예(_screenTransitionAdDelay)를 두고
  /// 1회 노출을 시도한다. 이 유예 동안 상태가 바뀌었을 수 있으므로
  /// (프리미엄 구매, 다른 pause 상태 진입 등) 실제 노출 직전에
  /// _presentPendingAd() 내부에서 다시 한번 조건을 확인한다.
  void onScreenTransition() {
    if (!_isAdPending) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(_screenTransitionAdDelay, _presentPendingAd);
    });
  }

  /// [변경] 튜토리얼 직후 유예 기간(_isPostTutorialGraceActive) 중에는
  /// 터치 트리거 자체를 완전히 무시한다 — 이 기간엔 오직 180초 시간
  /// 트리거만 광고를 띄울 수 있다.
  ///
  /// [변경] pending 중일 때는 터치 카운트 자체는 계속 올라가지만(계측
  /// 목적상 자연스럽게 흐르도록 둠), 이미 조건을 만족한 pending 광고가
  /// 있으므로 추가로 queue를 시도하지 않는다.
  void recordGlobalTouch() {
    if (_shouldPauseAds) return;
    if (_isPostTutorialGraceActive) return; // 유예 기간엔 터치 트리거 비활성

    _touchesSinceLastAd++;
    if (!_isAdPending && _touchesSinceLastAd >= _touchThreshold) {
      _queueAd('touch');
    }
  }
}
