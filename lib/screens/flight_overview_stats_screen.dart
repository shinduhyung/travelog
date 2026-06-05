//lib/screens/flight_overview_stats_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/screens/flights_menu_screen.dart';
import 'package:fl_chart/fl_chart.dart';

enum StatType { distance, duration, count }

enum LongestShortestPeriod { day, week, month, year, allTime }

enum MostFrequentPeriod { day, week, month, year }

class FlightOverviewStatsScreen extends StatefulWidget {
  const FlightOverviewStatsScreen({super.key});

  @override
  _FlightOverviewStatsScreenState createState() => _FlightOverviewStatsScreenState();
}

class _FlightOverviewStatsScreenState extends State<FlightOverviewStatsScreen> {
  Map<String, Future<Map<String, double>>> _distanceStatsFutures = {};
  Map<String, Future<Map<String, double>>> _durationStatsFutures = {};
  Map<String, Future<Map<String, double>>> _countStatsFutures = {};
  Map<String, Future<Map<String, dynamic>>> _longestShortestDistanceFutures = {};
  Map<String, Future<Map<String, dynamic>>> _longestShortestDurationFutures = {};
  Map<String, Future<Map<String, dynamic>>> _longestShortestCountFutures = {};
  Map<MostFrequentPeriod, Future<Map<String, dynamic>>> _mostFrequentFutures = {};
  Future<Map<String, dynamic>>? _yearlyTrendFuture;

  bool _showAverageDistance = false;
  bool _showAverageDuration = false;
  bool _showAverageCount = false;

  StatType _selectedStatType = StatType.distance;
  LongestShortestPeriod _selectedLongestShortestPeriod = LongestShortestPeriod.allTime;
  MostFrequentPeriod _selectedMostFrequentPeriod = MostFrequentPeriod.month;
  int _interactiveYear = DateTime.now().year;
  int _longestShortestSelectedYear = DateTime.now().year;

  DateTime? _customStartDate;
  DateTime? _customEndDate;
  Future<Map<String, double>>? _customDistanceStatsFuture;
  Future<Map<String, double>>? _customDurationStatsFuture;
  Future<Map<String, double>>? _customCountStatsFuture;
  Future<Map<String, dynamic>>? _customLongestShortestDistanceFuture;
  Future<Map<String, dynamic>>? _customLongestShortestDurationFuture;
  Future<Map<String, dynamic>>? _customLongestShortestCountFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchStats();
    _fetchLongestShortestStatsForPeriod(_selectedLongestShortestPeriod);
    _fetchMostFrequentStats();
    _fetchYearlyTrendData();
  }

  Color _getStatTypeColor() {
    switch (_selectedStatType) {
      case StatType.distance:
        return Colors.blue;
      case StatType.duration:
        return Colors.purple;
      case StatType.count:
        return Colors.orange;
    }
  }

  // ---------------------------------------------------------------------------
  // 🚨 추가: 대형 숫자를 B/M/k 단위로 포맷팅하는 헬퍼 함수
  // ---------------------------------------------------------------------------
  String _formatLargeNumber(double value, {int precision = 0}) {
    if (value >= 1000000000) {
      return (value / 1000000000).toStringAsFixed(precision) + 'B';
    } else if (value >= 1000000) {
      return (value / 1000000).toStringAsFixed(precision) + 'M';
    } else if (value >= 1000) {
      return (value / 1000).toStringAsFixed(precision) + 'k';
    } else {
      return value.toStringAsFixed(precision);
    }
  }

  // Y축 간격을 동적으로 계산하는 헬퍼 함수
  double _calculateNiceInterval(double maxValue, {int desiredCount = 5}) {
    if (maxValue <= 0) return 1.0;

    double roughStep = maxValue / desiredCount;

    double exponent = (log(roughStep) / log(10)).floorToDouble();
    double powerOfTen = pow(10, exponent).toDouble();

    if (roughStep <= 1.0 * powerOfTen) {
      return 1.0 * powerOfTen;
    } else if (roughStep <= 2.0 * powerOfTen) {
      return 2.0 * powerOfTen;
    } else if (roughStep <= 5.0 * powerOfTen) {
      return 5.0 * powerOfTen;
    } else {
      return 10.0 * powerOfTen;
    }
  }

  // 거리 파싱 헬퍼
  double _getDistanceValue(FlightLog flight, AirportProvider airportProvider) {
    try {
      final dep = airportProvider.allAirports.firstWhere(
              (e) => e.iataCode == flight.departureIata,
          orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0));
      final arr = airportProvider.allAirports.firstWhere(
              (e) => e.iataCode == flight.arrivalIata,
          orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0));

      if (dep.iataCode.isEmpty || arr.iataCode.isEmpty) return -1;
      if (dep.latitude == 0 && dep.longitude == 0) return -1;
      if (arr.latitude == 0 && arr.longitude == 0) return -1;

      return _haversineDistance(dep.latitude, dep.longitude, arr.latitude, arr.longitude);
    } catch (e) {
      return -1;
    }
  }

  // 시간 파싱 헬퍼 (다양한 포맷 지원 강화)
  int _getDurationValue(FlightLog flight) {
    if (flight.duration == null || flight.duration!.isEmpty) return -1;

    String d = flight.duration!.trim();

    try {
      // 1. "HH:MM" 형식
      if (d.contains(':')) {
        final parts = d.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0].trim()) ?? 0;
          final m = int.tryParse(parts[1].trim()) ?? 0;
          final total = h * 60 + m;
          return total > 0 ? total : -1;
        }
      }

      // 2. "Xh Ym" 형식
      if (d.toLowerCase().contains('h') || d.toLowerCase().contains('m')) {
        int h = 0;
        int m = 0;

        final hMatch = RegExp(r'(\d+)\s*h', caseSensitive: false).firstMatch(d);
        if (hMatch != null) {
          h = int.parse(hMatch.group(1)!);
        }

        final mMatch = RegExp(r'(\d+)\s*m', caseSensitive: false).firstMatch(d);
        if (mMatch != null) {
          m = int.parse(mMatch.group(1)!);
        }

        final total = h * 60 + m;
        return total > 0 ? total : -1;
      }

      // 3. 숫자만 있는 경우 (분 단위로 간주)
      final val = int.tryParse(d);
      if (val != null && val > 0) return val;

    } catch (e) {
      return -1;
    }

    return -1;
  }

  // 로컬 거리 통계 계산 (N/A 제외)
  Future<Map<String, double>> _calculateDistanceStatsLocally({
    DateTime? startDate,
    DateTime? endDate,
    required AirportProvider airportProvider,
    required AirlineProvider airlineProvider,
  }) async {
    double totalDistance = 0;
    int validCount = 0;

    for (var log in airlineProvider.allFlightLogs) {
      if (log.isCanceled || log.date == 'Unknown') continue;
      try {
        final logDate = DateTime.parse(log.date);
        if (startDate != null && logDate.isBefore(startDate)) continue;
        if (endDate != null && logDate.isAfter(endDate)) continue;
      } catch(e) { continue; }

      final distance = _getDistanceValue(log, airportProvider);
      if (distance > 0) {
        totalDistance += distance * log.times;
        validCount += log.times;
      }
    }

    double average = validCount > 0 ? totalDistance / validCount : 0;
    return {'total': totalDistance, 'average': average};
  }

  // 로컬 시간 통계 계산 (N/A 제외)
  Future<Map<String, double>> _calculateDurationStatsLocally({
    DateTime? startDate,
    DateTime? endDate,
    required AirlineProvider airlineProvider,
  }) async {
    double totalMinutes = 0;
    int validCount = 0;

    for (var log in airlineProvider.allFlightLogs) {
      if (log.isCanceled || log.date == 'Unknown') continue;
      try {
        final logDate = DateTime.parse(log.date);
        if (startDate != null && logDate.isBefore(startDate)) continue;
        if (endDate != null && logDate.isAfter(endDate)) continue;
      } catch (e) { continue; }

      final minutes = _getDurationValue(log);
      if (minutes > 0) {
        totalMinutes += minutes * log.times;
        validCount += log.times;
      }
    }

    double average = validCount > 0 ? totalMinutes / validCount : 0;
    return {'total': totalMinutes / 60.0, 'average': (average / 60.0)};
  }

  // 로컬 Longest/Shortest Distance (N/A 제외)
  Future<Map<String, dynamic>> _findLongestShortestDistanceLocally({
    DateTime? startDate,
    DateTime? endDate,
    required AirportProvider airportProvider,
    required AirlineProvider airlineProvider,
  }) async {
    FlightLog? longest;
    FlightLog? shortest;
    double maxDist = -1;
    double minDist = double.infinity;

    for (var log in airlineProvider.allFlightLogs) {
      if (log.isCanceled || log.date == 'Unknown') continue;
      try {
        final logDate = DateTime.parse(log.date);
        if (startDate != null && logDate.isBefore(startDate)) continue;
        if (endDate != null && logDate.isAfter(endDate)) continue;
      } catch (e) { continue; }

      final dist = _getDistanceValue(log, airportProvider);
      if (dist <= 0) continue;

      if (dist > maxDist) {
        maxDist = dist;
        longest = log;
      }
      if (dist < minDist) {
        minDist = dist;
        shortest = log;
      }
    }

    if (minDist == double.infinity) shortest = null;

    return {'longest': longest, 'shortest': shortest};
  }

  // 로컬 Longest/Shortest Duration (N/A 제외)
  Future<Map<String, dynamic>> _findLongestShortestDurationLocally({
    DateTime? startDate,
    DateTime? endDate,
    required AirlineProvider airlineProvider,
  }) async {
    FlightLog? longest;
    FlightLog? shortest;
    int maxMin = -1;
    int minMin = 999999;

    for (var log in airlineProvider.allFlightLogs) {
      if (log.isCanceled || log.date == 'Unknown') continue;
      try {
        final logDate = DateTime.parse(log.date);
        if (startDate != null && logDate.isBefore(startDate)) continue;
        if (endDate != null && logDate.isAfter(endDate)) continue;
      } catch (e) { continue; }

      final mins = _getDurationValue(log);
      if (mins <= 0) continue;

      if (mins > maxMin) {
        maxMin = mins;
        longest = log;
      }
      if (mins < minMin) {
        minMin = mins;
        shortest = log;
      }
    }

    if (minMin == 999999) shortest = null;

    return {'longest': longest, 'shortest': shortest};
  }

  // ---------------------------------------------------------------------------

  void _fetchMostFrequentStats() {
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    setState(() {
      _mostFrequentFutures = {
        MostFrequentPeriod.day: airlineProvider.calculateMostFrequentPeriod(
          format: DateFormat('yyyy-MM-dd'),
        ),
        MostFrequentPeriod.week: airlineProvider.calculateMostFrequentPeriod(
          format: DateFormat('yyyy-ww'),
        ),
        MostFrequentPeriod.month: airlineProvider.calculateMostFrequentPeriod(
          format: DateFormat('yyyy-MM'),
        ),
        MostFrequentPeriod.year: airlineProvider.calculateMostFrequentPeriod(
          format: DateFormat('yyyy'),
        ),
      };
    });
  }

  void _fetchStats() {
    final now = DateTime.now();
    final startOfLast7Days = now.subtract(const Duration(days: 7));
    final startOfLast30Days = now.subtract(const Duration(days: 30));
    final startOfLast365Days = now.subtract(const Duration(days: 365));
    final startOfYear = DateTime(_interactiveYear, 1, 1);
    final endOfYear = DateTime(_interactiveYear, 12, 31, 23, 59, 59);

    final airportProvider = Provider.of<AirportProvider>(context, listen: false);
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);

    setState(() {
      _distanceStatsFutures = {
        'Last 7 Days': _calculateDistanceStatsLocally(startDate: startOfLast7Days, endDate: now, airportProvider: airportProvider, airlineProvider: airlineProvider),
        'Last 30 Days': _calculateDistanceStatsLocally(startDate: startOfLast30Days, endDate: now, airportProvider: airportProvider, airlineProvider: airlineProvider),
        'Last 365 Days': _calculateDistanceStatsLocally(startDate: startOfLast365Days, endDate: now, airportProvider: airportProvider, airlineProvider: airlineProvider),
        '$_interactiveYear': _calculateDistanceStatsLocally(startDate: startOfYear, endDate: endOfYear, airportProvider: airportProvider, airlineProvider: airlineProvider),
        'All Time': _calculateDistanceStatsLocally(airportProvider: airportProvider, airlineProvider: airlineProvider),
      };

      _durationStatsFutures = {
        'Last 7 Days': _calculateDurationStatsLocally(startDate: startOfLast7Days, endDate: now, airlineProvider: airlineProvider),
        'Last 30 Days': _calculateDurationStatsLocally(startDate: startOfLast30Days, endDate: now, airlineProvider: airlineProvider),
        'Last 365 Days': _calculateDurationStatsLocally(startDate: startOfLast365Days, endDate: now, airlineProvider: airlineProvider),
        '$_interactiveYear': _calculateDurationStatsLocally(startDate: startOfYear, endDate: endOfYear, airlineProvider: airlineProvider),
        'All Time': _calculateDurationStatsLocally(airlineProvider: airlineProvider),
      };

      _countStatsFutures = {
        'Last 7 Days': airlineProvider.calculateFlightCountStats(startDate: startOfLast7Days, endDate: now),
        'Last 30 Days': airlineProvider.calculateFlightCountStats(startDate: startOfLast30Days, endDate: now),
        'Last 365 Days': airlineProvider.calculateFlightCountStats(startDate: startOfLast365Days, endDate: now),
        '$_interactiveYear': airlineProvider.calculateFlightCountStats(startDate: startOfYear, endDate: endOfYear),
        'All Time': airlineProvider.calculateFlightCountStats(),
      };
    });
  }

  void _fetchLongestShortestStatsForPeriod(LongestShortestPeriod period) {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate = now;

    switch (period) {
      case LongestShortestPeriod.day:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case LongestShortestPeriod.week:
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case LongestShortestPeriod.month:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case LongestShortestPeriod.year:
        startDate = DateTime(_longestShortestSelectedYear, 1, 1);
        endDate = DateTime(_longestShortestSelectedYear, 12, 31, 23, 59, 59);
        break;
      case LongestShortestPeriod.allTime:
        startDate = null;
        endDate = null;
        break;
    }

    final airportProvider = Provider.of<AirportProvider>(context, listen: false);
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);

    setState(() {
      _longestShortestDistanceFutures = {
        'All Time': _findLongestShortestDistanceLocally(startDate: startDate, endDate: endDate, airportProvider: airportProvider, airlineProvider: airlineProvider),
      };
      _longestShortestDurationFutures = {
        'All Time': _findLongestShortestDurationLocally(startDate: startDate, endDate: endDate, airlineProvider: airlineProvider),
      };
      _longestShortestCountFutures = {
        'All Time': airlineProvider.findLongestShortestFlightByCount(startDate: startDate, endDate: endDate),
      };
    });
  }

  void _fetchYearlyTrendData() {
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);
    setState(() {
      _yearlyTrendFuture = _calculateYearlyTrendData(
        airlineProvider: airlineProvider,
        airportProvider: airportProvider,
      );
    });
  }

  Future<Map<String, dynamic>> _calculateYearlyTrendData({
    required AirlineProvider airlineProvider,
    required AirportProvider airportProvider,
  }) async {
    final allLogs = airlineProvider.allFlightLogs;
    final currentYear = DateTime.now().year;
    final startYear = currentYear - 9; // 최근 10년

    // 초기화 맵
    final Map<int, double> yearlyDistance = {};
    final Map<int, double> yearlyDuration = {}; // Minutes
    final Map<int, int> yearlyCount = {};

    for (int year = startYear; year <= currentYear; year++) {
      yearlyDistance[year] = 0.0;
      yearlyDuration[year] = 0.0;
      yearlyCount[year] = 0;
    }

    for (var log in allLogs) {
      if (log.isCanceled || log.date == 'Unknown') continue;

      try {
        final logDate = DateTime.parse(log.date);
        final year = logDate.year;

        if (year >= startYear && year <= currentYear) {
          // 1. Distance Calculation (N/A excluded)
          final distance = _getDistanceValue(log, airportProvider);
          if (distance > 0) {
            yearlyDistance[year] = (yearlyDistance[year] ?? 0.0) + distance * log.times;
          }

          // 2. Duration Calculation (N/A excluded)
          final minutes = _getDurationValue(log);
          if (minutes > 0) {
            yearlyDuration[year] = (yearlyDuration[year] ?? 0.0) + minutes * log.times;
          }

          // 3. Count Calculation
          yearlyCount[year] = (yearlyCount[year] ?? 0) + log.times;
        }
      } catch (e) {
        continue;
      }
    }

    final List<Map<String, dynamic>> yearData = [];
    for (int year = startYear; year <= currentYear; year++) {
      yearData.add({
        'year': year,
        'count': yearlyCount[year] ?? 0,
        'distance': yearlyDistance[year] ?? 0.0,
        'duration': (yearlyDuration[year] ?? 0.0) / 60.0, // Minutes to Hours
      });
    }

    return {'yearData': yearData};
  }

  List<Widget> _buildStatsList() {
    Map<String, Future<Map<String, double>>> currentFutures;
    bool showAverage;

    if (_selectedStatType == StatType.distance) {
      currentFutures = _distanceStatsFutures;
      showAverage = _showAverageDistance;
    } else if (_selectedStatType == StatType.duration) {
      currentFutures = _durationStatsFutures;
      showAverage = _showAverageDuration;
    } else {
      currentFutures = _countStatsFutures;
      showAverage = _showAverageCount;
    }

    final keys = [
      'Last 7 Days',
      'Last 30 Days',
      'Last 365 Days',
      '$_interactiveYear',
      'All Time',
    ];

    final icons = [
      Icons.calendar_today,
      Icons.date_range,
      Icons.event_note,
      Icons.calendar_view_month,
      Icons.all_inclusive,
    ];

    return List.generate(keys.length, (index) {
      final key = keys[index];
      final icon = icons[index];
      final future = currentFutures[key];

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _buildStatRow(
          period: key,
          icon: icon,
          future: future!,
          showAverage: showAverage,
        ),
      );
    });
  }

  Widget _buildStatRow({
    required String period,
    required IconData icon,
    required Future<Map<String, double>> future,
    required bool showAverage,
  }) {
    return FutureBuilder<Map<String, double>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.red.shade300),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          );
        } else if (snapshot.hasData) {
          final value = showAverage ? snapshot.data!['average']! : snapshot.data!['total']!;
          String formattedValue;

          if (_selectedStatType == StatType.distance) {
            formattedValue = '${_formatDistance(value)} km';
          } else if (_selectedStatType == StatType.duration) {
            formattedValue = _formatDuration(value);
          } else {
            formattedValue = _formatCount(value, isAverage: showAverage);
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getStatTypeColor().withOpacity(0.05),
                  _getStatTypeColor().withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getStatTypeColor().withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatTypeColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: _getStatTypeColor()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Text(
                  formattedValue,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getStatTypeColor(),
                  ),
                ),
              ],
            ),
          );
        } else {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey.shade400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Text(
                  'No data',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildStatCategorySelector() {
    return Row(
      children: [
        _buildCategoryButton(
          label: 'Distance',
          icon: Icons.flight,
          isSelected: _selectedStatType == StatType.distance,
          onTap: () => setState(() {
            _selectedStatType = StatType.distance;
            _fetchYearlyTrendData();
          }),
          color: Colors.blue,
        ),
        const SizedBox(width: 8),
        _buildCategoryButton(
          label: 'Duration',
          icon: Icons.access_time,
          isSelected: _selectedStatType == StatType.duration,
          onTap: () => setState(() {
            _selectedStatType = StatType.duration;
            _fetchYearlyTrendData();
          }),
          color: Colors.purple,
        ),
        const SizedBox(width: 8),
        _buildCategoryButton(
          label: 'Count',
          icon: Icons.format_list_numbered,
          isSelected: _selectedStatType == StatType.count,
          onTap: () => setState(() {
            _selectedStatType = StatType.count;
            _fetchYearlyTrendData();
          }),
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildCategoryButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
              colors: [
                color,
                color.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isSelected ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl({
    required bool showAverage,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentButton(
            label: 'Total',
            isSelected: !showAverage,
            onTap: () => onChanged(false),
          ),
          _buildSegmentButton(
            label: 'Average',
            isSelected: showAverage,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildLongestShortestFlightCard({
    required String title,
    required Future<Map<String, dynamic>> future,
    required bool isCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.05),
            Theme.of(context).primaryColor.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.military_tech,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading data.',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  );
                } else if (snapshot.hasData) {
                  final longestFlight = snapshot.data!['longest'] as FlightLog?;
                  final shortestFlight = snapshot.data!['shortest'] as FlightLog?;

                  return Column(
                    children: [
                      if (longestFlight != null)
                        _buildFlightDetailCard(
                          label: 'Longest',
                          flight: longestFlight,
                          color: Colors.blue,
                          isCount: isCount,
                        ),
                      if (longestFlight != null && shortestFlight != null)
                        const SizedBox(height: 16),
                      if (shortestFlight != null)
                        _buildFlightDetailCard(
                          label: 'Shortest',
                          flight: shortestFlight,
                          color: Colors.orange,
                          isCount: isCount,
                        ),
                      if (longestFlight == null && shortestFlight == null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              'No flights in this period.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        ),
                    ],
                  );
                } else {
                  return Center(
                    child: Text(
                      'No data available.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightDetailCard({
    required String label,
    required FlightLog flight,
    required Color color,
    required bool isCount,
  }) {
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);
    final departureAirport = airportProvider.allAirports.firstWhere(
          (e) => e.iataCode == (flight.departureIata ?? ''),
      orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0),
    );
    final arrivalAirport = airportProvider.allAirports.firstWhere(
          (e) => e.iataCode == (flight.arrivalIata ?? ''),
      orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                flight.date != 'Unknown'
                    ? DateFormat('MMM d, y').format(DateTime.parse(flight.date))
                    : 'Unknown',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flight.departureIata ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flight_takeoff,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flight_land,
                  size: 16,
                  color: color,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      flight.arrivalIata ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (!isCount && _selectedStatType == StatType.distance) ...[
                  _buildInfoColumn(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: _calculateFlightDistance(flight, airportProvider),
                  ),
                ],
                if (!isCount && _selectedStatType == StatType.duration) ...[
                  _buildInfoColumn(
                    icon: Icons.access_time,
                    label: 'Duration',
                    value: flight.duration != null && flight.duration!.isNotEmpty
                        ? _formatDurationFromString(flight.duration!)
                        : 'N/A',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: LongestShortestPeriod.values.map((period) {
          final isSelected = _selectedLongestShortestPeriod == period;
          String label;
          switch (period) {
            case LongestShortestPeriod.day:
              label = 'Day';
              break;
            case LongestShortestPeriod.week:
              label = 'Week';
              break;
            case LongestShortestPeriod.month:
              label = 'Month';
              break;
            case LongestShortestPeriod.year:
              label = 'Year';
              break;
            case LongestShortestPeriod.allTime:
              label = 'All';
              break;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedLongestShortestPeriod = period;
                  _fetchLongestShortestStatsForPeriod(period);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMostFrequentPeriodCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.05),
            Theme.of(context).primaryColor.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Most Frequent Period',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildMostFrequentPeriodSelector(),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>>(
              future: _mostFrequentFutures[_selectedMostFrequentPeriod],
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading data.',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  );
                } else if (snapshot.hasData) {
                  final mostFrequent = snapshot.data!['most'] as MapEntry<String, int>?;
                  final leastFrequent = snapshot.data!['least'] as MapEntry<String, int>?;

                  return Column(
                    children: [
                      if (mostFrequent != null)
                        _buildFrequencyCard(
                          label: 'Most Frequent',
                          period: _formatPeriodLabel(mostFrequent.key),
                          count: mostFrequent.value,
                          color: Colors.green,
                        ),
                      if (mostFrequent != null && leastFrequent != null)
                        const SizedBox(height: 16),
                      if (leastFrequent != null)
                        _buildFrequencyCard(
                          label: 'Least Frequent',
                          period: _formatPeriodLabel(leastFrequent.key),
                          count: leastFrequent.value,
                          color: Colors.deepOrange,
                        ),
                      if (mostFrequent == null && leastFrequent == null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              'No data available.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        ),
                    ],
                  );
                } else {
                  return Center(
                    child: Text(
                      'No data available.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyCard({
    required String label,
    required String period,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              label == 'Most Frequent' ? Icons.trending_up : Icons.trending_down,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  period,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'flights',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMostFrequentPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: MostFrequentPeriod.values.map((period) {
          final isSelected = _selectedMostFrequentPeriod == period;
          String label;
          switch (period) {
            case MostFrequentPeriod.day:
              label = 'Day';
              break;
            case MostFrequentPeriod.week:
              label = 'Week';
              break;
            case MostFrequentPeriod.month:
              label = 'Month';
              break;
            case MostFrequentPeriod.year:
              label = 'Year';
              break;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMostFrequentPeriod = period;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildYearlyTrendCard() {
    // 🚨 동적 값 키와 레이블 설정
    String valueKey;
    String yAxisUnit;
    int decimalPrecision = 0;

    if (_selectedStatType == StatType.distance) {
      valueKey = 'distance';
      yAxisUnit = 'km';
    } else if (_selectedStatType == StatType.duration) {
      valueKey = 'duration';
      yAxisUnit = 'hours';
      decimalPrecision = 0; // 🚨 수정: Duration 소수점 제거
    } else {
      valueKey = 'count';
      yAxisUnit = 'flights';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatTypeColor().withOpacity(0.05),
            _getStatTypeColor().withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatTypeColor().withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatTypeColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.insights,
                    color: _getStatTypeColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yearly Trend (${valueKey})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Last 10 Years',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>>(
              future: _yearlyTrendFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Error loading trend data.',
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                  );
                } else if (snapshot.hasData) {
                  final yearData = snapshot.data!['yearData'] as List<Map<String, dynamic>>;

                  // Calculate max Y value and appropriate interval
                  final double rawMaxValue = yearData.map((y) => y[valueKey].toDouble()).reduce((a, b) => max(a, b).toDouble());
                  final double niceInterval = _calculateNiceInterval(rawMaxValue);
                  final double maxY = (rawMaxValue / niceInterval).ceilToDouble() * niceInterval;

                  if (rawMaxValue == 0) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'No ${valueKey} data in the last 10 years',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: niceInterval,
                          getDrawingHorizontalLine: (value) {
                            if (value % niceInterval == 0) {
                              return FlLine(
                                color: Colors.grey.shade200,
                                strokeWidth: 1,
                              );
                            }
                            return FlLine(color: Colors.transparent);
                          },
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              interval: niceInterval,
                              getTitlesWidget: (value, meta) {

                                String text;

                                if (_selectedStatType == StatType.distance || _selectedStatType == StatType.count) {
                                  // Distance/Count: 정수 & 스케일링 적용
                                  text = _formatLargeNumber(value, precision: 0);
                                } else {
                                  // Duration: 정수 (소수점 제거)
                                  text = value.toStringAsFixed(0);
                                }

                                return Text(
                                  text,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              yearData.length,
                                  (index) => FlSpot(
                                index.toDouble(),
                                yearData[index][valueKey].toDouble(),
                              ),
                            ),
                            isCurved: true,
                            preventCurveOverShooting: true,
                            gradient: LinearGradient(
                              colors: [
                                _getStatTypeColor(),
                                _getStatTypeColor().withOpacity(0.7),
                              ],
                            ),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: _getStatTypeColor(),
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  _getStatTypeColor().withOpacity(0.15),
                                  _getStatTypeColor().withOpacity(0.05),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => _getStatTypeColor().withOpacity(0.9),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final year = yearData[spot.x.toInt()]['year'];
                                final value = yearData[spot.x.toInt()][valueKey];

                                String formattedValue;

                                if (_selectedStatType == StatType.distance || _selectedStatType == StatType.count) {
                                  // Distance/Count: 소수점 1자리까지 스케일링
                                  formattedValue = _formatLargeNumber(value, precision: 1);
                                } else {
                                  // Duration: 정수 (소수점 제거)
                                  formattedValue = value.toStringAsFixed(0);
                                }

                                return LineTooltipItem(
                                  '$year\n$formattedValue $yAxisUnit',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'No data available.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatPeriodLabel(String period) {
    try {
      if (period.contains('-') && period.length == 10) {
        final date = DateTime.parse(period);
        return DateFormat('MMM d, y').format(date);
      } else if (period.contains('-') && period.length == 7) {
        final parts = period.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        return DateFormat('MMM y').format(DateTime(year, month));
      } else if (period.length == 4) {
        return period;
      } else if (period.contains('-') && period.split('-')[1].length == 2) {
        final parts = period.split('-');
        final year = int.parse(parts[0]);
        final week = int.parse(parts[1]);
        final firstDayOfYear = DateTime(year, 1, 1);
        final daysToAdd = (week - 1) * 7;
        final weekDate = firstDayOfYear.add(Duration(days: daysToAdd));
        return 'Week ${week}, ${year}';
      }
    } catch (e) {
      return period;
    }
    return period;
  }

  String _formatDistance(double distance) {
    return distance.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  String _formatDuration(double duration) {
    final hours = duration.floor();
    final minutes = ((duration - hours) * 60).round();
    return '${hours}h ${minutes}m';
  }

  String _formatCount(double count, {required bool isAverage}) {
    if (isAverage) {
      return count.toStringAsFixed(1);
    } else {
      return count.toInt().toString();
    }
  }

  String _formatDurationFromString(String duration) {
    try {
      if (duration.contains(':')) {
        final parts = duration.split(':');
        if (parts.length >= 2) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = int.tryParse(parts[1]) ?? 0;
          return '${hours}h ${minutes}m';
        }
      }
      return duration;
    } catch (e) {
      return duration;
    }
  }

  String _calculateFlightDistance(FlightLog flight, AirportProvider airportProvider) {
    try {
      final departureAirport = airportProvider.allAirports.firstWhere(
            (e) => e.iataCode == (flight.departureIata ?? ''),
        orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0),
      );
      final arrivalAirport = airportProvider.allAirports.firstWhere(
            (e) => e.iataCode == (flight.arrivalIata ?? ''),
        orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0),
      );

      if (departureAirport.iataCode.isEmpty || arrivalAirport.iataCode.isEmpty) {
        return 'N/A';
      }

      final distance = _haversineDistance(
        departureAirport.latitude,
        departureAirport.longitude,
        arrivalAirport.latitude,
        arrivalAirport.longitude,
      );

      return '${_formatDistance(distance)} km';
    } catch (e) {
      return 'N/A';
    }
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;

        final airportProvider = Provider.of<AirportProvider>(context, listen: false);
        final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);

        _customDistanceStatsFuture = _calculateDistanceStatsLocally(
          startDate: _customStartDate,
          endDate: _customEndDate,
          airportProvider: airportProvider,
          airlineProvider: airlineProvider,
        );

        _customDurationStatsFuture = _calculateDurationStatsLocally(
          startDate: _customStartDate,
          endDate: _customEndDate,
          airlineProvider: airlineProvider,
        );

        _customCountStatsFuture = airlineProvider.calculateFlightCountStats(
          startDate: _customStartDate,
          endDate: _customEndDate,
        );

        _customLongestShortestDistanceFuture = _findLongestShortestDistanceLocally(
          airportProvider: airportProvider,
          startDate: _customStartDate,
          endDate: _customEndDate,
          airlineProvider: airlineProvider,
        );

        _customLongestShortestDurationFuture = _findLongestShortestDurationLocally(
          startDate: _customStartDate,
          endDate: _customEndDate,
          airlineProvider: airlineProvider,
        );

        _customLongestShortestCountFuture = airlineProvider.findLongestShortestFlightByCount(
          startDate: _customStartDate,
          endDate: _customEndDate,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatCategorySelector(),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedStatType.toString().split('.').last.substring(0, 1).toUpperCase() +
                                _selectedStatType.toString().split('.').last.substring(1),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildSegmentedControl(
                            showAverage: (_selectedStatType == StatType.distance)
                                ? _showAverageDistance
                                : (_selectedStatType == StatType.duration
                                ? _showAverageDuration
                                : _showAverageCount),
                            onChanged: (value) {
                              setState(() {
                                if (_selectedStatType == StatType.distance) {
                                  _showAverageDistance = value;
                                } else if (_selectedStatType == StatType.duration) {
                                  _showAverageDuration = value;
                                } else {
                                  _showAverageCount = value;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        children: _buildStatsList(),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.date_range,
                              color: Theme.of(context).primaryColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Custom Date Range',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectDateRange,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            foregroundColor: Theme.of(context).primaryColor,
                          ),
                          child: const Text(
                            'Select Date Range',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_customStartDate != null && _customEndDate != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${DateFormat('MMM d, y').format(_customStartDate!)} - ${DateFormat('MMM d, y').format(_customEndDate!)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_selectedStatType == StatType.distance)
                                FutureBuilder<Map<String, double>>(
                                  future: _customDistanceStatsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    } else if (snapshot.hasError) {
                                      return Text(
                                        'Error loading data.',
                                        style: TextStyle(color: Colors.red.shade600),
                                      );
                                    } else if (snapshot.hasData) {
                                      final value = _showAverageDistance
                                          ? snapshot.data!['average']!
                                          : snapshot.data!['total']!;
                                      return Text(
                                        '${_formatDistance(value)} km',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      );
                                    } else {
                                      return Text(
                                        'No data for this date range.',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      );
                                    }
                                  },
                                ),
                              if (_selectedStatType == StatType.duration)
                                FutureBuilder<Map<String, double>>(
                                  future: _customDurationStatsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    } else if (snapshot.hasError) {
                                      return Text(
                                        'Error loading data.',
                                        style: TextStyle(color: Colors.red.shade600),
                                      );
                                    } else if (snapshot.hasData) {
                                      final value = _showAverageDuration
                                          ? snapshot.data!['average']!
                                          : snapshot.data!['total']!;
                                      final formattedValue = _formatDuration(value);
                                      return Text(
                                        formattedValue,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      );
                                    } else {
                                      return Text(
                                        'No data for this date range.',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      );
                                    }
                                  },
                                ),
                              if (_selectedStatType == StatType.count)
                                FutureBuilder<Map<String, double>>(
                                  future: _customCountStatsFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    } else if (snapshot.hasError) {
                                      return Text(
                                        'Error loading data.',
                                        style: TextStyle(color: Colors.red.shade600),
                                      );
                                    } else if (snapshot.hasData) {
                                      final value =
                                      _showAverageCount ? snapshot.data!['average']! : snapshot.data!['total']!;
                                      final formattedValue = _formatCount(value, isAverage: _showAverageCount);
                                      return Text(
                                        '$formattedValue flights',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      );
                                    } else {
                                      return Text(
                                        'No data for this date range.',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedStatType == StatType.distance)
                Builder(
                  builder: (context) {
                    final future = _longestShortestDistanceFutures['All Time'];
                    if (future == null) {
                      return const SizedBox.shrink();
                    }
                    return _buildLongestShortestFlightCard(
                      title: 'Longest & Shortest Flights',
                      future: future,
                      isCount: false,
                    );
                  },
                ),
              if (_selectedStatType == StatType.duration)
                Builder(
                  builder: (context) {
                    final future = _longestShortestDurationFutures['All Time'];
                    if (future == null) {
                      return const SizedBox.shrink();
                    }
                    return _buildLongestShortestFlightCard(
                      title: 'Longest & Shortest Flights',
                      future: future,
                      isCount: false,
                    );
                  },
                ),
              if (_selectedStatType == StatType.count) _buildMostFrequentPeriodCard(),
              const SizedBox(height: 16),
              _buildYearlyTrendCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}