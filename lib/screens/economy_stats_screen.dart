// lib/screens/economy_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/economy_data_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/economy_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart'; // 상세 화면 임포트 추가
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:collection/collection.dart';

// Helper: ISO A2 → 국기 이모지
String flagEmoji(String isoA2) {
  if (isoA2.length != 2) return '';
  final base = 0x1F1E6 - 0x41;
  return String.fromCharCode(base + isoA2.codeUnitAt(0)) +
      String.fromCharCode(base + isoA2.codeUnitAt(1));
}

// Helper: 국가 클릭시 CountryDetailScreen으로 이동
void navigateToCountryDetail(BuildContext context, Country country) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CountryDetailScreen(country: country)),
  );
}

class RankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final double Function(EconomyData, Map<String, dynamic>) valueAccessor;
  final String unit;
  final int precision;

  RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.valueAccessor,
    this.unit = '',
    this.precision = 0,
  });
}

class SpecialGroupInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final List<String> memberCodes;
  final String mapLegend;

  SpecialGroupInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.memberCodes,
    required this.mapLegend,
  });
}

class EconomyStatsScreen extends StatefulWidget {
  const EconomyStatsScreen({super.key});

  @override
  State<EconomyStatsScreen> createState() => _EconomyStatsScreenState();
}

class _EconomyStatsScreenState extends State<EconomyStatsScreen> {
  Map<String, double> _giniIndexData = {};
  bool _isLoadingGini = true;
  Map<String, double> _goldReservesData = {};
  bool _isLoadingGold = true;

  String? _goldError;
  String? _giniError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EconomyProvider>(context, listen: false).loadEconomyData();
      _loadGiniData();
      _loadGoldData();
    });
  }

  Future<void> _loadGoldData() async {
    try {
      final String response = await rootBundle.loadString('assets/gold.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _goldReservesData = {
          for (var item in data)
            item['iso_a3'] as String: (item['gold'] as num).toDouble()
        };
        _goldError = null;
      });
    } catch (e) {
      final String errorMessage = 'Gold Reserves Error: $e';
      debugPrint(errorMessage);
      setState(() {
        _goldError = errorMessage;
      });
    } finally {
      setState(() {
        _isLoadingGold = false;
      });
    }
  }

  Future<void> _loadGiniData() async {
    try {
      final String response = await rootBundle.loadString('assets/gini_data.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _giniIndexData = {
          for (var item in data)
            item['iso_a3'] as String: (item['gini_index'] as num).toDouble()
        };
        _giniError = null;
      });
    } catch (e) {
      final String errorMessage = 'Gini Index Error: $e';
      debugPrint(errorMessage);
      setState(() {
        _giniError = errorMessage;
      });
    } finally {
      setState(() {
        _isLoadingGini = false;
      });
    }
  }

  Widget _buildErrorWidget(String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          error!,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea( // 상단바 겹침 방지
        bottom: false,
        child: Consumer2<EconomyProvider, CountryProvider>(
          builder: (context, economyProvider, countryProvider, child) {
            if (economyProvider.isLoading || countryProvider.isLoading || _isLoadingGini || _isLoadingGold) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_goldError != null) return _buildErrorWidget(_goldError);
            if (_giniError != null) return _buildErrorWidget(_giniError);

            final allEconomyData = economyProvider.economyData;
            final visitedCountryNames = countryProvider.visitedCountries;
            final filteredCountries = countryProvider.filteredCountries;

            final allowedIsoA3s = filteredCountries.map((c) => c.isoA3).toSet();
            final filteredEconomyData = allEconomyData.where((e) => allowedIsoA3s.contains(e.isoA3)).toList();

            final Map<String, String> isoA3ToCountryNameMap = {
              for (var country in filteredCountries)
                country.isoA3: country.name
            };

            final Map<String, Country> isoA3ToCountryMap = {
              for (var country in filteredCountries)
                country.isoA3: country
            };

            final extraData = {
              'gini': _giniIndexData,
              'gold': _goldReservesData,
              'trivia': economyProvider.economicsTriviaData,
            };

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TotalGdpCard(allData: filteredEconomyData, visitedNames: visitedCountryNames, isoA3ToCountryNameMap: isoA3ToCountryNameMap),
                  const SizedBox(height: 24),
                  _GdpByContinentCard(allData: filteredEconomyData, visitedNames: visitedCountryNames, isoA3ToCountryNameMap: isoA3ToCountryNameMap),
                  const SizedBox(height: 24),
                  _AverageGdpCard(allData: filteredEconomyData, visitedNames: visitedCountryNames, isoA3ToCountryNameMap: isoA3ToCountryNameMap),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 600,
                    child: _CombinedRankingCard(
                      allData: filteredEconomyData,
                      visitedNames: visitedCountryNames,
                      isoA3ToCountryNameMap: isoA3ToCountryNameMap,
                      isoA3ToCountryMap: isoA3ToCountryMap, // 추가 전달
                      extraData: extraData,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _DevelopmentStatusSection(
                    allData: filteredEconomyData,
                    visitedNames: visitedCountryNames,
                    isoA3ToCountryNameMap: isoA3ToCountryNameMap,
                    isoA3ToCountryMap: isoA3ToCountryMap,
                  ),
                  const SizedBox(height: 24),
                  _CombinedSpecialGroupCard(
                    allData: filteredEconomyData,
                    visitedNames: visitedCountryNames,
                    isoA3ToCountryNameMap: isoA3ToCountryNameMap,
                    isoA3ToCountryMap: isoA3ToCountryMap, // 추가 전달
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DevelopmentStatusSection extends StatefulWidget {
  final List<EconomyData> allData;
  final Set<String> visitedNames;
  final Map<String, String> isoA3ToCountryNameMap;
  final Map<String, Country> isoA3ToCountryMap;

  const _DevelopmentStatusSection({
    required this.allData,
    required this.visitedNames,
    required this.isoA3ToCountryNameMap,
    required this.isoA3ToCountryMap,
  });

  @override
  State<_DevelopmentStatusSection> createState() => _DevelopmentStatusSectionState();
}

class _DevelopmentStatusSectionState extends State<_DevelopmentStatusSection> {
  String? _expandedStatus = null;

  final Map<String, Color> _statusColors = const {
    'Developed': Color(0xFF000080),
    'Developing': Color(0xFFFFD700),
    'Underdeveloped': Color(0xFFFF0000),
  };

  final Map<String, String> _statusLegends = const {
    'Developed': 'Developed Countries',
    'Developing': 'Developing Countries',
    'Underdeveloped': 'Underdeveloped Countries',
  };

  final List<String> _sortedStatuses = const ['Developed', 'Developing', 'Underdeveloped'];

  String _mapStatusToKey(String? status) {
    switch (status) {
      case 'Developed':
        return 'Developed';
      case 'Developing':
        return 'Developing';
      case 'Underdeveloped':
        return 'Underdeveloped';
      default:
        return 'Unknown';
    }
  }

  void _toggleStatus(String statusTitle) {
    setState(() {
      if (_expandedStatus == statusTitle) {
        _expandedStatus = null;
      }
      else {
        _expandedStatus = statusTitle;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Map<String, List<EconomyData>> groupedDataByStatus = {};
    for (var status in _statusColors.keys) {
      groupedDataByStatus[status] = [];
    }

    for (var data in widget.allData) {
      final mappedStatus = _mapStatusToKey(data.developmentStatus);
      if (groupedDataByStatus.containsKey(mappedStatus)) {
        groupedDataByStatus[mappedStatus]!.add(data);
      }
    }

    final Map<String, List<Country>> groupedCountriesByStatus = {};
    groupedDataByStatus.forEach((key, value) {
      groupedCountriesByStatus[key] = value
          .map((e) => widget.isoA3ToCountryMap[e.isoA3])
          .whereNotNull()
          .toList();
    });

    final List<Widget> statusTiles = _sortedStatuses.map((title) {
      final countries = groupedCountriesByStatus[title] ?? [];
      if (countries.isEmpty) return const SizedBox.shrink();

      final total = countries.length;
      final visited = countries.where((c) => widget.visitedNames.contains(c.name)).length;
      final percentage = total > 0 ? (visited / total) : 0.0;
      final statusColor = _statusColors[title] ?? theme.primaryColor;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
        child: _StatusTile(
          title: title,
          countries: countries,
          visitedNames: widget.visitedNames,
          percentage: percentage,
          color: statusColor,
          isExpanded: _expandedStatus == title,
          onToggle: _toggleStatus,
        ),
      );
    }).toList();


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.lightBlue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
              label: const Text(
                'Development Status Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                final List<HighlightGroup> highlightGroups = [];
                for (var status in _sortedStatuses) {
                  final countries = groupedDataByStatus[status];
                  if (countries != null && countries.isNotEmpty) {
                    highlightGroups.add(HighlightGroup(
                      name: _statusLegends[status] ?? status,
                      color: _statusColors[status] ?? Colors.grey,
                      countryCodes: countries.map((e) => e.isoA3).toList(),
                    ));
                  }
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => CountriesMapScreen(highlightGroups: highlightGroups)));
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: statusTiles,
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String title;
  final List<Country> countries;
  final Set<String> visitedNames;
  final double percentage;
  final Color color;
  final bool isExpanded;
  final Function(String) onToggle;

  const _StatusTile({
    required this.title,
    required this.countries,
    required this.visitedNames,
    required this.percentage,
    required this.color,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = countries.length;
    final visited = countries.where((c) => visitedNames.contains(c.name)).length;
    List<Country> sortedCountries = List.from(countries)..sort((a,b) => a.name.compareTo(b.name));

    return Container(
      decoration: BoxDecoration(
        color: isExpanded ? color.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? color.withOpacity(0.3) : Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? color.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => onToggle(title),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: isExpanded ? FontWeight.w900 : FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(percentage * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$visited / $total Countries',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 6,
                          backgroundColor: color.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              child: !isExpanded ? null : Column(
                children: [
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: sortedCountries.length,
                      itemBuilder: (context, index) {
                        final country = sortedCountries[index];
                        final isVisited = visitedNames.contains(country.name);
                        return InkWell( // 상세 페이지 연결 적용
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => navigateToCountryDetail(context, country),
                          child: Row(
                            children: [
                              Icon(
                                isVisited ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: isVisited ? color : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)), // 국기 추가
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  country.name,
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
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
            ),
          )
        ],
      ),
    );
  }
}

class _TotalGdpCard extends StatefulWidget {
  final List<EconomyData> allData;
  final Set<String> visitedNames;
  final Map<String, String> isoA3ToCountryNameMap;
  const _TotalGdpCard({super.key, required this.allData, required this.visitedNames, required this.isoA3ToCountryNameMap});

  @override
  State<_TotalGdpCard> createState() => _TotalGdpCardState();
}

class _TotalGdpCardState extends State<_TotalGdpCard> {
  bool _isPpp = false;

  @override
  Widget build(BuildContext context) {
    final visitedData = widget.allData.where((e) => widget.visitedNames.contains(widget.isoA3ToCountryNameMap[e.isoA3] ?? e.name)).toList();
    final totalVisitedGdp = visitedData.fold<double>(0, (sum, item) => sum + (_isPpp ? item.gdpPpp : item.gdpNominal));
    final totalWorldGdp = widget.allData.fold<double>(0, (sum, item) => sum + (_isPpp ? item.gdpPpp : item.gdpNominal));
    final gdpPercentage = totalWorldGdp > 0 ? (totalVisitedGdp / totalWorldGdp * 100) : 0.0;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -20, child: Icon(Icons.monetization_on_outlined, size: 150, color: primaryColor.withOpacity(0.05))),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Global Wealth', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade500, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('Total GDP', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
                    ]),
                    Row(
                      children: [
                        Text('PPP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isPpp ? primaryColor : Colors.grey)),
                        Switch(
                            value: _isPpp,
                            activeColor: primaryColor,
                            onChanged: (val) => setState(() => _isPpp = val)
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildStatRow(context, label: 'Visited GDP', value: '\$${(totalVisitedGdp / 1000).toStringAsFixed(2)}T', color: primaryColor, icon: Icons.check_circle_outline),
                          const SizedBox(height: 16),
                          _buildStatRow(context, label: 'World GDP', value: '\$${(totalWorldGdp / 1000).toStringAsFixed(2)}T', color: Colors.grey.shade400, icon: Icons.public),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: SleekCircularSlider(
                          initialValue: gdpPercentage,
                          min: 0, max: 100,
                          appearance: CircularSliderAppearance(
                            customWidths: CustomSliderWidths(trackWidth: 8, progressBarWidth: 12, handlerSize: 0, shadowWidth: 0),
                            customColors: CustomSliderColors(trackColor: Colors.grey.shade100, progressBarColors: [primaryColor, primaryColor.withOpacity(0.6)], dynamicGradient: true),
                            infoProperties: InfoProperties(mainLabelStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor), modifier: (double value) => "${value.toStringAsFixed(1)}%"),
                            size: 110, angleRange: 360, startAngle: 270,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, {required String label, required String value, required Color color, required IconData icon}) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis),
          ]),
        ),
      ],
    );
  }
}

class _GdpByContinentCard extends StatefulWidget {
  final List<EconomyData> allData;
  final Set<String> visitedNames;
  final Map<String, String> isoA3ToCountryNameMap;
  const _GdpByContinentCard({super.key, required this.allData, required this.visitedNames, required this.isoA3ToCountryNameMap});

  @override
  State<_GdpByContinentCard> createState() => _GdpByContinentCardState();
}

class _GdpByContinentCardState extends State<_GdpByContinentCard> {
  bool _isPpp = false;
  static final List<Map<String, Object>> continentsData = [
    {'name': 'Asia', 'fullName': 'Asia', 'asset': 'assets/icons/asia.png', 'color': Colors.pink.shade200},
    {'name': 'Europe', 'fullName': 'Europe', 'asset': 'assets/icons/europe.png', 'color': Colors.amber},
    {'name': 'Africa', 'fullName': 'Africa', 'asset': 'assets/icons/africa.png', 'color': Colors.brown},
    {'name': 'N. America', 'fullName': 'North America', 'asset': 'assets/icons/n_america.png', 'color': Colors.blue.shade200},
    {'name': 'S. America', 'fullName': 'South America', 'asset': 'assets/icons/s_america.png', 'color': Colors.green},
    {'name': 'Oceania', 'fullName': 'Oceania', 'asset': 'assets/icons/oceania.png', 'color': Colors.purple},
  ];

  @override
  Widget build(BuildContext context) {
    final compactFormatter = NumberFormat.compact(locale: 'en_US');
    final Map<String, double> totalGdpByContinent = {};
    final Map<String, double> visitedGdpByContinent = {};

    for (var data in continentsData) {
      final fullName = data['fullName'] as String;
      totalGdpByContinent[fullName] = 0;
      visitedGdpByContinent[fullName] = 0;
    }

    for (var countryData in widget.allData) {
      if (countryData.continent != null && totalGdpByContinent.containsKey(countryData.continent)) {
        final gdpValue = _isPpp ? countryData.gdpPpp : countryData.gdpNominal;
        totalGdpByContinent.update(countryData.continent!, (v) => v + gdpValue);
        if (widget.visitedNames.contains(widget.isoA3ToCountryNameMap[countryData.isoA3] ?? countryData.name)) {
          visitedGdpByContinent.update(countryData.continent!, (v) => v + gdpValue);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GDP by Continent', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
              Row(children: [
                Text('PPP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isPpp ? Theme.of(context).primaryColor : Colors.grey)),
                Switch(value: _isPpp, activeColor: Theme.of(context).primaryColor, onChanged: (val) => setState(() => _isPpp = val)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4),
          itemCount: continentsData.length,
          itemBuilder: (context, index) {
            final data = continentsData[index];
            final name = data['name'] as String;
            final asset = data['asset'] as String;
            final fullName = data['fullName'] as String;
            final color = data['color'] as Color;

            final visitedGdp = visitedGdpByContinent[fullName] ?? 0;
            final totalGdp = totalGdpByContinent[fullName] ?? 0;
            final percent = totalGdp == 0 ? 0.0 : visitedGdp / totalGdp;

            return Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))]),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Image.asset(asset, width: 16, height: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${(percent * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                      Flexible(child: Text('\$${compactFormatter.format(visitedGdp * 1e9)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: percent, minHeight: 6, backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color))),
                  ]),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AverageGdpCard extends StatefulWidget {
  final List<EconomyData> allData;
  final Set<String> visitedNames;
  final Map<String, String> isoA3ToCountryNameMap;
  const _AverageGdpCard({super.key, required this.allData, required this.visitedNames, required this.isoA3ToCountryNameMap});

  @override
  State<_AverageGdpCard> createState() => _AverageGdpCardState();
}

class _AverageGdpCardState extends State<_AverageGdpCard> {
  bool _isPpp = false;

  @override
  Widget build(BuildContext context) {
    final numberFormatter = NumberFormat.decimalPattern('en_US');
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = Theme.of(context).primaryColor;

    final visitedData = widget.allData.where((e) => widget.visitedNames.contains(widget.isoA3ToCountryNameMap[e.isoA3] ?? e.name)).toList();
    final totalVisitedGdp = visitedData.fold<double>(0, (sum, item) => sum + (_isPpp ? item.gdpPpp : item.gdpNominal));
    final totalVisitedPopulation = visitedData.fold<double>(0, (sum, item) => sum + item.population);
    final avgVisitedGdpPerCapita = totalVisitedPopulation > 0 ? (totalVisitedGdp * 1e9) / (totalVisitedPopulation * 1e6) : 0.0;
    final totalWorldGdp = widget.allData.fold<double>(0, (sum, item) => sum + (_isPpp ? item.gdpPpp : item.gdpNominal));
    final totalWorldPopulation = widget.allData.fold<double>(0, (sum, item) => sum + item.population);
    final avgWorldGdpPerCapita = totalWorldPopulation > 0 ? (totalWorldGdp * 1e9) / (totalWorldPopulation * 1e6) : 0.0;
    final maxValue = math.max(avgVisitedGdpPerCapita, avgWorldGdpPerCapita);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Average GDP per Capita', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
              Row(children: [
                Text('PPP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isPpp ? primaryColor : Colors.grey)),
                Switch(value: _isPpp, activeColor: primaryColor, onChanged: (val) => setState(() => _isPpp = val)),
              ]),
            ],
          ),
          const SizedBox(height: 24),
          _buildHorizontalBar(context: context, label: 'Visited', value: avgVisitedGdpPerCapita, maxValue: maxValue, color: primaryColor, formattedValue: '\$${numberFormatter.format(avgVisitedGdpPerCapita.round())}', icon: Icons.flight_takeoff),
          const SizedBox(height: 16),
          _buildHorizontalBar(context: context, label: 'World', value: avgWorldGdpPerCapita, maxValue: maxValue, color: Colors.grey.shade400, formattedValue: '\$${numberFormatter.format(avgWorldGdpPerCapita.round())}', icon: Icons.public),
        ],
      ),
    );
  }

  Widget _buildHorizontalBar({required BuildContext context, required String label, required double value, required double maxValue, required Color color, required String formattedValue, required IconData icon}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barMaxWidth = constraints.maxWidth - 100;
        final barWidth = math.max(4.0, (value / (maxValue == 0 ? 1 : maxValue)) * barMaxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: color), const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
              const Spacer(),
              Text(formattedValue, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
            ]),
            const SizedBox(height: 8),
            Container(
              height: 12, width: double.infinity,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic, width: barWidth, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))])),
            ),
          ],
        );
      },
    );
  }
}

class _CombinedRankingCard extends StatefulWidget {
  final List<EconomyData> allData;
  final Set<String> visitedNames;
  final Map<String, String> isoA3ToCountryNameMap;
  final Map<String, Country> isoA3ToCountryMap; // 추가됨
  final Map<String, dynamic> extraData;

  const _CombinedRankingCard({
    required this.allData,
    required this.visitedNames,
    required this.isoA3ToCountryNameMap,
    required this.isoA3ToCountryMap,
    required this.extraData,
  });

  @override
  State<_CombinedRankingCard> createState() => _CombinedRankingCardState();
}

class _CombinedRankingCardState extends State<_CombinedRankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selectedRanking;

  int _displaySegment = 0;
  int _sortOrderSegment = 0;
  String _selectedContinent = 'World';
  List<EconomyData> _rankedList = [];

  final List<String> _continents = ['World', 'Asia', 'Europe', 'Africa', 'North America', 'South America', 'Oceania'];
  static final Map<String, Color> _continentColors = {
    'Asia': Colors.pink.shade200, 'Europe': Colors.amber, 'Africa': Colors.brown,
    'North America': Colors.blue.shade200, 'South America': Colors.green, 'Oceania': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _rankings = [
      RankingInfo(title: 'GDP (Nominal)', icon: Icons.monetization_on, themeColor: Colors.green, valueAccessor: (e, _) => e.gdpNominal * 1e9),
      RankingInfo(title: 'GDP (PPP)', icon: Icons.account_balance_wallet, themeColor: Colors.lightGreen, valueAccessor: (e, _) => e.gdpPpp * 1e9),
      RankingInfo(
          title: 'GDP per Capita (Nominal)', icon: Icons.person, themeColor: Colors.blue,
          valueAccessor: (e, _) => e.population > 0 ? (e.gdpNominal * 1e9) / (e.population * 1e6) : 0
      ),
      RankingInfo(
          title: 'GDP per Capita (PPP)', icon: Icons.people, themeColor: Colors.lightBlue,
          valueAccessor: (e, _) => e.population > 0 ? (e.gdpPpp * 1e9) / (e.population * 1e6) : 0
      ),
      RankingInfo(title: 'Gold Reserves', icon: Icons.savings_outlined, themeColor: Colors.amber.shade700, valueAccessor: (e, extra) => (extra['gold'] as Map<String, double>?)?[e.isoA3] ?? 0.0, precision: 0, unit: ' t'),
      RankingInfo(title: 'Gini Index', icon: Icons.compare_arrows, themeColor: Colors.orange, valueAccessor: (e, extra) => (extra['gini'] as Map<String, double>?)?[e.isoA3] ?? 0.0, precision: 1),

      // Agriculture
      RankingInfo(title: 'Rice Production', icon: Icons.grain, themeColor: Colors.teal.shade300, valueAccessor: (e, extra) => (extra['trivia']?['rice'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Wheat Production', icon: Icons.grass, themeColor: Colors.amber.shade400, valueAccessor: (e, extra) => (extra['trivia']?['wheat'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Barley Production', icon: Icons.local_drink, themeColor: Colors.orange.shade400, valueAccessor: (e, extra) => (extra['trivia']?['barley'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Maize Production', icon: Icons.agriculture, themeColor: Colors.yellow.shade700, valueAccessor: (e, extra) => (extra['trivia']?['maize'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Coffee Production', icon: Icons.local_cafe, themeColor: Colors.brown, valueAccessor: (e, extra) => (extra['trivia']?['coffee'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Cocoa Production', icon: Icons.cookie, themeColor: Colors.brown.shade900, valueAccessor: (e, extra) => (extra['trivia']?['cocoa'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Banana Production', icon: Icons.eco, themeColor: Colors.yellow.shade600, valueAccessor: (e, extra) => (extra['trivia']?['banana'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Apple Production', icon: Icons.local_florist, themeColor: Colors.red, valueAccessor: (e, extra) => (extra['trivia']?['apple'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),

      // Livestock
      RankingInfo(title: 'Beef Production', icon: Icons.restaurant, themeColor: Colors.red.shade900, valueAccessor: (e, extra) => (extra['trivia']?['beef'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Pork Production', icon: Icons.restaurant_menu, themeColor: Colors.pink.shade300, valueAccessor: (e, extra) => (extra['trivia']?['pork'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Chicken Production', icon: Icons.pets, themeColor: Colors.orange.shade300, valueAccessor: (e, extra) => (extra['trivia']?['chicken'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Milk Production', icon: Icons.local_drink, themeColor: Colors.blueGrey, valueAccessor: (e, extra) => (extra['trivia']?['milk'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Eggs Production', icon: Icons.egg, themeColor: Colors.amber.shade100, valueAccessor: (e, extra) => (extra['trivia']?['eggs'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),

      // Other Ag
      RankingInfo(title: 'Tea Production', icon: Icons.emoji_food_beverage, themeColor: Colors.green.shade800, valueAccessor: (e, extra) => (extra['trivia']?['tea'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Cotton Production', icon: Icons.checkroom, themeColor: Colors.grey.shade400, valueAccessor: (e, extra) => (extra['trivia']?['cotton'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),

      // Resources
      RankingInfo(title: 'Gold Production', icon: Icons.monetization_on, themeColor: Colors.amber, valueAccessor: (e, extra) => (extra['trivia']?['gold'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Silver Production', icon: Icons.monetization_on_outlined, themeColor: Colors.blueGrey.shade200, valueAccessor: (e, extra) => (extra['trivia']?['silver'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Copper Production', icon: Icons.cable, themeColor: Colors.deepOrangeAccent, valueAccessor: (e, extra) => (extra['trivia']?['copper'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Iron Ore Production', icon: Icons.build, themeColor: Colors.black54, valueAccessor: (e, extra) => (extra['trivia']?['iron_ore'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Diamond Production', icon: Icons.diamond, themeColor: Colors.cyanAccent, valueAccessor: (e, extra) => (extra['trivia']?['diamond'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' carats'),
      RankingInfo(title: 'Crude Oil Production', icon: Icons.oil_barrel, themeColor: Colors.black, valueAccessor: (e, extra) => (extra['trivia']?['crude_oil'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' bbl/d'),
      RankingInfo(title: 'Natural Gas Production', icon: Icons.propane, themeColor: Colors.blue.shade900, valueAccessor: (e, extra) => (extra['trivia']?['natural_gas'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' bcm'),
      RankingInfo(title: 'Coal Production', icon: Icons.fireplace, themeColor: Colors.grey.shade800, valueAccessor: (e, extra) => (extra['trivia']?['coal'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),
      RankingInfo(title: 'Uranium Production', icon: Icons.science, themeColor: Colors.greenAccent.shade700, valueAccessor: (e, extra) => (extra['trivia']?['uranium'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' t'),

      // Industrial / Tech
      RankingInfo(title: 'Car Production', icon: Icons.directions_car, themeColor: Colors.indigo, valueAccessor: (e, extra) => (extra['trivia']?['car_production'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: 'M units', precision: 1),
      RankingInfo(title: 'Phone Production', icon: Icons.smartphone, themeColor: Colors.deepPurple, valueAccessor: (e, extra) => (extra['trivia']?['phone_production'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: 'M units', precision: 0),

      // Finance
      RankingInfo(title: 'Bitcoin Ownership', icon: Icons.currency_bitcoin, themeColor: Colors.orange, valueAccessor: (e, extra) => (extra['trivia']?['bitcoin_ownership_estimated_high'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: '%', precision: 1),
      RankingInfo(title: 'USD Reserves', icon: Icons.attach_money, themeColor: Colors.green, valueAccessor: (e, extra) => (extra['trivia']?['usd_reserves'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: 'B', precision: 0),

      // Consumption
      RankingInfo(title: 'Chicken Consumption', icon: Icons.restaurant, themeColor: Colors.orangeAccent, valueAccessor: (e, extra) => (extra['trivia']?['chicken_consumption'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' kg/capita', precision: 0),
      RankingInfo(title: 'Beef Consumption', icon: Icons.restaurant, themeColor: Colors.redAccent, valueAccessor: (e, extra) => (extra['trivia']?['beef_consumption'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' kg/capita', precision: 0),
      RankingInfo(title: 'Pork Consumption', icon: Icons.restaurant, themeColor: Colors.pinkAccent, valueAccessor: (e, extra) => (extra['trivia']?['pork_consumption'] as Map<String, double>?)?[e.isoA3] ?? 0.0, unit: ' kg/capita', precision: 0),

    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _CombinedRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allData != oldWidget.allData || widget.visitedNames != oldWidget.visitedNames || widget.extraData != oldWidget.extraData) {
      _prepareList();
    }
  }

  void _prepareList() {
    List<EconomyData> listToRank;
    if (_displaySegment == 1) listToRank = widget.allData.where((c) => widget.visitedNames.contains(widget.isoA3ToCountryNameMap[c.isoA3] ?? c.name)).toList();
    else listToRank = List.from(widget.allData);

    if (_selectedContinent != 'World') listToRank = listToRank.where((c) => c.continent == _selectedContinent).toList();

    listToRank = listToRank.where((c) {
      final value = _selectedRanking.valueAccessor(c, widget.extraData);
      return value > 0;
    }).toList();

    listToRank.sort((a, b) {
      final valA = _selectedRanking.valueAccessor(a, widget.extraData);
      final valB = _selectedRanking.valueAccessor(b, widget.extraData);
      return _sortOrderSegment == 0 ? valB.compareTo(valA) : valA.compareTo(valB);
    });

    if (mounted) setState(() { _rankedList = listToRank; });
  }

  void _onFilterChanged() => setState(() => _prepareList());

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final useDefaultColor = countryProvider.useDefaultRankingBarColor;
    final double maxValue = _rankedList.isNotEmpty ? _rankedList.map((c) => _selectedRanking.valueAccessor(c, widget.extraData)).reduce(math.max) : 1.0;

    final rankingThemeColor = _selectedRanking.themeColor;

    final isGdp = _selectedRanking.title.contains('GDP (');
    final numberFormatter = isGdp ? NumberFormat.compact(locale: 'en_US') : NumberFormat.decimalPattern('en_US');


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
                DropdownButtonHideUnderline(
                  child: DropdownButton<RankingInfo>(
                    borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
                    value: _selectedRanking, isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, color: rankingThemeColor),
                    items: _rankings.map((group) => DropdownMenuItem<RankingInfo>(
                      value: group,
                      child: Row(children: [
                        Icon(group.icon, color: group.themeColor),
                        const SizedBox(width: 12),
                        Text(group.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                    )).toList(),
                    onChanged: (newValue) { if (newValue != null) { setState(() { _selectedRanking = newValue; _prepareList(); }); } },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [ButtonSegment<int>(value: 0, label: Text('All')), ButtonSegment<int>(value: 1, label: Text('Visited'))],
                          selected: {_displaySegment},
                          onSelectionChanged: (s) { _displaySegment = s.first; _onFilterChanged(); },
                          style: SegmentedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            selectedForegroundColor: Colors.white,
                            selectedBackgroundColor: rankingThemeColor.withOpacity(0.8),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300, width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                          ),
                        )
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [ButtonSegment<int>(value: 0, label: Text('High')), ButtonSegment<int>(value: 1, label: Text('Low'))],
                          selected: {_sortOrderSegment},
                          onSelectionChanged: (s) { _sortOrderSegment = s.first; _onFilterChanged(); },
                          style: SegmentedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            selectedForegroundColor: Colors.white,
                            selectedBackgroundColor: rankingThemeColor.withOpacity(0.8),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300, width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                          ),
                        )
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButton<String>(
                    borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
                    value: _selectedContinent,
                    items: _continents.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (String? newValue) { _selectedContinent = newValue!; _onFilterChanged(); },
                    underline: const SizedBox(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _rankedList.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No data to display.\n\nIf you selected Gold, Gini, or Trivia, ensure the data files (gold.json, gini_data.json, economics_trivia.json) are correctly placed in the \'assets\' folder and registered in pubspec.yaml, then restart the app.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _rankedList.length,
              itemBuilder: (context, index) {
                final country = _rankedList[index];
                final countryObj = widget.isoA3ToCountryMap[country.isoA3]; // Country 객체 가져오기
                final displayName = widget.isoA3ToCountryNameMap[country.isoA3] ?? country.name;
                final isVisited = widget.visitedNames.contains(displayName);
                final rank = index + 1;
                final value = _selectedRanking.valueAccessor(country, widget.extraData);
                final barColor = useDefaultColor ? rankingThemeColor : (_continentColors[country.continent] ?? rankingThemeColor);
                final progressValue = value.toDouble() / math.max(1.0, maxValue);

                final formattedValue = isGdp
                    ? '\$${numberFormatter.format(value)}'
                    : (_selectedRanking.title.contains('Capita')
                    ? '\$${numberFormatter.format(value.round())}'
                    : '${numberFormatter.format(double.parse(value.toStringAsFixed(_selectedRanking.precision)))} ${_selectedRanking.unit}');

                return Card(
                  elevation: 0,
                  color: isVisited ? rankingThemeColor.withOpacity(0.12) : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell( // 상세 페이지 연결
                    borderRadius: BorderRadius.circular(12),
                    onTap: countryObj != null ? () => navigateToCountryDetail(context, countryObj) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('$rank', style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                              const SizedBox(width: 12),
                              if (countryObj != null) ...[
                                Text(flagEmoji(countryObj.isoA2), style: const TextStyle(fontSize: 18)), // 국기 추가
                                const SizedBox(width: 8),
                              ],
                              Expanded(child: Text(displayName, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                              Text(formattedValue, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LayoutBuilder(
                            builder: (context, constraints) => Stack(
                              children: [
                                Container(height: 6, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3))),
                                Container(height: 6, width: constraints.maxWidth * progressValue, decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(3))),
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

class _CombinedSpecialGroupCard extends StatefulWidget {
  final List<EconomyData> allData;
  final Set<String> visitedNames;
  final Map<String, String> isoA3ToCountryNameMap;
  final Map<String, Country> isoA3ToCountryMap; // 추가됨

  const _CombinedSpecialGroupCard({
    required this.allData,
    required this.visitedNames,
    required this.isoA3ToCountryNameMap,
    required this.isoA3ToCountryMap,
  });

  @override
  State<_CombinedSpecialGroupCard> createState() => _CombinedSpecialGroupCardState();
}

class _CombinedSpecialGroupCardState extends State<_CombinedSpecialGroupCard> {
  late final List<SpecialGroupInfo> _groups;
  late SpecialGroupInfo _selectedGroup;
  bool _isExpanded = false;

  static const List<String> _noIncomeTaxCountryCodes = ['ARE', 'BHR', 'BRN', 'MCO', 'BHS', 'BMU', 'CYM', 'VGB', 'TCA', 'KNA', 'AIA', 'VUT', 'WLF', 'ESH', 'SOM'];
  static const List<String> _noCorporateTaxCountryCodes = ['BLZ', 'BMU', 'VGB', 'CYM', 'GGY', 'IMN', 'JEY', 'BLM', 'TCA', 'VUT', 'WLF'];
  static const List<String> _noVatCountryCodes = ['ATG', 'BHS', 'BHR', 'BMU', 'VGB', 'BRN', 'CYM', 'GGY', 'IMN', 'JEY', 'MCO', 'QAT', 'BLM', 'KNA', 'SOM', 'TCA', 'ARE', 'VUT', 'WLF', 'ESH'];
  static const List<String> _carbonTaxCountryCodes = ['ARG', 'CAN', 'CHL', 'CHN', 'COL', 'DNK', 'EST', 'FIN', 'FRA', 'ISL', 'IRL', 'JPN', 'KAZ', 'KOR', 'LVA', 'LIE', 'LUX', 'MEX', 'NLD', 'NZL', 'NOR', 'SGP', 'SVN', 'ZAF', 'ESP', 'SWE', 'CHE', 'UKR', 'GBR'];


  @override
  void initState() {
    super.initState();
    final allIsoA3s = widget.allData.map((e) => e.isoA3).toSet();

    _groups = [
      SpecialGroupInfo(title: 'No Income Tax', icon: Icons.money_off, themeColor: Colors.green.shade700, mapLegend: 'No Income Tax', memberCodes: _noIncomeTaxCountryCodes.where(allIsoA3s.contains).toList()),
      SpecialGroupInfo(title: 'No Corporate Tax', icon: Icons.business_center_outlined, themeColor: Colors.orange.shade700, mapLegend: 'No Corporate Tax', memberCodes: _noCorporateTaxCountryCodes.where(allIsoA3s.contains).toList()),
      SpecialGroupInfo(title: 'No VAT', icon: Icons.remove_shopping_cart, themeColor: Colors.blue.shade700, mapLegend: 'No VAT', memberCodes: _noVatCountryCodes.where(allIsoA3s.contains).toList()),
      SpecialGroupInfo(title: 'Carbon Tax', icon: Icons.eco, themeColor: Colors.brown.shade700, mapLegend: 'Carbon Tax', memberCodes: _carbonTaxCountryCodes.where(allIsoA3s.contains).toList()),
    ];
    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentCountries = widget.allData.where((c) => _selectedGroup.memberCodes.contains(c.isoA3)).toList();
    final total = currentCountries.length;
    final visited = currentCountries.where((c) => widget.visitedNames.contains(widget.isoA3ToCountryNameMap[c.isoA3])).length;
    final percentage = total > 0 ? (visited / total) : 0.0;
    final sortedCountries = List.from(currentCountries)..sort((a,b) => (widget.isoA3ToCountryNameMap[a.isoA3]??'').compareTo(widget.isoA3ToCountryNameMap[b.isoA3]??''));

    return Card(
      elevation: 4, shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SpecialGroupInfo>(
                borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
                value: _selectedGroup, isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) => DropdownMenuItem<SpecialGroupInfo>(
                  value: group,
                  child: Row(children: [
                    Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
                    Expanded(child: Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  ]),
                )).toList(),
                onChanged: (newValue) { if(newValue != null) setState(() { _selectedGroup = newValue; _isExpanded = false; }); },
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Visited Countries", style: textTheme.bodyLarge),
                      Text.rich(TextSpan(
                        text: '$visited', style: theme.textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                        children: [TextSpan(text: ' / $total', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
                      )),
                    ]),
                    ElevatedButton.icon(
                      onPressed: () {
                        final groups = [HighlightGroup(name: _selectedGroup.mapLegend, color: _selectedGroup.themeColor, countryCodes: _selectedGroup.memberCodes)];
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: groups)));
                      },
                      icon: const Icon(Icons.map_outlined), label: const Text('Map'),
                      style: ElevatedButton.styleFrom(backgroundColor: _selectedGroup.themeColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: percentage, backgroundColor: _selectedGroup.themeColor.withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(_selectedGroup.themeColor), minHeight: 8, borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
            child: _isExpanded ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: sortedCountries.length,
                itemBuilder: (context, index) {
                  final country = sortedCountries[index];
                  final countryObj = widget.isoA3ToCountryMap[country.isoA3]; // Country 객체 가져오기
                  final displayName = widget.isoA3ToCountryNameMap[country.isoA3] ?? country.name;
                  final isVisited = widget.visitedNames.contains(displayName);

                  return InkWell( // 상세 페이지 연결
                    borderRadius: BorderRadius.circular(8),
                    onTap: countryObj != null ? () => navigateToCountryDetail(context, countryObj) : null,
                    child: Container(
                      decoration: BoxDecoration(
                          color: isVisited ? _selectedGroup.themeColor.withOpacity(0.12) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          if (countryObj != null) ...[
                            Text(flagEmoji(countryObj.isoA2), style: const TextStyle(fontSize: 14)), // 국기 추가
                            const SizedBox(width: 6),
                          ],
                          Expanded(child: Align(alignment: Alignment.centerLeft, child: Text(displayName, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}