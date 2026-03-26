// lib/screens/military_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:jidoapp/screens/geopolitics_stats_screen.dart';
import 'package:jidoapp/screens/specific_countries_stats_screen.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:collection/collection.dart';


// Helper: ISO A2 → 국기 이모지
String flagEmoji(String isoA2) {
  if (isoA2.length != 2) return '';
  final base = 0x1F1E6 - 0x41;
  return String.fromCharCode(base + isoA2.codeUnitAt(0)) +
      String.fromCharCode(base + isoA2.codeUnitAt(1));
}

// Helper: 국가 클릭 → CountryDetailScreen
void navigateToCountryDetail(BuildContext context, Country country) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => CountryDetailScreen(country: country)),
  );
}

// Data Class: Ranking Information
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

// AchievementGroup: For single bloc/group
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

// AchievementDisplayEntry
class _AchievementDisplayEntry {
  final String displayName;
  final List<String> isoA3Codes;
  final String? type;

  const _AchievementDisplayEntry(this.displayName, this.isoA3Codes, {this.type});
}

// ConflictGroupInfo: For comparing two major sides
class ConflictGroupInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final String side1Name;
  final String side2Name;
  final List<String> side1Codes;
  final List<String> side2Codes;
  final Color side1Color;
  final Color side2Color;
  final String mapLegend;

  const ConflictGroupInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.side1Name,
    required this.side2Name,
    required this.side1Codes,
    required this.side2Codes,
    required this.side1Color,
    required this.side2Color,
    required this.mapLegend,
  });
}

// Data Class: Special Group Information
class SpecialGroupInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final List<String> memberCodes;
  final List<String> subMemberCodes;
  final String subMemberLegend;
  final List<HighlightGroup> Function(List<Country> countriesToDisplay) mapGroupsBuilder;

  const SpecialGroupInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.memberCodes,
    required this.mapGroupsBuilder,
    this.subMemberCodes = const [],
    this.subMemberLegend = '',
  });
}

// MilitaryTabScreen
class MilitaryTabScreen extends StatelessWidget {
  const MilitaryTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final countryProvider = Provider.of<CountryProvider>(context);

    if (countryProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredCountries = countryProvider.filteredCountries;
    final visitedCountryNames = countryProvider.visitedCountries;

    // 1. Define Strategic Power Rankings
    final List<RankingInfo> strategicRankings = [
      RankingInfo(title: 'Military Power Index', icon: Icons.military_tech, themeColor: Colors.deepOrange.shade700, valueAccessor: (c) => c.PwrIndx, precision: 4, sortAscendingForHigh: true),
      RankingInfo(title: 'Military Expenditure', icon: Icons.attach_money, themeColor: Colors.lightBlue.shade700, valueAccessor: (c) => c.militaryExpenditure, unit: '%', precision: 1),
      RankingInfo(title: 'Nukes', icon: Icons.warning_amber_rounded, themeColor: Colors.red.shade700, valueAccessor: (c) => c.nukesTotal, precision: 0),
    ];

    // 2. Define Military Assets Rankings
    final List<RankingInfo> assetRankings = [
      RankingInfo(title: 'Armed Forces Personnel', icon: Icons.groups, themeColor: Colors.blueGrey.shade700, valueAccessor: (c) => c.armedForcesPersonnel, precision: 0),
      RankingInfo(title: 'Navy Ships', icon: Icons.directions_boat, themeColor: Colors.blue.shade800, valueAccessor: (c) => c.navyShipsTotal, precision: 0),
      RankingInfo(title: 'Aircraft Carriers', icon: Icons.layers, themeColor: Colors.cyan.shade700, valueAccessor: (c) => c.aircraftCarriersTotal, precision: 0),
      RankingInfo(title: 'Total Aircraft', icon: Icons.flight, themeColor: Colors.teal.shade700, valueAccessor: (c) => c.totalAircraft, precision: 0),
      RankingInfo(title: 'Tanks', icon: Icons.shield_outlined, themeColor: Colors.brown.shade700, valueAccessor: (c) => c.tanksTotal, precision: 0),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Strategic Power
          SizedBox(
            height: 550,
            child: _RankingCategoryCard(
              cardTitle: 'Strategic Power',
              cardIcon: Icons.psychology,
              rankings: strategicRankings,
              countriesToDisplay: filteredCountries,
              visitedCountryNames: visitedCountryNames,
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Military Assets
          SizedBox(
            height: 550,
            child: _RankingCategoryCard(
              cardTitle: 'Military Assets',
              cardIcon: Icons.hardware,
              rankings: assetRankings,
              countriesToDisplay: filteredCountries,
              visitedCountryNames: visitedCountryNames,
            ),
          ),
          const SizedBox(height: 24),

          // Casualties Ranking Card (Modified)
          SizedBox(
            height: 450,
            child: _CasualtyRankingCard(
              countriesToDisplay: filteredCountries,
              visitedCountryNames: visitedCountryNames,
            ),
          ),
          const SizedBox(height: 24),

          _CombinedSpecialGroupCard(
            countriesToDisplay: filteredCountries,
            visitedCountryNames: visitedCountryNames,
          ),
          const SizedBox(height: 24),

          _CombinedHistoricalAllianceAndMiscCard(
            allCountries: filteredCountries,
            visitedCountryNames: visitedCountryNames,
          ),
          const SizedBox(height: 24),

          _CombinedHistoricalWarProgressCard(
            allCountries: filteredCountries,
            visitedCountryNames: visitedCountryNames,
          ),
        ],
      ),
    );
  }
}

// MilitaryStatsScreen Wrapper
class MilitaryStatsScreen extends StatelessWidget {
  const MilitaryStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Material(
                elevation: 1,
                child: TabBar(
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(icon: Icon(Icons.military_tech), text: 'Military'),
                    Tab(icon: Icon(Icons.public), text: 'Geopolitics'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    MilitaryTabScreen(),
                    GeopoliticsStatsScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// REFACTORED: Generic Ranking Card used for both "Strategic Power" and "Military Assets"
class _RankingCategoryCard extends StatefulWidget {
  final String cardTitle;
  final IconData cardIcon;
  final List<RankingInfo> rankings;
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _RankingCategoryCard({
    required this.cardTitle,
    required this.cardIcon,
    required this.rankings,
    required this.countriesToDisplay,
    required this.visitedCountryNames,
  });

  @override
  State<_RankingCategoryCard> createState() => _RankingCategoryCardState();
}

class _RankingCategoryCardState extends State<_RankingCategoryCard> {
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
    _selectedRanking = widget.rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _RankingCategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countriesToDisplay, oldWidget.countriesToDisplay) ||
        !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames) ||
        !listEquals(widget.rankings, oldWidget.rankings)) {

      if(!listEquals(widget.rankings, oldWidget.rankings)) {
        _selectedRanking = widget.rankings.first;
      }
      _prepareList();
    }
  }

  void _prepareList() {
    List<Country> listToRank;
    if (_displaySegment == 1) {
      listToRank = widget.countriesToDisplay.where((c) => widget.visitedCountryNames.contains(c.name)).toList();
    } else {
      listToRank = List.from(widget.countriesToDisplay);
    }

    if (_selectedContinent != 'World') {
      listToRank = listToRank.where((c) => c.continent == _selectedContinent).toList();
    }

    listToRank = listToRank.where((c) => _selectedRanking.valueAccessor(c) != null).toList();

    listToRank.sort((a, b) {
      final valA = _selectedRanking.valueAccessor(a)?.toDouble() ?? 0.0;
      final valB = _selectedRanking.valueAccessor(b)?.toDouble() ?? 0.0;

      bool highButtonPressed = _sortOrderSegment == 0;
      bool sortAsc = (highButtonPressed && _selectedRanking.sortAscendingForHigh) || (!highButtonPressed && !_selectedRanking.sortAscendingForHigh);

      return sortAsc ? valA.compareTo(valB) : valB.compareTo(valA);
    });

    if (mounted) setState(() { _rankedList = listToRank; });
  }

  void _onFilterChanged() => setState(() => _prepareList());

  Widget _buildRankText(int rank, Color color) {
    return Text(
      '$rank',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final useDefaultColor = countryProvider.useDefaultRankingBarColor;
    final NumberFormat formatter = NumberFormat.decimalPattern();
    final rankingThemeColor = _selectedRanking.themeColor;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(widget.cardIcon, color: Colors.grey.shade800),
                    const SizedBox(width: 8),
                    Text(widget.cardTitle, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),

                DropdownButtonHideUnderline(
                  child: DropdownButton<RankingInfo>(
                    borderRadius: BorderRadius.circular(16),
                    value: _selectedRanking, isExpanded: true,
                    icon: Icon(_selectedRanking.icon, color: rankingThemeColor),
                    items: widget.rankings.map((group) => DropdownMenuItem<RankingInfo>(
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
                          segments: [ButtonSegment<int>(value: 0, label: Text(_selectedRanking.sortAscendingForHigh ? 'Stronger' : 'High', style: const TextStyle(fontSize: 12))), ButtonSegment<int>(value: 1, label: Text(_selectedRanking.sortAscendingForHigh ? 'Weaker' : 'Low', style: const TextStyle(fontSize: 12)))],
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
                    borderRadius: BorderRadius.circular(16),
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

                double progressValue = 0.0;
                if (_selectedRanking.title.contains('Power Index')) {
                  final allValues = _rankedList.map((c) => 1 / (_selectedRanking.valueAccessor(c)?.toDouble() ?? 1.0));
                  final maxValue = allValues.reduce(math.max);
                  progressValue = (1 / (value.toDouble())) / maxValue;
                } else {
                  final allValues = _rankedList.map((c) => _selectedRanking.valueAccessor(c)?.toDouble() ?? 0.0);
                  final maxValue = allValues.isEmpty ? 1.0 : allValues.reduce(math.max);
                  progressValue = value.toDouble() / math.max(1.0, maxValue);
                }

                String displayValue;
                if (_selectedRanking.precision == 0 && !(_selectedRanking.title.contains('Power Index'))) {
                  displayValue = formatter.format(value);
                } else {
                  displayValue = value.toStringAsFixed(_selectedRanking.precision);
                }

                return Card(
                  elevation: 0,
                  color: isVisited ? rankingThemeColor.withOpacity(0.12) : Colors.transparent,
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
                              _buildRankText(rank, rankingThemeColor),
                              const SizedBox(width: 8),
                              Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(country.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                              Text('$displayValue${_selectedRanking.unit}', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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

// Combined Special Group Card (Existing Conscription/Nuclear States)
class _CombinedSpecialGroupCard extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;
  const _CombinedSpecialGroupCard({required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  State<_CombinedSpecialGroupCard> createState() => _CombinedSpecialGroupCardState();
}

class _CombinedSpecialGroupCardState extends State<_CombinedSpecialGroupCard> {
  late final List<SpecialGroupInfo> _groups;
  late SpecialGroupInfo _selectedGroup;
  bool _isExpanded = false;

  static const List<String> _allConscriptionCodes = ['ARM', 'AUT', 'AZE', 'BLR', 'BRA', 'CHN', 'CUB', 'CYP', 'EGY', 'ERI', 'EST', 'ETH', 'FIN', 'GRC', 'IRN', 'ISR', 'KAZ', 'KOR', 'KWT', 'LAO', 'LTU', 'MDA', 'MMR', 'NLD', 'NGA', 'NPL', 'NOR', 'PRK', 'QAT', 'RUS', 'SGP', 'SYR', 'THA', 'TUN', 'TUR', 'TKM', 'UKR', 'UZB', 'VNM'];
  static const List<String> _femaleConscriptionCodes = ['ERI', 'ISR', 'NLD', 'NOR', 'PRK', 'UKR'];
  static const List<String> _allNuclearCodes = ['USA', 'RUS', 'CHN', 'GBR', 'FRA', 'IND', 'PAK', 'ISR', 'PRK'];
  static const List<String> _unofficialNuclearCodes = ['IND', 'PAK', 'ISR', 'PRK'];

  @override
  void initState() {
    super.initState();
    _groups = [
      SpecialGroupInfo(
          title: 'Conscription Countries', icon: Icons.group, themeColor: Colors.indigo.shade700,
          memberCodes: _allConscriptionCodes,
          subMemberCodes: _femaleConscriptionCodes,
          subMemberLegend: '(*) Female Conscription',
          mapGroupsBuilder: _conscriptionMapBuilder
      ),
      SpecialGroupInfo(
        title: 'Nuclear Countries', icon: Icons.public_off, themeColor: Colors.green.shade700,
        memberCodes: _allNuclearCodes,
        subMemberCodes: _unofficialNuclearCodes,
        subMemberLegend: '(*) Unofficial Nuclear',
        mapGroupsBuilder: _nuclearMapBuilder,
      ),
    ];
    _selectedGroup = _groups.first;
  }

  static List<HighlightGroup> _conscriptionMapBuilder(List<Country> countries) {
    final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
    final female = _femaleConscriptionCodes.where(currentIsoA3s.contains).toList();
    final maleOnly = _allConscriptionCodes.where((c) => currentIsoA3s.contains(c) && !female.contains(c)).toList();
    return [
      HighlightGroup(name: 'Conscription', color: Colors.indigo.shade700, countryCodes: maleOnly),
      HighlightGroup(name: 'Female Conscription (*)', color: Colors.pink.shade700, countryCodes: female),
    ];
  }

  static List<HighlightGroup> _nuclearMapBuilder(List<Country> countries) {
    final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
    final unofficial = _unofficialNuclearCodes.where(currentIsoA3s.contains).toList();
    final official = _allNuclearCodes.where((c) => currentIsoA3s.contains(c) && !unofficial.contains(c)).toList();
    return [
      HighlightGroup(name: 'Official Nuclear', color: Colors.green.shade700, countryCodes: official),
      HighlightGroup(name: 'Unofficial Nuclear (*)', color: Colors.orange.shade700, countryCodes: unofficial),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentCountries = widget.countriesToDisplay.where((c) => _selectedGroup.memberCodes.contains(c.isoA3)).toList();
    final total = currentCountries.length;
    final visited = currentCountries.where((c) => widget.visitedCountryNames.contains(c.name)).length;
    final percentage = total > 0 ? (visited / total) : 0.0;
    final sortedCountries = List.from(currentCountries)..sort((a,b) => a.name.compareTo(b.name));

    return Card(
      elevation: 4, shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: Colors.grey.shade50,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SpecialGroupInfo>(
                borderRadius: BorderRadius.circular(16),
                value: _selectedGroup, isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) => DropdownMenuItem<SpecialGroupInfo>(
                  value: group,
                  child: Row(children: [
                    Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
                    Expanded(child: Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  ]),
                )).toList(),
                onChanged: (newValue) { if (newValue != null) { setState(() { _selectedGroup = newValue; _isExpanded = false; }); } },
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
                      Text("Visited Countries", style: theme.textTheme.bodyLarge),
                      Text.rich(TextSpan(
                        text: '$visited', style: theme.textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.w700),
                        children: [TextSpan(text: ' / $total', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
                      )),
                    ]),
                    ElevatedButton.icon(
                      onPressed: () {
                        final groups = _selectedGroup.mapGroupsBuilder(widget.countriesToDisplay);
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
            child: _isExpanded ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: GridView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
                    itemCount: sortedCountries.length,
                    itemBuilder: (context, index) {
                      final country = sortedCountries[index];
                      final isVisited = widget.visitedCountryNames.contains(country.name);
                      final isSubMember = _selectedGroup.subMemberCodes.contains(country.isoA3);
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => navigateToCountryDetail(context, country),
                        child: Container(
                          decoration: BoxDecoration(
                              color: isVisited ? _selectedGroup.themeColor.withOpacity(0.12) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8)
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: RichText(
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                      style: theme.textTheme.bodyMedium,
                                      children: [
                                        if(isSubMember)
                                          const TextSpan(text: '(*) ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                                        TextSpan(text: country.name),
                                      ]
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if(_selectedGroup.subMemberLegend.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_selectedGroup.subMemberLegend, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

// Single Bloc Tracking Group Card (WWI, WWII, UK, Israel, etc.)
class _CombinedHistoricalAllianceAndMiscCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedHistoricalAllianceAndMiscCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedHistoricalAllianceAndMiscCard> createState() => _CombinedHistoricalAllianceAndMiscCardState();
}

class _CombinedHistoricalAllianceAndMiscCardState extends State<_CombinedHistoricalAllianceAndMiscCard> {
  late final List<AchievementGroup> _groups;
  late AchievementGroup _selectedGroup;
  bool _isExpanded = false;

  static const List<String> _austriaHungarySuccessorCodes = ['AUT', 'HUN'];

  @override
  void initState() {
    super.initState();
    _groups = [
      AchievementGroup(
        title: 'WWI Central Powers', icon: Icons.flag, themeColor: Colors.red.shade900, mapLegend: 'WWI Central Power',
        entries: [
          _AchievementDisplayEntry('German Empire', ['DEU'], type: 'WWI'),
          _AchievementDisplayEntry('Austria-Hungary', _austriaHungarySuccessorCodes, type: 'WWI'),
          _AchievementDisplayEntry('Ottoman Empire', ['TUR'], type: 'WWI'),
          _AchievementDisplayEntry('Bulgaria', ['BGR'], type: 'WWI'),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
      AchievementGroup(
        title: 'WWII Axis Powers', icon: Icons.directions_bus_filled, themeColor: Colors.black, mapLegend: 'WWII Axis Power',
        entries: [
          _AchievementDisplayEntry('Germany', ['DEU'], type: 'WWII'),
          _AchievementDisplayEntry('Italy', ['ITA'], type: 'WWII'),
          _AchievementDisplayEntry('Japan', ['JPN'], type: 'WWII'),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
      AchievementGroup(
        title: 'UK Never Invaded', icon: Icons.sentiment_satisfied, themeColor: Colors.green.shade700, mapLegend: 'UK Never Invaded',
        entries: [
          _AchievementDisplayEntry('Countries Never Invaded', ['GTM', 'BOL', 'PRY', 'MLI', 'CIV', 'TCD', 'CAF', 'COG', 'SWE', 'BLR', 'UZB', 'KGZ', 'TJK', 'MNG'], type: 'NeverInvaded'),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
      AchievementGroup(
        title: 'Israel Conflict Countries', icon: Icons.gavel, themeColor: Colors.orange.shade800, mapLegend: 'Israel Conflict',
        entries: [
          _AchievementDisplayEntry('Conflict Countries', ['EGY', 'JOR', 'SYR', 'LBN', 'IRQ', 'SAU', 'PSE', 'IRN', 'TUN', 'SDN', 'YEM', 'MAR'], type: 'IsraelConflict'),
        ]..sort((a,b) => a.displayName.compareTo(b.displayName)),
      ),
    ];

    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final List<String> solidHighlightCodes = [];
    final List<String> fadedHighlightCodes = [];

    int totalEntries = _selectedGroup.entries.length;
    int visitedEntries = 0;

    for (var entry in _selectedGroup.entries) {
      bool isAnyVisited = entry.isoA3Codes.any((code) {
        final country = widget.allCountries.firstWhereOrNull((c) => c.isoA3 == code);
        return country != null && widget.visitedCountryNames.contains(country.name);
      });

      if (isAnyVisited) {
        visitedEntries++;
        solidHighlightCodes.addAll(entry.isoA3Codes);
      } else {
        fadedHighlightCodes.addAll(entry.isoA3Codes);
      }
    }
    final percentage = totalEntries > 0 ? (visitedEntries / totalEntries) : 0.0;

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
                      Text(group.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                            Text("Visited Entities", style: theme.textTheme.bodyLarge),
                            Text.rich(TextSpan(
                              text: '$visitedEntries',
                              style: theme.textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.w700),
                              children: [TextSpan(text: ' / $totalEntries', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
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

                      // 단일 국가면 국기+클릭
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
                            Expanded(child: Text(entry.displayName, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    },
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

// Two Blocs Comparison Group Card (Korean War, Vietnam War, R-U War)
class _CombinedHistoricalWarProgressCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedHistoricalWarProgressCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedHistoricalWarProgressCard> createState() => _CombinedHistoricalWarProgressCardState();
}

class _CombinedHistoricalWarProgressCardState extends State<_CombinedHistoricalWarProgressCard> {
  late final List<ConflictGroupInfo> _groups;
  late ConflictGroupInfo _selectedGroup;
  bool _isExpanded = false;

  static const List<String> _ussrSuccessorCodes = [
    'ARM', 'AZE', 'BLR', 'EST', 'GEO', 'KAZ', 'KGZ', 'LVA', 'LTU', 'MDA', 'RUS', 'TJK', 'TKM', 'UKR', 'UZB'
  ];

  @override
  void initState() {
    super.initState();
    final List<String> natoCoreCodes = ['USA', 'GBR', 'FRA', 'DEU', 'CAN'];

    _groups = [
      ConflictGroupInfo(
        title: 'Korean War', icon: Icons.local_police, themeColor: Colors.grey.shade900, mapLegend: 'Korean War Side',
        side1Name: 'North Allies', side1Color: Colors.red.shade700,
        side2Name: 'South Allies (UN)', side2Color: Colors.blue.shade700,
        side1Codes: [..._ussrSuccessorCodes, 'PRK', 'CHN'],
        side2Codes: ['KOR', 'USA', 'GBR', 'CAN', 'AUS', 'TUR', 'PHL', 'THA', 'NLD', 'COL', 'GRC', 'NZL', 'ETH', 'ZAF', 'FRA', 'BEL', 'LUX'],
      ),
      ConflictGroupInfo(
        title: 'Vietnam War', icon: Icons.local_fire_department, themeColor: Colors.green.shade900, mapLegend: 'Vietnam War Side',
        side1Name: 'North Allies', side1Color: Colors.red.shade700,
        side2Name: 'South Allies', side2Color: Colors.blue.shade700,
        side1Codes: [..._ussrSuccessorCodes, 'PRK', 'CHN'],
        side2Codes: ['USA', 'KOR', 'THA', 'AUS', 'NZL', 'PHL', 'TWN'],
      ),
      ConflictGroupInfo(
        title: 'Russia-Ukraine War', icon: Icons.directions_run, themeColor: Colors.blueGrey.shade700, mapLegend: 'R-U War Side',
        side1Name: 'Russia Supporters', side1Color: Colors.blueGrey.shade700,
        side2Name: 'NATO Core Opposition', side2Color: Colors.blue.shade700,
        side1Codes: ['BLR', 'KGZ', 'NIC', 'CUB', 'VEN', 'SRB', 'IRN', 'SYR', 'TUR', 'CHN', 'MMR', 'MLI', 'NER', 'ERI', 'UGA', 'ZWE', 'CAF', 'HUN'],
        side2Codes: natoCoreCodes,
      ),
    ];

    _selectedGroup = _groups.first;
  }

  double _calculateProgress(List<String> codes) {
    if (codes.isEmpty) return 0.0;
    final visitedCount = codes.where((code) {
      final country = widget.allCountries.firstWhereOrNull((c) => c.isoA3 == code);
      return country != null && widget.visitedCountryNames.contains(country.name);
    }).length;
    return visitedCount / codes.length;
  }

  Widget _buildSideSection(BuildContext context, ThemeData theme, String sideName, Color sideColor, List<String> codes) {
    final countries = codes
        .map((code) => widget.allCountries.firstWhereOrNull((c) => c.isoA3 == code))
        .whereType<Country>()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Container(
      decoration: BoxDecoration(
        color: sideColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sideColor.withOpacity(0.3), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: sideColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(sideName, style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold, color: sideColor,
              )),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 4.5,
              mainAxisSpacing: 6, crossAxisSpacing: 6,
            ),
            itemCount: countries.length,
            itemBuilder: (context, index) {
              final country = countries[index];
              final isVisited = widget.visitedCountryNames.contains(country.name);
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => navigateToCountryDetail(context, country),
                child: Container(
                  decoration: BoxDecoration(
                    color: isVisited ? sideColor.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Icon(
                        isVisited ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: isVisited ? sideColor : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(country.name,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final info = _selectedGroup;

    final progress1 = _calculateProgress(info.side1Codes);
    final progress2 = _calculateProgress(info.side2Codes);

    final visited1 = (progress1 * info.side1Codes.length).round();
    final visited2 = (progress2 * info.side2Codes.length).round();

    final total1 = info.side1Codes.length;
    final total2 = info.side2Codes.length;

    final List<String> allCodes = info.side1Codes.toSet().union(info.side2Codes.toSet()).toList();
    final List<Country> countriesToShow = allCodes.map((code) =>
        widget.allCountries.firstWhereOrNull((c) => c.isoA3 == code)
    ).whereType<Country>().toList()..sort((a,b) => a.name.compareTo(b.name));

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
              child: DropdownButton<ConflictGroupInfo>(
                borderRadius: BorderRadius.circular(16),
                value: _selectedGroup, isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: info.themeColor),
                items: _groups.map((group) => DropdownMenuItem<ConflictGroupInfo>(
                  value: group,
                  child: Row(
                    children: [
                      Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
                      Text(group.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                    Text(info.side1Name, style: textTheme.titleMedium?.copyWith(color: info.side1Color, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: LinearProgressIndicator(value: progress1, backgroundColor: info.side1Color.withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(info.side1Color), minHeight: 10, borderRadius: BorderRadius.circular(5))),
                        const SizedBox(width: 12),
                        Text('$visited1 / $total1', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(info.side2Name, style: textTheme.titleMedium?.copyWith(color: info.side2Color, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: LinearProgressIndicator(value: progress2, backgroundColor: info.side2Color.withOpacity(0.2), valueColor: AlwaysStoppedAnimation<Color>(info.side2Color), minHeight: 10, borderRadius: BorderRadius.circular(5))),
                        const SizedBox(width: 12),
                        Text('$visited2 / $total2', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: () {
                        final groups = <HighlightGroup>[];

                        final solid1Codes = info.side1Codes.where((code) {
                          final country = widget.allCountries.firstWhereOrNull((c) => c.isoA3 == code);
                          return country != null && widget.visitedCountryNames.contains(country.name);
                        }).toList();
                        final faded1Codes = info.side1Codes.where((code) => !solid1Codes.contains(code)).toList();

                        final solid2Codes = info.side2Codes.where((code) {
                          final country = widget.allCountries.firstWhereOrNull((c) => c.isoA3 == code);
                          return country != null && widget.visitedCountryNames.contains(country.name);
                        }).toList();
                        final faded2Codes = info.side2Codes.where((code) => !solid2Codes.contains(code)).toList();

                        if(faded1Codes.isNotEmpty) groups.add(HighlightGroup(name: '${info.side1Name} (Not Visited)', color: info.side1Color.withOpacity(0.35), countryCodes: faded1Codes, ignoreVisitedOpacity: true));
                        if(solid1Codes.isNotEmpty) groups.add(HighlightGroup(name: info.side1Name, color: info.side1Color, countryCodes: solid1Codes, ignoreVisitedOpacity: true));

                        if(faded2Codes.isNotEmpty) groups.add(HighlightGroup(name: '${info.side2Name} (Not Visited)', color: info.side2Color.withOpacity(0.35), countryCodes: faded2Codes, ignoreVisitedOpacity: true));
                        if(solid2Codes.isNotEmpty) groups.add(HighlightGroup(name: info.side2Name, color: info.side2Color, countryCodes: solid2Codes, ignoreVisitedOpacity: true));

                        Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: groups)));
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Map'),
                      style: ElevatedButton.styleFrom(backgroundColor: info.themeColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSideSection(context, theme, info.side1Name, info.side1Color, info.side1Codes),
                      const SizedBox(height: 12),
                      _buildSideSection(context, theme, info.side2Name, info.side2Color, info.side2Codes),
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

// War Casualties Ranking Card
class _CasualtyRankingCard extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _CasualtyRankingCard({required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  State<_CasualtyRankingCard> createState() => _CasualtyRankingCardState();
}

class _CasualtyRankingCardState extends State<_CasualtyRankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selectedRanking;
  List<Country> _rankedList = [];

  static final Map<String, Color> _continentColors = {
    'Asia': Colors.pink.shade200, 'Europe': Colors.amber, 'Africa': Colors.brown,
    'North America': Colors.blue.shade200, 'South America': Colors.green, 'Oceania': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _rankings = [
      RankingInfo(
          title: 'WWI Casualties',
          icon: Icons.history,
          themeColor: Colors.brown.shade700,
          valueAccessor: (c) => c.ww1Casualties,
          unit: '',
          precision: 0
      ),
      RankingInfo(
          title: 'WWII Casualties',
          icon: Icons.history_toggle_off,
          themeColor: Colors.red.shade900,
          valueAccessor: (c) => c.ww2Casualties,
          unit: '',
          precision: 0
      ),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _CasualtyRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countriesToDisplay, oldWidget.countriesToDisplay) ||
        !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames)) {
      _prepareList();
    }
  }

  void _prepareList() {
    // Switch removed: Always show All Countries
    List<Country> listToRank = List.from(widget.countriesToDisplay);

    listToRank = listToRank.where((c) => (_selectedRanking.valueAccessor(c) ?? 0) > 0).toList();

    listToRank.sort((a, b) {
      final valA = _selectedRanking.valueAccessor(a) ?? 0;
      final valB = _selectedRanking.valueAccessor(b) ?? 0;
      return valB.compareTo(valA);
    });

    if (mounted) setState(() { _rankedList = listToRank; });
  }

  Widget _buildRankText(int rank, Color color) {
    return Text(
      '$rank',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final useDefaultColor = countryProvider.useDefaultRankingBarColor;
    final rankingThemeColor = _selectedRanking.themeColor;

    final double maxValue = _rankedList.isNotEmpty
        ? _rankedList.map((c) => _selectedRanking.valueAccessor(c)?.toDouble() ?? 0.0).reduce(math.max)
        : 1.0;

    final numberFormat = NumberFormat.decimalPattern('en_US');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: rankingThemeColor.withOpacity(0.1),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: rankingThemeColor),
                    const SizedBox(width: 8),
                    Text("Historical War Casualties", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<RankingInfo>(
                    borderRadius: BorderRadius.circular(16),
                    value: _selectedRanking, isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, color: rankingThemeColor),
                    items: _rankings.map((group) => DropdownMenuItem<RankingInfo>(
                      value: group,
                      child: Row(children: [
                        Icon(group.icon, color: group.themeColor, size: 20),
                        const SizedBox(width: 12),
                        Text(group.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                    )).toList(),
                    onChanged: (newValue) { if (newValue != null) { setState(() { _selectedRanking = newValue; _prepareList(); }); } },
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
                final progressValue = value.toDouble() / math.max(1.0, maxValue);

                return Card(
                  elevation: 0,
                  color: isVisited ? rankingThemeColor.withOpacity(0.12) : Colors.transparent,
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
                              _buildRankText(rank, rankingThemeColor),
                              const SizedBox(width: 8),
                              Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(country.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15))),
                              Text(numberFormat.format(value), style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Stack(
                            children: [
                              Container(height: 6, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3))),
                              FractionallySizedBox(
                                widthFactor: progressValue,
                                child: Container(height: 6, decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(3))),
                              ),
                            ],
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