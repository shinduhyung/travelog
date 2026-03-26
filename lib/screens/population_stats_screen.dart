// lib/screens/population_stats_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/country_detail_screen.dart'; // 상세 화면 임포트 추가
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'dart:math' as math;

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

  RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.valueAccessor,
    this.unit = '',
  });
}

class PopulationStatsScreen extends StatelessWidget {
  const PopulationStatsScreen({super.key});

  static final List<Map<String, Object>> continentsData = [
    {'name': 'Asia', 'fullName': 'Asia', 'asset': 'assets/icons/asia.png', 'color': Colors.pink.shade300},
    {'name': 'Europe', 'fullName': 'Europe', 'asset': 'assets/icons/europe.png', 'color': Colors.amber.shade700},
    {'name': 'Africa', 'fullName': 'Africa', 'asset': 'assets/icons/africa.png', 'color': Colors.brown.shade400},
    {'name': 'N. America', 'fullName': 'North America', 'asset': 'assets/icons/n_america.png', 'color': Colors.blue.shade400},
    {'name': 'S. America', 'fullName': 'South America', 'asset': 'assets/icons/s_america.png', 'color': Colors.green.shade500},
    {'name': 'Oceania', 'fullName': 'Oceania', 'asset': 'assets/icons/oceania.png', 'color': Colors.purple.shade400},
  ];

  @override
  Widget build(BuildContext context) {
    final numberFormatter = NumberFormat.decimalPattern('en_US');
    final compactFormatter = NumberFormat.compact();

    return Scaffold(
      // AppBar 제거 (통합 화면의 탭 뷰로 사용됨)
      body: SafeArea( // 상단바 겹침 방지 적용
        bottom: false,
        child: Consumer<CountryProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final countriesToDisplay = provider.filteredCountries;
            final visitedCountryNames = provider.visitedCountries;
            final visitedCountries = countriesToDisplay.where((c) => visitedCountryNames.contains(c.name)).toList();

            final totalVisitedPopulation = visitedCountries.fold<int>(0, (sum, item) => sum + item.populationEst);
            final totalWorldPopulation = countriesToDisplay.fold<int>(0, (sum, item) => sum + item.populationEst);
            final populationPercentage = totalWorldPopulation > 0 ? (totalVisitedPopulation / totalWorldPopulation * 100) : 0.0;

            final Map<String, int> totalPopulationByContinent = {};
            final Map<String, int> visitedPopulationByContinent = {};
            for (var data in continentsData) {
              final fullName = data['fullName'] as String;
              totalPopulationByContinent[fullName] = 0;
              visitedPopulationByContinent[fullName] = 0;
            }

            for (var country in countriesToDisplay) {
              if (country.continent != null && totalPopulationByContinent.containsKey(country.continent)) {
                totalPopulationByContinent.update(country.continent!, (v) => v + country.populationEst);
                if (visitedCountryNames.contains(country.name)) {
                  visitedPopulationByContinent.update(country.continent!, (v) => v + country.populationEst);
                }
              }
            }

            final avgVisitedPopulation = visitedCountries.isNotEmpty ? totalVisitedPopulation / visitedCountries.length : 0.0;
            final avgWorldPopulation = countriesToDisplay.isNotEmpty ? totalWorldPopulation / countriesToDisplay.length : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTotalPopulationCard(context, compactFormatter, totalVisitedPopulation, totalWorldPopulation, populationPercentage),
                  const SizedBox(height: 24),
                  _buildPopulationByContinentCard(context, compactFormatter, visitedPopulationByContinent, totalPopulationByContinent),
                  const SizedBox(height: 24),
                  _buildAveragePopulationCard(context, compactFormatter, avgVisitedPopulation, avgWorldPopulation),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 600,
                    child: _CombinedRankingCard(
                      countriesToDisplay: countriesToDisplay,
                      visitedCountryNames: visitedCountryNames,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTotalPopulationCard(BuildContext context, NumberFormat formatter, int visited, int total, double percentage) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 배경 장식
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.people_outline,
              size: 150,
              color: primaryColor.withOpacity(0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Global Reach',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total Population',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    // 백분율 표시 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // 왼쪽 통계 수치
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildStatRow(
                            context,
                            label: 'Met',
                            value: formatter.format(visited),
                            color: primaryColor,
                            icon: Icons.person_pin_circle,
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow(
                            context,
                            label: 'Total World',
                            value: formatter.format(total),
                            color: Colors.grey.shade400,
                            icon: Icons.public,
                          ),
                        ],
                      ),
                    ),
                    // 오른쪽 원형 차트
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: SleekCircularSlider(
                          initialValue: percentage,
                          min: 0,
                          max: 100,
                          appearance: CircularSliderAppearance(
                            customWidths: CustomSliderWidths(
                              trackWidth: 8,
                              progressBarWidth: 12,
                              handlerSize: 0,
                              shadowWidth: 0,
                            ),
                            customColors: CustomSliderColors(
                              trackColor: Colors.grey.shade100,
                              progressBarColors: [
                                primaryColor,
                                primaryColor.withOpacity(0.6)
                              ],
                              dynamicGradient: true,
                            ),
                            infoProperties: InfoProperties(
                              mainLabelStyle: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                              modifier: (double value) => "${value.toStringAsFixed(1)}%",
                            ),
                            size: 110,
                            angleRange: 360,
                            startAngle: 270,
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPopulationByContinentCard(BuildContext context, NumberFormat formatter, Map<String, int> visited, Map<String, int> total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text('Population by Continent', style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black,
          )),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: continentsData.length,
          itemBuilder: (context, index) {
            final data = continentsData[index];
            final name = data['name'] as String;
            final asset = data['asset'] as String;
            final fullName = data['fullName'] as String;
            final color = data['color'] as Color;

            final visitedPop = visited[fullName] ?? 0;
            final totalPop = total[fullName] ?? 0;
            final percent = totalPop == 0 ? 0.0 : visitedPop / totalPop;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(asset, width: 16, height: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(percent * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '${formatter.format(visitedPop)} / ${formatter.format(totalPop)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 6,
                          backgroundColor: color.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAveragePopulationCard(BuildContext context, NumberFormat formatter, double visitedAvg, double worldAvg) {
    final textTheme = Theme.of(context).textTheme;
    final primaryColor = Theme.of(context).primaryColor;
    final maxValue = math.max(visitedAvg, worldAvg);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Average Population per Country', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildHorizontalBar(
            context: context,
            label: 'Visited',
            value: visitedAvg,
            maxValue: maxValue,
            color: primaryColor,
            formatter: formatter,
            icon: Icons.flight_takeoff,
          ),
          const SizedBox(height: 16),
          _buildHorizontalBar(
            context: context,
            label: 'World',
            value: worldAvg,
            maxValue: maxValue,
            color: Colors.grey.shade400,
            formatter: formatter,
            icon: Icons.public,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBar({
    required BuildContext context,
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    required NumberFormat formatter,
    required IconData icon,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barMaxWidth = constraints.maxWidth - 100;
        final barWidth = math.max(4.0, (value / (maxValue == 0 ? 1 : maxValue)) * barMaxWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  formatter.format(value.round()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                width: barWidth,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
  late final RankingInfo _selectedRanking;

  int _displaySegment = 0; // 0: All, 1: Visited
  int _sortOrderSegment = 0; // 0: High, 1: Low
  String _selectedContinent = 'World';
  List<Country> _rankedList = [];

  final List<String> _continents = ['World', 'Asia', 'Europe', 'Africa', 'North America', 'South America', 'Oceania'];

  @override
  void initState() {
    super.initState();
    _selectedRanking = RankingInfo(title: 'Population Ranking', icon: Icons.groups, themeColor: Colors.teal, valueAccessor: (c) => c.populationEst);
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
    if (_displaySegment == 0) {
      listToRank = List.from(widget.countriesToDisplay);
    } else {
      listToRank = widget.countriesToDisplay.where((c) => widget.visitedCountryNames.contains(c.name)).toList();
    }

    if (_selectedContinent != 'World') {
      listToRank = listToRank.where((c) => c.continent == _selectedContinent).toList();
    }

    listToRank = listToRank.where((c) => _selectedRanking.valueAccessor(c) != null && _selectedRanking.valueAccessor(c)! > 0).toList();

    listToRank.sort((a,b) => (_selectedRanking.valueAccessor(a) ?? 0).compareTo(_selectedRanking.valueAccessor(b) ?? 0));

    if (_sortOrderSegment == 0) { // High to Low
      listToRank = listToRank.reversed.toList();
    }

    if(mounted){
      setState(() {
        _rankedList = listToRank;
      });
    }
  }

  void _onFilterChanged() => setState(() => _prepareList());

  // 순위에 따라 아이콘을 반환하는 헬퍼 함수
  // 1, 2, 3위도 일반 숫자 형식으로 표시되도록 수정
  Widget _buildRankIcon(int rank, Color color) {
    // 1위, 2위, 3위 포함 모든 순위를 일반 텍스트로 표시
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
    final compactFormatter = NumberFormat.compact();
    final topValue = _rankedList.isNotEmpty ? _selectedRanking.valueAccessor(_rankedList.first) ?? 1.0 : 1.0;

    // 1. 랭킹표의 테마색을 가져옵니다.
    final rankingThemeColor = _selectedRanking.themeColor;

    final countryProvider = Provider.of<CountryProvider>(context);
    final useDefaultColor = countryProvider.useDefaultRankingBarColor;

    final Map<String, Color> continentColors = {
      for (var data in PopulationStatsScreen.continentsData)
        data['fullName'] as String: data['color'] as Color
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단 필터/옵션 영역 (스위치 디자인 변경됨)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(_selectedRanking.icon, color: rankingThemeColor),
                    const SizedBox(width: 12),
                    Text(_selectedRanking.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // ⭐️ 스위치 디자인 적용됨
                    Expanded(
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<int>(value: 0, label: Text('All')),
                          ButtonSegment<int>(value: 1, label: Text('Visited')),
                        ],
                        selected: {_displaySegment},
                        onSelectionChanged: (s) { _displaySegment = s.first; _onFilterChanged(); },
                        style: SegmentedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          selectedForegroundColor: Colors.white,
                          // 1. 랭킹표의 테마색으로 변경
                          selectedBackgroundColor: rankingThemeColor.withOpacity(0.8),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ⭐️ 스위치 디자인 적용됨
                    Expanded(
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<int>(value: 0, label: Text('High')),
                          ButtonSegment<int>(value: 1, label: Text('Low')),
                        ],
                        selected: {_sortOrderSegment},
                        onSelectionChanged: (s) { _sortOrderSegment = s.first; _onFilterChanged(); },
                        style: SegmentedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          selectedForegroundColor: Colors.white,
                          // 1. 랭킹표의 테마색으로 변경
                          selectedBackgroundColor: rankingThemeColor.withOpacity(0.8),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
                        ),
                      ),
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
          // 랭킹 리스트
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
                final barColor = useDefaultColor ? rankingThemeColor : (continentColors[country.continent] ?? rankingThemeColor);
                final progressValue = value.toDouble() / math.max(1.0, topValue.toDouble());


                return Card(
                  elevation: 0,
                  color: isVisited ? rankingThemeColor.withOpacity(0.12) : Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell( // 상세 페이지 연결 적용
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => navigateToCountryDetail(context, country),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // 순위 표시 함수 사용 (1, 2, 3위도 숫자로 표시됨)
                              _buildRankIcon(rank, rankingThemeColor),
                              const SizedBox(width: 12),
                              Text(flagEmoji(country.isoA2), style: const TextStyle(fontSize: 18)), // 국기 추가
                              const SizedBox(width: 8),
                              Expanded(child: Text(country.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                              Text(compactFormatter.format(value), style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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