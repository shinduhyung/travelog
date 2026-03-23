// lib/screens/recommendations_screen.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:collection/collection.dart';

// Models
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';

// Providers
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/personality_provider.dart';

// Services & Screens
import 'package:jidoapp/services/travel_quantifier.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/screens/country_detail_screen.dart';

// [추가] 로딩 로고 위젯 임포트


class RecommendationMatch {
  final String name;
  final String countryCode;
  final double score;

  RecommendationMatch({
    required this.name,
    required this.countryCode,
    required this.score,
  });
}

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<RecommendationMatch> _landmarkMatches = [];
  List<RecommendationMatch> _countryMatches = [];
  List<RecommendationMatch> _cityMatches = [];
  bool _isDataLoaded = false;

  final Color primaryBlue = const Color(0xFF2563EB);
  final Color accentBlue = const Color(0xFFDBEAFE);
  final Color bgLight = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _calculateRecommendations();
    if (mounted) {
      setState(() {
        _isDataLoaded = true;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadPrototypes(String fileName) async {
    try {
      final String response = await rootBundle.loadString('assets/$fileName');
      final data = await json.decode(response);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<void> _calculateRecommendations() async {
    final personality = context.read<PersonalityProvider>();
    final countryProvider = context.read<CountryProvider>();
    final cityProvider = context.read<CityProvider>();
    final airlineProvider = context.read<AirlineProvider>();
    final airportProvider = context.read<AirportProvider>();
    final landmarkProvider = context.read<LandmarksProvider>();

    if (!personality.isCalculated) personality.calculateScores();
    final dnaScores = personality.finalScores;

    Map<String, double> personalityVector = {};
    dnaScores.forEach((key, v) {
      personalityVector[key] = ((v - 50.0) / 50.0).clamp(-1.0, 1.0);
    });

    final quantifier = TravelQuantifier(
      countryProvider: countryProvider,
      cityProvider: cityProvider,
      airlineProvider: airlineProvider,
      airportProvider: airportProvider,
    );
    final features = quantifier.quantify();

    Map<String, double> fullLandmarkMap = {
      'landmark_culture_nature': features.landmarkCultureNature,
      'landmark_ancient_modern': features.landmarkAncientModern,
      'landmark_urban_rural': features.landmarkUrbanRural,
      'landmark_adventure_relax': features.landmarkAdventureRelax,
      'landmark_art_science': features.landmarkSpiritualSecular,
      'landmark_spiritual_secular': features.landmarkSpiritualSecular,
      'landmark_crowd': features.landmarkCrowd,
      'landmark_budget_luxury': features.landmarkBudgetLuxury,
      'landmark_local_tourist': features.landmarkLocalTourist,
      'landmark_calm_nightlife': features.landmarkCalmNightlife,
    };

    Map<String, double> coreLandmarkMapForCity = {
      'landmark_urban_rural': features.landmarkUrbanRural,
      'landmark_ancient_modern': features.landmarkAncientModern,
      'landmark_crowd': features.landmarkCrowd,
      'landmark_budget_luxury': features.landmarkBudgetLuxury,
    };

    Map<String, double> landmarkRecommenderVector = {
      ...personalityVector,
      ...fullLandmarkMap,
    };

    Map<String, double> countryRecommenderVector = {
      ...personalityVector,
      'countryWealth': features.countryWealth,
      'countryType': features.countryType,
      'countryNightlife': features.countryNightlife,
      ...fullLandmarkMap,
    };

    Map<String, double> cityRecommenderVector = {
      ...personalityVector,
      'cityWealth': features.cityWealth,
      'cityType': features.cityType,
      'cityNightlife': features.cityNightlife,
      ...coreLandmarkMapForCity,
    };

    final landmarkData = await _loadPrototypes('landmark_type.json');
    final countryData = await _loadPrototypes('country_type.json');
    final cityData = await _loadPrototypes('city_type.json');

    final Map<String, int> popularityByA2 = {};
    for (var country in countryProvider.allCountries) {
      popularityByA2[country.isoA2] = country.countryPopularity;
    }

    final visitedLandmarks = landmarkProvider.visitedLandmarks;
    final visitedCountries = countryProvider.visitedCountries;
    final visitedCities = cityProvider.visitedCities;

    if (mounted) {
      setState(() {
        _landmarkMatches = _getMatches(landmarkData, landmarkRecommenderVector)
            .where((m) => !visitedLandmarks.contains(m.name))
            .take(5)
            .toList();

        _countryMatches = _getMatches(
            countryData,
            countryRecommenderVector,
            popularityMap: popularityByA2
        )
            .where((m) => !visitedCountries.contains(m.name))
            .take(5)
            .toList();

        _cityMatches = _getMatches(cityData, cityRecommenderVector)
            .where((m) => !visitedCities.contains(m.name))
            .take(5)
            .toList();
      });
    }
  }

  List<RecommendationMatch> _getMatches(
      List<Map<String, dynamic>> prototypes,
      Map<String, double> userVector,
      {Map<String, int>? popularityMap}
      ) {
    List<RecommendationMatch> matches = [];
    for (var proto in prototypes) {
      double distance = 0;
      double sumWeights = 0;
      Map<String, dynamic> pRaw = proto['P'];
      Map<String, dynamic> wRaw = proto['W'];

      wRaw.forEach((axis, weight) {
        if (userVector.containsKey(axis)) {
          double uVal = userVector[axis]!;
          double pVal = (pRaw[axis] as num?)?.toDouble() ?? 0.0;
          distance += (weight as num) * (uVal - pVal).abs();
          sumWeights += weight;
        }
      });

      if (sumWeights > 0) {
        // Base matching score calculation
        double score = 1.0 - (distance / (2.0 * sumWeights));

        // Applied New Dynamic Popularity Bias
        // Logic: 5 is default (0%). Each point diff is ±3%.

        // 1. Landmark Popularity (기존 로직)
        if (proto.containsKey('landmarkPopularity')) {
          int popVal = (proto['landmarkPopularity'] as num).toInt();
          double popModifier = (popVal - 5) * 0.03;
          score += popModifier;
        }

        // 2. Country Popularity (기존 로직)
        final String countryA2 = proto['countryCode'] ?? '';
        if (popularityMap != null && popularityMap.containsKey(countryA2)) {
          int countryPopVal = popularityMap[countryA2]!;
          double countryPopModifier = (countryPopVal - 5) * 0.03;
          score += countryPopModifier;
        }

        // 3. City Popularity (새로 추가된 부분)
        // city_type.json에 "popularity" 키가 있을 경우 반영
        if (proto.containsKey('popularity')) {
          int cityPopVal = (proto['popularity'] as num).toInt();
          double cityPopModifier = (cityPopVal - 5) * 0.03;
          score += cityPopModifier;
        }

        matches.add(RecommendationMatch(
          name: proto['name'],
          countryCode: countryA2,
          score: score.clamp(0.0, 1.0),
        ));
      }
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    // 데이터 로딩 중일 때 비행기 로고 애니메이션 표시
    if (!_isDataLoaded) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 48),
              _buildModernSection('Countries', Icons.public_outlined, _countryMatches, _onCountryTap),
              const SizedBox(height: 56),
              _buildModernSection('Cities', Icons.location_city_outlined, _cityMatches, _onCityTap),
              const SizedBox(height: 56),
              _buildModernSection('Landmarks', Icons.explore_outlined, _landmarkMatches, _onLandmarkTap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI recommendations',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSection(String title, IconData icon, List<RecommendationMatch> matches, Function(RecommendationMatch) onTap) {
    if (matches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              return _buildHorizontalCard(match, onTap);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalCard(RecommendationMatch match, Function(RecommendationMatch) onTap) {
    return GestureDetector(
      onTap: () => onTap(match),
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CountryFlag.fromCountryCode(match.countryCode),
                  ),
                ),
                Text(
                  '${(match.score * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onLandmarkTap(RecommendationMatch match) {
    final provider = context.read<LandmarksProvider>();
    final landmark = provider.allLandmarks.firstWhereOrNull((l) => l.name == match.name);
    if (landmark != null) _showLandmarkDetailsModal(context, landmark, primaryBlue);
  }

  void _onCountryTap(RecommendationMatch match) {
    final countryProvider = context.read<CountryProvider>();
    final country = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2 == match.countryCode);
    if (country != null) Navigator.push(context, MaterialPageRoute(builder: (context) => CountryDetailScreen(country: country)));
  }

  void _onCityTap(RecommendationMatch match) {
    _showCityDetailSheet(context, match.name, match.countryCode);
  }

  void _showCityDetailSheet(BuildContext context, String cityName, String countryCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<CityProvider>(
        builder: (context, provider, child) {
          final cityVisitDetail = provider.getCityVisitDetail(cityName) ??
              CityVisitDetail(name: cityName, arrivalDate: '', departureDate: '', duration: '');
          final countryProvider = context.read<CountryProvider>();
          final countryModel = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2 == countryCode);
          final cityModel = provider.allCities.firstWhereOrNull((c) => c.name == cityName);
          final themeColor = countryModel?.themeColor ?? primaryBlue;

          // 그라데이션을 사용하므로 글자색을 흰색으로 고정
          const headerTextColor = Colors.white;

          return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))
            ),
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Stack(
                      children: [
                        // 베이스 테마 컬러 그라데이션
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  themeColor,
                                  themeColor.withOpacity(0.9),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 다크 그라데이션 오버레이
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // 콘텐츠 영역
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold))
                                    ),
                                    if (countryModel != null)
                                      Container(
                                          width: 40,
                                          height: 28,
                                          decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: headerTextColor.withOpacity(0.3))
                                          ),
                                          child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: CountryFlag.fromCountryCode(countryModel.isoA2)
                                          )
                                      ),
                                  ]
                              ),
                              const SizedBox(height: 12),
                              Row(
                                  children: [
                                    Expanded(
                                        child: Text(
                                            cityName,
                                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: headerTextColor)
                                        )
                                    ),
                                    if (cityVisitDetail.visitDateRanges.isNotEmpty)
                                      const Icon(Icons.verified, color: headerTextColor, size: 28),
                                  ]
                              ),
                              Text(
                                  countryModel?.name ?? countryCode,
                                  style: TextStyle(fontSize: 16, color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.w500)
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('My Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 4),
                              RatingBar.builder(initialRating: cityVisitDetail.rating, allowHalfRating: true, itemCount: 5, itemSize: 24, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateCityVisitDetail(cityName, cityVisitDetail.copyWith(rating: rating))),
                            ]),
                            IconButton(icon: Icon(cityVisitDetail.isWishlisted ? Icons.favorite : Icons.favorite_border, color: cityVisitDetail.isWishlisted ? Colors.red : Colors.grey, size: 30), onPressed: () => provider.updateCityVisitDetail(cityName, cityVisitDetail.copyWith(isWishlisted: !cityVisitDetail.isWishlisted))),
                          ]),
                          const Divider(height: 40),
                          if (cityModel != null) ...[
                            _buildCityStatRow('Population', NumberFormat('#,###').format(cityModel.population), Icons.people_outline, themeColor),
                            const Divider(height: 40),
                          ],
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Visits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            TextButton.icon(icon: const Icon(Icons.add), label: const Text('Add'), onPressed: () {
                              final updated = cityVisitDetail.copyWith(visitDateRanges: [...cityVisitDetail.visitDateRanges, DateRange()]);
                              provider.updateCityVisitDetail(cityName, updated);
                            }),
                          ]),
                          const SizedBox(height: 8),
                          if (cityVisitDetail.visitDateRanges.isNotEmpty)
                            ...cityVisitDetail.visitDateRanges.asMap().entries.map((entry) => _RecommendationCityVisitCard(
                              key: ValueKey('${cityName}_visit_${entry.key}'),
                              range: entry.value,
                              onSave: (updated) => provider.updateCityDateRange(cityName, entry.key, updated),
                              onDelete: () => provider.removeCityDateRange(cityName, entry.key),
                            ))
                          else
                            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No visits recorded.'))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCityStatRow(String label, String value, IconData icon, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(children: [
        Icon(icon, size: 20, color: themeColor),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Consumer<LandmarksProvider>(
        builder: (context, provider, child) {
          final freshLandmark = provider.allLandmarks.firstWhereOrNull((l) => l.name == landmark.name) ?? landmark;
          final isVisited = provider.visitedLandmarks.contains(freshLandmark.name);
          final isWishlisted = provider.wishlistedLandmarks.contains(freshLandmark.name);
          final countryNames = provider.getCountryNames(freshLandmark.countriesIsoA3);
          final countryProvider = context.read<CountryProvider>();
          Color? themeColor;
          if (freshLandmark.countriesIsoA3.isNotEmpty) {
            final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == freshLandmark.countriesIsoA3.first);
            themeColor = c?.themeColor;
          }
          final finalColor = themeColor ?? fallbackThemeColor;

          // 그라데이션 오버레이 위이므로 텍스트 흰색으로 고정
          const headerTextColor = Colors.white;

          return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))
            ),
            child: FractionallySizedBox(
              heightFactor: 0.85,
              child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Stack(
                          children: [
                            // 베이스 테마 컬러 그라데이션
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      finalColor,
                                      finalColor.withOpacity(0.9),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 다크 그라데이션 오버레이
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 콘텐츠 영역
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(sheetContext),
                                              child: const Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))
                                          ),
                                          ElevatedButton(
                                              onPressed: () => Navigator.pop(sheetContext),
                                              style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                                              child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: finalColor))
                                          ),
                                        ]
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                        children: [
                                          Expanded(
                                              child: Text(
                                                  freshLandmark.name,
                                                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor)
                                              )
                                          ),
                                          if (isVisited)
                                            const Icon(Icons.check_circle, color: headerTextColor, size: 24)
                                        ]
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                              child: Text(
                                                  countryNames,
                                                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8))
                                              )
                                          )
                                        ]
                                    ),
                                  ]
                              ),
                            ),
                          ]
                      ),
                    ),
                    Expanded(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                            children: [
                                              const Text('Wishlist:'),
                                              IconButton(
                                                  icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey),
                                                  onPressed: () => provider.toggleWishlistStatus(freshLandmark.name)
                                              )
                                            ]
                                        ),
                                        RatingBar.builder(
                                            initialRating: freshLandmark.rating ?? 0.0,
                                            allowHalfRating: true,
                                            itemSize: 28,
                                            itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                            onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating)
                                        ),
                                      ]
                                  ),
                                  const Divider(height: 32),
                                  LandmarkInfoCard(
                                      overview: freshLandmark.overview,
                                      historySignificance: freshLandmark.history_significance,
                                      highlights: freshLandmark.highlights,
                                      themeColor: finalColor
                                  ),
                                ]
                            )
                        )
                    )
                  ]
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecommendationCityVisitCard extends StatelessWidget {
  final DateRange range;
  final Function(DateRange) onSave;
  final VoidCallback onDelete;

  const _RecommendationCityVisitCard({super.key, required this.range, required this.onSave, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    String displayDate = 'Select Dates';
    if (range.arrival != null || range.departure != null) {
      String arrival = range.arrival != null ? dateFormat.format(range.arrival!) : '...';
      String departure = range.departure != null ? dateFormat.format(range.departure!) : '...';
      displayDate = '$arrival - $departure';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.calendar_month, color: Color(0xFF2563EB)),
        title: Text(displayDate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: range.userDefinedDuration != null ? Text('${range.userDefinedDuration} days') : null,
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: onDelete),
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            initialDateRange: (range.arrival != null && range.departure != null) ? DateTimeRange(start: range.arrival!, end: range.departure!) : null,
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            onSave(range.copyWith(arrival: picked.start, departure: picked.end, userDefinedDuration: picked.end.difference(picked.start).inDays + 1));
          }
        },
      ),
    );
  }
}