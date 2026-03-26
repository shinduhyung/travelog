// lib/screens/city_climate_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'dart:math' as math;
import 'package:jidoapp/screens/city_stats_map_screen.dart';
import 'package:jidoapp/screens/cities_screen.dart';

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
// 디자인 토큰 (Geography/Specials와 동일)
// ====================================================================

class _CT {
  static const Color bg       = Color(0xFFF7F7F5);
  static const Color surface  = Colors.white;
  static const Color ink      = Color(0xFF141414);
  static const Color inkMid   = Color(0xFF5C5C5C);
  static const Color inkLight = Color(0xFFAAAAAA);
  static const Color divider  = Color(0xFFE8E8E4);

  static const Color temp      = Color(0xFFD66B2A);
  static const Color precip    = Color(0xFF3B5C7A);
  static const Color seaLevel  = Color(0xFF3B7ABF);
  static const Color river     = Color(0xFF3D9EC4);
  static const Color mountain  = Color(0xFF2A8C74);
  static const Color desert    = Color(0xFFC4922A);
  static const Color snow      = Color(0xFF5A7080);
}

const Map<String, Color> _continentColors = {
  'Asia': Color(0xFFF48FB1),
  'Europe': Color(0xFFFFCA28),
  'Africa': Color(0xFF8D6E63),
  'North America': Color(0xFF90CAF9),
  'South America': Color(0xFF66BB6A),
  'Oceania': Color(0xFFCE93D8),
};

// ====================================================================
// RankingInfo
// ====================================================================

class RankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final num Function(City) valueAccessor;
  final String unit;

  const RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.valueAccessor,
    this.unit = '',
  });
}

// ====================================================================
// 진입점 래퍼
// ====================================================================

class CityClimateScreen extends StatelessWidget {
  const CityClimateScreen({super.key});

  @override
  Widget build(BuildContext context) => const CityClimateTabScreen();
}

// ====================================================================
// Climate 탭 본체
// ====================================================================

class CityClimateTabScreen extends StatelessWidget {
  const CityClimateTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CityProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(strokeWidth: 2, color: _CT.ink),
                SizedBox(height: 16),
                Text('Loading climate data...', style: TextStyle(fontSize: 13, color: _CT.inkLight)),
              ],
            ),
          );
        }

        final visitedNames = provider.visitedCities;

        // 컬렉션 그룹 정의
        final groups = [
          _ClimateGroup(
            title: 'Below Sea Level',
            label: 'ELEVATION',
            icon: Icons.water_outlined,
            color: _CT.seaLevel,
            cities: provider.capitalsBelowSeaLevel,
          ),
          _ClimateGroup(
            title: 'Elevation > 1,000m',
            label: 'ELEVATION',
            icon: Icons.landscape_outlined,
            color: _CT.mountain,
            cities: provider.capitalsAbove1000m,
          ),
          _ClimateGroup(
            title: 'Hot Desert Climate',
            label: 'CLIMATE',
            icon: Icons.wb_sunny_outlined,
            color: _CT.desert,
            cities: provider.capitalsHotDesertClimate,
          ),
          _ClimateGroup(
            title: 'No Seasonal Snowfall',
            label: 'CLIMATE',
            icon: Icons.ac_unit_outlined,
            color: _CT.snow,
            cities: provider.capitalsNoSeasonalSnowfall,
          ),
        ];

        final completed = groups.where((g) =>
        g.cities.isNotEmpty && g.cities.every((c) => visitedNames.contains(c.name))
        ).length;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Rankings
              _SectionHeader(label: 'RANKINGS'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ClimateRankingCard(
                  allCities: provider.allCities,
                  visitedNames: visitedNames,
                  useDefaultColor: provider.useDefaultCityRankingBarColor,
                ),
              ),

              // ── Collections summary
              _SectionHeader(label: 'COLLECTIONS'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ClimateSummaryBar(
                  groups: groups,
                  visitedNames: visitedNames,
                  completed: completed,
                ),
              ),
              const SizedBox(height: 16),

              // 섹션 레이블별 그룹 렌더링
              ..._buildGroupedCards(groups, visitedNames),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupedCards(
      List<_ClimateGroup> groups,
      Set<String> visitedNames,
      ) {
    final widgets = <Widget>[];
    String? lastLabel;
    for (final g in groups) {
      if (g.label != lastLabel) {
        widgets.add(_SectionHeader(label: g.label));
        lastLabel = g.label;
      }
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _ClimateCollectionCard(data: g, visitedNames: visitedNames),
      ));
    }
    return widgets;
  }
}
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
          Text(label, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 2.0, color: _CT.inkLight,
          )),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: _CT.divider)),
        ],
      ),
    );
  }
}

// ====================================================================
// 랭킹 카드
// ====================================================================

class _ClimateRankingCard extends StatefulWidget {
  final List<City> allCities;
  final Set<String> visitedNames;
  final bool useDefaultColor;

  const _ClimateRankingCard({
    required this.allCities,
    required this.visitedNames,
    required this.useDefaultColor,
  });

  @override
  State<_ClimateRankingCard> createState() => _ClimateRankingCardState();
}

class _ClimateRankingCardState extends State<_ClimateRankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selected;
  int _sortDir = 0;
  List<City> _list = [];

  @override
  void initState() {
    super.initState();
    _rankings = [
      RankingInfo(
        title: 'Avg Temperature',
        icon: Icons.thermostat_outlined,
        themeColor: _CT.temp,
        valueAccessor: (c) => c.avgTemp,
        unit: '°C',
      ),
      RankingInfo(
        title: 'Avg Precipitation',
        icon: Icons.water_drop_outlined,
        themeColor: _CT.precip,
        valueAccessor: (c) => c.avgPrecipitation,
        unit: 'mm',
      ),
    ];
    _selected = _rankings.first;
    _prepareList();
  }

  void _prepareList() {
    final filtered = widget.allCities
        .where((c) => _selected.valueAccessor(c) != 0.0)
        .toList();
    filtered.sort((a, b) {
      final va = _selected.valueAccessor(a);
      final vb = _selected.valueAccessor(b);
      return _sortDir == 0 ? vb.compareTo(va) : va.compareTo(vb);
    });
    setState(() => _list = filtered.take(30).toList());
  }

  @override
  Widget build(BuildContext context) {
    final topValue = _list.isNotEmpty
        ? _list.map((c) => _selected.valueAccessor(c).abs()).reduce(math.max)
        : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: _CT.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CT.divider),
      ),
      child: Column(
        children: [
          // ── 탭 토글 헤더
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _CT.divider)),
            ),
            child: Row(
              children: [
                ..._rankings.map((r) {
                  final active = r == _selected;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _selected = r; _prepareList(); }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active ? _CT.ink : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(r.icon, size: 15,
                                color: active ? Colors.white : _CT.inkLight),
                            const SizedBox(width: 6),
                            Text(r.title, style: TextStyle(
                              fontSize: 12,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                              color: active ? Colors.white : _CT.inkLight,
                            )),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() {
                    _sortDir = _sortDir == 0 ? 1 : 0;
                    _prepareList();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: _CT.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _CT.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _sortDir == 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            key: ValueKey(_sortDir),
                            size: 14,
                            color: _CT.inkMid,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sortDir == 0 ? 'High' : 'Low',
                          style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: _CT.inkMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 리스트
          SizedBox(
            height: 360,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _list.length,
              itemBuilder: (context, index) {
                final item = _list[index];
                final isVisited = widget.visitedNames.contains(item.name);
                final rank = index + 1;
                final value = _selected.valueAccessor(item);
                final barFrac = (value.abs() / topValue).clamp(0.0, 1.0).toDouble();
                final barColor = widget.useDefaultColor
                    ? _selected.themeColor
                    : (_continentColors[item.continent] ?? _selected.themeColor);
                final displayStr = '${value.toStringAsFixed(1)}${_selected.unit}';

                return _RankRow(
                  rank: rank, city: item,
                  value: displayStr, isVisited: isVisited,
                  barFraction: barFrac,
                  barColor: barColor,
                  accentColor: _selected.themeColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final City city;
  final String value;
  final bool isVisited;
  final double barFraction;
  final Color barColor;
  final Color accentColor;

  const _RankRow({
    required this.rank, required this.city, required this.value,
    required this.isVisited, required this.barFraction,
    required this.barColor, required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showExternalCityDetailsModal(context, city),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isVisited ? accentColor.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(
            color: isVisited ? accentColor : Colors.transparent,
            width: 2.5,
          )),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                rank <= 3 ? (rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉') : '$rank',
                style: TextStyle(
                  fontSize: rank <= 3 ? 16 : 12,
                  fontWeight: FontWeight.w700,
                  color: _CT.inkLight,
                ),
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
                        child: Text(city.name, style: TextStyle(
                          fontSize: 13,
                          fontWeight: isVisited ? FontWeight.w700 : FontWeight.w500,
                          color: _CT.ink,
                        ), overflow: TextOverflow.ellipsis),
                      ),
                      if (isVisited) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
                      ],
                      const SizedBox(width: 6),
                      Text(value, style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _CT.ink,
                      )),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: barFraction, minHeight: 3,
                      backgroundColor: _CT.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(_cityFlagEmoji(city), style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(city.country, style: const TextStyle(fontSize: 10, color: _CT.inkLight)),
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
// Collections 요약 바
// ====================================================================

class _ClimateSummaryBar extends StatelessWidget {
  final List<_ClimateGroup> groups;
  final Set<String> visitedNames;
  final int completed;

  const _ClimateSummaryBar({
    required this.groups, required this.visitedNames, required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final total = groups.length;
    final pct = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _CT.ink, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed of $total collections',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  completed == 0 ? 'No collections fully completed yet'
                      : completed == total ? 'All collections completed! 🎉'
                      : '${total - completed} remaining to complete',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                ),
                const SizedBox(height: 14),
                _SegBar(groups: groups, visitedNames: visitedNames),
              ],
            ),
          ),
          const SizedBox(width: 20),
          _ArcPct(value: pct),
        ],
      ),
    );
  }
}

class _SegBar extends StatelessWidget {
  final List<_ClimateGroup> groups;
  final Set<String> visitedNames;
  const _SegBar({required this.groups, required this.visitedNames});

  @override
  Widget build(BuildContext context) {
    final total = groups.fold<int>(0, (s, g) => s + g.cities.length);
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: groups.map((g) {
            final frac = g.cities.length / total;
            final vis = g.cities.where((c) => visitedNames.contains(c.name)).length;
            final visFrac = g.cities.isNotEmpty ? vis / g.cities.length : 0.0;
            return Expanded(
              flex: (frac * 1000).round(),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                child: Stack(children: [
                  Container(color: const Color(0xFF2E2E2E)),
                  FractionallySizedBox(widthFactor: visFrac, child: Container(color: g.color)),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ArcPct extends StatelessWidget {
  final double value;
  const _ArcPct({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68, height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(68, 68), painter: _ArcPainter(value: value)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${(value * 100).round()}', style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1,
              )),
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
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    const sw = 4.0;
    canvas.drawCircle(c, r, Paint()
      ..color = const Color(0xFF2E2E2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw);
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2, 2 * math.pi * value, false,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value;
}

// ====================================================================
// 그룹 데이터 모델
// ====================================================================

class _ClimateGroup {
  final String title;
  final String label;
  final IconData icon;
  final Color color;
  final List<City> cities;

  const _ClimateGroup({
    required this.title, required this.label,
    required this.icon, required this.color, required this.cities,
  });
}

// ====================================================================
// Collection 카드
// ====================================================================

class _ClimateCollectionCard extends StatefulWidget {
  final _ClimateGroup data;
  final Set<String> visitedNames;
  const _ClimateCollectionCard({required this.data, required this.visitedNames});

  @override
  State<_ClimateCollectionCard> createState() => _ClimateCollectionCardState();
}

class _ClimateCollectionCardState extends State<_ClimateCollectionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _rotateAnim, _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _rotateAnim = Tween(begin: 0.0, end: 0.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      _expanded ? _ctrl.forward() : _ctrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.data;
    final sorted = List<City>.from(g.cities)..sort((a, b) => a.name.compareTo(b.name));
    final total = sorted.length;
    final visited = sorted.where((c) => widget.visitedNames.contains(c.name)).length;
    final pct = total > 0 ? visited / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _CT.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CT.divider),
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
                      color: g.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(g.icon, size: 20, color: g.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.label, style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          letterSpacing: 1.5, color: g.color,
                        )),
                        const SizedBox(height: 2),
                        Text(g.title, style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: _CT.ink, letterSpacing: -0.2,
                        )),
                      ],
                    ),
                  ),
                  // 지도 버튼
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CityStatsMapScreen(
                        cities: sorted, title: g.title, markerColor: g.color,
                      ),
                    )),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _CT.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _CT.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.map_outlined, size: 14, color: _CT.inkMid),
                          SizedBox(width: 4),
                          Text('Map', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: _CT.inkMid,
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  RotationTransition(
                    turns: _rotateAnim,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 22, color: _CT.inkLight),
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
                    value: pct, minHeight: 5,
                    backgroundColor: _CT.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(g.color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Chip(label: 'Visited', value: '$visited', color: g.color),
                    const SizedBox(width: 8),
                    _Chip(label: 'Remaining', value: '${total - visited}', color: _CT.inkLight),
                    const Spacer(),
                    Text(
                      '${(pct * 100).round()}%',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: pct > 0 ? g.color : _CT.inkLight,
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
                  border: Border(top: BorderSide(color: _CT.divider)),
                ),
                child: Wrap(
                  spacing: 7, runSpacing: 7,
                  children: sorted.map((city) {
                    final isVisited = widget.visitedNames.contains(city.name);
                    return _CityChip(city: city, isVisited: isVisited, color: g.color);
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
  final String label, value;
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
          color: _CT.inkLight, letterSpacing: 0.3,
        )),
      ],
    );
  }
}

class _CityChip extends StatelessWidget {
  final City city;
  final bool isVisited;
  final Color color;
  const _CityChip({required this.city, required this.isVisited, required this.color});

  @override
  Widget build(BuildContext context) {
    final flag = _cityFlagEmoji(city);
    return GestureDetector(
      onTap: () => showExternalCityDetailsModal(context, city),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isVisited ? color : _CT.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isVisited ? color : _CT.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag.isNotEmpty) ...[
              Text(flag, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 5),
            ],
            Text(city.name, style: TextStyle(
              fontSize: 12,
              fontWeight: isVisited ? FontWeight.w700 : FontWeight.w500,
              color: isVisited ? Colors.white : _CT.inkMid,
              letterSpacing: 0.1,
            )),
          ],
        ),
      ),
    );
  }
}