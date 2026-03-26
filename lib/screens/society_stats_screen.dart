// lib/screens/society_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart'; // 추가됨
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'package:jidoapp/screens/religion_stats_screen.dart';
import 'package:jidoapp/screens/language_stats_screen.dart';
import 'package:jidoapp/screens/history_stats_screen.dart';

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
  final bool isRestricted;

  RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.valueAccessor,
    this.unit = '',
    this.precision = 0,
    this.isRestricted = false,
  });
}

// Data Class: Special Group Info
class SpecialGroupInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final List<String> memberCodes;
  final List<HighlightGroup> Function(List<Country> countriesToDisplay) mapGroupsBuilder;

  SpecialGroupInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.memberCodes,
    required this.mapGroupsBuilder,
  });
}

// SocietyTabScreen
class SocietyTabScreen extends StatelessWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;
  const SocietyTabScreen({super.key, required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  Widget build(BuildContext context) {
    // 1. Development Rankings
    final List<RankingInfo> developmentRankings = [
      RankingInfo(title: 'Nobel Prizes', icon: Icons.emoji_events, themeColor: Colors.amber.shade700, valueAccessor: (c) => c.novel, precision: 0),
      RankingInfo(title: 'Democracy Index', icon: Icons.how_to_vote, themeColor: Colors.deepOrange, valueAccessor: (c) => c.democracy, precision: 2),
      RankingInfo(title: 'HDI', icon: Icons.trending_up, themeColor: Colors.teal, valueAccessor: (c) => c.hdi, precision: 3),
      // Tertiary Education 제한 적용 (Top 10)
      RankingInfo(title: 'Tertiary Education', icon: Icons.school, themeColor: Colors.indigo, valueAccessor: (c) => c.tertiaryEducation, unit: '%', precision: 1, isRestricted: true),
    ];

    // 2. Demographics Rankings
    final List<RankingInfo> demographicsRankings = [
      RankingInfo(title: 'Fertility Rate', icon: Icons.family_restroom, themeColor: Colors.pinkAccent, valueAccessor: (c) => c.fertilityRate, precision: 2),
      RankingInfo(title: 'Immigrant Rate', icon: Icons.luggage, themeColor: Colors.purple, valueAccessor: (c) => c.immigrantRate, unit: '%', precision: 1),
      RankingInfo(title: 'Sex Ratio (M/F)', icon: Icons.wc, themeColor: Colors.cyan, valueAccessor: (c) => c.sexRatio, unit: '', precision: 2),
    ];

    // 3. Public Health Rankings
    final List<RankingInfo> publicHealthRankings = [
      // Life Expectancy 제외하고 나머지 제한 적용 (Top 10)
      RankingInfo(title: 'Life Expectancy', icon: Icons.health_and_safety, themeColor: Colors.green, valueAccessor: (c) => c.lifeExpectancy, unit: ' yrs', precision: 1),
      RankingInfo(title: 'HIV Prevalence', icon: Icons.monitor_heart, themeColor: Colors.pink, valueAccessor: (c) => c.hivPrevalence, unit: '%', precision: 1, isRestricted: true),
      RankingInfo(title: 'Alzheimer\'s Case Rate', icon: Icons.psychology, themeColor: Colors.deepOrangeAccent, valueAccessor: (c) => c.alzheimersCaseRate, unit: ' /100k', precision: 0, isRestricted: true),
      RankingInfo(title: 'Cancer Rate (ASR)', icon: Icons.sick, themeColor: Colors.purpleAccent, valueAccessor: (c) => c.cancerRate, unit: '', precision: 1, isRestricted: true),
      RankingInfo(title: 'COVID-19 Vaccination', icon: Icons.vaccines, themeColor: Colors.blueAccent, valueAccessor: (c) => c.covidVaccinationRate, unit: '%', precision: 1, isRestricted: true),
      RankingInfo(title: 'Hospital Beds', icon: Icons.local_hospital, themeColor: Colors.teal.shade300, valueAccessor: (c) => c.hospitalBeds, unit: ' /1k', precision: 1, isRestricted: true),
      RankingInfo(title: 'Specialist Doctor Pay', icon: Icons.attach_money, themeColor: Colors.green.shade700, valueAccessor: (c) => c.specialistDoctorPay, unit: ' USD', precision: 0, isRestricted: true),
    ];

    // 4. Social Risk Rankings
    final List<RankingInfo> socialRiskRankings = [
      // Homicide Rate 제외하고 나머지 제한 적용 (Top 10)
      RankingInfo(title: 'Homicide Rate', icon: Icons.personal_injury, themeColor: Colors.red.shade800, valueAccessor: (c) => c.homicideRate, precision: 2),
      RankingInfo(title: 'Firearm Ownership', icon: Icons.shield, themeColor: Colors.black, valueAccessor: (c) => c.firearmOwnership, unit: ' /100', precision: 1, isRestricted: true),
      RankingInfo(title: 'Opiate Usage', icon: Icons.medication, themeColor: Colors.deepPurple, valueAccessor: (c) => c.opiateUsage, unit: '%', precision: 2, isRestricted: true),
      RankingInfo(title: 'Alcohol Consumption', icon: Icons.local_bar, themeColor: Colors.brown, valueAccessor: (c) => c.alcoholConsumption, unit: ' L', precision: 1, isRestricted: true),
      RankingInfo(title: 'Smoking Rate', icon: Icons.smoking_rooms, themeColor: Colors.grey, valueAccessor: (c) => c.smokersPercent, unit: '%', precision: 1, isRestricted: true),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormsOfGovernmentSection(
            countriesToDisplay: countriesToDisplay,
            visitedCountryNames: visitedCountryNames,
          ),
          const SizedBox(height: 24),

          // 1. Development
          SizedBox(
            height: 550,
            child: _RankingCategoryCard(
              cardTitle: 'Development',
              cardIcon: Icons.public,
              rankings: developmentRankings,
              countriesToDisplay: countriesToDisplay,
              visitedCountryNames: visitedCountryNames,
            ),
          ),
          const SizedBox(height: 24),

          // 2. Demographics
          SizedBox(
            height: 550,
            child: _RankingCategoryCard(
              cardTitle: 'Demographics',
              cardIcon: Icons.people,
              rankings: demographicsRankings,
              countriesToDisplay: countriesToDisplay,
              visitedCountryNames: visitedCountryNames,
            ),
          ),
          const SizedBox(height: 24),

          // 3. Public Health
          SizedBox(
            height: 550,
            child: _RankingCategoryCard(
              cardTitle: 'Public Health',
              cardIcon: Icons.health_and_safety,
              rankings: publicHealthRankings,
              countriesToDisplay: countriesToDisplay,
              visitedCountryNames: visitedCountryNames,
            ),
          ),
          const SizedBox(height: 24),

          // 4. Social Risk
          SizedBox(
            height: 550,
            child: _RankingCategoryCard(
              cardTitle: 'Social Risk',
              cardIcon: Icons.warning_amber_rounded,
              rankings: socialRiskRankings,
              countriesToDisplay: countriesToDisplay,
              visitedCountryNames: visitedCountryNames,
            ),
          ),
          const SizedBox(height: 24),

          // Age Related (Existing)
          SizedBox(
            height: 400,
            child: _AgeRelatedRankingCard(
              countriesToDisplay: countriesToDisplay,
              visitedCountryNames: visitedCountryNames,
            ),
          ),
          const SizedBox(height: 24),

          // Special Groups (Moved to Bottom)
          _CombinedSpecialGroupCard(
            countriesToDisplay: countriesToDisplay,
            visitedCountryNames: visitedCountryNames,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// SocietyStatsScreen (Wrapper)
class SocietyStatsScreen extends StatelessWidget {
  const SocietyStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CountryProvider>(
      builder: (context, countryProvider, child) {
        if (countryProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final filteredCountries = countryProvider.filteredCountries;
        final visitedCountryNames = countryProvider.visitedCountries;

        const List<Tab> tabs = <Tab>[
          Tab(icon: Icon(Icons.groups), text: 'Society'),
          Tab(icon: Icon(Icons.import_contacts), text: 'Religion'),
          Tab(icon: Icon(Icons.language), text: 'Language'),
          Tab(icon: Icon(Icons.history_edu), text: 'History'),
        ];

        final List<Widget> screens = <Widget>[
          SocietyTabScreen(countriesToDisplay: filteredCountries, visitedCountryNames: visitedCountryNames),
          const ReligionStatsScreen(),
          const LanguageStatsScreen(),
          const HistoryStatsScreen(),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Material(
            color: Colors.white,
            child: SafeArea( // 상단바 겹침 방지 적용
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
                  Expanded(
                    child: TabBarView(
                      children: screens,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Government Section Widget
class _FormsOfGovernmentSection extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _FormsOfGovernmentSection({
    required this.countriesToDisplay,
    required this.visitedCountryNames,
  });

  @override
  State<_FormsOfGovernmentSection> createState() => _FormsOfGovernmentSectionState();
}

class _FormsOfGovernmentSectionState extends State<_FormsOfGovernmentSection> {
  Map<String, String> _govData = {};
  bool _isLoadingGovData = true;
  final Set<String> _expandedStatuses = {};

  final Map<String, Color> _govColors = {
    'Presidential': const Color(0xFF2E86DE),
    'Semi-presidential': const Color(0xFF8E44AD),
    'Parliamentary': const Color(0xFF27AE60),
    'Absolute monarchy': const Color(0xFF2C3E50),
    'Socialist': const Color(0xFFE74C3C),
    'Theocracy': const Color(0xFFA0522D),
    'Military': const Color(0xFFE67E22),
  };

  @override
  void initState() {
    super.initState();
    _loadGovData();
  }

  Future<void> _loadGovData() async {
    try {
      final String response = await rootBundle.loadString('assets/gov.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _govData = {
          for (var item in data)
            item['iso_a3'] as String: item['GOV'] as String
        };
      });
    } catch (e) {
      debugPrint('🚨🚨🚨 Government Data Load Error: $e');
    } finally {
      setState(() {
        _isLoadingGovData = false;
      });
    }
  }

  void _toggleStatusExpanded(String statusTitle) {
    setState(() {
      if (_expandedStatuses.contains(statusTitle)) {
        _expandedStatuses.remove(statusTitle);
      } else {
        _expandedStatuses.add(statusTitle);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingGovData) {
      return const Center(child: CircularProgressIndicator());
    }

    final Map<String, List<Country>> groupedByGov = {};
    for (var type in _govColors.keys) {
      groupedByGov[type] = [];
    }

    for (var country in widget.countriesToDisplay) {
      final govType = _govData[country.isoA3];
      if (govType != null && groupedByGov.containsKey(govType)) {
        groupedByGov[govType]!.add(country);
      }
    }

    final sortedGovTypes = _govColors.keys.toList();
    final theme = Theme.of(context);

    final List<Widget> govTiles = sortedGovTypes.map((title) {
      final countries = groupedByGov[title] ?? [];
      if (countries.isEmpty) return const SizedBox.shrink();

      final total = countries.length;
      final visited = countries.where((c) => widget.visitedCountryNames.contains(c.name)).length;
      final percentage = total > 0 ? (visited / total) : 0.0;
      final statusColor = _govColors[title] ?? theme.primaryColor;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: _GovernmentTile(
          title: title,
          countries: countries,
          visitedNames: widget.visitedCountryNames,
          percentage: percentage,
          color: statusColor,
          isExpanded: _expandedStatuses.contains(title),
          onToggle: _toggleStatusExpanded,
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
              icon: const Icon(Icons.account_balance, color: Colors.white, size: 20),
              label: const Text(
                'Government Type Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                final List<HighlightGroup> highlightGroups = [];
                for (var type in sortedGovTypes) {
                  final countries = groupedByGov[type];
                  if (countries != null && countries.isNotEmpty) {
                    highlightGroups.add(HighlightGroup(
                      name: type,
                      color: _govColors[type] ?? Colors.grey,
                      countryCodes: countries.map((c) => c.isoA3).toList(),
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
          children: govTiles,
        ),
      ],
    );
  }
}

// Government Tile Widget
class _GovernmentTile extends StatelessWidget {
  final String title;
  final List<Country> countries;
  final Set<String> visitedNames;
  final double percentage;
  final Color color;
  final bool isExpanded;
  final Function(String) onToggle;

  const _GovernmentTile({
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
                        return InkWell( // 클릭 시 해당 국가 화면으로 이동
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

// REFACTORED: Generic Ranking Category Card
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
      final valA = _selectedRanking.valueAccessor(a) ?? 0;
      final valB = _selectedRanking.valueAccessor(b) ?? 0;
      return _sortOrderSegment == 0 ? valB.compareTo(valA) : valA.compareTo(valB);
    });

    // 제한된 항목(isRestricted=true)인 경우 상위 10개만 남김
    if (_selectedRanking.isRestricted) {
      listToRank = listToRank.take(10).toList();
    }

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
    final double maxValue = _rankedList.isNotEmpty ? _rankedList.map((c) => _selectedRanking.valueAccessor(c)?.toDouble() ?? 0.0).reduce(math.max) : 1.0;

    final rankingThemeColor = _selectedRanking.themeColor;
    final isRestricted = _selectedRanking.isRestricted;

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
                    borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
                    value: _selectedRanking, isExpanded: true,
                    icon: Icon(_selectedRanking.icon, color: rankingThemeColor),
                    items: widget.rankings.map((group) => DropdownMenuItem<RankingInfo>(
                      value: group,
                      child: Row(children: [
                        Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
                        Text(group.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                    )).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRanking = newValue;
                          // 제한된 항목 선택 시 필터 강제 조정
                          if (_selectedRanking.isRestricted) {
                            _displaySegment = 0; // All
                            _sortOrderSegment = 0; // High
                            _selectedContinent = 'World';
                          }
                          _prepareList();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: IgnorePointer(
                          ignoring: isRestricted,
                          child: Opacity(
                            opacity: isRestricted ? 0.5 : 1.0,
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
                            ),
                          ),
                        )
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: IgnorePointer(
                          ignoring: isRestricted,
                          child: Opacity(
                            opacity: isRestricted ? 0.5 : 1.0,
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
                            ),
                          ),
                        )
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IgnorePointer(
                    ignoring: isRestricted,
                    child: Opacity(
                      opacity: isRestricted ? 0.5 : 1.0,
                      child: DropdownButton<String>(
                        borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
                        value: _selectedContinent,
                        items: _continents.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (String? newValue) { _selectedContinent = newValue!; _onFilterChanged(); },
                        underline: const SizedBox(),
                      ),
                    ),
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
                  child: InkWell( // 클릭 시 해당 국가 화면으로 이동
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
                              Text('${value.toStringAsFixed(_selectedRanking.precision)}${_selectedRanking.unit}', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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

// Combined Special Group Card (Re-positioned to bottom in SocietyTabScreen)
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

  // Group Codes
  static const List<String> _drinkableTapWaterCountryCodes = [
    'AND', 'ABW', 'AUS', 'AUT', 'BHR', 'BEL', 'BMU', 'CAN', 'CHL', 'COK', 'CRI', 'HRV', 'CUW', 'CZE', 'DNK', 'EST', 'FIN', 'FRA', 'DEU', 'GRL', 'HUN', 'ISL', 'ISR', 'ITA', 'JPN', 'KWT', 'LIE', 'LUX', 'MLT', 'MCO', 'NLD', 'NCL', 'NZL', 'NOR', 'PLW', 'POL', 'PRT', 'PRI', 'IRL', 'SMR', 'SAU', 'SGP', 'SVK', 'SVN', 'KOR', 'ESP', 'SWE', 'CHE', 'VIR', 'ARE', 'GBR', 'USA'
  ];

  static const List<String> _activeExecutionCodes = ['NGA', 'SSD', 'TWN', 'USA', 'MYS', 'MMR', 'BHR', 'BGD', 'VNM', 'BLR', 'BWA', 'PRK', 'SAU', 'SOM', 'SDN', 'SYR', 'SGP', 'ARE', 'AFG', 'YEM', 'OMN', 'JOR', 'IRQ', 'IRN', 'EGY', 'IND', 'IDN', 'JPN', 'CHN', 'QAT', 'KWT', 'THA', 'PAK', 'PSE'];
  static const List<String> _maintainedNoExecutionCodes = ['GUY', 'GMB', 'GTM', 'GRD', 'NER', 'KOR', 'DMA', 'LAO', 'LBR', 'RUS', 'LBN', 'LSO', 'LBY', 'MWI', 'MLI', 'MAR', 'MRT', 'MDV', 'BRB', 'BHS', 'BLZ', 'BRN', 'VCT', 'LCA', 'KNA', 'LKA', 'DZA', 'ATG', 'ERI', 'SWZ', 'ETH', 'UGA', 'JAM', 'ZWE', 'CMR', 'KEN', 'COM', 'CUB', 'TJK', 'TZA', 'TON', 'TUN', 'TTO'];
  static const List<String> _specialCircumstancesCodes = ['BRA', 'SLV', 'ISR', 'CHL', 'PER', 'BFA'];
  static const List<String> _leftHandTrafficCountryCodes = ['AIA', 'ATG', 'AUS', 'BHS', 'BGD', 'BRB', 'BMU', 'BTN', 'BWA', 'VGB', 'BRN', 'CYM', 'COK', 'CYP', 'DMA', 'TLS', 'SWZ', 'FLK', 'FJI', 'GGY', 'GRD', 'GUY', 'HKG', 'IND', 'IDN', 'IRL', 'IMN', 'JAM', 'JPN', 'JEY', 'KEN', 'KIR', 'LSO', 'MAC', 'MWI', 'MYS', 'MDV', 'MLT', 'MUS', 'MSR', 'MOZ', 'NAM', 'NRU', 'NPL', 'NZL', 'NIU', 'NFK', 'PAK', 'PNG', 'PCN', 'KNA', 'LCA', 'VCT', 'WSM', 'SYC', 'SGP', 'SLB', 'ZAF', 'LKA', 'SUR', 'TZA', 'THA', 'TKL', 'TON', 'TUN', 'TTO', 'TCA', 'TUV', 'UGA', 'GBR', 'VIR', 'ZMB', 'ZWE'];
  static const List<String> _homogeneousCountryCodes = ['SOM', 'TWN', 'PRK', 'EGY', 'LSO', 'DZA', 'BGD', 'MAR', 'VUT', 'ARM', 'TUN', 'ALB', 'JPN', 'POL', 'TON', 'KIR', 'MHL', 'KHM', 'SLB', 'LBN', 'PRT', 'KOR', 'NRU'];
  static const List<String> _euthanasiaPermittedCountryCodes = ['NLD', 'BEL', 'LUX', 'COL', 'CHE', 'CAN', 'NZL', 'ESP', 'AUS', 'DEU', 'AUT'];

  static const List<String> _femaleLeaderCountryCodes = [
    'UKR', 'HND', 'DMA', 'VCT', 'TUN', 'JPN', 'TZA', 'AUS', 'VAT', 'NAM',
    'SVN', 'MLT', 'BRB', 'DNK', 'CAN', 'KNA', 'MDA', 'COD', 'SUR', 'LTU',
    'MHL', 'ISL', 'MKD', 'ITA', 'BLZ', 'LVA', 'IND', 'BHS', 'MEX', 'NZL',
    'TTO', 'LIE', 'BIH'
  ];
  static const List<String> _freeUniversityCountryCodes = [
    'CUB', 'MEX', 'EGY', 'PHL', 'MAR', 'LKA', 'NZL', 'URY', 'TTO', 'MUS',
    'FJI', 'IND', 'TUR', 'ARG', 'POL', 'TWN', 'LBN', 'EST', 'LUX', 'RUS',
    'BRA', 'CZE', 'IRN', 'CYP', 'DEU', 'KEN', 'SAU', 'ARE', 'NOR', 'SVK',
    'KWT', 'PAN', 'LTU', 'BRN', 'ISL', 'FRA', 'ITA', 'ESP', 'BEL', 'SWE',
    'GRC', 'AUT', 'DNK', 'SVN', 'MLT', 'FIN'
  ];
  static const List<String> _freecollegeCountryCodes = [
    'IND', 'CHN', 'IDN', 'PAK', 'BRA', 'RUS', 'MEX', 'JPN', 'EGY', 'PHL',
    'TUR', 'DEU', 'THA', 'GBR', 'FRA', 'ZAF', 'ITA', 'COL', 'KOR', 'ESP',
    'DZA', 'ARG', 'CAN', 'MAR', 'MYS', 'GHA', 'PER', 'AUS', 'PRK', 'BFA',
    'LKA', 'TWN', 'CHL', 'ROU', 'NLD', 'RWA', 'TUN', 'BEL', 'CUB', 'SWE',
    'CZE', 'PRT', 'GRC', 'ISR', 'AUT', 'CHE', 'HKG', 'BGR', 'SRB', 'DNK',
    'SGP', 'FIN', 'NOR', 'IRL', 'NZL', 'CRI', 'KWT', 'HRV', 'GEO', 'ALB',
    'BWA', 'TTO', 'MUS', 'BTN', 'MAC', 'LUX', 'SUR', 'MDV', 'BHS', 'ISL',
    'SYC', 'LIE', 'USA', 'NGA', 'BGD', 'COD', 'VNM', 'IRN', 'TZA', 'KEN',
    'MMR', 'SDN', 'UGA', 'IRQ', 'AGO', 'UKR', 'POL', 'UZB', 'SAU', 'CIV',
    'CMR', 'NPL', 'VEN', 'ZMB', 'KAZ', 'SEN', 'GTM', 'ECU', 'KHM', 'BOL',
    'JOR', 'DOM', 'ARE', 'HND', 'TJK', 'PNG', 'AZE', 'HUN', 'BLR', 'TKM',
    'LBY', 'PRY', 'SLV', 'LBN', 'OMN', 'SVK', 'PAN', 'MNG', 'URY', 'PRI',
    'BIH', 'QAT', 'NAM', 'MDA', 'ARM', 'LTU', 'SVN', 'LVA', 'MKD', 'BHR',
    'CYP','EST', 'SWZ', 'MNE', 'MLT', 'MCO'
  ];
  static const List<String> _pornographyIllegalCountryCodes = [
    'YEM', 'UZB', 'MYS', 'SAU', 'NPL', 'PRK', 'SYR', 'KHM', 'ARE', 'BLR',
    'LAO', 'TKM', 'OMN', 'KWT', 'ERI', 'QAT', 'ARM', 'BWA', 'GNQ', 'BHR',
    'MDV', 'BRN', 'CHN', 'IDN', 'PAK', 'BGD', 'VNM', 'IRN', 'TUR', 'THA',
    'TZA', 'KOR', 'UGA', 'AFG'
  ];
  static const List<String> _abortionRegulatedCountryCodes = [
    'CHN', 'RUS', 'VNM', 'TUR', 'THA', 'FRA', 'ZAF', 'ESP', 'ARG', 'CAN',
    'UKR', 'UZB', 'MOZ', 'NPL', 'KAZ', 'ROU', 'KHM', 'TUN', 'BEL', 'CUB',
    'SWE', 'CZE', 'PRT', 'AZE', 'GRC', 'BLR', 'TKM', 'BGR', 'SRB', 'DNK',
    'SGP', 'FIN', 'NOR', 'SVK', 'IRL', 'NZL', 'HRV', 'GEO', 'MNG', 'URY',
    'MDA', 'ARM', 'LTU', 'ALB', 'SVN', 'LVA', 'MKD', 'EST', 'GUY', 'LUX',
    'MNE', 'CPV', 'ISL', 'STP', 'IMN', 'SMR'
  ];
  static const List<String> _abortionJurisdictionVariesCountryCodes = [
    'USA', 'NGA', 'MEX', 'AUS', 'BIH'
  ];
  static const List<String> _prostitutionLegalCountryCodes = [
    'AUS', 'BGD', 'BOL', 'CPV', 'COL', 'ECU', 'ERI', 'DEU', 'GRC', 'HUN',
    'IDN', 'LBN', 'MOZ', 'NLD', 'NZL', 'PAN', 'PER', 'SLE', 'CHE', 'TUR',
    'URY', 'VEN'
  ];
  static const List<String> _prostitutionLimitedLegalityCountryCodes = [
    'DZA', 'ARG', 'AUT', 'BHS', 'BEL', 'BEN', 'BWA', 'BRA', 'BGR', 'BFA',
    'CAF', 'CHL', 'CUB', 'CYP', 'CZE', 'DNK', 'DOM', 'COD', 'EST', 'ETH',
    'FJI', 'FIN', 'GTM', 'HND', 'HKG', 'IND', 'ITA', 'CIV', 'JPN', 'KAZ',
    'KEN', 'KGZ', 'LVA', 'LUX', 'MAC', 'MDG', 'MWI', 'MLI', 'MLT', 'MEX',
    'NAM', 'NIC', 'NGA', 'MKD', 'POL', 'PRT', 'ROU', 'SEN', 'SGP', 'SLB',
    'SSD', 'ESP', 'TJK', 'THA', 'TLS', 'TGO', 'GBR', 'ZMB'
  ];
  static const List<String> _cannabisLegalCountryCodes = [
    'CAN', 'MLT', 'URY', 'DEU'
  ];
  static const List<String> _cannabisPartiallyLegalCountryCodes = [
    'USA', 'IND', 'MEX', 'LUX', 'GEO', 'THA', 'ZAF'
  ];


  @override
  void initState() {
    super.initState();
    final allIsoA3s = widget.countriesToDisplay.map((c) => c.isoA3).toSet();

    _groups = [
      SpecialGroupInfo(
          title: 'Drinkable Tap Water', icon: Icons.water_drop, themeColor: Colors.blue,
          memberCodes: _drinkableTapWaterCountryCodes,
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [HighlightGroup(name: 'Drinkable Tap Water', color: Colors.blue, countryCodes: _drinkableTapWaterCountryCodes.where(currentIsoA3s.contains).toList())];
          }
      ),

      SpecialGroupInfo(
          title: 'Capital Punishment', icon: Icons.gavel, themeColor: Colors.red,
          memberCodes: {..._activeExecutionCodes, ..._maintainedNoExecutionCodes, ..._specialCircumstancesCodes}.toList(),
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [
              HighlightGroup(name: 'Active Execution', color: Colors.red, countryCodes: _activeExecutionCodes.where(currentIsoA3s.contains).toList()),
              HighlightGroup(name: 'Maintained (No Recent)', color: Colors.yellow, countryCodes: _maintainedNoExecutionCodes.where(currentIsoA3s.contains).toList()),
              HighlightGroup(name: 'Special Circumstances', color: Colors.lightGreen, countryCodes: _specialCircumstancesCodes.where(currentIsoA3s.contains).toList()),
            ];
          }
      ),
      SpecialGroupInfo(
          title: 'Left-Hand Traffic', icon: Icons.traffic, themeColor: Colors.blue.shade700,
          memberCodes: _leftHandTrafficCountryCodes,
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [HighlightGroup(name: 'Left-Hand Traffic', color: Colors.blue.shade700, countryCodes: _leftHandTrafficCountryCodes.where(currentIsoA3s.contains).toList())];
          }
      ),
      SpecialGroupInfo(
          title: 'Homogeneous Countries', icon: Icons.group_work, themeColor: Colors.purple.shade700,
          memberCodes: _homogeneousCountryCodes,
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [HighlightGroup(name: '95% Homogeneity or More', color: Colors.purple.shade700, countryCodes: _homogeneousCountryCodes.where(currentIsoA3s.contains).toList())];
          }
      ),
      SpecialGroupInfo(
          title: 'Euthanasia Permitted', icon: Icons.healing, themeColor: Colors.red.shade700,
          memberCodes: _euthanasiaPermittedCountryCodes,
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [HighlightGroup(name: 'Euthanasia Permitted', color: Colors.red.shade700, countryCodes: _euthanasiaPermittedCountryCodes.where(currentIsoA3s.contains).toList())];
          }
      ),

      SpecialGroupInfo(
          title: 'Current/Recent Female Leader', icon: Icons.woman, themeColor: Colors.orange,
          memberCodes: _femaleLeaderCountryCodes,
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [HighlightGroup(name: 'Female Leader (Current/Recent)', color: Colors.orange, countryCodes: _femaleLeaderCountryCodes.where(currentIsoA3s.contains).toList())];
          }
      ),
      SpecialGroupInfo(
          title: 'Free University Status', icon: Icons.account_balance, themeColor: Colors.lightBlue,
          memberCodes: _freeUniversityCountryCodes,
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [HighlightGroup(name: 'Free University', color: Colors.lightBlue, countryCodes: _freeUniversityCountryCodes.where(currentIsoA3s.contains).toList())];
          }
      ),
      SpecialGroupInfo(
          title: 'Free College Status', icon: Icons.school_outlined, themeColor: Colors.indigoAccent,
          memberCodes: _freecollegeCountryCodes,
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [HighlightGroup(name: 'Free College', color: Colors.indigoAccent, countryCodes: _freecollegeCountryCodes.where(currentIsoA3s.contains).toList())];
          }
      ),
      SpecialGroupInfo(
          title: 'Pornography Illegal', icon: Icons.no_photography, themeColor: Colors.black,
          memberCodes: _pornographyIllegalCountryCodes,
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [HighlightGroup(name: 'Pornography Illegal', color: Colors.black, countryCodes: _pornographyIllegalCountryCodes.where(currentIsoA3s.contains).toList())];
          }
      ),

      SpecialGroupInfo(
          title: 'Abortion Legality Status', icon: Icons.pregnant_woman, themeColor: Colors.green,
          memberCodes: {..._abortionRegulatedCountryCodes, ..._abortionJurisdictionVariesCountryCodes}.toList(),
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [
              HighlightGroup(name: 'Legal/Regulated', color: Colors.green, countryCodes: _abortionRegulatedCountryCodes.where(currentIsoA3s.contains).toList()),
              HighlightGroup(name: 'Jurisdiction Varies', color: Colors.yellow, countryCodes: _abortionJurisdictionVariesCountryCodes.where(currentIsoA3s.contains).toList()),
            ];
          }
      ),
      SpecialGroupInfo(
          title: 'Prostitution Legality Status', icon: Icons.hotel, themeColor: Colors.pink,
          memberCodes: {..._prostitutionLegalCountryCodes, ..._prostitutionLimitedLegalityCountryCodes}.toList(),
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [
              HighlightGroup(name: 'Legal/Decriminalized', color: Colors.pink, countryCodes: _prostitutionLegalCountryCodes.where(currentIsoA3s.contains).toList()),
              HighlightGroup(name: 'Limited/Regulated', color: Colors.deepOrange, countryCodes: _prostitutionLimitedLegalityCountryCodes.where(currentIsoA3s.contains).toList()),
            ];
          }
      ),
      SpecialGroupInfo(
          title: 'Cannabis Legality Status', icon: Icons.grass, themeColor: Colors.green.shade900,
          memberCodes: {..._cannabisLegalCountryCodes, ..._cannabisPartiallyLegalCountryCodes}.toList(),
          mapGroupsBuilder: (countries) {
            final currentIsoA3s = countries.map((c) => c.isoA3).toSet();
            return [
              HighlightGroup(name: 'Legal/Recreational', color: Colors.green.shade900, countryCodes: _cannabisLegalCountryCodes.where(currentIsoA3s.contains).toList()),
              HighlightGroup(name: 'Partially Legal/Medical', color: Colors.lightGreen.shade700, countryCodes: _cannabisPartiallyLegalCountryCodes.where(currentIsoA3s.contains).toList()),
            ];
          }
      ),
    ];
    _selectedGroup = _groups.first;
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
            child: _isExpanded ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: sortedCountries.length,
                itemBuilder: (context, index) {
                  final country = sortedCountries[index];
                  final isVisited = widget.visitedCountryNames.contains(country.name);
                  return InkWell( // 클릭 시 해당 국가 화면으로 이동
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => navigateToCountryDetail(context, country),
                    child: Container(
                      decoration: BoxDecoration(
                          color: isVisited ? _selectedGroup.themeColor.withOpacity(0.12) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8)
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 16)), // 국기 추가
                          const SizedBox(width: 6),
                          Expanded(
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(country.name, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)
                            ),
                          ),
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

// Age Related Ranking Card
class _AgeRelatedRankingCard extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _AgeRelatedRankingCard({required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  State<_AgeRelatedRankingCard> createState() => _AgeRelatedRankingCardState();
}

class _AgeRelatedRankingCardState extends State<_AgeRelatedRankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selectedRanking;

  int _displaySegment = 0;
  int _sortOrderSegment = 0; // 0: High, 1: Low
  List<Country> _rankedList = [];

  @override
  void initState() {
    super.initState();
    _rankings = [
      RankingInfo(
          title: 'Median Age',
          icon: Icons.hourglass_bottom,
          themeColor: Colors.teal.shade700,
          valueAccessor: (c) => c.medianAge,
          unit: ' yrs',
          precision: 1
      ),
      RankingInfo(
          title: 'Age at First Marriage',
          icon: Icons.favorite,
          themeColor: Colors.pinkAccent,
          valueAccessor: (c) => c.ageAtFirstMarriage,
          unit: ' yrs',
          precision: 1
      ),
      RankingInfo(
          title: 'Avg Age at First Birth',
          icon: Icons.pregnant_woman,
          themeColor: Colors.orange.shade800,
          valueAccessor: (c) => c.avgAgeFirstBirth,
          unit: ' yrs',
          precision: 1
      ),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _AgeRelatedRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countriesToDisplay, oldWidget.countriesToDisplay) ||
        !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames)) {
      _prepareList();
    }
  }

  void _prepareList() {
    List<Country> listToRank;
    // 0: All, 1: Visited
    if (_displaySegment == 1) {
      listToRank = widget.countriesToDisplay.where((c) => widget.visitedCountryNames.contains(c.name)).toList();
    } else {
      listToRank = List.from(widget.countriesToDisplay);
    }

    // Filter out null values for the selected metric
    listToRank = listToRank.where((c) => _selectedRanking.valueAccessor(c) != null).toList();

    // Sort
    listToRank.sort((a, b) {
      final valA = _selectedRanking.valueAccessor(a) ?? 0;
      final valB = _selectedRanking.valueAccessor(b) ?? 0;
      // 0: High to Low, 1: Low to High (Default for age might be interesting either way)
      return _sortOrderSegment == 0 ? valB.compareTo(valA) : valA.compareTo(valB);
    });

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

    final double maxValue = _rankedList.isNotEmpty
        ? _rankedList.map((c) => _selectedRanking.valueAccessor(c)?.toDouble() ?? 0.0).reduce(math.max)
        : 1.0;

    final rankingThemeColor = _selectedRanking.themeColor;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.cake, color: Colors.deepPurple), // Section Icon
                    const SizedBox(width: 8),
                    Text("Age Demographics", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<RankingInfo>(
                    borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                            visualDensity: VisualDensity.compact,
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List Section
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
                // Use ranking theme color for simplicity in this dedicated card
                final barColor = rankingThemeColor;
                final progressValue = value.toDouble() / math.max(1.0, maxValue);

                return Card(
                  elevation: 0,
                  color: isVisited ? rankingThemeColor.withOpacity(0.12) : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell( // 클릭 시 해당 국가 화면으로 이동
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
                              Expanded(child: Text(country.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15))),
                              Text('${value.toStringAsFixed(_selectedRanking.precision)}${_selectedRanking.unit}', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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