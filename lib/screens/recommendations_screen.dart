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
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
  List<RecommendationMatch> _countryMatches  = [];
  List<RecommendationMatch> _cityMatches     = [];
  bool _isDataLoaded = false;

  static const Color _kBlue     = Color(0xFF2563EB); // AI Picks 헤더용
  static const Color _kBg       = Color(0xFFF8FAFC);
  static const Color _kMint     = Color(0xFF00BFA5); // Countries 섹션 (민트)
  static const Color _kYellow   = Colors.amber;      // Cities 섹션 (노랑)
  static const Color _kLandmark = Color(0xFFD946EF); // Landmarks 섹션 (핑크-보라)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  Future<void> _initData() async {
    await _calculateRecommendations();
    if (mounted) setState(() => _isDataLoaded = true);
  }

  Future<List<Map<String, dynamic>>> _loadPrototypes(String fileName) async {
    try {
      final String response = await rootBundle.loadString('assets/$fileName');
      return List<Map<String, dynamic>>.from(json.decode(response));
    } catch (e) { return []; }
  }

  Future<void> _calculateRecommendations() async {
    final personality    = context.read<PersonalityProvider>();
    final countryProvider = context.read<CountryProvider>();
    final cityProvider   = context.read<CityProvider>();
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
      'landmark_culture_nature':    features.landmarkCultureNature,
      'landmark_ancient_modern':    features.landmarkAncientModern,
      'landmark_urban_rural':       features.landmarkUrbanRural,
      'landmark_adventure_relax':   features.landmarkAdventureRelax,
      'landmark_art_science':       features.landmarkSpiritualSecular,
      'landmark_spiritual_secular': features.landmarkSpiritualSecular,
      'landmark_crowd':             features.landmarkCrowd,
      'landmark_budget_luxury':     features.landmarkBudgetLuxury,
      'landmark_local_tourist':     features.landmarkLocalTourist,
      'landmark_calm_nightlife':    features.landmarkCalmNightlife,
    };

    Map<String, double> coreLandmarkMapForCity = {
      'landmark_urban_rural':   features.landmarkUrbanRural,
      'landmark_ancient_modern': features.landmarkAncientModern,
      'landmark_crowd':         features.landmarkCrowd,
      'landmark_budget_luxury': features.landmarkBudgetLuxury,
    };

    final landmarkRecommenderVector = { ...personalityVector, ...fullLandmarkMap };
    final countryRecommenderVector  = {
      ...personalityVector,
      'countryWealth':    features.countryWealth,
      'countryType':      features.countryType,
      'countryNightlife': features.countryNightlife,
      ...fullLandmarkMap,
    };
    final cityRecommenderVector = {
      ...personalityVector,
      'cityWealth':    features.cityWealth,
      'cityType':      features.cityType,
      'cityNightlife': features.cityNightlife,
      ...coreLandmarkMapForCity,
    };

    final landmarkData = await _loadPrototypes('landmark_type.json');
    final countryData  = await _loadPrototypes('country_type.json');
    final cityData     = await _loadPrototypes('city_type.json');

    final Map<String, int> popularityByA2 = {};
    for (var country in countryProvider.allCountries) {
      popularityByA2[country.isoA2] = country.countryPopularity;
    }

    final visitedLandmarks = landmarkProvider.visitedLandmarks;
    final visitedCountries = countryProvider.visitedCountries;
    final visitedCities    = cityProvider.visitedCities;

    if (mounted) {
      setState(() {
        _landmarkMatches = _getMatches(landmarkData, landmarkRecommenderVector)
            .where((m) => !visitedLandmarks.contains(m.name)).take(5).toList();
        _countryMatches  = _getMatches(countryData, countryRecommenderVector, popularityMap: popularityByA2)
            .where((m) => !visitedCountries.contains(m.name)).take(5).toList();
        _cityMatches     = _getMatches(cityData, cityRecommenderVector)
            .where((m) => !visitedCities.contains(m.name)).take(5).toList();
      });
    }
  }

  List<RecommendationMatch> _getMatches(
      List<Map<String, dynamic>> prototypes,
      Map<String, double> userVector,
      {Map<String, int>? popularityMap}) {
    List<RecommendationMatch> matches = [];
    for (var proto in prototypes) {
      double distance = 0, sumWeights = 0;
      Map<String, dynamic> pRaw = proto['P'];
      Map<String, dynamic> wRaw = proto['W'];

      wRaw.forEach((axis, weight) {
        if (userVector.containsKey(axis)) {
          double uVal = userVector[axis]!;
          double pVal = (pRaw[axis] as num?)?.toDouble() ?? 0.0;
          distance    += (weight as num) * (uVal - pVal).abs();
          sumWeights  += weight;
        }
      });

      if (sumWeights > 0) {
        double score = 1.0 - (distance / (2.0 * sumWeights));
        if (proto.containsKey('landmarkPopularity')) {
          score += ((proto['landmarkPopularity'] as num).toInt() - 5) * 0.03;
        }
        final String countryA2 = proto['countryCode'] ?? '';
        if (popularityMap != null && popularityMap.containsKey(countryA2)) {
          score += (popularityMap[countryA2]! - 5) * 0.03;
        }
        if (proto.containsKey('popularity')) {
          score += ((proto['popularity'] as num).toInt() - 5) * 0.03;
        }
        matches.add(RecommendationMatch(name: proto['name'], countryCode: countryA2, score: score.clamp(0.0, 1.0)));
      }
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── 헤더 ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _kBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.search_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text('AI Picks',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: _kBlue, letterSpacing: 0.4)),
                    ]),
                    const SizedBox(height: 10),
                    const Text('Recommendations',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                            color: Color(0xFF111827), letterSpacing: -0.8, height: 1.1)),
                    const SizedBox(height: 5),
                    Text('Tailored to your travel DNA',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ),
            ),

            // ── 섹션들 ─────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildSection(
              'Countries', Icons.public_rounded, _kMint,
              _countryMatches, _onCountryTap,
            )),
            SliverToBoxAdapter(child: _buildSection(
              'Cities', Icons.location_city_rounded, _kYellow,
              _cityMatches, _onCityTap,
            )),
            SliverToBoxAdapter(child: _buildSection(
              'Landmarks', Icons.explore_rounded, _kLandmark,
              _landmarkMatches, _onLandmarkTap,
            )),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
      String title,
      IconData icon,
      Color color,
      List<RecommendationMatch> matches,
      Function(RecommendationMatch) onTap,
      ) {
    if (matches.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Container(
                width: 3, height: 18,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827), letterSpacing: -0.2)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Top ${matches.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // 카드 리스트
          SizedBox(
            height: 152,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: matches.length,
              itemBuilder: (context, index) => _buildCard(matches[index], index, color, onTap),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(RecommendationMatch match, int index, Color color, Function(RecommendationMatch) onTap) {
    final pct = (match.score * 100).toInt();
    // score bar width: 40~100% 범위로 시각화
    final barRatio = match.score.clamp(0.4, 1.0);

    return GestureDetector(
      onTap: () => onTap(match),
      child: Container(
        width: 158,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: index == 0
              ? Border.all(color: color.withOpacity(0.35), width: 1.5)
              : Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(
              color: index == 0 ? color.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 국기 + 순위
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              if (match.countryCode.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(width: 30, height: 20,
                      child: CountryFlag.fromCountryCode(match.countryCode)),
                )
              else
                const SizedBox(width: 30, height: 20),
              // 1등엔 강조 배지, 나머지는 숫자만
              if (index == 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('BEST',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                )
              else
                Text('#${index + 1}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[400])),
            ]),

            const SizedBox(height: 10),

            // 이름
            Expanded(
              child: Text(match.name,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: Color(0xFF111827), height: 1.25)),
            ),

            const SizedBox(height: 10),

            // 매치율 + 바
            Row(children: [
              Text('$pct%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(children: [
                    Container(height: 3, color: Colors.grey[100]),
                    FractionallySizedBox(
                      widthFactor: barRatio,
                      child: Container(height: 3, color: color),
                    ),
                  ]),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Tap handlers ──────────────────────────────────────────────────────────

  void _onLandmarkTap(RecommendationMatch match) {
    final provider = context.read<LandmarksProvider>();
    final landmark = provider.allLandmarks.firstWhereOrNull((l) => l.name == match.name);
    if (landmark != null) _showLandmarkDetailsModal(context, landmark, _kLandmark);
  }

  void _onCountryTap(RecommendationMatch match) {
    final countryProvider = context.read<CountryProvider>();
    final country = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2 == match.countryCode);
    if (country != null) Navigator.push(context, MaterialPageRoute(builder: (_) => CountryDetailScreen(country: country)));
  }

  void _onCityTap(RecommendationMatch match) {
    _showCityDetailSheet(context, match.name, match.countryCode);
  }

  // ── City Modal ─────────────────────────────────────────────────────────────

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
          final countryModel    = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2 == countryCode);
          final cityModel       = provider.allCities.firstWhereOrNull((c) => c.name == cityName);
          final themeColor      = countryModel?.themeColor ?? _kYellow;
          const headerTextColor = Colors.white;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(children: [
                    Positioned.fill(child: Container(decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [themeColor, themeColor.withOpacity(0.9)])))),
                    Positioned.fill(child: Container(decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.8)])))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          TextButton(onPressed: () => Navigator.pop(context),
                              child: const Text('Close', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold))),
                          if (countryModel != null)
                            Container(width: 40, height: 28,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: headerTextColor.withOpacity(0.3))),
                                child: ClipRRect(borderRadius: BorderRadius.circular(4),
                                    child: CountryFlag.fromCountryCode(countryModel.isoA2))),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: Text(cityName,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: headerTextColor))),
                          if (cityVisitDetail.visitDateRanges.isNotEmpty)
                            const Icon(Icons.verified, color: headerTextColor, size: 28),
                        ]),
                        Text(countryModel?.name ?? countryCode,
                            style: TextStyle(fontSize: 16, color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ]),
                ),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('My Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 4),
                        RatingBar.builder(initialRating: cityVisitDetail.rating, allowHalfRating: true,
                            itemCount: 5, itemSize: 24,
                            itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                            onRatingUpdate: (rating) => provider.updateCityVisitDetail(cityName, cityVisitDetail.copyWith(rating: rating))),
                      ]),
                      IconButton(icon: Icon(cityVisitDetail.isWishlisted ? Icons.favorite : Icons.favorite_border,
                          color: cityVisitDetail.isWishlisted ? Colors.red : Colors.grey, size: 30),
                          onPressed: () => provider.updateCityVisitDetail(cityName, cityVisitDetail.copyWith(isWishlisted: !cityVisitDetail.isWishlisted))),
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
                    else const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No visits recorded.'))),
                  ]),
                )),
              ]),
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

  // ── Landmark Modal ─────────────────────────────────────────────────────────

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Consumer<LandmarksProvider>(
        builder: (context, provider, child) {
          final freshLandmark = provider.allLandmarks.firstWhereOrNull((l) => l.name == landmark.name) ?? landmark;
          final isVisited     = provider.visitedLandmarks.contains(freshLandmark.name);
          final isWishlisted  = provider.wishlistedLandmarks.contains(freshLandmark.name);
          final countryNames  = provider.getCountryNames(freshLandmark.countriesIsoA3);
          final countryProvider = context.read<CountryProvider>();

          Color? themeColor;
          if (freshLandmark.countriesIsoA3.isNotEmpty) {
            final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == freshLandmark.countriesIsoA3.first);
            themeColor = c?.themeColor;
          }
          final finalColor      = themeColor ?? fallbackThemeColor;
          const headerTextColor = Colors.white;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: FractionallySizedBox(
              heightFactor: 0.85,
              child: Column(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(children: [
                    Positioned.fill(child: Container(decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [finalColor, finalColor.withOpacity(0.9)])))),
                    Positioned.fill(child: Container(decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.8)])))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          TextButton(onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                          ElevatedButton(onPressed: () => Navigator.pop(sheetContext),
                              style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                              child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: finalColor))),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: Text(freshLandmark.name,
                              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor))),
                          if (isVisited) const Icon(Icons.check_circle, color: headerTextColor, size: 24),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(countryNames,
                              style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                  color: headerTextColor.withOpacity(0.8)))),
                        ]),
                      ]),
                    ),
                  ]),
                ),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        const Text('Wishlist:'),
                        IconButton(icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border,
                            color: isWishlisted ? Colors.red : Colors.grey),
                            onPressed: () => provider.toggleWishlistStatus(freshLandmark.name)),
                      ]),
                      RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0,
                          allowHalfRating: true, itemSize: 28,
                          itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                          onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating)),
                    ]),
                    const Divider(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text('History (${freshLandmark.visitDates.length} entries)',
                          style: Theme.of(sheetContext).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Visit'),
                        onPressed: () => provider.addVisitDate(freshLandmark.name),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (freshLandmark.visitDates.isNotEmpty)
                      ...freshLandmark.visitDates.asMap().entries.map((entry) => _LandmarkVisitEditorCard(
                        key: ValueKey('${freshLandmark.name}_${entry.key}'),
                        landmarkName: freshLandmark.name,
                        visitDate: entry.value,
                        index: entry.key,
                        onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                      ))
                    else const Center(child: Text('No visits recorded.')),
                    const Divider(height: 24),
                    LandmarkInfoCard(
                        overview: freshLandmark.overview,
                        historySignificance: freshLandmark.history_significance,
                        highlights: freshLandmark.highlights,
                        themeColor: finalColor),
                  ]),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }
}


// ─── Landmark Visit Editor Card ───────────────────────────────────────────────

class _LandmarkVisitEditorCard extends StatefulWidget {
  final String landmarkName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;

  const _LandmarkVisitEditorCard({
    super.key,
    required this.landmarkName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
  });

  @override
  State<_LandmarkVisitEditorCard> createState() => _LandmarkVisitEditorCardState();
}

class _LandmarkVisitEditorCardState extends State<_LandmarkVisitEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late List<String> _currentPhotos;
  int? _year, _month, _day;
  late String _displayTitle, _displayMemo;
  bool _isEditing = false;
  final ExpansionTileController _expansionTileController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _displayTitle = widget.visitDate.title;
    _displayMemo  = widget.visitDate.memo ?? '';
    _titleController = TextEditingController(text: _displayTitle);
    _memoController  = TextEditingController(text: _displayMemo);
    _currentPhotos   = List.from(widget.visitDate.photos);
    _year = widget.visitDate.year; _month = widget.visitDate.month; _day = widget.visitDate.day;
    if (_displayTitle.isEmpty && _displayMemo.isEmpty && _currentPhotos.isEmpty) _isEditing = true;
  }

  @override void dispose() { _titleController.dispose(); _memoController.dispose(); super.dispose(); }

  void _saveChanges() {
    context.read<LandmarksProvider>().updateLandmarkVisit(
      widget.landmarkName, widget.index,
      title: _titleController.text, memo: _memoController.text,
      year: _year ?? -9999, month: _month ?? -9999, day: _day ?? -9999,
      photos: _currentPhotos,
    );
    setState(() { _displayTitle = _titleController.text; _displayMemo = _memoController.text; _isEditing = false; });
  }

  void _cancelEditing() {
    setState(() {
      _titleController.text = _displayTitle; _memoController.text = _displayMemo;
      _year = widget.visitDate.year; _month = widget.visitDate.month; _day = widget.visitDate.day;
      _currentPhotos = List.from(widget.visitDate.photos); _isEditing = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final p = await showDatePicker(context: context,
        initialDate: DateTime(_year ?? DateTime.now().year, _month ?? 1, _day ?? 1),
        firstDate: DateTime(1900), lastDate: DateTime(2100));
    if (p != null && mounted) setState(() { _year = p.year; _month = p.month; _day = p.day; });
  }

  void _pickImage(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source);
    if (f != null && mounted) setState(() => _currentPhotos.add(f.path));
  }

  Widget _buildPhotoPreview(String path, int i) => Stack(clipBehavior: Clip.none, children: [
    Container(width: 60, height: 60, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover))),
    if (_isEditing) Positioned(top: -6, right: 6,
        child: GestureDetector(onTap: () => setState(() => _currentPhotos.removeAt(i)),
            child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.cancel, color: Colors.red, size: 22)))),
  ]);

  @override
  Widget build(BuildContext context) {
    final tc = const Color(0xFFD946EF); // Landmark 테마색 적용 (핑크-보라)
    return Card(
      elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController, initiallyExpanded: _isEditing,
        title: Text(_displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text('Date: $_year-$_month-$_day', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
            onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Delete Visit Record'),
                content: const Text('Are you sure you want to delete this visit record?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  TextButton(onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                      child: const Text('Delete', style: TextStyle(color: Colors.red))),
                ]))),
        children: [Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_isEditing) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Visit Date: $_year-$_month-$_day',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                TextButton.icon(icon: const Icon(Icons.edit_calendar, size: 18), label: const Text('Edit Date'),
                    onPressed: () => _selectDate(context),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title', isDense: true, filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: _memoController, maxLines: 3, minLines: 1,
                  decoration: InputDecoration(labelText: 'Memo', isDense: true, filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
            ] else if (_displayMemo.isNotEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_displayMemo, style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4))),
            const SizedBox(height: 12),
            if (_currentPhotos.isNotEmpty || _isEditing)
              Padding(padding: const EdgeInsets.only(top: 8),
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none,
                      child: Row(children: [
                        if (_isEditing) Container(margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300)),
                            child: IconButton(icon: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                                onPressed: () => _pickImage(ImageSource.gallery))),
                        ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList(),
                      ]))),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (_isEditing) ...[
                TextButton(onPressed: _cancelEditing,
                    child: Text('Cancel', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: _saveChanges,
                    icon: const Icon(Icons.save, size: 18), label: const Text('Save'),
                    style: ElevatedButton.styleFrom(backgroundColor: tc, foregroundColor: Colors.white, elevation: 0)),
              ] else
                OutlinedButton.icon(onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit, size: 16), label: const Text('Edit Record'),
                    style: OutlinedButton.styleFrom(foregroundColor: tc,
                        side: BorderSide(color: tc.withOpacity(0.5)))),
            ]),
          ]),
        )],
      ),
    );
  }
}

// ── City Visit Card ───────────────────────────────────────────────────────────

class _RecommendationCityVisitCard extends StatelessWidget {
  final DateRange range;
  final Function(DateRange) onSave;
  final VoidCallback onDelete;

  const _RecommendationCityVisitCard({
    super.key,
    required this.range,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    String displayDate = 'Select Dates';
    if (range.arrival != null || range.departure != null) {
      final arrival   = range.arrival != null ? dateFormat.format(range.arrival!) : '...';
      final departure = range.departure != null ? dateFormat.format(range.departure!) : '...';
      displayDate = '$arrival – $departure';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.calendar_month, color: Colors.amber), // City 테마색 적용
        title: Text(displayDate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: range.userDefinedDuration != null ? Text('${range.userDefinedDuration} days') : null,
        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: onDelete),
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            initialDateRange: (range.arrival != null && range.departure != null)
                ? DateTimeRange(start: range.arrival!, end: range.departure!)
                : null,
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            onSave(range.copyWith(
              arrival: picked.start, departure: picked.end,
              userDefinedDuration: picked.end.difference(picked.start).inDays + 1,
            ));
          }
        },
      ),
    );
  }
}