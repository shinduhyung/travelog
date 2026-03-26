// lib/screens/geography_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart'; // 상세 화면 추가
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

// Climate Stats Screen import
import 'package:jidoapp/screens/climate_stats_screen.dart';

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

// --- 데이터 클래스 ---
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

class SpecialGroupInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final List<String> memberCodes;
  final Map<String, int>? memberData;
  final List<String> subMemberCodes;
  final String subMemberLegend;
  final List<HighlightGroup> Function(List<Country> countriesToDisplay) mapGroupsBuilder;

  const SpecialGroupInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.memberCodes,
    required this.mapGroupsBuilder,
    this.memberData,
    this.subMemberCodes = const [],
    this.subMemberLegend = '',
  });
}


// GeographyTabScreen: 기존 GeographyStatsScreen의 모든 내용을 담습니다.
class GeographyTabScreen extends StatelessWidget {
  const GeographyTabScreen({super.key});

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
    // Scaffold와 AppBar는 래퍼인 GeographyStatsScreen에서 처리합니다.
    return Consumer<CountryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final countriesToDisplay = provider.filteredCountries;
        final visitedCountryNames = provider.visitedCountries;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 1. Latitude / Elevation
              SizedBox(
                height: 520,
                child: _CombinedGeoMetricCard(
                  countriesToDisplay: countriesToDisplay,
                  visitedCountryNames: visitedCountryNames,
                ),
              ),
              const SizedBox(height: 24),

              // 2. Geographic Features
              SizedBox(
                height: 520,
                child: _CombinedRankingCard(
                  allCountries: countriesToDisplay,
                  visitedCountryNames: visitedCountryNames,
                ),
              ),
              const SizedBox(height: 24),

              // 3. Geo Blocks
              _CombinedGeoBlockCard(
                allCountries: countriesToDisplay,
                visitedCountryNames: visitedCountryNames,
              ),
              const SizedBox(height: 24),

              // 4. Special Groups
              _CombinedSpecialGroupCard(
                allCountries: countriesToDisplay,
                visitedCountryNames: visitedCountryNames,
              ),
            ],
          ),
        );
      },
    );
  }
}


// GeographyStatsScreen: Climate Stats와 통합하는 래퍼 스크린
class GeographyStatsScreen extends StatelessWidget {
  const GeographyStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const List<Tab> tabs = <Tab>[
      Tab(icon: Icon(Icons.terrain), text: 'Geography'),
      Tab(icon: Icon(Icons.thermostat), text: 'Climate'),
    ];

    const List<Widget> screens = <Widget>[
      GeographyTabScreen(),
      ClimateStatsScreen(),
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
  }
}


// --- 지리 블록 카드 ---
class _CombinedGeoBlockCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedGeoBlockCard({super.key, required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedGeoBlockCard> createState() => _CombinedGeoBlockCardState();
}

class _CombinedGeoBlockCardState extends State<_CombinedGeoBlockCard> {
  late final List<SpecialGroupInfo> _groups;
  late SpecialGroupInfo _selectedGroup;
  bool _isExpanded = false;

  // 지리/문화 블록 그룹 코드
  static const List<String> _scandinaviaCodes = ['NOR', 'SWE', 'DNK'];
  static const List<String> _beneluxCodes = ['BEL', 'NLD', 'LUX'];
  static const List<String> _balticCodes = ['EST', 'LVA', 'LTU'];
  static const List<String> _caucasusCodes = ['GEO', 'ARM', 'AZE'];

  @override
  void initState() {
    super.initState();
    _groups = [
      SpecialGroupInfo(
        title: 'Scandinavian', icon: Icons.flag, themeColor: Colors.blue, memberCodes: _scandinaviaCodes,
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'Scandinavian', color: Colors.blue, countryCodes: _scandinaviaCodes),
        ],
      ),
      SpecialGroupInfo(
        title: 'Benelux', icon: Icons.currency_exchange, themeColor: Colors.yellow.shade700, memberCodes: _beneluxCodes,
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'Benelux', color: Colors.yellow.shade700, countryCodes: _beneluxCodes),
        ],
      ),
      SpecialGroupInfo(
        title: 'Baltic', icon: Icons.waves, themeColor: Colors.teal, memberCodes: _balticCodes,
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'Baltic', color: Colors.teal, countryCodes: _balticCodes),
        ],
      ),
      SpecialGroupInfo(
        title: 'Caucasus', icon: Icons.terrain, themeColor: Colors.brown, memberCodes: _caucasusCodes,
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'Caucasus', color: Colors.brown, countryCodes: _caucasusCodes),
        ],
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

    final sortedCountries = List<Country>.from(currentCountries)..sort((a,b) => a.name.compareTo(b.name));

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
                      Text("Visited Countries", style: theme.textTheme.bodyLarge),
                      Text.rich(TextSpan(
                        text: '$visited', style: theme.textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                        children: [TextSpan(text: ' / $total', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
                      )),
                    ]),
                    ElevatedButton.icon(
                      onPressed: () {
                        final groups = _selectedGroup.mapGroupsBuilder(widget.allCountries);
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

                  return InkWell( // 상세 페이지 연결
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
                          Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)), // 국기 추가
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


// --- 지도 관련 특수 그룹 카드 ---
class _CombinedSpecialGroupCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedSpecialGroupCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedSpecialGroupCard> createState() => _CombinedSpecialGroupCardState();
}

class _CombinedSpecialGroupCardState extends State<_CombinedSpecialGroupCard> {
  late final List<SpecialGroupInfo> _groups;
  late SpecialGroupInfo _selectedGroup;
  bool _isExpanded = false;

  // Data Definitions
  static const List<String> doublyLandlockedCodes = ['UZB', 'LIE'];
  static const List<String> landlockedCodes = [
    'AFG', 'AND', 'ARM', 'AUT', 'AZE', 'BLR', 'BTN', 'BOL', 'BWA', 'BFA', 'BDI', 'CAF', 'TCD', 'CZE', 'ETH', 'HUN', 'KAZ', 'KGZ', 'LAO', 'LSO', 'LUX', 'MWI', 'MLI', 'MDA', 'MNG', 'NPL', 'NER', 'MKD', 'PRY', 'RWA', 'SMR', 'SRB', 'SVK', 'SSD', 'CHE', 'TJK', 'TKM', 'UGA', 'VAT', 'ZMB', 'ZWE'
  ];
  static const List<String> allLandlockedCodes = [...landlockedCodes, ...doublyLandlockedCodes];

  static const List<String> equatorCountryCodes = [
    'BRA', 'COL', 'ECU', 'STP', 'GAB', 'COG', 'COD', 'UGA', 'KEN', 'SOM', 'MDV', 'IDN', 'KIR'
  ];

  static const List<String> medEuropeCodes = ['ESP', 'FRA', 'MCO', 'ITA', 'MLT', 'SVN', 'HRV', 'BIH', 'MNE', 'ALB', 'GRC'];
  static const List<String> medAsiaCodes = ['TUR', 'CYP', 'SYR', 'LBN', 'ISR', 'PSE'];
  static const List<String> medAfricaCodes = ['EGY', 'LBY', 'TUN', 'DZA', 'MAR'];
  static const List<String> allMedCodes = [...medEuropeCodes, ...medAsiaCodes, ...medAfricaCodes];

  static const List<String> himalayaCodes = ['IND', 'NPL', 'BTN', 'CHN', 'PAK'];
  static const List<String> alpineCodes = ['FRA', 'MCO', 'ITA', 'CHE', 'LIE', 'AUT', 'DEU', 'SVN'];

  static const List<String> islandCodes = [
    'ABW', 'AIA', 'ALA', 'ASM', 'ATG', 'AUS', 'BHR', 'BHS', 'BLM', 'BMU', 'BRB', 'COK', 'COM', 'CPV', 'CUB', 'CUW', 'CYM', 'CYP', 'DMA', 'DOM', 'FJI', 'FLK', 'FRO', 'FSM', 'GBR', 'GRD', 'GRL', 'GUM', 'HTI', 'IDN', 'IMN', 'IRL', 'ISL', 'JAM', 'JEY', 'JPN', 'KIR', 'KNA', 'LCA', 'LKA', 'MAF', 'MDG', 'MDV', 'MHL', 'MLT', 'MUS', 'MNP', 'MSR', 'NCL', 'NFK', 'NIU', 'NRU', 'NZL', 'PCN', 'PHL', 'PLW', 'PNG', 'PRI', 'PYF', 'SGP', 'SLB', 'SPM', 'STP', 'SXM', 'SYC', 'TCA', 'TLS', 'TON', 'TTO', 'TUV', 'TWN', 'VCT', 'VGB', 'VIR', 'VUT', 'WLF', 'WSM'
  ];

  static const Map<String, int> multipleTimeZonesData = {
    'RUS': 11, 'CAN': 6, 'USA': 11, 'AUS': 9, 'BRA': 4, 'MEX': 4, 'IDN': 3, 'KIR': 3, 'FRA': 12, 'GBR': 9, 'DNK': 5, 'NZL': 5, 'NLD': 2, 'CHL': 2, 'ESP': 2, 'PRT': 2, 'ECU': 2, 'KAZ': 2, 'MNG': 2, 'PNG': 2, 'FSM': 2
  };

  @override
  void initState() {
    super.initState();
    _groups = [
      SpecialGroupInfo(
        title: 'Landlocked',
        icon: Icons.landscape,
        themeColor: Colors.red,
        memberCodes: allLandlockedCodes,
        subMemberCodes: doublyLandlockedCodes,
        subMemberLegend: '(*) Doubly Landlocked',
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'Landlocked', color: Colors.red, countryCodes: landlockedCodes),
          HighlightGroup(name: 'Doubly Landlocked (*)', color: Colors.purple, countryCodes: doublyLandlockedCodes),
        ],
      ),
      SpecialGroupInfo(
        title: 'On the Equator',
        icon: Icons.public,
        themeColor: Colors.brown,
        memberCodes: equatorCountryCodes,
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'On the Equator', color: Colors.brown, countryCodes: equatorCountryCodes),
        ],
      ),
      SpecialGroupInfo(
        title: 'Mediterranean Sea',
        icon: Icons.wb_sunny,
        themeColor: Colors.orange,
        memberCodes: allMedCodes,
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'Europe Coast', color: Colors.indigo, countryCodes: medEuropeCodes),
          HighlightGroup(name: 'Asia Coast', color: Colors.orange, countryCodes: medAsiaCodes),
          HighlightGroup(name: 'Africa Coast', color: Colors.brown, countryCodes: medAfricaCodes),
        ],
      ),
      SpecialGroupInfo(
        title: 'The Alps',
        icon: Icons.snowboarding,
        themeColor: Colors.teal,
        memberCodes: alpineCodes,
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'Alpine Region', color: Colors.teal, countryCodes: alpineCodes),
        ],
      ),
      SpecialGroupInfo(
        title: 'The Himalayas',
        icon: Icons.terrain,
        themeColor: Colors.grey.shade700,
        memberCodes: himalayaCodes,
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'Himalayan Region', color: Colors.grey.shade700, countryCodes: himalayaCodes),
        ],
      ),
      SpecialGroupInfo(
        title: 'Island Countries',
        icon: Icons.beach_access,
        themeColor: Colors.cyan,
        memberCodes: islandCodes,
        mapGroupsBuilder: (countries) => [
          HighlightGroup(name: 'Island Nations', color: Colors.cyan, countryCodes: islandCodes),
        ],
      ),
      SpecialGroupInfo(
        title: 'Multiple Timezones',
        icon: Icons.hourglass_empty,
        themeColor: Colors.grey.shade900,
        memberCodes: multipleTimeZonesData.keys.toList(),
        memberData: multipleTimeZonesData,
        mapGroupsBuilder: (countries) {
          final groups = <HighlightGroup>[];
          multipleTimeZonesData.forEach((iso, count) {
            final color = count >= 10 ? Colors.black : count >= 6 ? Colors.purple : count >= 3 ? Colors.red : Colors.pink;
            final name = count >= 10 ? '10+ Time Zones' : count >= 6 ? '6-9 Time Zones' : count >= 3 ? '3-5 Time Zones' : '2 Time Zones';
            final existingGroup = groups.firstWhere((g) => g.name == name, orElse: () {
              final newGroup = HighlightGroup(name: name, color: color, countryCodes: []);
              groups.add(newGroup);
              return newGroup;
            });
            existingGroup.countryCodes.add(iso);
          });
          return groups;
        },
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

    final sortedCountries = List<Country>.from(currentCountries);
    if (_selectedGroup.title == 'Multiple Timezones') {
      sortedCountries.sort((a,b) => (_selectedGroup.memberData![b.isoA3] ?? 0).compareTo(_selectedGroup.memberData![a.isoA3] ?? 0));
    } else {
      sortedCountries.sort((a,b) => a.name.compareTo(b.name));
    }

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
                        text: '$visited', style: textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                        children: [TextSpan(text: ' / $total', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600))],
                      )),
                    ]),
                    ElevatedButton.icon(
                      onPressed: () {
                        final groups = _selectedGroup.mapGroupsBuilder(widget.allCountries);
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
                  final isSubMember = _selectedGroup.subMemberCodes.contains(country.isoA3);
                  final memberData = _selectedGroup.memberData?[country.isoA3];

                  return InkWell( // 상세 페이지 연결
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
                          Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 14)), // 국기 추가
                          const SizedBox(width: 6),
                          Expanded(
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: RichText(
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    style: theme.textTheme.bodyMedium,
                                    children: [
                                      if(isSubMember) const TextSpan(text: '(*) ', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                                      TextSpan(text: country.name),
                                      if(memberData != null) TextSpan(text: ' ($memberData)', style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                  ),
                                )
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

// --- 🔄 위도/고도 평균 및 랭킹 통합 카드 ---
class _CombinedGeoMetricCard extends StatefulWidget {
  final List<Country> countriesToDisplay;
  final Set<String> visitedCountryNames;

  const _CombinedGeoMetricCard({required this.countriesToDisplay, required this.visitedCountryNames});

  @override
  State<_CombinedGeoMetricCard> createState() => _CombinedGeoMetricCardState();
}

class _CombinedGeoMetricCardState extends State<_CombinedGeoMetricCard> {
  // --- State Variables ---
  String _selectedMetricType = 'Latitude'; // 'Latitude' or 'Elevation'

  // Latitude states
  int _latitudeSortOrder = 0; // 0: High, 1: Low
  int _latitudeMetric = 0;    // 0: Average, 1: Farthest Pt., 2: Capital

  // Elevation states
  int _elevationSortOrder = 0; // 0: High, 1: Low
  int _elevationMetric = 1;    // 0: Highest, 1: Average

  List<Country> _rankedList = [];
  final Map<String, Color> continentColors = { for (var data in GeographyTabScreen.continentsData) data['fullName'] as String: data['color'] as Color };

  @override
  void initState() {
    super.initState();
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _CombinedGeoMetricCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.countriesToDisplay, oldWidget.countriesToDisplay) ||
        !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames)) {
      _prepareList();
    }
  }

  void _prepareList() {
    List<Country> listToRank = List.from(widget.countriesToDisplay);

    if (_selectedMetricType == 'Latitude') {
      // 정렬 로직 (High: 내림차순, Low: 오름차순)
      if (_latitudeSortOrder == 0) { // High (North)
        if (_latitudeMetric == 0) { // Average
          listToRank.sort((a, b) => b.centroidLat.compareTo(a.centroidLat));
        } else if (_latitudeMetric == 1) { // Farthest
          listToRank.sort((a, b) => b.northLat.compareTo(a.northLat));
        } else { // Capital
          listToRank.sort((a, b) => b.capitalLat.compareTo(a.capitalLat));
        }
      } else { // Low (South)
        if (_latitudeMetric == 0) { // Average
          listToRank.sort((a, b) => a.centroidLat.compareTo(b.centroidLat));
        } else if (_latitudeMetric == 1) { // Farthest
          listToRank.sort((a, b) => a.southLat.compareTo(b.southLat));
        } else { // Capital
          listToRank.sort((a, b) => a.capitalLat.compareTo(b.capitalLat));
        }
      }
    } else { // Elevation
      if (_elevationMetric == 1) { // Average
        listToRank.sort((a, b) => b.elevationAverage.compareTo(a.elevationAverage));
      } else { // Highest
        listToRank.sort((a, b) => b.elevationHighest.compareTo(a.elevationHighest));
      }
      if (_elevationSortOrder == 1) { // Low
        listToRank = listToRank.reversed.toList();
      }
    }
    setState(() {
      _rankedList = listToRank;
    });
  }

  // 모든 순위를 일반 텍스트로 표시하는 헬퍼 함수
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isLatitude = _selectedMetricType == 'Latitude';
    final themeColor = isLatitude ? Colors.blue : Colors.brown;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Main Metric Type Dropdown ---
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
                value: _selectedMetricType,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: themeColor),
                items: [
                  DropdownMenuItem(
                    value: 'Latitude',
                    child: Row(children: [
                      Icon(Icons.public, color: Colors.blue),
                      const SizedBox(width: 12),
                      Text('Latitude', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  DropdownMenuItem(
                    value: 'Elevation',
                    child: Row(children: [
                      Icon(Icons.terrain, color: Colors.brown),
                      const SizedBox(width: 12),
                      Text('Elevation', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMetricType = value;
                      _prepareList();
                    });
                  }
                },
              ),
            ),
          ),

          // --- Ranking Control Dropdowns ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: isLatitude ? _latitudeSortOrder : _elevationSortOrder,
                    decoration: InputDecoration(
                        labelText: 'Order',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), // 둥근 모서리
                        isDense: true
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text('High'),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text('Low'),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      if (isLatitude) _latitudeSortOrder = v!; else _elevationSortOrder = v!;
                      _prepareList();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isLatitude
                      ? DropdownButtonFormField<int>(
                    value: _latitudeMetric,
                    decoration: InputDecoration(
                        labelText: 'Metric',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), // 둥근 모서리
                        isDense: true
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Average')),
                      DropdownMenuItem(value: 1, child: Text('Farthest Pt.')),
                      DropdownMenuItem(value: 2, child: Text('Capital')),
                    ],
                    onChanged: (v) => setState(() { _latitudeMetric = v!; _prepareList(); }),
                  )
                      : DropdownButtonFormField<int>(
                    value: _elevationMetric,
                    decoration: InputDecoration(
                        labelText: 'Metric',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), // 둥근 모서리
                        isDense: true
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Average')),
                      DropdownMenuItem(value: 0, child: Text('Highest')),
                    ],
                    onChanged: (v) => setState(() { _elevationMetric = v!; _prepareList(); }),
                  ),
                ),
              ],
            ),
          ),

          // --- Average Display Section ---
          _buildAverageDisplay(),

          const Divider(indent: 20, endIndent: 20, height: 24),

          // --- Ranking List (Expanded to fit) ---
          Expanded(child: _buildRankingList(context, themeColor)),
        ],
      ),
    );
  }

  Widget _buildAverageDisplay() {
    final visitedCountries = widget.countriesToDisplay.where((c) => widget.visitedCountryNames.contains(c.name)).toList();
    final allCountries = widget.countriesToDisplay;

    final latitudeFormatter = NumberFormat("0.00", 'en_US');
    final elevationFormatter = NumberFormat("###,###,##0", 'en_US');

    String suffix;
    double visitedAvg;
    double worldAvg;
    Color color;
    NumberFormat selectedFormatter;

    if (_selectedMetricType == 'Latitude') {
      color = Colors.blue;
      suffix = '°';
      selectedFormatter = latitudeFormatter;
      if (_latitudeMetric == 0) { // Average
        visitedAvg = visitedCountries.isNotEmpty ? visitedCountries.fold<double>(0, (p, c) => p + c.centroidLat) / visitedCountries.length : 0;
        worldAvg = allCountries.isNotEmpty ? allCountries.fold<double>(0, (p, c) => p + c.centroidLat) / allCountries.length : 0;
      } else if (_latitudeMetric == 1) { // Farthest
        visitedAvg = visitedCountries.isNotEmpty ? visitedCountries.fold<double>(0, (p, c) => p + (_latitudeSortOrder == 0 ? c.northLat : c.southLat)) / visitedCountries.length : 0;
        worldAvg = allCountries.isNotEmpty ? allCountries.fold<double>(0, (p, c) => p + (_latitudeSortOrder == 0 ? c.northLat : c.southLat)) / allCountries.length : 0;
      } else { // Capital
        visitedAvg = visitedCountries.isNotEmpty ? visitedCountries.fold<double>(0, (p, c) => p + c.capitalLat) / visitedCountries.length : 0;
        worldAvg = allCountries.isNotEmpty ? allCountries.fold<double>(0, (p, c) => p + c.capitalLat) / allCountries.length : 0;
      }
    } else { // Elevation
      color = Colors.brown;
      suffix = ' m';
      selectedFormatter = elevationFormatter;
      if (_elevationMetric == 1) { // Average
        visitedAvg = visitedCountries.isNotEmpty ? visitedCountries.fold<double>(0, (p, c) => p + c.elevationAverage) / visitedCountries.length : 0;
        worldAvg = allCountries.isNotEmpty ? allCountries.fold<double>(0, (p, c) => p + c.elevationAverage) / allCountries.length : 0;
      } else { // Highest
        visitedAvg = visitedCountries.isNotEmpty ? visitedCountries.fold<double>(0, (p, c) => p + c.elevationHighest) / visitedCountries.length : 0;
        worldAvg = allCountries.isNotEmpty ? allCountries.fold<double>(0, (p, c) => p + c.elevationHighest) / allCountries.length : 0;
      }
    }

    final maxValue = math.max(visitedAvg.abs(), worldAvg.abs());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildHorizontalBar(context: context, label: 'Visited', value: visitedAvg, maxValue: maxValue, color: color, formatter: selectedFormatter, suffix: suffix),
          const SizedBox(height: 16),
          _buildHorizontalBar(context: context, label: 'World', value: worldAvg, maxValue: maxValue, color: Colors.grey.shade400, formatter: selectedFormatter, suffix: suffix),
        ],
      ),
    );
  }

  Widget _buildRankingList(BuildContext context, Color themeColor) {
    if (_rankedList.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final elevationFormatter = NumberFormat("###,###,##0", 'en_US');

    double getTopValue() {
      if (_rankedList.isEmpty) return 1.0;
      double topVal;
      if (_selectedMetricType == 'Latitude') {
        double value;
        if (_latitudeMetric == 0) value = _rankedList.first.centroidLat;
        else if (_latitudeMetric == 1) value = _latitudeSortOrder == 0 ? _rankedList.first.northLat : _rankedList.first.southLat;
        else value = _rankedList.first.capitalLat;
        topVal = value;
      } else {
        topVal = (_elevationMetric == 1 ? _rankedList.first.elevationAverage : _rankedList.first.elevationHighest).toDouble();
      }
      return topVal.abs();
    }
    final topValue = getTopValue();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: _rankedList.length,
      itemBuilder: (context, index) {
        final item = _rankedList[index];
        final isVisited = widget.visitedCountryNames.contains(item.name);
        final rank = index + 1;
        final barColor = continentColors[item.continent] ?? themeColor;

        num rawValue;
        String displayValue;

        if (_selectedMetricType == 'Latitude') {
          double value;
          if (_latitudeMetric == 0) value = item.centroidLat;
          else if (_latitudeMetric == 1) value = _latitudeSortOrder == 0 ? item.northLat : item.southLat;
          else value = item.capitalLat;
          rawValue = value;
          displayValue = '${value.toStringAsFixed(2)}°';
        } else {
          int value = _elevationMetric == 1 ? item.elevationAverage : item.elevationHighest;
          rawValue = value;
          displayValue = '${elevationFormatter.format(value)} m';
        }

        return Card(
          elevation: 0,
          color: isVisited ? themeColor.withOpacity(0.12) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell( // 상세 페이지 연결
            borderRadius: BorderRadius.circular(12),
            onTap: () => navigateToCountryDetail(context, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildRankText(rank, themeColor),
                      const SizedBox(width: 12),
                      Text(flagEmoji(item.isoA2), style: const TextStyle(fontSize: 18)), // 국기 추가
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 17))),
                      const SizedBox(width: 12),
                      Text(displayValue, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: rawValue.abs().toDouble() / (topValue == 0 ? 1 : topValue.toDouble()),
                    borderRadius: BorderRadius.circular(5),
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade300,
                    color: barColor,
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

// --- Geographic Features 카드 ---
class _CombinedRankingCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedRankingCard({required this.allCountries, required this.visitedCountryNames});

  @override
  State<_CombinedRankingCard> createState() => _CombinedRankingCardState();
}

class _CombinedRankingCardState extends State<_CombinedRankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selectedRanking;

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
      RankingInfo(title: 'Island Count', icon: Icons.beach_access, themeColor: Colors.blue, valueAccessor: (c) => c.islandCount),
      RankingInfo(title: 'Coastline Length', icon: Icons.waves, themeColor: Colors.green, valueAccessor: (c) => c.coastlineLength, unit: ' km'),
      RankingInfo(title: 'Lake Count', icon: Icons.water, themeColor: Colors.lightBlue, valueAccessor: (c) => c.lakeCount, unit: ' '),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _CombinedRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.allCountries, oldWidget.allCountries) || !setEquals(widget.visitedCountryNames, oldWidget.visitedCountryNames)) {
      _prepareList();
    }
  }

  void _prepareList() {
    List<Country> listToRank = List.from(widget.allCountries);

    listToRank = listToRank.where((c) {
      final value = _selectedRanking.valueAccessor(c);
      return value != null && (value as num) > 0;
    }).toList();

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
    final double maxValue = _rankedList.isNotEmpty ? (_selectedRanking.valueAccessor(_rankedList.first) ?? 0).toDouble() : 1.0;

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
                    Icon(Icons.search, color: rankingThemeColor),
                    const SizedBox(width: 8),
                    Text('Geographic Features', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                        Icon(group.icon, color: group.themeColor),
                        const SizedBox(width: 12),
                        Text(group.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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

                final formattedValue = '${numberFormatter.format(double.parse(value.toStringAsFixed(_selectedRanking.precision)))} ${_selectedRanking.unit}';

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