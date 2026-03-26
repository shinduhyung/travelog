// lib/screens/sports_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // rootBundle을 위해 추가
import 'dart:convert'; // json.decode를 위해 추가
import 'package:provider/provider.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:collection/collection.dart'; // firstWhereOrNull을 위해 추가
import 'dart:math' as math; // For math.max
import 'package:flutter/foundation.dart'; // For listEquals, setEquals
import 'package:intl/intl.dart'; // for NumberFormat


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

// Data Class: Ranking Info
class RankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final num? Function(Country) valueAccessor;
  final String unit;
  final int precision;

  const RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.valueAccessor,
    this.unit = '',
    this.precision = 0,
  });
}

// Data Class: Achievement Group Info
class AchievementGroup {
  final String title;
  final IconData icon;
  final Color themeColor;
  final String mapLegend;
  final List<_AchievementDisplayEntry> entries;

  const AchievementGroup({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.mapLegend,
    required this.entries,
  });
}

// Helper class for achievement display
class _AchievementDisplayEntry {
  final String displayName;
  final List<String> isoA3Codes;
  final String? type;

  const _AchievementDisplayEntry(this.displayName, this.isoA3Codes, {this.type});
}

class SportsTabScreen extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const SportsTabScreen({super.key, required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  State<SportsTabScreen> createState() => _SportsTabScreenState();
}

class _SportsTabScreenState extends State<SportsTabScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MostPopularSportSection(
            countriesToDisplay: widget.countriesToDisplay,
            visitedCountryNames: widget.visitedCountryNames,
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 600,
            child: _OlympicsRankingCard(
              countriesToDisplay: widget.countriesToDisplay,
              visitedCountryNames: widget.visitedCountryNames,
            ),
          ),

          const SizedBox(height: 24),
          _CombinedSportsAchievementCard(
            allCountries: widget.countriesToDisplay,
            visitedCountryNames: widget.visitedCountryNames,
          ),
        ],
      ),
    );
  }
}

class SportsStatsScreen extends StatelessWidget {
  const SportsStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CountryProvider>(
      builder: (context, countryProvider, child) {
        if (countryProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredCountries = countryProvider.filteredCountries;
        final visitedCountryNames = countryProvider.visitedCountries;

        return SportsTabScreen(countriesToDisplay: filteredCountries, visitedCountryNames: visitedCountryNames);
      },
    );
  }
}

class _OlympicsRankingCard extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _OlympicsRankingCard({
    required this.countriesToDisplay,
    required this.visitedCountryNames,
  });

  @override
  State<_OlympicsRankingCard> createState() => _OlympicsRankingCardState();
}

class _OlympicsRankingCardState extends State<_OlympicsRankingCard> {
  int _seasonSegment = 0; // 0: Summer, 1: Winter
  int _displaySegment = 0; // 0: All, 1: Visited
  int _medalTypeSegment = 0; // 0: Gold, 1: Total
  String _selectedContinent = 'World';
  List<Country> _rankedList = [];

  final List<String> _continents = ['World', 'Asia', 'Europe', 'Africa', 'North America', 'South America', 'Oceania'];

  static final Map<String, Color> _continentColors = {
    'Asia': Colors.pink.shade200, 'Europe': Colors.amber, 'Africa': Colors.brown,
    'North America': Colors.blue.shade200, 'South America': Colors.green.shade400, 'Oceania': Colors.purple.shade400,
  };

  @override
  void initState() {
    super.initState();
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _OlympicsRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countriesToDisplay, oldWidget.countriesToDisplay) ||
        !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames)) {
      _prepareList();
    }
  }

  void _prepareList() {
    List<Country> listToRank;

    if (_displaySegment == 1) { // Visited
      listToRank = widget.countriesToDisplay.where((c) => widget.visitedCountryNames.contains(c.name)).toList();
    } else { // All
      listToRank = List.from(widget.countriesToDisplay);
    }

    if (_selectedContinent != 'World') {
      listToRank = listToRank.where((c) => c.continent == _selectedContinent).toList();
    }

    if (_seasonSegment == 0) { // Summer
      listToRank = listToRank.where((c) {
        final value = _medalTypeSegment == 0 ? c.summerGold : c.summerTotal;
        return value != null && value > 0;
      }).toList();
    } else { // Winter
      listToRank = listToRank.where((c) {
        final value = _medalTypeSegment == 0 ? c.winterGold : c.winterTotal;
        return value != null && value > 0;
      }).toList();
    }

    // Always sort descending
    listToRank.sort((a, b) {
      final medalsA = _seasonSegment == 0
          ? (_medalTypeSegment == 0 ? (a.summerGold ?? 0) : (a.summerTotal ?? 0))
          : (_medalTypeSegment == 0 ? (a.winterGold ?? 0) : (a.winterTotal ?? 0));
      final medalsB = _seasonSegment == 0
          ? (_medalTypeSegment == 0 ? (b.summerGold ?? 0) : (b.summerTotal ?? 0))
          : (_medalTypeSegment == 0 ? (b.winterGold ?? 0) : (b.winterTotal ?? 0));

      return medalsB.compareTo(medalsA);
    });

    if (mounted) {
      setState(() {
        _rankedList = listToRank;
      });
    }
  }

  void _onFilterChanged() {
    setState(() {
      _prepareList();
    });
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
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final useDefaultColor = countryProvider.useDefaultRankingBarColor;
    final Color olympicColor = _seasonSegment == 0 ? Colors.amber.shade700 : Colors.lightBlue.shade700;

    final double maxMedal = _rankedList.isNotEmpty
        ? _rankedList.map((c) {
      return _seasonSegment == 0
          ? (_medalTypeSegment == 0 ? (c.summerGold ?? 0) : (c.summerTotal ?? 0))
          : (_medalTypeSegment == 0 ? (c.winterGold ?? 0) : (c.winterTotal ?? 0));
    }).reduce(math.max).toDouble()
        : 1.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section (Matches "Internet & Social Media" style: Colored background, Clean dropdowns)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: olympicColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: olympicColor),
                    const SizedBox(width: 8),
                    Text('Olympic Games', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 1: Season & Continent Dropdowns (Reverted to clean style)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          borderRadius: BorderRadius.circular(16),
                          value: _seasonSegment,
                          isExpanded: true,
                          // FIX: Changed trailing icon to standard arrow to avoid double icons
                          icon: Icon(Icons.arrow_drop_down, color: olympicColor),
                          items: [
                            DropdownMenuItem<int>(
                              value: 0,
                              child: Row(children: [
                                Icon(Icons.wb_sunny, color: Colors.amber.shade700),
                                const SizedBox(width: 8),
                                Text('Summer Olympics', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ]),
                            ),
                            DropdownMenuItem<int>(
                              value: 1,
                              child: Row(children: [
                                Icon(Icons.ac_unit, color: Colors.lightBlue.shade700),
                                const SizedBox(width: 8),
                                Text('Winter Olympics', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _seasonSegment = val;
                                _onFilterChanged();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          borderRadius: BorderRadius.circular(16),
                          value: _selectedContinent,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: olympicColor),
                          items: _continents.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis,))).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedContinent = newValue!;
                              _onFilterChanged();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Row 2: Medal Type & Visited Dropdowns (Reverted to clean style)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          borderRadius: BorderRadius.circular(16),
                          value: _medalTypeSegment,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: olympicColor),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Gold Medals')),
                            DropdownMenuItem(value: 1, child: Text('Total Medals')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _medalTypeSegment = val;
                                _onFilterChanged();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          borderRadius: BorderRadius.circular(16),
                          value: _displaySegment,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: olympicColor),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('All Countries')),
                            DropdownMenuItem(value: 1, child: Text('Visited Only')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _displaySegment = val;
                                _onFilterChanged();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
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
                final medalValue = _seasonSegment == 0
                    ? (_medalTypeSegment == 0 ? (country.summerGold ?? 0) : (country.summerTotal ?? 0))
                    : (_medalTypeSegment == 0 ? (country.winterGold ?? 0) : (country.winterTotal ?? 0));

                final barColor = useDefaultColor ? olympicColor : (_continentColors[country.continent] ?? Colors.grey);
                final progressValue = medalValue / math.max(1.0, maxMedal);

                return Card(
                  elevation: 0,
                  color: isVisited ? olympicColor.withOpacity(0.12) : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => navigateToCountryDetail(context, country),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildRankText(rank, olympicColor),
                              const SizedBox(width: 8),
                              Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(country.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17))),
                              const SizedBox(width: 8),
                              Text(medalValue.toString(), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: progressValue,
                            borderRadius: BorderRadius.circular(5),
                            minHeight: 5,
                            backgroundColor: Colors.grey.shade200,
                            color: barColor,
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

class _CombinedSportsAchievementCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedSportsAchievementCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedSportsAchievementCard> createState() => _CombinedSportsAchievementCardState();
}

class _CombinedSportsAchievementCardState extends State<_CombinedSportsAchievementCard> {
  late final List<AchievementGroup> _groups;
  late AchievementGroup _selectedGroup;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _groups = [
      AchievementGroup(
        title: 'Olympic Hosts', icon: Icons.stadium, themeColor: Colors.purple, mapLegend: 'Olympic Host',
        entries: [
          _AchievementDisplayEntry('United States', ['USA'], type: 'both'), _AchievementDisplayEntry('France', ['FRA'], type: 'both'), _AchievementDisplayEntry('Japan', ['JPN'], type: 'both'),
          _AchievementDisplayEntry('Germany', ['DEU'], type: 'both'), _AchievementDisplayEntry('Italy', ['ITA'], type: 'both'), _AchievementDisplayEntry('Russia', ['RUS'], type: 'both'),
          _AchievementDisplayEntry('Canada', ['CAN'], type: 'both'), _AchievementDisplayEntry('South Korea', ['KOR'], type: 'both'), _AchievementDisplayEntry('China', ['CHN'], type: 'both'),
          _AchievementDisplayEntry('Yugoslavia', ['SVN', 'HRV', 'BIH', 'MNE', 'MKD', 'SRB', 'KOS'], type: 'both'), _AchievementDisplayEntry('Greece', ['GRC'], type: 'summer'),
          _AchievementDisplayEntry('United Kingdom', ['GBR'], type: 'summer'), _AchievementDisplayEntry('Sweden', ['SWE'], type: 'summer'), _AchievementDisplayEntry('Belgium', ['BEL'], type: 'summer'),
          _AchievementDisplayEntry('Finland', ['FIN'], type: 'summer'), _AchievementDisplayEntry('Netherlands', ['NLD'], type: 'summer'), _AchievementDisplayEntry('Mexico', ['MEX'], type: 'summer'),
          _AchievementDisplayEntry('Spain', ['ESP'], type: 'summer'), _AchievementDisplayEntry('Australia', ['AUS'], type: 'summer'), _AchievementDisplayEntry('Brazil', ['BRA'], type: 'summer'),
          _AchievementDisplayEntry('Argentina', ['ARG'], type: 'summer'), _AchievementDisplayEntry('Hungary', ['HUN'], type: 'summer'), _AchievementDisplayEntry('Turkey', ['TUR'], type: 'summer'),
          _AchievementDisplayEntry('Czechoslovakia', ['CZE', 'SVK'], type: 'summer'), _AchievementDisplayEntry('Switzerland', ['CHE'], type: 'winter'), _AchievementDisplayEntry('Norway', ['NOR'], type: 'winter'),
          _AchievementDisplayEntry('Austria', ['AUT'], type: 'winter'),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
      AchievementGroup(
        title: 'World Cup Winners', icon: Icons.emoji_events, themeColor: Colors.amber.shade700, mapLegend: 'World Cup Winner',
        entries: [
          _AchievementDisplayEntry('Argentina', ['ARG']), _AchievementDisplayEntry('Brazil', ['BRA']), _AchievementDisplayEntry('England', ['GBR']),
          _AchievementDisplayEntry('France', ['FRA']), _AchievementDisplayEntry('Germany', ['DEU']), _AchievementDisplayEntry('Italy', ['ITA']),
          _AchievementDisplayEntry('Spain', ['ESP']), _AchievementDisplayEntry('Uruguay', ['URY']),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
      AchievementGroup(
        title: 'World Cup Hosts', icon: Icons.public, themeColor: Colors.blue.shade400, mapLegend: 'World Cup Host',
        entries: [
          _AchievementDisplayEntry('Argentina', ['ARG']), _AchievementDisplayEntry('Brazil', ['BRA']), _AchievementDisplayEntry('Canada', ['CAN']), _AchievementDisplayEntry('Chile', ['CHL']),
          _AchievementDisplayEntry('England', ['GBR']), _AchievementDisplayEntry('France', ['FRA']), _AchievementDisplayEntry('Germany', ['DEU']), _AchievementDisplayEntry('Italy', ['ITA']),
          _AchievementDisplayEntry('Japan', ['JPN']), _AchievementDisplayEntry('Mexico', ['MEX']), _AchievementDisplayEntry('Qatar', ['QAT']), _AchievementDisplayEntry('Russia', ['RUS']),
          _AchievementDisplayEntry('South Africa', ['ZAF']), _AchievementDisplayEntry('South Korea', ['KOR']), _AchievementDisplayEntry('Spain', ['ESP']), _AchievementDisplayEntry('Sweden', ['SWE']),
          _AchievementDisplayEntry('Switzerland', ['CHE']), _AchievementDisplayEntry('United States', ['USA']), _AchievementDisplayEntry('Uruguay', ['URY']),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
      AchievementGroup(
        title: 'WBC Winners', icon: Icons.sports_baseball, themeColor: Colors.red.shade700, mapLegend: 'WBC Winner',
        entries: [
          _AchievementDisplayEntry('Dominican Rep.', ['DMA']), _AchievementDisplayEntry('Japan', ['JPN']), _AchievementDisplayEntry('United States', ['USA']),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
      AchievementGroup(
        title: 'FIBA Winners', icon: Icons.sports_basketball, themeColor: Colors.orange.shade800, mapLegend: 'FIBA Winner',
        entries: [
          _AchievementDisplayEntry('Argentina', ['ARG']), _AchievementDisplayEntry('Brazil', ['BRA']), _AchievementDisplayEntry('Germany', ['DEU']),
          _AchievementDisplayEntry('Soviet Union', ['ARM', 'AZE', 'BLR', 'EST', 'GEO', 'KAZ', 'KGZ', 'LVA', 'LTU', 'MDA', 'RUS', 'TJK', 'TKM', 'UKR', 'UZB']),
          _AchievementDisplayEntry('Spain', ['ESP']), _AchievementDisplayEntry('United States', ['USA']),
          _AchievementDisplayEntry('Yugoslavia', ['SVN', 'HRV', 'BIH', 'MNE', 'MKD', 'SRB', 'KOS']),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
      AchievementGroup(
        title: 'Cricket World Cup Winners', icon: Icons.sports_cricket, themeColor: Colors.brown, mapLegend: 'Cricket Winner',
        entries: [
          _AchievementDisplayEntry('Australia', ['AUS']), _AchievementDisplayEntry('England', ['GBR']), _AchievementDisplayEntry('India', ['IND']),
          _AchievementDisplayEntry('Pakistan', ['PAK']), _AchievementDisplayEntry('Sri Lanka', ['LKA']),
          _AchievementDisplayEntry('West Indies', ['GRD', 'LCA', 'VCT', 'ATG', 'JAM', 'KNA', 'GUY', 'DMA', 'BRB', 'TTO', 'SXM', 'VIR', 'MSR', 'VGB', 'AIA']),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
      AchievementGroup(
        title: 'Chess Champions', icon: Icons.grid_on, themeColor: Colors.grey.shade800, mapLegend: 'Chess Champion',
        entries: [
          _AchievementDisplayEntry('Armenia', ['ARM']), _AchievementDisplayEntry('Austria', ['AUT']), _AchievementDisplayEntry('China', ['CHN']),
          _AchievementDisplayEntry('Germany', ['DEU']), _AchievementDisplayEntry('Hungary', ['HUN']), _AchievementDisplayEntry('India', ['IND']),
          _AchievementDisplayEntry('Latvia', ['LVA']), _AchievementDisplayEntry('Netherlands', ['NLD']), _AchievementDisplayEntry('Norway', ['NOR']),
          _AchievementDisplayEntry('Russia', ['RUS']), _AchievementDisplayEntry('United States', ['USA']),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
    ];

    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    int total = _selectedGroup.entries.length;
    int visited = 0;

    final List<String> solidHighlightCodes = [];
    final List<String> fadedHighlightCodes = [];

    for (var entry in _selectedGroup.entries) {
      bool isAnyVisited = entry.isoA3Codes.any((code) {
        final country = widget.allCountries.firstWhereOrNull((c) => c.isoA3 == code);
        return country != null && widget.visitedCountryNames.contains(country.name);
      });
      if (isAnyVisited) {
        visited++;
        solidHighlightCodes.addAll(entry.isoA3Codes);
      } else {
        fadedHighlightCodes.addAll(entry.isoA3Codes);
      }
    }
    final percentage = total > 0 ? (visited / total) : 0.0;

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AchievementGroup>(
                borderRadius: BorderRadius.circular(16),
                value: _selectedGroup, isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) => DropdownMenuItem<AchievementGroup>(
                  value: group,
                  child: Row(
                    children: [
                      Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
                      Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )).toList(),
                onChanged: (newValue) {
                  if (newValue != null) setState(() { _selectedGroup = newValue; _isExpanded = false; });
                },
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Visited Entities", style: textTheme.bodyLarge),
                            Text.rich(TextSpan(
                              text: '$visited',
                              style: textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                              children: [TextSpan(text: ' / $total', style: textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
                            )),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            final groups = <HighlightGroup>[];
                            if(fadedHighlightCodes.isNotEmpty) {
                              groups.add(HighlightGroup(name: '${_selectedGroup.mapLegend} (Not Visited)', color: _selectedGroup.themeColor.withOpacity(0.35), countryCodes: fadedHighlightCodes.toSet().toList(), ignoreVisitedOpacity: true));
                            }
                            if(solidHighlightCodes.isNotEmpty) {
                              groups.add(HighlightGroup(name: _selectedGroup.mapLegend, color: _selectedGroup.themeColor, countryCodes: solidHighlightCodes.toSet().toList(), ignoreVisitedOpacity: true));
                            }
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: groups)));
                          },
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Map'),
                          style: ElevatedButton.styleFrom(backgroundColor: _selectedGroup.themeColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(color: _selectedGroup.themeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(5)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(value: percentage, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(_selectedGroup.themeColor)),
                      ),
                    ),
                  ],
                )
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded ? Column(
              children: [
                const Divider(height: 1, indent: 20, endIndent: 20),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
                    itemCount: _selectedGroup.entries.length,
                    itemBuilder: (context, index) {
                      final entry = _selectedGroup.entries[index];
                      final isVisited = entry.isoA3Codes.any((code) {
                        final country = widget.allCountries.firstWhereOrNull((c) => c.isoA3 == code);
                        return country != null && widget.visitedCountryNames.contains(country.name);
                      });

                      String marker = '';
                      if (entry.type == 'winter') marker = '*';
                      if (entry.type == 'both') marker = '**';

                      // 단일 국가면 국기 표시 및 클릭 가능
                      String flag = '';
                      Country? singleCountry;
                      if (entry.isoA3Codes.length == 1) {
                        singleCountry = widget.allCountries.firstWhereOrNull((c) => c.isoA3 == entry.isoA3Codes.first);
                        if (singleCountry != null) flag = flagEmoji(singleCountry.isoA2);
                      }
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: singleCountry != null ? () => navigateToCountryDetail(context, singleCountry!) : null,
                        child: Row(
                          children: [
                            Icon(isVisited ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: isVisited ? _selectedGroup.themeColor : Colors.grey.shade400),
                            const SizedBox(width: 6),
                            if (flag.isNotEmpty) ...[Text(flag, style: const TextStyle(fontSize: 14)), const SizedBox(width: 4)],
                            Expanded(child: Text('${entry.displayName} $marker', style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_selectedGroup.title == 'Olympic Hosts')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("(*) Winter Only Host", style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                        Text("(**) Both Summer & Winter Host", style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
              ],
            ) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MostPopularSportSection extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _MostPopularSportSection({
    required this.countriesToDisplay,
    required this.visitedCountryNames,
  });

  @override
  State<_MostPopularSportSection> createState() => _MostPopularSportSectionState();
}

class _MostPopularSportSectionState extends State<_MostPopularSportSection> {
  Map<String, String> _sportsData = {};
  bool _isLoadingSportsData = true;
  String? _expandedSport;

  final Map<String, Color> _sportColors = {
    'Football (Soccer)': const Color(0xFF2ECC71), 'Cricket': const Color(0xFFD4AC0D), 'Basketball': const Color(0xFFE67E22),
    'Baseball': const Color(0xFF2C3E50), 'Ice Hockey': const Color(0xFF85C1E9), 'Rugby': const Color(0xFF6C3483),
    'American Football': const Color(0xFFA0522D), 'Australian Football': const Color(0xFFE74C3C), 'Gaelic Football': const Color(0xFF1ABC9C),
    'Wrestling': const Color(0xFF8E1B1B), 'Archery': const Color(0xFF2980B9), 'Boatracing': const Color(0xFF2471A3),
  };

  @override
  void initState() {
    super.initState();
    _loadSportsData();
  }

  Future<void> _loadSportsData() async {
    try {
      final String response = await rootBundle.loadString('assets/sports.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _sportsData = { for (var item in data) item['iso_a3'] as String: (item['sports'] as String == 'Soccer' ? 'Football (Soccer)' : item['sports'] as String) };
      });
    } finally {
      if(mounted) setState(() { _isLoadingSportsData = false; });
    }
  }

  void _toggleSportExpanded(String sportName) {
    setState(() {
      if (_expandedSport == sportName) {
        _expandedSport = null;
      } else {
        _expandedSport = sportName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSportsData) {
      return const Center(child: CircularProgressIndicator());
    }

    final Map<String, List<Country>> groupedBySport = {};
    for (var type in _sportColors.keys) {
      groupedBySport[type] = [];
    }

    for (var country in widget.countriesToDisplay) {
      final sport = _sportsData[country.isoA3];
      if (sport != null && groupedBySport.containsKey(sport)) {
        groupedBySport[sport]!.add(country);
      }
    }

    final List<String> relevantSports = _sportColors.keys.where((sport) => groupedBySport[sport]!.isNotEmpty).toList();

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
                backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Icons.sports_soccer, color: Colors.white, size: 20),
              label: const Text(
                'Most Popular Sports Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                final List<HighlightGroup> highlightGroups = [];
                final Set<String> allRelevantSportCountryCodes = relevantSports.expand((sportName) => groupedBySport[sportName]!.map((c) => c.isoA3)).toSet();

                for (var type in relevantSports) {
                  final countries = groupedBySport[type];
                  if (countries != null && countries.isNotEmpty) {
                    highlightGroups.add(HighlightGroup(name: type, color: _sportColors[type] ?? Colors.grey, countryCodes: countries.map((c) => c.isoA3).toList()));
                  }
                }

                final Set<String> allFilteredCountryIsoA3s = widget.countriesToDisplay.map((c) => c.isoA3).toSet();
                final List<String> otherCountriesFaded = allFilteredCountryIsoA3s.where((code) => !allRelevantSportCountryCodes.contains(code)).toList();
                if (otherCountriesFaded.isNotEmpty) {
                  highlightGroups.add(HighlightGroup(name: 'Other Countries', color: Colors.grey.withOpacity(0.35), countryCodes: otherCountriesFaded));
                }

                highlightGroups.sort((a,b) => a.name == 'Other Countries' ? -1 : 1);

                Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: highlightGroups)));
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: relevantSports.map((title) {
              final countries = groupedBySport[title] ?? [];
              final total = countries.length;
              final visited = countries.where((c) => widget.visitedCountryNames.contains(c.name)).length;
              final percentage = total > 0 ? (visited / total) : 0.0;
              final isExpanded = _expandedSport == title;
              final theme = Theme.of(context);
              final sportColor = _sportColors[title] ?? theme.primaryColor;

              List<Country> sortedCountries = List.from(countries)..sort((a, b) => a.name.compareTo(b.name));

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                child: _SportTile(
                  title: title,
                  countries: countries,
                  visitedNames: widget.visitedCountryNames,
                  percentage: percentage,
                  color: sportColor,
                  isExpanded: isExpanded,
                  onToggle: _toggleSportExpanded,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SportTile extends StatelessWidget {
  final String title;
  final List<Country> countries;
  final Set<String> visitedNames;
  final double percentage;
  final Color color;
  final bool isExpanded;
  final Function(String) onToggle;

  const _SportTile({
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
        borderRadius: BorderRadius.circular(12),
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
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => navigateToCountryDetail(context, country),
                          child: Row(
                            children: [
                              Icon(
                                isVisited ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: isVisited ? color : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)),
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