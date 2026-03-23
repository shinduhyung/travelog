// lib/screens/world_wonders_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:country_flags/country_flags.dart';

import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/widgets/landmark_visit_editor_card.dart'; // 공통 위젯 import

class WorldWondersScreen extends StatefulWidget {
  const WorldWondersScreen({super.key});

  @override
  State<WorldWondersScreen> createState() => _WorldWondersScreenState();
}

class _WorldWondersScreenState extends State<WorldWondersScreen> {
  // 요청하신 이미지 경로가 포함된 신 세계 7대 불가사의 리스트
  final List<Map<String, String>> _wondersList = [
    {'name': 'Great Wall of China', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fgreat_wall.png?alt=media', 'iso': 'CN'},
    {'name': 'Petra', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fpetra.png?alt=media', 'iso': 'JO'},
    {'name': 'Colosseum', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fcolosseum.png?alt=media', 'iso': 'IT'},
    {'name': 'Chichen Itza', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fchichen_itza.png?alt=media', 'iso': 'MX'},
    {'name': 'Machu Picchu', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fmachu_picchu.png?alt=media', 'iso': 'PE'},
    {'name': 'Taj Mahal', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Ftaj_mahal.png?alt=media', 'iso': 'IN'},
    {'name': 'Christ the Redeemer', 'image': 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/wonders%2Fchrist_redeemer.png?alt=media', 'iso': 'BR'},
  ];

  @override
  Widget build(BuildContext context) {
    final landmarksProvider = context.watch<LandmarksProvider>();
    final allLandmarks = landmarksProvider.allLandmarks;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2C3E50),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('World Wonders',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0
                  )),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.2), size: 100),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final data = _wondersList[index];
                  final name = data['name']!;
                  final imageUrl = data['image']!;
                  final iso = data['iso']!;

                  final isVisited = landmarksProvider.visitedLandmarks.contains(name);
                  final landmark = allLandmarks.firstWhereOrNull((l) => l.name == name);

                  return _buildWonderCard(name, imageUrl, iso, isVisited, landmark);
                },
                childCount: _wondersList.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWonderCard(String name, String imageUrl, String iso, bool isVisited, Landmark? landmark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (landmark != null) {
                _showLandmarkDetailsModal(context, landmark, const Color(0xFF2C3E50));
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
                    ),
                    if (isVisited)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Visited', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(width: 28, height: 20, child: CountryFlag.fromCountryCode(iso)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
        final countryNames = provider.getCountryNames(freshLandmark.countriesIsoA3);

        String locationDisplay = countryNames;
        if (freshLandmark.city != 'Unknown' && freshLandmark.city != 'Unknown City') {
          locationDisplay = '$countryNames, ${freshLandmark.city}';
        }

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
        final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
            ? Colors.white
            : Colors.black;

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Container(
                color: themeColor,
                padding: const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                            child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: Text(freshLandmark.name,
                                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor))),
                        if (isVisited) Icon(Icons.check_circle, color: headerTextColor, size: 24),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(locationDisplay, style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8), fontWeight: FontWeight.normal))),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [const Text('Wishlist:'), IconButton(visualDensity: VisualDensity.compact, icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey), onPressed: () => provider.toggleWishlistStatus(freshLandmark.name))]),
                            Row(mainAxisSize: MainAxisSize.min, children: [const Text('My Rating:'), const SizedBox(width: 8), RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating))]),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('History (${freshLandmark.visitDates.length} entries)', style: Theme.of(sheetContext).textTheme.titleSmall), OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'), onPressed: () => provider.addVisitDate(freshLandmark.name))]),
                        const SizedBox(height: 8),
                        if (freshLandmark.visitDates.isNotEmpty) ...freshLandmark.visitDates.asMap().entries.map((entry) => LandmarkVisitEditorCard(
                          key: ValueKey('${freshLandmark.name}_${entry.key}'),
                          landmarkName: freshLandmark.name,
                          visitDate: entry.value,
                          index: entry.key,
                          onDelete: () => provider.removeVisitDate(freshLandmark.name, entry.key),
                          availableLocations: freshLandmark.locations,
                        )) else const Center(child: Text('No visits recorded.')),
                        const Divider(height: 24),
                        LandmarkInfoCard(
                            overview: freshLandmark.overview,
                            historySignificance: freshLandmark.history_significance,
                            highlights: freshLandmark.highlights,
                            themeColor: themeColor
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => setState(() {}));
  }
}