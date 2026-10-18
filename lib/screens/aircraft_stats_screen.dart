// lib/screens/aircraft_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:jidoapp/screens/add_flight_log_screen.dart';

// ⭐️ [신규 추가] 랭킹 유형을 정의하기 위한 Enum
enum RankingType { aircraft, airline }

class AircraftStatsScreen extends StatefulWidget {
  const AircraftStatsScreen({super.key});

  @override
  State<AircraftStatsScreen> createState() => _AircraftStatsScreenState();
}

class _AircraftStatsScreenState extends State<AircraftStatsScreen> {
  // --- 스타일 정의 ---
  final Color _primaryColor = const Color(0xFF3F51B5); // Indigo (파란색 계열)
  final List<String> _periods = ['Last 30 Days', 'Last 365 Days', 'Year', 'All Time', 'Custom'];
  String _selectedPeriod = 'All Time';
  int _selectedYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  String _selectedAircraftGroup = 'All';
  bool _showRanking = false;
  RankingType _selectedRankingType = RankingType.aircraft;

  int _totalFlightsInPeriod = 0;
  List<Map<String, dynamic>> _rankedAirlines = [];
  List<Map<String, dynamic>> _rankedAircrafts = [];
  Map<String, List<FlightLog>> _groupedLogs = {};
  List<LineChartBarData> _lineChartData = [];
  double _lineChartMaxY = 10.0;

  Map<String, int> _groupCounts = {};
  int? _touchedIndex = -1;

  final Map<String, Map<String, dynamic>> _aircraftGroupInfo = {
    'All': {'color': Colors.deepPurple, 'name': 'All Manufacturers', 'abbr': 'All'},
    'Airbus': {'color': const Color(0xFF1E88E5), 'name': 'Airbus', 'abbr': 'Airbus'}, // Blue
    'Boeing': {'color': const Color(0xFFE53935), 'name': 'Boeing', 'abbr': 'Boeing'}, // Red/Orange tone
    'Others': {'color': const Color(0xFF757575), 'name': 'Others', 'abbr': 'Others'}, // Grey
  };
  final List<String> _aircraftGroupOrder = ['All', 'Airbus', 'Boeing', 'Others'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareData();
  }

  // --- 데이터 처리 로직 ---
  String _getAircraftGroup(String? aircraftModel) {
    if (aircraftModel == null || aircraftModel.isEmpty || aircraftModel.toLowerCase() == 'unknown') {
      return 'Others';
    }
    final model = aircraftModel.toLowerCase().replaceAll('-', '').replaceAll(' ', '');
    if (model.contains('airbus') || model.startsWith('a3') || model.startsWith('a2')) {
      return 'Airbus';
    }
    if (model.contains('boeing') || model.startsWith('b7') || model.startsWith('707') || model.startsWith('717') || model.startsWith('727') || model.startsWith('737') || model.startsWith('747') || model.startsWith('757') || model.startsWith('767') || model.startsWith('777') || model.startsWith('787')) {
      return 'Boeing';
    }
    return 'Others';
  }

  void _prepareData() {
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    final allLogs = airlineProvider.allFlightLogs;

    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Last 30 Days':
        startDate = now.subtract(const Duration(days: 30));
        endDate = now;
        break;
      case 'Last 365 Days':
        startDate = now.subtract(const Duration(days: 365));
        endDate = now;
        break;
      case 'Year':
        startDate = DateTime(_selectedYear, 1, 1);
        endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59);
        break;
      case 'Custom':
        startDate = _customStartDate;
        endDate = _customEndDate;
        break;
      default:
        break;
    }

    final logsInPeriod = allLogs.where((log) {
      if (log.aircraft == null || log.aircraft!.isEmpty || log.aircraft == 'Unknown' || log.isCanceled) {
        return false;
      }
      DateTime? logDate;
      if (log.date != 'Unknown' && log.date.isNotEmpty) {
        try {
          logDate = DateTime.parse(log.date);
        } catch (e) { logDate = null; }
      }
      if (_selectedPeriod == 'All Time') return logDate != null;
      if (logDate == null) return false;
      if (startDate != null && logDate.isBefore(startDate)) return false;
      if (endDate != null && logDate.isAfter(endDate)) return false;
      return true;
    }).toList();

    final Map<String, int> groupCounts = {};
    for (var log in logsInPeriod) {
      final group = _getAircraftGroup(log.aircraft);
      groupCounts[group] = (groupCounts[group] ?? 0) + log.times;
    }

    int totalFlights = groupCounts.values.fold(0, (a, b) => a + b);

    final logsForView = logsInPeriod.where((log) {
      if (_selectedAircraftGroup == 'All') return true;
      return _getAircraftGroup(log.aircraft) == _selectedAircraftGroup;
    }).toList();

    final Map<String, int> airlineCounts = {};
    for (var log in logsForView) {
      if (log.airlineName != null && log.airlineName != 'Unknown') {
        airlineCounts[log.airlineName!] = (airlineCounts[log.airlineName!] ?? 0) + log.times;
      }
    }

    final rankedAirlines = airlineCounts.entries.map((e) => {'name': e.key, 'count': e.value}).toList();
    rankedAirlines.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final Map<String, int> aircraftCounts = {};
    for (var log in logsForView) {
      final model = log.aircraft ?? 'Unknown';
      if (model != 'Unknown') {
        aircraftCounts[model] = (aircraftCounts[model] ?? 0) + log.times;
      }
    }
    final rankedAircrafts = aircraftCounts.entries.map((e) => {'name': e.key, 'count': e.value}).toList();
    rankedAircrafts.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final Map<String, List<FlightLog>> groupedLogs = {};
    for (var log in logsForView) {
      final model = log.aircraft ?? 'Unknown';
      if (!groupedLogs.containsKey(model)) {
        groupedLogs[model] = [];
      }
      groupedLogs[model]!.add(log);
    }
    groupedLogs.forEach((key, value) {
      value.sort((a, b) {
        final dateA = DateTime.tryParse(a.date);
        final dateB = DateTime.tryParse(b.date);
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
    });
    final sortedGroupedLogs = Map.fromEntries(
        groupedLogs.entries.toList()..sort((e1, e2) => e1.key.compareTo(e2.key))
    );

    _prepareLineChartData(allLogs);

    setState(() {
      _totalFlightsInPeriod = totalFlights;
      _groupCounts = groupCounts;
      _groupedLogs = sortedGroupedLogs;
      _rankedAirlines = rankedAirlines;
      _rankedAircrafts = rankedAircrafts;
    });
  }

  void _prepareLineChartData(List<FlightLog> allLogs) {
    final int currentYear = DateTime.now().year;
    final int startYear = currentYear - 9;
    final Map<int, Map<String, int>> yearlyCounts = {
      for (var i = startYear; i <= currentYear; i++) i: {}
    };
    double maxCount = 0;

    for (var log in allLogs) {
      if (log.aircraft == null || log.aircraft!.isEmpty || log.aircraft == 'Unknown' || log.isCanceled || log.date == 'Unknown') continue;
      final year = int.tryParse(log.date.split('-')[0]);
      if (year != null && year >= startYear && year <= currentYear) {
        final group = _getAircraftGroup(log.aircraft);
        yearlyCounts[year]![group] = (yearlyCounts[year]![group] ?? 0) + log.times;
      }
    }

    final List<LineChartBarData> lines = [];
    final Map<String, Color> lineColors = {
      'Airbus': _aircraftGroupInfo['Airbus']!['color'],
      'Boeing': _aircraftGroupInfo['Boeing']!['color'],
      'Others': _aircraftGroupInfo['Others']!['color'],
      'Total': Colors.black87,
    };

    final allDataPoints = <String, List<FlSpot>>{
      for(var group in lineColors.keys) group: []
    };

    for (int year = startYear; year <= currentYear; year++) {
      int yearlyTotal = 0;
      _aircraftGroupInfo.keys.forEach((group) {
        if (group == 'All') return;
        final count = yearlyCounts[year]![group] ?? 0;
        allDataPoints[group]!.add(FlSpot(year.toDouble(), count.toDouble()));
        yearlyTotal += count;
      });
      allDataPoints['Total']!.add(FlSpot(year.toDouble(), yearlyTotal.toDouble()));
      if(yearlyTotal > maxCount) maxCount = yearlyTotal.toDouble();
    }

    allDataPoints.forEach((name, spots) {
      final isTotal = name == 'Total';
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        preventCurveOvershootingThreshold: 0.0,
        color: lineColors[name],
        barWidth: isTotal ? 2.5 : 3,
        dashArray: isTotal ? [5, 5] : null,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: isTotal ? 3 : 4,
              color: lineColors[name]!,
              strokeWidth: 0,
            );
          },
        ),
        belowBarData: BarAreaData(show: false),
      ));
    });

    if (mounted) {
      setState(() {
        _lineChartData = lines;
        double newMaxY = maxCount == 0 ? 10 : (maxCount * 1.25);
        if (newMaxY > 10) { newMaxY = (newMaxY / 5).ceil() * 5.0; } else { newMaxY = newMaxY.ceilToDouble(); }
        _lineChartMaxY = newMaxY;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // AppBar를 제거하고, SafeArea 아래에 SingleChildScrollView를 바로 사용
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 뒤로가기 버튼 제거됨

              _buildPeriodSelector(), // 맨 위로 이동
              const SizedBox(height: 20),
              _buildPieChartSection(),
              const SizedBox(height: 24),
              _buildViewSelector(),
              if (_showRanking) ...[
                const SizedBox(height: 16),
                _buildRankingTypeSelector(),
              ],
              const SizedBox(height: 16),
              _buildAircraftGroupDropdown(),
              const SizedBox(height: 24),
              _showRanking
                  ? (_selectedRankingType == RankingType.aircraft
                  ? _buildAircraftRankingList()
                  : _buildAirlineRankingList())
                  : _buildGroupedFlightLogList(),
              const SizedBox(height: 32),
              _buildLineChartSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // 🚨 [수정] 드롭다운 디자인 개선 및 연도 선택기 통합
  Widget _buildPeriodSelector() {
    // 🚨 [수정] 드롭다운 전체 컨테이너에 테두리와 그림자 추가
    final inputDecoration = InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primaryColor, width: 2.0),
      ),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: Icon(Icons.arrow_drop_down, color: _primaryColor),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.2), // 🚨 [수정] 파란색 그림자
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 'Year'가 선택되었을 때 커스텀 위젯을 사용
          if (_selectedPeriod == 'Year')
            _buildYearSelectorTile()
          else
          // 'Year'가 아닐 때 기존 드롭다운 필드 사용
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: inputDecoration.copyWith(suffixIcon: Icon(Icons.arrow_drop_down, color: _primaryColor)),
              isExpanded: true,
              items: _periods.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    tr(value),
                    style: TextStyle( // 🚨 [수정] 글씨 색깔을 테마색으로 변경
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue == 'Custom') {
                  _showCustomDateRangePicker();
                } else if (newValue != null) {
                  setState(() {
                    _selectedPeriod = newValue;
                  });
                  _prepareData();
                }
              },
            ),

          // Custom 기간 표시
          if (_selectedPeriod == 'Custom' && _customStartDate != null && _customEndDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(tr('${DateFormat('yyyy-MM-dd').format(_customStartDate!)} ~ ${DateFormat('yyyy-MM-dd').format(_customEndDate!)}'), style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🚨 [수정] 'Year' 선택 시 드롭다운 자리에 들어갈 위젯 (스타일 적용 및 Overflow 수정)
  Widget _buildYearSelectorTile() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.5), width: 1.5), // 🚨 [추가] 테두리
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Period 선택 드롭다운 (Year)
          Container(
            padding: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                icon: Icon(Icons.arrow_drop_down, color: _primaryColor), // 🚨 [수정] 파란색 아이콘
                items: _periods.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      tr(value),
                      style: TextStyle( // 🚨 [수정] 글씨 색깔을 테마색으로 변경
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue == 'Custom') {
                    _showCustomDateRangePicker();
                  } else if (newValue != null) {
                    setState(() {
                      _selectedPeriod = newValue;
                    });
                    _prepareData();
                  }
                },
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.black),
              ),
            ),
          ),
          // 🚨 [수정] 연도 선택기 (왼쪽으로 공간 확보)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: _primaryColor), // 🚨 [수정] 파란색 아이콘
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    _selectedYear--;
                    _prepareData();
                  }),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 🚨 [수정] 패딩 축소
                  margin: const EdgeInsets.symmetric(horizontal: 4), // 🚨 [수정] 마진 축소
                  decoration: BoxDecoration(
                    // 🚨 [수정] 파란색 배경
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('$_selectedYear'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      // 🚨 [수정] 파란색 텍스트
                      color: _primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: _primaryColor), // 🚨 [수정] 파란색 아이콘
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    _selectedYear++;
                    _prepareData();
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null ? DateTimeRange(start: _customStartDate!, end: _customEndDate!) : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedPeriod = 'Custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _prepareData();
    }
  }

  Widget _buildPieChartSection() {
    final keys = _aircraftGroupInfo.keys.where((k) => k != 'All').toList();
    final pieData = List.generate(keys.length, (i) {
      final key = keys[i];
      final info = _aircraftGroupInfo[key]!;
      final count = _groupCounts[key] ?? 0;
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 75.0 : 65.0;
      final color = info['color'] as Color;

      return PieChartSectionData(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        value: count.toDouble(),
        title: '',
        radius: radius,
        borderSide: isTouched ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
      );
    });

    Widget? centerWidget;
    if (_touchedIndex == null || _touchedIndex == -1 || _totalFlightsInPeriod == 0) {
      centerWidget = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('$_totalFlightsInPeriod'),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primaryColor),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Total Flights'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    } else {
      final key = keys[_touchedIndex!];
      final info = _aircraftGroupInfo[key]!;
      final count = _groupCounts[key] ?? 0;
      final percentage = (_totalFlightsInPeriod > 0) ? (count / _totalFlightsInPeriod) * 100 : 0.0;
      centerWidget = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(info['abbr']),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: info['color']),
            ),
            const SizedBox(height: 4),
            Text(tr('$count'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(tr('${percentage.toStringAsFixed(1)}%'), style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 🚨 [수정] 원형 그래프 제목
            Padding(
              padding: const EdgeInsets.only(bottom: 40), // 🚨 [수정] 간격을 32에서 40으로 늘림
              child: Text(
                tr('Aircraft Type'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: _primaryColor.lighten(0.1),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              height: 220,
              child: (pieData.isEmpty || _totalFlightsInPeriod == 0)
                  ? Center(child: Text(tr('No data for this period.'), style: TextStyle(color: Colors.grey.shade600)))
                  : Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: pieData,
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 70,
                    ),
                  ),
                  centerWidget,
                ],
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: _aircraftGroupInfo.entries.where((e) => e.key != 'All').map((entry) {
                return _buildLegendItem(entry.value['color'], entry.value['abbr']);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Text(tr(text), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: SegmentedButton<bool>(
        // 🚨 [수정] 체크 표시 제거
        showSelectedIcon: false,
        segments:  [
          ButtonSegment<bool>(value: false, label: Text(tr('Flight Logs')), icon: Icon(Icons.list_alt)),
          ButtonSegment<bool>(value: true, label: Text(tr('Ranking')), icon: Icon(Icons.format_list_numbered)),
        ],
        selected: {_showRanking},
        onSelectionChanged: (Set<bool> newSelection) {
          setState(() {
            _showRanking = newSelection.first;
          });
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: _primaryColor,
          selectedForegroundColor: Colors.white,
          backgroundColor: Colors.white,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildRankingTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: SegmentedButton<RankingType>(
        // 🚨 [수정] 체크 표시 제거
        showSelectedIcon: false,
        segments:  [
          ButtonSegment<RankingType>(value: RankingType.aircraft, label: Text(tr('By Aircraft Type')), icon: Icon(Icons.airplanemode_active)),
          ButtonSegment<RankingType>(value: RankingType.airline, label: Text(tr('By Airline')), icon: Icon(Icons.business)),
        ],
        selected: {_selectedRankingType},
        onSelectionChanged: (Set<RankingType> newSelection) {
          setState(() {
            _selectedRankingType = newSelection.first;
          });
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: _aircraftGroupInfo[_selectedAircraftGroup]!['color'] as Color,
          selectedForegroundColor: Colors.white,
          backgroundColor: Colors.white,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // 🚨 [수정] 드롭다운 디자인 개선
  Widget _buildAircraftGroupDropdown() {
    final selectedColor = _aircraftGroupInfo[_selectedAircraftGroup]!['color'] as Color;

    final inputDecoration = InputDecoration(
      labelText: tr('Aircraft Manufacturer'),
      labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
      prefixIcon: Icon(Icons.airplanemode_active, color: selectedColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: selectedColor.withOpacity(0.5), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: selectedColor.withOpacity(0.5), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: selectedColor, width: 2.0),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: selectedColor.withOpacity(0.2), // 🚨 [수정] 색상에 맞는 그림자
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedAircraftGroup,
        decoration: inputDecoration,
        items: _aircraftGroupOrder.map((key) {
          final entry = _aircraftGroupInfo[key]!;
          return DropdownMenuItem<String>(
            value: key,
            child: Text(
              tr(entry['name']),
              style: TextStyle(color: entry['color'], fontWeight: FontWeight.bold, fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedAircraftGroup = newValue;
            });
            _prepareData();
          }
        },
      ),
    );
  }

  Widget _buildGroupedFlightLogList() {
    if (_groupedLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            // 수정됨: Icons.flight_off -> Icons.airplanemode_inactive
            Icon(Icons.airplanemode_inactive, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(tr('No flights found'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          ],
        ),
      );
    }
    final groupKeys = _groupedLogs.keys.toList();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupKeys.length,
      itemBuilder: (context, index) {
        final aircraftModel = groupKeys[index];
        final logs = _groupedLogs[aircraftModel]!;
        final group = _getAircraftGroup(aircraftModel);
        final color = _aircraftGroupInfo[group]!['color'] as Color;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                tr(aircraftModel),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            ...logs.map((log) => _buildLogCard(log)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildAirlineRankingList() {
    if (_rankedAirlines.isEmpty) {
      return  Center(heightFactor: 5, child: Text(tr('No airlines to rank.')));
    }
    final maxCount = _rankedAirlines.isNotEmpty ? _rankedAirlines.first['count'] as int : 1;
    final color = _aircraftGroupInfo[_selectedAircraftGroup]!['color'] as Color;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: math.min(_rankedAirlines.length, 10),
      itemBuilder: (context, index) {
        final item = _rankedAirlines[index];
        return _buildRankingCard(
          index: index,
          name: item['name'],
          count: item['count'],
          maxCount: maxCount,
          color: color,
        );
      },
    );
  }

  Widget _buildAircraftRankingList() {
    if (_rankedAircrafts.isEmpty) {
      return  Center(heightFactor: 5, child: Text(tr('No aircraft to rank.')));
    }
    final maxCount = _rankedAircrafts.isNotEmpty ? _rankedAircrafts.first['count'] as int : 1;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: math.min(_rankedAircrafts.length, 20),
      itemBuilder: (context, index) {
        final item = _rankedAircrafts[index];
        final group = _getAircraftGroup(item['name']);
        final color = _aircraftGroupInfo[group]!['color'] as Color;
        return _buildRankingCard(
            index: index,
            name: item['name'],
            count: item['count'],
            maxCount: maxCount,
            color: color
        );
      },
    );
  }

  Widget _buildRankingCard({required int index, required String name, required int count, required int maxCount, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text(tr('#${index + 1}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(tr(name), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(tr('$count Flights'), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: count / (maxCount > 0 ? maxCount : 1),
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.trending_up, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  tr("Yearly Trend (10 Years)"),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.grey[200]!, strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) {
                      if (value == meta.max || value == meta.min) return Container();
                      return SideTitleWidget(axisSide: meta.axisSide, child: Text(tr(value.toInt().toString()), style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)));
                    })),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1, getTitlesWidget: (value, meta) {
                      return SideTitleWidget(axisSide: meta.axisSide, child: Text(tr(value.toInt().toString().substring(2)), style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)));
                    })),
                  ),
                  borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1), left: BorderSide(color: Colors.grey[300]!, width: 1))),
                  minX: (DateTime.now().year - 9).toDouble(),
                  maxX: DateTime.now().year.toDouble(),
                  minY: 0,
                  maxY: _lineChartMaxY,
                  lineBarsData: _lineChartData,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(Colors.black87, 'Total'),
                ..._aircraftGroupInfo.entries.where((e) => e.key != 'All').map((e) => _buildLegendItem(e.value['color'], e.value['abbr'])),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(FlightLog log) {
    String displayDate = log.date;
    if (displayDate != 'Unknown') {
      try {
        displayDate = DateFormat.yMMMd(AppLocale.instance.locale.languageCode).format(DateTime.parse(displayDate));
      } catch (e) {}
    }

    final aircraftUpper = log.aircraft?.toUpperCase() ?? '-';
    final displayAircraft = (aircraftUpper == 'UNKNOWN' || aircraftUpper.isEmpty) ? '-' : aircraftUpper;
    final group = _getAircraftGroup(log.aircraft);
    final color = _aircraftGroupInfo[group]!['color'] as Color;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddFlightLogScreen(initialLog: log, isEditing: true))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.flight, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.airlineName ?? tr('Unknown'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(tr(displayAircraft), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 8),
                    Text(tr('${log.departureIata ?? 'N/A'} → ${log.arrivalIata ?? 'N/A'}'), style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tr(displayDate), style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  if (log.rating > 0) ...[
                    const SizedBox(height: 8),
                    RatingBar.builder(
                      initialRating: log.rating,
                      itemCount: 5,
                      itemSize: 16.0,
                      itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber.shade700),
                      onRatingUpdate: (rating) {},
                      ignoreGestures: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
  Color lighten([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}