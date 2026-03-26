// lib/screens/city_economy_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/screens/cities_screen.dart';

void _showCityModal(BuildContext context, City city) {
  final provider = Provider.of<CityProvider>(context, listen: false);
  final fullCity = provider.allCities.firstWhere(
        (c) => c.name == city.name && c.countryIsoA2.isNotEmpty,
    orElse: () => city,
  );
  showExternalCityDetailsModal(context, fullCity);
}

class RankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final String metricKey;
  final num Function(dynamic) valueAccessor;
  final String unit;

  const RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.metricKey,
    required this.valueAccessor,
    this.unit = '',
  });
}

class CityEconomyScreen extends StatefulWidget {
  const CityEconomyScreen({super.key});

  static final Map<String, Color> continentColors = {
    'Asia': Colors.pink.shade400,
    'Europe': Colors.amber.shade600,
    'Africa': Colors.brown.shade400,
    'North America': Colors.blue.shade400,
    'South America': Colors.green.shade500,
    'Oceania': Colors.purple.shade400,
  };

  @override
  State<CityEconomyScreen> createState() => _CityEconomyScreenState();
}

class _CityEconomyScreenState extends State<CityEconomyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CityProvider>(
        builder: (context, cityProvider, child) {
          if (cityProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CombinedRankingCard(cityProvider: cityProvider),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CombinedRankingCard extends StatefulWidget {
  final CityProvider cityProvider;

  const _CombinedRankingCard({required this.cityProvider});

  @override
  State<_CombinedRankingCard> createState() => _CombinedRankingCardState();
}

class _CombinedRankingCardState extends State<_CombinedRankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selectedRanking;

  int _gdpTypeSegment = 0;
  int _wealthTypeSegment = 0;

  String _selectedContinent = 'World';
  List<dynamic> _rankedList = [];

  final List<String> _continents = [
    'World',
    'Asia',
    'Europe',
    'Africa',
    'North America',
    'South America',
    'Oceania'
  ];

  @override
  void initState() {
    super.initState();
    _rankings = [
      RankingInfo(
          title: 'GDP Ranking',
          icon: Icons.monetization_on,
          themeColor: Colors.teal,
          metricKey: 'gdp',
          valueAccessor: (c) => c.gdpNominal,
          unit: '\$'),
      RankingInfo(
          title: 'Wealthiest',
          icon: Icons.diamond,
          themeColor: Colors.blue,
          metricKey: 'wealth',
          valueAccessor: (c) => c.millionaires),
      RankingInfo(
          title: 'Financial',
          icon: Icons.account_balance,
          themeColor: Colors.purple,
          metricKey: 'financial_index',
          valueAccessor: (c) => int.parse(c['financial_index']),
          unit: ''),
    ];
    _selectedRanking = _rankings.first;
    _prepareList();
  }

  void _prepareList() {
    dynamic listToRank;

    switch (_selectedRanking.metricKey) {
      case 'gdp':
        listToRank = widget.cityProvider.allCities
            .where((c) => c.gdpNominal != 0.0)
            .toList();
        if (_selectedContinent != 'World') {
          listToRank = (listToRank as List<City>)
              .where((c) => c.continent == _selectedContinent)
              .toList();
        }
        (listToRank as List<City>).sort((a, b) =>
            (_gdpTypeSegment == 0 ? b.gdpNominal : b.gdpPpp)
                .compareTo(_gdpTypeSegment == 0 ? a.gdpNominal : a.gdpPpp));
        break;
      case 'wealth':
        listToRank = widget.cityProvider.millionaireCities;
        if (_selectedContinent != 'World') {
          listToRank = (listToRank as List<City>)
              .where((c) => c.continent == _selectedContinent)
              .toList();
        }
        (listToRank as List<City>).sort((a, b) =>
            (_wealthTypeSegment == 0 ? b.millionaires : b.billionaires)
                .compareTo(_wealthTypeSegment == 0 ? a.millionaires : a.billionaires));
        break;
      case 'financial_index':
        listToRank = widget.cityProvider.financialIndexRawData;
        if (_selectedContinent != 'World') {
          listToRank = (listToRank as List<Map<String, dynamic>>)
              .where((c) => c['continent'] == _selectedContinent)
              .toList();
        }
        (listToRank as List<Map<String, dynamic>>).sort((a, b) =>
            int.parse(b['financial_index'])
                .compareTo(int.parse(a['financial_index'])));
        break;
      default:
        listToRank = [];
    }

    setState(() {
      _rankedList =
          listToRank.take(_selectedContinent == 'World' ? 100 : 30).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final compactFormatter = NumberFormat.compact(locale: 'en_US');
    final topValue = _rankedList.isNotEmpty
        ? _selectedRanking.valueAccessor(_rankedList.first)
        : 1;
    final useDefaultColor = widget.cityProvider.useDefaultCityRankingBarColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8E8E4))),
            ),
            child: Column(
              children: [
                // ── 메트릭 탭 (GDP / Wealthiest / Financial)
                Row(
                  children: _rankings.map((r) {
                    final active = r == _selectedRanking;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() { _selectedRanking = r; _prepareList(); }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF141414) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(r.icon, size: 15, color: active ? Colors.white : const Color(0xFFAAAAAA)),
                            const SizedBox(width: 6),
                            Text(r.title, style: TextStyle(
                              fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                              color: active ? Colors.white : const Color(0xFFAAAAAA),
                            )),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // ── GDP 서브토글
                if (_selectedRanking.metricKey == 'gdp') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [['Nominal', 0], ['PPP', 1]].map((e) {
                      final active = _gdpTypeSegment == e[1];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() { _gdpTypeSegment = e[1] as int; _prepareList(); }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF141414) : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: active ? const Color(0xFF141414) : const Color(0xFFE8E8E4)),
                            ),
                            child: Text(e[0] as String, textAlign: TextAlign.center, style: TextStyle(
                              fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                              color: active ? Colors.white : const Color(0xFFAAAAAA),
                            )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                // ── Wealth 서브토글
                if (_selectedRanking.metricKey == 'wealth') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [['Millionaires', 0], ['Billionaires', 1]].map((e) {
                      final active = _wealthTypeSegment == e[1];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() { _wealthTypeSegment = e[1] as int; _prepareList(); }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF141414) : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: active ? const Color(0xFF141414) : const Color(0xFFE8E8E4)),
                            ),
                            child: Text(e[0] as String, textAlign: TextAlign.center, style: TextStyle(
                              fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                              color: active ? Colors.white : const Color(0xFFAAAAAA),
                            )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                // ── 대륙 드롭다운
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE8E8E4)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedContinent,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF5C5C5C)),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF141414), fontWeight: FontWeight.w600),
                        items: _continents.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                        onChanged: (v) { if (v != null) setState(() { _selectedContinent = v; _prepareList(); }); },
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          SizedBox(
            height: 600,
            child: _rankedList.isEmpty
                ? const Center(child: Text('No data to display.'))
                : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _rankedList.length,
              itemBuilder: (context, index) {
                final item = _rankedList[index];
                final rank = index + 1;

                final String name = item is City ? item.name : item['name'];
                final String continent =
                item is City ? item.continent : item['continent'];

                num value;
                if (_selectedRanking.metricKey == 'gdp') {
                  value = _gdpTypeSegment == 0
                      ? (item as City).gdpNominal
                      : (item as City).gdpPpp;
                } else if (_selectedRanking.metricKey == 'wealth') {
                  value = _wealthTypeSegment == 0
                      ? (item as City).millionaires
                      : (item as City).billionaires;
                } else {
                  value = _selectedRanking.valueAccessor(item);
                }

                final isVisited =
                widget.cityProvider.visitedCities.contains(name);
                final barColor = useDefaultColor
                    ? _selectedRanking.themeColor
                    : (CityEconomyScreen.continentColors[continent] ??
                    _selectedRanking.themeColor);

                return GestureDetector(
                  onTap: item is City ? () => _showCityModal(context, item) : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isVisited ? _selectedRanking.themeColor.withOpacity(0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(
                        color: isVisited ? _selectedRanking.themeColor : Colors.transparent,
                        width: 2.5,
                      )),
                    ),
                    child: Row(children: [
                      SizedBox(width: 28, child: Text(
                        rank <= 3 ? (rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉') : '$rank',
                        style: TextStyle(fontSize: rank <= 3 ? 16 : 12, fontWeight: FontWeight.w700, color: const Color(0xFFAAAAAA)),
                        textAlign: TextAlign.center,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(name, style: TextStyle(
                            fontSize: 13, fontWeight: isVisited ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF141414),
                          ), overflow: TextOverflow.ellipsis)),
                          if (isVisited) ...[const SizedBox(width: 4), Icon(Icons.check_circle_rounded, size: 14, color: _selectedRanking.themeColor)],
                          const SizedBox(width: 6),
                          Text('${_selectedRanking.unit}${compactFormatter.format(value)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF141414))),
                        ]),
                        const SizedBox(height: 5),
                        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
                          value: topValue == 0 ? 0 : (value / topValue).clamp(0.0, 1.0).toDouble(),
                          minHeight: 3,
                          backgroundColor: const Color(0xFFE8E8E4),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        )),
                        const SizedBox(height: 3),
                        Text(item is City ? (item as City).country : ((item as Map<String,dynamic>)['country'] ?? ''),
                            style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                      ])),
                    ]),
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