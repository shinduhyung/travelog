// lib/screens/top_statues_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';

import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/widgets/landmark_visit_editor_card.dart'; // 공통 위젯 import
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class TopStatuesScreen extends StatelessWidget {
  const TopStatuesScreen({super.key});

  static final List<Map<String, dynamic>> _top20Statues = [
    {'rank': 1, 'name': 'Statue of Unity', 'height': '182 m', 'iso': 'IN'},
    {'rank': 2, 'name': 'Spring Temple Buddha', 'height': '128 m', 'iso': 'CN'},
    {'rank': 3, 'name': 'Laykyun Sekkya', 'height': '116 m', 'iso': 'MM'},
    {'rank': 4, 'name': 'Vishwas Swaroopam', 'height': '106 m', 'iso': 'IN'},
    {'rank': 5, 'name': 'Ushiku Daibutsu', 'height': '100 m', 'iso': 'JP'},
    {'rank': 6, 'name': 'Sendai Daikannon', 'height': '100 m', 'iso': 'JP'},
    {'rank': 7, 'name': 'Guanyin of Nanshan', 'height': '92 m', 'iso': 'CN'},
    {'rank': 8, 'name': 'Great Buddha of Thailand', 'height': '92 m', 'iso': 'TH'},
    {'rank': 9, 'name': 'Dai Kannon of Kita no Miyako park', 'height': '88 m', 'iso': 'JP'},
    {'rank': 10, 'name': 'Mother Homeland Calls', 'height': '85 m', 'iso': 'RU'},
    {'rank': 11, 'name': 'Awaji Kannon', 'height': '80 m', 'iso': 'JP'},
    {'rank': 12, 'name': 'Grand Buddha at Ling Shan', 'height': '79 m', 'iso': 'CN'},
    {'rank': 13, 'name': 'Guanyin of Mount Xiqiao', 'height': '77 m', 'iso': 'CN'},
    {'rank': 14, 'name': 'Tokyo Wan Kannon', 'height': '56 m', 'iso': 'JP'},
    {'rank': 15, 'name': 'Usami Kannon', 'height': '50 m', 'iso': 'JP'},
    {'rank': 16, 'name': 'African Renaissance Monument', 'height': '49 m', 'iso': 'SN'},
    {'rank': 17, 'name': 'Statue of Liberty', 'height': '46 m', 'iso': 'US'},
    {'rank': 18, 'name': 'The Motherland Monument', 'height': '42 m', 'iso': 'UA'},
    {'rank': 19, 'name': 'Christ the Redeemer', 'height': '30 m', 'iso': 'BR'},
    {'rank': 20, 'name': 'Genghis Khan Statue Complex', 'height': '40 m', 'iso': 'MN'},
  ];

  @override
  Widget build(BuildContext context) {
    final landmarksProvider = context.watch<LandmarksProvider>();
    final allLandmarks = landmarksProvider.allLandmarks;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.accessibility_new_rounded,
                          color: Color(0xFFa18cd1),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'World\'s Tallest Statues',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The most massive and tallest sculptures across the globe',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                physics: const BouncingScrollPhysics(),
                itemCount: _top20Statues.length,
                itemBuilder: (context, index) {
                  final data = _top20Statues[index];
                  final name = data['name'] as String;
                  final height = data['height'] as String;
                  final iso = data['iso'] as String;
                  final rank = data['rank'] as int;

                  final isVisited = landmarksProvider.visitedLandmarks.contains(name);
                  final landmark = allLandmarks.firstWhereOrNull((l) => l.name == name);

                  return GestureDetector(
                    onTap: () {
                      if (landmark != null) {
                        _showLandmarkDetailsModal(context, landmark, const Color(0xFFa18cd1));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("$name details not found in database")),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isVisited
                            ? Border.all(color: Colors.teal.withOpacity(0.5), width: 1.5)
                            : Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            alignment: Alignment.center,
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: rank <= 3 ? const Color(0xFFa18cd1) : Colors.grey[400],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 32,
                              height: 24,
                              child: CountryFlag.fromCountryCode(iso),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  height,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isVisited)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Visited',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600,
                                ),
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
                        LandmarkInfoCard(overview: freshLandmark.overview, historySignificance: freshLandmark.history_significance, highlights: freshLandmark.highlights, themeColor: themeColor),
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
    );
  }
}