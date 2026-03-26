// lib/screens/religion_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:flutter/foundation.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/religion_provider.dart';
import 'package:jidoapp/models/religion_data_model.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart'; // CountryDetailScreen 임포트 추가

import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // 리스트 비교용
import 'dart:math' as math; // max 계산용
import 'package:intl/intl.dart'; // 숫자 포맷팅용

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

class ReligionStatsScreen extends StatefulWidget {
  const ReligionStatsScreen({super.key});

  @override
  State<ReligionStatsScreen> createState() => _ReligionStatsScreenState();
}

class _ReligionStatsScreenState extends State<ReligionStatsScreen> {
  // 1. 확장/축소 상태를 관리하는 Set
  final Set<String> _expandedItems = {};

  // 종파 보기 스위치 상태
  bool _showDenominations = false;

  // 종교/종파별 대표 색상
  final Map<String, Color> _religionColors = {
    'Christianity': Colors.purple,
    'Catholicism': const Color(0xFF795548),
    'Protestantism': Colors.pinkAccent,
    'Eastern Orthodoxy': const Color(0xFF4A004A),
    'Islam': Colors.green,
    'Sunni': const Color(0xFF98FB98),
    'Shia': const Color(0xFF808000),
    'Ibadi': const Color(0xFF3CB371),
    'Hinduism': Colors.red,
    'Buddhism': Colors.orange,
    'Judaism': Colors.blue,
    'Others': Colors.grey,
  };

  // 확장/축소 토글 함수
  void _toggleExpanded(String itemName) {
    setState(() {
      if (_expandedItems.contains(itemName)) {
        _expandedItems.remove(itemName);
      } else {
        _expandedItems.add(itemName);
      }
    });
  }

  // 2. HighlightGroup 생성 로직
  List<HighlightGroup> _getReligionHighlightGroups(List<Country> allCountries, Map<String, ReligionData> religionDataMap) {
    final Map<String, List<String>> groups = {};

    final Set<String> allKeys = _religionColors.keys.toSet();
    for (var key in allKeys) {
      groups[key] = [];
    }

    // 국가별로 가장 적절한 그룹 키(종교 또는 종파)를 찾아 할당
    for (var country in allCountries) {
      final religionInfo = religionDataMap[country.isoA3];
      String groupKey = 'Others';

      if (religionInfo != null) {
        final String religion = religionInfo.religion;
        final String? denomination = religionInfo.denomination;

        if (_showDenominations && (religion == 'Christianity' || religion == 'Islam')) {
          // 스위치 ON: 기독교/이슬람은 종파로 그룹핑
          groupKey = denomination != null && allKeys.contains(denomination) ? denomination : religion;
        } else if (allKeys.contains(religion)) {
          // 스위치 OFF 또는 기타 종교: 주 종교로 그룹핑
          groupKey = religion;
        }
      }

      groups[groupKey]!.add(country.isoA3);
    }

    // HighlightGroup 리스트로 변환
    final List<HighlightGroup> highlightGroups = [];
    groups.forEach((name, codes) {
      if (codes.isNotEmpty) {
        highlightGroups.add(HighlightGroup(
          name: name,
          color: _religionColors[name] ?? Colors.grey,
          countryCodes: codes,
        ));
      }
    });

    // 'Others'를 마지막에 배치
    highlightGroups.sort((a, b) {
      if (a.name == 'Others') return 1;
      if (b.name == 'Others') return -1;
      return 0;
    });

    return highlightGroups;
  }

  @override
  Widget build(BuildContext context) {
    final countryProvider = Provider.of<CountryProvider>(context);
    final religionProvider = Provider.of<ReligionProvider>(context);

    if (countryProvider.isLoading || religionProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final countries = countryProvider.allCountries;
    final visited = countryProvider.visitedCountries;
    final religionDataMap = religionProvider.religionDataMap as Map<String, ReligionData>;

    final Map<String, List<Country>> countriesByReligion = {};
    final Map<String, List<Country>> countriesByDenomination = {};

    for (var country in countries) {
      final religionInfo = religionDataMap[country.isoA3];
      if (religionInfo != null) {
        countriesByReligion.putIfAbsent(religionInfo.religion, () => []).add(country);
        if (religionInfo.denomination != null) {
          countriesByDenomination.putIfAbsent(religionInfo.denomination!, () => []).add(country);
        }
      }
    }

    final List<Map<String, dynamic>> allStats = [
      {'type': 'religion', 'name': 'Christianity'},
      {'type': 'denomination', 'name': 'Catholicism', 'isSub': true},
      {'type': 'denomination', 'name': 'Protestantism', 'isSub': true},
      {'type': 'denomination', 'name': 'Eastern Orthodoxy', 'isSub': true},
      {'type': 'religion', 'name': 'Islam'},
      {'type': 'denomination', 'name': 'Sunni', 'isSub': true},
      {'type': 'denomination', 'name': 'Shia', 'isSub': true},
      {'type': 'denomination', 'name': 'Ibadi', 'isSub': true},
      {'type': 'religion', 'name': 'Hinduism'},
      {'type': 'religion', 'name': 'Buddhism'},
      {'type': 'religion', 'name': 'Judaism'},
    ];

    final List<Map<String, dynamic>> visibleStats = allStats.where((stat) {
      final bool isSub = stat['isSub'] ?? false;
      if (isSub && !_showDenominations) {
        return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // 1. 전체 지도 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.deepOrange.shade400],
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
                icon: const Icon(Icons.public, color: Colors.white, size: 20),
                label: const Text(
                  'World Religions Map',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                onPressed: () {
                  final List<HighlightGroup> highlightGroups = _getReligionHighlightGroups(countries, religionDataMap);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: highlightGroups)));
                },
              ),
            ),
          ),
          const Divider(),

          // 2. 종파 보기 스위치
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Show Denominations',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: _showDenominations,
                  onChanged: (value) => setState(() => _showDenominations = value),
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),

          // 3. 종교 타일 리스트
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleStats.length,
            itemBuilder: (context, index) {
              final stat = visibleStats[index];
              final bool isSub = stat['isSub'] ?? false;
              final list = stat['type'] == 'religion' ? countriesByReligion : countriesByDenomination;
              final countriesForStat = list[stat['name']] ?? [];

              if (countriesForStat.isEmpty) return const SizedBox.shrink();

              return _ReligionTile(
                title: stat['name'],
                countries: countriesForStat,
                visitedNames: visited,
                itemColor: _religionColors[stat['name']] ?? Theme.of(context).primaryColor,
                isSubItem: isSub,
                isExpanded: _expandedItems.contains(stat['name']),
                onToggle: _toggleExpanded,
              );
            },
          ),

          const SizedBox(height: 24),

          // 4. 종교 인구 랭킹 카드
          SizedBox(
            height: 480,
            child: _ReligionPopulationRankingCard(
              countriesToDisplay: countries,
              visitedCountryNames: visited,
            ),
          ),

          const SizedBox(height: 24),

          // 5. 가톨릭 계급 랭킹 카드
          SizedBox(
            height: 400,
            child: _CatholicHierarchyRankingCard(
              countriesToDisplay: countries,
              visitedCountryNames: visited,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ReligionTile extends StatelessWidget {
  final String title;
  final List<Country> countries;
  final Set<String> visitedNames;
  final Color itemColor;
  final bool isSubItem;
  final bool isExpanded;
  final Function(String) onToggle;

  const _ReligionTile({
    required this.title,
    required this.countries,
    required this.visitedNames,
    required this.itemColor,
    required this.isSubItem,
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

    return Padding(
      padding: EdgeInsets.fromLTRB(isSubItem ? 20.0 : 0, 0, 0, 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: isExpanded ? itemColor.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded ? itemColor.withOpacity(0.3) : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isExpanded ? itemColor.withOpacity(0.1) : Colors.black.withOpacity(0.05),
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
                              color: isSubItem ? Colors.black54 : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(percentage * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: itemColor,
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
                              backgroundColor: itemColor.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(itemColor),
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
                          return InkWell( // 탭할 때 상세 페이지로 이동
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => navigateToCountryDetail(context, country),
                            child: Row(
                              children: [
                                Icon(
                                  isVisited ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color: isVisited ? itemColor : Colors.grey,
                                ),
                                const SizedBox(width: 4),
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
      ),
    );
  }
}

// Helper Class for Rankings
class ReligionRankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final num? Function(Country) valueAccessor;
  final String unit;

  ReligionRankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.valueAccessor,
    this.unit = '',
  });
}

// 1. Religion Population Ranking Card
class _ReligionPopulationRankingCard extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _ReligionPopulationRankingCard({required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  State<_ReligionPopulationRankingCard> createState() => _ReligionPopulationRankingCardState();
}

class _ReligionPopulationRankingCardState extends State<_ReligionPopulationRankingCard> {
  late final List<ReligionRankingInfo> _rankings;
  late ReligionRankingInfo _selectedRanking;

  List<Country> _rankedList = [];

  static final Map<String, Color> _continentColors = {
    'Asia': Colors.pink.shade200, 'Europe': Colors.amber, 'Africa': Colors.brown,
    'North America': Colors.blue.shade200, 'South America': Colors.green, 'Oceania': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _rankings = [
      ReligionRankingInfo(title: 'Christian Population', icon: Icons.church, themeColor: Colors.purple, valueAccessor: (c) => c.christianPop),
      ReligionRankingInfo(title: 'Muslim Population', icon: Icons.mosque, themeColor: Colors.green, valueAccessor: (c) => c.muslimPop),
      ReligionRankingInfo(title: 'Hindu Population', icon: Icons.temple_hindu, themeColor: Colors.red, valueAccessor: (c) => c.hinduPop),
      ReligionRankingInfo(title: 'Buddhist Population', icon: Icons.self_improvement, themeColor: Colors.orange, valueAccessor: (c) => c.buddhistPop),
      ReligionRankingInfo(title: 'Jewish Population', icon: Icons.star, themeColor: Colors.blue, valueAccessor: (c) => c.jewishPop),
      ReligionRankingInfo(title: 'Sikh Population', icon: Icons.spa, themeColor: Colors.brown, valueAccessor: (c) => c.sikhPop),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _ReligionPopulationRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countriesToDisplay, oldWidget.countriesToDisplay) ||
        !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames)) {
      _prepareList();
    }
  }

  void _prepareList() {
    // Switch Removed: Always use all displayed countries
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
    return Text('$rank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final useDefaultColor = countryProvider.useDefaultRankingBarColor;
    final rankingThemeColor = _selectedRanking.themeColor;

    final double maxValue = _rankedList.isNotEmpty ? _rankedList.map((c) => _selectedRanking.valueAccessor(c)?.toDouble() ?? 0.0).reduce(math.max) : 1.0;
    final numberFormatter = NumberFormat.decimalPattern('en_US');

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
                    Icon(Icons.groups, color: rankingThemeColor),
                    const SizedBox(width: 8),
                    Text("Religious Populations", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<ReligionRankingInfo>(
                    borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
                    value: _selectedRanking, isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, color: rankingThemeColor),
                    items: _rankings.map((group) => DropdownMenuItem<ReligionRankingInfo>(
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
                  child: InkWell( // 탭할 때 상세 페이지로 이동
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
                              Text(numberFormatter.format(value), style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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

// 2. Catholic Hierarchy Ranking Card
class _CatholicHierarchyRankingCard extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _CatholicHierarchyRankingCard({required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  State<_CatholicHierarchyRankingCard> createState() => _CatholicHierarchyRankingCardState();
}

class _CatholicHierarchyRankingCardState extends State<_CatholicHierarchyRankingCard> {
  late final List<ReligionRankingInfo> _rankings;
  late ReligionRankingInfo _selectedRanking;

  List<Country> _rankedList = [];

  static final Map<String, Color> _continentColors = {
    'Asia': Colors.pink.shade200, 'Europe': Colors.amber, 'Africa': Colors.brown,
    'North America': Colors.blue.shade200, 'South America': Colors.green, 'Oceania': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _rankings = [
      ReligionRankingInfo(title: 'Historical Popes', icon: Icons.history_edu, themeColor: const Color(0xFFF1C40F), valueAccessor: (c) => c.popeCount),
      ReligionRankingInfo(title: 'Living Cardinals', icon: Icons.person, themeColor: const Color(0xFFC0392B), valueAccessor: (c) => c.cardinalCount),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _CatholicHierarchyRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countriesToDisplay, oldWidget.countriesToDisplay) ||
        !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames)) {
      _prepareList();
    }
  }

  void _prepareList() {
    // Switch Removed: Always use all displayed countries
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
    return Text('$rank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final useDefaultColor = countryProvider.useDefaultRankingBarColor;
    final rankingThemeColor = _selectedRanking.themeColor;

    final double maxValue = _rankedList.isNotEmpty ? _rankedList.map((c) => _selectedRanking.valueAccessor(c)?.toDouble() ?? 0.0).reduce(math.max) : 1.0;

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
                    Icon(Icons.volunteer_activism, color: rankingThemeColor),
                    const SizedBox(width: 8),
                    Text("Catholic Hierarchy", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<ReligionRankingInfo>(
                    borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
                    value: _selectedRanking, isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down_circle_outlined, color: rankingThemeColor),
                    items: _rankings.map((group) => DropdownMenuItem<ReligionRankingInfo>(
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
                  child: InkWell( // 탭할 때 상세 페이지로 이동
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
                              Text('$value', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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