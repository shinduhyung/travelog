// lib/screens/city_sports_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/screens/city_stats_map_screen.dart';
import 'package:collection/collection.dart';
import 'dart:math' as math;
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

String _flagEmoji(String? countryCode) {
  if (countryCode == null) return '';
  final code = countryCode.trim().toUpperCase();
  if (code.length != 2) return '';
  final a = code.codeUnitAt(0);
  final b = code.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '';
  return String.fromCharCode(0x1F1E6 + (a - 65)) +
      String.fromCharCode(0x1F1E6 + (b - 65));
}

String _cityFlagEmoji(City city) {
  final iso = city.countryIsoA2.trim();
  if (iso.length == 2) return _flagEmoji(iso);
  return _flagEmoji(_countryNameToIso[city.country.trim()]);
}

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
// 디자인 토큰 (Specials와 동일)
// ====================================================================

class _ST {
  static const Color bg      = Color(0xFFF7F7F5);
  static const Color surface = Colors.white;
  static const Color ink     = Color(0xFF141414);
  static const Color inkMid  = Color(0xFF5C5C5C);
  static const Color inkLight= Color(0xFFAAAAAA);
  static const Color divider = Color(0xFFE8E8E4);
}

// ====================================================================
// 카드 데이터 모델
// ====================================================================

class _CardData {
  final String title;
  final String label;       // 섹션 레이블 (FOOTBALL, OLYMPICS …)
  final IconData icon;
  final Color color;
  final List<String> cityNames;

  const _CardData({
    required this.title,
    required this.label,
    required this.icon,
    required this.color,
    required this.cityNames,
  });
}

// ====================================================================
// 메인 스크린
// ====================================================================

class CitySportsScreen extends StatelessWidget {
  const CitySportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CityProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(strokeWidth: 2, color: _ST.ink),
                const SizedBox(height: 16),
                const Text(
                  'Loading sports...',
                  style: TextStyle(fontSize: 13, color: _ST.inkLight, letterSpacing: 0.3),
                ),
              ],
            ),
          );
        }

        final visited = provider.visitedCities;

        // ── 카드 목록 정의
        final List<_CardData> cards = [
          // FOOTBALL LEGENDS
          _CardData(
            title: 'Cristiano Ronaldo',
            label: 'FOOTBALL LEGEND',
            icon: Icons.sports_soccer,
            color: const Color(0xFFD64545),
            cityNames: ['Manchester', 'Riyadh', 'Madrid', 'Lisbon', 'Turin'],
          ),
          _CardData(
            title: 'Lionel Messi',
            label: 'FOOTBALL LEGEND',
            icon: Icons.sports_soccer,
            color: const Color(0xFF3D5A99),
            cityNames: ['Barcelona', 'Paris', 'Miami'],
          ),
          _CardData(
            title: 'Zlatan Ibrahimović',
            label: 'FOOTBALL LEGEND',
            icon: Icons.sports_soccer,
            color: const Color(0xFF2A6B9C),
            cityNames: ['Malmö', 'Amsterdam', 'Turin', 'Milan', 'Barcelona', 'Paris', 'Manchester', 'Los Angeles'],
          ),
          // OLYMPICS
          _CardData(
            title: 'Summer Olympics',
            label: 'OLYMPICS',
            icon: Icons.wb_sunny_outlined,
            color: const Color(0xFFC4922A),
            cityNames: provider.summerOlympicsCities.map((c) => c.name).toSet().toList()..sort(),
          ),
          _CardData(
            title: 'Winter Olympics',
            label: 'OLYMPICS',
            icon: Icons.ac_unit_outlined,
            color: const Color(0xFF5A9EC4),
            cityNames: provider.winterOlympicsCities.map((c) => c.name).toSet().toList()..sort(),
          ),
          // AMERICAN SPORTS
          _CardData(
            title: 'NFL Cities',
            label: 'AMERICAN SPORTS',
            icon: Icons.sports_football_outlined,
            color: const Color(0xFF7A4A2A),
            cityNames: provider.nflCities.map((c) => c.name).toSet().toList()..sort(),
          ),
          _CardData(
            title: 'NBA Cities',
            label: 'AMERICAN SPORTS',
            icon: Icons.sports_basketball_outlined,
            color: const Color(0xFFD66B2A),
            cityNames: provider.nbaCities.map((c) => c.name).toSet().toList()..sort(),
          ),
          _CardData(
            title: 'MLB Cities',
            label: 'AMERICAN SPORTS',
            icon: Icons.sports_baseball_outlined,
            color: const Color(0xFF2A8C74),
            cityNames: provider.mlbCities.map((c) => c.name).toSet().toList()..sort(),
          ),
          _CardData(
            title: 'NHL Cities',
            label: 'AMERICAN SPORTS',
            icon: Icons.sports_hockey_outlined,
            color: const Color(0xFF3B5C7A),
            cityNames: provider.nhlCities.map((c) => c.name).toSet().toList()..sort(),
          ),
          _CardData(
            title: 'MLS Cities',
            label: 'AMERICAN SPORTS',
            icon: Icons.sports_soccer_outlined,
            color: const Color(0xFF2A6B4A),
            cityNames: provider.mlsCities.map((c) => c.name).toSet().toList()..sort(),
          ),
          // TENNIS
          _CardData(
            title: 'Tennis Grand Slam',
            label: 'TENNIS',
            icon: Icons.sports_tennis_outlined,
            color: const Color(0xFF6B3D99),
            cityNames: const ['Melbourne', 'Paris', 'London', 'New York City'],
          ),
        ];

        // 완료된 컬렉션 수
        final completed = cards.where((c) {
          if (c.cityNames.isEmpty) return false;
          return c.cityNames.every((name) => visited.contains(name));
        }).length;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 상단 요약 헤더
              _SectionHeader(label: 'COLLECTIONS'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SportsSummaryBar(
                  cards: cards,
                  visitedNames: visited,
                  completed: completed,
                ),
              ),

              const SizedBox(height: 8),

              // ── 카드 리스트 (섹션 레이블별 그룹)
              ..._buildGroupedCards(cards, visited, provider),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupedCards(
      List<_CardData> cards,
      Set<String> visited,
      CityProvider provider,
      ) {
    final widgets = <Widget>[];
    String? lastLabel;

    for (final card in cards) {
      if (card.label != lastLabel) {
        widgets.add(_SectionHeader(label: card.label));
        lastLabel = card.label;
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _SportsCard(
            data: card,
            visitedNames: visited,
            provider: provider,
          ),
        ),
      );
    }
    return widgets;
  }
}

// ====================================================================
// 섹션 헤더 (Specials와 동일)
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
              color: _ST.inkLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: _ST.divider)),
        ],
      ),
    );
  }
}

// ====================================================================
// 요약 바
// ====================================================================

class _SportsSummaryBar extends StatelessWidget {
  final List<_CardData> cards;
  final Set<String> visitedNames;
  final int completed;

  const _SportsSummaryBar({
    required this.cards,
    required this.visitedNames,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final total = cards.length;
    final pct = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ST.ink,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed of $total collections',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  completed == 0
                      ? 'No collections fully completed yet'
                      : completed == total
                      ? 'All collections completed! 🎉'
                      : '${total - completed} remaining to complete',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 14),
                _SegmentBar(cards: cards, visitedNames: visitedNames),
              ],
            ),
          ),
          const SizedBox(width: 20),
          _ArcPercent(value: pct),
        ],
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  final List<_CardData> cards;
  final Set<String> visitedNames;

  const _SegmentBar({required this.cards, required this.visitedNames});

  @override
  Widget build(BuildContext context) {
    final total = cards.fold<int>(0, (s, c) => s + c.cityNames.length);
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: cards.map((c) {
            final fraction = c.cityNames.length / total;
            final visitedCount = c.cityNames.where((n) => visitedNames.contains(n)).length;
            final visitedFrac = c.cityNames.isNotEmpty ? visitedCount / c.cityNames.length : 0.0;

            return Expanded(
              flex: (fraction * 1000).round(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                child: Stack(
                  children: [
                    Container(color: const Color(0xFF2E2E2E)),
                    FractionallySizedBox(
                      widthFactor: visitedFrac,
                      child: Container(color: c.color),
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

class _ArcPercent extends StatelessWidget {
  final double value;
  const _ArcPercent({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(68, 68), painter: _ArcPainter(value: value)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}',
                style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: Colors.white, height: 1,
                ),
              ),
              const Text('%', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
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
    const sw = 4.0;
    canvas.drawCircle(center, radius,
        Paint()..color = const Color(0xFF2E2E2E)..style = PaintingStyle.stroke..strokeWidth = sw);
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * value, false,
        Paint()
          ..color = Colors.white..style = PaintingStyle.stroke
          ..strokeWidth = sw..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value;
}

// ====================================================================
// 스포츠 카드
// ====================================================================

class _SportsCard extends StatefulWidget {
  final _CardData data;
  final Set<String> visitedNames;
  final CityProvider provider;

  const _SportsCard({
    required this.data,
    required this.visitedNames,
    required this.provider,
  });

  @override
  State<_SportsCard> createState() => _SportsCardState();
}

class _SportsCardState extends State<_SportsCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _rotatAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _rotatAnim = Tween(begin: 0.0, end: 0.5).animate(
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
    final d = widget.data;
    final total = d.cityNames.length;
    final visited = d.cityNames.where((n) => widget.visitedNames.contains(n)).length;
    final remaining = total - visited;
    final pct = total > 0 ? visited / total : 0.0;

    // 지도용 City 리스트
    final mapCities = d.cityNames
        .map((name) => widget.provider.allCities.firstWhereOrNull((c) => c.name == name))
        .whereType<City>()
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: _ST.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ST.divider),
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
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: d.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(d.icon, size: 20, color: d.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            letterSpacing: 1.5, color: d.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.title,
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: _ST.ink, letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 지도 버튼
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CityStatsMapScreen(
                          cities: mapCities,
                          title: d.title,
                          markerColor: d.color,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _ST.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _ST.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.map_outlined, size: 14, color: _ST.inkMid),
                          SizedBox(width: 4),
                          Text('Map', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _ST.inkMid, letterSpacing: 0.2,
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  RotationTransition(
                    turns: _rotatAnim,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 22, color: _ST.inkLight),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: _ST.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(d.color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Chip(label: 'Visited', value: '$visited', color: d.color),
                    const SizedBox(width: 8),
                    _Chip(label: 'Remaining', value: '$remaining', color: _ST.inkLight),
                    const Spacer(),
                    Text(
                      '${(pct * 100).round()}%',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: pct > 0 ? d.color : _ST.inkLight,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 펼침: 도시 칩
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _expanded
                ? FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _ST.divider)),
                ),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: d.cityNames.map((name) {
                    final isVisited = widget.visitedNames.contains(name);
                    final cityObj = widget.provider.allCities
                        .firstWhereOrNull((c) => c.name == name);
                    return _CityChip(
                      name: name,
                      city: cityObj,
                      isVisited: isVisited,
                      color: d.color,
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
// 작은 컴포넌트
// ====================================================================

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w500,
          color: _ST.inkLight, letterSpacing: 0.3,
        )),
      ],
    );
  }
}

class _CityChip extends StatelessWidget {
  final String name;
  final City? city;
  final bool isVisited;
  final Color color;

  const _CityChip({
    required this.name,
    required this.isVisited,
    required this.color,
    this.city,
  });

  @override
  Widget build(BuildContext context) {
    final flag = city != null ? _cityFlagEmoji(city!) : '';
    return GestureDetector(
      onTap: city != null
          ? () => _showCityModal(context, city!)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isVisited ? color : _ST.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isVisited ? color : _ST.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag.isNotEmpty) ...[
              Text(flag, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 5),
            ],
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isVisited ? FontWeight.w700 : FontWeight.w500,
                color: isVisited ? Colors.white : _ST.inkMid,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}