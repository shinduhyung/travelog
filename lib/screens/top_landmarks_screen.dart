// lib/screens/top_landmarks_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // 캐시 매니저 패키지 추가

// Models & Providers
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';

// Widgets
import 'package:jidoapp/widgets/landmark_info_card.dart';

// 파이어베이스 설정 무시하고 강제로 30일 기기 보관하는 커스텀 캐시 매니저 설정
final CacheManager _landmarksCacheManager = CacheManager(
  Config(
    'landmarks_cache_key',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 300,
  ),
);

class TopLandmarksScreen extends StatefulWidget {
  const TopLandmarksScreen({super.key});

  @override
  State<TopLandmarksScreen> createState() => _TopLandmarksScreenState();
}

class _TopLandmarksScreenState extends State<TopLandmarksScreen> {
  bool _isCompactList = false;

  final Map<String, String> _customCityMap = {
    'Mount Everest': 'Solukhumbu / Tingri',
    'Grand Canyon': 'Arizona',
    'Mount Fuji': 'Shizuoka–Yamanashi',
    'Great Barrier Reef': 'Queensland',
    'Amazon Rainforest': 'Amazon Basin',
    'Sahara Desert': 'North Africa',
    'Galápagos Islands': 'Galápagos Province',
    'Easter Island': 'Rapa Nui',
    'Mount Kilimanjaro': 'Kilimanjaro Region',
    'Dead Sea': 'Jordan Rift Valley',
    'Matterhorn': 'Valais / Aosta Valley',
    'Banff National Park': 'Alberta',
    'Uluru': 'Northern Territory',
    'Alcatraz': 'San Francisco Bay',
    'Ha Long Bay': 'Quảng Ninh Province',
    'Serengeti National Park': 'Mara–Serengeti Ecosystem',
    'Cappadocia Fairy Chimneys': 'Nevşehir Province',
    'Salar de Uyuni': 'Potosí Department',
    'Amalfi Coast': 'Campania',
    'Monument Valley': 'Arizona–Utah Border',
    'Mount Vesuvius': 'Campania',
    'Antelope Canyon': 'Arizona',
    'Mont Blanc': 'Auvergne-Rhône-Alpes / Aosta',
    'French Polynesia': 'South Pacific',
    'Blue Lagoon': 'Reykjanes Peninsula',
    'Cape of Good Hope': 'Western Cape',
    'Table Mountain': 'Cape Town',
    'Cliffs of Moher': 'County Clare',
    'Jungfrau': 'Bernese Oberland',
    'Lake Titicaca': 'Puno / La Paz',
    'Mount Sinai': 'South Sinai',
    'Dolomites': 'Northern Italy',
    'Milford Sound': 'Fiordland',
    'Bryce Canyon': 'Utah',
    'Atacama Desert': 'Antofagasta Region',
    'Death Valley': 'California',
    'Torres del Paine': 'Magallanes Region',
    "Giant's Causeway": 'County Antrim',
    'Perito Moreno Glacier': 'Santa Cruz Province',
    'Zion Canyon': 'Utah',
    'Lake Bled': 'Upper Carniola',
    'Zhangjiajie National Forest': 'Hunan Province',
    'Pamukkale Travertine Terraces': 'Denizli Province',
    'Plitvice Lakes': 'Lika-Senj County',
    'Arches National Park': 'Utah',
    'Ngorongoro Crater': 'Arusha Region',
    'Denali': 'Alaska',
    'The Twelve Apostles': 'Victoria',
    'Geirangerfjord': 'Møre og Romsdal',
    'Avenue of the Baobabs': 'Menabe Region',
    'Glacier National Park': 'Montana',
    'Waitomo Glowworm Caves': 'Waikato',
    'Jiuzhaigou Valley': 'Sichuan Province',
    'Thingvellir National Park': 'Southwest Iceland',
    'Mount Roraima': 'Guiana Highlands',
    'Vatnajökull Ice Caves': 'Southeast Iceland',
    'Mount Cook': 'Canterbury',
    'Lençóis Maranhenses': 'Maranhão',
    'Mount Athos': 'Chalkidiki',
    'Jökulsárlón Glacier Lagoon': 'Southeast Iceland',
    'Fraser Island': 'Queensland',
    'Mount Rainier': 'Washington State',
    'Lake Baikal': 'Irkutsk Oblast',
    'Mount Etna': 'Sicily',
    'Huangshan': 'Anhui Province'
  };

  String _getLandmarkImageUrl(String name) {
    final snake = name
        .toLowerCase()
        .replaceAll(RegExp(r"[''`]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/top_landmarks%2F$snake.jpg?alt=media';
  }

  String _getDisplayLandmarkName(String name) {
    if (name == 'Auschwitz-Birkenau Memorial and Museum') return 'Auschwitz Birkenau';
    if (name == 'Hungarian Parliament Building') return 'Hungarian Parliament';
    if (name == 'Notre Dame of Cathedral of Saigon' || name == 'Notre Dame Cathedral of Saigon') return 'Saigon Notre Dame';
    if (name == 'Bagan Archaeological Zone') return 'Bagan';
    if (name == 'Pamukkale Travertine Terraces') return 'Pamukkale';
    if (name == 'Pearl Harbor National Memorial' || name == 'Pearl Harbor Peace Memorial') return 'Pearl Harbor Memorial';
    if (name == 'Mezquita-Cathedral of Córdoba') return 'Cordoba Mezquita';
    if (name == 'Sheikh Zayed Grand Mosque') return 'Sheikh Zayed Mosque';
    return name;
  }

  String _getDisplayCityName(Landmark item) {
    if (_customCityMap.containsKey(item.name)) {
      return _customCityMap[item.name]!;
    }
    if (item.city != 'Unknown' && item.city != 'Unknown City') {
      return item.city;
    }
    return ' ';
  }

  Widget _buildSingleFlag(String isoA2, {double width = 42, double height = 31}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: width,
          height: height,
          child: CountryFlag.fromCountryCode(isoA2),
        ),
      ),
    );
  }

  Widget _buildEmptyFlag({double width = 42, double height = 31}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.public,
        size: width * 0.5,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildRegionFlag(String imagePath, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(imagePath, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildFlagStack(List<String> isoA3List, CountryProvider countryProvider, {double flagWidth = 42, double flagHeight = 31, double overlap = 20}) {
    if (isoA3List.isEmpty) return _buildEmptyFlag(width: flagWidth, height: flagHeight);

    final validA2s = isoA3List.map((isoA3) {
      return countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == isoA3)?.isoA2;
    }).whereNotNull().toList();

    if (validA2s.isEmpty) return _buildEmptyFlag(width: flagWidth, height: flagHeight);
    if (validA2s.length == 1) return _buildSingleFlag(validA2s.first, width: flagWidth, height: flagHeight);

    List<Widget> positionedFlags = [];
    for (int i = validA2s.length - 1; i >= 0; i--) {
      positionedFlags.add(
          Positioned(
            left: i * overlap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: _buildSingleFlag(validA2s[i], width: flagWidth, height: flagHeight),
            ),
          )
      );
    }

    double totalWidth = flagWidth + ((validA2s.length - 1) * overlap);
    return SizedBox(
      width: totalWidth,
      height: flagHeight,
      child: Stack(
        children: positionedFlags,
      ),
    );
  }

  Widget _buildRegionOrFlagStack(Landmark item, CountryProvider countryProvider, {double flagWidth = 42, double flagHeight = 31, double overlap = 20}) {
    if (item.name == 'Sahara Desert') {
      return _buildRegionFlag('assets/flags/africa.png', flagWidth, flagHeight);
    }
    if (item.name == 'Amazon Rainforest') {
      return _buildRegionFlag('assets/flags/south_america.png', flagWidth, flagHeight);
    }
    return _buildFlagStack(item.countriesIsoA3, countryProvider, flagWidth: flagWidth, flagHeight: flagHeight, overlap: overlap);
  }

  Widget _buildUnstackedFlags(Landmark item, CountryProvider countryProvider, {double flagWidth = 24, double flagHeight = 18}) {
    final validA2s = item.countriesIsoA3.map((isoA3) {
      return countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == isoA3)?.isoA2;
    }).whereNotNull().toList();

    if (validA2s.isEmpty) return _buildEmptyFlag(width: flagWidth, height: flagHeight);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: validA2s.map((a2) => _buildSingleFlag(a2, width: flagWidth, height: flagHeight)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LandmarksProvider, CountryProvider>(
      builder: (context, landmarksProvider, countryProvider, child) {
        final topItems = landmarksProvider.allLandmarks
            .where((item) => item.global_rank > 0)
            .toList()
          ..sort((a, b) => a.global_rank.compareTo(b.global_rank));

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Color(0xFFF9FAFB),
                      ],
                    ),
                  ),
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
                                  width: 4,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF14B8A6),
                                        Color(0xFF0D9488),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Global Top Attractions',
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
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                'Discover the most iconic destinations',
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
                            _isCompactList ? Icons.grid_view_rounded : Icons.view_agenda_rounded,
                            color: const Color(0xFF14B8A6),
                          ),
                          onPressed: () {
                            setState(() {
                              _isCompactList = !_isCompactList;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    physics: const BouncingScrollPhysics(),
                    itemCount: topItems.length,
                    itemBuilder: (context, index) {
                      final item = topItems[index];
                      final isVisited = landmarksProvider.visitedLandmarks.contains(item.name);
                      final themeColor = Theme.of(context).primaryColor;
                      final imageUrl = _getLandmarkImageUrl(item.name);

                      Color getRankGradientColor(int rank) {
                        if (rank <= 10) return const Color(0xFFFFD700);
                        if (rank <= 30) return const Color(0xFFC0C0C0);
                        if (rank <= 50) return const Color(0xFFCD7F32);
                        return const Color(0xFF94A3B8);
                      }

                      final rankColor = getRankGradientColor(item.global_rank);

                      if (_isCompactList) {
                        return _buildCompactItem(item, isVisited, rankColor, themeColor, countryProvider);
                      }

                      return GestureDetector(
                        onTap: () => _showLandmarkDetailsModal(context, item, themeColor),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isVisited ? const Color(0xFF14B8A6) : const Color(0xFFE5E7EB),
                              width: isVisited ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isVisited
                                    ? const Color(0xFF14B8A6).withOpacity(0.15)
                                    : Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CachedNetworkImage(
                                          cacheManager: _landmarksCacheManager, // 커스텀 캐시 매니저 연동
                                          memCacheWidth: 600, // 디코딩 딜레이 방지를 위해 메모리 사이즈 축소
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(color: Colors.grey[100]),
                                          errorWidget: (context, url, error) => Container(color: Colors.grey[100]),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.4),
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.1),
                                              ],
                                              stops: const [0.0, 0.5, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 16,
                                        left: 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: rankColor.withOpacity(0.8),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.emoji_events, size: 14, color: rankColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                '#${item.global_rank}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isVisited)
                                        Positioned(
                                          top: 16,
                                          right: 16,
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0xFF14B8A6),
                                                  Color(0xFF0D9488),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF14B8A6).withOpacity(0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(18.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 82,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildRegionOrFlagStack(item, countryProvider, flagWidth: 42, flagHeight: 31, overlap: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getDisplayLandmarkName(item.name),
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF111827),
                                              letterSpacing: -0.4,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getDisplayCityName(item),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
          ),
        );
      },
    );
  }

  Widget _buildCompactItem(Landmark item, bool isVisited, Color rankColor, Color themeColor, CountryProvider countryProvider) {
    String? isoA2;
    if (item.countriesIsoA3.isNotEmpty) {
      final country = countryProvider.allCountries.firstWhereOrNull(
              (c) => c.isoA3 == item.countriesIsoA3.first
      );
      isoA2 = country?.isoA2;
    }

    Widget flagWidget;
    if (item.name == 'Sahara Desert') {
      flagWidget = _buildRegionFlag('assets/flags/africa.png', 32, 24);
    } else if (item.name == 'Amazon Rainforest') {
      flagWidget = _buildRegionFlag('assets/flags/south_america.png', 32, 24);
    } else if (isoA2 != null) {
      flagWidget = _buildSingleFlag(isoA2, width: 32, height: 24);
    } else {
      flagWidget = _buildEmptyFlag(width: 32, height: 24);
    }

    return GestureDetector(
      onTap: () => _showLandmarkDetailsModal(context, item, themeColor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isVisited ? const Color(0xFF14B8A6) : const Color(0xFFE5E7EB),
            width: isVisited ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isVisited
                  ? const Color(0xFF14B8A6).withOpacity(0.08)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rankColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${item.global_rank}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: rankColor.withOpacity(0.9),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            flagWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDisplayLandmarkName(item.name),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (item.countriesIsoA3.length > 1 && item.name != 'Sahara Desert' && item.name != 'Amazon Rainforest')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Multinational",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    )
                  else
                    Text(
                      _getDisplayCityName(item),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            if (isVisited)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF14B8A6),
                      Color(0xFF0D9488),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<LandmarksProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();

        final freshLandmark = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited = provider.visitedLandmarks.contains(freshLandmark.name);
        final isWishlisted = provider.wishlistedLandmarks.contains(freshLandmark.name);

        final visitedSubCount = provider.getVisitedSubLocationCount(freshLandmark.name);
        final totalSubCount = freshLandmark.locations?.length ?? 0;

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere(
                  (c) => c.isoA3 == freshLandmark.countriesIsoA3.first,
            );
            landmarkThemeColor = country.themeColor;
          } catch (e) {
            landmarkThemeColor = null;
          }
        }

        final themeColor = landmarkThemeColor ?? fallbackThemeColor;
        const headerTextColor = Colors.white;

        final imageUrl = _getLandmarkImageUrl(freshLandmark.name);
        final displayCity = _getDisplayCityName(freshLandmark);

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CachedNetworkImage(
                            cacheManager: _landmarksCacheManager, // 커스텀 캐시 매니저 연동
                            memCacheWidth: 800, // 모달 사진은 조금 더 크게
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[100]),
                            errorWidget: (context, url, error) => Container(
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
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.8),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => Navigator.pop(sheetContext),
                                    icon: const Icon(Icons.close, color: headerTextColor, size: 20),
                                    label: const Text('Close', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: headerTextColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: headerTextColor.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          '#${freshLandmark.global_rank}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: headerTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      freshLandmark.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                        color: headerTextColor,
                                        letterSpacing: -0.5,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  if (isVisited || visitedSubCount > 0)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: headerTextColor.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_circle, color: headerTextColor, size: 24),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(Icons.location_on, size: 16, color: headerTextColor.withOpacity(0.9)),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildUnstackedFlags(freshLandmark, countryProvider, flagWidth: 24, flagHeight: 18),
                                        if (displayCity.trim().isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            displayCity,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: headerTextColor.withOpacity(0.9),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (totalSubCount > 1) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.layers, size: 16, color: headerTextColor.withOpacity(0.9)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$visitedSubCount / $totalSubCount locations visited',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: headerTextColor.withOpacity(0.85),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.favorite_border, size: 20, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Wishlist',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                                        color: isWishlisted ? Colors.red : Colors.grey[400],
                                        size: 28,
                                      ),
                                      onPressed: () => provider.toggleWishlistStatus(freshLandmark.name),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Icon(Icons.star_border, size: 20, color: Colors.grey[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'My Rating',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const Spacer(),
                                    RatingBar.builder(
                                      initialRating: freshLandmark.rating ?? 0.0,
                                      minRating: 0,
                                      direction: Axis.horizontal,
                                      allowHalfRating: true,
                                      itemCount: 5,
                                      itemSize: 28.0,
                                      itemPadding: const EdgeInsets.symmetric(horizontal: 2),
                                      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                      onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          if (totalSubCount > 1) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: themeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.layers, size: 18, color: themeColor),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Components / Locations",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[900],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: freshLandmark.locations!.map((loc) {
                                  final isLocVisited = provider.isSubLocationVisited(freshLandmark.name, loc.name);
                                  return CheckboxListTile(
                                    title: Text(loc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    value: isLocVisited,
                                    activeColor: themeColor,
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    onChanged: (val) {
                                      provider.toggleSubLocation(freshLandmark.name, loc.name);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.history, size: 18, color: themeColor),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Visit History',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[900],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${freshLandmark.visitDates.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                                onPressed: () => provider.addVisitDate(freshLandmark.name),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  side: BorderSide(color: themeColor),
                                  foregroundColor: themeColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (freshLandmark.visitDates.isNotEmpty)
                            ...freshLandmark.visitDates.asMap().entries.map((entry) => _LandmarkVisitEditorCard(
                              key: ValueKey('${freshLandmark.name}_${entry.key}'),
                              landmarkName: freshLandmark.name,
                              visitDate: entry.value,
                              index: entry.key,
                              onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                              availableLocations: freshLandmark.locations,
                            ))
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No visits recorded',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),

                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  themeColor.withOpacity(0.05),
                                  themeColor.withOpacity(0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: themeColor.withOpacity(0.1)),
                            ),
                            child: LandmarkInfoCard(
                              overview: freshLandmark.overview,
                              historySignificance: freshLandmark.history_significance,
                              highlights: freshLandmark.highlights,
                              themeColor: themeColor,
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {});
  }
}

class _LandmarkVisitEditorCard extends StatefulWidget {
  final String landmarkName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final List<LandmarkSubLocation>? availableLocations;

  const _LandmarkVisitEditorCard({
    super.key,
    required this.landmarkName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
    this.availableLocations,
  });

  @override
  State<_LandmarkVisitEditorCard> createState() => _LandmarkVisitEditorCardState();
}

class _LandmarkVisitEditorCardState extends State<_LandmarkVisitEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late List<String> _currentPhotos;
  int? _year, _month, _day;
  final ExpansionTileController _expansionTileController = ExpansionTileController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.visitDate.title);
    _memoController = TextEditingController(text: widget.visitDate.memo);
    _currentPhotos = List.from(widget.visitDate.photos);
    _year = widget.visitDate.year;
    _month = widget.visitDate.month;
    _day = widget.visitDate.day;
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null && mounted) {
      final newPhotos = List<String>.from(_currentPhotos)..add(pickedFile.path);
      setState(() => _currentPhotos = newPhotos);
      if(mounted){
        context.read<LandmarksProvider>().updateLandmarkVisit(
            widget.landmarkName, widget.index, photos: newPhotos
        );
      }
    }
  }

  Widget _buildPhotoPreview(String photoPath, int index) {
    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(photoPath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<LandmarksProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        controller: _expansionTileController,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          widget.visitDate.title.isNotEmpty ? widget.visitDate.title : 'Visit Record',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                '$_year-$_month-$_day',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          onPressed: widget.onDelete,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onEditingComplete: () => provider.updateLandmarkVisit(
                    widget.landmarkName,
                    widget.index,
                    title: _titleController.text,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _memoController,
                  decoration: InputDecoration(
                    labelText: 'Memo',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                  onEditingComplete: () => provider.updateLandmarkVisit(
                    widget.landmarkName,
                    widget.index,
                    memo: _memoController.text,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add_photo_alternate),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ..._currentPhotos.asMap().entries.map((e) => _buildPhotoPreview(e.value, e.key)).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}