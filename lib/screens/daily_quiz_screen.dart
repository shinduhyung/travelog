import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:country_flags/country_flags.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

// 기존 모델 및 프로바이더 임포트
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';

// 도시, 항공사, 공항 관련 모델, 프로바이더, 스크린 임포트
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/widgets/city_detail_modal.dart';

import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/screens/airline_detail_screen.dart';

import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/screens/airports_screen.dart';

// top_landmarks 모달용 캐시 매니저
final CacheManager _quizLandmarksCacheManager = CacheManager(
  Config(
    'landmarks_cache_key',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 300,
  ),
);

class DailyQuizScreen extends StatefulWidget {
  final String? initialDate; // 알림 탭 딥링크용 (YYYYMMDD)
  final bool initialExpert; // true면 Expert 푸시로 진입 (Expert 모드로 시작)

  /// true면 [initialExpert]를 무시하고 사용자가 저장해둔 기본 모드(설정 화면/퀴즈 화면에서
  /// "Set as My Default"로 지정한 값)를 읽어와서 시작 모드로 사용함. 알림 딥링크처럼
  /// 명시적으로 모드가 정해진 진입 경로에서는 false로 둬야 함 (기본값).
  final bool useSavedDefaultMode;

  const DailyQuizScreen({
    super.key,
    this.initialDate,
    this.initialExpert = false,
    this.useSavedDefaultMode = false,
  });

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen>
    with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // quizzes.json 캐시 (Storage에서 한 번만 다운로드) - Normal mode
  List<Map<String, dynamic>>? _cachedQuizzes;
  // quizzes_hard.json 캐시 - Expert mode
  List<Map<String, dynamic>>? _cachedQuizzesExpert;

  bool _isLoading = true;
  bool _isQuizAvailable = false;
  bool _hasSolved = false;

  // Expert mode toggle
  bool _isExpertMode = false;
  bool _expertHistoryLoaded = false;

  // ── Premium gating (Expert mode) ─────────────────────────
  static const String _prefKeyDefaultQuizMode = 'daily_quiz_default_mode'; // 'normal' | 'expert'
  bool _isPremium = false;
  bool _defaultIsExpert = false; // 사용자가 저장해둔 기본 모드 (My Trips / 알림 기준)
  // Default 선택 패널이 펼쳐져 있는지 — 계정 최초 1회만 자동으로 펼쳐두고, 그 뒤로는
  // 접힌 상태로 시작해서 탭했을 때만 다시 펼쳐짐
  bool _defaultModeExpanded = false;
  Timer? _expertGateTimer;
  bool _expertGateShown = false;
  // 1초 자동 팝업은 이 화면에서 딱 한 번만 — 그 이후엔 직접 눌렀을 때만 다시 뜸
  bool _autoExpertGateFired = false;

  // ── Animations ────────────────────────────────────────────
  late final AnimationController _questionEntranceController;
  late final AnimationController _celebrationController;
  late final AnimationController _shakeController;
  late final AnimationController _shimmerController;
  bool _showCelebration = false;

  // 5월 28일 시작 날짜 세팅 및 선택 날짜 초기화 (Normal mode)
  final DateTime _startDate = DateTime(2026, 5, 28);
  // Expert mode quiz set starts 2026-08-20
  final DateTime _expertStartDate = DateTime(2026, 8, 20);
  late DateTime _selectedDate;
  String _dateStr = "";

  String _question = "";
  List<String> _options = [];
  bool _isUserCorrect = false;
  int _correctAnswerIndex = -1;
  int _selectedAnswerIndex = -1;
  String _explanation = "";

  // 모든 날짜의 풀이 결과를 저장하기 위한 맵 (Normal mode)
  final Map<String, bool> _historySolvedMap = {};
  final Map<String, bool> _historyCorrectMap = {};
  final Map<String, int> _historySelectedIndexMap = {};

  // Expert mode history maps (kept separate from Normal mode progress)
  final Map<String, bool> _historySolvedMapExpert = {};
  final Map<String, bool> _historyCorrectMapExpert = {};
  final Map<String, int> _historySelectedIndexMapExpert = {};

  // ── Mode-aware helpers ──────────────────────────────────
  DateTime get _currentStartDate => _isExpertMode ? _expertStartDate : _startDate;
  Map<String, bool> get _solvedMap => _isExpertMode ? _historySolvedMapExpert : _historySolvedMap;
  Map<String, bool> get _correctMap => _isExpertMode ? _historyCorrectMapExpert : _historyCorrectMap;

  static const List<Color> _normalGradient = [Color(0xFF6366F1), Color(0xFF4F46E5)];
  static const List<Color> _expertGradient = [Color(0xFF7C3AED), Color(0xFFDB2777)];
  List<Color> get _accentGradient => _isExpertMode ? _expertGradient : _normalGradient;
  Color get _accentColor => _isExpertMode ? const Color(0xFF7C3AED) : const Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    // Expert 푸시로 진입했으면 처음부터 Expert 모드로 시작 (useSavedDefaultMode=true면 아래에서 덮어씀)
    _isExpertMode = widget.useSavedDefaultMode ? false : widget.initialExpert;
    _isPremium = SubscriptionService.instance.isPremium;

    _questionEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showCelebration = false);
      }
    });
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    final nowUtc = DateTime.now().toUtc();

    // 알림 탭으로 진입 시 해당 날짜로 이동
    final initialDate = widget.initialDate;
    if (initialDate != null && initialDate.length == 8) {
      try {
        final y = int.parse(initialDate.substring(0, 4));
        final m = int.parse(initialDate.substring(4, 6));
        final d = int.parse(initialDate.substring(6, 8));
        _selectedDate = DateTime.utc(y, m, d);
      } catch (_) {
        _selectedDate = nowUtc.isBefore(_currentStartDate) ? _currentStartDate : nowUtc;
      }
    } else {
      _selectedDate = nowUtc.isBefore(_currentStartDate) ? _currentStartDate : nowUtc;
    }
    _initializeData();
  }

  @override
  void dispose() {
    _expertGateTimer?.cancel();
    _questionEntranceController.dispose();
    _celebrationController.dispose();
    _shakeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 이 키가 아예 없다는 건 "계정이 한 번도 기본 모드를 설정한 적 없음" = 최초 진입.
      // 최초 진입일 때만 선택 패널을 펼쳐서 보여주고, 그 이후로는 항상 접힌 상태로 시작함.
      final bool everConfigured = prefs.containsKey(_prefKeyDefaultQuizMode);
      final saved = prefs.getString(_prefKeyDefaultQuizMode);
      final savedIsExpert = saved == 'expert';
      if (!mounted) return;
      setState(() {
        _defaultIsExpert = savedIsExpert;
        _defaultModeExpanded = !everConfigured;
      });

      if (widget.useSavedDefaultMode) {
        // 저장된 기본값이 Expert인데 지금은 구독자가 아니면(만료 등) Normal로 안전하게 폴백
        final bool startExpert = savedIsExpert && _isPremium;
        if (startExpert != _isExpertMode) {
          final nowUtc = DateTime.now().toUtc();
          setState(() {
            _isExpertMode = startExpert;
            _selectedDate =
            nowUtc.isBefore(_currentStartDate) ? _currentStartDate : nowUtc;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading default quiz mode preference: $e');
    }
  }

  Future<void> _initializeData() async {
    await _loadDefaultModePreference();
    await _loadAllQuizHistory();
    if (_isExpertMode) {
      // Expert 모드로 바로 진입한 경우 Expert 히스토리도 함께 로드
      await _loadAllQuizHistory(expert: true);
      _expertHistoryLoaded = true;
    }
    await _loadQuizForDate(_selectedDate);
  }

  Future<void> _loadAllQuizHistory({bool expert = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final collectionName = expert ? 'quiz_history_expert' : 'quiz_history';
      final snapshots = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
          .get();

      final solvedMap = expert ? _historySolvedMapExpert : _historySolvedMap;
      final correctMap = expert ? _historyCorrectMapExpert : _historyCorrectMap;
      final selectedMap = expert ? _historySelectedIndexMapExpert : _historySelectedIndexMap;

      for (var doc in snapshots.docs) {
        final data = doc.data();
        solvedMap[doc.id] = true;
        correctMap[doc.id] = data['isCorrect'] ?? false;
        final savedIndex = data['selectedAnswerIndex'];
        if (savedIndex != null) {
          selectedMap[doc.id] = savedIndex as int;
        }
      }
    } catch (e) {
      debugPrint("Error loading quiz history (expert=$expert): $e");
    }
  }

  // Switch between Normal / Expert quiz sets
  Future<void> _onModeChanged(bool expert) async {
    if (expert == _isExpertMode) return;

    _expertGateTimer?.cancel();
    _expertGateShown = false;
    if (expert) {
      // Expert로 새로 들어올 때마다 "처음 1초 자동 팝업"을 다시 허용
      _autoExpertGateFired = false;
    }

    final nowUtc = DateTime.now().toUtc();
    final today = DateTime(nowUtc.year, nowUtc.month, nowUtc.day);
    final startDate = expert ? _expertStartDate : _startDate;
    final newSelectedDate = today.isBefore(startDate) ? startDate : today;

    setState(() {
      _isExpertMode = expert;
      _selectedDate = newSelectedDate;
      _isLoading = true;
    });

    if (expert && !_expertHistoryLoaded) {
      await _loadAllQuizHistory(expert: true);
      _expertHistoryLoaded = true;
    }
    await _loadQuizForDate(_selectedDate);
  }

  Future<void> _loadQuizForDate(DateTime date) async {
    setState(() => _isLoading = true);
    try {
      final year = date.year.toString();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      _dateStr = "$year$month$day";
      final expert = _isExpertMode;
      final jsonPath = expert ? 'functions/quizzes_hard.json' : 'functions/quizzes.json';
      debugPrint("🗓️ [Quiz] 날짜: $_dateStr (expert=$expert)");

      // 캐시 없으면 Storage에서 다운로드 (Normal/Expert 각각 별도 캐시)
      List<Map<String, dynamic>>? cache = expert ? _cachedQuizzesExpert : _cachedQuizzes;

      if (cache == null) {
        debugPrint("📥 [Quiz] Storage에서 $jsonPath 다운로드 시작");
        try {
          final ref = FirebaseStorage.instance.ref(jsonPath);
          debugPrint("📦 [Quiz] Storage ref 생성 완료: ${ref.fullPath}");
          final url = await ref.getDownloadURL();
          debugPrint("🔗 [Quiz] Download URL 획득: $url");
          final response = await http.get(Uri.parse(url));
          debugPrint("📡 [Quiz] HTTP 응답 코드: ${response.statusCode}");
          if (response.statusCode != 200) {
            debugPrint("❌ [Quiz] HTTP 실패 → _isQuizAvailable=false");
            setState(() { _isQuizAvailable = false; _isLoading = false; });
            return;
          }
          cache = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          if (expert) {
            _cachedQuizzesExpert = cache;
          } else {
            _cachedQuizzes = cache;
          }
          debugPrint("✅ [Quiz] 캐시 완료 — 총 ${cache.length}개 퀴즈");
          if (cache.isNotEmpty) {
            debugPrint("   첫 번째 date: ${cache.first['date']}, 마지막 date: ${cache.last['date']}");
          }
        } catch (storageError) {
          debugPrint("❌ [Quiz] Storage/HTTP 오류: $storageError");
          setState(() { _isQuizAvailable = false; _isLoading = false; });
          return;
        }
      } else {
        debugPrint("💾 [Quiz] 캐시 사용 — 총 ${cache.length}개");
      }

      // date 필드로 해당 날짜 퀴즈 찾기
      final quizData = cache.firstWhere(
            (q) => q['date'] == _dateStr,
        orElse: () => {},
      );
      debugPrint("🔍 [Quiz] $_dateStr 매칭 결과: ${quizData.isEmpty ? '없음' : '찾음 (question: ${quizData['question']?.toString().substring(0, 30)}...)'}");

      if (quizData.isEmpty) {
        debugPrint("⚠️ [Quiz] 해당 날짜 퀴즈 없음 → _isQuizAvailable=false");
        setState(() { _isQuizAvailable = false; _isLoading = false; });
        return;
      }

      _isQuizAvailable = true;

      final nowUtc = DateTime.now().toUtc();
      final today = DateTime(nowUtc.year, nowUtc.month, nowUtc.day);
      final selectedDay = DateTime(date.year, date.month, date.day);
      bool isToday = selectedDay == today;
      // 정답 공개: 내가 푼 날 or 어제 이전(전날까지만 답 공개, 오늘은 미풀이시 문제만)
      bool revealAnswer = selectedDay.isBefore(today); // 전날까지만

      final solvedMap = expert ? _historySolvedMapExpert : _historySolvedMap;
      final correctMap = expert ? _historyCorrectMapExpert : _historyCorrectMap;
      final selectedMap = expert ? _historySelectedIndexMapExpert : _historySelectedIndexMap;
      debugPrint("📅 [Quiz] isToday=$isToday, revealAnswer=$revealAnswer, hasSolved=${solvedMap[_dateStr]}");

      if (solvedMap[_dateStr] == true) {
        debugPrint("✅ [Quiz] 이미 풀었음 → solved 상태로 렌더");
        _updateState(quizData, true, correctMap[_dateStr] ?? false, selectedMap[_dateStr] ?? -1);
      } else if (revealAnswer) {
        debugPrint("📆 [Quiz] 전날 이전 미풀이 → 답 공개 상태로 렌더");
        _updateState(quizData, true, false, -1);
      } else {
        debugPrint("🎯 [Quiz] 오늘 미풀이 → 문제 출제 상태로 렌더");
        _updateState(quizData, false, false, -1);
      }
    } catch (e, st) {
      debugPrint("❌ [Quiz] 전체 오류: $e");
      debugPrintStack(stackTrace: st);
    } finally {
      setState(() => _isLoading = false);
      _evaluateExpertGate();
    }
  }

  void _updateState(Map<String, dynamic> data, bool solved, bool correct, int selected) {
    setState(() {
      _hasSolved = solved;
      _isUserCorrect = correct;
      _selectedAnswerIndex = selected;
      _correctAnswerIndex = data['correctAnswerIndex'];
      _explanation = data['explanation'] ?? "";
      _question = data['question'];
      _options = List<String>.from(data['options']);
    });
    _questionEntranceController
      ..reset()
      ..forward();
  }

  Future<void> _submitAnswer(int index) async {
    if (_hasSolved) return;

    // Expert 모드는 구독자만 풀 수 있음 — 비구독자가 답을 고르면 즉시 페이월 안내
    if (_isExpertMode && !_isPremium) {
      _promptExpertSubscription();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      bool isCorrect = (index == _correctAnswerIndex);
      final collectionName = _isExpertMode ? 'quiz_history_expert' : 'quiz_history';

      await _firestore
          .collection('users')
          .doc(user?.uid)
          .collection(collectionName)
          .doc(_dateStr)
          .set({
        'isCorrect': isCorrect,
        'selectedAnswerIndex': index,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _solvedMap[_dateStr] = true;
      _correctMap[_dateStr] = isCorrect;

      setState(() {
        _hasSolved = true;
        _isUserCorrect = isCorrect;
        _selectedAnswerIndex = index;
        _isLoading = false;
      });

      _expertGateTimer?.cancel();

      if (isCorrect) {
        HapticFeedback.mediumImpact();
        setState(() => _showCelebration = true);
        _celebrationController.forward(from: 0);
      } else {
        HapticFeedback.selectionClick();
        _shakeController.forward(from: 0);
      }
    } catch (e) {
      debugPrint("Error submitting answer: $e");
      setState(() => _isLoading = false);
    }
  }

  // ── Expert(Premium) 페이월 게이팅 ─────────────────────────
  void _evaluateExpertGate() {
    _expertGateTimer?.cancel();
    // 자동(1초 타이머) 팝업은 화면당 딱 한 번만 — 그 뒤로는 사용자가 직접
    // 눌렀을 때(_promptExpertSubscription 수동 호출)만 다시 뜸
    if (_autoExpertGateFired) return;
    if (_isExpertMode && !_isPremium && _isQuizAvailable && !_hasSolved) {
      _expertGateTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        _autoExpertGateFired = true;
        _promptExpertSubscription();
      });
    }
  }

  void _promptExpertSubscription() {
    if (!mounted || _expertGateShown) return;
    _expertGateTimer?.cancel();
    _expertGateShown = true;

    SubscriptionSheet.show(context, triggerContext: 'daily_quiz_expert_gate').then((_) {
      _isPremium = SubscriptionService.instance.isPremium;
      _expertGateShown = false;
      if (!mounted) return;
      setState(() {}); // 구독 완료 시 잠금 UI 즉시 해제되도록 리프레시
    });
  }

  @override
  Widget build(BuildContext context) {
    // 구독 상태가 바뀌면(구매/복원 등) 자동으로 리빌드되어 Expert 잠금 UI가 즉시 갱신됨
    _isPremium = context.watch<SubscriptionService>().isPremium;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isExpertMode
              ? ShaderMask(
            key: const ValueKey('expert_title'),
            shaderCallback: (bounds) =>
                LinearGradient(colors: _accentGradient).createShader(bounds),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department_rounded, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  "Daily Quiz · Expert",
                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          )
              : const Text(
            "Daily Quiz",
            key: ValueKey('normal_title'),
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            height: 3,
            decoration: BoxDecoration(
              gradient: _isExpertMode
                  ? LinearGradient(colors: _accentGradient)
                  : const LinearGradient(colors: [Colors.white, Colors.white]),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildModeToggle(),
              _buildDefaultModeSelector(),
              _buildHorizontalCalendar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !_isQuizAvailable
                    ? _buildEmptyState()
                    : _buildQuizContent(),
              ),
            ],
          ),
          if (_showCelebration)
            IgnorePointer(
              child: _CelebrationOverlay(
                controller: _celebrationController,
                colors: _accentGradient,
              ),
            ),
        ],
      ),
    );
  }

  // ── 저장된 기본 모드 표시 / 변경 ─────────────────────────
  Future<void> _setDefaultMode(bool expert) async {
    if (expert && !_isPremium) {
      _promptExpertSubscription();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDefaultQuizMode, expert ? 'expert' : 'normal');
      if (mounted) {
        setState(() {
          _defaultIsExpert = expert;
          _defaultModeExpanded = false; // 설정 완료되면 접힌 상태로 되돌아감
        });
      }
      unawaited(_syncQuizModeToFcmToken(expert ? 'expert' : 'normal'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: expert ? const Color(0xFF7C3AED) : const Color(0xFF6366F1),
          content: Text(
            expert
                ? 'Expert Quiz set as your default ✓'
                : 'Normal Quiz set as your default ✓',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error saving default quiz mode: $e');
    }
  }

  /// 현재 기기의 FCM 토큰에 선호 모드를 저장 — 서버(Cloud Functions)가 이 값을 보고
  /// Normal/Expert 알림 중 어느 쪽을 보낼지 결정함.
  Future<void> _syncQuizModeToFcmToken(String mode) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _firestore
          .collection('fcm_tokens')
          .doc(token)
          .set({'quizMode': mode}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing quizMode to fcm token: $e');
    }
  }

  // ── 기본 모드 선택 UI (구독자 전용, Normal/Expert 화면 양쪽에 노출) ─────
  Widget _buildDefaultModeSelector() {
    // 비구독자에게는 아예 노출하지 않음 — Expert를 기본으로 고를 수도 없고,
    // 어차피 Normal이 유일한 선택지라 보여줄 이유가 없음.
    if (!_isPremium) return const SizedBox(height: 8);

    if (!_defaultModeExpanded) {
      // 접힌 상태 — 계정 최초 설정 이후엔 항상 이 상태로 시작, 탭하면 펼쳐짐
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
        child: GestureDetector(
          onTap: () => setState(() => _defaultModeExpanded = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  _defaultIsExpert ? Icons.local_fire_department_rounded : Icons.psychology_rounded,
                  size: 14,
                  color: _defaultIsExpert ? _expertGradient.first : _normalGradient.first,
                ),
                const SizedBox(width: 7),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Default: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                      ),
                      TextSpan(
                        text: _defaultIsExpert ? 'Expert' : 'Normal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _defaultIsExpert ? _expertGradient.first : _normalGradient.first,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.expand_more_rounded, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _defaultIsExpert ? _expertGradient.first.withOpacity(0.06) : _normalGradient.first.withOpacity(0.06),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (_defaultIsExpert ? _expertGradient.first : _normalGradient.first).withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_active_rounded, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              'Default',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
            ),
            const Spacer(),
            _buildDefaultModeChip(
              label: 'Normal',
              icon: Icons.psychology_rounded,
              expert: false,
              gradient: _normalGradient,
            ),
            const SizedBox(width: 6),
            _buildDefaultModeChip(
              label: 'Expert',
              icon: Icons.local_fire_department_rounded,
              expert: true,
              gradient: _expertGradient,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultModeChip({
    required String label,
    required IconData icon,
    required bool expert,
    required List<Color> gradient,
  }) {
    final bool selected = _defaultIsExpert == expert;
    return GestureDetector(
      onTap: () => _setDefaultMode(expert),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected ? LinearGradient(colors: gradient) : null,
          color: selected ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
            BoxShadow(
              color: gradient.first.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Normal / Expert segmented toggle ────────────────────
  Widget _buildModeToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _isExpertMode
            ? [
          BoxShadow(
            color: _accentColor.withOpacity(0.18),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ]
            : null,
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: _isExpertMode ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _accentGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isExpertMode
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, _) {
                          final sweepX = -width * 0.5 + _shimmerController.value * width * 1.7;
                          return Stack(
                            children: [
                              Positioned(
                                left: sweepX,
                                top: -10,
                                bottom: -10,
                                width: width * 0.28,
                                child: Transform.rotate(
                                  angle: -0.4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white.withOpacity(0.0),
                                          Colors.white.withOpacity(0.32),
                                          Colors.white.withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                )
                    : null,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildModeTab(
                  label: "NORMAL",
                  icon: Icons.psychology_rounded,
                  selected: !_isExpertMode,
                  onTap: () => _onModeChanged(false),
                ),
              ),
              Expanded(
                child: _buildModeTab(
                  label: "EXPERT",
                  icon: Icons.local_fire_department_rounded,
                  selected: _isExpertMode,
                  onTap: () => _onModeChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: selected ? Colors.white : Colors.grey.shade500,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalCalendar() {
    final nowUtc = DateTime.now().toUtc();
    final today = DateTime(nowUtc.year, nowUtc.month, nowUtc.day);
    final activeStartDate = _currentStartDate;
    final startDay = DateTime(activeStartDate.year, activeStartDate.month, activeStartDate.day);
    final int itemCount = today.difference(startDay).inDays + 1;

    // 월 구분선 위치 계산: index→date, 이전 index와 월이 다를 때 표시
    return Container(
      height: 116,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final date = activeStartDate.add(Duration(days: index));
          final prevDate = index > 0 ? activeStartDate.add(Duration(days: index - 1)) : null;
          final isMonthStart = prevDate == null || date.month != prevDate.month;

          bool isSelected = (date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day);
          bool isFuture = date.isAfter(DateTime(nowUtc.year, nowUtc.month, nowUtc.day));

          String loopDateStr = "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
          bool hasSolved = _solvedMap[loopDateStr] ?? false;
          bool isCorrect = _correctMap[loopDateStr] ?? false;

          BoxBorder calendarBorder;
          if (isSelected) {
            calendarBorder = Border.all(color: Colors.transparent);
          } else if (hasSolved) {
            calendarBorder = Border.all(color: isCorrect ? Colors.green : Colors.red, width: 2);
          } else {
            calendarBorder = Border.all(color: Colors.grey.shade200);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 월 표시 (월이 바뀌는 첫 날에만)
              if (isMonthStart)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    DateFormat('yyyy MMM').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _accentColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              else
                const SizedBox(height: 18),
              GestureDetector(
                onTap: isFuture
                    ? null // 미래 날짜는 선택 불가
                    : () {
                  setState(() => _selectedDate = date);
                  _loadQuizForDate(date);
                },
                child: Container(
                  width: 60,
                  height: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _accentGradient,
                    )
                        : null,
                    color: isSelected
                        ? null
                        : isFuture
                        ? Colors.grey.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: calendarBorder,
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E').format(date),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white70
                              : isFuture
                              ? Colors.grey.shade400
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isFuture
                              ? Colors.grey.shade400
                              : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuizContent() {
    final bool locked = _isExpertMode && !_isPremium && !_hasSolved;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
      // 잠긴 상태에선 스크롤 중 실수로 채점되지 않도록 물리 스크롤은 유지하되
      // 탭 제스처는 아래 GestureDetector가 감지해서 바로 페이월을 띄움
      physics: locked ? const ClampingScrollPhysics() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedBuilder(
            animation: _questionEntranceController,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(_questionEntranceController.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 26),
                  child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: _isExpertMode
                    ? Border.all(color: _accentColor.withOpacity(0.20), width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: _isExpertMode ? _accentColor.withOpacity(0.12) : Colors.black.withOpacity(0.03),
                    blurRadius: _isExpertMode ? 24 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (locked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildPremiumChip(),
                    ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _accentColor.withOpacity(0.20),
                              _accentColor.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _accentGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.38),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isExpertMode ? Icons.local_fire_department_rounded : Icons.psychology_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(_question,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), height: 1.4),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(_options.length, (index) {
            return AnimatedBuilder(
              animation: _questionEntranceController,
              builder: (context, child) {
                final delay = math.min(0.08 * index, 0.5);
                final raw = ((_questionEntranceController.value - delay) / (1 - delay)).clamp(0.0, 1.0);
                final t = Curves.easeOutCubic.transform(raw);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
                );
              },
              child: _buildModernOption(index, locked: locked),
            );
          }),
          if (_hasSolved) _buildExplanationSection(),
        ],
      ),
    );

    if (!locked) return content;

    // 잠긴 Expert 화면에서는 옵션뿐 아니라 카드 어디를 눌러도 바로 페이월이 뜨도록
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _promptExpertSubscription,
      child: content,
    );
  }

  // 반짝이는 사선 하이라이트가 계속 흐르는 "PREMIUM" 배지
  Widget _buildPremiumChip() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(gradient: LinearGradient(colors: _accentGradient)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text('PREMIUM',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6)),
              ],
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, _) {
                    final sweepX = -width * 0.7 + _shimmerController.value * width * 2.2;
                    return Stack(
                      children: [
                        Positioned(
                          left: sweepX,
                          top: -8,
                          bottom: -8,
                          width: width * 0.4,
                          child: Transform.rotate(
                            angle: -0.5,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.5),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 옵션 텍스트로 visited 여부 판단
  bool _isOptionVisited(String optionText) {
    final lowerText = optionText.trim().toLowerCase();
    final landmarkProvider = context.read<LandmarksProvider>();
    final countryProvider = context.read<CountryProvider>();
    final cityProvider = context.read<CityProvider>();

    // 랜드마크 방문 여부
    if (landmarkProvider.allLandmarks.any(
            (l) => l.name.toLowerCase() == lowerText && landmarkProvider.visitedLandmarks.contains(l.name))) return true;
    // 국가 방문 여부 (isoA3 기준)
    final matchedCountry = countryProvider.allCountries.firstWhereOrNull((c) => c.name.toLowerCase() == lowerText);
    if (matchedCountry != null && countryProvider.visitedCountries.contains(matchedCountry.isoA3)) return true;
    // 도시 방문 여부 (cityName 기준)
    if (cityProvider.isVisited(optionText.trim())) return true;
    return false;
  }

  Widget _buildModernOption(int index, {bool locked = false}) {
    bool isSelected = (index == _selectedAnswerIndex);
    bool isCorrect = (index == _correctAnswerIndex);
    final optionText = _options[index];
    final isVisited = _isOptionVisited(optionText);
    final bool isWrongSelected = _hasSolved && isSelected && !_isUserCorrect;

    Color borderColor = _isExpertMode ? _accentColor.withOpacity(0.15) : Colors.grey.shade200;
    Color backgroundTileColor = Colors.white;
    Color iconColor = Colors.grey.shade300;
    IconData resultIcon = Icons.circle_outlined;

    if (_hasSolved) {
      if (isCorrect) {
        if (_selectedAnswerIndex == -1) {
          borderColor = Colors.amber;
          backgroundTileColor = Colors.amber.withOpacity(0.08);
          iconColor = Colors.amber;
          resultIcon = Icons.stars;
        } else if (_selectedAnswerIndex == _correctAnswerIndex) {
          borderColor = Colors.green;
          backgroundTileColor = Colors.green.withOpacity(0.08);
          iconColor = Colors.green;
          resultIcon = Icons.check_circle;
        } else {
          borderColor = Colors.amber;
          backgroundTileColor = Colors.amber.withOpacity(0.08);
          iconColor = Colors.amber;
          resultIcon = Icons.stars;
        }
      } else if (isSelected && !_isUserCorrect) {
        borderColor = Colors.red;
        backgroundTileColor = Colors.red.withOpacity(0.08);
        iconColor = Colors.red;
        resultIcon = Icons.cancel;
      }
    }

    Widget tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: backgroundTileColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(borderColor == Colors.grey.shade200 ? 0.0 : 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: _hasSolved && (isCorrect || (isSelected && !_isUserCorrect))
                  ? LinearGradient(colors: [iconColor, iconColor.withOpacity(0.7)])
                  : null,
              color: _hasSolved && (isCorrect || (isSelected && !_isUserCorrect))
                  ? null
                  : _isExpertMode
                  ? _accentColor.withOpacity(0.10)
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              "${index + 1}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _hasSolved && (isCorrect || (isSelected && !_isUserCorrect))
                    ? Colors.white
                    : _isExpertMode
                    ? _accentColor
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(optionText,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                if (isVisited)
                  Positioned(
                    top: -10,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1ABFBC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 9, color: Colors.white),
                          SizedBox(width: 2),
                          Text('visited', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (locked)
            Icon(Icons.lock_rounded, size: 18, color: _accentColor.withOpacity(0.6))
          else ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.info_outline, size: 20, color: Colors.grey),
              onPressed: () => _showInfoModalForOption(optionText),
            ),
            const SizedBox(width: 4),
            Icon(resultIcon, color: iconColor, size: 24),
          ],
        ],
      ),
    );

    if (locked) {
      tile = Opacity(opacity: 0.55, child: tile);
    }

    if (isWrongSelected) {
      tile = AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final progress = _shakeController.value;
          final shakeOffset =
              math.sin(progress * math.pi * 6) * (1 - progress) * 8;
          return Transform.translate(offset: Offset(shakeOffset, 0), child: child);
        },
        child: tile,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _PressableScale(
        onTap: () => locked ? _promptExpertSubscription() : _submitAnswer(index),
        borderRadius: BorderRadius.circular(16),
        child: tile,
      ),
    );
  }

  Widget _buildExplanationSection() {
    final bgColor = _isExpertMode ? const Color(0xFFF5F3FF) : const Color(0xFFEEF2FF);
    final borderColor = _isExpertMode ? const Color(0xFFDDD6FE) : const Color(0xFFC7D2FE);
    final iconColor = _isExpertMode ? const Color(0xFF7C3AED) : const Color(0xFF4F46E5);
    final titleColor = _isExpertMode ? const Color(0xFF6D28D9) : const Color(0xFF4338CA);
    final bodyColor = _isExpertMode ? const Color(0xFF5B21B6) : const Color(0xFF3730A3);

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text("Explanation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor)),
          ]),
          const SizedBox(height: 12),
          Text(_explanation, style: TextStyle(fontSize: 15, color: bodyColor, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.grey.shade100,
                  Colors.grey.shade50,
                ],
              ),
            ),
            child: Icon(
              _isExpertMode ? Icons.local_fire_department_outlined : Icons.event_busy_rounded,
              size: 44,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isExpertMode ? "No expert quiz found for this date." : "No quiz found for this date.",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showInfoModalForOption(String optionText) {
    final cleanText = optionText.trim();
    final lowerText = cleanText.toLowerCase();

    final countryProvider = context.read<CountryProvider>();
    final landmarkProvider = context.read<LandmarksProvider>();
    final cityProvider = context.read<CityProvider>();
    final airlineProvider = context.read<AirlineProvider>();
    final airportProvider = context.read<AirportProvider>();

    // 1. 국가 매칭
    final country = countryProvider.allCountries.firstWhereOrNull(
          (c) => c.name.toLowerCase() == lowerText,
    );
    if (country != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CountryDetailScreen(country: country)));
      return;
    }

    // 2. 랜드마크 매칭
    final landmark = landmarkProvider.allLandmarks.firstWhereOrNull(
          (l) => l.name.toLowerCase() == lowerText,
    );
    if (landmark != null) {
      _showTopLandmarksStyleBottomSheet(context, landmark);
      return;
    }

    // 3. 도시 매칭
    final city = cityProvider.allCities.firstWhereOrNull(
          (c) => c.name.toLowerCase() == lowerText,
    );
    if (city != null) {
      showCityDetailModal(context, city);
      return;
    }

    // 4. 항공사 매칭
    final airline = airlineProvider.airlines.firstWhereOrNull(
          (a) => a.name.toLowerCase() == lowerText,
    );
    if (airline != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AirlineDetailScreen(airlineName: airline.name)));
      return;
    }

    // 5. 공항 매칭
    final airport = airportProvider.allAirports.firstWhereOrNull(
          (ap) => ap.name.toLowerCase() == lowerText,
    );
    if (airport != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AirportsScreen()));
      return;
    }

    // 6. 매칭 실패 시 디버그 콘솔 로그 출력
    debugPrint("모달 연결 실패: $optionText");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("No details found for '$optionText'")),
    );
  }

  void _showTopLandmarksStyleBottomSheet(BuildContext context, Landmark landmark) {
    final countryProvider = context.read<CountryProvider>();

    Color fallbackThemeColor = const Color(0xFF6366F1);
    Color themeColor = fallbackThemeColor;
    if (landmark.countriesIsoA3.isNotEmpty) {
      final countryObj = countryProvider.allCountries.firstWhereOrNull(
            (c) => c.isoA3 == landmark.countriesIsoA3.first,
      );
      if (countryObj != null) {
        themeColor = countryObj.themeColor ?? fallbackThemeColor;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext _) {
        return _QuizLandmarkModal(
          initialLandmark: landmark,
          fallbackThemeColor: themeColor,
          cacheManager: _quizLandmarksCacheManager,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// 탭하면 살짝 눌리는 느낌을 주는 프레셔블 스케일 래퍼.
// InkWell 리플 대신 스케일 다운으로 좀 더 고급스러운 촉각 피드백을 줌.
// ─────────────────────────────────────────────
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;

  const _PressableScale({
    required this.child,
    required this.onTap,
    this.borderRadius,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    );
    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// 정답 축하 애니메이션 — 은은한 빛 번짐 + 컨페티 입자가
// 화면 중앙에서 확 터졌다가 사라지는 셀레브레이션 오버레이.
// ─────────────────────────────────────────────
class _CelebrationOverlay extends StatelessWidget {
  final AnimationController controller;
  final List<Color> colors;

  const _CelebrationOverlay({required this.controller, required this.colors});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        // 빛 번짐: 0~0.35 구간에서 확 커졌다가 나머지 구간 동안 서서히 옅어짐
        final glowT = Curves.easeOut.transform((t / 0.35).clamp(0.0, 1.0));
        final glowFade = 1.0 - Curves.easeIn.transform(((t - 0.25) / 0.75).clamp(0.0, 1.0));
        final glowScale = 0.4 + glowT * 1.8;
        final glowOpacity = glowT * glowFade * 0.55;

        return SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: glowScale,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.first.withOpacity(glowOpacity),
                        colors.last.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: size,
                painter: _ConfettiPainter(progress: t, colors: colors),
              ),
              _CelebrationBadge(progress: t, colors: colors),
            ],
          ),
        );
      },
    );
  }
}

class _CelebrationBadge extends StatelessWidget {
  final double progress;
  final List<Color> colors;

  const _CelebrationBadge({required this.progress, required this.colors});

  @override
  Widget build(BuildContext context) {
    // 0~0.25: elastic pop-in, 0.25~0.65: hold, 0.65~1.0: fade+float up
    final popT = Curves.elasticOut.transform((progress / 0.25).clamp(0.0, 1.0));
    final fadeT = 1.0 - Curves.easeIn.transform(((progress - 0.65) / 0.35).clamp(0.0, 1.0));
    final riseOffset = (1.0 - fadeT) * -18;

    if (progress < 0.02) return const SizedBox.shrink();

    return Transform.translate(
      offset: Offset(0, riseOffset),
      child: Opacity(
        opacity: fadeT.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.4 + popT * 0.6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withOpacity(0.5),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('Correct!',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  final double angle;
  final double speed;
  final double size;
  final double spin;
  final int colorIndex;

  const _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.spin,
    required this.colorIndex,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress; // 0..1
  final List<Color> colors;

  _ConfettiPainter({required this.progress, required this.colors});

  static final List<_ConfettiParticle> _particles = List.generate(18, (i) {
    final rnd = math.Random(i * 97 + 13);
    return _ConfettiParticle(
      angle: (i / 18) * 2 * math.pi + rnd.nextDouble() * 0.3,
      speed: 90 + rnd.nextDouble() * 110,
      size: 5 + rnd.nextDouble() * 5,
      spin: (rnd.nextBool() ? 1 : -1) * (2 + rnd.nextDouble() * 4),
      colorIndex: i % 4,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.03) return;
    final center = Offset(size.width / 2, size.height * 0.42);
    // 입자는 0.05~0.9 구간 동안 바깥으로 퍼지고, 0.5 이후로 옅어짐
    final travel = Curves.easeOut.transform(((progress - 0.03) / 0.75).clamp(0.0, 1.0));
    final fade = 1.0 - Curves.easeIn.transform(((progress - 0.45) / 0.55).clamp(0.0, 1.0));
    if (fade <= 0) return;

    final palette = [
      ...colors,
      const Color(0xFFFFD54F), // gold accent
      Colors.white,
    ];

    for (final p in _particles) {
      final dx = math.cos(p.angle) * p.speed * travel;
      final dy = math.sin(p.angle) * p.speed * travel - (travel * travel * 40); // 살짝 위로 튀는 궤적
      final offset = center + Offset(dx, dy);
      final color = palette[p.colorIndex % palette.length].withOpacity(fade.clamp(0.0, 1.0));

      final paint = Paint()..color = color;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(p.spin * progress * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.8, height: p.size),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────
// top_landmarks 스타일 랜드마크 모달
// ─────────────────────────────────────────────
String _quizGetLandmarkImageUrl(String name) {
  final snake = name
      .toLowerCase()
      .replaceAll(RegExp(r"[''`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/top_landmarks%2F$snake.jpg?alt=media';
}

class _QuizLandmarkModal extends StatefulWidget {
  final Landmark initialLandmark;
  final Color fallbackThemeColor;
  final CacheManager cacheManager;

  const _QuizLandmarkModal({
    required this.initialLandmark,
    required this.fallbackThemeColor,
    required this.cacheManager,
  });

  @override
  State<_QuizLandmarkModal> createState() => _QuizLandmarkModalState();
}

class _QuizLandmarkModalState extends State<_QuizLandmarkModal> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<LandmarksProvider, CountryProvider>(
      builder: (context, provider, countryProvider, _) {
        final freshLandmark = provider.allLandmarks.firstWhereOrNull(
              (l) => l.name == widget.initialLandmark.name,
        ) ??
            widget.initialLandmark;

        final isVisited = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted = provider.wishlistedLandmarks.contains(freshLandmark.name);
        final visitedSubCount = provider.getVisitedSubLocationCount(freshLandmark.name);
        final totalSubCount = freshLandmark.locations?.length ?? 0;

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere(
                  (c) => c.isoA3 == freshLandmark.countriesIsoA3.first,
            );
            landmarkThemeColor = country.themeColor;
          } catch (_) {}
        }
        final themeColor = landmarkThemeColor ?? widget.fallbackThemeColor;
        const headerTextColor = Colors.white;

        final imageUrl = _quizGetLandmarkImageUrl(freshLandmark.name);

        // 도시명
        String displayCity = freshLandmark.city != 'Unknown' && freshLandmark.city != 'Unknown City'
            ? freshLandmark.city
            : '';

        // 국기 위젯
        Widget buildFlags() {
          final validA2s = freshLandmark.countriesIsoA3.map((isoA3) {
            return countryProvider.allCountries
                .firstWhereOrNull((c) => c.isoA3 == isoA3)
                ?.isoA2;
          }).whereNotNull().toList();

          if (validA2s.isEmpty) return const SizedBox.shrink();
          return Wrap(
            spacing: 4,
            children: validA2s.map((a2) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 24, height: 18,
                child: CountryFlag.fromCountryCode(a2),
              ),
            )).toList(),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                // ── 헤더 이미지 영역 ──
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CachedNetworkImage(
                            cacheManager: widget.cacheManager,
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.grey[100]),
                            errorWidget: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [themeColor, themeColor.withOpacity(0.9)],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.8),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close, color: headerTextColor, size: 20),
                                    label: const Text('Close', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                  if (freshLandmark.global_rank > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: headerTextColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: headerTextColor.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            '#${freshLandmark.global_rank}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: headerTextColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      freshLandmark.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                        color: headerTextColor,
                                        letterSpacing: -0.5,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  if (isVisited || visitedSubCount > 0)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: headerTextColor.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_circle, color: headerTextColor, size: 24),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: headerTextColor.withOpacity(0.9)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        buildFlags(),
                                        if (displayCity.trim().isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            displayCity,
                                            style: TextStyle(fontSize: 14, color: headerTextColor.withOpacity(0.9), fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (totalSubCount > 1) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.layers, size: 16, color: headerTextColor.withOpacity(0.9)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$visitedSubCount / $totalSubCount locations visited',
                                      style: TextStyle(fontSize: 13, color: headerTextColor.withOpacity(0.85), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── 스크롤 바디 ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Wishlist + Rating
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.favorite_border, size: 20, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    Text('Wishlist', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                                    const Spacer(),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                                        color: isWishlisted ? Colors.red : Colors.grey[400],
                                        size: 28,
                                      ),
                                      onPressed: () => provider.toggleWishlistStatus(freshLandmark.name),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Icon(Icons.star_border, size: 20, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    Text('My Rating', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                                    const Spacer(),
                                    RatingBar.builder(
                                      initialRating: freshLandmark.rating ?? 0.0,
                                      minRating: 0,
                                      allowHalfRating: true,
                                      itemCount: 5,
                                      itemSize: 28.0,
                                      itemPadding: const EdgeInsets.symmetric(horizontal: 2),
                                      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                      onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Sub-locations
                          if (totalSubCount > 1) ...[
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Icon(Icons.layers, size: 18, color: themeColor),
                              ),
                              const SizedBox(width: 12),
                              Text('Components / Locations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[900])),
                            ]),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: freshLandmark.locations!.map((loc) {
                                  final isLocVisited = provider.isSubLocationVisited(freshLandmark.name, loc.name);
                                  return CheckboxListTile(
                                    title: Text(loc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    value: isLocVisited,
                                    activeColor: themeColor,
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    onChanged: (_) => provider.toggleSubLocation(freshLandmark.name, loc.name),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Visit History
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.history, size: 18, color: themeColor),
                            ),
                            const SizedBox(width: 12),
                            Text('Visit History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[900])),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                              child: Text('${freshLandmark.visitDates.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                              onPressed: () => provider.addVisitDate(freshLandmark.name),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                side: BorderSide(color: themeColor),
                                foregroundColor: themeColor,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          if (freshLandmark.visitDates.isNotEmpty)
                            ...freshLandmark.visitDates.asMap().entries.map((entry) => _LandmarkVisitEditorCard(
                              key: ValueKey('${freshLandmark.name}_${entry.key}'),
                              landmarkName: freshLandmark.name,
                              visitDate: entry.value,
                              index: entry.key,
                              onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                              availableLocations: freshLandmark.locations,
                            ))
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text('No visits recorded', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),

                          // Info card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [themeColor.withOpacity(0.05), themeColor.withOpacity(0.02)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: themeColor.withOpacity(0.1)),
                            ),
                            child: LandmarkInfoCard(
                              overview: freshLandmark.overview,
                              historySignificance: freshLandmark.history_significance,
                              highlights: freshLandmark.highlights,
                              themeColor: themeColor,
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _LandmarkVisitEditorCard extends StatefulWidget {
  final String landmarkName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final List<LandmarkSubLocation>? availableLocations;

  const _LandmarkVisitEditorCard({
    super.key,
    required this.landmarkName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
    this.availableLocations,
  });

  @override
  State<_LandmarkVisitEditorCard> createState() => _LandmarkVisitEditorCardState();
}

class _LandmarkVisitEditorCardState extends State<_LandmarkVisitEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late List<String> _currentPhotos;
  int? _year, _month, _day;

  late String _displayTitle;
  late String _displayMemo;
  bool _isEditing = false;

  final ExpansionTileController _expansionTileController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.visitDate.title;
    _displayMemo = widget.visitDate.memo ?? '';

    _titleController = TextEditingController(text: _displayTitle);
    _memoController = TextEditingController(text: _displayMemo);
    _currentPhotos = List.from(widget.visitDate.photos);
    _year = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day = widget.visitDate.day;

    if (_displayTitle.isEmpty && _displayMemo.isEmpty && _currentPhotos.isEmpty) {
      _isEditing = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    context.read<LandmarksProvider>().updateLandmarkVisit(
      widget.landmarkName,
      widget.index,
      title: _titleController.text,
      memo: _memoController.text,
      year: _year ?? -9999,
      month: _month ?? -9999,
      day: _day ?? -9999,
      photos: _currentPhotos,
    );

    setState(() {
      _displayTitle = _titleController.text;
      _displayMemo = _memoController.text;
      _isEditing = false;
    });
  }

  void _cancelEditing() {
    setState(() {
      _titleController.text = _displayTitle;
      _memoController.text = _displayMemo;
      _year = widget.visitDate.year;
      _month = widget.visitDate.month;
      _day = widget.visitDate.day;
      _currentPhotos = List.from(widget.visitDate.photos);
      _isEditing = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime initialDate = DateTime(
      _year ?? DateTime.now().year,
      _month ?? DateTime.now().month,
      _day ?? DateTime.now().day,
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      setState(() {
        _year = picked.year;
        _month = picked.month;
        _day = picked.day;
      });
    }
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null && mounted) {
      setState(() {
        _currentPhotos.add(pickedFile.path);
      });
    }
  }

  void _toggleLocationInVisit(String locName, bool isSelected) {
    final provider = context.read<LandmarksProvider>();
    List<String> currentDetails = List.from(widget.visitDate.visitedDetails);

    if (isSelected) {
      if (!currentDetails.contains(locName)) {
        currentDetails.add(locName);
        if (!provider.isSubLocationVisited(widget.landmarkName, locName)) {
          provider.toggleSubLocation(widget.landmarkName, locName);
        }
      }
    } else {
      currentDetails.remove(locName);
    }

    provider.updateLandmarkVisit(
        widget.landmarkName,
        widget.index,
        visitedDetails: currentDetails
    );

    setState(() {});
  }

  Widget _buildPhotoPreview(String photoPath, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(photoPath), fit: BoxFit.cover),
          ),
        ),
        if (_isEditing)
          Positioned(
            top: -6,
            right: 6,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentPhotos.removeAt(index);
                });
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel, color: Colors.red, size: 22),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController,
        initiallyExpanded: _isEditing,
        title: Text(
          _displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text('Date: $_year-$_month-$_day', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Visit Record'),
                content: const Text('Are you sure you want to delete this visit record?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete();
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditing) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Visit Date: $_year-$_month-$_day', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        label: const Text('Edit Date'),
                        onPressed: () => _selectDate(context),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      labelText: 'Memo',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ] else ...[
                  if (_displayMemo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _displayMemo,
                        style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
                      ),
                    ),
                ],

                const SizedBox(height: 12),

                if (widget.availableLocations != null && widget.availableLocations!.length > 1) ...[
                  Text("Locations included in this visit:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: !_isEditing,
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: widget.availableLocations!.map((loc) {
                        final isChecked = widget.visitDate.visitedDetails.contains(loc.name);
                        return FilterChip(
                          label: Text(loc.name, style: const TextStyle(fontSize: 12)),
                          selected: isChecked,
                          selectedColor: themeColor.withOpacity(0.2),
                          checkmarkColor: themeColor,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300)
                          ),
                          onSelected: (bool selected) {
                            _toggleLocationInVisit(loc.name, selected);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_currentPhotos.isNotEmpty || _isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
                          if (_isEditing)
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                                onPressed: () => _pickImage(ImageSource.gallery),
                              ),
                            ),
                          ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList(),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isEditing) ...[
                      TextButton(
                        onPressed: _cancelEditing,
                        child: Text('Cancel', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saveChanges,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Record'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: themeColor,
                          side: BorderSide(color: themeColor.withOpacity(0.5)),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}