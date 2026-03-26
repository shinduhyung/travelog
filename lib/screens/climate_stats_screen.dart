// lib/screens/climate_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/screens/climate_map_screen.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart'; // 상세 화면 추가
import 'package:jidoapp/screens/geography_stats_screen.dart';

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

// 데이터 클래스: 랭킹 정보
class RankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final num? Function(Country) valueAccessor;
  final String unit;
  final int precision;
  final bool sortAscendingForHigh;

  const RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.valueAccessor,
    this.unit = '',
    this.precision = 0,
    this.sortAscendingForHigh = false,
  });
}

class ClimateStatsScreen extends StatelessWidget {
  const ClimateStatsScreen({super.key});

  static const Map<String, String> _climateZoneNames = {
    'A': 'Tropical',
    'B': 'Arid',
    'C': 'Temperate',
    'D': 'Continental',
    'E': 'Polar',
  };

  static const Map<String, Color> _climateZoneColors = {
    'A': Color(0xFFFF0000), 'B': Color(0xFFFFFF00), 'C': Color(0xFF008000), 'D': Color(0xFF0000FF), 'E': Color(0xFF00FFFF),
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<CountryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredCountries = provider.filteredCountries;
        final visitedCountryNames = provider.visitedCountries;

        final Map<String, List<Country>> countriesByClimateZone = {};
        for (var country in filteredCountries) {
          if (country.climateZone != null) {
            countriesByClimateZone.putIfAbsent(country.climateZone!, () => []).add(country);
          }
        }
        final List<String> climateZonesToShow = _climateZoneNames.keys.toList();


        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _ClimateMapButton(
                countriesByClimateZone: countriesByClimateZone,
                climateZonesToShow: climateZonesToShow,
                climateZoneNames: _climateZoneNames,
                climateZoneColors: _climateZoneColors,
              ),
              const SizedBox(height: 12),
              _ClimateZoneSection(
                countriesByClimateZone: countriesByClimateZone,
                visitedCountryNames: visitedCountryNames,
                climateZonesToShow: climateZonesToShow,
                climateZoneNames: _climateZoneNames,
                climateZoneColors: _climateZoneColors,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 600,
                child: _CombinedRankingCard(
                  countriesToDisplay: filteredCountries,
                  visitedCountryNames: visitedCountryNames,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClimateMapButton extends StatelessWidget {
  final Map<String, List<Country>> countriesByClimateZone;
  final List<String> climateZonesToShow;
  final Map<String, String> climateZoneNames;
  final Map<String, Color> climateZoneColors;

  const _ClimateMapButton({
    required this.countriesByClimateZone,
    required this.climateZonesToShow,
    required this.climateZoneNames,
    required this.climateZoneColors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
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
            'World Climate Map',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          onPressed: () {
            final List<HighlightGroup> highlightGroups = [];
            for (var zoneCode in climateZonesToShow) {
              final countries = countriesByClimateZone[zoneCode];
              if (countries != null && countries.isNotEmpty) {
                highlightGroups.add(HighlightGroup(
                  name: climateZoneNames[zoneCode] ?? zoneCode,
                  color: climateZoneColors[zoneCode] ?? Colors.grey,
                  countryCodes: countries.map((c) => c.isoA3).toList(),
                ));
              }
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: highlightGroups)),
            );
          },
        ),
      ),
    );
  }
}

class _ClimateZoneSection extends StatefulWidget {
  final Map<String, List<Country>> countriesByClimateZone;
  final Set<String> visitedCountryNames;
  final List<String> climateZonesToShow;
  final Map<String, String> climateZoneNames;
  final Map<String, Color> climateZoneColors;

  const _ClimateZoneSection({
    required this.countriesByClimateZone,
    required this.visitedCountryNames,
    required this.climateZonesToShow,
    required this.climateZoneNames,
    required this.climateZoneColors,
  });

  @override
  State<_ClimateZoneSection> createState() => _ClimateZoneSectionState();
}

class _ClimateZoneSectionState extends State<_ClimateZoneSection> {
  String? _expandedZoneCode;

  void _toggleZone(String zoneCode) {
    setState(() {
      if (_expandedZoneCode == zoneCode) {
        _expandedZoneCode = null;
      } else {
        _expandedZoneCode = zoneCode;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> zoneTiles = widget.climateZonesToShow.map((zoneCode) {
      final countriesInZone = widget.countriesByClimateZone[zoneCode] ?? [];
      if (countriesInZone.isEmpty) {
        return const SizedBox.shrink();
      }
      countriesInZone.sort((a,b) => a.name.compareTo(b.name));

      final zoneName = widget.climateZoneNames[zoneCode] ?? 'Unknown Zone';
      final color = widget.climateZoneColors[zoneCode] ?? Theme.of(context).primaryColor;
      final isExpanded = _expandedZoneCode == zoneCode;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _ClimateZoneTile(
          title: zoneName,
          zoneCode: zoneCode,
          countries: countriesInZone,
          visitedNames: widget.visitedCountryNames,
          color: color,
          isExpanded: isExpanded,
          onToggle: _toggleZone,
        ),
      );
    }).toList();

    return Column(
      children: zoneTiles,
    );
  }
}

class _ClimateZoneTile extends StatelessWidget {
  final String title;
  final String zoneCode;
  final List<Country> countries;
  final Set<String> visitedNames;
  final Color color;
  final bool isExpanded;
  final Function(String) onToggle;

  const _ClimateZoneTile({
    required this.title,
    required this.zoneCode,
    required this.countries,
    required this.visitedNames,
    required this.color,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final total = countries.length;
    final visited = countries.where((c) => visitedNames.contains(c.name)).length;
    final percentage = total > 0 ? (visited / total) : 0.0;
    final theme = Theme.of(context);
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
            onTap: () => onToggle(zoneCode),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 8,
                            backgroundColor: color.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$visited / $total Countries',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey,
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
                        childAspectRatio: 4.5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: sortedCountries.length,
                      itemBuilder: (context, index) {
                        final country = sortedCountries[index];
                        final isVisited = visitedNames.contains(country.name);
                        return InkWell( // 상세 페이지 연결
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

class _CombinedRankingCard extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _CombinedRankingCard({required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  State<_CombinedRankingCard> createState() => _CombinedRankingCardState();
}

class _CombinedRankingCardState extends State<_CombinedRankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selectedRanking;

  int _displaySegment = 0;
  int _sortOrderSegment = 0;
  String _selectedContinent = 'World';
  List<Country> _rankedList = [];

  final List<String> _continents = ['World', 'Asia', 'Europe', 'Africa', 'North America', 'South America', 'Oceania'];
  static final Map<String, Color> _continentColors = {
    'Asia': Colors.pink.shade200, 'Europe': Colors.amber, 'Africa': Colors.brown,
    'North America': Colors.blue.shade200, 'South America': Colors.green, 'Oceania': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _rankings = [
      RankingInfo(title: 'Average Temperature', icon: Icons.thermostat, themeColor: Colors.orange, valueAccessor: (c) => c.avgTemp, unit: '°C', precision: 1),
      RankingInfo(title: 'Average Precipitation', icon: Icons.water_drop, themeColor: Colors.blue, valueAccessor: (c) => c.avgPrecipitation, unit: 'mm', precision: 0),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _CombinedRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countriesToDisplay, oldWidget.countriesToDisplay) ||
        !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames)) {
      _prepareList();
    }
  }

  void _prepareList() {
    List<Country> listToRank;
    if (_displaySegment == 1) listToRank = widget.countriesToDisplay.where((c) => widget.visitedCountryNames.contains(c.name)).toList();
    else listToRank = List.from(widget.countriesToDisplay);
    if (_selectedContinent != 'World') listToRank = listToRank.where((c) => c.continent == _selectedContinent).toList();
    listToRank = listToRank.where((c) => _selectedRanking.valueAccessor(c) != null && _selectedRanking.valueAccessor(c) != 0).toList();
    listToRank.sort((a, b) { final valA = _selectedRanking.valueAccessor(a) ?? 0; final valB = _selectedRanking.valueAccessor(b) ?? 0; return _sortOrderSegment == 0 ? valB.compareTo(valA) : valA.compareTo(valB); });
    if (mounted) setState(() { _rankedList = listToRank; });
  }

  void _onFilterChanged() => setState(() => _prepareList());

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
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final useDefaultColor = countryProvider.useDefaultRankingBarColor;
    final NumberFormat formatter = NumberFormat.decimalPattern();
    final rankingThemeColor = _selectedRanking.themeColor;

    final double maxValue = _rankedList.isNotEmpty ? _rankedList.map((c) => _selectedRanking.valueAccessor(c)?.abs() ?? 0.0).reduce(math.max).toDouble() : 1.0;

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
                        Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
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
                ? const Center(child: Text('No data to display.'))
                : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _rankedList.length,
              itemBuilder: (context, index) {
                final country = _rankedList[index];
                final isVisited = widget.visitedCountryNames.contains(country.name);
                final rank = index + 1;
                final value = _selectedRanking.valueAccessor(country) ?? 0;
                final barColor = useDefaultColor ? rankingThemeColor : (_continentColors[country.continent] ?? rankingThemeColor);
                final progressValue = value.abs().toDouble() / math.max(1.0, maxValue);

                String displayValue;
                if (_selectedRanking.precision == 0) {
                  displayValue = formatter.format(value);
                } else {
                  displayValue = value.toStringAsFixed(_selectedRanking.precision);
                }

                return Card(
                  elevation: 0,
                  color: isVisited ? rankingThemeColor.withOpacity(0.12) : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell( // 상세 페이지 연결
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => navigateToCountryDetail(context, country),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildRankText(rank, rankingThemeColor),
                              const SizedBox(width: 12),
                              Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 18)), // 국기 추가
                              const SizedBox(width: 8),
                              Expanded(child: Text(country.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                              Text('$displayValue${_selectedRanking.unit}', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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

Widget _buildHorizontalBar({
  required BuildContext context,
  required String label,
  required double value,
  required double maxValue,
  required Color color,
  required NumberFormat formatter,
  String suffix = '',
}) {
  final isNegative = value < 0;
  final displayValue = value.abs();
  final displayMaxValue = maxValue;

  return LayoutBuilder(
    builder: (context, constraints) {
      final barMaxWidth = constraints.maxWidth - 60 - 92;
      final barWidth = (displayValue / (displayMaxValue == 0 ? 1 : displayMaxValue)) * barMaxWidth;
      return Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Align(
                alignment: isNegative ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: barWidth > 0 ? barWidth : 0,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              '${formatter.format(value)}$suffix',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      );
    },
  );
}