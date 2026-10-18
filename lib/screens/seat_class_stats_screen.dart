// lib/screens/seat_class_stats_screen.dart

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


class SeatClassStatsScreen extends StatefulWidget {
  const SeatClassStatsScreen({super.key});

  @override
  State<SeatClassStatsScreen> createState() => _SeatClassStatsScreenState();
}

class _SeatClassStatsScreenState extends State<SeatClassStatsScreen> {
  // --- 상태 변수 정의 ---
  // 🚨 [수정] 디자인 통일을 위한 Primary Color 정의 (DeepPurple 유지)
  final Color _primaryColor = Colors.deepPurple;

  final List<String> _periods = ['Last 30 Days', 'Last 365 Days', 'Year', 'All Time', 'Custom'];
  String _selectedPeriod = 'All Time';
  int _selectedYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // 좌석 등급 및 뷰 선택
  String _selectedSeatClass = 'Economy';
  bool _showRanking = false; // Log <-> Ranking 스위치

  // 데이터 처리 결과 저장
  int? _touchedIndex = -1;
  Map<String, int> _classCounts = {};
  int _totalFlightsInPeriod = 0;
  List<FlightLog> _filteredLogsForView = [];
  List<Map<String, dynamic>> _rankedAirlines = [];
  List<LineChartBarData> _lineChartData = [];
  double _lineChartMaxY = 10.0; // 라인차트 Y축 최대값

  final Map<String, Map<String, dynamic>> _seatClassInfo = {
    'Economy': {'color': Colors.blue, 'name': 'Economy', 'abbr': 'Eco.'},
    'Premium Economy': {'color': Colors.indigo, 'name': 'Premium Economy', 'abbr': 'Pre. Eco.'},
    'Business': {'color': Colors.purple, 'name': 'Business', 'abbr': 'Business'},
    'First': {'color': Colors.pink.shade400, 'name': 'First', 'abbr': 'First'},
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareData(); // 데이터 로드 및 처리
  }

  // --- 데이터 처리 로직 ---
  void _prepareData() {
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    final allLogs = airlineProvider.allFlightLogs;

    // 1. 기간에 따른 startDate, endDate 계산
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
      case 'All Time':
      default:
        break;
    }

    // 2. 기간 및 'Unknown' 좌석 등급 제외 필터링
    final logsInPeriod = allLogs.where((log) {
      if (log.seatClass == 'Unknown' || log.isCanceled) return false;

      DateTime? logDate;
      if (log.date != 'Unknown' && log.date.isNotEmpty) {
        final parts = log.date.split('-');
        if (parts.isNotEmpty && int.tryParse(parts[0]) != null) {
          try {
            final year = int.parse(parts[0]);
            final month = parts.length > 1 ? int.parse(parts[1]) : 1;
            final day = parts.length > 2 ? int.parse(parts[2]) : 1;
            logDate = DateTime(year, month, day);
          } catch (e) { logDate = null; }
        }
      }

      if (_selectedPeriod == 'All Time') return logDate != null;

      if (logDate == null) return false;
      if (startDate != null && logDate.isBefore(startDate)) return false;
      if (endDate != null && logDate.isAfter(endDate)) return false;
      return true;
    }).toList();

    // 3. 파이 차트 데이터 생성을 위한 카운트
    final Map<String, int> classCounts = {};
    for (var log in logsInPeriod) {
      if (log.seatClass != null) {
        classCounts[log.seatClass!] = (classCounts[log.seatClass!] ?? 0) + log.times;
      }
    }

    int totalFlights = classCounts.values.fold(0, (a, b) => a + b);

    // 4. 하단 뷰를 위한 데이터 필터링 (선택된 좌석 등급 기준)
    final logsForView = logsInPeriod.where((log) => log.seatClass == _selectedSeatClass).toList();

    // 5. 항공사 랭킹 데이터 생성
    final Map<String, int> airlineCounts = {};
    for (var log in logsForView) {
      if (log.airlineName != null && log.airlineName != 'Unknown') {
        airlineCounts[log.airlineName!] = (airlineCounts[log.airlineName!] ?? 0) + log.times;
      }
    }

    final ranked = airlineCounts.entries.map((e) => {'name': e.key, 'count': e.value}).toList();
    ranked.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    // 6. 라인 그래프 데이터 생성 (최근 10년)
    _prepareLineChartData(allLogs);

    // 7. 상태 업데이트
    setState(() {
      _totalFlightsInPeriod = totalFlights;
      _classCounts = classCounts;
      _filteredLogsForView = logsForView;
      _rankedAirlines = ranked;
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
      if (log.seatClass == 'Unknown' || log.isCanceled || log.date == 'Unknown') continue;
      final year = int.tryParse(log.date.split('-')[0]);
      if (year != null && year >= startYear && year <= currentYear) {
        final seatClass = log.seatClass!;
        yearlyCounts[year]![seatClass] = (yearlyCounts[year]![seatClass] ?? 0) + log.times;
      }
    }

    final List<LineChartBarData> lines = [];
    final Map<String, Color> lineColors = {
      'Economy': _seatClassInfo['Economy']!['color'],
      'Premium Economy': _seatClassInfo['Premium Economy']!['color'],
      'Business': _seatClassInfo['Business']!['color'],
      'First': _seatClassInfo['First']!['color'],
      'Total': Colors.black,
    };

    final allDataPoints = <String, List<FlSpot>>{
      for(var sc in lineColors.keys) sc: []
    };

    for (int year = startYear; year <= currentYear; year++) {
      int yearlyTotal = 0;
      _seatClassInfo.keys.forEach((sc) {
        final count = yearlyCounts[year]![sc] ?? 0;
        allDataPoints[sc]!.add(FlSpot(year.toDouble(), count.toDouble()));
        yearlyTotal += count;
      });
      allDataPoints['Total']!.add(FlSpot(year.toDouble(), yearlyTotal.toDouble()));
      if(yearlyTotal > maxCount) maxCount = yearlyTotal.toDouble();
    }

    allDataPoints.forEach((name, spots) {
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true, // 스타일 통일
        preventCurveOverShooting: true,
        preventCurveOvershootingThreshold: 0.0,
        color: lineColors[name],
        barWidth: name == 'Total' ? 3.5 : 2.5,
        dashArray: name == 'Total' ? [4, 4] : null,
        isStrokeCapRound: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    });

    if (mounted) {
      setState(() {
        _lineChartData = lines;
        _lineChartMaxY = maxCount == 0 ? 10 : (maxCount * 1.25);
      });
    }
  }

  // --- 위젯 빌드 메서드 ---
  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    // 🚨 [수정] Scaffold 배경색 및 AppBar 제거
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0), // 패딩 통일
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPeriodSelector(),
              const SizedBox(height: 20),
              _buildPieChartSection(),
              const SizedBox(height: 24),
              _buildViewSelector(),
              const SizedBox(height: 20),
              _buildSeatClassDropdown(),
              const SizedBox(height: 24),
              _showRanking ? _buildRankingList() : _buildFlightLogList(),
              const SizedBox(height: 32),
              _buildLineChartSection(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // 🚨 [수정] 통일된 Period Selector 디자인 (Year 화살표 포함)
  Widget _buildPeriodSelector() {
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
            color: _primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedPeriod == 'Year')
            _buildYearSelectorTile()
          else
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: inputDecoration.copyWith(suffixIcon: Icon(Icons.arrow_drop_down, color: _primaryColor)),
              isExpanded: true,
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
              ),
              items: _periods.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    tr(value),
                    style: TextStyle(
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

          if (_selectedPeriod == 'Custom' && _customStartDate != null && _customEndDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      tr('${DateFormat('yyyy-MM-dd').format(_customStartDate!)} ~ ${DateFormat('yyyy-MM-dd').format(_customEndDate!)}'),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYearSelectorTile() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
                items: _periods.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      tr(value),
                      style: TextStyle(
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                  fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: _primaryColor),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    _selectedYear--;
                    _prepareData();
                  }),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('$_selectedYear'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: _primaryColor),
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
            colorScheme: ColorScheme.light(primary: _primaryColor, onPrimary: Colors.white),
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
    final keys = _seatClassInfo.keys.toList();
    final pieData = List.generate(keys.length, (i) {
      final key = keys[i];
      final info = _seatClassInfo[key]!;
      final count = _classCounts[key] ?? 0;
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
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    } else {
      final key = keys[_touchedIndex!];
      final info = _seatClassInfo[key]!;
      final count = _classCounts[key] ?? 0;
      final percentage = (_totalFlightsInPeriod > 0) ? (count / _totalFlightsInPeriod) * 100 : 0.0;
      centerWidget = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(info['abbr']),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: info['color'],
              ),
            ),
            const SizedBox(height: 4),
            Text(tr('$count'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(tr('${percentage.toStringAsFixed(1)}%'), style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      );
    }

    // 🚨 [수정] 통일된 파이차트 컨테이너 디자인
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
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Text(
                tr('Seat Class'),
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
              child: (_totalFlightsInPeriod == 0)
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), Text(tr('No data for this period'), style: TextStyle(color: Colors.grey[500], fontSize: 16))]))
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
              spacing: 8.0, // 12.0 -> 8.0 축소
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: _seatClassInfo.entries.map((entry) {
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
      // Padding 축소: horizontal 10->8, vertical 6->4
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4), // 간격 축소 8->4
          Text(trSeatClass(text), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Colors.grey[800])), // 폰트 축소 11->10
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
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SegmentedButton<bool>(
        // 🚨 [수정] 체크 아이콘 제거
        showSelectedIcon: false,
        segments:  [
          ButtonSegment<bool>(value: false, label: Text(tr('Flight Logs')), icon: Icon(Icons.list_alt)),
          ButtonSegment<bool>(value: true, label: Text(tr('Ranking')), icon: Icon(Icons.emoji_events)),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSeatClassDropdown() {
    final selectedColor = _seatClassInfo[_selectedSeatClass]!['color'] as Color;

    final inputDecoration = InputDecoration(
      labelText: tr('Seat Class'),
      labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
      prefixIcon: Icon(Icons.chair, color: selectedColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: selectedColor.withOpacity(0.5), width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: selectedColor.withOpacity(0.5), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: selectedColor, width: 2.0)),
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
            color: selectedColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedSeatClass,
        decoration: inputDecoration,
        items: _seatClassInfo.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: entry.value['color'], shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Text(
                  trSeatClass(entry.value['name']),
                  style: TextStyle(color: entry.value['color'], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedSeatClass = newValue;
            });
            _prepareData();
          }
        },
      ),
    );
  }

  Widget _buildFlightLogList() {
    if (_filteredLogsForView.isEmpty) {
      return _buildEmptyState('flights');
    }
    _filteredLogsForView.sort((a,b) => b.date.compareTo(a.date));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredLogsForView.length,
      itemBuilder: (context, index) {
        return _buildLogCard(_filteredLogsForView[index]);
      },
    );
  }

  Widget _buildEmptyState(String type) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            // 🚨 [수정] Icons.flight_off 제거 및 airplanemode_inactive 적용
            child: Icon(Icons.airplanemode_inactive, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(tr('No $type found'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(tr('for this type in the selected period'), style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildRankingList() {
    if (_rankedAirlines.isEmpty) {
      return _buildEmptyState('airlines');
    }
    final maxCount = _rankedAirlines.isNotEmpty ? _rankedAirlines.first['count'] as int : 1;
    final color = _seatClassInfo[_selectedSeatClass]!['color'] as Color;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: math.min(_rankedAirlines.length, 10),
      itemBuilder: (context, index) {
        final item = _rankedAirlines[index];
        final name = item['name'] as String;
        final count = item['count'] as int;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
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
                      child: Center(
                        child: Text(
                          tr('#${index + 1}'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tr(name), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text(tr('$count Flights'), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
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
      },
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
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
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) return Container();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(tr(value.toInt().toString()), style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(tr(value.toInt().toString().substring(2)), style: const TextStyle(fontSize: 12)),
                          );
                        },
                      ),
                    ),
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0, // 12.0 -> 8.0 축소
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem(Colors.black, 'Total'),
                ..._seatClassInfo.entries.map((e) => _buildLegendItem(e.value['color'], e.value['abbr'])),
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
        final dateTime = DateTime.parse(displayDate);
        displayDate = DateFormat.yMMMd(AppLocale.instance.locale.languageCode).format(dateTime);
      } catch (e) {/* Use original date string */}
    }

    final flightNumberUpper = log.flightNumber.toUpperCase();
    final displayFlightNumber = (flightNumberUpper == 'UNKNOWN' || flightNumberUpper.isEmpty) ? '-' : flightNumberUpper;
    final seatClassColor = _seatClassInfo[log.seatClass]?['color'] as Color? ?? _primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: seatClassColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: seatClassColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                decoration: BoxDecoration(
                  color: seatClassColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.flight, color: seatClassColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.airlineName ?? tr('Unknown'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(tr(displayFlightNumber), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
                    const SizedBox(height: 4),
                    Text(tr('${log.departureIata ?? 'N/A'} → ${log.arrivalIata ?? 'N/A'}'), style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tr(displayDate), style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  if (log.rating > 0) ...[
                    const SizedBox(height: 8),
                    RatingBar.builder(
                      initialRating: log.rating,
                      itemCount: 5,
                      itemSize: 16.0,
                      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
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
