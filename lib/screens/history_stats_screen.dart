// lib/screens/history_stats_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // for list.firstWhereOrNull

// [모든 제국 지도 화면 import]
import 'package:jidoapp/screens/mongol_empire_map_screen.dart';
import 'package:jidoapp/screens/ottoman_empire_map_screen.dart';
import 'package:jidoapp/screens/british_empire_map_screen.dart';
import 'package:jidoapp/screens/roman_empire_map_screen.dart';
import 'package:jidoapp/screens/french_empire_map_screen.dart';
import 'package:jidoapp/screens/alexander_empire_map_screen.dart';

import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/screens/country_detail_screen.dart'; // 상세 화면 임포트 추가

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

// 🆕 GroupInfo 정의 (geopolitics_stats_screen.dart에서 가져옴)
class GroupInfo {
  final String title;
  final IconData icon;
  final List<String> memberCodes;
  final Color themeColor;
  final String mapLegend;
  final List<String>? subMemberCodes;
  final Color? subThemeColor;
  final String? subMapLegend;
  final String? note;

  GroupInfo({
    required this.title,
    required this.icon,
    required this.memberCodes,
    required this.themeColor,
    required this.mapLegend,
    this.subMemberCodes,
    this.subThemeColor,
    this.subMapLegend,
    this.note,
  });
}

class HistoryStatsScreen extends StatefulWidget {
  const HistoryStatsScreen({super.key});

  @override
  State<HistoryStatsScreen> createState() => _HistoryStatsScreenState();
}

class _HistoryStatsScreenState extends State<HistoryStatsScreen> {
  // 각 제국 타일 확장 여부 상태 변수
  bool _isMongolExpanded = false;
  bool _isOttomanExpanded = false;
  // bool _isBritishExpanded = false; // 주석 처리
  bool _isRomanExpanded = false;
  // bool _isFrenchExpanded = false;  // 주석 처리
  bool _isAlexanderExpanded = false;

  // 1. 몽골 제국 데이터
  static const Map<String, double> _mongolEmpireAreas = {
    'China': 9600000, 'Russia': 4500000, 'Kazakhstan': 2724900, 'Iran': 1648195,
    'Mongolia': 1564110, 'Afghanistan': 652864, 'Ukraine': 603500, 'Turkmenistan': 488100,
    'Uzbekistan': 447400, 'Iraq': 438317, 'Turkey': 400000, 'Pakistan': 300000,
    'Kyrgyzstan': 199951, 'Tajikistan': 143100, 'North Korea': 120540, 'South Korea': 100210,
    'Romania': 100000, 'Azerbaijan': 86600, 'Georgia': 69700, 'Moldova': 33851, 'Armenia': 29743,
  };

  // 2. 오스만 제국 데이터
  static const Map<String, double> _ottomanEmpireAreas = {
    'Turkey': 783562, 'Egypt': 1010408, 'Saudi Arabia': 2149690, 'Iraq': 438317,
    'Syria': 185180, 'Greece': 131957, 'Bulgaria': 110994, 'Romania': 238391,
    'Algeria': 2381741, 'Tunisia': 163610, 'Libya': 1759540, 'Serbia': 88361,
    'Jordan': 89342, 'Israel': 22072, 'Lebanon': 10452, 'Palestine': 6020,
    'Hungary': 93030, 'Croatia': 56594, 'Bosnia and Herzegovina': 51197,
    'Albania': 28748, 'North Macedonia': 25713, 'Montenegro': 13812,
    'Kosovo': 10908, 'Cyprus': 9251,
  };

  // 3. 로마 제국 데이터
  static const Map<String, double> _romanEmpireAreas = {
    'Italy': 301340, 'France': 551695, 'Spain': 505992, 'Turkey': 783562,
    'Egypt': 1010408, 'United Kingdom': 242495, 'Greece': 131957, 'Syria': 185180,
    'Tunisia': 163610, 'Algeria': 2381741, 'Morocco': 446550, 'Romania': 238391,
    'Bulgaria': 110994, 'Portugal': 92090, 'Israel': 22072, 'Jordan': 89342,
    'Lebanon': 10452, 'Cyprus': 9251, 'Switzerland': 41284, 'Austria': 83871,
    'Hungary': 93030, 'Croatia': 56594, 'Slovenia': 20273, 'Serbia': 88361,
    'Albania': 28748, 'Libya': 1759540, 'Belgium': 30528, 'Netherlands': 41543,
  };

  // 4. 알렉산더 제국 데이터
  static const Map<String, double> _alexanderEmpireAreas = {
    'Iran': 1648195, 'Egypt': 1010408, 'Turkey': 783562, 'Afghanistan': 652864,
    'Pakistan': 881913, 'Iraq': 438317, 'Turkmenistan': 488100, 'Uzbekistan': 447400,
    'Syria': 185180, 'Greece': 131957, 'Jordan': 89342, 'Tajikistan': 143100,
    'Bulgaria': 110994, 'North Macedonia': 25713, 'Israel': 22072, 'Lebanon': 10452,
    'Cyprus': 9251, 'Kuwait': 17818, 'Kyrgyzstan': 199951,
  };

  void _toggleExpanded(String empireName) {
    setState(() {
      if (empireName == 'Mongol Empire') {
        _isMongolExpanded = !_isMongolExpanded;
      } else if (empireName == 'Ottoman Empire') {
        _isOttomanExpanded = !_isOttomanExpanded;
      } else if (empireName == 'British Empire') {
        // _isBritishExpanded = !_isBritishExpanded;
      } else if (empireName == 'Roman Empire') {
        _isRomanExpanded = !_isRomanExpanded;
      } else if (empireName == 'French Empire') {
        // _isFrenchExpanded = !_isFrenchExpanded;
      } else if (empireName == 'Empire of Alexander') {
        _isAlexanderExpanded = !_isAlexanderExpanded;
      }
    });
  }

  Map<String, dynamic> _calculateStats(Map<String, double> areas, Set<String> visitedSet) {
    double totalArea = 0;
    double visitedArea = 0;
    int visitedCount = 0;

    areas.forEach((country, area) {
      totalArea += area;
      if (visitedSet.contains(country)) {
        visitedArea += area;
        visitedCount++;
      }
    });

    final percentage = totalArea > 0 ? visitedArea / totalArea : 0.0;
    final totalCount = areas.length;
    final sortedCountries = areas.keys.toList()
      ..sort((a, b) => areas[b]!.compareTo(areas[a]!));

    return {
      'visitedCount': visitedCount, 'totalCount': totalCount,
      'percentage': percentage, 'sortedCountries': sortedCountries, 'totalArea': totalArea,
    };
  }

  @override
  Widget build(BuildContext context) {
    final countryProvider = Provider.of<CountryProvider>(context);
    final visitedSet = countryProvider.visitedCountries;
    final allCountries = countryProvider.allCountries;

    // 통계 계산
    final mongolStats = _calculateStats(_mongolEmpireAreas, visitedSet);
    final ottomanStats = _calculateStats(_ottomanEmpireAreas, visitedSet);
    // final britishStats = _calculateStats(_britishEmpireAreas, visitedSet);
    final romanStats = _calculateStats(_romanEmpireAreas, visitedSet);
    // final frenchStats = _calculateStats(_frenchEmpireAreas, visitedSet);
    final alexanderStats = _calculateStats(_alexanderEmpireAreas, visitedSet);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 알렉산더 제국 (Empire of Alexander) - 가장 오래됨
          _buildEmpireGroup(
            context,
            title: "Empire of Alexander", // 연도 제거
            color: Colors.amber.shade900,
            mapScreen: const AlexanderEmpireMapScreen(),
            empireAreas: _alexanderEmpireAreas,
            stats: alexanderStats,
            isExpanded: _isAlexanderExpanded,
            visitedSet: visitedSet,
            allCountries: allCountries,
          ),

          const SizedBox(height: 24),

          // 2. 로마 제국 (Roman Empire)
          _buildEmpireGroup(
            context,
            title: "Roman Empire", // 연도 제거
            color: Colors.purple.shade700,
            mapScreen: const RomanEmpireMapScreen(),
            empireAreas: _romanEmpireAreas,
            stats: romanStats,
            isExpanded: _isRomanExpanded,
            visitedSet: visitedSet,
            allCountries: allCountries,
          ),

          const SizedBox(height: 24),

          // 3. 몽골 제국 (Mongol Empire)
          _buildEmpireGroup(
            context,
            title: "Mongol Empire",
            color: Colors.blue.shade800,
            mapScreen: const MongolEmpireMapScreen(),
            empireAreas: _mongolEmpireAreas,
            stats: mongolStats,
            isExpanded: _isMongolExpanded,
            visitedSet: visitedSet,
            allCountries: allCountries,
          ),

          const SizedBox(height: 24),

          // 4. 오스만 제국 (Ottoman Empire)
          _buildEmpireGroup(
            context,
            title: "Ottoman Empire",
            color: Colors.red.shade800,
            mapScreen: const OttomanEmpireMapScreen(),
            empireAreas: _ottomanEmpireAreas,
            stats: ottomanStats,
            isExpanded: _isOttomanExpanded,
            visitedSet: visitedSet,
            allCountries: allCountries,
          ),

          // 🆕 역사/정치 연합 그룹 카드 추가
          const SizedBox(height: 24),
          _CombinedHistoricalUnionCard(
            allCountries: countryProvider.filteredCountries,
            visitedCountryNames: visitedSet,
          ),
        ],
      ),
    );
  }

  // [통합 위젯] 지도 버튼 + 통계 타일을 묶어서 보여주는 위젯
  Widget _buildEmpireGroup(
      BuildContext context, {
        required String title,
        required Color color,
        required Widget mapScreen,
        required Map<String, double> empireAreas,
        required Map<String, dynamic> stats,
        required bool isExpanded,
        required Set<String> visitedSet,
        required List<Country> allCountries, // 국가 상세 화면을 위해 추가
      }) {
    return Column(
      children: [
        // 지도 보기 버튼 (새로운 스타일)
        _buildStylishMapButton(context, title, color, mapScreen),

        const SizedBox(height: 8), // 버튼과 타일 사이 간격

        // 통계 타일
        _buildEmpireTile(
          context,
          title: title,
          empireAreas: empireAreas,
          visitedCount: stats['visitedCount'],
          totalCount: stats['totalCount'],
          percentage: stats['percentage'],
          countries: stats['sortedCountries'],
          visitedSet: visitedSet,
          color: color,
          totalEmpireArea: stats['totalArea'],
          isExpanded: isExpanded,
          onToggle: () => _toggleExpanded(title),
          allCountries: allCountries,
        ),
      ],
    );
  }

  // [디자인 수정] 더 세련된 지도 버튼 (배너 스타일)
  Widget _buildStylishMapButton(BuildContext context, String title, Color color, Widget mapScreen) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.85), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => mapScreen)),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.public, color: Colors.white.withOpacity(0.9), size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'View $title Map',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // [기존 유지] 통계 타일
  Widget _buildEmpireTile(
      BuildContext context, {
        required String title, required Map<String, double> empireAreas,
        required int visitedCount, required int totalCount, required double percentage,
        required List<String> countries, required Set<String> visitedSet,
        required Color color, required double totalEmpireArea,
        required bool isExpanded, required VoidCallback onToggle,
        required List<Country> allCountries, // 추가됨
      }) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat.decimalPattern('en_US');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isExpanded ? color.withOpacity(0.5) : Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)
          )
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("Territory Stats", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade700))),
                      Text('${(percentage * 100).toStringAsFixed(1)}%', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: percentage, minHeight: 8, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation<Color>(color)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${numberFormat.format(visitedCount)} / ${numberFormat.format(totalCount)} countries visited', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                      Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey.shade400),
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
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final countryName = countries[index];
                        final isVisited = visitedSet.contains(countryName);
                        final area = empireAreas[countryName]!;
                        final share = (area / totalEmpireArea) * 100;
                        final countryObj = allCountries.firstWhereOrNull((c) => c.name == countryName); // 찾기

                        return InkWell( // 클릭 시 상세 화면 이동
                          borderRadius: BorderRadius.circular(8),
                          onTap: countryObj != null ? () => navigateToCountryDetail(context, countryObj) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(isVisited ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: isVisited ? color : Colors.grey.shade300),
                                const SizedBox(width: 8),
                                if (countryObj != null) ...[
                                  Text(flagEmoji(countryObj.isoA2), style: const TextStyle(fontSize: 16)), // 국기 추가
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(countryName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: isVisited ? Colors.black87 : Colors.grey.shade500)),
                                      Text('${numberFormat.format(area.round())} km²', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400)),
                                    ],
                                  ),
                                ),
                                Text('${share.toStringAsFixed(1)}%', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🆕 역사/정치 연합 그룹 카드
class _CombinedHistoricalUnionCard extends StatefulWidget {
  final List<Country> allCountries;
  final Set<String> visitedCountryNames;

  const _CombinedHistoricalUnionCard({
    required this.allCountries,
    required this.visitedCountryNames,
  });

  @override
  State<_CombinedHistoricalUnionCard> createState() => _CombinedHistoricalUnionCardState();
}

class _CombinedHistoricalUnionCardState extends State<_CombinedHistoricalUnionCard> {
  late final List<GroupInfo> _groups;
  late GroupInfo _selectedGroup;
  bool _isExpanded = false;

  // 🚨 역사적 그룹 코드
  static const List<String> _ussrCodes = ['RUS', 'UKR', 'BLR', 'MDA', 'LVA', 'LTU', 'EST', 'GEO', 'AZE', 'ARM', 'KAZ', 'UZB', 'TKM', 'KGZ', 'TJK'];
  static const List<String> _yugoslaviaCodes = ['SVN', 'HRV', 'BIH', 'SRB', 'MNE', 'MKD', 'KOS'];
  static const List<String> _commonwealthOriginalCodes = ['GUY', 'GRD', 'DMA', 'BRB', 'BHS', 'BLZ', 'LCA', 'VCT', 'KNA', 'ATG', 'JAM', 'CAN', 'TTO', 'MYS', 'MDV', 'BGD', 'BRN', 'LKA', 'SGP', 'IND', 'PAK', 'GHA', 'GMB', 'NGA', 'ZAF', 'LSO', 'RWA', 'MWI', 'MUS', 'BWA', 'SYC', 'SLE', 'SWZ', 'UGA', 'ZMB', 'CMR', 'KEN', 'TZA', 'NRU', 'NZL', 'VUT', 'WSM', 'SLB', 'KIR', 'TON', 'TUV', 'PNG', 'FJI', 'AUS', 'MLT', 'CYP'];
  static const List<String> _commonwealthLaterCodes = ['RWA', 'NAM', 'GAB', 'TGO', 'MOZ'];
  static const List<String> _allCommonwealthCodes = [..._commonwealthOriginalCodes, ..._commonwealthLaterCodes];

  @override
  void initState() {
    super.initState();
    _groups = [
      GroupInfo(
        title: 'Former USSR',
        icon: Icons.star_half,
        memberCodes: _ussrCodes,
        themeColor: Colors.red.shade700,
        mapLegend: 'Former Soviet Republics',
      ),
      GroupInfo(
        title: 'Former Yugoslavia',
        icon: Icons.flag_circle,
        memberCodes: _yugoslaviaCodes,
        themeColor: Colors.blueGrey.shade700,
        mapLegend: 'Former Yugoslav States',
      ),
      // 🆕 영연방 그룹 (원조 vs 추후 가입으로 분할)
      GroupInfo(
        title: 'British Commonwealth',
        icon: Icons.people,
        memberCodes: _allCommonwealthCodes,
        themeColor: Colors.green.shade600,
        mapLegend: 'Original Member',
        subMemberCodes: _commonwealthLaterCodes,
        subThemeColor: Colors.orange.shade600,
        subMapLegend: 'Later/Non-Traditional Member (*)',
        note: '(*) Later/Non-Traditional Member',
      ),
    ];
    _selectedGroup = _groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final currentCountries = widget.allCountries.where((country) =>
        _selectedGroup.memberCodes.contains(country.isoA3)
    ).toList();

    final total = currentCountries.length;
    final visited = currentCountries.where((country) =>
        widget.visitedCountryNames.contains(country.name)
    ).length;
    final percentage = total > 0 ? (visited / total) : 0.0;

    final sortedCountries = List<Country>.from(currentCountries)
      ..sort((a, b) => a.name.compareTo(b.name));

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
              child: DropdownButton<GroupInfo>(
                borderRadius: BorderRadius.circular(16), // 둥근 모서리 적용
                value: _selectedGroup,
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down_circle_outlined, color: _selectedGroup.themeColor),
                items: _groups.map((group) {
                  return DropdownMenuItem<GroupInfo>(
                    value: group,
                    child: Row(
                      children: [
                        Icon(group.icon, color: group.themeColor),
                        const SizedBox(width: 12),
                        Text(group.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (GroupInfo? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedGroup = newValue;
                      _isExpanded = false;
                    });
                  }
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
                            Text("Visited", style: theme.textTheme.bodyLarge),
                            Text.rich(
                                TextSpan(
                                    text: '$visited',
                                    style: theme.textTheme.headlineSmall?.copyWith(color: _selectedGroup.themeColor, fontWeight: FontWeight.bold),
                                    children: [
                                      TextSpan(
                                          text: ' / $total',
                                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)
                                      ),
                                    ]
                                )
                            )
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            final Set<String> currentFilteredIsoA3s = widget.allCountries.map((c) => c.isoA3).toSet();
                            final List<HighlightGroup> groups = [];
                            final mainMembers = _selectedGroup.memberCodes.where((c) => currentFilteredIsoA3s.contains(c)).toList();
                            final subMembers = _selectedGroup.subMemberCodes?.where((c) => currentFilteredIsoA3s.contains(c)).toList() ?? [];

                            // 메인 그룹 (서브 그룹 제외)
                            groups.add(HighlightGroup(
                                name: _selectedGroup.mapLegend,
                                color: _selectedGroup.themeColor,
                                countryCodes: mainMembers.where((c) => !subMembers.contains(c)).toList()));

                            // 서브 그룹 (추후 가입)
                            if (subMembers.isNotEmpty) {
                              groups.add(HighlightGroup(
                                  name: _selectedGroup.subMapLegend!,
                                  color: _selectedGroup.subThemeColor!,
                                  countryCodes: subMembers));
                            }

                            Navigator.push(context, MaterialPageRoute(builder: (context) => CountriesMapScreen(highlightGroups: groups)));
                          },
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Map'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedGroup.themeColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: _selectedGroup.themeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(_selectedGroup.themeColor),
                        ),
                      ),
                    ),
                  ],
                )
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Column(
              children: [
                const Divider(height: 1, indent: 20, endIndent: 20),
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
                      final isVisited = widget.visitedCountryNames.contains(country.name);
                      final isSubMember = _selectedGroup.subMemberCodes?.contains(country.isoA3) ?? false;

                      return InkWell( // 클릭 시 상세 화면 이동
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => navigateToCountryDetail(context, country),
                        child: Row(
                          children: [
                            Icon(
                              isVisited ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 20,
                              color: isVisited ? _selectedGroup.themeColor : Colors.grey.shade400,
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
                            if (isSubMember)
                              Icon(Icons.star, size: 16, color: _selectedGroup.subThemeColor),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_selectedGroup.note != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    child: Text(_selectedGroup.note!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}