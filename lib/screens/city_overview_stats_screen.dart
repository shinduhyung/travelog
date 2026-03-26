// lib/screens/city_overview_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

import 'package:jidoapp/screens/populations_screen.dart';
import 'package:jidoapp/screens/city_economy_screen.dart';
import 'package:jidoapp/screens/cities_screen.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:country_flags/country_flags.dart';
import 'package:jidoapp/screens/city_tiers_screen.dart';

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

class RankingInfo {
  final String title;
  final IconData icon;
  final Color themeColor;
  final String metricKey;
  final String unit;

  const RankingInfo({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.metricKey,
    this.unit = '',
  });
}

final Map<String, Color> _continentColors = {
  'Asia': Colors.pink.shade200,
  'Europe': Colors.amber,
  'Africa': Colors.brown,
  'North America': Colors.blue.shade200,
  'South America': Colors.green,
  'Oceania': Colors.purple,
};

class CitiesInCountry {
  final String countryName;
  final List<City> cities;

  CitiesInCountry({required this.countryName, required this.cities});
}

class CityOverviewTabScreen extends StatefulWidget {
  const CityOverviewTabScreen({super.key});

  @override
  State<CityOverviewTabScreen> createState() => _CityOverviewTabScreenState();
}

class _CityOverviewTabScreenState extends State<CityOverviewTabScreen> {
  String _xAxisMetric = 'visitCount';
  String _yAxisMetric = 'totalDays';

  bool _xLogScale = false;
  bool _yLogScale = false;

  bool _includeHome = false;
  bool _includeLived = false;
  bool _includeTransfer = false;
  bool _includeLayover = true;

  List<City> _getFilteredCities(CityProvider cityProvider) {
    final List<City> result = [];
    final visitedCityNames = cityProvider.visitDetails.keys;

    for (String cityName in visitedCityNames) {
      final details = cityProvider.visitDetails[cityName];
      if (details == null) continue;

      final bool isHome = cityProvider.homeCityName == cityName;
      final bool hasLived = details.hasLived;
      final bool hasTransfer = details.visitDateRanges.any((r) => r.isTransfer);
      final bool hasLayover = details.visitDateRanges.any((r) => r.isLayover);
      final bool isNormalVisit = !isHome && !hasLived && !hasTransfer && !hasLayover;

      bool shouldInclude = false;
      if (isNormalVisit) shouldInclude = true;
      else if (_includeHome && isHome) shouldInclude = true;
      else if (_includeLived && hasLived) shouldInclude = true;
      else if (_includeTransfer && hasTransfer) shouldInclude = true;
      else if (_includeLayover && hasLayover) shouldInclude = true;

      if (!shouldInclude) continue;

      City? city = cityProvider.getCityDetail(cityName);

      if (city == null) {
        city = City(
          name: cityName,
          country: 'Unknown',
          countryIsoA2: '',
          continent: 'Unknown',
          population: 0,
          latitude: 0,
          longitude: 0,
          capitalStatus: CapitalStatus.none,
        );
      }
      result.add(city);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cityProvider = Provider.of<CityProvider>(context);
    final countryProvider = Provider.of<CountryProvider>(context);

    final filteredCities = _getFilteredCities(cityProvider);

    return _OverviewContent(
      provider: cityProvider,
      countryProvider: countryProvider,
      filteredCities: filteredCities,
      xAxisMetric: _xAxisMetric,
      yAxisMetric: _yAxisMetric,
      xLogScale: _xLogScale,
      yLogScale: _yLogScale,
      includeHome: _includeHome,
      includeLived: _includeLived,
      includeTransfer: _includeTransfer,
      includeLayover: _includeLayover,
      onXAxisChanged: (value) => setState(() => _xAxisMetric = value),
      onYAxisChanged: (value) => setState(() => _yAxisMetric = value),
      onXLogScaleChanged: (value) => setState(() => _xLogScale = value),
      onYLogScaleChanged: (value) => setState(() => _yLogScale = value),
      onIncludeHomeChanged: (value) => setState(() => _includeHome = value),
      onIncludeLivedChanged: (value) => setState(() => _includeLived = value),
      onIncludeTransferChanged: (value) => setState(() => _includeTransfer = value),
      onIncludeLayoverChanged: (value) => setState(() => _includeLayover = value),
      onCityTap: (city) => _showCityModal(context, city),
    );
  }
}

class CityOverviewStatsScreen extends StatelessWidget {
  const CityOverviewStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const List<Tab> tabs = <Tab>[
      Tab(icon: Icon(Icons.insights), text: 'Overview'),
      Tab(icon: Icon(Icons.groups), text: 'Population'),
      Tab(icon: Icon(Icons.monetization_on), text: 'Economy'),
    ];

    final List<Widget> screens = <Widget>[
      const CityOverviewTabScreen(),
      const PopulationsScreen(),
      const CityEconomyScreen(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: const Color(0xFFF7F7F5),
          cardColor: Colors.white,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F7F5),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: const Color(0xFFE8E8E4)),
              ),
              title: TabBar(
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Population'),
                  Tab(text: 'Economy'),
                ],
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.5),
                labelColor: const Color(0xFF141414),
                unselectedLabelColor: const Color(0xFFAAAAAA),
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: Color(0xFF141414), width: 2),
                  insets: EdgeInsets.symmetric(horizontal: 24),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
              ),
            ),
          ),
          body: TabBarView(children: screens),
        ),
      ),
    );
  }
}

class _OverviewContent extends StatefulWidget {
  final CityProvider provider;
  final CountryProvider countryProvider;
  final List<City> filteredCities;
  final String xAxisMetric;
  final String yAxisMetric;
  final bool xLogScale;
  final bool yLogScale;
  final bool includeHome;
  final bool includeLived;
  final bool includeTransfer;
  final bool includeLayover;
  final ValueChanged<String> onXAxisChanged;
  final ValueChanged<String> onYAxisChanged;
  final ValueChanged<bool> onXLogScaleChanged;
  final ValueChanged<bool> onYLogScaleChanged;
  final ValueChanged<bool> onIncludeHomeChanged;
  final ValueChanged<bool> onIncludeLivedChanged;
  final ValueChanged<bool> onIncludeTransferChanged;
  final ValueChanged<bool> onIncludeLayoverChanged;
  final ValueChanged<City> onCityTap;

  const _OverviewContent({
    super.key,
    required this.provider,
    required this.countryProvider,
    required this.filteredCities,
    required this.xAxisMetric,
    required this.yAxisMetric,
    required this.xLogScale,
    required this.yLogScale,
    required this.includeHome,
    required this.includeLived,
    required this.includeTransfer,
    required this.includeLayover,
    required this.onXAxisChanged,
    required this.onYAxisChanged,
    required this.onXLogScaleChanged,
    required this.onYLogScaleChanged,
    required this.onIncludeHomeChanged,
    required this.onIncludeLivedChanged,
    required this.onIncludeTransferChanged,
    required this.onIncludeLayoverChanged,
    required this.onCityTap,
  });

  @override
  State<_OverviewContent> createState() => _OverviewContentState();
}

class _OverviewContentState extends State<_OverviewContent> {
  City? _selectedCity;

  String _getCorrectIsoA2(String rawCode) {
    final code = rawCode.toUpperCase();
    if (code.length == 3) {
      return widget.countryProvider.isoA2ToIsoA3Map.entries
          .firstWhereOrNull((e) => e.value == code)?.key ?? code;
    }
    return code;
  }

  Widget _buildFlag(String countryCode, {double size = 20}) {
    final isoA2 = _getCorrectIsoA2(countryCode);
    if (isoA2.isEmpty) {
      return Icon(Icons.flag_outlined, size: size, color: Colors.grey);
    }
    return SizedBox(
      width: size,
      height: size * 0.75,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CountryFlag.fromCountryCode(isoA2),
      ),
    );
  }

  String _formatNumber(double val) {
    if (val == 0) return '0';
    if (val >= 1000000000) {
      return '${(val / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}b';
    }
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1).replaceAll('.0', '')}m';
    }
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    }
    return val.toInt().toString();
  }

  List<CitiesInCountry> _groupCitiesByCountry(List<City> cities, CityProvider cityProvider, CountryProvider countryProvider) {
    final Map<String, CitiesInCountry> countryGroups = {};

    for (var city in cities) {
      final isoA2 = _getCorrectIsoA2(city.countryIsoA2);
      final country = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2 == isoA2);
      final countryName = country?.name ?? city.country;

      String groupName = countryName;

      if (countryName == 'Unknown') {
        groupName = isoA2.isNotEmpty ? "Unknown ($isoA2)" : "Unknown (N/A)";
      } else {
        groupName = countryName;
      }

      if (!countryGroups.containsKey(groupName)) {
        countryGroups[groupName] = CitiesInCountry(countryName: groupName, cities: []);
      }

      countryGroups[groupName]!.cities.add(city);
    }

    final sortedGroups = countryGroups.values.toList()
      ..sort((a, b) => a.countryName.compareTo(b.countryName));

    for (var group in sortedGroups) {
      group.cities.sort((a, b) => a.name.compareTo(b.name));
    }

    return sortedGroups;
  }

  Widget _buildCitiesListCard(BuildContext context) {
    final groupedCities = _groupCitiesByCountry(widget.filteredCities, widget.provider, widget.countryProvider);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 20),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: const Text(
            'Visited Cities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.filteredCities.isEmpty
                    ? const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No cities selected by current filters.'),
                    ),
                  )
                ]
                    : groupedCities.map((cbc) {
                  if (cbc.cities.isEmpty) return const SizedBox.shrink();
                  return _buildCountryCityGroup(context, cbc);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryCityGroup(BuildContext context, CitiesInCountry citiesInCountry) {
    final firstCity = citiesInCountry.cities.first;
    final isoA2 = _getCorrectIsoA2(firstCity.countryIsoA2);

    Color themeColor = const Color(0xFFE91E63);

    if (isoA2.isNotEmpty) {
      final country = widget.countryProvider.allCountries.firstWhereOrNull(
            (c) => c.isoA2 == isoA2,
      );
      if (country != null && country.themeColor != null) {
        themeColor = country.themeColor!;
      }
    }

    final cityCount = citiesInCountry.cities.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFlag(isoA2, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        citiesInCountry.countryName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '$cityCount ${cityCount == 1 ? 'city' : 'cities'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: citiesInCountry.cities.map((city) {
                CityVisitDetail? detail = widget.provider.visitDetails[city.name];
                if (detail == null) {
                  final cleanName = city.name.replaceFirst(RegExp(r'\(\d+\)$'), '');
                  detail = widget.provider.visitDetails[cleanName];
                }

                if (detail == null) return const SizedBox.shrink();
                return _buildCityItem(context, detail, city, themeColor);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityItem(BuildContext context, CityVisitDetail cityDetail, City cityModel, Color themeColor) {
    final displayCityName = cityDetail.name.split('|').first.trim().replaceAll(RegExp(r'\s*\(.*\)$'), '').trim();
    final visitCount = cityDetail.visitCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => widget.onCityTap(cityModel),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: themeColor.withOpacity(0.2), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: themeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        displayCityName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$visitCount ${visitCount == 1 ? 'visit' : 'visits'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (cityDetail.rating > 0)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        cityDetail.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade700, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${cityDetail.totalDurationInDays()} days',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntegratedChartCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text('Data Explorer', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAxisSelectors(context),
                const SizedBox(height: 12),
                _buildFilterSwitches(context),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildScatterChart(context, widget.provider, widget.filteredCities),
                const SizedBox(height: 36),
                _buildLegend(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final continents = [
      'Asia',
      'Europe',
      'Africa',
      'North America',
      'South America',
      'Oceania'
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: continents.map((continent) {
        final color = _continentColors[continent] ?? Colors.grey;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(continent, style: const TextStyle(fontSize: 11, color: Colors.black87)),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 6,
            shadowColor: Colors.amber.withOpacity(0.3),
            margin: const EdgeInsets.only(bottom: 20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.shade50,
                    Colors.white,
                    Colors.amber.shade50,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Image.asset(
                            'assets/icons/city.png',
                            width: 32,
                            height: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Cities Visited",
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${widget.filteredCities.length}",
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Cities by Continent",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._buildContinentProgressBars(widget.filteredCities),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          _buildCitiesListCard(context),

          const SizedBox(height: 12),
          // 🚨 순서 변경: Ranking → Rating Tiers → Chart
          _CityOverviewRankingCard(
            cities: widget.filteredCities,
            provider: widget.provider,
            countryProvider: widget.countryProvider,
            includeHome: widget.includeHome,
            includeLived: widget.includeLived,
            includeTransfer: widget.includeTransfer,
            includeLayover: widget.includeLayover,
            onIncludeHomeChanged: widget.onIncludeHomeChanged,
            onIncludeLivedChanged: widget.onIncludeLivedChanged,
            onIncludeTransferChanged: widget.onIncludeTransferChanged,
            onIncludeLayoverChanged: widget.onIncludeLayoverChanged,
          ),
          const SizedBox(height: 24),
          _CityRatingTierCard(
            cities: widget.filteredCities,
            provider: widget.provider,
            countryProvider: widget.countryProvider,
          ),
          const SizedBox(height: 24),
          _buildIntegratedChartCard(context),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  List<Widget> _buildContinentProgressBars(List<City> cities) {
    final List<Map<String, Object>> continentsData = [
      {'name': 'Asia', 'fullName': 'Asia', 'asset': 'assets/icons/asia.png', 'color': Colors.pink.shade200},
      {'name': 'Europe', 'fullName': 'Europe', 'asset': 'assets/icons/europe.png', 'color': Colors.amber},
      {'name': 'Africa', 'fullName': 'Africa', 'asset': 'assets/icons/africa.png', 'color': Colors.brown},
      {'name': 'N. America', 'fullName': 'North America', 'asset': 'assets/icons/n_america.png', 'color': Colors.blue.shade200},
      {'name': 'S. America', 'fullName': 'South America', 'asset': 'assets/icons/s_america.png', 'color': Colors.green},
      {'name': 'Oceania', 'fullName': 'Oceania', 'asset': 'assets/icons/oceania.png', 'color': Colors.purple},
    ];

    final int totalVisitedCount = cities.length;
    final Map<String, int> cityContinentCounts = {
      'Asia': 0, 'Europe': 0, 'Africa': 0, 'North America': 0, 'South America': 0, 'Oceania': 0
    };

    for (var city in cities) {
      if (cityContinentCounts.containsKey(city.continent)) {
        cityContinentCounts[city.continent] = (cityContinentCounts[city.continent] ?? 0) + 1;
      }
    }

    continentsData.sort((a, b) {
      final countA = cityContinentCounts[a['fullName']] as int? ?? 0;
      final countB = cityContinentCounts[b['fullName']] as int? ?? 0;
      return countB.compareTo(countA);
    });

    return continentsData.map((data) {
      final fullName = data['fullName'] as String;
      final name = data['name'] as String;
      final asset = data['asset'] as String;
      final color = data['color'] as Color;
      final count = cityContinentCounts[fullName] ?? 0;
      final percentage = totalVisitedCount > 0
          ? (count / totalVisitedCount * 100)
          : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    asset,
                    width: 20,
                    height: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Text(
                  "$count (${percentage.toStringAsFixed(1)}%)",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: totalVisitedCount > 0
                      ? count / totalVisitedCount
                      : 0,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          color.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildAxisSelectors(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('X', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    borderRadius: BorderRadius.circular(24),
                    value: widget.xAxisMetric,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Colors.black),
                    items: const [
                      DropdownMenuItem(value: 'visitCount', child: Text('Visit Count')),
                      DropdownMenuItem(value: 'totalDays', child: Text('Total Days')),
                      DropdownMenuItem(value: 'rating', child: Text('Rating')),
                      DropdownMenuItem(value: 'population', child: Text('Population')),
                    ],
                    onChanged: (value) {
                      if (value != null) widget.onXAxisChanged(value);
                    },
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Log', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 24,
                    width: 32,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch(
                        value: widget.xLogScale,
                        onChanged: widget.onXLogScaleChanged,
                        activeColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('Y', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    borderRadius: BorderRadius.circular(24),
                    value: widget.yAxisMetric,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 13, color: Colors.black),
                    items: const [
                      DropdownMenuItem(value: 'visitCount', child: Text('Visit Count')),
                      DropdownMenuItem(value: 'totalDays', child: Text('Total Days')),
                      DropdownMenuItem(value: 'rating', child: Text('Rating')),
                      DropdownMenuItem(value: 'population', child: Text('Population')),
                    ],
                    onChanged: (value) {
                      if (value != null) widget.onYAxisChanged(value);
                    },
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Log', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 24,
                    width: 32,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch(
                        value: widget.yLogScale,
                        onChanged: widget.onYLogScaleChanged,
                        activeColor: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSwitches(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(context, 'Home', widget.includeHome, widget.onIncludeHomeChanged),
        _buildFilterChip(context, 'Lived', widget.includeLived, widget.onIncludeLivedChanged),
        _buildFilterChip(context, 'Transfer', widget.includeTransfer, widget.onIncludeTransferChanged),
        _buildFilterChip(context, 'Layover', widget.includeLayover, widget.onIncludeLayoverChanged),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: value,
      onSelected: onChanged,
      showCheckmark: false,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: value ? Theme.of(context).primaryColor : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildScatterChart(BuildContext context, CityProvider provider, List<City> filteredCities) {
    if (filteredCities.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const Text('No cities to display.', style: TextStyle(color: Colors.grey)),
      );
    }

    final List<ScatterSpot> spots = [];
    final Map<int, City> spotIndexToCity = {};

    for (int i = 0; i < filteredCities.length; i++) {
      final city = filteredCities[i];

      CityVisitDetail? details = provider.visitDetails[city.name];
      if (details == null) {
        final cleanName = city.name.replaceFirst(RegExp(r'\(\d+\)$'), '');
        details = provider.visitDetails[cleanName];
      }

      if (details == null) continue;

      final rawX = _getMetricValue(city, details, widget.xAxisMetric);
      final rawY = _getMetricValue(city, details, widget.yAxisMetric);
      if (rawX == null || rawY == null) continue;

      final xValue = widget.xLogScale ? (rawX > 0 ? log(rawX) / ln10 : 0.0) : rawX;
      final yValue = widget.yLogScale ? (rawY > 0 ? log(rawY) / ln10 : 0.0) : rawY;

      final color = _continentColors[city.continent] ?? Colors.grey;

      spots.add(ScatterSpot(
        xValue,
        yValue,
        dotPainter: FlDotCirclePainter(color: color, radius: 3.5),
      ));
      spotIndexToCity[spots.length - 1] = city;
    }

    if (spots.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const Text('No data available for selected metrics', style: TextStyle(color: Colors.grey)),
      );
    }

    final xValues = spots.map((e) => e.x).toList();
    final yValues = spots.map((e) => e.y).toList();
    final maxXValue = xValues.isEmpty ? 0.0 : xValues.reduce(max);
    final maxYValue = yValues.isEmpty ? 0.0 : yValues.reduce(max);

    final finalMaxX = maxXValue == 0 ? (widget.xLogScale ? 1.0 : 10.0) : (maxXValue * 1.1);
    final finalMaxY = maxYValue == 0 ? (widget.yLogScale ? 1.0 : 10.0) : (maxYValue * 1.1);

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: ScatterChart(
            ScatterChartData(
              scatterSpots: spots,
              minX: 0,
              maxX: finalMaxX,
              minY: 0,
              maxY: finalMaxY,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    axisNameWidget: Text(widget.yAxisMetric, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max) return const SizedBox.shrink();
                          if (value % 1 != 0) return const SizedBox.shrink();
                          double original = widget.yLogScale ? pow(10, value).toDouble() : value;
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(_formatNumber(original), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          );
                        })),
                bottomTitles: AxisTitles(
                    axisNameWidget: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(widget.xAxisMetric, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    ),
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max) return const SizedBox.shrink();
                          if (value % 1 != 0) return const SizedBox.shrink();
                          double original = widget.xLogScale ? pow(10, value).toDouble() : value;
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(_formatNumber(original), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          );
                        })),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                horizontalInterval: widget.yLogScale ? 1.0 : (finalMaxY / 5).clamp(1.0, double.infinity),
                verticalInterval: widget.xLogScale ? 1.0 : (finalMaxX / 5).clamp(1.0, double.infinity),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Colors.grey.shade300, width: 1),
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  top: BorderSide.none,
                  right: BorderSide.none,
                ),
              ),
              scatterTouchData: ScatterTouchData(
                enabled: true,
                touchCallback: (FlTouchEvent event, ScatterTouchResponse? response) {
                  if (response != null && response.touchedSpot != null && event is FlTapUpEvent) {
                    final spot = response.touchedSpot!;
                    final city = spotIndexToCity[spots.indexOf(spot.spot)];
                    if (city != null) {
                      setState(() {
                        _selectedCity = city;
                      });
                    }
                  }
                },
                touchTooltipData: ScatterTouchTooltipData(
                  getTooltipItems: (ScatterSpot spot) {
                    final city = spotIndexToCity[spots.indexOf(spot)];
                    if (city == null) return ScatterTooltipItem('', textStyle: const TextStyle());
                    return ScatterTooltipItem(city.name, textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                  },
                ),
              ),
            ),
          ),
        ),
        if (_selectedCity != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
            ),
            child: Row(
              children: [
                _buildFlag(_selectedCity!.countryIsoA2, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selected City', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(_selectedCity!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showExternalCityDetailsModal(context, _selectedCity!);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.menu_book, color: Theme.of(context).primaryColor, size: 24),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCity = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close, size: 20, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  double? _getMetricValue(City city, CityVisitDetail details, String metric) {
    switch (metric) {
      case 'visitCount':
        return details.visitCount.toDouble();
      case 'totalDays':
        return details.totalDurationInDays().toDouble();
      case 'rating':
        return details.rating;
      case 'population':
        return city.population.toDouble();
      default:
        return null;
    }
  }
}

class _CityOverviewRankingCard extends StatefulWidget {
  final List<City> cities;
  final CityProvider provider;
  final CountryProvider countryProvider;
  final bool includeHome, includeLived, includeTransfer, includeLayover;
  final Function(bool) onIncludeHomeChanged, onIncludeLivedChanged, onIncludeTransferChanged, onIncludeLayoverChanged;

  const _CityOverviewRankingCard({
    required this.cities, required this.provider, required this.countryProvider,
    required this.includeHome, required this.includeLived, required this.includeTransfer, required this.includeLayover,
    required this.onIncludeHomeChanged, required this.onIncludeLivedChanged, required this.onIncludeTransferChanged, required this.onIncludeLayoverChanged,
  });

  @override
  State<_CityOverviewRankingCard> createState() => _CityOverviewRankingCardState();
}

class _CityOverviewRankingCardState extends State<_CityOverviewRankingCard> {
  late final List<RankingInfo> _rankings;
  late RankingInfo _selectedRanking;

  String _selectedContinent = 'World';
  String _selectedCountry = 'All';
  List<MapEntry<City, double>> _rankedList = [];
  List<String> _continents = ['World'];
  List<String> _countries = ['All'];

  @override
  void initState() {
    super.initState();
    _rankings = const [
      RankingInfo(title: 'Visit Count', icon: Icons.pin_drop, themeColor: Colors.amber, metricKey: 'visitCount'),
      RankingInfo(title: 'Total Days', icon: Icons.calendar_today, themeColor: Colors.amber, metricKey: 'totalDays', unit: ' days'),
    ];
    _selectedRanking = _rankings.first;

    _updateFilterLists();
    _prepareList();
  }

  @override
  void didUpdateWidget(covariant _CityOverviewRankingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.cities, oldWidget.cities)) {
      _updateFilterLists();
      _prepareList();
    }
  }

  void _updateFilterLists() {
    _continents = ['World', ...widget.cities.map((c) => c.continent).where((c) => c.isNotEmpty).toSet().toList()..sort()];
    _updateCountryList();
  }

  void _updateCountryList() {
    if (_selectedContinent == 'World') {
      _countries = ['All', ...widget.cities.map((c) => c.country).toSet().toList()..sort()];
    } else {
      _countries = ['All', ...widget.cities.where((c) => c.continent == _selectedContinent).map((c) => c.country).toSet().toList()..sort()];
    }
    if (!_countries.contains(_selectedCountry)) {
      _selectedCountry = 'All';
    }
  }

  void _prepareList() {
    List<City> listToRank = List.from(widget.cities);

    if (_selectedContinent != 'World') {
      listToRank = listToRank.where((c) => c.continent == _selectedContinent).toList();
    }
    if (_selectedCountry != 'All') {
      listToRank = listToRank.where((c) => c.country == _selectedCountry).toList();
    }

    List<MapEntry<City, double>> rankedWithValues = [];
    for (var city in listToRank) {
      CityVisitDetail? details = widget.provider.visitDetails[city.name];
      if (details == null) {
        final cleanName = city.name.replaceFirst(RegExp(r'\(\d+\)$'), '');
        details = widget.provider.visitDetails[cleanName];
      }

      if (details == null) continue;

      double value = 0;
      switch (_selectedRanking.metricKey) {
        case 'visitCount': value = details.visitCount.toDouble(); break;
        case 'totalDays': value = details.totalDurationInDays().toDouble(); break;
      }
      if (value > 0) {
        rankedWithValues.add(MapEntry(city, value));
      }
    }

    rankedWithValues.sort((a, b) => b.value.compareTo(a.value));

    if (mounted) setState(() => _rankedList = rankedWithValues);
  }

  String _getCorrectIsoA2(String rawCode) {
    final code = rawCode.toUpperCase();
    if (code.length == 3) {
      return widget.countryProvider.isoA2ToIsoA3Map.entries
          .firstWhereOrNull((e) => e.value == code)?.key ?? code;
    }
    return code;
  }

  Widget _buildFilterChip(String label, bool value, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: value,
      onSelected: (newValue) => onChanged(newValue),
      showCheckmark: false,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.25),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildFlag(String countryCode, {double size = 18}) {
    final isoA2 = _getCorrectIsoA2(countryCode);
    if (isoA2.isEmpty) {
      return Icon(Icons.flag_outlined, size: size, color: Colors.grey);
    }
    return SizedBox(
      width: size,
      height: size * 0.75,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CountryFlag.fromCountryCode(isoA2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final topValue = _rankedList.isNotEmpty ? _rankedList.first.value : 1.0;
    final rankingThemeColor = _selectedRanking.themeColor;

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
                // ── 메트릭 탭 (Visit Count / Total Days)
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
                              fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                              color: active ? Colors.white : const Color(0xFFAAAAAA),
                            )),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                // ── 대륙 + 국가 드롭다운
                Row(children: [
                  Expanded(
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE8E8E4)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedContinent,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF5C5C5C)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF141414), fontWeight: FontWeight.w600),
                          items: _continents.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                          onChanged: (v) { if (v != null) setState(() { _selectedContinent = v; _updateCountryList(); _prepareList(); }); },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE8E8E4)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedCountry,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF5C5C5C)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF141414), fontWeight: FontWeight.w600),
                          items: _countries.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                          onChanged: (v) { if (v != null) setState(() { _selectedCountry = v; _prepareList(); }); },
                        ),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                // ── Filter chips
                Wrap(
                  spacing: 6, alignment: WrapAlignment.center,
                  children: [
                    _buildFilterChip('Home', widget.includeHome, widget.onIncludeHomeChanged),
                    _buildFilterChip('Lived', widget.includeLived, widget.onIncludeLivedChanged),
                    _buildFilterChip('Transfer', widget.includeTransfer, widget.onIncludeTransferChanged),
                    _buildFilterChip('Layover', widget.includeLayover, widget.onIncludeLayoverChanged),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 350,
            child: _rankedList.isEmpty ? const Center(child: Text('No cities to display.')) : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _rankedList.length,
              itemBuilder: (context, index) {
                final entry = _rankedList[index];
                final city = entry.key;
                final value = entry.value;
                final rank = index + 1;

                final themeColor = _selectedRanking.themeColor;
                final barColor = _continentColors[city.continent] ?? themeColor;
                final topValue2 = _rankedList.isNotEmpty ? _rankedList.first.value : 1.0;
                final barFrac = topValue2 > 0 ? (value / topValue2).clamp(0.0, 1.0) : 0.0;

                return GestureDetector(
                  onTap: () => _showCityModal(context, city),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: themeColor, width: 2.5)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            rank <= 3 ? (rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉') : '$rank',
                            style: TextStyle(fontSize: rank <= 3 ? 16 : 12, fontWeight: FontWeight.w700, color: const Color(0xFFAAAAAA)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                _buildFlag(city.countryIsoA2),
                                const SizedBox(width: 6),
                                Expanded(child: Text(city.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF141414)), overflow: TextOverflow.ellipsis)),
                                Icon(Icons.check_circle_rounded, size: 14, color: themeColor),
                                const SizedBox(width: 6),
                                Text('${value.toInt()}${_selectedRanking.unit}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF141414))),
                              ]),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(value: barFrac, minHeight: 3, backgroundColor: const Color(0xFFE8E8E4), valueColor: AlwaysStoppedAnimation<Color>(barColor)),
                              ),
                              const SizedBox(height: 3),
                              Text(city.country, style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                            ],
                          ),
                        ),
                      ],
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

class _CityRatingTierCard extends StatelessWidget {
  final List<City> cities;
  final CityProvider provider;
  final CountryProvider countryProvider;

  const _CityRatingTierCard({required this.cities, required this.provider, required this.countryProvider});

  String _getCorrectIsoA2(String rawCode) {
    final code = rawCode.toUpperCase();
    if (code.length == 3) {
      return countryProvider.isoA2ToIsoA3Map.entries
          .firstWhereOrNull((e) => e.value == code)?.key ?? code;
    }
    return code;
  }

  Widget _buildFlag(String countryCode, {double size = 16}) {
    final isoA2 = _getCorrectIsoA2(countryCode);
    if (isoA2.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: size,
      height: size * 0.75,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: CountryFlag.fromCountryCode(isoA2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final Map<double, List<City>> citiesByRating = {};

    for (final city in cities) {
      CityVisitDetail? details = provider.visitDetails[city.name];
      if (details == null) {
        final cleanName = city.name.replaceFirst(RegExp(r'\(\d+\)$'), '');
        details = provider.visitDetails[cleanName];
      }

      if (details != null && details.rating > 0) {
        final rating = details.rating;
        citiesByRating.putIfAbsent(rating, () => []).add(city);
      }
    }

    final tiers = [5.0, 4.5, 4.0, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0, 0.5];
    final tierWidgets = <Widget>[];

    for (final tier in tiers) {
      final citiesInTier = citiesByRating[tier] ?? [];
      if (citiesInTier.isNotEmpty) {
        tierWidgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 65,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        const SizedBox(height: 4),
                        Text(tier.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade800)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: 6.0, runSpacing: 6.0,
                      children: citiesInTier.map((city) {
                        final chipColor = _continentColors[city.continent] ?? Theme.of(context).primaryColor;
                        return Chip(
                          avatar: _buildFlag(city.countryIsoA2),
                          label: Text(city.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: chipColor.withOpacity(0.1),
                          side: BorderSide.none,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text('Rating Tiers', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.amber,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    // 🚨 City Tiers Screen으로 이동
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CityTiersScreen()));
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: tierWidgets.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No cities with ratings to display.", style: TextStyle(color: Colors.grey))))
                : Column(children: tierWidgets),
          ),
        ],
      ),
    );
  }
}