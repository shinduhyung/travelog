// lib/screens/airport_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/services/statistics_repository.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';

// Import Lounge Screen
import 'flights_lounge_stats_screen.dart';

// Continent colors and names
const Map<String, Map<String, dynamic>> continentMap = {
  'Asia': {'name': 'Asia', 'color': Color(0xFFF48FB1)},
  'Europe': {'name': 'Europe', 'color': Color(0xFFFFC107)},
  'Africa': {'name': 'Africa', 'color': Color(0xFF795548)},
  'North America': {'name': 'North America', 'color': Color(0xFF64B5F6)},
  'South America': {'name': 'South America', 'color': Color(0xFF81C784)},
  'Oceania': {'name': 'Oceania', 'color': Color(0xFFB39DDB)},
  'Antarctica': {'name': 'Antarctica', 'color': Colors.grey},
  'Unknown': {'name': 'Unknown', 'color': Colors.grey},
};

class AirportStatsScreen extends StatefulWidget {
  const AirportStatsScreen({super.key});

  @override
  State<AirportStatsScreen> createState() => _AirportStatsScreenState();
}

class _AirportStatsScreenState extends State<AirportStatsScreen> {
  final MaterialColor themeColor = Colors.blue;
  int _selectedIndex = 0; // 0: Airport, 1: Lounge

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Switch
            Container(
              color: _selectedIndex == 0 ? themeColor[800] : Colors.red.shade800,
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) return Colors.white;
                      return Colors.white.withOpacity(0.2);
                    }),
                    foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) {
                        return _selectedIndex == 0 ? themeColor[800]! : Colors.red.shade800;
                      }
                      return Colors.white;
                    }),
                    side: MaterialStateProperty.all(BorderSide.none),
                  ),
                  segments:  [
                    ButtonSegment<int>(
                      value: 0,
                      label: Text(tr('Airport')),
                      icon: Icon(Icons.flight),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text(tr('Lounge')),
                      icon: Icon(Icons.wine_bar),
                    ),
                  ],
                  selected: {_selectedIndex},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _selectedIndex = newSelection.first;
                    });
                  },
                ),
              ),
            ),
            // Main Contents
            Expanded(
              child: _selectedIndex == 0
                  ? _AirportStatsBody(themeColor: themeColor)
                  : const LoungeStatsScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AirportStatsBody extends StatelessWidget {
  final MaterialColor themeColor;

  const _AirportStatsBody({required this.themeColor});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Consumer2<AirportProvider, CountryProvider>(
      builder: (context, airportProvider, countryProvider, child) {
        if (airportProvider.isLoading || countryProvider.allCountries.isEmpty) {
          return Center(child: CircularProgressIndicator(color: themeColor[800]));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 466,
                child: FutureBuilder(
                  future: Future.wait([
                    StatisticsRepository.instance.loadLegacyString('assets/top_airports.json'),
                    rootBundle.loadString('assets/airports.json'),
                  ]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return  Center(child: Text(tr('Failed to load ranking data.')));
                    }

                    final List<dynamic> rankingData = json.decode(snapshot.data![0] as String);
                    final Map<String, dynamic> airportMap = json.decode(snapshot.data![1] as String);
                    final List<dynamic> airportData = airportMap.values.toList();
                    final Map<String, dynamic> iataToAirport = {
                      for (var item in airportData)
                        if (item.containsKey('iata') && (item['iata'] as String).isNotEmpty)
                          item['iata'] as String: item,
                    };
                    final visitedAirportNames = airportProvider.visitedAirports;

                    return _AirportRankingCard(
                      rankingData: rankingData,
                      visitedAirportNames: visitedAirportNames,
                      iataToAirport: iataToAirport,
                      themeColor: themeColor,
                      countryProvider: countryProvider,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 600,
                child: _AirportRankingByFlightsCard(
                  airportProvider: airportProvider,
                  themeColor: themeColor,
                ),
              ),
              const SizedBox(height: 24),
              _AirportYearlyTrendCard(
                airportProvider: airportProvider,
                countryProvider: countryProvider,
                primaryColor: themeColor[800]!,
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

class _AirportRankingCard extends StatelessWidget {
  final List<dynamic> rankingData;
  final Set<String> visitedAirportNames;
  final Map<String, dynamic> iataToAirport;
  final MaterialColor themeColor;
  final CountryProvider countryProvider;

  const _AirportRankingCard({
    required this.rankingData,
    required this.visitedAirportNames,
    required this.iataToAirport,
    required this.themeColor,
    required this.countryProvider,
  });

  String _getContinent(String? isoA2, String countryName) {
    try {
      if (isoA2 != null && isoA2.isNotEmpty) {
        final country = countryProvider.allCountries.firstWhere(
                (c) => c.isoA2.toUpperCase() == isoA2.toUpperCase(),
            orElse: () => throw Exception('Not Found'));
        return country.continent ?? 'Unknown';
      }
      throw Exception('ISO Code missing');
    } catch (_) {
      try {
        final searchName = countryName.toLowerCase().trim();
        final country = countryProvider.allCountries.firstWhere(
                (c) =>
            c.name.toLowerCase() == searchName ||
                c.isoA3.toLowerCase() == searchName ||
                (searchName.length > 3 && c.name.toLowerCase().contains(searchName)),
            orElse: () => throw Exception('Not Found'));
        return country.continent ?? 'Unknown';
      } catch (e) {
        return 'Unknown';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return _AirportRankingCardView(
      rankingData: rankingData,
      visitedAirportNames: visitedAirportNames,
      iataToAirport: iataToAirport,
      themeColor: themeColor,
      getContinent: _getContinent,
    );
  }
}

class _AirportRankingCardView extends StatefulWidget {
  final List<dynamic> rankingData;
  final Set<String> visitedAirportNames;
  final Map<String, dynamic> iataToAirport;
  final MaterialColor themeColor;
  final String Function(String?, String) getContinent;

  const _AirportRankingCardView({
    required this.rankingData,
    required this.visitedAirportNames,
    required this.iataToAirport,
    required this.themeColor,
    required this.getContinent,
  });

  @override
  State<_AirportRankingCardView> createState() => _AirportRankingCardViewState();
}

class _AirportRankingCardViewState extends State<_AirportRankingCardView> {
  int _displaySegment = 0;
  final Color visitedColor = Colors.blue.shade700;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final textTheme = Theme.of(context).textTheme;
    final List<dynamic> filteredRankingData = _displaySegment == 0
        ? widget.rankingData
        : widget.rankingData.where((item) => widget.visitedAirportNames.contains(item['iata_code'])).toList();

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
                    Text(tr('Top 100 Airports'), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(
                  height: 40,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.selected)) return widget.themeColor.shade700;
                        return Colors.transparent;
                      }),
                      foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.selected)) return Colors.white;
                        return widget.themeColor.shade700;
                      }),
                      shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      side: MaterialStateProperty.all(BorderSide(color: widget.themeColor.shade700)),
                      padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 10)),
                      textStyle: MaterialStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    segments:  [
                      ButtonSegment<int>(value: 0, label: Center(child: Text(tr('All')))),
                      ButtonSegment<int>(value: 1, label: Center(child: Text(tr('Flown')))),
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
          Expanded(
            child: filteredRankingData.isEmpty
                ?  Center(child: Text(tr('No data to display.')))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              itemCount: filteredRankingData.length,
              itemBuilder: (context, index) {
                final airportItem = filteredRankingData[index];
                final iataCode = airportItem['iata_code'] as String;
                final isVisited = widget.visitedAirportNames.contains(iataCode);
                final rank = airportItem['rank'] as int;

                final airportInfo = widget.iataToAirport[iataCode];
                final airportName = airportInfo?['name'] as String? ?? 'Unknown Airport';
                final countryName = airportItem['country_name'] as String? ?? 'Unknown';
                final isoA2 = airportItem['iso_a2'] as String?;

                final continentName = widget.getContinent(isoA2, countryName);
                final continentColor = continentMap[continentName]?['color'] ?? Colors.grey;

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
                      title: Text(airportName,
                          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(iataCode,
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.circle, size: 8, color: continentColor),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(
                                tr(countryName),
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

class _AirportRankingByFlightsCard extends StatefulWidget {
  final AirportProvider airportProvider;
  final MaterialColor themeColor;

  const _AirportRankingByFlightsCard({
    required this.airportProvider,
    required this.themeColor,
  });

  @override
  State<_AirportRankingByFlightsCard> createState() => _AirportRankingByFlightsCardState();
}

class _AirportRankingByFlightsCardState extends State<_AirportRankingByFlightsCard> {
  String _selectedPeriod = 'All Time';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int _sortOrderSegment = 0;
  final List<String> _periods = ['30 Days', '365 Days', 'Year', 'All Time', 'Custom'];
  List<Map<String, dynamic>> _rankedAirports = [];
  int _averageUses = 0;
  int _maxUsesInPeriod = 1;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _AirportRankingByFlightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareList();
  }

  void _showCustomDateRangePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(
          start: _customStartDate ?? now.subtract(const Duration(days: 365)),
          end: _customEndDate ?? now),
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

    final Map<String, int> airportUseCounts = {};
    for (var iataCode in widget.airportProvider.visitedAirports) {
      final visitEntries = widget.airportProvider.getVisitEntries(iataCode);
      int usesInPeriod = 0;
      for (var entry in visitEntries) {
        bool isWithinRange = false;
        if (_selectedPeriod == 'All Time') {
          if (entry.year != null || entry.month != null || entry.day != null) isWithinRange = true;
        } else {
          final entryDate = entry.date;
          if (entryDate != null) {
            isWithinRange = true;
            if (startDate != null && entryDate.isBefore(startDate)) isWithinRange = false;
            if (endDate != null && entryDate.isAfter(endDate)) isWithinRange = false;
          }
        }
        if (isWithinRange) {
          usesInPeriod++;
        }
      }
      if (usesInPeriod > 0) airportUseCounts[iataCode] = usesInPeriod;
    }

    List<Map<String, dynamic>> rankedAirports = [];
    int validTotalUses = 0;
    int validAirportCount = 0;

    for (var iataCode in airportUseCounts.keys) {
      final useCount = airportUseCounts[iataCode]!;
      final matching = widget.airportProvider.allAirports.where((a) => a.iataCode == iataCode);

      if (matching.isNotEmpty) {
        final airport = matching.first;
        rankedAirports.add({'airport': airport, 'useCount': useCount});
        validTotalUses += useCount;
        validAirportCount++;
      }
    }

    if (rankedAirports.isNotEmpty) {
      _maxUsesInPeriod = rankedAirports.map((e) => e['useCount'] as int).reduce(math.max);
      _averageUses = (validTotalUses / validAirportCount).round();
    } else {
      _maxUsesInPeriod = 1;
      _averageUses = 0;
    }

    rankedAirports.sort((a, b) => a['useCount'].compareTo(b['useCount']));
    if (_sortOrderSegment == 0) rankedAirports = rankedAirports.reversed.toList();

    if (mounted) {
      setState(() {
        _rankedAirports = rankedAirports;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final textTheme = Theme.of(context).textTheme;
    final topUses = _maxUsesInPeriod;

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
                Icon(Icons.flight, color: widget.themeColor[800]),
                const SizedBox(width: 8),
                Text(tr('Most Visited Airports'), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                              borderSide: BorderSide(color: widget.themeColor[800]!)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: widget.themeColor[800]!, width: 2)),
                        ),
                        items: _periods
                            .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(tr(value),
                                style: TextStyle(color: widget.themeColor[800], fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (String? newValue) {
                          if (newValue == 'Custom')
                            _showCustomDateRangePicker();
                          else
                            setState(() {
                              _selectedPeriod = newValue!;
                              _prepareList();
                            });
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
                        onSelectionChanged: (Set<int> newSelection) => setState(() {
                          _sortOrderSegment = newSelection.first;
                          _prepareList();
                        }),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                            if (states.contains(MaterialState.selected)) return widget.themeColor.shade700;
                            return Colors.transparent;
                          }),
                          foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                            if (states.contains(MaterialState.selected)) return Colors.white;
                            return widget.themeColor.shade700;
                          }),
                          shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          side: MaterialStateProperty.all(BorderSide(color: widget.themeColor.shade700)),
                          padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 10)),
                          textStyle: MaterialStateProperty.all(
                              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                            onPressed: () => setState(() {
                              _selectedYear--;
                              _prepareList();
                            })),
                        Text(tr('$_selectedYear'),
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold, color: widget.themeColor[800])),
                        IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: () => setState(() {
                              _selectedYear++;
                              _prepareList();
                            })),
                      ],
                    ),
                  ),
                if (_selectedPeriod == 'Custom' && _customStartDate != null && _customEndDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                        tr('Custom Range: ${DateFormat('yyyy-MM-dd').format(_customStartDate!)} ~ ${DateFormat('yyyy-MM-dd').format(_customEndDate!)}'),
                        style: const TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _rankedAirports.isEmpty
                ?  Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(tr('No valid airport records available.')),
                ))
                : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _rankedAirports.length,
              itemBuilder: (context, index) {
                final item = _rankedAirports[index];
                final airport = item['airport'] as Airport;
                final useCount = item['useCount'] as int;
                final rank = _sortOrderSegment == 0 ? index + 1 : _rankedAirports.length - index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(airport.name,
                                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                                Text(airport.iataCode,
                                    style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                              ],
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
                          value: useCount / (topUses > 0 ? topUses : 1),
                          borderRadius: BorderRadius.circular(5),
                          minHeight: 6,
                          backgroundColor: widget.themeColor.withOpacity(0.2),
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            color: widget.themeColor.withOpacity(0.05),
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Center(
              child: Text(tr('Average Uses: $_averageUses'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.themeColor[800])),
            ),
          ),
        ],
      ),
    );
  }
}

class _AirportYearlyTrendCard extends StatefulWidget {
  final AirportProvider airportProvider;
  final CountryProvider? countryProvider;
  final Color primaryColor;
  const _AirportYearlyTrendCard({required this.airportProvider, this.countryProvider, required this.primaryColor});

  @override
  State<_AirportYearlyTrendCard> createState() => _AirportYearlyTrendCardState();
}

class _AirportYearlyTrendCardState extends State<_AirportYearlyTrendCard> {
  List<LineChartBarData> _lineChartData = [];
  double _lineChartMaxY = 10.0;

  @override
  void initState() {
    super.initState();
    _prepareLineChartData();
  }

  @override
  void didUpdateWidget(covariant _AirportYearlyTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.airportProvider != oldWidget.airportProvider) {
      _prepareLineChartData();
    }
  }

  void _prepareLineChartData() {
    final int currentYear = DateTime.now().year;
    final int startYear = currentYear - 9;
    final Map<int, Map<String, int>> yearlyCounts = {
      for (var i = startYear; i <= currentYear; i++)
        i: {
          for (var continentName in continentMap.keys) continentName: 0,
        }
    };
    double maxCount = 0;

    final Map<String, Airport> iataToAirportObject = {
      for (var airport in widget.airportProvider.allAirports) airport.iataCode: airport
    };

    final visitedIataSet = widget.airportProvider.visitedAirports;

    for (var iata in visitedIataSet) {
      final airport = iataToAirportObject[iata];
      String continent = 'Unknown';

      if (airport != null && widget.countryProvider != null) {
        try {
          final country = widget.countryProvider!.allCountries
              .firstWhere((c) => c.isoA2.toLowerCase() == airport.country.toLowerCase(),
              orElse: () => throw Exception('Not Found'));
          continent = country.continent ?? 'Unknown';
        } catch (e) {
          continent = 'Unknown';
        }
      }

      if (airport == null || continent == 'Unknown') continue;

      for (var entry in widget.airportProvider.getVisitEntries(iata)) {
        if (entry.year != null && entry.year! >= startYear && entry.year! <= currentYear) {
          final year = entry.year!;
          final continentCountsForYear = yearlyCounts[year]!;
          final currentCount = continentCountsForYear[continent] ?? 0;
          continentCountsForYear[continent] = currentCount + 1;
        }
      }
    }

    final List<LineChartBarData> lines = [];
    final Map<String, Color> lineColors = {
      ...continentMap.map((key, value) => MapEntry(key, value['color'])),
      'Total': Colors.black87,
    };

    final allDataPoints = <String, List<FlSpot>>{
      for (var code in continentMap.keys.where((k) => k != 'Unknown')) code: [],
      'Total': [],
    };

    for (int year = startYear; year <= currentYear; year++) {
      int yearlyTotal = 0;
      continentMap.keys.where((k) => k != 'Unknown').forEach((continentName) {
        final count = yearlyCounts[year]![continentName] ?? 0;
        allDataPoints[continentName]!.add(FlSpot(year.toDouble(), count.toDouble()));
        yearlyTotal += count;
      });
      allDataPoints['Total']!.add(FlSpot(year.toDouble(), yearlyTotal.toDouble()));
      if (yearlyTotal > maxCount) maxCount = yearlyTotal.toDouble();
    }

    allDataPoints.forEach((name, spots) {
      if (lineColors.containsKey(name) && spots.any((spot) => spot.y > 0)) {
        final isTotal = name == 'Total';
        lines.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          preventCurveOvershootingThreshold: 0.0,
          color: lineColors[name],
          barWidth: isTotal ? 2.5 : 3,
          isStrokeCapRound: true,
          dashArray: isTotal ? [5, 5] : null,
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
      }
    });

    if (mounted) {
      setState(() {
        _lineChartData = lines;
        double newMaxY = maxCount == 0 ? 10 : (maxCount * 1.25);
        if (newMaxY > 10) {
          newMaxY = (newMaxY / 5).ceil() * 5.0;
        } else {
          newMaxY = newMaxY.ceilToDouble();
        }
        _lineChartMaxY = newMaxY;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
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
                    color: widget.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.trending_up, color: widget.primaryColor, size: 24),
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
              child: _lineChartData.isEmpty
                  ?  Center(child: Text(tr("No data in the last 10 years.")))
                  : LineChart(
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
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) {
                            return Container();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              tr(value.toInt().toString()),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
                            ),
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
                            child: Text(
                              tr(value.toInt().toString().substring(2)),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      left: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
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
                ...continentMap.entries
                    .where((e) => e.key != 'Unknown' && e.key != 'Antarctica')
                    .map((e) => _buildLegendItem(e.value['color'], e.value['name'])),
              ],
            )
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
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Text(tr(text), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[800])),
        ],
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