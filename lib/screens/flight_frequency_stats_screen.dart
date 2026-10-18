// lib/screens/flight_frequency_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/models/airport_visit_entry.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:jidoapp/screens/add_flight_log_screen.dart';
import 'dart:math' as math;
import 'package:jidoapp/models/airport_model.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';


enum StatSource { flights, airports }

enum FrequencyChartType {
  year('Busiest Year', 'yyyy'),
  month('Busiest Month', 'MMMM'),
  dayOfWeek('Busiest Day of the Week', 'E'),
  hour('Busiest Time of Day', '');

  const FrequencyChartType(this.title, this.format);
  final String title;
  final String format;
}

enum DistributionType { duration, distance }

class FlightFrequencyStatsScreen extends StatefulWidget {
  const FlightFrequencyStatsScreen({super.key});

  @override
  State<FlightFrequencyStatsScreen> createState() =>
      _FlightFrequencyStatsScreenState();
}

class _FlightFrequencyStatsScreenState
    extends State<FlightFrequencyStatsScreen> {

  StatSource _selectedStatSource = StatSource.flights;
  FrequencyChartType _selectedChartType = FrequencyChartType.year;
  TimeType _selectedTimeType = TimeType.departure;
  DistributionType _selectedDistributionType = DistributionType.duration;
  bool _isLoading = true;

  // Frequency Stats
  Map<String, int> _chartData = {};
  String _mostFrequent = 'N/A';
  int _count = 0;

  // Distribution Stats
  Map<String, int> _durationData = {};
  Map<String, int> _distanceData = {};

  // Scatter Plot Stats
  List<FlightScatterPlotPoint> _scatterPlotData = [];
  FlightLog? _touchedFlightLog;

  // Streaks Stats
  late Map<String, Future<Map<String, dynamic>>> _streakDetailFutures;

  // UI Colors
  final Color _primaryColor = Colors.indigo.shade700;
  final Color _accentColor = Colors.orange.shade400;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);

    // Streaks 데이터 로드
    _streakDetailFutures = {
      'Monthly': airlineProvider.calculateLongestStreakByMonthWithPeriod(),
      'Yearly': airlineProvider.calculateLongestStreakByYearWithPeriod(),
    };


    Map<String, dynamic> stats;

    if (_selectedStatSource == StatSource.flights) {
      if (_selectedChartType == FrequencyChartType.hour) {
        stats = await airlineProvider.getHourlyFrequencyStats(timeType: _selectedTimeType);
      } else {
        stats = await airlineProvider.getFrequencyStats(_selectedChartType.format);
      }

      _durationData = await airlineProvider.getDurationDistributionStats();
      _distanceData = await airlineProvider.getDistanceDistributionStats(airportProvider: airportProvider);
      _scatterPlotData = await airlineProvider.getScatterPlotData(airportProvider: airportProvider);

    } else { // Airports
      final provider = Provider.of<AirportProvider>(context, listen: false);
      stats = await provider.getAirportFrequencyStats(_selectedChartType.format);
      // Clear flight-only data
      _durationData = {};
      _distanceData = {};
      _scatterPlotData = [];
      _touchedFlightLog = null;
    }

    if (mounted) {
      setState(() {
        _chartData = Map<String, int>.from(stats['distribution']);
        _mostFrequent = stats['most_frequent'];
        _count = stats['count'];
        _isLoading = false;
        _touchedFlightLog = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    // 🚨 [수정] 스크린 타이틀 헤더 제거 (AppBar 제거 후 추가했던 Padding 위젯도 제거)
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🚨 [제거] 상단 제목 Padding 위젯 제거됨

              if (_isLoading)
                Center(
                  heightFactor: 10,
                  child: CircularProgressIndicator(color: _primaryColor),
                )
              else ...[
                _buildStreaksCard(),
                const SizedBox(height: 16),
                _buildSourceSelector(),
                const SizedBox(height: 16),
                _buildDropdownSelector(),
                const SizedBox(height: 16),
                if (_selectedStatSource == StatSource.flights && _selectedChartType == FrequencyChartType.hour) ...[
                  _buildTimeTypeSelector(),
                  const SizedBox(height: 16),
                ],
                _buildStatCard(),
                if (_selectedStatSource == StatSource.flights) ...[
                  const SizedBox(height: 24),
                  _buildCombinedDistributionCard(),
                  const SizedBox(height: 24),
                  _buildScatterPlotCard(),
                  _buildScatterInfoPanel(),
                  const SizedBox(height: 24),
                  _buildMostFrequentRoutesCard(),
                ],
                const SizedBox(height: 24),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreaksCard() {
    return Card(
      elevation: 4.0, // 그림자 증가 (UI 강조)
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                tr('Flight Streaks'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _primaryColor.darken(0.1),
                ),
              ),
            ),
            const Divider(height: 20),
            _buildStreakDetailRow(
              title: 'Monthly Streak',
              future: _streakDetailFutures['Monthly']!,
              icon: Icons.calendar_month,
              iconColor: Colors.teal.shade500,
            ),
            const Divider(height: 1),
            _buildStreakDetailRow(
              title: 'Yearly Streak',
              future: _streakDetailFutures['Yearly']!,
              icon: Icons.calendar_today,
              iconColor: Colors.brown.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakDetailRow({
    required String title,
    required Future<Map<String, dynamic>> future,
    required IconData icon,
    required Color iconColor,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        Widget trailingWidget;
        Widget subtitleWidget = const SizedBox(height: 4);

        if (snapshot.connectionState == ConnectionState.waiting) {
          trailingWidget = SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: iconColor),
          );
        } else if (snapshot.hasError) {
          trailingWidget = const Icon(Icons.error_outline, color: Colors.red);
          subtitleWidget = Text(tr('Error'), style: textTheme.bodyMedium?.copyWith(color: Colors.red));
        } else if (snapshot.hasData) {
          final count = snapshot.data!['count'] ?? 0;
          final period = snapshot.data!['period'] as String?;

          trailingWidget = Text(
            tr('$count'),
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          );

          if (period != null && period.isNotEmpty && count > 0) {
            subtitleWidget = Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                tr('Longest: $period'),
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          } else {
            trailingWidget = Text(tr('0'), style: textTheme.headlineSmall?.copyWith(color: Colors.grey.shade400));
            subtitleWidget = Text(
              tr('No record'),
              style: textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
            );
          }
        } else {
          trailingWidget = Text(tr('0'), style: textTheme.headlineSmall?.copyWith(color: Colors.grey.shade400));
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          title: Text(
            tr(title),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: subtitleWidget,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: trailingWidget,
          ),
        );
      },
    );
  }


  Widget _buildSourceSelector() {
    return Center(
      child: SegmentedButton<StatSource>(
        // 🚨 [수정] 체크 표시 없애기: showSelectedIcon 명시 (기존 유지)
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: StatSource.flights, label:  Text(tr('Flights')), icon: const Icon(Icons.flight_takeoff)),
          ButtonSegment(value: StatSource.airports, label:  Text(tr('Airports')), icon: const Icon(Icons.connecting_airports)),
        ],
        selected: {_selectedStatSource},
        onSelectionChanged: (Set<StatSource> newSelection) {
          setState(() {
            _selectedStatSource = newSelection.first;
            if (_selectedStatSource == StatSource.airports && _selectedChartType == FrequencyChartType.hour) {
              _selectedChartType = FrequencyChartType.year;
            }
          });
          _loadData();
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: _getThemeColor().withOpacity(0.2),
          selectedForegroundColor: _getThemeColor().darken(0.3),
          backgroundColor: Colors.white,
          side: BorderSide(color: _getThemeColor().withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDropdownSelector() {
    final allTypes = FrequencyChartType.values;
    final availableTypes = _selectedStatSource == StatSource.airports
        ? allTypes.where((t) => t != FrequencyChartType.hour)
        : allTypes;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: DropdownButtonFormField<FrequencyChartType>(
        value: _selectedChartType,
        decoration: InputDecoration(
          labelText: tr('Analysis Type'),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(Icons.bar_chart, color: _getThemeColor()),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        items: availableTypes.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(tr(type.title), style: const TextStyle(fontWeight: FontWeight.w500)),
          );
        }).toList(),
        onChanged: (FrequencyChartType? newValue) {
          if (newValue != null) {
            setState(() => _selectedChartType = newValue);
            _loadData();
          }
        },
      ),
    );
  }

  Widget _buildTimeTypeSelector() {
    return Center(
      child: SegmentedButton<TimeType>(
        // 🚨 [수정] 체크 표시 없애기: showSelectedIcon 명시 (기존 유지)
        showSelectedIcon: false,
        segments:  [
          ButtonSegment(value: TimeType.departure, label: Text(tr('Departure')), icon: Icon(Icons.flight_takeoff)),
          ButtonSegment(value: TimeType.arrival, label: Text(tr('Arrival')), icon: Icon(Icons.flight_land)),
          ButtonSegment(value: TimeType.inFlight, label: Text(tr('In-Flight')), icon: Icon(Icons.airplanemode_active)),
        ],
        selected: {_selectedTimeType},
        onSelectionChanged: (Set<TimeType> newSelection) {
          setState(() => _selectedTimeType = newSelection.first);
          _loadData();
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: _getThemeColor().withOpacity(0.2),
          selectedForegroundColor: _getThemeColor().darken(0.3),
          backgroundColor: Colors.white,
          side: BorderSide(color: _getThemeColor().withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildStatCard() {
    final unit = _selectedStatSource == StatSource.flights ? 'flights' : 'visits';
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(_selectedChartType.title),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _primaryColor.darken(0.1),
              ),
            ),
            const SizedBox(height: 20),
            if (_count > 0)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: _getThemeColor().withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getThemeColor().withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.military_tech, color: _getThemeColor(), size: 24),
                    const SizedBox(width: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleMedium,
                        children: [
                          TextSpan(
                            text: tr('$_mostFrequent '),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getThemeColor().darken(0.2),
                              fontSize: 20,
                            ),
                          ),
                          TextSpan(
                            text: tr('($_count $unit)'),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(child: Text(tr("No data"), style: TextStyle(color: Colors.grey.shade600, fontSize: 18))),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _buildFrequencyBarChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedDistributionCard() {
    final isDuration = _selectedDistributionType == DistributionType.duration;
    final chartData = isDuration ? _durationData : _distanceData;
    final orderedKeys = isDuration
        ? ['~1h', '1–3h', '3–6h', '6–10h', '10–14h', '14h+']
        : ['~500km', '500-1,500km', '1,500-4,000km', '4,000-8,000km', '8,000-12,000km', '12,000km+'];


    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tr(isDuration ? 'Flight Duration Distribution' : 'Flight Distance Distribution'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _primaryColor.darken(0.1),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: DropdownButton<DistributionType>(
                    value: _selectedDistributionType,
                    underline: const SizedBox.shrink(),
                    icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
                    style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600, fontSize: 14),
                    items:  [
                      DropdownMenuItem(value: DistributionType.duration, child: Text(tr('Duration'), style: TextStyle(fontWeight: FontWeight.w500))),
                      DropdownMenuItem(value: DistributionType.distance, child: Text(tr('Distance'), style: TextStyle(fontWeight: FontWeight.w500))),
                    ],
                    onChanged: (DistributionType? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedDistributionType = newValue);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _buildGenericBarChart(
                chartData: chartData,
                orderedKeys: orderedKeys,
                barColor: isDuration ? Colors.teal.shade400 : Colors.indigo.shade400,
                yAxisUnit: 'flights',
                getCategoryLabel: (index, key) {
                  if (isDuration) {
                    return key.replaceAll('–', '-');
                  } else {
                    String formattedKey = key.replaceAll('km', '').replaceAll(',', '').trim();
                    if (formattedKey.startsWith('~')) {
                      return '~0.5k';
                    } else if (formattedKey.endsWith('+')) {
                      return '12k+';
                    } else if (formattedKey.contains('-')) {
                      final parts = formattedKey.split('-');
                      final start = (double.tryParse(parts[0]) ?? 0) / 1000;
                      final end = (double.tryParse(parts[1]) ?? 0) / 1000;
                      final startStr = start.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
                      final endStr = end.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
                      return '${startStr}-${endStr}k';
                    }
                    return key;
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScatterPlotCard() {
    double? maxXValue;
    double? maxYValue;

    if (_scatterPlotData.isNotEmpty) {
      maxXValue = _scatterPlotData.map((p) => p.durationMinutes).reduce((a, b) => a > b ? a : b);
      maxYValue = _scatterPlotData.map((p) => p.distanceKm).reduce((a, b) => a > b ? a : b);
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🚨 [수정] Scatter 제거
            Text(
              tr('Duration vs Distance'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _primaryColor.darken(0.1),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: _scatterPlotData.isEmpty
                  ? Center(child: Text(tr('No flight data for scatter plot.'), style: TextStyle(color: Colors.grey.shade600)))
                  : ScatterChart(
                ScatterChartData(
                  scatterSpots: _scatterPlotData.map((point) {
                    return ScatterSpot(
                      point.durationMinutes,
                      point.distanceKm,
                      dotPainter: FlDotCirclePainter(
                        radius: 5,
                        color: point.color,
                      ),
                    );
                  }).toList(),
                  minX: 0,
                  minY: 0,
                  maxX: maxXValue != null ? maxXValue * 1.1 : 360, // 10% 여유
                  maxY: maxYValue != null ? maxYValue * 1.1 : 10000,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget:  Text(tr('Distance (km)'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) {
                        if (value.toInt() % (meta.max ~/ 4) != 0 || value == meta.max || value == meta.min) return const SizedBox();
                        return Text(tr((value / 1000).toStringAsFixed(0) + 'k'), style: const TextStyle(fontSize: 10));
                      }),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget:  Text(tr('Duration (hours)'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 120, getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) return const SizedBox();
                        return Text(tr((value / 60).toStringAsFixed(0) + 'h'), style: const TextStyle(fontSize: 10));
                      }),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  scatterTouchData: ScatterTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchSpotThreshold: 16.0,
                      touchCallback: (event, response) {
                        if (event is FlTapDownEvent) {
                          if (response?.touchedSpot != null) {
                            final spotIndex = response!.touchedSpot!.spotIndex;
                            setState(() {
                              _touchedFlightLog = _scatterPlotData[spotIndex].flight;
                            });
                          } else {
                            setState(() {
                              _touchedFlightLog = null;
                            });
                          }
                        }
                      },
                      touchTooltipData: ScatterTouchTooltipData(
                        getTooltipItems: (touchedSpot) {
                          final foundPoint = _scatterPlotData.firstWhereOrNull(
                                  (p) => p.durationMinutes == touchedSpot.x && p.distanceKm == touchedSpot.y
                          );

                          if (foundPoint != null) {
                            return ScatterTooltipItem(
                              '${foundPoint.flight.airlineName ?? 'Unknown'} ${foundPoint.flight.flightNumber}\n${(foundPoint.durationMinutes / 60).toStringAsFixed(1)}h / ${foundPoint.distanceKm.toStringAsFixed(0)}km',
                              textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                            );
                          }
                          return null;
                        },
                      )
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildScatterInfoPanel() {
    if (_touchedFlightLog == null) {
      return const SizedBox.shrink();
    }
    final log = _touchedFlightLog!;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.flight_takeoff, color: _accentColor),
        title: Text(tr('${log.airlineName ?? 'Unknown'} ${log.flightNumber}'), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(tr('${log.date} / ${log.departureIata} → ${log.arrivalIata}')),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddFlightLogScreen(initialLog: log, isEditing: true)),
          );
        },
      ),
    );
  }

  Widget _buildMostFrequentRoutesCard() {
    return SizedBox(
      height: 500, // 높이 고정
      child: _MostFrequentRoutesCard(
        airlineProvider: Provider.of<AirlineProvider>(context, listen: false),
        airportProvider: Provider.of<AirportProvider>(context, listen: false),
        themeColor: _getThemeColor(),
      ),
    );
  }

  Widget _buildFrequencyBarChart() {
    return _buildGenericBarChart(
        chartData: _chartData,
        barColor: _getBarColor(),
        orderedKeys: _getOrderedKeys(),
        isTimeChart: _selectedChartType == FrequencyChartType.hour,
        yAxisUnit: _selectedStatSource == StatSource.flights ? 'flights' : 'visits',
        getCategoryLabel: (index, key) {
          switch(_selectedChartType) {
            case FrequencyChartType.year:
              return key.length > 2 ? key.substring(2) : key;
            case FrequencyChartType.month:
              return key.substring(0, 3);
            case FrequencyChartType.hour:
              if (index % 3 != 0) return null;
              return index.toString();
            default:
              return key;
          }
        }
    );
  }

  Widget _buildGenericBarChart({
    required Map<String, int> chartData,
    required Color barColor,
    List<String>? orderedKeys,
    bool isTimeChart = false,
    String? yAxisUnit,
    String? Function(int index, String key)? getCategoryLabel,
  }) {
    if (chartData.values.every((v) => v == 0)) {
      return Center(child: Text(tr('No data to display.'), style: TextStyle(color: Colors.grey.shade600)));
    }

    final keys = orderedKeys ?? chartData.keys.toList();

    final barGroups = List.generate(keys.length, (i) {
      final key = keys[i];
      final value = chartData[key] ?? 0;
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: value.toDouble(),
          color: barColor,
          width: isTimeChart ? 8 : 16,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: chartData.values.reduce(math.max).toDouble() * 1.25,
            color: barColor.withOpacity(0.1),
          ),
        )
      ]);
    });

    double maxY = chartData.values.fold(0.0, (max, v) => v > max ? v.toDouble() : max);
    maxY = (maxY * 1.25);
    if (maxY < 5) maxY = 5;
    final interval = (maxY / 5).ceilToDouble();
    if (interval == 0) {
      maxY = 5;
    } else {
      maxY = interval * 5;
    }


    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String key = keys[group.x.toInt()];
              String displayValue = rod.toY.toInt().toString();
              if (yAxisUnit != null) {
                displayValue += ' $yAxisUnit';
              }

              if (isTimeChart) {
                final hour = int.parse(key);
                final nextHour = (hour + 1) % 24;
                key = '${hour.toString().padLeft(2, '0')}:00~${nextHour.toString().padLeft(2, '0')}:00';
              }
              return BarTooltipItem(
                '$key\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                children: <TextSpan>[ TextSpan(text: tr(displayValue), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500))],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= keys.length) return const SizedBox();
                final key = keys[index];
                String? text = getCategoryLabel != null ? getCategoryLabel(index, key) : key;
                if (text == null) return const SizedBox();

                return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0,
                    child: Text(
                      tr(text),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                );
              },
              reservedSize: 38,
            ),
          ),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: interval > 0 ? interval : 1,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.max || value == meta.min) return const SizedBox();
                    return Text(
                      tr(value.toInt().toString()),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    );
                  }
              )
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 1,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
      ),
    );
  }

  MaterialColor _getThemeColor() {
    return _selectedStatSource == StatSource.flights ? Colors.indigo : Colors.green;
  }

  Color _getBarColor() {
    switch (_selectedChartType) {
      case FrequencyChartType.year: return Colors.amber.shade600;
      case FrequencyChartType.month: return Colors.cyan.shade600;
      case FrequencyChartType.dayOfWeek: return Colors.purple.shade600;
      case FrequencyChartType.hour: return Colors.orange.shade600;
    }
  }

  List<String> _getOrderedKeys() {
    switch (_selectedChartType) {
      case FrequencyChartType.year:
        if (_chartData.keys.isEmpty) return [];
        final years = _chartData.keys.map(int.parse).toList()..sort();
        return years.map((y) => y.toString()).toList();
      case FrequencyChartType.month:
        return const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      case FrequencyChartType.dayOfWeek:
        return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case FrequencyChartType.hour:
        return List.generate(24, (i) => i.toString());
    }
  }
}

// ⭐️ [신규] 가장 흔한 노선 랭킹 위젯
class _MostFrequentRoutesCard extends StatefulWidget {
  final AirlineProvider airlineProvider;
  final AirportProvider airportProvider;
  final MaterialColor themeColor;

  const _MostFrequentRoutesCard({
    required this.airlineProvider,
    required this.airportProvider,
    required this.themeColor,
  });

  @override
  State<_MostFrequentRoutesCard> createState() => _MostFrequentRoutesCardState();
}

class _MostFrequentRoutesCardState extends State<_MostFrequentRoutesCard> {
  int _selectedSegment = 0; // 0: By Airport, 1: By Country
  List<MapEntry<String, int>> _rankedAirportRoutes = [];
  List<MapEntry<String, int>> _rankedCountryRoutes = [];
  bool _didPrepareRankings = false;
  final Color _wineColor = Colors.red.shade800;
  Map<String, String> _countryNameToContinentMap = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrepareRankings) {
      _prepareRouteRankings();
      _didPrepareRankings = true;
    }
  }

  @override
  void didUpdateWidget(covariant _MostFrequentRoutesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.airlineProvider != oldWidget.airlineProvider || widget.airportProvider != oldWidget.airportProvider) {
      _prepareRouteRankings();
    }
  }

  void _prepareRouteRankings() {
    final allLogs = widget.airlineProvider.allFlightLogs;
    final iataToAirportMap = {for (var airport in widget.airportProvider.allAirports) airport.iataCode: airport};
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final countryCodeToNameMap = { for (var c in countryProvider.allCountries) c.isoA2: c.name }
      ..addAll({ for (var c in countryProvider.allCountries) c.isoA3: c.name });

    _countryNameToContinentMap = {
      for (var c in countryProvider.allCountries) if (c.continent != null) c.name: c.continent!
    };


    final Map<String, int> airportRouteCounts = {};
    final Map<String, int> countryRouteCounts = {};

    for (final log in allLogs) {
      if (log.departureIata == null || log.arrivalIata == null || log.isCanceled) continue;

      final depIata = log.departureIata!;
      final arrIata = log.arrivalIata!;

      if (depIata.isEmpty || arrIata.isEmpty || depIata == arrIata) continue;

      final depAirport = iataToAirportMap[depIata];
      final arrAirport = iataToAirportMap[arrIata];

      // Airport 랭킹에서 IATA 코드가 아닌 (예: 도시명) 항목 제외
      if (depIata.length == 3 && arrIata.length == 3 && depAirport != null && arrAirport != null) {
        final airportPair = [depIata, arrIata]..sort();
        final airportRouteKey = airportPair.join('-');
        airportRouteCounts[airportRouteKey] = (airportRouteCounts[airportRouteKey] ?? 0) + 1;
      }


      if (depAirport != null && arrAirport != null) {
        final depCountryCode = depAirport.country;
        final arrCountryCode = arrAirport.country;

        final depCountry = countryCodeToNameMap[depCountryCode] ?? depCountryCode;
        final arrCountry = countryCodeToNameMap[arrCountryCode] ?? arrCountryCode;


        if (depCountry == arrCountry) continue; // 국내선 제외

        final countryPair = [depCountry, arrCountry]..sort();
        final countryRouteKey = countryPair.join('-');
        countryRouteCounts[countryRouteKey] = (countryRouteCounts[countryRouteKey] ?? 0) + 1;
      }
    }

    // setState를 호출하여 UI를 업데이트
    if(mounted) {
      setState(() {
        _rankedAirportRoutes = airportRouteCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        _rankedCountryRoutes = countryRouteCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final textTheme = Theme.of(context).textTheme;
    final displayList = _selectedSegment == 0 ? _rankedAirportRoutes : _rankedCountryRoutes;
    final iataToAirportMap = {for (var airport in widget.airportProvider.allAirports) airport.iataCode: airport};

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: widget.themeColor.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🚨 [수정] 제목을 Frequent Routes로 변경 (유지)
                Text(
                  tr('Frequent Routes'),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.themeColor.darken(0.1),
                  ),
                ),
                // 🚀 [수정] 스위치 디자인 개선
                _buildModernSegmentedControl(),
              ],
            ),
          ),
          Expanded(
            child: displayList.isEmpty
                ? Center(
              child: Text(
                tr('No route data available.'),
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: math.min(displayList.length, 20),
              itemBuilder: (context, index) {
                final entry = displayList[index];
                final routeKey = entry.key;
                final count = entry.value;
                final rank = index + 1;

                Widget title;

                if (_selectedSegment == 0) { // Airport
                  final iatas = routeKey.split('-');
                  final airport1 = iataToAirportMap[iatas[0]];
                  final airport2 = iataToAirportMap[iatas[1]];

                  Widget buildTappableIata(Airport? airport, String iata) {
                    return InkWell(
                      onTap: airport == null ? null : () {
                        _showAirportDetailsInModal(context, airport);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 6.0),
                        child: Text(
                          iata,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: widget.themeColor.darken(0.1),
                          ),
                        ),
                      ),
                    );
                  }

                  // 🚨 [수정] Airport 텍스트 레이아웃 및 정렬 개선 (유지)
                  title = Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildTappableIata(airport1, iatas[0]),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(Icons.swap_horiz, color: Colors.grey.shade500, size: 20),
                      ),
                      buildTappableIata(airport2, iatas[1]),
                    ],
                  );

                } else { // Country
                  final countries = routeKey.split('-');
                  final country1 = countries[0];
                  final country2 = countries[1];

                  final countryProvider = Provider.of<CountryProvider>(context, listen: false);
                  final continentColors = countryProvider.continentColors;

                  final continent1 = _countryNameToContinentMap[country1] ?? '';
                  final continent2 = _countryNameToContinentMap[country2] ?? '';

                  final color1 = continentColors[continent1] ?? Colors.grey.shade700;
                  final color2 = continentColors[continent2] ?? Colors.grey.shade700;

                  // 🚨 [수정] Country 텍스트 레이아웃 및 기호 개선
                  title = Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr(country1),
                        // 🚨 [수정] 글씨 작게 만들기: fontSize를 14로 명시
                        style: textTheme.titleMedium?.copyWith(fontSize: 14, color: color1, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        // 🚨 [수정] Country 간 구분 기호를 아이콘으로 변경 (유지)
                        child: Icon(Icons.swap_horiz, color: Colors.grey.shade500, size: 20),
                      ),
                      Text(
                        tr(country2),
                        // 🚨 [수정] 글씨 작게 만들기: fontSize를 14로 명시
                        style: textTheme.titleMedium?.copyWith(fontSize: 14, color: color2, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                }

                // 🚨 [UI 개선] 리스트 항목 디자인 최종 개선
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0), // 패딩 유지
                  decoration: BoxDecoration(
                    color: Colors.white, // 배경색 고정
                    borderRadius: BorderRadius.circular(12), // 모서리 둥글게
                    border: Border.all(color: widget.themeColor.withOpacity(0.15), width: 1.0), // 테두리 색상 적용
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04), // 그림자 강화
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // 랭킹 번호 디자인
                      Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [widget.themeColor.shade400, widget.themeColor.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            tr('#$rank'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: Center(child: title)),
                      // 카운트 배지 디자인
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.themeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tr('$count'),
                          style: textTheme.titleMedium?.copyWith(
                            color: widget.themeColor.darken(0.2),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 [신규] 개선된 Segmented Control 위젯
  Widget _buildModernSegmentedControl() {
    // 0: Airport, 1: Country
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: widget.themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ToggleButtons(
        isSelected: [_selectedSegment == 0, _selectedSegment == 1],
        onPressed: (index) {
          setState(() {
            _selectedSegment = index;
          });
        },
        constraints: const BoxConstraints(minHeight: 30.0, minWidth: 65.0),
        renderBorder: false,
        borderRadius: BorderRadius.circular(20),
        // 🚨 [수정] 기본 그림자, 채우기 색상 제거 (투명 처리)
        fillColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        children: [
          _buildSegmentButton('Airport', 0),
          _buildSegmentButton('Country', 1),
        ],
      ),
    );
  }

  // 🚀 [신규] Segmented Control의 개별 버튼 위젯
  Widget _buildSegmentButton(String text, int value) {
    final isSelected = _selectedSegment == value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? widget.themeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          tr(text),
          style: TextStyle(
            color: isSelected ? Colors.white : widget.themeColor.darken(0.2),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  // --- Start: Methods copied from airports_screen.dart (Not modified for logic, only for potential UI/style consistency) ---

  void _showAirportDetailsInModal(BuildContext context, Airport airport) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext sheetContext) {
        return Consumer<AirportProvider>(
          builder: (context, provider, child) {
            final useCount = provider.getVisitCount(airport.iataCode);
            final isHub = provider.isHub(airport.iataCode);

            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Column(
                children: [
                  Container(
                    color: widget.themeColor.shade800,
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 8, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child:  Text(tr('Cancel'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child:  Text(tr('Done'), style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: widget.themeColor.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('${airport.name} (${airport.iataCode})'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          tr('${airport.country} | Uses: $useCount | Hub: ${isHub ? 'Yes' : 'No'}'),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildUseDetails(context, airport, provider),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUseDetails(BuildContext context, Airport airport, AirportProvider provider) {
    final uses = provider.getVisitEntries(airport.iataCode);
    final currentRating = provider.getRating(airport.iataCode);
    final isHub = provider.isHub(airport.iataCode);
    final loungeVisitCount = provider.getLoungeVisitCount(airport.iataCode);
    final averageLoungeRating = provider.getAverageLoungeRating(airport.iataCode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 8),
                   Text(tr('My Hub')),
                  Checkbox(
                    value: isHub,
                    onChanged: (bool? value) {
                      provider.updateHubStatus(airport.iataCode, value ?? false);
                    },
                  ),
                ],
              ),
              const Divider(height: 10),
              Row(
                children: [
                  Icon(Icons.wine_bar, color: _wineColor),
                  const SizedBox(width: 8),
                  Text(tr('Business Lounge: $loungeVisitCount Visits')),
                ],
              ),
              if (loungeVisitCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 8.0),
                  child: Row(
                    children: [
                      Text(tr('Average Rating: '), style: Theme.of(context).textTheme.bodySmall),
                      Icon(Icons.wine_bar, color: _wineColor, size: 20),
                      Text(
                        tr(' (${averageLoungeRating.toStringAsFixed(1)})'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 20),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('My Rating'), style: Theme.of(context).textTheme.titleSmall),
              IconButton(
                icon: const Icon(Icons.note_alt_outlined, color: Colors.grey),
                onPressed: () => _showMemoAndPhotoDialog(context, airport.iataCode),
                tooltip: tr('Add Memo and Photos'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: currentRating,
            minRating: 0,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemSize: 28.0,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => Icon(
              Icons.airplanemode_active,
              color: widget.themeColor,
            ),
            onRatingUpdate: (rating) {
              provider.updateRating(airport.iataCode, rating);
            },
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('History (${uses.length} uses)'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label:  Text(tr('Add Use')),
                onPressed: () {
                  provider.addVisitEntry(airport.iataCode);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (uses.isNotEmpty)
            ...uses.asMap().entries.map((entry) {
              final index = entry.key;
              final use = entry.value;
              final dateText = (use.year?.toString() ?? '????') +
                  '/' +
                  (use.month?.toString().padLeft(2, '0') ?? '??') +
                  '/' +
                  (use.day?.toString().padLeft(2, '0') ?? '??');

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateSection(context, use, index, provider),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                tr('#${index + 1}: '),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                tr(dateText),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.note_alt_outlined, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showMemoAndPhotoDialog(context, airport.iataCode, useIndex: index + 1),
                                tooltip: tr('Add Memo for this Use'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                tooltip: tr('Remove this use'),
                                onPressed: () {
                                  provider.removeVisitEntry(airport.iataCode, index);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title:  Text(tr('Transfer'), style: TextStyle(fontSize: 11)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isTransfer,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isTransfer: value);
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title:  Text(tr('Layover'), style: TextStyle(fontSize: 11)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isLayover,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isLayover: value);
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title:  Text(tr('Stopover'), style: TextStyle(fontSize: 11)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isStopover,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isStopover: value);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const VerticalDivider(),
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 30,
                                  child: Transform.scale(
                                    scale: 0.9,
                                    alignment: Alignment.centerLeft,
                                    child: CheckboxListTile(
                                      title:  Text(tr('Lounge Use'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      secondary: Icon(Icons.wine_bar, color: _wineColor, size: 16),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      value: use.isLoungeUsed,
                                      onChanged: (bool? value) {
                                        provider.updateVisitEntry(airport.iataCode, index, isLoungeUsed: value);
                                      },
                                    ),
                                  ),
                                ),
                                if (use.isLoungeUsed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: RatingBar.builder(
                                                initialRating: use.loungeRating ?? 0.0,
                                                minRating: 0,
                                                direction: Axis.horizontal,
                                                allowHalfRating: true,
                                                itemCount: 5,
                                                itemSize: 20.0,
                                                itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
                                                itemBuilder: (context, _) => Icon(Icons.wine_bar, color: _wineColor),
                                                onRatingUpdate: (rating) {
                                                  provider.updateVisitEntry(airport.iataCode, index, loungeRating: rating);
                                                },
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.note_alt_outlined, color: Colors.grey, size: 20),
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _showMemoAndPhotoDialog(
                                                context,
                                                airport.iataCode,
                                                useIndex: index + 1,
                                                isForLounge: true,
                                              ),
                                              tooltip: tr('Add Lounge Memo & Photos for this visit'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Builder(
                                            builder: (context) {
                                              final totalMinutes = use.loungeDurationInMinutes ?? 0;
                                              final hours = totalMinutes ~/ 60;
                                              final minutes = totalMinutes % 60;
                                              final hourController = TextEditingController(text: hours == 0 ? '' : hours.toString());
                                              final minuteController = TextEditingController(text: minutes == 0 ? '' : minutes.toString());
                                              hourController.selection = TextSelection.fromPosition(TextPosition(offset: hourController.text.length));
                                              minuteController.selection = TextSelection.fromPosition(TextPosition(offset: minuteController.text.length));
                                              void updateDuration() {
                                                final h = int.tryParse(hourController.text) ?? 0;
                                                final m = int.tryParse(minuteController.text) ?? 0;
                                                final newTotalMinutes = (h * 60) + m;
                                                if (use.loungeDurationInMinutes != newTotalMinutes) {
                                                  provider.updateVisitEntry(
                                                    airport.iataCode,
                                                    index,
                                                    loungeDurationInMinutes: newTotalMinutes > 0 ? newTotalMinutes : null,
                                                  );
                                                }
                                              }
                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller: hourController,
                                                      textAlign: TextAlign.center,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                      decoration:  InputDecoration(labelText: tr('H'), isDense: true, border: OutlineInputBorder()),
                                                      onChanged: (_) => updateDuration(),
                                                    ),
                                                  ),
                                                   Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                                                    child: Text(tr(':'), style: TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                  Expanded(
                                                    child: TextFormField(
                                                      controller: minuteController,
                                                      textAlign: TextAlign.center,
                                                      keyboardType: TextInputType.number,
                                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                      decoration:  InputDecoration(labelText: tr('M'), isDense: true, border: OutlineInputBorder()),
                                                      onChanged: (_) => updateDuration(),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          if (uses.isEmpty)
             Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Center(child: Text(tr('No uses recorded yet. Press "Add Use" to start.'))),
            ),
        ],
      ),
    );
  }

  void _showMemoAndPhotoDialog(BuildContext context, String iataCode, {int? useIndex, bool isForLounge = false}) {
    final provider = Provider.of<AirportProvider>(context, listen: false);
    final isPerUseMemo = useIndex != null;
    String initialMemo = '';
    List<String> initialPhotos = [];
    if (isForLounge && isPerUseMemo) {
      final visitEntry = provider.getVisitEntries(iataCode)[useIndex - 1];
      initialMemo = visitEntry.loungeMemo ?? '';
      initialPhotos = visitEntry.loungePhotos;
    } else if (isPerUseMemo) {
      initialMemo = 'Memo for use #$useIndex (Placeholder)';
      initialPhotos = [];
    } else {
      initialMemo = provider.getMemo(iataCode);
      initialPhotos = provider.getPhotos(iataCode);
    }
    final TextEditingController memoController = TextEditingController(text: initialMemo);
    List<String> currentPhotos = List.from(initialPhotos);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void _pickImage(ImageSource source) async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: source);
              if (pickedFile != null) {
                setStateDialog(() {
                  currentPhotos.add(pickedFile.path);
                });
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                   SnackBar(content: Text(tr('Photo selected and path saved.'))),
                );
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                   SnackBar(content: Text(tr('Image selection cancelled.'))),
                );
              }
            }
            return AlertDialog(
              title: Text(isForLounge && isPerUseMemo ? 'Lounge Memo & Photos for Visit #${useIndex}' : (isPerUseMemo ? 'Memo & Photos for Use #$useIndex' : 'Memo & Photos for $iataCode')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(tr('Memo:'), style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: memoController,
                      maxLines: 5,
                      minLines: 3,
                      decoration:  InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: tr('Write your thoughts here...'),
                      ),
                    ),
                    const SizedBox(height: 20),
                     Text(tr('Photos:'), style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (BuildContext modalContext) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      ListTile(
                                        leading: const Icon(Icons.photo_library),
                                        title:  Text(tr('Photo Library')),
                                        onTap: () {
                                          Navigator.pop(modalContext);
                                          _pickImage(ImageSource.gallery);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_camera),
                                        title:  Text(tr('Camera')),
                                        onTap: () {
                                          Navigator.pop(modalContext);
                                          _pickImage(ImageSource.camera);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child:  Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.blue),
                                  Text(tr('Add Photo'), style: TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ...currentPhotos.asMap().entries.map((entry) {
                          return _buildPhotoPreview(entry.value, entry.key, (index) {
                            setStateDialog(() {
                              currentPhotos.removeAt(index);
                            });
                          });
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child:  Text(tr('Cancel')),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child:  Text(tr('Save')),
                  onPressed: () {
                    if (isForLounge && isPerUseMemo) {
                      provider.updateVisitEntry(
                        iataCode,
                        useIndex - 1,
                        loungeMemo: memoController.text,
                        loungePhotos: currentPhotos,
                      );
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                         SnackBar(content: Text(tr('Lounge memo and photos for this visit saved.'))),
                      );
                    } else if (isPerUseMemo) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                         SnackBar(content: Text(tr('Memo and photos for use saved (Model update required).'))),
                      );
                    } else {
                      provider.updateMemoAndPhotos(
                          iataCode,
                          memoController.text,
                          currentPhotos
                      );
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                         SnackBar(content: Text(tr('Memo and photos saved.'))),
                      );
                    }
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPhotoPreview(String photoPath, int index, Function(int) onRemove) {
    final file = File(photoPath);
    bool fileExists = file.existsSync();
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400)
          ),
          child: fileExists
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(file, fit: BoxFit.cover),
          )
              : Center(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                  tr('File Not Found: ${photoPath.substring(photoPath.length > 8 ? photoPath.length - 8 : 0)}'),
                  style: const TextStyle(fontSize: 8, color: Colors.red),
                  textAlign: TextAlign.center
              ),
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
            onPressed: () => onRemove(index),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSection(BuildContext context, AirportVisitEntry use, int index, AirportProvider provider) {
    int? year = use.year;
    int? month = use.month;
    int? day = use.day;
    final years = [null, ...List.generate(80, (i) => DateTime.now().year - i)];
    final months = [null, ...List.generate(12, (i) => i + 1)];
    final days = [null, ...List.generate(31, (i) => i + 1)];
    final iataCode = provider.allAirports.firstWhere((a) => provider.getVisitEntries(a.iataCode).contains(use)).iataCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(tr('Visit Date'), style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                provider.updateVisitEntry(
                    iataCode,
                    index,
                    year: null,
                    month: null,
                    day: null
                );
              },
              tooltip: tr('Clear Date'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _buildDropdown<int>(
                    'Year', year, years.cast<int?>(), (val) => provider.updateVisitEntry(iataCode, index, year: val)
                )
            ),
            const SizedBox(width: 8),
            Expanded(
                child: _buildDropdown<int>(
                    'Month', month, months.cast<int?>(), (val) => provider.updateVisitEntry(iataCode, index, month: val)
                )
            ),
            const SizedBox(width: 8),
            Expanded(
                child: _buildDropdown<int>(
                    'Day', day, days.cast<int?>(), (val) => provider.updateVisitEntry(iataCode, index, day: val)
                )
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown<T>(String hint, T? value, List<T?> items, ValueChanged<T?> onChanged) {
    return DropdownButtonFormField<T>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
          labelText: tr(hint),
          border: const OutlineInputBorder(),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
      items: items
          .map((item) => DropdownMenuItem<T>(
        value: item as T?,
        child: Text(
          tr(item?.toString() ?? 'Unknown'),
          style: TextStyle(
            fontSize: (item == null) ? 11.0 : 15.0,
            color: (item == null) ? Colors.grey.shade600 : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }
// --- End: Methods copied from airports_screen.dart ---
}

extension ColorUtils on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}