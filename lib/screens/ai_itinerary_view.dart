// lib/screens/ai_itinerary_view.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/models/itinerary_entry_model.dart'; // Itinerary 모델 추가
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/providers/itinerary_provider.dart'; // Provider 추가
import 'package:provider/provider.dart';

// 데이터 소스 구분을 위한 열거형
enum ItinerarySourceType { tripLog, itinerary }

class ActivityItem {
  String emoji;
  String content;
  ActivityItem({required this.emoji, required this.content});
}

class DailyPageModel {
  String date;
  String dayName;
  List<ActivityItem> activities;
  DailyPageModel({required this.date, required this.dayName, required this.activities});
}

class AiItineraryView extends StatefulWidget {
  // 소스 타입에 따라 ID 타입이 다를 수 있으므로 유연하게 처리
  final String title;
  final String entryId; // TripLog는 String, Itinerary는 int(String으로 변환해서 전달)
  final ItinerarySourceType sourceType;
  final DateTime? initialDate;

  const AiItineraryView({
    super.key,
    required this.title,
    required this.entryId,
    required this.sourceType,
    this.initialDate,
  });

  @override
  State<AiItineraryView> createState() => _AiItineraryViewState();
}

class _AiItineraryViewState extends State<AiItineraryView> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DailyPageModel> _dailyPages = [];
  PageController? _pageController;
  int _currentPage = 0;

  static const Color orange = Color(0xFFF97316);
  static const Color lightOrange = Color(0xFFFED7AA);

  // ⭐️ AI가 생성한 이모지 제거용 패턴 (더 강력하게 적용)
  // 줄의 시작 부분에 있는 이모지 + 공백을 제거
  final RegExp _aiEmojiPattern = RegExp(r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]\s*', unicode: true);

  @override
  void initState() {
    super.initState();
    _loadItinerary();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadItinerary() async {
    try {
      String itineraryText = '';

      // ⭐️ 소스 타입에 따라 다른 Provider에서 텍스트 로드
      if (widget.sourceType == ItinerarySourceType.tripLog) {
        itineraryText = await Provider.of<TripLogProvider>(context, listen: false)
            .getOrGenerateItinerary(widget.entryId);
      } else {
        // ItineraryEntry는 이미 텍스트를 가지고 있으므로 Provider에서 entry를 찾아 가져옴
        final intId = int.parse(widget.entryId);
        final entry = Provider.of<ItineraryProvider>(context, listen: false)
            .entries.firstWhere((e) => e.id == intId);
        itineraryText = entry.generatedItinerary;
      }

      _parseItineraryToState(itineraryText);

      setState(() {
        _isLoading = false;
      });

      if (widget.initialDate != null && _dailyPages.isNotEmpty) {
        final targetDateStr = widget.initialDate!.toIso8601String().substring(0, 10);
        final foundIndex = _dailyPages.indexWhere((page) => page.date == targetDateStr);
        if (foundIndex != -1) {
          _currentPage = foundIndex;
          _pageController = PageController(initialPage: foundIndex);
        }
      }
      _pageController ??= PageController(initialPage: 0);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load itinerary: $e';
      });
    }
  }

  void _parseItineraryToState(String itineraryText) {
    final List<DailyPageModel> pages = [];
    final lines = itineraryText.split('\n');

    String? currentDate;
    String? currentDayName;
    List<ActivityItem> currentActivities = [];

    // 📅 아이콘을 포함하거나 포함하지 않는 날짜 패턴
    final datePattern = RegExp(r'(?:📅\s*)?(\d{4}-\d{2}-\d{2})\s*\((\w+)\)');

    void saveCurrentDay() {
      if (currentDate != null) {
        pages.add(DailyPageModel(
          date: currentDate!,
          dayName: currentDayName ?? '',
          activities: List.from(currentActivities),
        ));
      }
    }

    for (var line in lines) {
      final trimmed = line.trim();
      // ❗️ [재수정] 파싱 시 '---' 라인과 빈 줄 확실히 제거
      if (trimmed.isEmpty || trimmed == '---') continue;

      final match = datePattern.firstMatch(trimmed);

      if (match != null) {
        saveCurrentDay();
        currentDate = match.group(1);
        currentDayName = match.group(2);
        currentActivities = [];
      } else if (currentDate != null) {
        // ⭐️ [이모지 중복 제거 로직]
        // 1. AI가 붙인 이모지 제거
        String cleanContent = trimmed.replaceAll(_aiEmojiPattern, '').trim();

        // 2. 뷰어 전용 이모지 결정
        String emoji = _getEmojiForActivity(cleanContent);

        currentActivities.add(ActivityItem(emoji: emoji, content: cleanContent));
      }
    }
    saveCurrentDay();

    if (pages.isEmpty && lines.isNotEmpty) {
      // 날짜 파싱 실패 시 통짜 표시 로직 (안전장치 유지)
      pages.add(DailyPageModel(
          date: 'Itinerary',
          dayName: '',
          activities: lines.where((l) => l.trim().isNotEmpty && l.trim() != '---').map((l) {
            String clean = l.replaceAll(_aiEmojiPattern, '').trim();
            return ActivityItem(emoji: _getEmojiForActivity(clean), content: clean);
          }).toList()
      ));
    }

    _dailyPages = pages;
  }

  Future<void> _saveChanges() async {
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i < _dailyPages.length; i++) {
      final page = _dailyPages[i];
      buffer.writeln('📅 ${page.date} (${page.dayName})');
      buffer.writeln();

      for (final activity in page.activities) {
        // ⭐️ 저장 포맷: [이모지] [내용]
        buffer.writeln('${activity.emoji} ${activity.content}');
      }

      if (i < _dailyPages.length - 1) {
        buffer.writeln();
        // ❗️ [재수정] 날짜 구분선 '---' 출력 로직 확실히 제거
        // buffer.writeln('---'); // 이 코드를 출력하지 않음
        buffer.writeln();
      }
    }

    final newItinerary = buffer.toString();

    // ⭐️ 소스 타입에 따라 적절한 Provider 호출
    if (widget.sourceType == ItinerarySourceType.tripLog) {
      await Provider.of<TripLogProvider>(context, listen: false)
          .saveUserEditedItinerary(widget.entryId, newItinerary);
    } else {
      await Provider.of<ItineraryProvider>(context, listen: false)
          .saveUserEditedItinerary(int.parse(widget.entryId), newItinerary);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(tr('Changes saved successfully!'))),
      );
    }
  }

  String _getEmojiForActivity(String activity) {
    // 사용자가 수동으로 설정한 이모지(유니코드)가 맨 앞에 있다면 그대로 사용
    if (activity.characters.isNotEmpty && activity.characters.first.runes.first > 0x1F000) {
      // 이 로직은 파싱 단계에서 이미 AI 이모지가 제거되었기 때문에,
      // 사실상 사용자가 입력 필드에서 이모지를 넣었을 때만 작동합니다.
    }

    final lower = activity.toLowerCase();
    if (lower.contains('airport') || lower.contains('flight') || lower.contains('terminal')) return '🛫';
    if (lower.contains('arrival') || lower.contains('landed')) return '🛬';
    if (lower.contains('train') || lower.contains('station')) return '🚄';
    if (lower.contains('bus')) return '🚌';
    if (lower.contains('hotel') || lower.contains('check-in')) return '🏨';
    if (lower.contains('eat') || lower.contains('food') || lower.contains('dinner')) return '🍽️';
    if (lower.contains('coffee') || lower.contains('cafe')) return '☕';
    if (lower.contains('museum') || lower.contains('gallery')) return '🏛️';
    if (lower.contains('shopping') || lower.contains('market')) return '🛍️';

    // ❗️ '✨' 대신 '📍' (핀)으로 통일 (이전 수정 유지)
    return '📍';
  }

  void _showEditDialog(ActivityItem item) {
    final textController = TextEditingController(text: item.content);
    String selectedEmoji = item.emoji;

    final List<String> emojiOptions = [
      '🛫', '🛬', '✈️', '🚄', '🚌', '🚗', '🏨', '🍽️', '☕',
      '🏛️', '🌳', '🛍️', '📍', '🌊', '⛰️', '🎡', '📸'
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:  Text(tr('Edit Activity')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: emojiOptions.map((e) {
                        final isSelected = e == selectedEmoji;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() { selectedEmoji = e; });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? orange.withOpacity(0.2) : Colors.transparent,
                              border: isSelected ? Border.all(color: orange) : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(tr(e), style: const TextStyle(fontSize: 24)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    decoration:  InputDecoration(labelText: tr('Activity Details'), border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child:  Text(tr('Cancel'))),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      item.content = textController.text;
                      item.emoji = selectedEmoji;
                    });
                    _saveChanges();
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: orange),
                  child:  Text(tr('Save'), style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: Text(tr(widget.title), style: const TextStyle(fontWeight: FontWeight.bold)), // title 사용
        // ... (나머지 AppBar 및 Body 코드는 이전과 동일)
        actions: [
          // 복사 버튼 등 기존 코드 유지
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(orange)))
          : _errorMessage != null
          ? Center(child: Text(tr(_errorMessage!)))
          : Column(
        children: [
          // Top navigation, PageView 등 기존 UI 코드 그대로 사용
          _buildNavigationHeader(), // (메서드 분리 혹은 인라인 코드 유지)
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _dailyPages.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) => _buildDayPage(_dailyPages[index], index + 1, _dailyPages.length),
            ),
          ),
        ],
      ),
    );
  }

  // 헬퍼 위젯: 상단 네비게이션 (기존 코드와 동일)
  Widget _buildNavigationHeader() {
    return Container(
      color: orange,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _currentPage > 0 ? () => _pageController!.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
            icon: Icon(Icons.arrow_back_ios_rounded, color: _currentPage > 0 ? Colors.white : Colors.white.withOpacity(0.3)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(tr(_dailyPages[_currentPage].date), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (_dailyPages[_currentPage].dayName.isNotEmpty)
                  Text(tr(_dailyPages[_currentPage].dayName), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
              ],
            ),
          ),
          IconButton(
            onPressed: _currentPage < _dailyPages.length - 1 ? () => _pageController!.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
            icon: Icon(Icons.arrow_forward_ios_rounded, color: _currentPage < _dailyPages.length - 1 ? Colors.white : Colors.white.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  // 헬퍼 위젯: 페이지 빌더 (기존 코드와 동일)
  Widget _buildDayPage(DailyPageModel pageData, int pageNum, int totalPages) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [orange, lightOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                      child: Text(tr('DAY $pageNum'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Text(tr('$pageNum / $totalPages'), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(tr(pageData.date), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Activities
          ...pageData.activities.map((item) {
            return GestureDetector(
              onTap: () => _showEditDialog(item),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text(tr(item.emoji), style: const TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(tr(item.content), style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87, fontWeight: FontWeight.w500)),
                      ),
                      Icon(Icons.edit, size: 16, color: Colors.grey[300]),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}