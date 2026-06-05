import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/screens/capitals_screen.dart';
import 'package:jidoapp/screens/landmark_cities_screen.dart';
import 'package:jidoapp/screens/cities_screen.dart'
    hide showExternalCityDetailsModal;
import 'package:jidoapp/widgets/city_detail_modal.dart';
import 'package:collection/collection.dart';
import 'dart:math';
import 'package:country_flags/country_flags.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TopCitiesScreen extends StatefulWidget {
  const TopCitiesScreen({super.key});

  @override
  State<TopCitiesScreen> createState() => _TopCitiesScreenState();
}

class _TopCitiesScreenState extends State<TopCitiesScreen> {
  bool _isLargestMode = false;
  bool _isCompactGawcList = false;

  static final List<Map<String, Object>> continentsData = [
    {'name': 'Asia', 'fullName': 'Asia', 'asset': 'assets/icons/asia.png', 'color': Colors.pink.shade300},
    {'name': 'Europe', 'fullName': 'Europe', 'asset': 'assets/icons/europe.png', 'color': Colors.amber.shade700},
    {'name': 'Africa', 'fullName': 'Africa', 'asset': 'assets/icons/africa.png', 'color': Colors.brown.shade400},
    {'name': 'N. America', 'fullName': 'North America', 'asset': 'assets/icons/n_america.png', 'color': Colors.blue.shade400},
    {'name': 'S. America', 'fullName': 'South America', 'asset': 'assets/icons/s_america.png', 'color': Colors.green.shade600},
    {'name': 'Oceania', 'fullName': 'Oceania', 'asset': 'assets/icons/oceania.png', 'color': Colors.purple.shade400},
  ];

  Widget _buildCapitalStats(BuildContext context, CityProvider cityProvider, CountryProvider countryProvider) {
    final theme = Theme.of(context);

    final Color modeColor = _isLargestMode
        ? const Color(0xFF3F51B5)
        : theme.primaryColor;

    int total = 0;
    int visited = 0;
    Map<String, int> totalByContinent = {};
    Map<String, int> visitedByContinent = {};

    for (var data in continentsData) {
      String continent = data['fullName'] as String;
      totalByContinent[continent] = 0;
      visitedByContinent[continent] = 0;
    }

    final countries = countryProvider.allCountries;

    for (var country in countries) {
      if (!countryProvider.includeTerritories && country.isTerritory) continue;

      String continent = country.continent ?? '';
      String targetCityName = '';

      if (_isLargestMode) {
        targetCityName = cityProvider.getLargestCityName(country.name);
      }

      if (targetCityName.isEmpty) {
        final capitalCity = cityProvider.allCities.firstWhereOrNull(
                (c) {
              bool isIsoMatch = c.countryIsoA2.isNotEmpty &&
                  c.countryIsoA2.toUpperCase() == country.isoA2.toUpperCase();
              bool isNameMatch = isIsoMatch || (c.country == country.name);

              if (!isNameMatch) return false;

              bool isOfficialCapital = (c.capitalStatus == CapitalStatus.capital);
              bool isTerritoryCapital = (countryProvider.includeTerritories && c.capitalStatus == CapitalStatus.territory);

              return isOfficialCapital || isTerritoryCapital;
            }
        );
        targetCityName = capitalCity?.name ?? '';
      }

      if (targetCityName.isNotEmpty) {
        if (totalByContinent.containsKey(continent)) {
          total++;
          totalByContinent[continent] = (totalByContinent[continent] ?? 0) + 1;

          if (cityProvider.isVisited(targetCityName)) {
            visited++;
            visitedByContinent[continent] = (visitedByContinent[continent] ?? 0) + 1;
          }
        }
      }
    }

    final ratio = total > 0 ? visited / total : 0.0;
    final percentage = (ratio * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: modeColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bar_chart_rounded, color: modeColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Major Cities",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<bool>(
                    value: _isLargestMode,
                    borderRadius: BorderRadius.circular(20),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600, size: 20),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: false,
                        child: Text("Capital Cities"),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text("Largest Cities"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _isLargestMode = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$percentage%",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: modeColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visited $visited of $total',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CapitalsScreen(isLargestMode: _isLargestMode)),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: modeColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: modeColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "View Map",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.map_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(modeColor),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 24),

          GridView.count(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: continentsData.map((data) {
              final name = data['name'] as String;
              final asset = data['asset'] as String;
              final fullName = data['fullName'] as String;
              final color = data['color'] as Color;

              final cVisited = visitedByContinent[fullName] ?? 0;
              final cTotal = totalByContinent[fullName] ?? 0;
              final cPercent = cTotal == 0 ? 0.0 : cVisited / cTotal;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(asset, width: 16, height: 16, color: color),
                      const SizedBox(width: 6),
                      Text(
                          name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey.shade700
                          )
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(cPercent * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$cVisited / $cTotal',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: cPercent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.from(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.amber,
          backgroundColor: const Color(0xFFFAFAFA),
        ),
        useMaterial3: true,
      ).copyWith(
          scaffoldBackgroundColor: const Color(0xFFF9FAFB),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: IconThemeData(color: Color(0xFF111827)),
          )
      ),
      child: Scaffold(
        body: SafeArea(
          child: Consumer2<CityProvider, CountryProvider>(
            builder: (context, cityProvider, countryProvider, child) {
              if (cityProvider.isLoading || countryProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final allGaWCData = cityProvider.gawcCities.where((c) => c.gawcTier != 'N/A').toList();
              final visitedCityNames = cityProvider.visitedCities;

              final totalGawcCount = allGaWCData.length;
              final visitedGawcCount = visitedCityNames.where((n) => allGaWCData.any((c) => c.name == n)).length;
              final gawcProgress = totalGawcCount > 0 ? (visitedGawcCount / totalGawcCount).clamp(0.0, 1.0) : 0.0;
              const citiesColor = Color(0xFFF59E0B);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Global Top Cities 헤더 ---
                    Container(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.location_city_rounded,
                                        color: Colors.amber,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Global Top Cities',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111827),
                                          letterSpacing: -0.8,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 44),
                                  child: Text(
                                    'GaWC Global City Rankings',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isCompactGawcList
                                    ? Icons.grid_view_rounded
                                    : Icons.view_agenda_rounded,
                                color: Colors.amber,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isCompactGawcList = !_isCompactGawcList;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 진행도 바 (전체 너비)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Visited', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                              Text('$visitedGawcCount / $totalGawcCount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: gawcProgress,
                              minHeight: 16,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: const AlwaysStoppedAnimation<Color>(citiesColor),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _GaWCRankingList(
                      citiesToDisplay: allGaWCData,
                      visitedCityNames: visitedCityNames,
                      isCompactList: _isCompactGawcList,
                    ),

                    const SizedBox(height: 28),

                    _buildCapitalStats(context, cityProvider, countryProvider),

                    const SizedBox(height: 20),

                    // --- Iconic Cities 카드 ---
                    Consumer<LandmarksProvider>(
                      builder: (context, landmarksProvider, _) {
                        const iconicColor = Color(0xFF4A5568);
                        const completedColor = Color(0xFFD97706);
                        final totalCities = LandmarkCitiesScreen.citiesData.length;

                        final visitedCityCount = LandmarkCitiesScreen.citiesData
                            .where((c) => cityProvider.isVisited(c['city'] as String))
                            .length;

                        final completedCityCount = LandmarkCitiesScreen.citiesData.where((cityData) {
                          final landmarks = cityData['landmarks'] as List<String>;
                          return landmarks.every((l) => landmarksProvider.visitedLandmarks.contains(l));
                        }).length;

                        final visitedRatio = totalCities > 0 ? (visitedCityCount / totalCities).clamp(0.0, 1.0) : 0.0;
                        final completedRatio = totalCities > 0 ? (completedCityCount / totalCities).clamp(0.0, 1.0) : 0.0;

                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LandmarkCitiesScreen()),
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.08),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 헤더 행
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: iconicColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.location_city_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Iconic Cities',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF111827),
                                              letterSpacing: -0.5,
                                              height: 1.1,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            '40 cities · 7 landmarks each',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: iconicColor.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: iconicColor,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Divider(color: Colors.grey.shade100, height: 1),
                                const SizedBox(height: 14),
                                // Cities visited 바
                                _IconicStatBar(
                                  label: 'Cities visited',
                                  value: visitedCityCount,
                                  total: totalCities,
                                  ratio: visitedRatio,
                                  color: iconicColor,
                                ),
                                const SizedBox(height: 10),
                                // Fully completed 바
                                _IconicStatBar(
                                  label: 'Fully completed  7/7 ★',
                                  value: completedCityCount,
                                  total: totalCities,
                                  ratio: completedRatio,
                                  color: completedColor,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GaWCRankingList extends StatefulWidget {
  final List<City> citiesToDisplay;
  final Set<String> visitedCityNames;
  final bool isCompactList;

  const _GaWCRankingList({
    required this.citiesToDisplay,
    required this.visitedCityNames,
    this.isCompactList = false,
  });

  @override
  State<_GaWCRankingList> createState() => _GaWCRankingListState();
}

class _GaWCRankingListState extends State<_GaWCRankingList> {
  final Set<String> _expandedTiers = {};

  final Map<String, Color> _tierColors = {
    'Alpha++': const Color(0xFF8B0000), 'Alpha+': const Color(0xFFDC143C),
    'Alpha': const Color(0xFFFF4500), 'Alpha-': const Color(0xFFFF8C00),
    'Beta+': const Color(0xFFDAA520), 'Beta': const Color(0xFF6B8E23),
    'Beta-': const Color(0xFF006400), 'Gamma+': const Color(0xFF4682B4),
    'Gamma': const Color(0xFF4169E1), 'Gamma-': const Color(0xFF191970),
  };

  final List<String> _sortedTiers = [
    'Alpha++', 'Alpha+', 'Alpha', 'Alpha-', 'Beta+', 'Beta', 'Beta-', 'Gamma+', 'Gamma', 'Gamma-',
  ];

  void _toggleTierExpanded(String tierName) {
    setState(() {
      if (_expandedTiers.contains(tierName)) {
        _expandedTiers.remove(tierName);
      } else {
        _expandedTiers.add(tierName);
      }
    });
  }

  String _getCityImageUrl(String name) {
    final snake = name
        .toLowerCase()
        .replaceAll(RegExp(r"[''`]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/top_cities%2F$snake.png?alt=media';
  }

  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '';
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  Widget _buildCompactCityItem(BuildContext context, City city, bool isVisited, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVisited ? themeColor.withOpacity(0.5) : const Color(0xFFE5E7EB),
          width: isVisited ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isVisited
                ? themeColor.withOpacity(0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            _getFlagEmoji(city.countryIsoA2),
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),
                if (city.countryIsoA2.isNotEmpty)
                  Text(
                    city.country,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: isVisited ? null : () {
              context.read<CityProvider>().addVisitWithDetails(city.name);
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isVisited ? themeColor : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isVisited ? Icons.check_rounded : Icons.add_rounded,
                color: isVisited ? Colors.white : Colors.grey[500],
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countryProvider = Provider.of<CountryProvider>(context);

    final Map<String, List<City>> groupedByTier = {};
    for (var tier in _sortedTiers) {
      groupedByTier[tier] = [];
    }

    for (var city in widget.citiesToDisplay) {
      if (groupedByTier.containsKey(city.gawcTier)) {
        groupedByTier[city.gawcTier]!.add(city);
      }
    }

    groupedByTier.removeWhere((key, value) => value.isEmpty);
    final List<String> presentSortedTiers = _sortedTiers.where((tier) => groupedByTier.containsKey(tier)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: presentSortedTiers.map((tierName) {
        final citiesInTier = groupedByTier[tierName] ?? [];
        final total = citiesInTier.length;
        final visited = citiesInTier.where((c) => widget.visitedCityNames.contains(c.name)).length;
        final percentage = total > 0 ? (visited / total) : 0.0;
        final isExpanded = _expandedTiers.contains(tierName);
        final tierColor = _tierColors[tierName] ?? Colors.amber;

        List<City> sortedCities = List.from(citiesInTier)..sort((a, b) => a.name.compareTo(b.name));

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => _toggleTierExpanded(tierName),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tierName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: tierColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                                '$total Cities',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                )
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              '${(percentage * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: tierColor,
                                letterSpacing: -0.5,
                              )
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 6,
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 80 * percentage,
                                decoration: BoxDecoration(color: tierColor, borderRadius: BorderRadius.circular(3)),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: !isExpanded ? const SizedBox.shrink() : Column(
                  children: [
                    Divider(height: 1, indent: 20, endIndent: 20, color: Colors.grey.shade100),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: widget.isCompactList
                          ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedCities.length,
                        itemBuilder: (context, index) {
                          final city = sortedCities[index];
                          final isVisited = widget.visitedCityNames.contains(city.name);
                          final country = countryProvider.allCountries.firstWhereOrNull(
                                (c) => c.isoA2 == city.countryIsoA2,
                          );
                          final themeColor = country?.themeColor ?? const Color(0xFF14B8A6);
                          return _buildCompactCityItem(context, city, isVisited, themeColor);
                        },
                      )
                          : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.78,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 16
                        ),
                        itemCount: sortedCities.length,
                        itemBuilder: (context, index) {
                          final city = sortedCities[index];
                          final isVisited = widget.visitedCityNames.contains(city.name);

                          final country = countryProvider.allCountries.firstWhereOrNull(
                                (c) => c.isoA2 == city.countryIsoA2,
                          );
                          final themeColor = country?.themeColor ?? const Color(0xFF14B8A6);

                          // --- Photo Grid 모드 ---
                          return GestureDetector(
                            onTap: () => showExternalCityDetailsModal(context, city),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl: _getCityImageUrl(city.name),
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(color: const Color(0xFFF3F4F6)),
                                            errorWidget: (context, url, error) => Container(color: const Color(0xFFF3F4F6)),
                                          ),
                                          // 그라디언트 오버레이
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(0.15),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          // + / check 버튼
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: isVisited ? null : () {
                                                context.read<CityProvider>().addVisitWithDetails(city.name);
                                              },
                                              child: isVisited
                                                  ? Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: themeColor,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.15),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                              )
                                                  : Container(
                                                width: 32,
                                                height: 32,
                                                decoration: const BoxDecoration(
                                                  color: Colors.black38,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      _getFlagEmoji(city.countryIsoA2),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text(
                                          city.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF111827),
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _IconicStatBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final double ratio;
  final Color color;

  const _IconicStatBar({
    required this.label,
    required this.value,
    required this.total,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              '  $pct%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              Container(height: 6, color: Colors.grey[100]),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}