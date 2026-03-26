// lib/screens/specials_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:collection/collection.dart';
import 'dart:math' as math;
import 'package:jidoapp/screens/sports_stats_screen.dart';
import 'package:intl/intl.dart';

// Data Class: Ranking Info (for Country-based rankings)
class CountryRankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final num? Function(Country) valueAccessor;
  final String unit;
  final int precision;

  const CountryRankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.valueAccessor,
    this.unit = '',
    this.precision = 0,
  });
}

// Data Class: Special Group Info (Flag, Visit)
class SpecialGroupInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final String mapLegend;
  final List<String> memberCodes;
  final List<String>? specialHighlightCodes;
  final String? specialHighlightMapLegend;
  final Color? specialHighlightColor;

  const SpecialGroupInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.mapLegend,
    required this.memberCodes,
    this.specialHighlightCodes,
    this.specialHighlightMapLegend,
    this.specialHighlightColor,
  });
}

// SpecialsTabScreen
class SpecialsTabScreen extends StatelessWidget {
  const SpecialsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CountryProvider>(
      builder: (context, countryProvider, child) {
        if (countryProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final allCountries = countryProvider.allCountries;
        final visitedCountryNames = countryProvider.visitedCountries;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 1. A-Z Challenge
              _AlphabeticalChallengeCard(
                allCountries: allCountries,
                visitedCountryNames: visitedCountryNames,
              ),
              const SizedBox(height: 24),

              // 2. Physical Features (Height, IQ, etc.) - Top 10 Only
              SizedBox(
                height: 600,
                child: _CombinedRankingCard(
                  countriesToDisplay: allCountries,
                  visitedCountryNames: visitedCountryNames,
                ),
              ),
              const SizedBox(height: 24),

              // 3. Internet & Social Media - Top 10 Only
              SizedBox(
                height: 480,
                child: _CombinedInternetRankingCard(
                  allData: allCountries,
                  visitedNames: visitedCountryNames,
                ),
              ),
              const SizedBox(height: 24),

              // 4. Special Groups (Flag, Name, Visits, Space)
              _CombinedFlagCard(
                allCountries: allCountries,
                visitedCountryNames: visitedCountryNames,
              ),
              const SizedBox(height: 24),
              _CombinedNameCard(
                allCountries: allCountries,
                visitedCountryNames: visitedCountryNames,
              ),
              const SizedBox(height: 24),
              _CombinedVisitsCard(
                allCountries: allCountries,
                visitedCountryNames: visitedCountryNames,
              ),
              const SizedBox(height: 24),
              _CombinedSpaceCard(
                allCountries: allCountries,
                visitedCountryNames: visitedCountryNames,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// SpecialsStatsScreen
class SpecialsStatsScreen extends StatelessWidget {
  const SpecialsStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const List<Tab> tabs = <Tab>[
      Tab(icon: Icon(Icons.auto_awesome), text: 'Specials'),
      Tab(icon: Icon(Icons.sports_soccer), text: 'Sports'),
    ];

    final List<Widget> screens = <Widget>[
      const SpecialsTabScreen(),
      const SportsStatsScreen(),
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
  }
}

// A-Z Challenge Card
class _AlphabeticalChallengeCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _AlphabeticalChallengeCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_AlphabeticalChallengeCard> createState() => _AlphabeticalChallengeCardState();
}

class _AlphabeticalChallengeCardState extends State<_AlphabeticalChallengeCard> {
  static const List<String> _alphabets = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'Y', 'Z'];
  Map<String, List<Country>> _countriesByAlphabet = {};
  Map<String, int> _visitedCountByAlphabet = {};
  int _totalVisitedAlphabets = 0;
  final int _totalAlphabets = _alphabets.length;

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  @override
  void didUpdateWidget(covariant _AlphabeticalChallengeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.allCountries, oldWidget.allCountries) ||
        !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames)) {
      _prepareData();
    }
  }

  void _prepareData() {
    final tempCountries = <String, List<Country>>{ for (var a in _alphabets) a: [] };
    final tempVisitedCounts = <String, int>{ for (var a in _alphabets) a: 0 };
    int visitedAlphabetCount = 0;

    for (var country in widget.allCountries) {
      if (country.name.isNotEmpty) {
        final firstLetter = country.name[0].toUpperCase();
        if (_alphabets.contains(firstLetter)) {
          tempCountries[firstLetter]!.add(country);
          if (widget.visitedCountryNames.contains(country.name)) {
            tempVisitedCounts[firstLetter] = tempVisitedCounts[firstLetter]! + 1;
          }
        }
      }
    }

    for (var alphabet in _alphabets) {
      if(tempCountries[alphabet]!.isNotEmpty) {
        tempCountries[alphabet]!.sort((a, b) => a.name.compareTo(b.name));
        if (tempVisitedCounts[alphabet]! > 0) {
          visitedAlphabetCount++;
        }
      }
    }

    if (mounted) {
      setState(() {
        _countriesByAlphabet = tempCountries;
        _visitedCountByAlphabet = tempVisitedCounts;
        _totalVisitedAlphabets = visitedAlphabetCount;
      });
    }
  }

  void _showCountryListDialog(BuildContext context, String alphabet) {
    final countries = _countriesByAlphabet[alphabet] ?? [];
    if(countries.isEmpty) return;

    final theme = Theme.of(context);

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.all(0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          title: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
            decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('"$alphabet" Countries', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                TextButton.icon(
                  icon: const Icon(Icons.map_outlined, color: Colors.white),
                  label: const Text('Map', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () {
                    final countryCodes = countries.map((c) => c.isoA3).toList();
                    final groups = [HighlightGroup(name: 'Countries starting with $alphabet', color: Theme.of(context).primaryColor, countryCodes: countryCodes)];
                    Navigator.of(context).pop();
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: groups)));
                  },
                )
              ],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: countries.length,
              itemBuilder: (context, index) {
                final country = countries[index];
                final isVisited = widget.visitedCountryNames.contains(country.name);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isVisited ? theme.primaryColor.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      navigateToCountryDetail(context, country);
                    },
                    leading: Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 20)),
                    title: Text(country.name),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final percentage = _totalAlphabets > 0 ? (_totalVisitedAlphabets / _totalAlphabets) : 0.0;

    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Countries A-Z Challenge', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Visited Alphabets: $_totalVisitedAlphabets / $_totalAlphabets', style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                  ]),
                ),
                SizedBox(
                  width: 80, height: 80,
                  child: SleekCircularSlider(
                    initialValue: percentage * 100,
                    appearance: CircularSliderAppearance(
                      size: 80, customWidths: CustomSliderWidths(progressBarWidth: 8, trackWidth: 8),
                      customColors: CustomSliderColors(trackColor: Colors.grey.shade200, progressBarColor: Theme.of(context).primaryColor),
                      infoProperties: InfoProperties(
                        mainLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        modifier: (double value) => '${value.toStringAsFixed(0)}%',
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _alphabets.length,
                itemBuilder: (context, index) {
                  final alphabet = _alphabets[index];
                  final total = _countriesByAlphabet[alphabet]?.length ?? 0;
                  final visited = _visitedCountByAlphabet[alphabet] ?? 0;
                  final bool isStarted = visited > 0;
                  final bool isCompleted = total > 0 && visited == total;

                  return InkWell(
                    onTap: () => _showCountryListDialog(context, alphabet),
                    borderRadius: BorderRadius.circular(12),
                    child: Tooltip(
                      message: total > 0 ? '$visited / $total countries visited' : 'No countries starting with $alphabet',
                      child: Container(
                        decoration: BoxDecoration(
                            color: isCompleted ? Theme.of(context).primaryColor.withOpacity(0.2) : isStarted ? Theme.of(context).primaryColor.withOpacity(0.08) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: isCompleted ? Border.all(color: Theme.of(context).primaryColor, width: 1.5) : null
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(alphabet, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: total == 0 ? Colors.grey.shade400 : null)),
                            if(total > 0)
                              Text('$visited/$total', style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        )
    );
  }
}

// Combined Ranking Card (Physical Features)
class _CombinedRankingCard extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _CombinedRankingCard({required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  State<_CombinedRankingCard> createState() => _CombinedRankingCardState();
}

class _CombinedRankingCardState extends State<_CombinedRankingCard> {
  late final List<CountryRankingInfo> _rankings;
  late CountryRankingInfo _selectedRanking;
  List<Country> _rankedList = [];

  final Map<String, Color> _continentColors = {
    'Asia': Colors.pink.shade200, 'Europe': Colors.amber, 'Africa': Colors.brown,
    'North America': Colors.blue.shade200, 'South America': Colors.green, 'Oceania': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _rankings = [
      CountryRankingInfo(title: 'Height (Men)', icon: Icons.male, themeColor: Colors.blue, valueAccessor: (c) => c.maleHeight, unit: ' cm', precision: 0),
      CountryRankingInfo(title: 'Height (Women)', icon: Icons.female, themeColor: Colors.pink, valueAccessor: (c) => c.femaleHeight, unit: ' cm', precision: 0),
      CountryRankingInfo(title: 'Obesity Rate', icon: Icons.monitor_weight, themeColor: Colors.orange, valueAccessor: (c) => c.obesityRate, unit: '%', precision: 1),
      CountryRankingInfo(title: 'IQ', icon: Icons.psychology, themeColor: Colors.deepPurple, valueAccessor: (c) => c.iq, precision: 2),
      CountryRankingInfo(title: 'Male Bald Rate', icon: Icons.person_off_outlined, themeColor: Colors.grey.shade700, valueAccessor: (c) => c.malePatternBaldness, unit: '%', precision: 1),
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
    // 🚨 1. Fixed Filter: All Countries
    List<Country> listToRank = List.from(widget.countriesToDisplay);

    // 🚨 2. Fixed Continent: World (No filter)

    // Filter valid values
    listToRank = listToRank.where((c) => _selectedRanking.valueAccessor(c) != null && _selectedRanking.valueAccessor(c)! > 0).toList();

    // 🚨 3. Fixed Sort: High (Descending)
    listToRank.sort((a, b) {
      final valA = _selectedRanking.valueAccessor(a) ?? 0;
      final valB = _selectedRanking.valueAccessor(b) ?? 0;
      return valB.compareTo(valA); // Always Descending
    });

    // 🚨 4. Limit to Top 10
    listToRank = listToRank.take(10).toList();

    if (mounted) setState(() { _rankedList = listToRank; });
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
    final double maxValue = _rankedList.isNotEmpty ? _rankedList.map((c) => _selectedRanking.valueAccessor(c) ?? 0).reduce(math.max).toDouble() : 1.0;
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
                Row(
                  children: [
                    Icon(Icons.accessibility_new, color: rankingThemeColor),
                    const SizedBox(width: 8),
                    Text('Physical Features', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),

                DropdownButtonHideUnderline(
                  child: DropdownButton<CountryRankingInfo>(
                    borderRadius: BorderRadius.circular(16),
                    value: _selectedRanking, isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, color: rankingThemeColor),
                    items: _rankings.map((group) => DropdownMenuItem<CountryRankingInfo>(
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
                          _prepareList();
                        });
                      }
                    },
                  ),
                ),
                // 🚨 UI Controls Removed (All/Visited, High/Low, Continent)
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

// Combined Internet Ranking Card (Internet & Social Media)
class _CombinedInternetRankingCard extends StatefulWidget {
  final List<Country> allData;
  final Set<String> visitedNames;

  const _CombinedInternetRankingCard({
    required this.allData,
    required this.visitedNames,
  });

  @override
  State<_CombinedInternetRankingCard> createState() => _CombinedInternetRankingCardState();
}

class _CombinedInternetRankingCardState extends State<_CombinedInternetRankingCard> {
  late final List<CountryRankingInfo> _rankings;
  late CountryRankingInfo _selectedRanking;
  List<Country> _rankedList = [];

  final Map<String, Color> _continentColors = {
    'Asia': Colors.pink.shade200, 'Europe': Colors.amber, 'Africa': Colors.brown,
    'North America': Colors.blue.shade200, 'South America': Colors.green, 'Oceania': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _rankings = [
      CountryRankingInfo(title: 'Internet Speed', icon: Icons.speed, themeColor: Colors.cyan, valueAccessor: (c) => c.internetSpeed, unit: ' Mbps', precision: 0),
      CountryRankingInfo(title: 'Internet Users', icon: Icons.public, themeColor: Colors.blue, valueAccessor: (c) => c.internetUsers, unit: 'M users', precision: 0),
      CountryRankingInfo(title: 'Internet Penetration', icon: Icons.wifi, themeColor: Colors.lightBlueAccent, valueAccessor: (c) => c.internetPenetration, unit: '%', precision: 0),
      CountryRankingInfo(title: 'Facebook Users', icon: Icons.facebook, themeColor: Colors.blue.shade900, valueAccessor: (c) => c.facebookUsers, unit: 'M users', precision: 1),
      CountryRankingInfo(title: 'Instagram Users', icon: Icons.camera_alt, themeColor: Colors.pink.shade500, valueAccessor: (c) => c.instagramUsers, unit: 'M users', precision: 1),
      CountryRankingInfo(title: 'YouTube Users', icon: Icons.play_circle_fill, themeColor: Colors.red, valueAccessor: (c) => c.youtubeUsers, unit: 'M users', precision: 1),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _CombinedInternetRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.allData, oldWidget.allData) || !setEquals(widget.visitedNames, oldWidget.visitedNames)) {
      _prepareList();
    }
  }

  void _prepareList() {
    // 🚨 1. Fixed Filter: All Countries
    List<Country> listToRank = List.from(widget.allData);

    // 🚨 2. Fixed Continent: World (No filter)

    // Filter valid values
    listToRank = listToRank.where((c) {
      final value = _selectedRanking.valueAccessor(c);
      return value != null && value > 0;
    }).toList();

    // 🚨 3. Fixed Sort: High (Descending)
    listToRank.sort((a, b) {
      final valA = _selectedRanking.valueAccessor(a) ?? 0;
      final valB = _selectedRanking.valueAccessor(b) ?? 0;
      return valB.compareTo(valA); // Always Descending
    });

    // 🚨 4. Limit to Top 10
    listToRank = listToRank.take(10).toList();

    if (mounted) setState(() { _rankedList = listToRank; });
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
    final double maxValue = _rankedList.isNotEmpty ? _rankedList.map((c) => _selectedRanking.valueAccessor(c) ?? 0).reduce(math.max).toDouble() : 1.0;

    final rankingThemeColor = _selectedRanking.themeColor;
    final numberFormatter = NumberFormat.decimalPattern('en_US');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: rankingThemeColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi_tethering, color: rankingThemeColor),
                    const SizedBox(width: 8),
                    Text('Internet & Social Media', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<CountryRankingInfo>(
                    borderRadius: BorderRadius.circular(16),
                    value: _selectedRanking, isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, color: rankingThemeColor),
                    items: _rankings.map((group) => DropdownMenuItem<CountryRankingInfo>(
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
                // 🚨 UI Controls Removed (All/Visited, High/Low, Continent)
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
                  'No data to display. Check if the required data is available in technology.json and the ISO A3 mappings are correct.',
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
                final isVisited = widget.visitedNames.contains(country.name);
                final rank = index + 1;
                final value = _selectedRanking.valueAccessor(country) ?? 0;
                final barColor = useDefaultColor ? rankingThemeColor : (_continentColors[country.continent] ?? rankingThemeColor);
                final progressValue = value.toDouble() / math.max(1.0, maxValue);

                final formattedValue = '${numberFormatter.format(double.parse(value.toStringAsFixed(_selectedRanking.precision)))} ${_selectedRanking.unit}';

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


// Combined Flag Card
class _CombinedFlagCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;
  const _CombinedFlagCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedFlagCard> createState() => _CombinedFlagCardState();
}

class _CombinedFlagCardState extends State<_CombinedFlagCard> {
  late final List<SpecialGroupInfo> _groups;
  late SpecialGroupInfo _selectedGroup;
  bool _isExpanded = false;

  // Flag-related group codes
  static const List<String> _starOnFlagCountryCodes = [
    'ESH', 'DZA', 'AGO', 'ABW', 'AUS', 'AZE', 'BIH', 'BRA', 'BFA', 'BDI', 'CPV', 'CMR', 'CYM', 'CAF', 'CHL', 'CHN', 'COM', 'COD', 'HRV', 'CUB', 'CUW', 'DJI', 'DMA', 'TLS', 'GNQ', 'ETH', 'GHA', 'GRD', 'GNB', 'HND', 'HKG', 'IMN', 'ISR', 'JOR', 'KOS', 'LBR', 'MAC', 'MYS', 'MHL', 'MRT', 'FSM', 'MAR', 'MOZ', 'MMR', 'NRU', 'NPL', 'NZL', 'PRK', 'MNP', 'PAK', 'PAN', 'PNG', 'PRY', 'PHL', 'PRI', 'KNA', 'WSM', 'STP', 'SEN', 'SGP', 'SVN', 'SLB', 'SOM', 'SSD', 'SUR', 'SYR', 'TJK', 'TGO', 'TUN', 'TUR', 'TKM', 'TUV', 'USA', 'UZB', 'VEN', 'VNM', 'ZWE'
  ];
  static const List<String> _tricolorVerticalCountryCodes = [
    'AFG', 'AND', 'BRB', 'BEL', 'CMR', 'CAN', 'TCD', 'FRA', 'GTM', 'GIN', 'IRL', 'ITA', 'CIV', 'MLI', 'MEX', 'MDA', 'MNG', 'NGA', 'NFK', 'PER', 'ROU', 'BLM', 'MAF', 'SPM', 'VCT', 'SEN'
  ];
  static const List<String> _tricolorHorizontalCountryCodes = [
    'GHA', 'NER', 'NIC', 'LAO', 'LBN', 'LSO', 'RWA', 'PRY', 'LBY', 'MWI', 'MMR', 'VEN', 'SRB', 'SOM', 'ESP', 'SVK', 'SVN', 'SYR', 'ARG', 'AZE', 'ECU', 'ETH', 'SLV', 'HND', 'IRQ', 'TJK', 'IRN', 'EGY', 'IND', 'HRV', 'BOL', 'KHM', 'PYF'
  ];

  @override
  void initState() {
    super.initState();
    _groups = [
      SpecialGroupInfo(title: 'Animals on Flag', icon: Icons.pets, themeColor: Colors.brown, mapLegend: 'Animals on Flag', memberCodes: const ['FLK', 'AIA', 'HRV', 'AND', 'FJI', 'MEX', 'MDA', 'MNE', 'ALB', 'BTN', 'DMA', 'ECU', 'EGY', 'GTM', 'KAZ', 'KIR', 'PNG', 'SRB', 'ESP', 'LKA', 'UGA', 'ZMB', 'ZWE']),
      SpecialGroupInfo(title: 'Plants on Flag', icon: Icons.local_florist, themeColor: Colors.green, mapLegend: 'Plants on Flag', memberCodes: const ['CAN', 'CYP', 'ERI', 'GNQ', 'GUM', 'HKG', 'LBN', 'MAC', 'NFK', 'GRD']),

      SpecialGroupInfo(
        title: 'Star on Flag', icon: Icons.star, themeColor: Colors.amber.shade700, mapLegend: 'Star on Flag', memberCodes: _starOnFlagCountryCodes,
      ),
      SpecialGroupInfo(
        title: 'Tricolor (Vertical)', icon: Icons.vertical_split, themeColor: Colors.red.shade700, mapLegend: 'Tricolor Vertical', memberCodes: _tricolorVerticalCountryCodes,
      ),
      SpecialGroupInfo(
        title: 'Tricolor (Horizontal)', icon: Icons.horizontal_split, themeColor: Colors.blue.shade700, mapLegend: 'Tricolor Horizontal', memberCodes: _tricolorHorizontalCountryCodes,
      ),
    ];
    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentCountries = widget.allCountries.where((c) => _selectedGroup.memberCodes.contains(c.isoA3)).toList();
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
                borderRadius: BorderRadius.circular(16),
                value: _selectedGroup, isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) => DropdownMenuItem<SpecialGroupInfo>(
                  value: group,
                  child: Row(children: [
                    Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
                    Expanded(child: Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1)),
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
                        text: '$visited', style: textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                        children: [TextSpan(text: ' / $total', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
                      )),
                    ]),
                    ElevatedButton.icon(
                      onPressed: () {
                        final groups = <HighlightGroup>[];
                        final mainCodes = _selectedGroup.memberCodes.where((c) => !(_selectedGroup.specialHighlightCodes?.contains(c) ?? false)).toList();
                        groups.add(HighlightGroup(name: _selectedGroup.mapLegend, color: _selectedGroup.themeColor, countryCodes: mainCodes));
                        if (_selectedGroup.specialHighlightCodes != null) {
                          groups.add(HighlightGroup(name: _selectedGroup.specialHighlightMapLegend!, color: _selectedGroup.specialHighlightColor!, countryCodes: _selectedGroup.specialHighlightCodes!));
                        }
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
                          Expanded(child: Text(country.name, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
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

// Combined Name Card
class _CombinedNameCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;
  const _CombinedNameCard({super.key, required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedNameCard> createState() => _CombinedNameCardState();
}

class _CombinedNameCardState extends State<_CombinedNameCard> {
  late final List<SpecialGroupInfo> _groups;
  late SpecialGroupInfo _selectedGroup;
  bool _isExpanded = false;

  // Name-related group codes
  static const List<String> _nameEndingLandCodes = ['SOM', 'FIN', 'ISL', 'IRL', 'NLD', 'POL', 'CHE', 'THA', 'NZL', 'ALA', 'GRL'];
  static const List<String> _nameEndingStanCodes = ['KAZ', 'UZB', 'TKM', 'KGZ', 'TJK', 'PAK', 'AFG'];
  static const List<String> _nameDirectionalCodes = ['CAF', 'TLS', 'PRK', 'MKD', 'MNP', 'ZAF', 'SGS', 'KOR', 'SSD', 'ESH'];

  @override
  void initState() {
    super.initState();
    _groups = [
      SpecialGroupInfo(
        title: 'Ending in "-land"', icon: Icons.landscape, themeColor: Colors.green, mapLegend: 'Ending in "-land"', memberCodes: _nameEndingLandCodes,
      ),
      SpecialGroupInfo(
        title: 'Ending in "-stan"', icon: Icons.security, themeColor: Colors.brown.shade700, mapLegend: 'Ending in "-stan"', memberCodes: _nameEndingStanCodes,
      ),
      SpecialGroupInfo(
        title: 'Named after Directions', icon: Icons.compass_calibration, themeColor: Colors.blue, mapLegend: 'Named after Directions (North, South, East, West)', memberCodes: _nameDirectionalCodes,
      ),
    ];
    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentCountries = widget.allCountries.where((c) => _selectedGroup.memberCodes.contains(c.isoA3)).toList();
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
                borderRadius: BorderRadius.circular(16),
                value: _selectedGroup, isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) => DropdownMenuItem<SpecialGroupInfo>(
                  value: group,
                  child: Row(children: [
                    Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
                    Expanded(child: Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1)),
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
                        text: '$visited', style: textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                        children: [TextSpan(text: ' / $total', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
                      )),
                    ]),
                    ElevatedButton.icon(
                      onPressed: () {
                        final groups = <HighlightGroup>[];
                        final mainCodes = _selectedGroup.memberCodes.where((c) => !(_selectedGroup.specialHighlightCodes?.contains(c) ?? false)).toList();
                        groups.add(HighlightGroup(name: _selectedGroup.mapLegend, color: _selectedGroup.themeColor, countryCodes: mainCodes));
                        if (_selectedGroup.specialHighlightCodes != null) {
                          groups.add(HighlightGroup(name: _selectedGroup.specialHighlightMapLegend!, color: _selectedGroup.specialHighlightColor!, countryCodes: _selectedGroup.specialHighlightCodes!));
                        }
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
                          Expanded(child: Text(country.name, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
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

// Combined Visits Card
class _CombinedVisitsCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedVisitsCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedVisitsCard> createState() => _CombinedVisitsCardState();
}

class _CombinedVisitsCardState extends State<_CombinedVisitsCard> {
  late final List<SpecialGroupInfo> _groups;
  late SpecialGroupInfo _selectedGroup;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _groups = [
      SpecialGroupInfo(
        title: 'Queen Elizabeth II\'s Visits', icon: Icons.castle, themeColor: Colors.deepPurple, mapLegend: 'Visited by Queen',
        memberCodes: const ['AFG', 'DZA', 'ARG', 'AUS', 'AUT', 'BHS', 'BHR', 'BGD', 'BRB', 'BEL', 'BMU', 'BWA', 'BRA', 'BRN', 'CAN', 'CYM', 'CHL', 'CHN', 'COL', 'COK', 'HRV', 'CYP', 'CZE', 'DNK', 'EST', 'ETH', 'FJI', 'FIN', 'FRA', 'GMB', 'DEU', 'GHA', 'GRC', 'GUY', 'HUN', 'ISL', 'IND', 'IDN', 'IRN', 'IRL', 'ITA', 'JAM', 'JPN', 'JOR', 'KAZ', 'KEN', 'KIR', 'KWT', 'LVA', 'LBN', 'LSO', 'LBR', 'LBY', 'LTU', 'LUX', 'MDG', 'MWI', 'MLI', 'MUS', 'MAR', 'MOZ', 'NAM', 'NPL', 'NLD', 'NZL', 'NGA', 'NOR', 'OMN', 'PAK', 'PAN', 'PNG', 'POL', 'PRT', 'QAT', 'RUS', 'RWA', 'SAU', 'SEN', 'SLE', 'SGP', 'SVK', 'SVN', 'ZAF', 'KOR', 'ESP', 'LKA', 'SDN', 'SWE', 'CHE', 'TZA', 'THA', 'TON', 'TTO', 'TUN', 'TUR', 'TUV', 'UGA', 'UKR', 'ARE', 'USA', 'URY', 'VAT', 'YEM', 'YUG', 'ZMB', 'ZWE', 'SYC', 'MUS'],
        specialHighlightCodes: const ['GBR'], specialHighlightMapLegend: 'Her Majesty\'s Home (UK)', specialHighlightColor: Colors.red,
      ),
      SpecialGroupInfo(
        title: '14th Dalai Lama\'s Visits', icon: Icons.self_improvement, themeColor: Colors.orange.shade400, mapLegend: 'Visited by Dalai Lama',
        memberCodes: const ['ARG', 'AUS', 'AUT', 'BEL', 'BGR', 'CAN', 'CHL', 'CRI', 'CZE', 'DNK', 'SLV', 'EST', 'FIN', 'FRA', 'DEU', 'GTM', 'IDN', 'IRL', 'ITA', 'JPN', 'JOR', 'LVA', 'LIE', 'LTU', 'MYS', 'MEX', 'MNG', 'NLD', 'NZL', 'NIC', 'NOR', 'POL', 'PRI', 'SMR', 'SVK', 'ZAF', 'RUS', 'ESP', 'SWE', 'CHE', 'TWN', 'THA', 'GBR', 'USA', 'VAT'],
      ),
      SpecialGroupInfo(
        title: 'Pope John Paul II\'s Visits', icon: Icons.church, themeColor: Colors.blue.shade400, mapLegend: 'Visited by Pope',
        memberCodes: const ['ALB', 'AGO', 'ARM', 'AZE', 'BHS', 'BGD', 'BLZ', 'BOL', 'BWA', 'BGR', 'BDI', 'CPV', 'CAF', 'TCD', 'CHL', 'COL', 'COG', 'CRI', 'CUB', 'DNK', 'TLS', 'ECU', 'EGY', 'GNQ', 'ERI', 'EST', 'FJI', 'FIN', 'GAB', 'GMB', 'GEO', 'GHA', 'GRC', 'GUM', 'GIN', 'GNB', 'HTI', 'HND', 'ISL', 'IDN', 'IRL', 'ISR', 'JAM', 'JPN', 'JOR', 'KAZ', 'LVA', 'LBN', 'LSO', 'LIE', 'LTU', 'LUX', 'MDG', 'MWI', 'MLI', 'MUS', 'MAR', 'MOZ', 'NLD', 'NZL', 'NOR', 'PAK', 'PSE', 'PAN', 'PRY', 'ROU', 'RWA', 'LCA', 'SMR', 'STP', 'SEN', 'SYC', 'SGP', 'SLB', 'ZAF', 'LKA', 'SDN', 'SWZ', 'SWE', 'SYR', 'TZA', 'THA', 'TLS', 'TGO', 'TTO', 'TUN', 'TUR', 'UGA', 'UKR', 'ARE', 'USA', 'URY', 'VAT', 'YEM', 'ZMB', 'ZWE'],
        specialHighlightCodes: const ['VAT'], specialHighlightMapLegend: 'Holy See (Vatican City)', specialHighlightColor: Colors.yellow,
      ),
    ];
    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentCountries = widget.allCountries.where((c) => _selectedGroup.memberCodes.contains(c.isoA3)).toList();
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
                borderRadius: BorderRadius.circular(16),
                value: _selectedGroup, isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) => DropdownMenuItem<SpecialGroupInfo>(
                  value: group,
                  child: Row(children: [
                    Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
                    Expanded(child: Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1)),
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
                        text: '$visited', style: textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                        children: [TextSpan(text: ' / $total', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
                      )),
                    ]),
                    ElevatedButton.icon(
                      onPressed: () {
                        final groups = <HighlightGroup>[];
                        final mainCodes = _selectedGroup.memberCodes.where((c) => !(_selectedGroup.specialHighlightCodes?.contains(c) ?? false)).toList();
                        groups.add(HighlightGroup(name: _selectedGroup.mapLegend, color: _selectedGroup.themeColor, countryCodes: mainCodes));
                        if (_selectedGroup.specialHighlightCodes != null) {
                          groups.add(HighlightGroup(name: _selectedGroup.specialHighlightMapLegend!, color: _selectedGroup.specialHighlightColor!, countryCodes: _selectedGroup.specialHighlightCodes!));
                        }
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
                          Expanded(child: Text(country.name, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
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

// The combined Space Card (Updated)
class _CombinedSpaceCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;
  const _CombinedSpaceCard({super.key, required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedSpaceCard> createState() => _CombinedSpaceCardState();
}

class _CombinedSpaceCardState extends State<_CombinedSpaceCard> {
  late final List<SpecialGroupInfo> _groups;
  late SpecialGroupInfo _selectedGroup;
  bool _isExpanded = false;

  // Space-related group codes
  static const List<String> _moonLandingCodes = ['USA', 'JPN', 'RUS', 'CHN', 'IND'];
  static const List<String> _orbitalLaunchCodes = ['USA', 'RUS', 'CHN', 'IND', 'JPN', 'ISR', 'IRN', 'PRK', 'KOR'];
  static const List<String> _humanSpaceflightCodes = ['RUS', 'USA', 'CHN'];

  @override
  void initState() {
    super.initState();
    _groups = [
      SpecialGroupInfo(
        title: 'Landed on the Moon', icon: Icons.flag, themeColor: Colors.indigo, mapLegend: 'Landed on the Moon', memberCodes: _moonLandingCodes,
      ),
      SpecialGroupInfo(
        title: 'Domestic Orbital Launch', icon: Icons.rocket_launch, themeColor: Colors.red.shade700, mapLegend: 'Domestic Orbital Launch Capability', memberCodes: _orbitalLaunchCodes,
      ),
      SpecialGroupInfo(
        title: 'Sent Humans to Space', icon: Icons.emoji_people, themeColor: Colors.orange.shade700, mapLegend: 'Sent Humans to Space', memberCodes: _humanSpaceflightCodes,
      ),
    ];
    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentCountries = widget.allCountries.where((c) => _selectedGroup.memberCodes.contains(c.isoA3)).toList();
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
                borderRadius: BorderRadius.circular(16),
                value: _selectedGroup, isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) => DropdownMenuItem<SpecialGroupInfo>(
                  value: group,
                  child: Row(children: [
                    Icon(group.icon, color: group.themeColor), const SizedBox(width: 12),
                    Expanded(child: Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1)),
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
                        text: '$visited', style: textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                        children: [TextSpan(text: ' / $total', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
                      )),
                    ]),
                    ElevatedButton.icon(
                      onPressed: () {
                        final groups = <HighlightGroup>[];
                        final mainCodes = _selectedGroup.memberCodes.where((c) => !(_selectedGroup.specialHighlightCodes?.contains(c) ?? false)).toList();
                        groups.add(HighlightGroup(name: _selectedGroup.mapLegend, color: _selectedGroup.themeColor, countryCodes: mainCodes));
                        if (_selectedGroup.specialHighlightCodes != null) {
                          groups.add(HighlightGroup(name: _selectedGroup.specialHighlightMapLegend!, color: _selectedGroup.specialHighlightColor!, countryCodes: _selectedGroup.specialHighlightCodes!));
                        }
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
                          Expanded(child: Text(country.name, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
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