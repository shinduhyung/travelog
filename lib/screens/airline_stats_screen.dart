// lib/screens/airline_stats_screen.dart

import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:jidoapp/services/statistics_repository.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/airline_detail_screen.dart';

class AirlineStatsScreen extends StatelessWidget {
  const AirlineStatsScreen({super.key});

  final MaterialColor themeColor = Colors.green;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer2<AirlineProvider, CountryProvider>(
                builder: (context, airlineProvider, countryProvider, child) {
                  if (airlineProvider.isLoading || countryProvider.isLoading) {
                    return Center(child: CircularProgressIndicator(color: themeColor[800]));
                  }

                  final allLogs = airlineProvider.allFlightLogs;
                  final allAirlines = airlineProvider.airlines;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        FutureBuilder(
                          future: StatisticsRepository.instance.loadLegacyString('assets/top_airlines.json'),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                height: 300,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (snapshot.hasError) {
                              return  SizedBox(
                                height: 300,
                                child: Center(child: Text(tr('Failed to load top airline data.'))),
                              );
                            }
                            final List<dynamic> rankingData = json.decode(snapshot.data!);
                            return _TopAirlinesRankingCard(
                              rankingData: rankingData,
                              allAirlines: allAirlines,
                              themeColor: themeColor,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 600,
                          child: _AirlineRankingCard(
                            allAirlines: allAirlines,
                            allFlightLogs: allLogs,
                            themeColor: themeColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _AirlineTypeStatsCard(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopAirlinesRankingCard extends StatefulWidget {
  final List<dynamic> rankingData;
  final List<Airline> allAirlines;
  final MaterialColor themeColor;

  const _TopAirlinesRankingCard({
    required this.rankingData,
    required this.allAirlines,
    required this.themeColor,
  });

  @override
  State<_TopAirlinesRankingCard> createState() => _TopAirlinesRankingCardState();
}

class _TopAirlinesRankingCardState extends State<_TopAirlinesRankingCard> {
  int _displaySegment = 0;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final textTheme = Theme.of(context).textTheme;
    final Color visitedColor = Colors.green.shade700;
    final countryProvider = context.read<CountryProvider>();

    final Set<String> flownAirlineNames = widget.allAirlines
        .where((a) => a.totalTimes > 0)
        .map((a) => a.name)
        .toSet();

    final List<dynamic> filteredRankingData = _displaySegment == 0
        ? widget.rankingData
        : widget.rankingData.where((item) => flownAirlineNames.contains(item['name'])).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: widget.themeColor[800]),
                    const SizedBox(width: 8),
                    Text(tr('🏆 Top 100 Airlines'), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(
                  height: 40,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return widget.themeColor.shade700;
                        }
                        return Colors.transparent;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return widget.themeColor.shade700;
                      }),
                      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      side: WidgetStateProperty.all(BorderSide(color: widget.themeColor.shade700)),
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10)),
                      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    segments:  [
                      ButtonSegment<int>(
                        value: 0,
                        label: Center(child: Text(tr('All'))),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Center(child: Text(tr('Flown'))),
                      ),
                    ],
                    selected: {_displaySegment},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _displaySegment = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 350,
            child: filteredRankingData.isEmpty
                ?  Center(child: Text(tr('No data to display.')))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              itemCount: filteredRankingData.length,
              itemBuilder: (context, index) {
                final airlineItem = filteredRankingData[index];
                final String airlineName = airlineItem['name'] as String;
                final String airlineCode = airlineItem['code'] as String;
                final String countryCode = (airlineItem['country_code'] as String).toUpperCase();
                final rank = airlineItem['rank'] as int;

                final isVisited = flownAirlineNames.contains(airlineName);

                final country = countryProvider.allCountries.cast<Country?>().firstWhere(
                      (c) => c?.isoA2 == countryCode,
                  orElse: () => null,
                );

                final String displayName = country?.name ?? countryCode;
                final String continent = country?.continent ?? 'Unknown';
                final Color continentColor = countryProvider.continentColors[continent] ?? Colors.grey;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isVisited
                          ? LinearGradient(
                        stops: const [0.02, 0.5],
                        colors: [visitedColor.withOpacity(0.4), Colors.transparent],
                      )
                          : null,
                      color: isVisited ? null : Colors.grey.shade50,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isVisited ? visitedColor : Colors.grey.shade400,
                        child: Text(
                          tr(rank.toString()),
                          style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: rank > 99 ? 11 : 14),
                        ),
                      ),
                      title: Text(airlineName,
                          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(airlineCode,
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.circle, size: 8, color: continentColor),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(
                                tr(displayName),
                                style: textTheme.bodyMedium
                                    ?.copyWith(color: continentColor, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AirlineRankingCard extends StatefulWidget {
  final List<Airline> allAirlines;
  final List<FlightLog> allFlightLogs;
  final MaterialColor themeColor;

  const _AirlineRankingCard({
    required this.allAirlines,
    required this.allFlightLogs,
    required this.themeColor,
  });

  @override
  State<_AirlineRankingCard> createState() => _AirlineRankingCardState();
}

class _AirlineRankingCardState extends State<_AirlineRankingCard> {
  String _selectedPeriod = 'All Time';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int _sortOrderSegment = 0; // 0: High, 1: Low
  final List<String> _periods = ['30 Days', '365 Days', 'Year', 'All Time', 'Custom'];
  List<Airline> _rankedAirlines = [];
  int _averageFlights = 0;
  int _maxFlightsInPeriod = 1;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _AirlineRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.allAirlines, oldWidget.allAirlines) ||
        !listEquals(widget.allFlightLogs, oldWidget.allFlightLogs)) {
      _prepareList();
    }
  }

  void _showCustomDateRangePicker() async {
    final DateTime now = DateTime.now();
    final DateTime oneYearAgo = now.subtract(const Duration(days: 365));
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? oneYearAgo,
        end: _customEndDate ?? now,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'Custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _prepareList();
      });
    }
  }

  void _prepareList() {
    DateTime? startDate;
    DateTime? endDate;

    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'All Time':
        break;
      case 'Year':
        startDate = DateTime(_selectedYear, 1, 1);
        endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59);
        break;
      case '365 Days':
        startDate = now.subtract(const Duration(days: 365));
        endDate = now;
        break;
      case '30 Days':
        startDate = now.subtract(const Duration(days: 30));
        endDate = now;
        break;
      case 'Custom':
        startDate = _customStartDate;
        endDate = _customEndDate;
        break;
    }

    final Map<String, int> airlineFlightCounts = {};
    int totalFlightsInPeriod = 0;

    for (var log in widget.allFlightLogs) {
      if (log.airlineName == null || log.airlineName == 'Unknown') {
        continue;
      }

      bool isWithinRange = false;

      if (_selectedPeriod == 'All Time') {
        if (log.date != 'Unknown' && log.date.isNotEmpty) {
          isWithinRange = true;
        }
      } else {
        if (log.date != 'Unknown' && log.date.isNotEmpty) {
          final parts = log.date.split('-');
          if (parts.isNotEmpty && int.tryParse(parts[0]) != null) {
            DateTime? logDate;
            try {
              final year = int.parse(parts[0]);
              final month = parts.length > 1 ? int.parse(parts[1]) : 1;
              final day = parts.length > 2 ? int.parse(parts[2]) : 1;
              logDate = DateTime(year, month, day);
            } catch (e) {
              logDate = null;
            }

            if (logDate != null) {
              isWithinRange = true;
              if (startDate != null && logDate.isBefore(startDate)) {
                isWithinRange = false;
              }
              if (endDate != null && logDate.isAfter(endDate)) {
                isWithinRange = false;
              }
            }
          }
        }
      }

      if (isWithinRange) {
        final airlineName = log.airlineName!;
        airlineFlightCounts[airlineName] = (airlineFlightCounts[airlineName] ?? 0) + log.times;
        totalFlightsInPeriod += log.times;
      }
    }

    List<Airline> rankedAirlines = [];
    if (airlineFlightCounts.isNotEmpty) {
      _maxFlightsInPeriod = airlineFlightCounts.values.reduce(math.max);
      _averageFlights = (totalFlightsInPeriod / airlineFlightCounts.length).round();
    } else {
      _maxFlightsInPeriod = 1;
      _averageFlights = 0;
    }

    for (var airlineName in airlineFlightCounts.keys) {
      final totalFlights = airlineFlightCounts[airlineName]!;
      final airline = widget.allAirlines.firstWhere((a) => a.name == airlineName,
          orElse: () => Airline(name: airlineName, code: 'N/A'));
      final tempAirline = Airline(name: airline.name, code: airline.code, logs: [], rating: airline.rating);
      tempAirline.logs = [FlightLog(flightNumber: "temp", times: totalFlights)];
      rankedAirlines.add(tempAirline);
    }

    rankedAirlines.sort((a, b) => a.totalTimes.compareTo(b.totalTimes));

    if (_sortOrderSegment == 0) {
      rankedAirlines = rankedAirlines.reversed.toList();
    }

    if (mounted) {
      setState(() {
        _rankedAirlines = rankedAirlines;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final textTheme = Theme.of(context).textTheme;
    final topFlights = _maxFlightsInPeriod;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.flight_takeoff, color: widget.themeColor[800]),
                const SizedBox(width: 8),
                Text(tr('Most Flown Airlines'), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            color: widget.themeColor.withOpacity(0.05),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPeriod,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: widget.themeColor[800]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: widget.themeColor[800]!, width: 2),
                          ),
                        ),
                        items: _periods.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              tr(value),
                              style: TextStyle(color: widget.themeColor[800], fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue == 'Custom') {
                            _showCustomDateRangePicker();
                          } else {
                            setState(() {
                              _selectedPeriod = newValue!;
                              _prepareList();
                            });
                          }
                        },
                        isExpanded: true,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments:  [
                          ButtonSegment<int>(value: 0, label: Text(tr('High'))),
                          ButtonSegment<int>(value: 1, label: Text(tr('Low'))),
                        ],
                        selected: {_sortOrderSegment},
                        onSelectionChanged: (Set<int> newSelection) {
                          setState(() {
                            _sortOrderSegment = newSelection.first;
                            _prepareList();
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return widget.themeColor.shade700;
                            }
                            return Colors.transparent;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return widget.themeColor.shade700;
                          }),
                          shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          side: WidgetStateProperty.all(BorderSide(color: widget.themeColor.shade700)),
                          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10)),
                          textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedPeriod == 'Year')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed: () {
                            setState(() {
                              _selectedYear--;
                              _prepareList();
                            });
                          },
                        ),
                        Text(
                          tr('$_selectedYear'),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: widget.themeColor[800],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          onPressed: () {
                            setState(() {
                              _selectedYear++;
                              _prepareList();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                if (_selectedPeriod == 'Custom' && _customStartDate != null && _customEndDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      tr('Custom Range: ${DateFormat('yyyy-MM-dd').format(_customStartDate!)} ~ ${DateFormat('yyyy-MM-dd').format(_customEndDate!)}'),
                      style: const TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _rankedAirlines.isEmpty
                ?  Center(child: Text(tr('No flight records available for this period.')))
                : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _rankedAirlines.length,
              itemBuilder: (context, index) {
                final airline = _rankedAirlines[index];
                final rank = _sortOrderSegment == 0 ? index + 1 : _rankedAirlines.length - index;
                final useCount = airline.totalTimes;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AirlineDetailScreen(airlineName: airline.name),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                                width: 32,
                                child: Text(tr('#$rank'),
                                    style: textTheme.titleSmall
                                        ?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold))),
                            Expanded(
                              child: Text(
                                airline.name,
                                style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(tr('$useCount'),
                                style: textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold, color: widget.themeColor[900])),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: [widget.themeColor[400]!, widget.themeColor[800]!],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(bounds);
                          },
                          child: LinearProgressIndicator(
                            value: useCount / (topFlights > 0 ? topFlights : 1),
                            borderRadius: BorderRadius.circular(5),
                            minHeight: 6,
                            backgroundColor: widget.themeColor.withOpacity(0.2),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: widget.themeColor.withOpacity(0.05),
              border: Border(top: BorderSide(color: widget.themeColor.withOpacity(0.1))),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Center(
              child: Text(
                tr('Average Flights: $_averageFlights'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: widget.themeColor[800],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// FSC vs LCC 통계 카드 (Unknown 제외 버전)
class _AirlineTypeStatsCard extends StatefulWidget {
  const _AirlineTypeStatsCard();

  @override
  State<_AirlineTypeStatsCard> createState() => _AirlineTypeStatsCardState();
}

class _AirlineTypeStatsCardState extends State<_AirlineTypeStatsCard> {
  final Color _primaryColor = Colors.green;
  final List<String> _periods = ['Last 365 Days', 'Year', 'All Time', 'Custom'];
  String _selectedPeriod = 'All Time';
  int _selectedYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  int? _touchedIndex = -1;
  int _totalItemsInPeriod = 0;
  // [수정] Unknown 제거
  Map<String, int> _pieChartCounts = {'FSC': 0, 'LCC': 0};
  List<LineChartBarData> _lineChartData = [];
  double _lineChartMaxY = 10.0;

  final Map<String, Map<String, dynamic>> _typeInfo = {
    'FSC': {'color': Colors.blue.shade600, 'name': 'FSC', 'abbr': 'FSC'},
    'LCC': {'color': Colors.orange.shade600, 'name': 'LCC', 'abbr': 'LCC'},
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareData();
  }

  void _prepareData() {
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    final allLogs = airlineProvider.allFlightLogs;
    final allAirlines = airlineProvider.airlines;

    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Last 365 Days': startDate = now.subtract(const Duration(days: 365)); endDate = now; break;
      case 'Year': startDate = DateTime(_selectedYear, 1, 1); endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59); break;
      case 'Custom': startDate = _customStartDate; endDate = _customEndDate; break;
      case 'All Time': default: break;
    }

    _pieChartCounts = {'FSC': 0, 'LCC': 0};
    int totalCount = 0;

    for (var log in allLogs) {
      if (log.isCanceled) continue;

      DateTime? logDate = DateTime.tryParse(log.date);
      bool isWithinRange = true;
      if (_selectedPeriod != 'All Time') {
        if (logDate == null) isWithinRange = false;
        if (startDate != null && logDate != null && logDate.isBefore(startDate)) isWithinRange = false;
        if (endDate != null && logDate != null && logDate.isAfter(endDate)) isWithinRange = false;
      }

      if (isWithinRange) {
        final airline = allAirlines.firstWhere(
                (a) => a.name == log.airlineName,
            orElse: () => Airline(name: 'Unknown', code: 'N/A')
        );
        final type = airline.airlineType;

        // [수정] Unknown이거나 null이면 모수에서 아예 제외
        if (type == null || type == 'Unknown' || !_typeInfo.containsKey(type)) {
          continue;
        }

        _pieChartCounts[type] = (_pieChartCounts[type] ?? 0) + log.times;
        totalCount += log.times;
      }
    }

    _totalItemsInPeriod = totalCount;
    _prepareLineChartData(allLogs, allAirlines);

    if (mounted) setState(() {});
  }

  void _prepareLineChartData(List<FlightLog> allLogs, List<Airline> allAirlines) {
    final int currentYear = DateTime.now().year;
    final int startYear = currentYear - 9;
    final Map<int, Map<String, int>> yearlyCounts = {
      for (var i = startYear; i <= currentYear; i++) i: {'FSC': 0, 'LCC': 0}
    };

    for (var log in allLogs) {
      if (log.isCanceled) continue;
      final year = DateTime.tryParse(log.date)?.year;
      if (year != null && year >= startYear && year <= currentYear) {
        final airline = allAirlines.firstWhere(
                (a) => a.name == log.airlineName,
            orElse: () => Airline(name: 'Unknown', code: 'N/A')
        );
        final type = airline.airlineType;

        // [수정] Unknown 제외
        if (type == null || type == 'Unknown' || !yearlyCounts[year]!.containsKey(type)) {
          continue;
        }

        yearlyCounts[year]![type] = (yearlyCounts[year]![type] ?? 0) + log.times;
      }
    }

    double maxCount = 0;
    final List<LineChartBarData> lines = [];
    final List<String> types = ['FSC', 'LCC', 'Total'];

    for (var type in types) {
      final List<FlSpot> spots = [];
      final isTotal = type == 'Total';
      final color = isTotal ? Colors.black87 : (_typeInfo[type]?['color'] ?? Colors.grey);

      for (int year = startYear; year <= currentYear; year++) {
        int count = 0;
        if (isTotal) {
          // [수정] FSC와 LCC의 합만 Total로 계산
          count = (yearlyCounts[year]!['FSC'] ?? 0) + (yearlyCounts[year]!['LCC'] ?? 0);
        } else {
          count = yearlyCounts[year]![type] ?? 0;
        }
        spots.add(FlSpot(year.toDouble(), count.toDouble()));
        if (count > maxCount) maxCount = count.toDouble();
      }

      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: color,
        barWidth: isTotal ? 2.5 : 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
        dashArray: isTotal ? [5, 5] : null,
      ));
    }

    _lineChartMaxY = maxCount == 0 ? 10 : (maxCount * 1.25).ceilToDouble();
    _lineChartData = lines;
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            tr('Carrier Type Distribution'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: _primaryColor, fontSize: 22),
          ),
          const SizedBox(height: 16),
          _buildPeriodSelector(),
          const SizedBox(height: 32),
          _buildPieChartSection(),
          const SizedBox(height: 32),
          _buildLineChartSection(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedPeriod,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _primaryColor.withOpacity(0.5))),
      ),
      items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(tr(p), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)))).toList(),
      onChanged: (val) {
        if (val == 'Custom') {
          _showCustomDateRangePicker();
        } else {
          setState(() { _selectedPeriod = val!; _prepareData(); });
        }
      },
    );
  }

  void _showCustomDateRangePicker() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (picked != null) {
      setState(() { _selectedPeriod = 'Custom'; _customStartDate = picked.start; _customEndDate = picked.end; _prepareData(); });
    }
  }

  Widget _buildPieChartSection() {
    // [수정] Unknown 제거
    final keys = ['FSC', 'LCC'];
    final pieData = List.generate(keys.length, (i) {
      final key = keys[i];
      final count = _pieChartCounts[key] ?? 0;
      final color = _typeInfo[key]!['color'] as Color;
      return PieChartSectionData(
        value: count.toDouble(),
        title: '',
        radius: i == _touchedIndex ? 70 : 60,
        color: color,
        borderSide: i == _touchedIndex ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
      );
    });

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                sections: pieData,
                centerSpaceRadius: 60,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(touchCallback: (event, res) {
                  setState(() {
                    if (!event.isInterestedForInteractions || res == null || res.touchedSection == null) {
                      _touchedIndex = -1;
                    } else {
                      _touchedIndex = res.touchedSection!.touchedSectionIndex;
                    }
                  });
                }),
              )),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('$_totalItemsInPeriod'), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryColor)),
                  Text(tr('Flights'), style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          children: keys.map((k) => _buildLegendItem(_typeInfo[k]!['color'], _typeInfo[k]!['name'])).toList(),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(tr(text), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLineChartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, color: _primaryColor),
            const SizedBox(width: 8),
             Text(tr("Yearly Trend (10 Years)"), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text(tr(v.toInt().toString()), style: const TextStyle(fontSize: 10)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text(tr(v.toInt().toString().substring(2)), style: const TextStyle(fontSize: 10)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey[300]!), left: BorderSide(color: Colors.grey[300]!))),
            lineBarsData: _lineChartData,
            minY: 0,
            maxY: _lineChartMaxY,
          )),
        ),
        const SizedBox(height: 16),
        Center(
          child: Wrap(
            spacing: 12,
            children: [
              _buildLegendItem(Colors.black87, 'Total'),
              _buildLegendItem(_typeInfo['FSC']!['color'], 'FSC'),
              _buildLegendItem(_typeInfo['LCC']!['color'], 'LCC'),
            ],
          ),
        ),
      ],
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
