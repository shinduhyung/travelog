// lib/screens/overview_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jidoapp/models/economy_data_model.dart';
import 'package:jidoapp/providers/economy_provider.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import 'package:jidoapp/screens/population_stats_screen.dart';
import 'package:jidoapp/screens/area_stats_screen.dart';
import 'package:jidoapp/screens/economy_stats_screen.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_tiers_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';

extension DateTimeComparison on DateTime {
  bool isAfterOrSame(DateTime other) {
    return isAfter(other) || isAtSameMomentAs(other);
  }

  bool isBeforeOrSame(DateTime other) {
    return isBefore(other) || isAtSameMomentAs(other);
  }
}

class RankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final String metricKey;
  final String unit;

  RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.metricKey,
    this.unit = '',
  });
}

class OverviewTabScreen extends StatefulWidget {
  const OverviewTabScreen({super.key});

  @override
  State<OverviewTabScreen> createState() => _OverviewTabScreenState();
}

class _OverviewTabScreenState extends State<OverviewTabScreen> {
  String _xAxisMetric = 'visitCount';
  String _yAxisMetric = 'totalDays';

  Country? _selectedCountry;

  bool _includeHome = false;
  bool _includeLived = false;
  bool _includeTransfer = false;
  bool _includeLayover = true;

  bool _xLogScale = false;
  bool _yLogScale = false;

  String _selectedDateRangeOption = 'All Time';
  String _selectedContinentOption = 'All';
  DateTimeRange? _customDateRange;
  final List<String> _dateRangeOptions = [
    'All Time',
    'Last 365 days',
    'Last 30 Days',
    'This Year',
    'Custom'
  ];
  final List<String> _continentOptions = [
    'All',
    'Asia',
    'Europe',
    'Africa',
    'North America',
    'South America',
    'Oceania'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EconomyProvider>(context, listen: false).loadEconomyData();
    });
  }

  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🌐';
    final int firstLetter = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  String _formatNumber(double val) {
    if (val == 0) return '0';
    if (val >= 1000000000) {
      return '${(val / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}b';
    }
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1).replaceAll('.0', '')}m';
    }
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    }
    return val.toInt().toString();
  }

  List<Country> _getFilteredCountries(CountryProvider provider) {
    return provider.allCountries.where((country) {
      final details = provider.visitDetails[country.name];
      if (details == null || !details.isVisited) return false;

      final bool isHome = provider.homeCountryIsoA3 == country.isoA3;
      final bool hasLived = details.hasLived;
      final bool hasTransfer = details.visitDateRanges.any((r) => r.isTransfer);
      final bool hasLayover = details.visitDateRanges.any((r) => r.isLayover);
      final bool isNormalVisit =
          !isHome && !hasLived && !hasTransfer && !hasLayover;

      if (isNormalVisit) {
        return true;
      }

      if (_includeHome && isHome) return true;
      if (_includeLived && hasLived) return true;
      if (_includeTransfer && hasTransfer) return true;
      if (_includeLayover && hasLayover) return true;

      return false;
    }).toList();
  }

  List<Country> _getCountriesForSummary(CountryProvider provider) {
    List<Country> countries = provider.filteredCountries;
    if (_selectedContinentOption != 'All') {
      countries = countries
          .where((c) => c.continent == _selectedContinentOption)
          .toList();
    }
    return countries;
  }

  List<Country> _getVisitedCountriesForSummary(
      CountryProvider provider, List<Country> totalCountriesForSummary) {
    return totalCountriesForSummary
        .where((c) =>
    provider.visitDetails.containsKey(c.name) &&
        provider.visitDetails[c.name]!.isVisited)
        .where((c) => _isVisitInDateRange(provider.visitDetails[c.name]!,
        _selectedDateRangeOption, _customDateRange))
        .toList();
  }

  bool _isVisitInDateRange(
      VisitDetails details, String rangeOption, DateTimeRange? customRange) {
    if (rangeOption == 'All Time') return true;
    if (details.visitDateRanges.isEmpty) return false;

    final now = DateTime.now();
    DateTime filterStart;
    DateTime filterEnd = now;

    switch (rangeOption) {
      case 'Last 365 days':
        filterStart = now.subtract(const Duration(days: 365));
        break;
      case 'Last 30 Days':
        filterStart = now.subtract(const Duration(days: 30));
        break;
      case 'This Year':
        filterStart = DateTime(now.year, 1, 1);
        break;
      case 'Custom':
        if (customRange == null) return false;
        filterStart = customRange.start;
        filterEnd = customRange.end;
        break;
      default:
        return true;
    }

    filterEnd =
        DateTime(filterEnd.year, filterEnd.month, filterEnd.day, 23, 59, 59);

    for (var range in details.visitDateRanges) {
      final arrival = range.arrival;
      final departure = range.departure ?? arrival;

      if (arrival == null || departure == null) continue;

      if (arrival.isBeforeOrSame(filterEnd) &&
          departure.isAfterOrSame(filterStart)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );

    if (range != null) {
      setState(() {
        _selectedDateRangeOption = 'Custom';
        _customDateRange = range;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final countryProvider = Provider.of<CountryProvider>(context);
    final economyProvider = Provider.of<EconomyProvider>(context);

    if (economyProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isoA3ToEconomyDataMap = {
      for (var data in economyProvider.economyData) data.isoA3: data
    };

    final filteredCountriesForChart = _getFilteredCountries(countryProvider);

    final totalCountriesForSummary = _getCountriesForSummary(countryProvider);
    final visitedCountriesForSummary =
    _getVisitedCountriesForSummary(countryProvider, totalCountriesForSummary);

    final totalCountries = totalCountriesForSummary.length;
    final visitedCountriesCount = visitedCountriesForSummary.length;

    final visitedContinents = visitedCountriesForSummary
        .map((c) => c.continent)
        .where((c) => c != null && c != 'Antarctica')
        .toSet();

    final totalContinentCount =
    _selectedContinentOption == 'All' ? 6 : 1;

    final countryRatio =
    totalCountries > 0 ? visitedCountriesCount / totalCountries : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(
            context: context,
            visitedCountriesList: visitedCountriesForSummary,
            totalCountries: totalCountries,
            visitedContinents: visitedContinents.length,
            totalContinents: totalContinentCount,
            countryRatio: countryRatio,
            provider: countryProvider,
          ),
          const SizedBox(height: 16),
          _buildContinentGrid(countryProvider),
          const SizedBox(height: 24),
          _OverviewRankingCard(
            countries: filteredCountriesForChart,
            provider: countryProvider,
            includeHome: _includeHome,
            includeLived: _includeLived,
            includeTransfer: _includeTransfer,
            includeLayover: _includeLayover,
            onIncludeHomeChanged: (value) =>
                setState(() => _includeHome = value),
            onIncludeLivedChanged: (value) =>
                setState(() => _includeLived = value),
            onIncludeTransferChanged: (value) =>
                setState(() => _includeTransfer = value),
            onIncludeLayoverChanged: (value) =>
                setState(() => _includeLayover = value),
          ),
          const SizedBox(height: 24),
          _RatingTierCard(
            countries: filteredCountriesForChart,
            provider: countryProvider,
          ),
          const SizedBox(height: 24),
          _buildIntegratedChartCard(countryProvider, filteredCountriesForChart, isoA3ToEconomyDataMap),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSummaryFilters() {
    return Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
            borderRadius: BorderRadius.circular(20),
            value: _selectedDateRangeOption,
            isExpanded: true,
            underline: Container(height: 1, color: Colors.grey.shade400),
            items: _dateRangeOptions
                .map((label) => DropdownMenuItem(
              value: label,
              child: Text(
                label == 'Custom' && _customDateRange != null
                    ? '${_customDateRange!.start.toLocal().toString().split(' ')[0]} - ${_customDateRange!.end.toLocal().toString().split(' ')[0]}'
                    : label,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ))
                .toList(),
            onChanged: (value) {
              if (value == 'Custom') {
                _selectCustomDateRange();
              } else {
                setState(() {
                  _selectedDateRangeOption = value!;
                  _customDateRange = null;
                });
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButton<String>(
            borderRadius: BorderRadius.circular(20),
            value: _selectedContinentOption,
            isExpanded: true,
            underline: Container(height: 1, color: Colors.grey.shade400),
            items: _continentOptions
                .map((label) => DropdownMenuItem(
              value: label,
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedContinentOption = value!;
              });
            },
          ),
        ),
      ],
    );
  }

  static const List<Map<String, dynamic>> continentsData = [
    {'name': 'Asia', 'asset': 'assets/icons/asia.png'},
    {'name': 'Europe', 'asset': 'assets/icons/europe.png'},
    {'name': 'Africa', 'asset': 'assets/icons/africa.png'},
    {'name': 'N. America', 'asset': 'assets/icons/n_america.png'},
    {'name': 'S. America', 'asset': 'assets/icons/s_america.png'},
    {'name': 'Oceania', 'asset': 'assets/icons/oceania.png'},
  ];

  Color _getStaticContinentColor(String continent) {
    switch (continent) {
      case 'North America': return Colors.blue.shade400;
      case 'South America': return Colors.green.shade400;
      case 'Africa': return Colors.brown.shade400;
      case 'Europe': return Colors.yellow.shade700;
      case 'Asia': return Colors.pink.shade300;
      case 'Oceania': return Colors.purple.shade400;
      default: return Colors.grey.shade500;
    }
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required List<Country> visitedCountriesList,
    required int totalCountries,
    required int visitedContinents,
    required int totalContinents,
    required double countryRatio,
    required CountryProvider provider,
  }) {
    final visitedCountries = visitedCountriesList.length;
    final remainingCountries = totalCountries - visitedCountries;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: ['All', ...continentsData.map((e) => e['name'] as String)].length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedContinentOption == 'All';
                final allVisited = provider.filteredCountries
                    .where((c) => provider.visitedCountries.contains(c.name))
                    .length;
                final allTotal = provider.filteredCountries.length;

                return GestureDetector(
                  onTap: () => setState(() => _selectedContinentOption = 'All'),
                  child: Container(
                    width: 90,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.8),
                        ],
                      )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? Theme.of(context).primaryColor.withOpacity(0.3)
                              : Colors.black.withOpacity(0.04),
                          blurRadius: isSelected ? 12 : 8,
                          offset: Offset(0, isSelected ? 4 : 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : Theme.of(context).primaryColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.public,
                            color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$allVisited/$allTotal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final entry = continentsData[index - 1];
              final name = entry['name'] as String;
              final asset = entry['asset'] as String;
              final fullName = name == 'N. America'
                  ? 'North America'
                  : (name == 'S. America' ? 'South America' : name);

              final countries = provider.filteredCountries.where((c) => c.continent == fullName).toList();
              final visited = countries.where((c) => provider.visitedCountries.contains(c.name)).length;
              final total = countries.length;
              final percent = total == 0 ? 0.0 : visited / total;
              final isComplete = percent == 1.0;
              final isSelected = _selectedContinentOption == fullName;

              return GestureDetector(
                onTap: () => setState(() => _selectedContinentOption = fullName),
                child: Container(
                  width: 90,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                      colors: [
                        _getStaticContinentColor(fullName),
                        _getStaticContinentColor(fullName).withOpacity(0.8),
                      ],
                    )
                        : null,
                    color: isSelected
                        ? null
                        : (isComplete
                        ? _getStaticContinentColor(fullName).withOpacity(0.1)
                        : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected || isComplete
                          ? _getStaticContinentColor(fullName)
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? _getStaticContinentColor(fullName).withOpacity(0.4)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: isSelected ? 12 : 8,
                        offset: Offset(0, isSelected ? 4 : 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.2)
                                  : _getStaticContinentColor(fullName).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Image.asset(
                                asset,
                                width: 24,
                                height: 24,
                                color: isSelected ? Colors.white : _getStaticContinentColor(fullName),
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                          ),
                          if (isComplete && !isSelected)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: _getStaticContinentColor(fullName),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$visited/$total',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : _getStaticContinentColor(fullName),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        GestureDetector(
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              builder: (context) => _buildDateFilterSheet(),
            );
            if (selected != null) {
              if (selected == 'Custom') {
                _selectCustomDateRange();
              } else {
                setState(() {
                  _selectedDateRangeOption = selected;
                  _customDateRange = null;
                });
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  _selectedDateRangeOption == 'Custom' && _customDateRange != null
                      ? '${_customDateRange!.start.toLocal().toString().split(' ')[0]} ~ ${_customDateRange!.end.toLocal().toString().split(' ')[0]}'
                      : _selectedDateRangeOption,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        Text(
          _selectedContinentOption == 'All' ? 'World' : _selectedContinentOption,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _selectedContinentOption == 'All'
                ? Theme.of(context).primaryColor
                : provider.continentColors[_selectedContinentOption] ?? Theme.of(context).primaryColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) {
                  return CustomPaint(
                    size: const Size(200, 200),
                    painter: _ArcProgressPainter(
                      progress: countryRatio * value,
                      backgroundColor: Colors.grey.shade200,
                      progressColor: _selectedContinentOption == 'All'
                          ? Theme.of(context).primaryColor
                          : provider.continentColors[_selectedContinentOption] ?? Theme.of(context).primaryColor,
                      strokeWidth: 12,
                    ),
                  );
                },
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<int>(
                    key: ValueKey('$visitedCountries-$_selectedContinentOption'),
                    duration: const Duration(milliseconds: 800),
                    tween: IntTween(begin: 0, end: visitedCountries),
                    builder: (context, value, child) {
                      return Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: _selectedContinentOption == 'All'
                              ? Theme.of(context).primaryColor
                              : provider.continentColors[_selectedContinentOption] ?? Theme.of(context).primaryColor,
                          height: 1,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'of $totalCountries countries',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              Positioned(
                top: 10,
                right: screenWidth / 2 - 115,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('percent-$countryRatio-$_selectedContinentOption'),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutBack,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedContinentOption == 'All'
                              ? Theme.of(context).primaryColor
                              : provider.continentColors[_selectedContinentOption] ?? Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (_selectedContinentOption == 'All'
                                  ? Theme.of(context).primaryColor
                                  : provider.continentColors[_selectedContinentOption] ?? Theme.of(context).primaryColor).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          '${(countryRatio * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        if (remainingCountries > 0)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _selectedContinentOption == 'All'
                      ? const CountriesMapScreen()
                      : CountriesMapScreen(region: _selectedContinentOption),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (_selectedContinentOption == 'All'
                        ? Theme.of(context).primaryColor
                        : provider.continentColors[_selectedContinentOption] ?? Theme.of(context).primaryColor).withOpacity(0.08),
                    Colors.purple.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_selectedContinentOption == 'All'
                          ? Theme.of(context).primaryColor
                          : provider.continentColors[_selectedContinentOption] ?? Theme.of(context).primaryColor).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.explore,
                      color: _selectedContinentOption == 'All'
                          ? Theme.of(context).primaryColor
                          : provider.continentColors[_selectedContinentOption] ?? Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$remainingCountries ${_selectedContinentOption == 'All' ? 'countries' : 'in $_selectedContinentOption'} waiting',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Keep exploring!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),

        if (_selectedContinentOption != 'All') ...[
          const SizedBox(height: 24),
          _buildSubregionList(context, provider, _selectedContinentOption, visitedCountriesList),
        ],
      ],
    );
  }

  void _showSubregionCountriesSheet(
      BuildContext context,
      String subregion,
      List<Country> subCountries,
      Set<String> visitedNames,
      Color themeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          subregion,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${subCountries.where((c) => visitedNames.contains(c.name)).length} / ${subCountries.length}',
                            style: TextStyle(
                              color: themeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: subCountries.length,
                      itemBuilder: (context, index) {
                        final country = subCountries[index];
                        final isVisited = visitedNames.contains(country.name);
                        return ListTile(
                          leading: Text(
                            _getFlagEmoji(country.isoA2),
                            style: const TextStyle(fontSize: 28),
                          ),
                          title: Text(
                            country.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.add_circle_outline, color: themeColor),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CountryDetailScreen(country: country),
                                    ),
                                  );
                                },
                                tooltip: 'View Country Details',
                              ),
                              const SizedBox(width: 4),
                              isVisited
                                  ? Icon(Icons.check_circle_rounded, color: themeColor)
                                  : Icon(Icons.circle_outlined, color: Colors.grey.shade300),
                            ],
                          ),
                        );
                      },
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

  Widget _buildSubregionList(BuildContext context, CountryProvider provider, String continent, List<Country> visitedCountriesList) {
    final countries = provider.filteredCountries.where((c) => c.continent == continent).toList();
    if (countries.isEmpty) return const SizedBox.shrink();

    final subregionMap = <String, List<Country>>{};
    for (var c in countries) {
      final sub = (c.name == 'Iran') ? 'Western Asia' : (c.subregion ?? 'Unknown');
      subregionMap.putIfAbsent(sub, () => []).add(c);
    }

    final subregions = subregionMap.keys.toList()..sort();
    final visitedNames = visitedCountriesList.map((c) => c.name).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subregions.map((subregion) {
        final subCountries = subregionMap[subregion]!;
        final total = subCountries.length;
        final visited = subCountries.where((c) => visitedNames.contains(c.name)).length;
        final progress = total > 0 ? visited / total : 0.0;
        final color = provider.subregionColors[subregion] ?? Colors.grey.shade500;

        return GestureDetector(
          onTap: () => _showSubregionCountriesSheet(context, subregion, subCountries, visitedNames, color),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      subregion,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$visited / $total',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilterPill(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Period', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._dateRangeOptions.map((option) => ListTile(
            title: Text(option),
            trailing: _selectedDateRangeOption == option
                ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                : null,
            onTap: () => Navigator.pop(context, option),
          )),
        ],
      ),
    );
  }

  Widget _buildContinentFilterSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Continent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._continentOptions.map((option) => ListTile(
            title: Text(option),
            trailing: _selectedContinentOption == option
                ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                : null,
            onTap: () => Navigator.pop(context, option),
          )),
        ],
      ),
    );
  }

  Widget _buildContinentGrid(CountryProvider provider) {
    return const SizedBox.shrink();
  }

  Widget _buildIntegratedChartCard(CountryProvider provider, List<Country> filteredCountries, Map<String, EconomyData> economyMap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text('Data Explorer', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAxisSelectors(),
                const SizedBox(height: 12),
                _buildFilterSwitches(),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildScatterChart(provider, filteredCountries, economyMap),
                const SizedBox(height: 36),
                _buildLegend(provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAxisSelectors() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('X', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    borderRadius: BorderRadius.circular(24),
                    value: _xAxisMetric,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    items: const [
                      DropdownMenuItem(value: 'visitCount', child: Text('Visit Count')),
                      DropdownMenuItem(value: 'totalDays', child: Text('Total Days')),
                      DropdownMenuItem(value: 'rating', child: Text('Rating')),
                      DropdownMenuItem(value: 'firstVisitOrder', child: Text('First Visit Order')),
                      DropdownMenuItem(value: 'visitMonth', child: Text('Visit Month')),
                      DropdownMenuItem(value: 'population', child: Text('Population')),
                      DropdownMenuItem(value: 'area', child: Text('Area')),
                      DropdownMenuItem(value: 'gdp', child: Text('GDP')),
                      DropdownMenuItem(value: 'gdpPerCapita', child: Text('GDP per Capita')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _xAxisMetric = value);
                    },
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Log', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 24,
                    width: 32,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch(
                        value: _xLogScale,
                        onChanged: (v) => setState(() => _xLogScale = v),
                        activeColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('Y', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    borderRadius: BorderRadius.circular(24),
                    value: _yAxisMetric,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    items: const [
                      DropdownMenuItem(value: 'visitCount', child: Text('Visit Count')),
                      DropdownMenuItem(value: 'totalDays', child: Text('Total Days')),
                      DropdownMenuItem(value: 'rating', child: Text('Rating')),
                      DropdownMenuItem(value: 'firstVisitOrder', child: Text('First Visit Order')),
                      DropdownMenuItem(value: 'visitMonth', child: Text('Visit Month')),
                      DropdownMenuItem(value: 'population', child: Text('Population')),
                      DropdownMenuItem(value: 'area', child: Text('Area')),
                      DropdownMenuItem(value: 'gdp', child: Text('GDP')),
                      DropdownMenuItem(value: 'gdpPerCapita', child: Text('GDP per Capita')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _yAxisMetric = value);
                    },
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Log', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 24,
                    width: 32,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch(
                        value: _yLogScale,
                        onChanged: (v) => setState(() => _yLogScale = v),
                        activeColor: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSwitches() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip('Home', _includeHome, (value) => setState(() => _includeHome = value)),
        _buildFilterChip('Lived', _includeLived, (value) => setState(() => _includeLived = value)),
        _buildFilterChip('Transfer', _includeTransfer, (value) => setState(() => _includeTransfer = value)),
        _buildFilterChip('Layover', _includeLayover, (value) => setState(() => _includeLayover = value)),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool value, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: value,
      onSelected: onChanged,
      showCheckmark: false,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: value ? Theme.of(context).primaryColor : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildScatterChart(CountryProvider provider, List<Country> filteredCountries, Map<String, EconomyData> economyMap) {
    if (filteredCountries.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const Text('No countries to display.', style: TextStyle(color: Colors.grey)),
      );
    }

    final List<MapEntry<String, DateTime?>> firstVisitDates = [];
    for (var country in filteredCountries) {
      final details = provider.visitDetails[country.name];
      DateTime? earliestDate;
      if (details != null) {
        for (var range in details.visitDateRanges) {
          if (range.arrival != null) {
            if (earliestDate == null || range.arrival!.isBefore(earliestDate)) {
              earliestDate = range.arrival;
            }
          }
        }
      }
      firstVisitDates.add(MapEntry(country.name, earliestDate));
    }

    firstVisitDates.sort((a, b) {
      if (a.value == null && b.value == null) return 0;
      if (a.value == null) return 1;
      if (b.value == null) return -1;
      return a.value!.compareTo(b.value!);
    });

    final Map<String, int> firstVisitOrderMap = {};
    for (int i = 0; i < firstVisitDates.length; i++) {
      firstVisitOrderMap[firstVisitDates[i].key] = i + 1;
    }

    final Map<String, DateTime?> firstVisitDateMap = {
      for (var entry in firstVisitDates) entry.key: entry.value,
    };

    final List<ScatterSpot> spots = [];
    final Map<int, Country> spotIndexToCountry = {};

    for (int i = 0; i < filteredCountries.length; i++) {
      final country = filteredCountries[i];
      final details = provider.visitDetails[country.name];

      if (details == null) continue;

      final earliestVisitDate = firstVisitDateMap[country.name];

      final rawX = _getMetricValue(country, details, _xAxisMetric, firstVisitOrderMap[country.name] ?? 0, economyMap, earliestVisitDate);
      final rawY = _getMetricValue(country, details, _yAxisMetric, firstVisitOrderMap[country.name] ?? 0, economyMap, earliestVisitDate);

      if (rawX == null || rawY == null) continue;

      final xValue = _xLogScale ? (rawX > 0 ? math.log(rawX) / math.ln10 : 0.0) : rawX;
      final yValue = _yLogScale ? (rawY > 0 ? math.log(rawY) / math.ln10 : 0.0) : rawY;

      final color = _getContinentColor(country.continent, provider);

      spots.add(ScatterSpot(
        xValue,
        yValue,
        dotPainter: FlDotCirclePainter(
          color: color,
          radius: 3.5,
        ),
      ));

      spotIndexToCountry[spots.length - 1] = country;
    }

    if (spots.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const Text('No data available for selected metrics', style: TextStyle(color: Colors.grey)),
      );
    }

    final xValues = spots.map((e) => e.x).toList();
    final yValues = spots.map((e) => e.y).toList();

    final maxXValue = xValues.isEmpty ? 0.0 : xValues.reduce((a, b) => a > b ? a : b);
    final maxYValue = yValues.isEmpty ? 0.0 : yValues.reduce((a, b) => a > b ? a : b);

    final finalMaxX = maxXValue == 0 ? (_xLogScale ? 1.0 : 10.0) : (maxXValue * 1.1);
    final finalMaxY = maxYValue == 0 ? (_yLogScale ? 1.0 : 10.0) : (maxYValue * 1.1);

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: ScatterChart(
            ScatterChartData(
              scatterSpots: spots,
              minX: 0,
              maxX: finalMaxX,
              minY: 0,
              maxY: finalMaxY,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: Text(_getAxisLabel(_yAxisMetric), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max) return const SizedBox.shrink();
                      if (value % 1 != 0) return const SizedBox.shrink();

                      double original = _yLogScale ? math.pow(10, value).toDouble() : value;
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(_formatNumber(original), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(_getAxisLabel(_xAxisMetric), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max) return const SizedBox.shrink();
                      if (value % 1 != 0) return const SizedBox.shrink();

                      double original = _xLogScale ? math.pow(10, value).toDouble() : value;
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(_formatNumber(original), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                horizontalInterval: _yLogScale ? 1.0 : (finalMaxY / 5).clamp(1.0, double.infinity),
                verticalInterval: _xLogScale ? 1.0 : (finalMaxX / 5).clamp(1.0, double.infinity),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Colors.grey.shade300, width: 1),
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  top: BorderSide.none,
                  right: BorderSide.none,
                ),
              ),
              scatterTouchData: ScatterTouchData(
                enabled: true,
                touchCallback: (FlTouchEvent event, ScatterTouchResponse? response) {
                  if (response != null && response.touchedSpot != null && event is FlTapUpEvent) {
                    final spot = response.touchedSpot!;
                    final country = spotIndexToCountry[spots.indexOf(spot.spot)];
                    if (country != null) {
                      setState(() {
                        _selectedCountry = country;
                      });
                    }
                  }
                },
                touchTooltipData: ScatterTouchTooltipData(
                  getTooltipItems: (ScatterSpot spot) {
                    final country = spotIndexToCountry[spots.indexOf(spot)];
                    if (country != null) {
                      return ScatterTooltipItem(
                        country.name,
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                    return ScatterTooltipItem('', textStyle: const TextStyle());
                  },
                ),
              ),
            ),
          ),
        ),

        if (_selectedCountry != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
            ),
            child: Row(
              children: [
                Text(
                  _getFlagEmoji(_selectedCountry!.isoA2),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selected Country', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(_selectedCountry!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CountryDetailScreen(country: _selectedCountry!),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.menu_book,
                      size: 24,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCountry = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close, size: 20, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLegend(CountryProvider provider) {
    final continents = [
      'Asia',
      'Europe',
      'Africa',
      'North America',
      'South America',
      'Oceania'
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: continents.map((continent) {
        final color = _getContinentColor(continent, provider);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(continent, style: const TextStyle(fontSize: 11, color: Colors.black87)),
          ],
        );
      }).toList(),
    );
  }

  double? _getMetricValue(
      Country country,
      VisitDetails details,
      String metric,
      int firstVisitOrder,
      Map<String, EconomyData> economyMap,
      DateTime? earliestVisitDate) {
    final economyData = economyMap[country.isoA3];

    switch (metric) {
      case 'visitCount':
        return details.visitCount.toDouble();
      case 'totalDays':
        return details.totalDurationInDays().toDouble();
      case 'rating':
        return details.rating;
      case 'firstVisitOrder':
        return firstVisitOrder > 0 ? firstVisitOrder.toDouble() : null;
      case 'visitMonth':
        return earliestVisitDate?.month.toDouble();
      case 'population':
        return economyData != null
            ? (economyData.population * 1000000)
            : country.populationEst.toDouble();
      case 'area':
        return country.area;
      case 'gdp':
        return economyData?.gdpNominal;
      case 'gdpPerCapita':
        if (economyData != null && economyData.population > 0) {
          return (economyData.gdpNominal * 1e9) /
              (economyData.population * 1e6);
        }
        return 0.0;
      default:
        return null;
    }
  }

  String _getAxisLabel(String metric) {
    switch (metric) {
      case 'visitCount':
        return 'Visit Count';
      case 'totalDays':
        return 'Total Days';
      case 'rating':
        return 'Rating';
      case 'firstVisitOrder':
        return 'First Visit Order';
      case 'visitMonth':
        return 'Visit Month';
      case 'population':
        return 'Population';
      case 'area':
        return 'Area (km²)';
      case 'gdp':
        return 'GDP (billions USD)';
      case 'gdpPerCapita':
        return 'GDP per Capita (USD)';
      default:
        return '';
    }
  }

  Color _getContinentColor(String? continent, CountryProvider provider) {
    if (continent == null) return Colors.grey;
    return provider.continentColors[continent] ?? Colors.grey;
  }
}

class OverviewStatsScreen extends StatelessWidget {
  const OverviewStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const List<Tab> tabs = <Tab>[
      Tab(icon: Icon(Icons.insights), text: 'Overview'),
      Tab(icon: Icon(Icons.groups), text: 'Population'),
      Tab(icon: Icon(Icons.map_outlined), text: 'Area'),
      Tab(icon: Icon(Icons.monetization_on_outlined), text: 'Economy'),
    ];

    const List<Widget> screens = <Widget>[
      OverviewTabScreen(),
      PopulationStatsScreen(),
      AreaStatsScreen(),
      EconomyStatsScreen(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Material(
                elevation: 1,
                child: TabBar(
                  tabs: tabs,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  indicatorSize: TabBarIndicatorSize.label,
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: screens,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewRankingCard extends StatefulWidget {
  final List<Country> countries;
  final CountryProvider provider;
  final bool includeHome;
  final bool includeLived;
  final bool includeTransfer;
  final bool includeLayover;
  final Function(bool) onIncludeHomeChanged;
  final Function(bool) onIncludeLivedChanged;
  final Function(bool) onIncludeTransferChanged;
  final Function(bool) onIncludeLayoverChanged;

  const _OverviewRankingCard({
    required this.countries,
    required this.provider,
    required this.includeHome,
    required this.includeLived,
    required this.includeTransfer,
    required this.includeLayover,
    required this.onIncludeHomeChanged,
    required this.onIncludeLivedChanged,
    required this.onIncludeTransferChanged,
    required this.onIncludeLayoverChanged,
  });

  @override
  State<_OverviewRankingCard> createState() => _OverviewRankingCardState();
}

class _OverviewRankingCardState extends State<_OverviewRankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selectedRanking;

  int _sortOrderSegment = 0;
  String _selectedContinent = 'World';
  List<MapEntry<Country, double>> _rankedList = [];

  final List<String> _continents = [
    'World',
    'Asia',
    'Europe',
    'Africa',
    'North America',
    'South America',
    'Oceania'
  ];

  @override
  void initState() {
    super.initState();
    _rankings = [
      RankingInfo(
          title: 'Visit Count',
          icon: Icons.location_on,
          themeColor: Colors.blue,
          metricKey: 'visitCount'),
      RankingInfo(
          title: 'Total Days',
          icon: Icons.calendar_today,
          themeColor: Colors.amber,
          metricKey: 'totalDays',
          unit: ' days'),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _OverviewRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countries, oldWidget.countries)) {
      _prepareList();
    }
  }

  void _prepareList() {
    List<Country> listToRank = List.from(widget.countries);

    if (_selectedContinent != 'World') {
      listToRank =
          listToRank.where((c) => c.continent == _selectedContinent).toList();
    }

    List<MapEntry<Country, double>> rankedWithValues = [];
    for (var country in listToRank) {
      final details = widget.provider.visitDetails[country.name];
      if (details == null) continue;

      double value = 0;
      switch (_selectedRanking.metricKey) {
        case 'visitCount':
          value = details.visitCount.toDouble();
          break;
        case 'totalDays':
          value = details.totalDurationInDays().toDouble();
          break;
      }
      if (value > 0) {
        rankedWithValues.add(MapEntry(country, value));
      }
    }

    rankedWithValues.sort((a, b) {
      int comparison = a.value.compareTo(b.value);
      return _sortOrderSegment == 0 ? -comparison : comparison;
    });

    if (mounted) {
      setState(() {
        _rankedList = rankedWithValues;
      });
    }
  }

  void _onFilterChanged() => setState(() => _prepareList());

  Widget _buildFilterChip(String label, bool value, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: value,
      onSelected: (newValue) => onChanged(newValue),
      showCheckmark: false,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.25),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildRankText(int rank, Color color) {
    return Text(
      '$rank',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final useDefaultColor = widget.provider.useDefaultRankingBarColor;
    final double maxValue =
    _rankedList.isNotEmpty ? _rankedList.map((e) => e.value).reduce(math.max) : 1.0;

    final rankingThemeColor = _selectedRanking.themeColor;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RankingInfo>(
                      borderRadius: BorderRadius.circular(24),
                      value: _selectedRanking,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down_circle_outlined,
                          color: rankingThemeColor),
                      items: _rankings
                          .map((group) => DropdownMenuItem<RankingInfo>(
                        value: group,
                        child: Row(children: [
                          Icon(group.icon, color: group.themeColor),
                          const SizedBox(width: 12),
                          Text(group.title,
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ]),
                      ))
                          .toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedRanking = newValue;
                            _prepareList();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<int>(value: 0, label: Text('High')),
                          ButtonSegment<int>(value: 1, label: Text('Low')),
                        ],
                        selected: {_sortOrderSegment},
                        onSelectionChanged: (s) {
                          _sortOrderSegment = s.first;
                          _onFilterChanged();
                        },
                        style: SegmentedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          selectedForegroundColor: Colors.white,
                          selectedBackgroundColor: rankingThemeColor.withOpacity(0.8),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          borderRadius: BorderRadius.circular(20),
                          value: _selectedContinent,
                          items: _continents
                              .map((String value) => DropdownMenuItem<String>(
                            value: value,
                            child:
                            Text(value, style: const TextStyle(fontSize: 14)),
                          ))
                              .toList(),
                          onChanged: (String? newValue) {
                            _selectedContinent = newValue!;
                            _onFilterChanged();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 0,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildFilterChip(
                          'Home', widget.includeHome, widget.onIncludeHomeChanged),
                      _buildFilterChip('Lived', widget.includeLived,
                          widget.onIncludeLivedChanged),
                      _buildFilterChip('Transfer', widget.includeTransfer,
                          widget.onIncludeTransferChanged),
                      _buildFilterChip('Layover', widget.includeLayover,
                          widget.onIncludeLayoverChanged),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 350,
            child: _rankedList.isEmpty
                ? const Center(child: Text('No countries to display.'))
                : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _rankedList.length,
              itemBuilder: (context, index) {
                final entry = _rankedList[index];
                final country = entry.key;
                final value = entry.value;
                final rank = index + 1;
                final barColor = useDefaultColor
                    ? rankingThemeColor
                    : widget.provider.continentColors[country.continent] ??
                    rankingThemeColor;
                final progressValue =
                    value.toDouble() / math.max(1.0, maxValue);

                return Card(
                  elevation: 0,
                  color: rankingThemeColor.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CountryDetailScreen(country: country)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildRankText(rank, rankingThemeColor),
                              const SizedBox(width: 8),
                              Text(
                                widget.provider.allCountries
                                    .where((c) => c.name == country.name)
                                    .map((c) {
                                  final base = 0x1F1E6 - 0x41;
                                  return String.fromCharCode(base + c.isoA2.codeUnitAt(0)) +
                                      String.fromCharCode(base + c.isoA2.codeUnitAt(1));
                                })
                                    .firstOrNull ?? '',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(country.name,
                                      style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold))),
                              Text(
                                  '${value.toInt()}${_selectedRanking.unit}',
                                  style: textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LayoutBuilder(
                            builder: (context, constraints) => Stack(
                              children: [
                                Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius:
                                        BorderRadius.circular(3))),
                                Container(
                                    height: 6,
                                    width: constraints.maxWidth *
                                        progressValue,
                                    decoration: BoxDecoration(
                                        color: barColor,
                                        borderRadius:
                                        BorderRadius.circular(3))),
                              ],
                            ),
                          ),
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

class _RatingTierCard extends StatelessWidget {
  final List<Country> countries;
  final CountryProvider provider;

  const _RatingTierCard({
    required this.countries,
    required this.provider,
  });

  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🌐';
    final int firstLetter = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  Color _getTierColor(double tier) {
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final Map<double, List<Country>> countriesByRating = {};
    for (final country in countries.where((c) =>
    provider.visitDetails[c.name]?.rating != null &&
        provider.visitDetails[c.name]!.rating > 0)) {
      final rating = provider.visitDetails[country.name]!.rating;
      if (countriesByRating.containsKey(rating)) {
        countriesByRating[rating]!.add(country);
      } else {
        countriesByRating[rating] = [country];
      }
    }

    final tiers = [5.0, 4.5, 4.0, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0, 0.5];
    final tierWidgets = <Widget>[];

    for (final tier in tiers) {
      final countriesInTier = countriesByRating[tier] ?? [];
      if (countriesInTier.isNotEmpty) {
        final tierColor = _getTierColor(tier);
        tierWidgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 65,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: tierColor, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          tier.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: tierColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: countriesInTier.map((country) {
                        return Tooltip(
                          message: country.name,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CountryDetailScreen(country: country)),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(6.0),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                _getFlagEmoji(country.isoA2),
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (tierWidgets.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(
                          'Rating Tiers',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.amber,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CountryTiersScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Center(
                    child: Text('No countries with ratings to display.', style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 8),
              ],
            )),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Rating Tiers',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.amber,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CountryTiersScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: tierWidgets,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _ArcProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}