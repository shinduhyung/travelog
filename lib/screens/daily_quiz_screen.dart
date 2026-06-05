import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:country_flags/country_flags.dart';
import 'package:image_picker/image_picker.dart';

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
  const DailyQuizScreen({super.key, this.initialDate});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // quizzes.json 캐시 (Storage에서 한 번만 다운로드)
  List<Map<String, dynamic>>? _cachedQuizzes;

  bool _isLoading = true;
  bool _isQuizAvailable = false;
  bool _hasSolved = false;

  // 5월 28일 시작 날짜 세팅 및 선택 날짜 초기화
  final DateTime _startDate = DateTime(2026, 5, 28);
  late DateTime _selectedDate;
  String _dateStr = "";

  String _question = "";
  List<String> _options = [];
  bool _isUserCorrect = false;
  int _correctAnswerIndex = -1;
  int _selectedAnswerIndex = -1;
  String _explanation = "";

  // 모든 날짜의 풀이 결과를 저장하기 위한 맵
  final Map<String, bool> _historySolvedMap = {};
  final Map<String, bool> _historyCorrectMap = {};
  final Map<String, int> _historySelectedIndexMap = {};

  @override
  void initState() {
    super.initState();
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
        _selectedDate = nowUtc.isBefore(_startDate) ? _startDate : nowUtc;
      }
    } else {
      _selectedDate = nowUtc.isBefore(_startDate) ? _startDate : nowUtc;
    }
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadAllQuizHistory();
    await _loadQuizForDate(_selectedDate);
  }

  Future<void> _loadAllQuizHistory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshots = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_history')
          .get();

      for (var doc in snapshots.docs) {
        final data = doc.data();
        _historySolvedMap[doc.id] = true;
        _historyCorrectMap[doc.id] = data['isCorrect'] ?? false;
        final savedIndex = data['selectedAnswerIndex'];
        if (savedIndex != null) {
          _historySelectedIndexMap[doc.id] = savedIndex as int;
        }
      }
    } catch (e) {
      debugPrint("Error loading all quiz history: $e");
    }
  }

  Future<void> _loadQuizForDate(DateTime date) async {
    setState(() => _isLoading = true);
    try {
      final year = date.year.toString();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      _dateStr = "$year$month$day";
      debugPrint("🗓️ [Quiz] 날짜: $_dateStr");

      // quizzes.json 캐시 없으면 Storage에서 다운로드
      if (_cachedQuizzes == null) {
        debugPrint("📥 [Quiz] Storage에서 quizzes.json 다운로드 시작");
        try {
          final ref = FirebaseStorage.instance.ref('functions/quizzes.json');
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
          _cachedQuizzes = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          debugPrint("✅ [Quiz] 캐시 완료 — 총 ${_cachedQuizzes!.length}개 퀴즈");
          if (_cachedQuizzes!.isNotEmpty) {
            debugPrint("   첫 번째 date: ${_cachedQuizzes!.first['date']}, 마지막 date: ${_cachedQuizzes!.last['date']}");
          }
        } catch (storageError) {
          debugPrint("❌ [Quiz] Storage/HTTP 오류: $storageError");
          setState(() { _isQuizAvailable = false; _isLoading = false; });
          return;
        }
      } else {
        debugPrint("💾 [Quiz] 캐시 사용 — 총 ${_cachedQuizzes!.length}개");
      }

      // date 필드로 해당 날짜 퀴즈 찾기
      final quizData = _cachedQuizzes!.firstWhere(
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
      final yesterday = today.subtract(const Duration(days: 1));
      bool isToday = selectedDay == today;
      // 정답 공개: 내가 푼 날 or 어제 이전(전날까지만 답 공개, 오늘은 미풀이시 문제만)
      bool revealAnswer = selectedDay.isBefore(today); // 전날까지만
      debugPrint("📅 [Quiz] isToday=$isToday, revealAnswer=$revealAnswer, hasSolved=\${_historySolvedMap[_dateStr]}");

      if (_historySolvedMap[_dateStr] == true) {
        debugPrint("✅ [Quiz] 이미 풀었음 → solved 상태로 렌더");
        _updateState(quizData, true, _historyCorrectMap[_dateStr] ?? false, _getSelectedAnswerIndexFromLocal(_dateStr) ?? -1);
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
    }
  }

  int? _getSelectedAnswerIndexFromLocal(String dateStr) {
    return _historySelectedIndexMap[dateStr];
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
  }

  Future<void> _submitAnswer(int index) async {
    if (_hasSolved) return;

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      bool isCorrect = (index == _correctAnswerIndex);

      await _firestore
          .collection('users')
          .doc(user?.uid)
          .collection('quiz_history')
          .doc(_dateStr)
          .set({
        'isCorrect': isCorrect,
        'selectedAnswerIndex': index,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _historySolvedMap[_dateStr] = true;
      _historyCorrectMap[_dateStr] = isCorrect;

      setState(() {
        _hasSolved = true;
        _isUserCorrect = isCorrect;
        _selectedAnswerIndex = index;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error submitting answer: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Daily Quiz", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
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
    );
  }

  Widget _buildHorizontalCalendar() {
    final nowUtc = DateTime.now().toUtc();
    final today = DateTime(nowUtc.year, nowUtc.month, nowUtc.day);
    final startDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
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
          final date = _startDate.add(Duration(days: index));
          final prevDate = index > 0 ? _startDate.add(Duration(days: index - 1)) : null;
          final isMonthStart = prevDate == null || date.month != prevDate.month;

          bool isSelected = (date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day);
          bool isFuture = date.isAfter(DateTime(nowUtc.year, nowUtc.month, nowUtc.day));

          String loopDateStr = "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
          bool hasSolved = _historySolvedMap[loopDateStr] ?? false;
          bool isCorrect = _historyCorrectMap[loopDateStr] ?? false;

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
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6366F1),
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              else
                const SizedBox(height: 18),
              GestureDetector(
                onTap: isFuture
                    ? null // 미래 날짜 선택 불가
                    : () {
                  setState(() => _selectedDate = date);
                  _loadQuizForDate(date);
                },
                child: Container(
                  width: 60,
                  height: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : isFuture
                        ? Colors.grey.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: calendarBorder,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                const Icon(Icons.psychology, size: 40, color: Color(0xFF6366F1)),
                const SizedBox(height: 16),
                Text(_question,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), height: 1.4),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(_options.length, (index) => _buildModernOption(index)),
          if (_hasSolved) _buildExplanationSection(),
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

  Widget _buildModernOption(int index) {
    bool isSelected = (index == _selectedAnswerIndex);
    bool isCorrect = (index == _correctAnswerIndex);
    final optionText = _options[index];
    final isVisited = _isOptionVisited(optionText);

    Color borderColor = Colors.grey.shade200;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _submitAnswer(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: backgroundTileColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                onPressed: () => _showInfoModalForOption(optionText),
              ),
              const SizedBox(width: 4),
              Icon(resultIcon, color: iconColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationSection() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.lightbulb, color: Color(0xFF4F46E5), size: 20),
            SizedBox(width: 8),
            Text("Explanation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4338CA))),
          ]),
          const SizedBox(height: 12),
          Text(_explanation, style: const TextStyle(fontSize: 15, color: Color(0xFF3730A3), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No quiz found for this date.", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
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