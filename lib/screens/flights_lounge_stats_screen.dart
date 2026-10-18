// lib/screens/flights_lounge_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/airport_visit_entry.dart';

// 랭킹 정렬 기준을 위한 Enum 타입 정의
enum LoungeSortType { mostVisits, rate, duration, avgRating, highestRating }

class LoungeStatsScreen extends StatefulWidget {
  const LoungeStatsScreen({super.key});

  @override
  State<LoungeStatsScreen> createState() => _LoungeStatsScreenState();
}

class _LoungeStatsScreenState extends State<LoungeStatsScreen> {
  final Color _themeColor = Colors.red.shade800; // 와인색 테마
  String _selectedPeriod = 'All Time';
  final List<String> _periods = ['30 Days', '365 Days', 'Year', 'All Time', 'Custom'];
  int _selectedYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  LoungeSortType _sortType = LoungeSortType.mostVisits;

  List<Map<String, dynamic>> _processedData = [];
  List<Map<String, dynamic>> _loungeVisitsInPeriod = [];
  int _totalAirportVisitsInPeriod = 0;
  int _totalLoungeDurationInPeriod = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareData();
  }

  void _prepareData() {
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);

    // 1. 기간에 해당하는 전체 공항 방문 기록 필터링
    final allVisitsInPeriod = airportProvider.allAirports.expand((airport) {
      return airportProvider.getVisitEntries(airport.iataCode)
          .map((entry) => {'airport': airport, 'entry': entry});
    }).where((visit) {
      final date = (visit['entry'] as AirportVisitEntry).date;
      if (date == null) return _selectedPeriod == 'All Time';

      DateTime? startDate, endDate;
      final now = DateTime.now();
      switch (_selectedPeriod) {
        case '30 Days': startDate = now.subtract(const Duration(days: 30)); endDate = now; break;
        case '365 Days': startDate = now.subtract(const Duration(days: 365)); endDate = now; break;
        case 'Year': startDate = DateTime(_selectedYear, 1, 1); endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59); break;
        case 'Custom': startDate = _customStartDate; endDate = _customEndDate; break;
        case 'All Time': return true;
      }
      if (startDate == null || endDate == null) return true;
      return !(date.isBefore(startDate) || date.isAfter(endDate));
    }).toList();

    // 2. 라운지 방문 기록만 필터링
    final loungeVisits = allVisitsInPeriod.where((v) => (v['entry'] as AirportVisitEntry).isLoungeUsed).toList();

    // 3. 로그 목록을 위해 시간순으로 정렬
    loungeVisits.sort((a, b) {
      final dateA = (a['entry'] as AirportVisitEntry).date;
      final dateB = (b['entry'] as AirportVisitEntry).date;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA); // 최신순
    });

    // 4. 공항별로 방문 기록 집계
    final Map<String, Map<String, dynamic>> aggregation = {};
    for (var visit in allVisitsInPeriod) {
      final airport = visit['airport'] as Airport;
      final entry = visit['entry'] as AirportVisitEntry;
      final key = airport.iataCode;

      aggregation.putIfAbsent(key, () => {
        'airportObject': airport,
        'allVisits': <AirportVisitEntry>[],
      });
      aggregation[key]!['allVisits'].add(entry);
    }

    // 5. 집계된 데이터를 최종 통계용 리스트로 가공
    List<Map<String, dynamic>> processed = [];
    int globalTotalDuration = 0;

    aggregation.forEach((iata, data) {
      final airport = data['airportObject'] as Airport;
      final allVisits = data['allVisits'] as List<AirportVisitEntry>;
      final loungeVisitsForAirport = allVisits.where((v) => v.isLoungeUsed).toList();

      if (loungeVisitsForAirport.isEmpty) return;

      final visitCount = loungeVisitsForAirport.length;
      final totalVisits = allVisits.length;
      final rate = totalVisits > 0 ? (visitCount / totalVisits) : 0.0;

      final totalDuration = loungeVisitsForAirport.fold<int>(0, (sum, v) => sum + (v.loungeDurationInMinutes ?? 0));
      globalTotalDuration += totalDuration;

      final ratedVisits = loungeVisitsForAirport.where((v) => v.loungeRating != null && v.loungeRating! > 0).toList();
      final avgRating = ratedVisits.isEmpty ? 0.0 : ratedVisits.fold<double>(0.0, (sum, v) => sum + v.loungeRating!) / ratedVisits.length;

      AirportVisitEntry? highestRatedVisit;
      if (ratedVisits.isNotEmpty) {
        highestRatedVisit = ratedVisits.reduce((a, b) => (a.loungeRating ?? 0) > (b.loungeRating ?? 0) ? a : b);
      }

      processed.add({
        'name': airport.name,
        'iata': airport.iataCode,
        'visitCount': visitCount,
        'rate': rate,
        'totalDuration': totalDuration,
        'avgRating': avgRating,
        'highestRatedVisit': highestRatedVisit,
      });
    });

    // 6. 현재 선택된 기준으로 랭킹 정렬
    processed.sort((a, b) {
      switch (_sortType) {
        case LoungeSortType.rate:
          return (b['rate'] as double).compareTo(a['rate'] as double);
        case LoungeSortType.duration:
          return (b['totalDuration'] as int).compareTo(a['totalDuration'] as int);
        case LoungeSortType.avgRating:
          return (b['avgRating'] as double).compareTo(a['avgRating'] as double);
        case LoungeSortType.highestRating:
          final ratingA = (a['highestRatedVisit'] as AirportVisitEntry?)?.loungeRating ?? 0.0;
          final ratingB = (b['highestRatedVisit'] as AirportVisitEntry?)?.loungeRating ?? 0.0;
          return ratingB.compareTo(ratingA);
        case LoungeSortType.mostVisits:
        default:
          return (b['visitCount'] as int).compareTo(a['visitCount'] as int);
      }
    });

    setState(() {
      _totalAirportVisitsInPeriod = allVisitsInPeriod.length;
      _loungeVisitsInPeriod = loungeVisits;
      _processedData = processed;
      _totalLoungeDurationInPeriod = globalTotalDuration;
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    int totalLoungeVisits = _loungeVisitsInPeriod.length;
    double totalAvgRating = 0;
    if(totalLoungeVisits > 0) {
      final totalRatingSum = _processedData.fold(0.0, (sum, item) => sum + ((item['avgRating'] as double) * (item['visitCount'] as int)));
      totalAvgRating = totalRatingSum / totalLoungeVisits;
    }

    // ⭐️ Scaffold와 AppBar를 제거하고 SingleChildScrollView만 리턴
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: _themeColor),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 24),
            _buildOverallStats(totalLoungeVisits, totalAvgRating, _totalAirportVisitsInPeriod, _totalLoungeDurationInPeriod),
            const SizedBox(height: 24),
            _buildRankingCard(),
            const SizedBox(height: 24),
            _buildLoungeLog(),
            const SizedBox(height: 24),
            _buildYearlyTrendCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() => Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedPeriod,
          decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
          items: _periods.map((String value) => DropdownMenuItem<String>(value: value, child: Text(tr(value)))).toList(),
          onChanged: (String? newValue) {
            if (newValue == 'Custom') { _showCustomDateRangePicker(); }
            else if (newValue != null) { setState(() { _selectedPeriod = newValue; }); _prepareData(); }
          },
        ),
        if (_selectedPeriod == 'Year')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => setState(() { _selectedYear--; _prepareData(); })),
              Text(tr('$_selectedYear'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => setState(() { _selectedYear++; _prepareData(); }))
            ]),
          ),
      ]
  );

  void _showCustomDateRangePicker() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (picked != null) {
      setState(() {
        _selectedPeriod = 'Custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _prepareData();
    }
  }

  Widget _buildOverallStats(int totalLoungeVisits, double avgRating, int totalAirportVisits, int totalDuration) {
    final ratio = totalAirportVisits > 0 ? (totalLoungeVisits / totalAirportVisits) * 100 : 0.0;
    final avgDuration = totalLoungeVisits > 0 ? totalDuration / totalLoungeVisits : 0.0;

    String formatDuration(double totalMinutes) {
      final hours = totalMinutes ~/ 60;
      final minutes = (totalMinutes % 60).round();
      return '${hours}h ${minutes}m';
    }

    Widget statItem(String title, String value, {Widget? icon}) {
      return Column(
        children: [
          Text(tr(title), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if(icon != null) ...[icon, const SizedBox(width: 8)],
              Text(tr(value), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _themeColor)),
            ],
          )
        ],
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                statItem('Total Visits', NumberFormat.compact().format(totalLoungeVisits)),
                statItem('Usage Rate', '${ratio.toStringAsFixed(1)}%'),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                statItem('Total Duration', formatDuration(totalDuration.toDouble())),
                statItem('Average Duration', formatDuration(avgDuration)),
              ],
            ),
            const Divider(height: 24),
            statItem('Average Rating', avgRating.toStringAsFixed(2), icon: Icon(Icons.wine_bar, color: _themeColor, size: 22)),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingCard() {
    String getSortTypeName(LoungeSortType type) {
      switch(type) {
        case LoungeSortType.mostVisits: return 'Most Visits';
        case LoungeSortType.rate: return 'Highest Rate';
        case LoungeSortType.duration: return 'Longest Duration';
        case LoungeSortType.avgRating: return 'Average Rating';
        case LoungeSortType.highestRating: return 'Highest Rating';
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<LoungeSortType>(
              value: _sortType,
              decoration: InputDecoration(
                filled: true,
                fillColor: _themeColor.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: LoungeSortType.values.map((type) {
                return DropdownMenuItem(value: type, child: Text(tr(getSortTypeName(type)), style: const TextStyle(fontWeight: FontWeight.bold)));
              }).toList(),
              onChanged: (type) {
                if (type != null) {
                  setState(() { _sortType = type; });
                  _prepareData();
                }
              },
            ),
            const Divider(height: 24),
            _processedData.isEmpty
                ?  SizedBox(height: 150, child: Center(child: Text(tr('No lounge visits in this period.'))))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(_processedData.length, 10),
              itemBuilder: (context, index) {
                return _buildRankItem(index, _processedData[index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankItem(int index, Map<String, dynamic> item) {
    String formatDuration(int totalMinutes) {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return '${hours}h ${minutes}m';
    }

    Widget trailing;
    switch(_sortType) {
      case LoungeSortType.rate:
        trailing = Text(tr('${((item['rate'] as double) * 100).toStringAsFixed(1)}%'), style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 16));
        break;
      case LoungeSortType.duration:
        trailing = Text(tr(formatDuration(item['totalDuration'])), style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 16));
        break;
      case LoungeSortType.avgRating:
        trailing = Row(children: [Icon(Icons.wine_bar, color: _themeColor, size: 18), Text(tr(' ${(item['avgRating'] as double).toStringAsFixed(2)}'), style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 16))]);
        break;
      case LoungeSortType.highestRating:
        final visit = item['highestRatedVisit'] as AirportVisitEntry?;
        String dateString = 'N/A';
        if (visit != null) {
          final year = visit.year?.toString() ?? '????';
          final month = visit.month?.toString().padLeft(2, '0') ?? '??';
          final day = visit.day?.toString().padLeft(2, '0') ?? '??';
          dateString = '$year-$month-$day';
        }
        trailing = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(children: [Icon(Icons.wine_bar, color: _themeColor, size: 18), Text(tr(' ${(visit?.loungeRating ?? 0).toStringAsFixed(1)}'), style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 16))]),
            Text(tr(dateString), style: Theme.of(context).textTheme.bodySmall)
          ],
        );
        break;
      case LoungeSortType.mostVisits:
      default:
        trailing = Text(tr('${item['visitCount']} Visits'), style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 16));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(tr('#${index + 1}'), style: const TextStyle(fontSize: 16, color: Colors.grey))),
          Expanded(child: Text(tr(item['name']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _buildLoungeLog() {
    if (_loungeVisitsInPeriod.isEmpty) return const SizedBox.shrink();

    String formatDuration(int? totalMinutes) {
      if (totalMinutes == null || totalMinutes == 0) return '-';
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return '${hours}h ${minutes}m';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr("Lounge Log"), style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _loungeVisitsInPeriod.length,
              itemBuilder: (context, index) {
                final visit = _loungeVisitsInPeriod[index];
                final airport = visit['airport'] as Airport;
                final entry = visit['entry'] as AirportVisitEntry;

                String dateString = 'Unknown Date';
                if (entry.date != null) {
                  final year = entry.year?.toString() ?? '????';
                  final month = entry.month?.toString().padLeft(2, '0') ?? '??';
                  final day = entry.day?.toString().padLeft(2, '0') ?? '??';
                  dateString = '$year-$month-$day';
                }

                return ListTile(
                  title: Text(airport.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(tr(dateString)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr(formatDuration(entry.loungeDurationInMinutes)), style: const TextStyle(color: Colors.black54)),
                      const SizedBox(width: 8),
                      Icon(Icons.wine_bar, color: _themeColor, size: 18),
                      Text(tr(' ${(entry.loungeRating ?? 0).toStringAsFixed(1)}'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyTrendCard() {
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);
    final int currentYear = DateTime.now().year;
    final int startYear = currentYear - 9;
    final Map<int, int> yearlyCounts = { for (var i = startYear; i <= currentYear; i++) i: 0 };

    airportProvider.allAirports.forEach((airport) {
      airportProvider.getVisitEntries(airport.iataCode)
          .where((entry) => entry.isLoungeUsed && entry.date != null && entry.date!.year >= startYear && entry.date!.year <= currentYear)
          .forEach((entry) {
        yearlyCounts[entry.date!.year] = (yearlyCounts[entry.date!.year] ?? 0) + 1;
      });
    });

    final spots = yearlyCounts.entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();
    final maxY = (yearlyCounts.values.fold(0, (prev, curr) => curr > prev ? curr : prev) * 1.25);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr("Yearly Trend"), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (v, m) => Text(tr(v.toInt().toString().substring(2))))),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) => Text(tr(value.toInt().toString())))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: startYear.toDouble(),
                  maxX: currentYear.toDouble(),
                  maxY: maxY < 10 ? 10 : maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: _themeColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: _themeColor.withOpacity(0.2)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}