// lib/screens/city_specials_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

// 🚨 지도 화면 및 스포츠 스크린 임포트
import 'package:jidoapp/screens/city_sports_screen.dart';
import 'package:jidoapp/screens/city_stats_map_screen.dart';
import 'package:jidoapp/screens/cities_screen.dart';

// ====================================================================
// 모달 헬퍼 (allCities에서 풀 데이터 City 조회 → 국가 테마색 보장)
// ====================================================================

void _showCityModal(BuildContext context, City city) {
  final provider = Provider.of<CityProvider>(context, listen: false);
  final fullCity = provider.allCities.firstWhere(
        (c) => c.name == city.name && c.countryIsoA2.isNotEmpty,
    orElse: () => city,
  );
  showExternalCityDetailsModal(context, fullCity);
}

// ====================================================================
// 국기 이모지 헬퍼
// ====================================================================

/// ISO 2자리 국가 코드 → 국기 이모지
String _flagEmoji(String? countryCode) {
  if (countryCode == null) return '';
  final code = countryCode.trim().toUpperCase();
  if (code.length != 2) return '';
  final a = code.codeUnitAt(0);
  final b = code.codeUnitAt(1);
  // A=65, Z=90 범위 체크
  if (a < 65 || a > 90 || b < 65 || b > 90) return '';
  // Regional Indicator Symbol: A → 0x1F1E6
  return String.fromCharCode(0x1F1E6 + (a - 65)) +
      String.fromCharCode(0x1F1E6 + (b - 65));
}

/// City에서 국기 이모지 가져오기 (countryIsoA2 우선, 없으면 country 이름으로 fallback)
String _cityFlagEmoji(City city) {
  final iso = city.countryIsoA2.trim();
  if (iso.length == 2) return _flagEmoji(iso);
  // fallback: country 이름으로 ISO 코드 조회
  final code = _countryNameToIso[city.country.trim()];
  return _flagEmoji(code);
}

/// 국가명 → ISO A2 코드 (fallback용)
const Map<String, String> _countryNameToIso = {
  'Afghanistan': 'AF', 'Albania': 'AL', 'Algeria': 'DZ', 'Argentina': 'AR',
  'Armenia': 'AM', 'Australia': 'AU', 'Austria': 'AT', 'Azerbaijan': 'AZ',
  'Bahrain': 'BH', 'Bangladesh': 'BD', 'Belarus': 'BY', 'Belgium': 'BE',
  'Bolivia': 'BO', 'Bosnia and Herzegovina': 'BA', 'Brazil': 'BR',
  'Bulgaria': 'BG', 'Cambodia': 'KH', 'Cameroon': 'CM', 'Canada': 'CA',
  'Chile': 'CL', 'China': 'CN', 'Colombia': 'CO', 'Croatia': 'HR',
  'Cuba': 'CU', 'Czech Republic': 'CZ', 'Czechia': 'CZ', 'Denmark': 'DK',
  'Ecuador': 'EC', 'Egypt': 'EG', 'Ethiopia': 'ET', 'Finland': 'FI',
  'France': 'FR', 'Georgia': 'GE', 'Germany': 'DE', 'Ghana': 'GH',
  'Greece': 'GR', 'Guatemala': 'GT', 'Hong Kong': 'HK', 'Hungary': 'HU',
  'India': 'IN', 'Indonesia': 'ID', 'Iran': 'IR', 'Iraq': 'IQ',
  'Ireland': 'IE', 'Israel': 'IL', 'Italy': 'IT', 'Jamaica': 'JM',
  'Japan': 'JP', 'Jordan': 'JO', 'Kazakhstan': 'KZ', 'Kenya': 'KE',
  'Kuwait': 'KW', 'Lebanon': 'LB', 'Libya': 'LY', 'Malaysia': 'MY',
  'Mexico': 'MX', 'Morocco': 'MA', 'Myanmar': 'MM', 'Nepal': 'NP',
  'Netherlands': 'NL', 'New Zealand': 'NZ', 'Nigeria': 'NG', 'Norway': 'NO',
  'Pakistan': 'PK', 'Panama': 'PA', 'Paraguay': 'PY', 'Peru': 'PE',
  'Philippines': 'PH', 'Poland': 'PL', 'Portugal': 'PT', 'Qatar': 'QA',
  'Romania': 'RO', 'Russia': 'RU', 'Saudi Arabia': 'SA', 'Senegal': 'SN',
  'Serbia': 'RS', 'Singapore': 'SG', 'Slovakia': 'SK', 'Slovenia': 'SI',
  'South Africa': 'ZA', 'South Korea': 'KR', 'Korea': 'KR',
  'Republic of Korea': 'KR', 'Spain': 'ES', 'Sri Lanka': 'LK',
  'Sudan': 'SD', 'Sweden': 'SE', 'Switzerland': 'CH', 'Syria': 'SY',
  'Taiwan': 'TW', 'Tanzania': 'TZ', 'Thailand': 'TH', 'Tunisia': 'TN',
  'Turkey': 'TR', 'Türkiye': 'TR', 'Ukraine': 'UA',
  'United Arab Emirates': 'AE', 'UAE': 'AE',
  'United Kingdom': 'GB', 'UK': 'GB',
  'United States': 'US', 'USA': 'US', 'United States of America': 'US',
  'Uruguay': 'UY', 'Uzbekistan': 'UZ', 'Venezuela': 'VE', 'Vietnam': 'VN',
  'Yemen': 'YE', 'Zimbabwe': 'ZW', 'North Korea': 'KP',
  'Democratic Republic of the Congo': 'CD', 'Congo': 'CG',
  'Ivory Coast': 'CI', 'Dominican Republic': 'DO',
  'El Salvador': 'SV', 'Costa Rica': 'CR', 'Honduras': 'HN',
  'Nicaragua': 'NI', 'Puerto Rico': 'PR',
};


// ====================================================================
// 데이터 클래스 및 Enum 정의
// ====================================================================

class RankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final num Function(dynamic) valueAccessor;
  final String metricKey;
  final String unit;

  const RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.valueAccessor,
    this.metricKey = '',
    this.unit = '',
  });
}

class SpecialGroupInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final List<City> cities;

  SpecialGroupInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.cities,
  });
}

enum MapFilter { all, visited }

final Map<String, Color> continentColors = {
  'Asia': Colors.pink.shade200,
  'Europe': Colors.amber,
  'Africa': Colors.brown,
  'North America': Colors.blue.shade200,
  'South America': Colors.green,
  'Oceania': Colors.purple,
};

// ====================================================================
// 디자인 토큰
// ====================================================================

class _AppTheme {
  static const Color bg = Color(0xFFF7F7F5);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF141414);
  static const Color inkMid = Color(0xFF5C5C5C);
  static const Color inkLight = Color(0xFFAAAAAA);
  static const Color divider = Color(0xFFE8E8E4);

  // 카테고리 accent 팔레트 (채도 낮은 인쇄물 스타일)
  static const Color accentFilm = Color(0xFFD64545);
  static const Color accentFlag = Color(0xFF3D5A99);
  static const Color accentCity = Color(0xFF2A8C74);
  static const Color accentSimilar = Color(0xFFD66B2A);
  static const Color accentFormer = Color(0xFF7A5C3C);
  static const Color accentPlanned = Color(0xFF5A7080);
  static const Color accentState = Color(0xFF6B3D99);

  static const Color rankingBuilding = Color(0xFF3B5C7A);
  static const Color rankingHollywood = Color(0xFFC4922A);
}

// ====================================================================
// 메인 통합 스크린
// ====================================================================

class CitySpecialsScreen extends StatelessWidget {
  const CitySpecialsScreen({super.key});

  static const List<String> _tabs = ['Specials', 'Sports'];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _AppTheme.bg,
        cardColor: _AppTheme.surface,
      ),
      child: DefaultTabController(
        length: _tabs.length,
        child: Scaffold(
          backgroundColor: _AppTheme.bg,
          appBar: _SpecialsAppBar(),
          body: const TabBarView(
            children: [
              _SpecialsTabContent(),
              CitySportsScreen(),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// App Bar
// ====================================================================

class _SpecialsAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _AppTheme.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _AppTheme.divider),
      ),
      title: TabBar(
        tabs: const [
          Tab(text: 'Specials'),
          Tab(text: 'Sports'),
        ],
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        labelColor: _AppTheme.ink,
        unselectedLabelColor: _AppTheme.inkLight,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: _AppTheme.ink, width: 2),
          insets: EdgeInsets.symmetric(horizontal: 24),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }
}

// ====================================================================
// Specials 탭 내용
// ====================================================================

class _SpecialsTabContent extends StatelessWidget {
  const _SpecialsTabContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<CityProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _AppTheme.ink,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading specials...',
                  style: TextStyle(
                    fontSize: 13,
                    color: _AppTheme.inkLight,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        }

        final visitedCities = provider.visitedCities;
        final allSkyscraperData =
        provider.skyscraperCities.where((c) => c.skyscraperCount != 0).toList();
        final allHollywoodData =
        provider.hollywoodCities.where((c) => c.hollywoodScore != 0.0).toList();
        final useDefaultColor = provider.useDefaultCityRankingBarColor;

        // 카테고리 데이터 목록
        final groups = [
          _GroupData(
            title: 'Int\'l Film Festivals',
            label: 'CULTURE',
            icon: Icons.movie_filter_outlined,
            color: _AppTheme.accentFilm,
            cities: provider.majorFilmFestivalCities,
          ),
          _GroupData(
            title: 'Country Name Identical',
            label: 'GEOGRAPHY',
            icon: Icons.flag_outlined,
            color: _AppTheme.accentFlag,
            cities: provider.countryNameIdenticalToCapital,
          ),
          _GroupData(
            title: 'Capital with "City"',
            label: 'NAMING',
            icon: Icons.location_city_outlined,
            color: _AppTheme.accentCity,
            cities: provider.capitalsWithCityInName,
          ),
          _GroupData(
            title: 'High Similarity Names',
            label: 'NAMING',
            icon: Icons.compare_arrows_outlined,
            color: _AppTheme.accentSimilar,
            cities: provider.countryCapitalHighSimilarity,
          ),
          _GroupData(
            title: 'Former Capitals',
            label: 'HISTORY',
            icon: Icons.history_edu_outlined,
            color: _AppTheme.accentFormer,
            cities: provider.formerCapitalRelocations,
          ),
          _GroupData(
            title: 'Planned Capitals',
            label: 'ARCHITECTURE',
            icon: Icons.architecture_outlined,
            color: _AppTheme.accentPlanned,
            cities: provider.plannedCapitals,
          ),
          _GroupData(
            title: 'City-States',
            label: 'POLITICS',
            icon: Icons.account_balance_outlined,
            color: _AppTheme.accentState,
            cities: provider.cityStates,
          ),
        ];

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 랭킹 섹션 헤더
              _SectionHeader(label: 'RANKINGS'),

              // ── 랭킹 카드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RankingCard(
                  skyscraperData: allSkyscraperData,
                  hollywoodData: allHollywoodData,
                  visitedNames: visitedCities,
                  useDefaultColor: useDefaultColor,
                ),
              ),

              const SizedBox(height: 8),

              // ── 컬렉션 섹션 헤더
              _SectionHeader(label: 'COLLECTIONS'),

              // ── 통계 요약 바
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CollectionSummaryRow(
                  groups: groups,
                  visitedCityNames: visitedCities,
                ),
              ),

              const SizedBox(height: 16),

              // ── 카테고리 카드 리스트
              ...groups.map(
                    (g) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _CollectionCard(
                    data: g,
                    visitedCityNames: visitedCities,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ====================================================================
// 섹션 헤더
// ====================================================================

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: _AppTheme.inkLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: _AppTheme.divider)),
        ],
      ),
    );
  }
}

// ====================================================================
// 컬렉션 요약 바 (상단 overview)
// ====================================================================

class _CollectionSummaryRow extends StatelessWidget {
  final List<_GroupData> groups;
  final Set<String> visitedCityNames;

  const _CollectionSummaryRow({
    required this.groups,
    required this.visitedCityNames,
  });

  @override
  Widget build(BuildContext context) {
    // 완료된 컬렉션 = 모든 도시를 방문한 그룹
    final completedGroups = groups.where((g) {
      if (g.cities.isEmpty) return false;
      return g.cities.every((c) => visitedCityNames.contains(c.name));
    }).length;
    final totalGroups = groups.length;
    final pct = totalGroups > 0 ? completedGroups / totalGroups : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppTheme.ink,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 숫자
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completedGroups of $totalGroups collections',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  completedGroups == 0
                      ? 'No collections fully completed yet'
                      : completedGroups == totalGroups
                      ? 'All collections completed! 🎉'
                      : '${totalGroups - completedGroups} remaining to complete',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 14),
                // 세그먼트 바
                _SegmentedProgressBar(groups: groups, visitedCityNames: visitedCityNames),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // 원형 퍼센트
          _CirclePercent(value: pct),
        ],
      ),
    );
  }
}

class _SegmentedProgressBar extends StatelessWidget {
  final List<_GroupData> groups;
  final Set<String> visitedCityNames;

  const _SegmentedProgressBar({
    required this.groups,
    required this.visitedCityNames,
  });

  @override
  Widget build(BuildContext context) {
    final totalCities = groups.fold<int>(0, (s, g) => s + g.cities.length);
    if (totalCities == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: groups.map((g) {
            final fraction = g.cities.length / totalCities;
            final visited =
                g.cities.where((c) => visitedCityNames.contains(c.name)).length;
            final visitedFrac = g.cities.isNotEmpty ? visited / g.cities.length : 0.0;

            return Expanded(
              flex: (fraction * 1000).round(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                child: Stack(
                  children: [
                    Container(color: const Color(0xFF2E2E2E)),
                    FractionallySizedBox(
                      widthFactor: visitedFrac,
                      child: Container(color: g.color),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CirclePercent extends StatelessWidget {
  final double value;
  const _CirclePercent({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(68, 68),
            painter: _ArcPainter(value: value),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const Text(
                '%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double value;
  const _ArcPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeW = 4.0;

    // track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF2E2E2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );
    // arc
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value;
}

// ====================================================================
// 랭킹 카드
// ====================================================================

class _RankingCard extends StatefulWidget {
  final List<City> skyscraperData;
  final List<City> hollywoodData;
  final Set<String> visitedNames;
  final bool useDefaultColor;

  const _RankingCard({
    required this.skyscraperData,
    required this.hollywoodData,
    required this.visitedNames,
    required this.useDefaultColor,
  });

  @override
  State<_RankingCard> createState() => _RankingCardState();
}

class _RankingCardState extends State<_RankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selectedRanking;
  List<City> _rankedList = [];

  @override
  void initState() {
    super.initState();
    _rankings = [
      RankingInfo(
        title: 'Skyscraper Count',
        icon: Icons.domain_outlined,
        themeColor: _AppTheme.rankingBuilding,
        valueAccessor: (c) => (c as City).skyscraperCount,
        metricKey: 'skyscraper',
      ),
      RankingInfo(
        title: 'Hollywood Filming',
        icon: Icons.movie_outlined,
        themeColor: _AppTheme.rankingHollywood,
        valueAccessor: (c) => (c as City).hollywoodScore,
        metricKey: 'hollywood',
      ),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  void _prepareList() {
    List<City> listToRank = _selectedRanking.metricKey == 'skyscraper'
        ? List<City>.from(widget.skyscraperData)
        : List<City>.from(widget.hollywoodData);

    listToRank.sort(
            (a, b) => _selectedRanking.valueAccessor(b).compareTo(_selectedRanking.valueAccessor(a)));
    setState(() => _rankedList = listToRank.take(30).toList());
  }

  @override
  Widget build(BuildContext context) {
    final compactFormatter = NumberFormat.compact();
    final topValue =
    _rankedList.isNotEmpty ? _selectedRanking.valueAccessor(_rankedList.first) : 1;
    final themeColor = _selectedRanking.themeColor;

    return Container(
      decoration: BoxDecoration(
        color: _AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppTheme.divider),
      ),
      child: Column(
        children: [
          // ── 탭 토글 헤더
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _AppTheme.divider)),
            ),
            child: Row(
              children: _rankings.map((r) {
                final isActive = r == _selectedRanking;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedRanking = r;
                      _prepareList();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isActive ? _AppTheme.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            r.icon,
                            size: 16,
                            color: isActive ? Colors.white : _AppTheme.inkLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            r.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                              color: isActive ? Colors.white : _AppTheme.inkLight,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── 랭킹 리스트
          SizedBox(
            height: 360,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _rankedList.length,
              itemBuilder: (context, index) {
                final item = _rankedList[index];
                final value = _selectedRanking.valueAccessor(item);
                final isVisited = widget.visitedNames.contains(item.name);
                final rank = index + 1;
                final barFraction =
                topValue == 0 ? 0.0 : value.toDouble() / topValue.toDouble();
                final barColor = widget.useDefaultColor
                    ? themeColor
                    : continentColors[item.continent] ?? themeColor;

                return _RankingRow(
                  rank: rank,
                  city: item,
                  value: _selectedRanking.metricKey == 'hollywood'
                      ? value.toInt().toString()
                      : compactFormatter.format(value),
                  isVisited: isVisited,
                  barFraction: barFraction,
                  barColor: barColor,
                  accentColor: themeColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final City city;
  final String value;
  final bool isVisited;
  final double barFraction;
  final Color barColor;
  final Color accentColor;

  const _RankingRow({
    required this.rank,
    required this.city,
    required this.value,
    required this.isVisited,
    required this.barFraction,
    required this.barColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    if (rank == 1) rankColor = const Color(0xFFC4922A);
    else if (rank == 2) rankColor = const Color(0xFF888888);
    else if (rank == 3) rankColor = const Color(0xFF8B5C2E);
    else rankColor = _AppTheme.inkLight;

    return GestureDetector(
      onTap: () => _showCityModal(context, city),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isVisited ? accentColor.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isVisited
              ? Border(left: BorderSide(color: accentColor, width: 2.5))
              : const Border(left: BorderSide(color: Colors.transparent, width: 2.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                rank <= 3 ? '${rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉'}' : '$rank',
                style: TextStyle(fontSize: rank <= 3 ? 16 : 12, fontWeight: FontWeight.w700, color: rankColor),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          city.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isVisited ? FontWeight.w700 : FontWeight.w500,
                            color: _AppTheme.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVisited) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
                      ],
                      const SizedBox(width: 6),
                      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _AppTheme.ink)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      minHeight: 3,
                      backgroundColor: _AppTheme.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(_cityFlagEmoji(city), style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(city.country, style: const TextStyle(fontSize: 10, color: _AppTheme.inkLight, letterSpacing: 0.1)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// 그룹 데이터 모델
// ====================================================================

class _GroupData {
  final String title;
  final String label;
  final IconData icon;
  final Color color;
  final List<City> cities;

  const _GroupData({
    required this.title,
    required this.label,
    required this.icon,
    required this.color,
    required this.cities,
  });
}

// ====================================================================
// 컬렉션 카드 (새 디자인)
// ====================================================================

class _CollectionCard extends StatefulWidget {
  final _GroupData data;
  final Set<String> visitedCityNames;

  const _CollectionCard({
    required this.data,
    required this.visitedCityNames,
  });

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _rotateAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 250), vsync: this);
    _rotateAnim = Tween(begin: 0.0, end: 0.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      _expanded ? _ctrl.forward() : _ctrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.data;
    final displayCities = List<City>.from(g.cities)..sort((a, b) => a.name.compareTo(b.name));
    final total = displayCities.length;
    final visited =
        displayCities.where((c) => widget.visitedCityNames.contains(c.name)).length;
    final pct = total > 0 ? visited / total : 0.0;
    final notVisitedCount = total - visited;

    return Container(
      decoration: BoxDecoration(
        color: _AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppTheme.divider),
      ),
      child: Column(
        children: [
          // ── 헤더
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 컬러 아이콘 박스
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: g.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(g.icon, size: 20, color: g.color),
                  ),
                  const SizedBox(width: 14),

                  // 타이틀
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: g.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          g.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _AppTheme.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 지도 버튼
                  _MapButton(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CityStatsMapScreen(
                          cities: displayCities,
                          title: g.title,
                          markerColor: g.color,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),
                  // 펼치기 아이콘
                  RotationTransition(
                    turns: _rotateAnim,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 22, color: _AppTheme.inkLight),
                  ),
                ],
              ),
            ),
          ),

          // ── 진행 바 + 통계
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                // 진행바
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: _AppTheme.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(g.color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatChip(
                      label: 'Visited',
                      value: '$visited',
                      color: g.color,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Remaining',
                      value: '$notVisitedCount',
                      color: _AppTheme.inkLight,
                    ),
                    const Spacer(),
                    Text(
                      '${(pct * 100).round()}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: pct > 0 ? g.color : _AppTheme.inkLight,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 펼침: 도시 칩 목록
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _expanded
                ? FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _AppTheme.divider),
                  ),
                ),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: displayCities.map((city) {
                    final isVisited = widget.visitedCityNames.contains(city.name);
                    return _CityChip(
                      city: city,
                      isVisited: isVisited,
                      color: g.color,
                    );
                  }).toList(),
                ),
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 작은 UI 컴포넌트들
// ====================================================================

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _AppTheme.inkLight,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _CityChip extends StatelessWidget {
  final City city;
  final bool isVisited;
  final Color color;

  const _CityChip({
    required this.city,
    required this.isVisited,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final flag = _cityFlagEmoji(city);
    return GestureDetector(
      onTap: () => _showCityModal(context, city),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isVisited ? color : _AppTheme.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isVisited ? color : _AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag.isNotEmpty) ...[
              Text(flag, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 5),
            ],
            Text(
              city.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isVisited ? FontWeight.w700 : FontWeight.w500,
                color: isVisited ? Colors.white : _AppTheme.inkMid,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _AppTheme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.map_outlined, size: 14, color: _AppTheme.inkMid),
            SizedBox(width: 4),
            Text(
              'Map',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _AppTheme.inkMid,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}