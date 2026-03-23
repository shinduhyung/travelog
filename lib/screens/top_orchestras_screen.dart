// lib/screens/top_orchestras_screen.dart

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

class TopOrchestrasScreen extends StatelessWidget {
  const TopOrchestrasScreen({super.key});

  static final List<Map<String, dynamic>> _topOrchestras = [
    {'rank': 1, 'name': 'Berlin Philharmonie', 'orchestra': 'Berlin Philharmonic', 'iso': 'DE'},
    {'rank': 2, 'name': 'Musikverein', 'orchestra': 'Vienna Philharmonic', 'iso': 'AT'},
    {'rank': 3, 'name': 'Royal Concertgebouw', 'orchestra': 'Royal Concertgebouw Orchestra', 'iso': 'NL'},
    {'rank': 4, 'name': 'Herkulessaal', 'orchestra': 'Bavarian Radio Symphony Orchestra', 'iso': 'DE'},
    {'rank': 5, 'name': 'Symphony Hall', 'orchestra': 'Boston Symphony Orchestra', 'iso': 'US'},
    {'rank': 6, 'name': 'Gewandhaus', 'orchestra': 'Leipzig Gewandhaus Orchestra', 'iso': 'DE'},
    {'rank': 7, 'name': 'Symphony Center', 'orchestra': 'Chicago Symphony Orchestra', 'iso': 'US'},
    {'rank': 8, 'name': 'Severance Hall', 'orchestra': 'Cleveland Orchestra', 'iso': 'US'},
    {'rank': 9, 'name': 'Berliner Konzerthaus', 'orchestra': 'Konzerthausorchester Berlin', 'iso': 'DE'},
    {'rank': 10, 'name': 'Semperoper', 'orchestra': 'Staatskapelle Dresden', 'iso': 'DE'},
    {'rank': 11, 'name': 'Royal Albert Hall', 'orchestra': 'London Symphony Orchestra', 'iso': 'GB'},
    {'rank': 12, 'name': 'Suntory Hall', 'orchestra': 'NHK Symphony Orchestra', 'iso': 'JP'},
    {'rank': 13, 'name': 'Philharmonie de Paris', 'orchestra': 'Orchestre de Paris', 'iso': 'FR'},
    {'rank': 14, 'name': 'Mariinsky Theatre', 'orchestra': 'Mariinsky Theatre Orchestra', 'iso': 'RU'},
    {'rank': 15, 'name': 'Teatro alla Scala', 'orchestra': 'Filarmonica della Scala', 'iso': 'IT'},
    {'rank': 16, 'name': 'Tonhalle Zurich', 'orchestra': 'Tonhalle Orchester Zurich', 'iso': 'CH'},
    {'rank': 17, 'name': 'Kultur- und Kongresszentrum Luzern', 'orchestra': 'Lucerne Festival Orchestra', 'iso': 'CH'},
    {'rank': 18, 'name': 'Walt Disney Concert Hall', 'orchestra': 'Los Angeles Philharmonic', 'iso': 'US'},
    {'rank': 19, 'name': 'Palace of Arts', 'orchestra': 'Budapest Festival Orchestra', 'iso': 'HU'},
    {'rank': 20, 'name': 'Esplanade', 'orchestra': 'Singapore Symphony Orchestra', 'iso': 'SG'},
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
                          Icons.music_note_outlined,
                          color: Color(0xFFE2B0FF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'World Top Orchestras',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'World-class orchestras and their legendary venues',
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
                itemCount: _topOrchestras.length,
                itemBuilder: (context, index) {
                  final data = _topOrchestras[index];
                  final name = data['name'] as String;
                  final orchestra = data['orchestra'] as String;
                  final iso = data['iso'] as String;
                  final rank = data['rank'] as int;

                  final isVisited = landmarksProvider.visitedLandmarks.contains(name);
                  final landmark = allLandmarks.firstWhereOrNull((l) => l.name == name);

                  return GestureDetector(
                    onTap: () {
                      if (landmark != null) {
                        _showLandmarkDetailsModal(context, landmark, const Color(0xFFE2B0FF));
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
                                color: rank <= 3 ? const Color(0xFFE2B0FF) : Colors.grey[400],
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
                                  orchestra,
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