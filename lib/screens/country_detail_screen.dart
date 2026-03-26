import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/screens/cities_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Models
import 'package:jidoapp/models/country_info_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/unesco_model.dart';
import 'package:jidoapp/models/economy_data_model.dart';

// Providers
import 'package:jidoapp/providers/country_info_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/providers/economy_provider.dart';

// Widgets
import 'package:jidoapp/widgets/landmark_info_card.dart';

class CountryDetailScreen extends StatefulWidget {
  final Country country;

  const CountryDetailScreen({super.key, required this.country});

  @override
  State<CountryDetailScreen> createState() => _CountryDetailScreenState();
}

class _CountryDetailScreenState extends State<CountryDetailScreen> {
  // Expansion States for Explore Section
  bool _isCulturalExpanded = false;
  bool _isNaturalExpanded = false;
  bool _isActivitiesExpanded = false;
  bool _isUnescoExpanded = false;

  final Set<String> _naturalAttributes = {
    'Mountain', 'Volcano', 'Desert', 'River', 'Lake', 'Sea', 'Beach',
    'Waterfall', 'Falls', 'Cave', 'Island', 'Unique Landscape', 'Glacier',
    'Canyon', 'Geothermal', 'Jungle'
  };

  final Set<String> _activityAttributes = {
    'Painting', 'Artwork', 'Library', 'Bookstore', 'Filming Location',
    'Theater', 'Performing Art', 'Food', 'Restaurant', 'Brewery', 'Winery',
    'Cafe', 'Fast Food', 'Festival', 'Event', 'Amusement Park',
    'Football Stadium', 'Zoo', 'Aquarium', 'Cruise Tour', 'Cable Car'
  };

  // Helper: Confirmation Dialog
  Future<bool> _showRemovalConfirmation(BuildContext context, String name, int count) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Removal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
        content: Text(
            'Are you sure you want to remove all $count visit records for $name?',
            style: GoogleFonts.poppins(color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, Remove', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  // Data Fetching Logic

// Data Fetching Logic

  String _getDisplayCityName(Landmark landmark) {
    if (landmark.name == 'Öresund Bridge') {
      if (widget.country.isoA3 == 'SWE') return 'Malmö';
      if (widget.country.isoA3 == 'DNK') return 'Copenhagen';
    }
    return landmark.city;
  }

  List<Landmark> _getTop30Landmarks(BuildContext context) {    final landmarksProvider = context.watch<LandmarksProvider>();
  final currentIso = widget.country.isoA3;

  final countryLandmarks = landmarksProvider.allLandmarks.where((landmark) {
    return landmark.countriesIsoA3.contains(currentIso);
  }).toList();

  // Filter: local_rank 1 to 30 based on CURRENT COUNTRY
  final filtered = countryLandmarks.where((l) {
    int rank = l.getRankForCountry(currentIso);
    return rank > 0 && rank <= 30;
  }).toList();

  // Sort by rank specific to this country
  filtered.sort((a, b) => a.getRankForCountry(currentIso).compareTo(b.getRankForCountry(currentIso)));
  return filtered;
  }

  // Helper to split landmarks into categories with Priority: Cultural -> Natural -> Activities
  Map<String, List<Landmark>> _categorizeLandmarks(List<Landmark> allCountryLandmarks) {
    final cultural = <Landmark>[];
    final natural = <Landmark>[];
    final activities = <Landmark>[];

    for (var l in allCountryLandmarks) {
      // 1. Cultural Check (Priority 1)
      // If it has any attribute distinct from natural/activity sets, treat as Cultural.
      bool isCultural = l.attributes.any((a) =>
      !_naturalAttributes.contains(a) && !_activityAttributes.contains(a));

      // 2. Natural Check (Priority 2)
      bool isNatural = l.attributes.any((a) => _naturalAttributes.contains(a));

      // 3. Activity Check (Priority 3)
      bool isActivity = l.attributes.any((a) => _activityAttributes.contains(a));

      if (isCultural) {
        cultural.add(l);
      } else if (isNatural) {
        // Now Natural takes precedence over Activities if both are present (and not cultural)
        natural.add(l);
      } else if (isActivity) {
        activities.add(l);
      } else {
        // Default / No attributes -> Cultural
        cultural.add(l);
      }
    }

    return {
      'cultural': cultural,
      'natural': natural,
      'activities': activities,
    };
  }

  List<UnescoSite> _getUnescoSitesForCountry(BuildContext context) {
    final unescoProvider = context.watch<UnescoProvider>();
    return unescoProvider.allSites.where((site) {
      return site.countriesIsoA3.contains(widget.country.isoA3);
    }).toList();
  }

  // Modal Logic (Full Detail Screens)

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
        final visitedSubCount = provider.getVisitedSubLocationCount(freshLandmark.name);
        final totalSubCount = freshLandmark.locations?.length ?? 0;

        String locationDisplay = countryNames;
        final displayCity = _getDisplayCityName(freshLandmark);
        if (displayCity != 'Unknown' && displayCity != 'Unknown City') {
          locationDisplay = '$countryNames, $displayCity';
        }

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = countryProvider.allCountries.firstWhere(
                  (c) => c.isoA3 == freshLandmark.countriesIsoA3.first,
            );
            landmarkThemeColor = country.themeColor;
          } catch (e) { landmarkThemeColor = null; }
        }
        final themeColor = landmarkThemeColor ?? fallbackThemeColor;
        final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark ? Colors.white : Colors.black;

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
                            child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor)),
                            style: ElevatedButton.styleFrom(backgroundColor: headerTextColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: Text(freshLandmark.name,
                                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold, fontSize: 26, color: headerTextColor))),
                        if (isVisited || visitedSubCount > 0) Icon(Icons.check_circle, color: headerTextColor, size: 24),
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
                        if (totalSubCount > 1) ...[
                          Text("Components / Locations", style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: freshLandmark.locations!.map((loc) {
                                final isLocVisited = provider.isSubLocationVisited(freshLandmark.name, loc.name);
                                return CheckboxListTile(
                                  title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                                  value: isLocVisited,
                                  activeColor: themeColor,
                                  dense: true,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  onChanged: (val) => provider.toggleSubLocation(freshLandmark.name, loc.name),
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(height: 24),
                        ],
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('History (${freshLandmark.visitDates.length} entries)', style: Theme.of(sheetContext).textTheme.titleSmall), OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'), onPressed: () => provider.addVisitDate(freshLandmark.name))]),
                        const SizedBox(height: 8),
                        if (freshLandmark.visitDates.isNotEmpty) ...freshLandmark.visitDates.asMap().entries.map((entry) => _LandmarkVisitEditorCard(
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
    ).then((_) => setState(() {}));
  }

  void _showUnescoSiteDetailsModal(BuildContext context, UnescoSite site, Color themeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<UnescoProvider>();
        final freshSite = provider.allSites.firstWhere((l) => l.name == site.name);
        final isVisited = provider.visitedSites.contains(freshSite.name);
        final isWishlisted = provider.wishlistedSites.contains(freshSite.name);
        final visitedSubCount = provider.getVisitedSubLocationCount(freshSite.name);
        final headerTextColor = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark ? Colors.white : Colors.black;

        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Container(
                color: themeColor,
                padding: const EdgeInsets.only(top: 16, left: 16, right: 8, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      TextButton(onPressed: () => Navigator.pop(sheetContext), child: Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600))),
                      ElevatedButton(onPressed: () => Navigator.pop(sheetContext), child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor)), style: ElevatedButton.styleFrom(backgroundColor: headerTextColor)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Text(freshSite.name, style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: headerTextColor))),
                      if (isVisited || visitedSubCount > 0) Padding(padding: const EdgeInsets.only(left: 8.0), child: Icon(Icons.check_circle, color: headerTextColor, size: 28)),
                    ]),
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
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [const Text('Wishlist:'), IconButton(visualDensity: VisualDensity.compact, icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey), onPressed: () => provider.toggleWishlistStatus(freshSite.name))]),
                          Row(mainAxisSize: MainAxisSize.min, children: [const Text('My Rating:'), const SizedBox(width: 8), RatingBar.builder(initialRating: freshSite.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateLandmarkRating(freshSite.name, rating))]),
                        ]),
                        const Divider(height: 20),
                        if (freshSite.locations.length > 1) ...[
                          Text("Components / Locations", style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: Column(children: freshSite.locations.map((loc) {
                              final isLocVisited = provider.isSubLocationVisited(freshSite.name, loc.name);
                              return CheckboxListTile(title: Text(loc.name, style: const TextStyle(fontSize: 14)), value: isLocVisited, activeColor: themeColor, dense: true, controlAffinity: ListTileControlAffinity.leading, onChanged: (val) => provider.toggleSubLocation(freshSite.name, loc.name));
                            }).toList()),
                          ),
                          const Divider(height: 24),
                        ],
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('History (${freshSite.visitDates.length} entries)', style: Theme.of(sheetContext).textTheme.titleSmall), OutlinedButton.icon(icon: const Icon(Icons.add), label: const Text('Add Visit'), onPressed: () => provider.addVisitDate(freshSite.name))]),
                        const SizedBox(height: 8),
                        if (freshSite.visitDates.isNotEmpty) ...freshSite.visitDates.asMap().entries.map((entry) => _UnescoVisitEditorCard(key: ValueKey('${freshSite.name}_${entry.key}'), siteName: freshSite.name, visitDate: entry.value, index: entry.key, onDelete: () => provider.removeVisitDate(freshSite.name, entry.key), availableLocations: freshSite.locations)) else const Center(child: Text('No visits recorded.')),
                        const Divider(height: 24),
                        LandmarkInfoCard(overview: freshSite.overview, historySignificance: freshSite.history_significance, highlights: freshSite.highlights, themeColor: themeColor),
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
    ).then((_) { setState(() {}); });
  }

  // UI Builders

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(top: 20.0, bottom: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: themeColor, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: themeColor),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColor)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String key, String value, {bool isSub = false}) {
    return Padding(
      padding: EdgeInsets.only(left: isSub ? 16.0 : 0, top: 6.0, bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text('${isSub ? '↳ ' : ''}$key', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700))),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(margin: const EdgeInsets.only(top: 6), width: 6, height: 6, decoration: BoxDecoration(color: Colors.blue.shade400, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildSyncableListItem({
    required String title,
    String? subtitle,
    required bool isVisited,
    required ValueChanged<bool>? onToggle,
    required VoidCallback onDetailPressed,
    required Color themeColor,
    int? rank,
  }) {
    final bool showSubtitle = subtitle != null && subtitle.trim().isNotEmpty;

    final bool isHighlighted = rank != null && rank > 0;
    final luminance = themeColor.computeLuminance();
    final highlightTextColor = luminance > 0.35 ? Colors.black87 : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: isHighlighted
          ? BoxDecoration(
        color: themeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themeColor.withOpacity(0.25), width: 1),
      )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                          color: isHighlighted ? themeColor.withOpacity(0.9) : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (showSubtitle)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 0),
                    child: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: themeColor,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            iconSize: 24,
            onPressed: onDetailPressed,
            tooltip: 'Details',
          ),
          const SizedBox(width: 4),
          Switch(value: isVisited, onChanged: onToggle, activeColor: themeColor),
        ],
      ),
    );
  }

  // 1. Modified Top 30 Card (Correct Rank Display)

  /// Converts landmark name to snake_case asset path
  /// e.g. "Taj Mahal" → "assets/countrydex/taj_mahal.jpg"
  String _getLandmarkImageUrl(String name) {
    final snake = name
        .toLowerCase()
        .replaceAll(RegExp(r"[''`]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/countrydex%2F$snake.jpg?alt=media';
  }

  Widget _buildTopLandmarkCardSimple(BuildContext context, Landmark landmark, LandmarksProvider provider, Color themeColor) {
    final isVisited = provider.visitedLandmarks.contains(landmark.name);
    final imageUrl = _getLandmarkImageUrl(landmark.name);

    // Derive a readable text color against themeColor background
    final luminance = themeColor.computeLuminance();
    final nameTextColor = luminance > 0.35 ? Colors.black87 : Colors.white;

    return GestureDetector(
      onTap: () => _showLandmarkDetailsModal(context, landmark, themeColor),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Container(
                        color: themeColor.withOpacity(0.12),
                        child: Center(child: CircularProgressIndicator(color: themeColor, strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.12),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: Icon(Icons.landscape_outlined, color: themeColor.withOpacity(0.5), size: 36),
                      ),
                    ),
                  ),
                  // Rank badge (top-left)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Builder(builder: (_) {
                      final rank = landmark.getRankForCountry(widget.country.isoA3);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('#$rank', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                      );
                    }),
                  ),
                  // Visited check (top-right)
                  if (isVisited)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                        ),
                        child: Icon(Icons.check_circle, color: themeColor, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            // Name area — theme color background, always 2-line height
            Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isVisited ? themeColor : themeColor.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  landmark.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: nameTextColor,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. New Expandable Explore Buttons & Logic

  Widget _buildExpandableCategoryButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: isExpanded ? color : Colors.grey.shade200, width: isExpanded ? 2 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Sub-builders for specific lists

  Widget _buildListGroupedByCity(
      BuildContext context,
      List<Landmark> items,
      Set<String> visitedItems,
      Function(String) onToggleVisited,
      Color themeColor,
      ) {
    if (items.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("No items found."));

    final Map<String, List<Landmark>> cityBuckets = {};
    for (var item in items) {
      final displayCity = _getDisplayCityName(item);
      final city = (displayCity == 'Unknown' || displayCity == 'Unknown City')
          ? 'Unknown Location'
          : displayCity;
      cityBuckets.putIfAbsent(city, () => []).add(item);
    }

    final sortedCityKeys = cityBuckets.keys.toList()
      ..sort((a, b) {
        int countA = cityBuckets[a]!.length;
        int countB = cityBuckets[b]!.length;
        if (countA != countB) return countB.compareTo(countA);
        return a.compareTo(b);
      });

    final landmarksProvider = context.read<LandmarksProvider>();
    final currentIso = widget.country.isoA3;

    return Column(
      children: sortedCityKeys.map((cityKey) {
        var cityItems = cityBuckets[cityKey]!;

        cityItems.sort((a, b) {
          int rankA = a.getRankForCountry(currentIso);
          int rankB = b.getRankForCountry(currentIso);

          bool hasRankA = rankA > 0;
          bool hasRankB = rankB > 0;

          if (hasRankA && !hasRankB) return -1;
          if (!hasRankA && hasRankB) return 1;
          if (hasRankA && hasRankB) {
            return rankA.compareTo(rankB);
          }
          return a.name.compareTo(b.name);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade50,
              child: Text(cityKey, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
            ),
            ...cityItems.map((item) {
              final isVisited = visitedItems.contains(item.name);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildSyncableListItem(
                  title: item.name,
                  subtitle: null, // City shown as group header
                  isVisited: isVisited,
                  onToggle: (val) async {
                    if (!val) {
                      if (item.visitDates.isNotEmpty) {
                        bool confirm = await _showRemovalConfirmation(context, item.name, item.visitDates.length);
                        if (!confirm) return;
                      }
                    }
                    landmarksProvider.toggleVisitedStatus(item.name);
                  },
                  onDetailPressed: () => _showLandmarkDetailsModal(context, item, themeColor),
                  themeColor: themeColor,
                  rank: item.getRankForCountry(currentIso),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGroupedList(
      BuildContext context,
      List<Landmark> items,
      Set<String> visitedItems,
      Function(String) onToggleVisited,
      Color themeColor,
      {required Map<String, List<String>> groupingRules, required String defaultGroup}
      ) {
    if (items.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text("No items found."));

    final Map<String, List<Landmark>> grouped = {};

    for (var item in items) {
      String group = defaultGroup;
      bool assigned = false;
      for (var entry in groupingRules.entries) {
        if (item.attributes.any((attr) => entry.value.contains(attr))) {
          group = entry.key;
          assigned = true;
          break;
        }
      }
      if (!assigned && defaultGroup == "NaturalAttribute") {
        for (var attr in item.attributes) {
          if (_naturalAttributes.contains(attr)) {
            group = attr == 'Waterfall' ? 'Falls' : attr;
            break;
          }
        }
        if (group == "NaturalAttribute") group = "Other Nature";
      }
      grouped.putIfAbsent(group, () => []).add(item);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    final landmarksProvider = context.read<LandmarksProvider>();
    final currentIso = widget.country.isoA3;

    return Column(
      children: sortedKeys.map((key) {
        final categoryItems = grouped[key]!;

        final Map<String, List<Landmark>> cityBuckets = {};
        for (var item in categoryItems) {
          final displayCity = _getDisplayCityName(item);
          final city = (displayCity == 'Unknown' || displayCity == 'Unknown City')
              ? 'Unknown Location'
              : displayCity;
          cityBuckets.putIfAbsent(city, () => []).add(item);
        }

        final sortedCityKeys = cityBuckets.keys.toList()
          ..sort((a, b) {
            int countA = cityBuckets[a]!.length;
            int countB = cityBuckets[b]!.length;
            if (countA != countB) return countB.compareTo(countA);
            return a.compareTo(b);
          });

        List<Landmark> sortedItems = [];
        for (var cityKey in sortedCityKeys) {
          var cityItems = cityBuckets[cityKey]!;

          cityItems.sort((a, b) {
            int rankA = a.getRankForCountry(currentIso);
            int rankB = b.getRankForCountry(currentIso);

            bool hasRankA = rankA > 0;
            bool hasRankB = rankB > 0;

            if (hasRankA && !hasRankB) return -1;
            if (!hasRankA && hasRankB) return 1;
            if (hasRankA && hasRankB) {
              return rankA.compareTo(rankB);
            }
            return a.name.compareTo(b.name);
          });

          sortedItems.addAll(cityItems);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade50,
              child: Text(key, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
            ),
            ...sortedItems.map((item) {
              final isVisited = visitedItems.contains(item.name);

              // City name hidden for non-cultural landmarks
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildSyncableListItem(
                  title: item.name,
                  subtitle: null,
                  isVisited: isVisited,
                  onToggle: (val) async {
                    if (!val) {
                      if (item.visitDates.isNotEmpty) {
                        bool confirm = await _showRemovalConfirmation(context, item.name, item.visitDates.length);
                        if (!confirm) return;
                      }
                    }
                    landmarksProvider.toggleVisitedStatus(item.name);
                  },
                  onDetailPressed: () => _showLandmarkDetailsModal(context, item, themeColor),
                  themeColor: themeColor,
                  rank: item.getRankForCountry(currentIso),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  // UNESCO Sorting Logic
  List<UnescoSite> _sortSitesByCityPopularity(List<UnescoSite> sites) {
    if (sites.isEmpty) return [];

    final Map<String, List<UnescoSite>> cityBuckets = {};
    for (var item in sites) {
      final city = (item.city == null || item.city == 'Unknown' || item.city == 'Unknown City')
          ? 'Unknown Location'
          : item.city!;
      cityBuckets.putIfAbsent(city, () => []).add(item);
    }

    final sortedCityKeys = cityBuckets.keys.toList()
      ..sort((a, b) {
        int countA = cityBuckets[a]!.length;
        int countB = cityBuckets[b]!.length;
        if (countA != countB) return countB.compareTo(countA);
        return a.compareTo(b);
      });

    List<UnescoSite> sortedItems = [];
    for (var cityKey in sortedCityKeys) {
      var cityItems = cityBuckets[cityKey]!;
      cityItems.sort((a, b) => a.name.compareTo(b.name));
      sortedItems.addAll(cityItems);
    }
    return sortedItems;
  }

  @override
  Widget build(BuildContext context) {
    final countryInfoProvider = context.watch<CountryInfoProvider>();
    final landmarksProvider = context.watch<LandmarksProvider>();
    final unescoProvider = context.watch<UnescoProvider>();

    final themeColor = widget.country.themeColor ?? Theme.of(context).primaryColor;

    // Data Preparation
    final topLandmarks = _getTop30Landmarks(context);
    final allLandmarks = landmarksProvider.allLandmarks.where((l) => l.countriesIsoA3.contains(widget.country.isoA3)).toList();
    final categorized = _categorizeLandmarks(allLandmarks);
    final unescoSites = _getUnescoSitesForCountry(context);

    // Modified: Highly granular grouping for Activities to match menu screen
    final activityGrouping = {
      'Painting & Artworks': ['Painting', 'Artwork'],
      'Libraries & Bookstores': ['Library', 'Bookstore'],
      'Filming Locations': ['Filming Location'],
      'Theaters': ['Theater', 'Performing Art'],
      'National Dishes': ['Food'],
      'Restaurants': ['Restaurant'],
      'Breweries & Wineries': ['Brewery', 'Winery'],
      'Starbucks Reserve': ['Cafe'],
      'Fast Food': ['Fast Food'],
      'Festivals & Events': ['Festival', 'Event'],
      'Amusement Parks': ['Amusement Park'],
      'Football Stadiums': ['Football Stadium'],
      'Zoos': ['Zoo'],
      'Aquariums': ['Aquarium'],
      'Cruise Tours': ['Cruise Tour'],
      'Cable Cars': ['Cable Car'],
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: countryInfoProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVisitLogCard(context),
              _buildCountryInfoCard(context, themeColor),

              const SizedBox(height: 12),

              // Top 30 Highlights
              if (topLandmarks.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Highlights in ${widget.country.name}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 190,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    physics: const BouncingScrollPhysics(),
                    itemCount: topLandmarks.length,
                    itemBuilder: (context, index) {
                      return _buildTopLandmarkCardSimple(context, topLandmarks[index], landmarksProvider, themeColor);
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Explore Title Changed
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  'Explore',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
              ),

              // 1. Cultural Landmarks (First Priority Display)
              _buildExpandableCategoryButton(
                title: 'Cultural Landmarks',
                subtitle: '${categorized['cultural']!.length} locations',
                icon: Icons.public,
                color: Colors.indigo,
                isExpanded: _isCulturalExpanded,
                onTap: () => setState(() => _isCulturalExpanded = !_isCulturalExpanded),
              ),
              if (_isCulturalExpanded)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: themeColor.withOpacity(0.2))),
                  child: _buildListGroupedByCity(
                      context,
                      categorized['cultural']!,
                      landmarksProvider.visitedLandmarks,
                      landmarksProvider.toggleVisitedStatus,
                      themeColor
                  ),
                ),

              // 2. Natural Wonders (Second Priority Display)
              _buildExpandableCategoryButton(
                title: 'Natural Wonders',
                subtitle: '${categorized['natural']!.length} locations',
                icon: Icons.landscape,
                color: Colors.green,
                isExpanded: _isNaturalExpanded,
                onTap: () => setState(() => _isNaturalExpanded = !_isNaturalExpanded),
              ),
              if (_isNaturalExpanded)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: themeColor.withOpacity(0.2))),
                  child: _buildGroupedList(
                      context,
                      categorized['natural']!,
                      landmarksProvider.visitedLandmarks,
                      landmarksProvider.toggleVisitedStatus,
                      themeColor,
                      groupingRules: {},
                      defaultGroup: "NaturalAttribute"
                  ),
                ),

              // 3. Activities (Third Priority Display)
              _buildExpandableCategoryButton(
                title: 'Activities',
                subtitle: '${categorized['activities']!.length} locations',
                icon: Icons.local_activity,
                color: Colors.pink,
                isExpanded: _isActivitiesExpanded,
                onTap: () => setState(() => _isActivitiesExpanded = !_isActivitiesExpanded),
              ),
              if (_isActivitiesExpanded)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: themeColor.withOpacity(0.2))),
                  child: _buildGroupedList(
                      context,
                      categorized['activities']!,
                      landmarksProvider.visitedLandmarks,
                      landmarksProvider.toggleVisitedStatus,
                      themeColor,
                      groupingRules: activityGrouping,
                      defaultGroup: "Other Activities"
                  ),
                ),

              // 4. UNESCO
              _buildExpandableCategoryButton(
                title: 'UNESCO World Heritage',
                subtitle: '${unescoSites.length} sites',
                icon: Icons.account_balance,
                color: Colors.orange,
                isExpanded: _isUnescoExpanded,
                onTap: () => setState(() => _isUnescoExpanded = !_isUnescoExpanded),
              ),
              if (_isUnescoExpanded)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: themeColor.withOpacity(0.2))),
                  child: Column(
                    children: unescoSites.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(16), child: Text("No UNESCO sites found."))]
                        : ['Cultural', 'Natural', 'Mixed'].map((type) {
                      final rawSites = unescoSites.where((s) => s.type == type).toList();
                      if (rawSites.isEmpty) return const SizedBox.shrink();

                      final sortedSites = _sortSitesByCityPopularity(rawSites);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: Colors.grey.shade50,
                            child: Text(type, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
                          ),
                          ...sortedSites.map((item) {
                            final isVisited = unescoProvider.visitedSites.contains(item.name);
                            String? subtitle = null; // City name hidden
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: _buildSyncableListItem(
                                title: item.name,
                                subtitle: subtitle,
                                isVisited: isVisited,
                                onToggle: (val) async {
                                  if (!val) {
                                    if (item.visitDates.isNotEmpty) {
                                      bool confirm = await _showRemovalConfirmation(context, item.name, item.visitDates.length);
                                      if (!confirm) return;
                                    }
                                  }
                                  unescoProvider.toggleVisitedStatus(item.name);
                                },
                                onDetailPressed: () => _showUnescoSiteDetailsModal(context, item, themeColor),
                                themeColor: themeColor,
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // Visit Log & Info Card Methods
  Widget _buildVisitLogCard(BuildContext context) {
    final countryProvider = context.watch<CountryProvider>();
    final visitDetails = countryProvider.visitDetails[widget.country.name];
    final isHomeCountry = countryProvider.homeCountryIsoA3 == widget.country.isoA3;
    final hasLived = visitDetails?.hasLived ?? false;
    final visitedCount = visitDetails?.visitDateRanges.length ?? 0;
    final totalVisitDuration = visitDetails?.totalDurationInDays() ?? 0;
    final isWishlisted = countryProvider.wishlistedCountries.contains(widget.country.name);

    final cardColor = widget.country.themeColor ?? Theme.of(context).primaryColor;
    final textColor = ThemeData.estimateBrightnessForColor(cardColor) == Brightness.dark ? Colors.white : Colors.black;

    final info = context.watch<CountryInfoProvider>().countryInfoMap[widget.country.isoA3];
    final int safetyLevel = info?.safetyLevel ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 32,
                              height: 24,
                              child: CountryFlag.fromCountryCode(
                                widget.country.isoA2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          Flexible(
                            child: Text(
                              widget.country.name,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: cardColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$visitedCount visits · $totalVisitDuration days',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (safetyLevel > 0) ...[
                            const SizedBox(width: 12),
                            _buildSafetyBadge(safetyLevel),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade200),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          InkWell(
                            onTap: () {
                              if (isHomeCountry) {
                                countryProvider.clearHomeCountry();
                              } else {
                                countryProvider.setHomeCountry(widget.country.name, widget.country.isoA3);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isHomeCountry ? Icons.home_rounded : Icons.home_outlined,
                                    color: isHomeCountry ? cardColor : Colors.grey.shade400,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Home',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isHomeCountry ? cardColor : Colors.grey.shade600,
                                      fontWeight: isHomeCountry ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              countryProvider.toggleLivedStatus(widget.country.name);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasLived ? Icons.apartment_rounded : Icons.apartment_outlined,
                                    color: hasLived ? cardColor : Colors.grey.shade400,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Lived',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: hasLived ? cardColor : Colors.grey.shade600,
                                      fontWeight: hasLived ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              countryProvider.toggleCountryWishlistStatus(widget.country.name);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                                    color: isWishlisted ? Colors.red : Colors.grey.shade400,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Favorite',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isWishlisted ? Colors.red : Colors.grey.shade600,
                                      fontWeight: isWishlisted ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        children: [
                          _StarRating(
                            size: 20,
                            rating: visitDetails?.rating ?? 0.0,
                            onRatingChanged: (rating) {
                              countryProvider.setCountryRating(widget.country.name, rating);
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (visitDetails?.rating ?? 0) > 0
                                ? '${(visitDetails?.rating ?? 0).toStringAsFixed(1)}'
                                : 'Rate',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      countryProvider.addDateRange(widget.country.name);
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('Add Visit Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardColor,
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (visitDetails != null && visitDetails.visitDateRanges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: visitDetails.visitDateRanges.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dateRange = entry.value;
                  final String title = dateRange.title.isNotEmpty ? dateRange.title : '#${index + 1}';

                  String subtitle = '';
                  if (dateRange.arrival != null && dateRange.departure != null) {
                    subtitle = '${DateFormat('yyyy-MM-dd').format(dateRange.arrival!)} - ${DateFormat('yyyy-MM-dd').format(dateRange.departure!)}';
                  } else if (dateRange.arrival != null) {
                    subtitle = 'From ${DateFormat('yyyy-MM-dd').format(dateRange.arrival!)}';
                  } else if (dateRange.departure != null) {
                    subtitle = 'Until ${DateFormat('yyyy-MM-dd').format(dateRange.departure!)}';
                  }

                  return _CountryVisitDetailEditorTile(
                    key: ValueKey('${widget.country.name}_visit_$index'),
                    title: title,
                    subtitle: subtitle.isNotEmpty ? subtitle : null,
                    range: dateRange,
                    themeColor: cardColor,
                    country: widget.country,
                    onSave: (updatedRange) {
                      countryProvider.saveDateRange(widget.country.name, index, updatedRange);
                    },
                    onDelete: () {
                      countryProvider.removeDateRange(widget.country.name, index);
                    },
                  );
                }).toList(),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Center(child: Text('No visits recorded.')),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Helper Widget for Safety Badge
  Widget _buildSafetyBadge(int level) {
    Color color;
    String text;

    switch (level) {
      case 1:
        color = const Color(0xFF2ECC71);
        text = "Very Safe";
        break;
      case 2:
        color = const Color(0xFFF1C40F);
        text = "Generally Safe";
        break;
      case 3:
        color = const Color(0xFFE67E22);
        text = "Exercise Caution";
        break;
      case 4:
        color = const Color(0xFFE74C3C);
        text = "High Risk";
        break;
      case 5:
        color = const Color(0xFF2C2C2C);
        text = "Do Not Travel";
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryInfoCard(BuildContext context, Color themeColor) {
    final economyProvider = context.watch<EconomyProvider>();
    final info = context.watch<CountryInfoProvider>().countryInfoMap[widget.country.isoA3];

    final EconomyData? economyData = economyProvider.economyData
        .firstWhereOrNull((e) => e.isoA3 == widget.country.isoA3);

    final numberFormat = NumberFormat.decimalPattern('en_US');
    final compactCurrencyFormat = NumberFormat.compactSimpleCurrency(locale: 'en_US');
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 0);

    String populationDisplay = numberFormat.format(widget.country.populationEst);
    String areaDisplay = '${numberFormat.format(widget.country.area)} km²';

    String gdpDisplay = 'N/A';
    String gdpPerCapitaDisplay = 'N/A';

    if (economyData != null) {
      double gdpRaw = economyData.gdpNominal * 1e9;
      gdpDisplay = compactCurrencyFormat.format(gdpRaw);

      if (widget.country.populationEst > 0) {
        double perCapita = gdpRaw / widget.country.populationEst;
        gdpPerCapitaDisplay = currencyFormat.format(perCapita);
      }
    }

    if (info == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Text('No additional info available.'),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'General Info', Icons.info_outline, themeColor),
            _buildInfoRow('Capital', info.capital),
            _buildInfoRow('Official Language', info.officialLanguage),
            _buildInfoRow('Currency', info.currency),
            _buildInfoRow('Population', populationDisplay),
            _buildInfoRow('Area', areaDisplay),
            _buildInfoRow('GDP', gdpDisplay),
            _buildInfoRow('GDP per Capita', gdpPerCapitaDisplay),

            _buildSectionHeader(context, 'Major Cities', Icons.location_city, themeColor),
            ...info.majorCities.map((city) {
              final cityProvider = context.watch<CityProvider>();
              final isVisited = cityProvider.visitedCities.contains(city.name);

              final cityObj = cityProvider.allCities.firstWhereOrNull((c) => c.name == city.name);
              final isAppDefinedCityInMapData = cityObj != null;

              return _buildSyncableListItem(
                title: '${city.name} (${city.population})',
                subtitle: isAppDefinedCityInMapData
                    ? city.description
                    : '${city.description} (Not in app database)',
                isVisited: isVisited,
                onToggle: isAppDefinedCityInMapData
                    ? (value) async {
                  if (!value) {
                    final details = cityProvider.visitDetails[city.name];
                    if (details != null && details.visitDateRanges.isNotEmpty) {
                      bool confirm = await _showRemovalConfirmation(context, city.name, details.visitDateRanges.length);
                      if (!confirm) return;
                    }
                  }
                  cityProvider.setVisitedStatus(city.name, value);
                }
                    : null,
                onDetailPressed: () {
                  if (cityObj != null) {
                    showExternalCityDetailsModal(context, cityObj);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('This city is not currently in the map database.')),
                    );
                  }
                },
                themeColor: themeColor,
              );
            }),

            _buildSectionHeader(context, 'Country History', Icons.history_edu, themeColor),
            if (info.history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Text("History data unavailable.", style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
              )
            else
              ...info.history.map((item) => _buildListItem(item)),

            _buildSectionHeader(context, 'Culture Highlights', Icons.palette_outlined, themeColor),
            ...info.cultureHighlights.map((item) => _buildListItem(item)),
            _buildSectionHeader(context, 'Transportation', Icons.train_outlined, themeColor),
            ...info.transportation.map((item) => _buildListItem(item)),
            _buildSectionHeader(context, 'Good to Know', Icons.lightbulb_outline, themeColor),
            ...info.goodToKnow.map((item) => _buildListItem(item)),
          ],
        ),
      ),
    );
  }
}

// Helper Classes

class _StarRating extends StatelessWidget {
  final double rating;
  final void Function(double) onRatingChanged;
  final double size;

  const _StarRating({
    required this.rating,
    required this.onRatingChanged,
    this.size = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    return RatingBar.builder(
      initialRating: rating,
      minRating: 0.5,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemSize: size,
      itemBuilder: (context, _) => const Icon(
        Icons.star,
        color: Colors.amber,
      ),
      onRatingUpdate: (rating) {
        onRatingChanged(rating);
      },
    );
  }
}

class _CountryVisitDetailEditorTile extends StatefulWidget {
  final DateRange range;
  final ValueChanged<DateRange> onSave;
  final VoidCallback onDelete;
  final String title;
  final String? subtitle;
  final Color themeColor;
  final Country country;

  const _CountryVisitDetailEditorTile({
    super.key,
    required this.range,
    required this.onSave,
    required this.onDelete,
    required this.title,
    this.subtitle,
    required this.themeColor,
    required this.country,
  });

  @override
  State<_CountryVisitDetailEditorTile> createState() =>
      _CountryVisitDetailEditorTileState();
}

class _CountryVisitDetailEditorTileState extends State<_CountryVisitDetailEditorTile> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late final TextEditingController _durationController;
  late bool _isLayover;
  late bool _isTransfer;
  late List<String> _currentPhotos;
  late final TextEditingController _citiesController;

  final ExpansionTileController _expansionTileController = ExpansionTileController();
  bool _isEditMode = false;

  int? _arrivalYear, _arrivalMonth, _arrivalDay;
  int? _departureYear, _departureMonth, _departureDay;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.range.title);
    _memoController = TextEditingController(text: widget.range.memo);
    _isLayover = widget.range.isLayover;
    _isTransfer = widget.range.isTransfer;
    _currentPhotos = List.from(widget.range.photos);
    _citiesController = TextEditingController(text: widget.range.cities.join(', '));

    _arrivalYear = widget.range.arrival?.year;
    _arrivalMonth = widget.range.arrival?.month;
    _arrivalDay = widget.range.arrival?.day;

    _departureYear = widget.range.departure?.year;
    _departureMonth = widget.range.departure?.month;
    _departureDay = widget.range.departure?.day;

    if (widget.range.userDefinedDuration != null) {
      _durationController = TextEditingController(text: widget.range.userDefinedDuration.toString());
    } else {
      final calculatedDuration = _calculateDuration();
      _durationController = TextEditingController(
        text: calculatedDuration?.toString() ?? (widget.range.isDurationUnknown ? 'Unknown' : ''),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    _durationController.dispose();
    _citiesController.dispose();
    super.dispose();
  }

  int? _calculateDuration() {
    if (_arrivalYear == null ||
        _arrivalMonth == null ||
        _arrivalDay == null ||
        _departureYear == null ||
        _departureMonth == null ||
        _departureDay == null) {
      return null;
    }

    final arrivalDate = DateTime(_arrivalYear!, _arrivalMonth!, _arrivalDay!);
    final departureDate =
    DateTime(_departureYear!, _departureMonth!, _departureDay!);

    if (departureDate.isBefore(arrivalDate)) {
      return null;
    }
    return departureDate.difference(arrivalDate).inDays + 1;
  }

  void _handleSave() {
    final userDuration = int.tryParse(_durationController.text);

    if (_arrivalYear != null && _arrivalMonth != null && _arrivalDay != null &&
        _departureYear != null && _departureMonth != null && _departureDay != null) {
      final arrivalDate = DateTime(_arrivalYear!, _arrivalMonth!, _arrivalDay!);
      final departureDate = DateTime(_departureYear!, _departureMonth!, _departureDay!);
      if (departureDate.isBefore(arrivalDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Departure date cannot be before arrival date.')),
        );
        return;
      }
    }

    final isAllDatesKnown = _arrivalYear != null && _arrivalMonth != null && _arrivalDay != null &&
        _departureYear != null && _departureMonth != null && _departureDay != null;

    final calculatedDuration = isAllDatesKnown ? _calculateDuration() : null;
    final finalDuration = userDuration ?? calculatedDuration;

    final cities = _citiesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final updatedRange = widget.range.copyWith(
      title: _titleController.text,
      memo: _memoController.text,
      isLayover: _isLayover,
      isTransfer: _isTransfer,
      userDefinedDuration: finalDuration,
      isDurationUnknown: finalDuration == null || finalDuration <= 0,
      arrival: _arrivalYear != null && _arrivalMonth != null && _arrivalDay != null
          ? DateTime(_arrivalYear!, _arrivalMonth!, _arrivalDay!)
          : null,
      departure:
      _departureYear != null && _departureMonth != null && _departureDay != null
          ? DateTime(_departureYear!, _departureMonth!, _departureDay!)
          : null,
      photos: _currentPhotos,
      cities: cities,
    );
    widget.onSave(updatedRange);
    _expansionTileController.collapse();
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _currentPhotos.add(pickedFile.path);
      });
    }
  }

  Widget _buildPhotoPreview(String photoPath, int index) {
    final file = File(photoPath);
    bool fileExists = file.existsSync();
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: fileExists
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(file, fit: BoxFit.cover),
          )
              : const Center(
            child: Icon(Icons.error_outline, color: Colors.red),
          ),
        ),
        if (_isEditMode)
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
              onPressed: () {
                setState(() {
                  _currentPhotos.removeAt(index);
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDateSection(String label, int? year, int? month, int? day,
      Function(int?, int?, int?) onChanged) {
    final years = [
      null,
      ...List.generate(80, (index) => DateTime.now().year - index)
    ];
    final months = [null, ...List.generate(12, (index) => index + 1)];
    int daysInMonth = 31;
    if (year != null && month != null) {
      try {
        daysInMonth = DateUtils.getDaysInMonth(year, month);
      } catch (e) {
      }
    }
    final days = [null, ...List.generate(daysInMonth, (index) => index + 1)];
    int? currentDay = (day != null && day <= daysInMonth) ? day : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                label == 'Arrival' ? Icons.flight_land : Icons.flight_takeoff,
                size: 18,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildDropdown(
                      'Year', year, years, (val) => onChanged(val, month, currentDay))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildDropdown('Month', month, months,
                          (val) => onChanged(year, val, currentDay))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildDropdown(
                      'Day', currentDay, days, (val) => onChanged(year, month, val))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
      String hint, T? value, List<T> items, ValueChanged<T?> onChanged) {
    return IgnorePointer(
      ignoring: !_isEditMode,
      child: DropdownButtonFormField<T>(
        value: value,
        isDense: true,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: items
            .map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(
            item?.toString() ?? '-',
            style: TextStyle(
              fontSize: (item == null) ? 9.0 : 13.5,
              color: (item == null) ? Colors.grey.shade600 : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        controller: _expansionTileController,
        title: Row(
          children: [
            Flexible(
              child: Text(
                widget.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: widget.themeColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: widget.subtitle != null
            ? Text(
          widget.subtitle!,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEditMode)
              IconButton(
                icon: Icon(Icons.edit_outlined, color: widget.themeColor, size: 20),
                onPressed: () {
                  setState(() {
                    _isEditMode = true;
                  });
                  _expansionTileController.expand();
                },
                tooltip: 'Edit',
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Visit Record'),
                    content: const Text('Are you sure you want to delete this visit record?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDelete();
                        },
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Delete',
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  readOnly: !_isEditMode,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title, size: 20, color: Colors.blue.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) {
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _memoController,
                  readOnly: !_isEditMode,
                  decoration: InputDecoration(
                    labelText: 'Memo',
                    prefixIcon: Icon(Icons.edit_note, size: 20, color: Colors.green.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 3,
                  onChanged: (val) {
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.location_city, size: 20, color: Colors.purple.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Visited Cities',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    if (_isEditMode)
                      IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.purple.shade600),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              final cityProvider = context.read<CityProvider>();
                              final searchController = TextEditingController();

                              List<City> filteredCities = [];

                              return StatefulBuilder(
                                builder: (context, setDialogState) {
                                  return AlertDialog(
                                    title: const Text('Add City'),
                                    content: SizedBox(
                                      width: double.maxFinite,
                                      height: 300,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: searchController,
                                            decoration: const InputDecoration(
                                              labelText: 'Search City',
                                              prefixIcon: Icon(Icons.search),
                                              border: OutlineInputBorder(),
                                              hintText: 'Type city name...',
                                            ),
                                            onChanged: (value) {
                                              setDialogState(() {
                                                if (value.trim().isEmpty) {
                                                  filteredCities = [];
                                                } else {
                                                  final targetIso = widget.country.isoA2.toUpperCase();
                                                  final targetName = widget.country.name.toLowerCase();
                                                  final query = value.toLowerCase();

                                                  filteredCities = cityProvider.allCities.where((city) {
                                                    if (!city.name.toLowerCase().contains(query)) {
                                                      return false;
                                                    }

                                                    bool isSameCountry = false;

                                                    if (city.countryIsoA2.isNotEmpty) {
                                                      if (city.countryIsoA2.toUpperCase() == targetIso) {
                                                        isSameCountry = true;
                                                      }
                                                    }

                                                    if (!isSameCountry) {
                                                      if (city.country.toLowerCase() == targetName) {
                                                        isSameCountry = true;
                                                      }
                                                    }

                                                    return isSameCountry;
                                                  }).take(20).toList();
                                                }
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          Expanded(
                                            child: ListView(
                                              shrinkWrap: true,
                                              children: [
                                                if (searchController.text.trim().isNotEmpty)
                                                  ListTile(
                                                    leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                                    title: Text('Add "${searchController.text}" (Custom)'),
                                                    subtitle: const Text('Add manually if not found'),
                                                    onTap: () {
                                                      setState(() {
                                                        final current = _citiesController.text;
                                                        final newCityName = searchController.text.trim();
                                                        if (current.isEmpty) {
                                                          _citiesController.text = newCityName;
                                                        } else {
                                                          _citiesController.text = '$current, $newCityName';
                                                        }
                                                      });
                                                      Navigator.pop(dialogContext);
                                                    },
                                                  ),

                                                if (filteredCities.isNotEmpty) const Divider(),

                                                ...filteredCities.map((city) => ListTile(
                                                  title: Text(city.name),
                                                  subtitle: city.population > 0
                                                      ? Text('Population: ${NumberFormat.compact().format(city.population)}')
                                                      : null,
                                                  onTap: () {
                                                    setState(() {
                                                      final current = _citiesController.text;
                                                      if (current.isEmpty) {
                                                        _citiesController.text = city.name;
                                                      } else {
                                                        _citiesController.text = '$current, ${city.name}';
                                                      }
                                                    });
                                                    Navigator.pop(dialogContext);
                                                  },
                                                )).toList(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _citiesController.text.split(',').where((e) => e.trim().isNotEmpty).isEmpty
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No cities added',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                )
                    : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _citiesController.text
                      .split(',')
                      .where((e) => e.trim().isNotEmpty)
                      .map((city) {
                    return Chip(
                      label: Text(
                        city.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: Colors.purple.shade400,
                      deleteIcon: _isEditMode ? const Icon(Icons.close, size: 16, color: Colors.white) : null,
                      onDeleted: _isEditMode ? () {
                        setState(() {
                          final cities = _citiesController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty && e != city.trim())
                              .toList();
                          _citiesController.text = cities.join(', ');
                        });
                      } : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.photo_library, size: 20, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Photos',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    if (_isEditMode)
                      IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.blue.shade600),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (modalContext) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Photo Library'),
                                    onTap: () {
                                      Navigator.pop(modalContext);
                                      _pickImage(ImageSource.gallery);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_camera),
                                    title: const Text('Camera'),
                                    onTap: () {
                                      Navigator.pop(modalContext);
                                      _pickImage(ImageSource.camera);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: _currentPhotos.isEmpty
                      ? Text(
                    'No photos added',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  )
                      : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _currentPhotos.asMap().entries.map(
                          (entry) => _buildPhotoPreview(entry.value, entry.key),
                    ).toList(),
                  ),
                ),
                const Divider(height: 24),
                _buildDateSection(
                    'Arrival', _arrivalYear, _arrivalMonth, _arrivalDay,
                        (y, m, d) {
                      setState(() {
                        _arrivalYear = y;
                        _arrivalMonth = m;
                        _arrivalDay = d;

                        final calculatedDuration = _calculateDuration();
                        if (calculatedDuration != null) {
                          _durationController.text = calculatedDuration.toString();
                        }
                      });
                    }),
                const SizedBox(height: 12),
                _buildDateSection(
                    'Departure', _departureYear, _departureMonth, _departureDay,
                        (y, m, d) {
                      setState(() {
                        _departureYear = y;
                        _departureMonth = m;
                        _departureDay = d;

                        final calculatedDuration = _calculateDuration();
                        if (calculatedDuration != null) {
                          _durationController.text = calculatedDuration.toString();
                        }
                      });
                    }),
                const SizedBox(height: 12),
                TextField(
                  controller: _durationController,
                  readOnly: !_isEditMode,
                  decoration: InputDecoration(
                    labelText: 'Duration (days)',
                    prefixIcon: Icon(Icons.schedule, size: 20, color: Colors.orange.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (val) {
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: !_isEditMode ? null : () {
                          setState(() => _isTransfer = !_isTransfer);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _isTransfer ? Colors.blue.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isTransfer ? Colors.blue.shade300 : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.transfer_within_a_station,
                                size: 20,
                                color: _isTransfer ? Colors.blue : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w500)),
                              Checkbox(
                                value: _isTransfer,
                                onChanged: !_isEditMode ? null : (val) {
                                  setState(() => _isTransfer = val ?? false);
                                },
                                activeColor: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: !_isEditMode ? null : () {
                          setState(() => _isLayover = !_isLayover);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _isLayover ? Colors.orange.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isLayover ? Colors.orange.shade300 : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.flight_land,
                                size: 20,
                                color: _isLayover ? Colors.orange : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              const Text('Layover', style: TextStyle(fontWeight: FontWeight.w500)),
                              Checkbox(
                                value: _isLayover,
                                onChanged: !_isEditMode ? null : (val) {
                                  setState(() => _isLayover = val ?? false);
                                },
                                activeColor: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Visit Record'),
                              content: const Text('Are you sure you want to delete this visit record?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onDelete();
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isEditMode ? () {
                          setState(() => _isEditMode = false);
                          _expansionTileController.collapse();
                        } : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isEditMode ? Colors.grey.shade700 : Colors.grey.shade400,
                          side: BorderSide(
                            color: _isEditMode ? Colors.grey.shade400 : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isEditMode ? () {
                          _handleSave();
                          setState(() => _isEditMode = false);
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isEditMode ? widget.themeColor : Colors.grey.shade300,
                          foregroundColor: _isEditMode ? Colors.white : Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        year: _year ?? -9999, month: _month ?? -9999, day: _day ?? -9999, photos: _currentPhotos);
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
    final tc = Theme.of(context).primaryColor;
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
                Text('Visit Date: $_year-$_month-$_day', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                TextButton.icon(icon: const Icon(Icons.edit_calendar, size: 18), label: const Text('Edit Date'),
                    onPressed: () => _selectDate(context), style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
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
                    style: OutlinedButton.styleFrom(foregroundColor: tc, side: BorderSide(color: tc.withOpacity(0.5)))),
            ]),
          ]),
        )],
      ),
    );
  }
}

class _UnescoVisitEditorCard extends StatefulWidget {
  final String siteName;
  final VisitDate visitDate;
  final int index;
  final VoidCallback onDelete;
  final List<UnescoSubLocation> availableLocations;

  const _UnescoVisitEditorCard({
    super.key,
    required this.siteName,
    required this.visitDate,
    required this.index,
    required this.onDelete,
    required this.availableLocations,
  });

  @override
  State<_UnescoVisitEditorCard> createState() => _UnescoVisitEditorCardState();
}

class _UnescoVisitEditorCardState extends State<_UnescoVisitEditorCard> {
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
    context.read<UnescoProvider>().updateLandmarkVisit(
        widget.siteName, widget.index,
        title: _titleController.text, memo: _memoController.text,
        year: _year ?? -9999, month: _month ?? -9999, day: _day ?? -9999, photos: _currentPhotos);
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

  void _toggleLocationInVisit(String locName, bool isSelected) {
    final provider = context.read<UnescoProvider>();
    final currentDetails = List<String>.from(widget.visitDate.visitedDetails);
    if (isSelected) {
      if (!currentDetails.contains(locName)) {
        currentDetails.add(locName);
        if (!provider.isSubLocationVisited(widget.siteName, locName)) provider.toggleSubLocation(widget.siteName, locName);
      }
    } else { currentDetails.remove(locName); }
    provider.updateLandmarkVisit(widget.siteName, widget.index, visitedDetails: currentDetails);
    setState(() {});
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
    final tc = Theme.of(context).primaryColor;
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
                Text('Visit Date: $_year-$_month-$_day', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                TextButton.icon(icon: const Icon(Icons.edit_calendar, size: 18), label: const Text('Edit Date'),
                    onPressed: () => _selectDate(context), style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
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
            if (widget.availableLocations != null && widget.availableLocations!.isNotEmpty) ...[
              const Text('Locations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 4),
              IgnorePointer(ignoring: !_isEditing,
                  child: Wrap(spacing: 8.0, runSpacing: 4.0,
                      children: widget.availableLocations!.map((loc) {
                        final isChecked = widget.visitDate.visitedDetails.contains(loc.name);
                        return FilterChip(
                          label: Text(loc.name, style: const TextStyle(fontSize: 11)),
                          selected: isChecked,
                          selectedColor: tc.withOpacity(0.2),
                          checkmarkColor: tc,
                          onSelected: (val) => _toggleLocationInVisit(loc.name, val),
                        );
                      }).toList())),
              const SizedBox(height: 16),
            ],
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
                    style: OutlinedButton.styleFrom(foregroundColor: tc, side: BorderSide(color: tc.withOpacity(0.5)))),
            ]),
          ]),
        )],
      ),
    );
  }
}