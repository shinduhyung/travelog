// lib/screens/landmarks_list_screen.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/screens/landmark_map_screen.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';
import 'package:jidoapp/widgets/landmark_visit_editor_card.dart'; // 공통 위젯 import 추가
import 'package:intl/intl.dart';

enum LandmarkSortOption { nameAsc, country, metricDesc }

class LandmarksListScreen extends StatefulWidget {
  final String title;
  final List<String> attributes;

  const LandmarksListScreen({
    super.key,
    required this.title,
    required this.attributes,
  });

  @override
  State<LandmarksListScreen> createState() => _LandmarksListScreenState();
}

class _LandmarksListScreenState extends State<LandmarksListScreen> {
  final TextEditingController _searchController = TextEditingController();

  // State Variables
  LandmarkSortOption _sortOption = LandmarkSortOption.nameAsc;
  bool _showVisitedOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));

    // Set default sort for Fast Food and Natural Categories
    if (_isFastFoodCategory ||
        _isRiverCategory ||
        _isLakeCategory ||
        _isMountainCategory ||
        _isFallsCategory) {
      _sortOption = LandmarkSortOption.metricDesc;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Logic Helper Methods ---

  // Category Helpers used in initState/build
  bool get _isFastFoodCategory => widget.attributes.contains('Fast Food');
  bool get _isRiverCategory => widget.attributes.contains('River');
  bool get _isMountainCategory => widget.attributes.contains('Mountain');
  bool get _isFallsCategory => widget.attributes.any((a) => ['Waterfall', 'Falls'].contains(a));
  bool get _isLakeCategory => widget.attributes.contains('Lake');
  bool get _isFoodCategory => widget.attributes.contains('Food');

  // Check Item Attributes
  bool _isItemCategory(Landmark item, String category) => item.attributes.contains(category);

  bool _isItemNatural(Landmark item) {
    return item.attributes.any((a) => [
      'Mountain', 'Waterfall', 'Falls', 'River', 'Lake', 'Sea', 'Beach', 'Island', 'Unique Landscape'
    ].contains(a));
  }

  String? _getHeaderImagePath() {
    final map = {
      'Seas': 'assets/explore_icons_large/seas.webp',
      'Beaches': 'assets/explore_icons_large/beaches.webp',
      'Rivers': 'assets/explore_icons_large/rivers.webp',
      'Lakes': 'assets/explore_icons_large/lakes.webp',
      'Waterfalls': 'assets/explore_icons_large/falls.webp',
      'Islands': 'assets/explore_icons_large/islands.webp',
      'Mountains': 'assets/explore_icons_large/mountains.webp',
      'Deserts': 'assets/explore_icons_large/deserts.webp',
      'Volcanic & Lava': 'assets/explore_icons_large/volcanoes.webp',
      'Canyons & Cliffs': 'assets/explore_icons_large/canyons.webp',
      'Caves & Underground': 'assets/explore_icons_large/caves.webp',
      'Geothermal': 'assets/explore_icons_large/geothermal.webp',
      'Glaciers': 'assets/explore_icons_large/glaciers.webp',
      'Forests & Jungles': 'assets/explore_icons_large/forests.webp',
      'Unique Landscapes': 'assets/explore_icons_large/unique_landscapes.webp',
      'Ancient & Medieval': 'assets/explore_icons_large/ancient_ruins.webp',
      'Modern History': 'assets/explore_icons_large/historical_sites.webp',
      'Archaeological Sites': 'assets/explore_icons_large/archaeological_sites.webp',
      'Traditional Villages': 'assets/explore_icons_large/traditional_villages.webp',
      'Castles & Forts': 'assets/explore_icons_large/castles.webp',
      'Palaces': 'assets/explore_icons_large/palaces.webp',
      'Modern Architecture': 'assets/explore_icons_large/modern_architecture.webp',
      'Towers': 'assets/explore_icons_large/towers_skyscrapers.webp',
      'Bridges': 'assets/explore_icons_large/bridges.webp',
      'Arches & Gates': 'assets/explore_icons_large/gates.webp',
      'Christian': 'assets/explore_icons_large/christian.webp',
      'Islamic': 'assets/explore_icons_large/islamic.webp',
      'Buddhist': 'assets/explore_icons_large/buddhist.webp',
      'Hindu': 'assets/explore_icons_large/hindu.webp',
      'Other Religions': 'assets/explore_icons_large/other_religion.webp',
      'Tombs & Cemeteries': 'assets/explore_icons_large/tombs.webp',
      'Museums & Galleries': 'assets/explore_icons_large/museums.webp',
      'Squares & Old Towns': 'assets/explore_icons_large/historical_squares.webp',
      'Urban Hubs': 'assets/explore_icons_large/urban_hubs.webp',
      'Universities': 'assets/explore_icons_large/universities.webp',
      'Markets': 'assets/explore_icons_large/markets.webp',
      'Statues': 'assets/explore_icons_large/statues.webp',
      'Parks & Gardens': 'assets/explore_icons_large/parks.webp',
      'Harbors & Waterfronts': 'assets/explore_icons_large/harbors.webp',

      // Activities Menu에서 넘어오는 타이틀 추가
      'Painting & Artworks': 'assets/explore_icons_large/paintings.webp',
      'Libraries & Bookstores': 'assets/explore_icons_large/library.webp',
      'Filming Locations': 'assets/explore_icons_large/filming_locations.webp',
      'Theaters': 'assets/explore_icons_large/theaters.webp',
      'Theaters & Performing Arts': 'assets/explore_icons_large/theaters.webp',
      'National Dishes': 'assets/explore_icons_large/food.webp',
      'Restaurants': 'assets/explore_icons_large/restaurants.webp',
      'Breweries': 'assets/explore_icons_large/brewery.webp',
      'Breweries & Wineries': 'assets/explore_icons_large/brewery.webp',
      'Starbucks Reserve': 'assets/explore_icons_large/starbucks.webp',
      'Fast Food': 'assets/explore_icons_large/fast_food.webp',
      'Festivals & Events': 'assets/explore_icons_large/festival.webp',
      'Amusement Parks': 'assets/explore_icons_large/amusement_parks.webp',
      'Football Stadiums': 'assets/explore_icons_large/football_stadiums.webp',
      'Zoos': 'assets/explore_icons_large/zoo.webp',
      'Aquariums': 'assets/explore_icons_large/aquarium.webp',
      'Cruise Tours': 'assets/explore_icons_large/cruise_tours.webp',
      'Cable Cars': 'assets/explore_icons_large/cable_car.webp',
    };
    return map[widget.title];
  }

  double _getMetricValue(Landmark item) {
    if (_isItemCategory(item, 'Mountain') || item.attributes.contains('Falls') || item.attributes.contains('Waterfall')) {
      return (item.height ?? 0).toDouble();
    } else if (_isItemCategory(item, 'Lake')) {
      return (item.area ?? 0).toDouble();
    } else if (_isItemCategory(item, 'River')) {
      if (item.length != null) {
        return double.tryParse(item.length!.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      }
    } else if (_isItemCategory(item, 'Fast Food')) {
      return (item.numberOfLocations ?? 0).toDouble();
    }
    return 0.0;
  }

  String _getMetricText(Landmark item) {
    final fmt = NumberFormat('#,###');
    if (_isItemCategory(item, 'Mountain') || item.attributes.contains('Falls') || item.attributes.contains('Waterfall')) {
      if (item.height != null) return '${fmt.format(item.height)} m';
    } else if (_isItemCategory(item, 'River')) {
      if (item.length != null) return '${item.length} km';
    } else if (_isItemCategory(item, 'Lake')) {
      if (item.area != null) return '${fmt.format(item.area)} km²';
    }
    return '';
  }

  String _getContinent(Landmark landmark, CountryProvider cp) {
    if (landmark.countriesIsoA3.isEmpty) return 'Unknown';
    final country = cp.allCountries.firstWhereOrNull(
            (c) => c.isoA3 == landmark.countriesIsoA3.first);
    return country?.continent ?? 'Unknown';
  }

  String _getCountryName(Landmark item, CountryProvider cp) {
    if (item.countriesIsoA3.isEmpty) return 'Unknown';
    if (item.countriesIsoA3.length > 1) return 'Multinational';
    return cp.isoToCountryNameMap[item.countriesIsoA3.first] ?? 'Unknown';
  }

  // Data Processing: Filter -> Sort -> Group
  Map<String, List<Landmark>> _processData(
      List<Landmark> allItems,
      LandmarksProvider provider,
      CountryProvider countryProvider
      ) {
    final searchQuery = _searchController.text.toLowerCase();

    // 1. Filtering
    List<Landmark> filtered = allItems.where((item) {
      if (_showVisitedOnly && !provider.visitedLandmarks.contains(item.name)) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final matchesName = item.name.toLowerCase().contains(searchQuery);
        final matchesCountry = item.countriesIsoA3.any((iso) =>
            (countryProvider.isoToCountryNameMap[iso] ?? '').toLowerCase().contains(searchQuery));
        if (!matchesName && !matchesCountry) return false;
      }
      return true;
    }).toList();

    // 2. Sorting
    switch (_sortOption) {
      case LandmarkSortOption.metricDesc:
        filtered.sort((a, b) => _getMetricValue(b).compareTo(_getMetricValue(a)));
        break;
      case LandmarkSortOption.country:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case LandmarkSortOption.nameAsc:
      default:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
    }

    // 3. Grouping
    Map<String, List<Landmark>> groupedMap = {};

    if (_isFoodCategory) {
      for (var item in filtered) {
        String key = _getContinent(item, countryProvider);
        groupedMap.putIfAbsent(key, () => []).add(item);
      }
    } else if (_sortOption == LandmarkSortOption.country) {
      for (var item in filtered) {
        String key = _getCountryName(item, countryProvider);
        groupedMap.putIfAbsent(key, () => []).add(item);
      }
    } else {
      groupedMap['All'] = filtered;
    }

    // 4. Sorting Groups
    if (_isFoodCategory || _sortOption == LandmarkSortOption.country) {
      var sortedKeys = groupedMap.keys.toList();
      sortedKeys.sort((k1, k2) {
        int visited1 = groupedMap[k1]!.where((i) => provider.visitedLandmarks.contains(i.name)).length;
        int visited2 = groupedMap[k2]!.where((i) => provider.visitedLandmarks.contains(i.name)).length;
        int compare = visited2.compareTo(visited1);
        if (compare != 0) return compare;
        return k1.compareTo(k2);
      });

      Map<String, List<Landmark>> sortedMap = {};
      for (var key in sortedKeys) {
        sortedMap[key] = groupedMap[key]!;
      }
      return sortedMap;
    }

    return groupedMap;
  }

  String? _getDisplayIsoA2(Landmark site, CountryProvider countryProvider) {
    if (site.city.contains('Macao') || site.countriesIsoA3.contains('MAC')) return 'MO';
    if (site.city.contains('Hong Kong') || site.countriesIsoA3.contains('HKG')) return 'HK';
    if (site.countriesIsoA3.contains('GRL')) return 'GL';
    if (site.countriesIsoA3.contains('PYF')) return 'PF';
    if (site.countriesIsoA3.contains('PRI')) return 'BM';
    if (site.countriesIsoA3.contains('BMU')) return 'BM';
    if (site.countriesIsoA3.contains('GIB')) return 'GI';
    if (site.countriesIsoA3.contains('PCN')) return 'PN';

    if (site.countriesIsoA3.length == 1) {
      try {
        final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == site.countriesIsoA3.first);
        return c?.isoA2;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  void _navigateToMap(BuildContext context, List<Landmark> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LandmarkMapScreen(
          title: widget.title,
          allItems: items,
          visitedItems: context.read<LandmarksProvider>().visitedLandmarks,
          onToggleVisited: context.read<LandmarksProvider>().toggleVisitedStatus,
        ),
      ),
    );
  }

  void _showLandmarkDetailsModal(BuildContext context, Landmark landmark, Color fallbackThemeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
        if (_isItemNatural(freshLandmark)) {
          locationDisplay = countryNames;
        }
        else if (freshLandmark.city != 'Unknown' && freshLandmark.city != 'Unknown City') {
          locationDisplay = '$countryNames, ${freshLandmark.city}';
        }

        if (_isItemCategory(freshLandmark, 'Filming Location') && freshLandmark.location != null) {
          locationDisplay += ' (${freshLandmark.location})';
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
        const headerTextColor = Colors.white;

        Widget? customHeaderWidget;

        if ((_isItemCategory(freshLandmark, 'Brewery') && freshLandmark.brand != null) ||
            (_isItemCategory(freshLandmark, 'Football Stadium') && freshLandmark.team != null)) {

          final text = _isItemCategory(freshLandmark, 'Football Stadium')
              ? freshLandmark.team!
              : freshLandmark.brand!;

          final openedText = (_isItemCategory(freshLandmark, 'Football Stadium') && freshLandmark.opened != null)
              ? "Opened ${freshLandmark.opened}"
              : null;

          customHeaderWidget = Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: headerTextColor.withOpacity(0.6), width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                ),
                if (openedText != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      openedText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: headerTextColor.withOpacity(0.9),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        else if (_isItemCategory(freshLandmark, 'Filming Location')) {
          List<String> subInfos = [];
          if (freshLandmark.director != null) subInfos.add('Directed by ${freshLandmark.director}');
          if (freshLandmark.releaseDate != null) subInfos.add(freshLandmark.releaseDate!);

          if (subInfos.isNotEmpty) {
            customHeaderWidget = Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                subInfos.join(' • '),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: headerTextColor.withOpacity(0.9),
                    fontStyle: FontStyle.italic
                ),
              ),
            );
          }
        }
        else if (_isItemCategory(freshLandmark, 'Festival') && freshLandmark.month != null) {
          customHeaderWidget = Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              freshLandmark.month!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: headerTextColor.withOpacity(0.95),
              ),
            ),
          );
        }
        else if (_isItemCategory(freshLandmark, 'Fast Food')) {
          String text = "";
          if (freshLandmark.type != null) text += freshLandmark.type!;
          if (freshLandmark.numberOfLocations != null) {
            String locText = "${NumberFormat('#,###').format(freshLandmark.numberOfLocations)} locations";
            if (text.isNotEmpty) {
              text += " • $locText";
            } else {
              text = locText;
            }
          }
          if (text.isNotEmpty) {
            customHeaderWidget = Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: headerTextColor.withOpacity(0.95),
                ),
              ),
            );
          }
        }
        else if (freshLandmark.type != null && freshLandmark.type!.isNotEmpty) {
          customHeaderWidget = Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              freshLandmark.type!,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: headerTextColor.withOpacity(0.95),
              ),
            ),
          );
        }

        String metricLabel = _getMetricText(freshLandmark);

        String? modalFlagIso = _getDisplayIsoA2(freshLandmark, countryProvider);
        List<String> displayIsos = [];

        // Sort countries to ensure China (CHN) comes first visually
        final List<String> sortedIsoA3 = List.from(freshLandmark.countriesIsoA3)
          ..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0));

        if (modalFlagIso == null || sortedIsoA3.length > 1) {
          for (var isoA3 in sortedIsoA3) {
            final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == isoA3);
            if (c != null) displayIsos.add(c.isoA2);
          }
        } else {
          displayIsos = [modalFlagIso];
        }

        String displayTitle = freshLandmark.name;
        if (_isItemCategory(freshLandmark, 'Cafe') && freshLandmark.opened != null) {
          displayTitle += ' (${freshLandmark.opened})';
        }

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
                  child: Stack(
                    children: [
                      // Base theme color gradient
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
                      // Dark gradient overlay
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
                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  child: const Text('Cancel', style: TextStyle(color: headerTextColor, fontWeight: FontWeight.w600)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                                  child: Text('Done', style: TextStyle(fontWeight: FontWeight.w600, color: themeColor)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayTitle,
                                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 26,
                                      color: headerTextColor,
                                    ),
                                  ),
                                ),
                                if (isVisited || visitedSubCount > 0)
                                  const Icon(Icons.check_circle, color: headerTextColor, size: 24),
                              ],
                            ),
                            if (metricLabel.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  metricLabel,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: headerTextColor.withOpacity(0.95),
                                  ),
                                ),
                              ),

                            if (customHeaderWidget != null) customHeaderWidget,

                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 14, color: headerTextColor.withOpacity(0.8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    locationDisplay,
                                    style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                                      color: headerTextColor.withOpacity(0.8),
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: displayIsos.map((isoA2) => Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: Container(
                                    height: 24,
                                    width: 32,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: headerTextColor.withOpacity(0.3), width: 1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: CountryFlag.fromCountryCode(isoA2),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),

                            if (totalSubCount > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: Text(
                                  "$visitedSubCount / $totalSubCount visited",
                                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                                    color: headerTextColor.withOpacity(0.9),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
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
                          if (_isItemCategory(freshLandmark, 'Painting') || _isItemCategory(freshLandmark, 'Artwork')) ...[
                            if (freshLandmark.artist != null) Text(freshLandmark.artist!, style: Theme.of(sheetContext).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 32)),
                            if (freshLandmark.created != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(freshLandmark.created!, style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(color: Colors.black54, fontStyle: FontStyle.italic))),
                            if (freshLandmark.museum != null) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Icon(Icons.museum_outlined, color: themeColor, size: 20), const SizedBox(width: 8), Text(freshLandmark.museum!, style: Theme.of(sheetContext).textTheme.titleMedium)])),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(thickness: 1)),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [const Text('Wishlist:'), IconButton(visualDensity: VisualDensity.compact, icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey), onPressed: () => provider.toggleWishlistStatus(freshLandmark.name))]),
                              Row(mainAxisSize: MainAxisSize.min, children: [const Text('My Rating:'), const SizedBox(width: 8), RatingBar.builder(initialRating: freshLandmark.rating ?? 0.0, minRating: 0, direction: Axis.horizontal, allowHalfRating: true, itemCount: 5, itemSize: 28.0, itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber), onRatingUpdate: (rating) => provider.updateLandmarkRating(freshLandmark.name, rating))]),
                            ],
                          ),
                          const Divider(height: 20),

                          if (totalSubCount > 1) ...[
                            Text("Components / Locations",
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: freshLandmark.locations!.map((loc) {
                                  final isLocVisited = provider.isSubLocationVisited(freshLandmark.name, loc.name);
                                  return CheckboxListTile(
                                    title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                                    value: isLocVisited,
                                    activeColor: themeColor,
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    onChanged: (val) {
                                      provider.toggleSubLocation(freshLandmark.name, loc.name);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            const Divider(height: 24),
                          ],

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

                          if (_isItemCategory(freshLandmark, 'Food')) ...[
                            if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                            if (freshLandmark.history != null) _buildInfoText('History', freshLandmark.history!, themeColor),
                            if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                          ]
                          else if (_isItemCategory(freshLandmark, 'Restaurant')) ...[
                            if (freshLandmark.history != null) _buildInfoText('History', freshLandmark.history!, themeColor),
                            if (freshLandmark.bestDishes != null) _buildInfoText('Best Dishes', freshLandmark.bestDishes!, themeColor),
                            if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                          ]
                          else if (_isItemCategory(freshLandmark, 'Festival')) ...[
                              if (freshLandmark.history != null) _buildInfoText('History', freshLandmark.history!, themeColor),
                              if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                            ]
                            else if (_isItemCategory(freshLandmark, 'Football Stadium')) ...[
                                if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                              ]
                              else if (_isItemCategory(freshLandmark, 'Brewery')) ...[
                                  if (freshLandmark.history != null) _buildInfoText('History', freshLandmark.history!, themeColor),
                                  if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                ]
                                else if (_isItemCategory(freshLandmark, 'Fast Food')) ...[
                                    if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                  ]
                                  else if (_isItemCategory(freshLandmark, 'Cafe')) ...[
                                      if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                      if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                                    ]
                                    else if (_isItemNatural(freshLandmark)) ...[
                                        if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                                        if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                      ]
                                      else if (_isItemCategory(freshLandmark, 'Filming Location')) ...[
                                          if (freshLandmark.overview != null) _buildInfoText('Overview', freshLandmark.overview!, themeColor),
                                          if (freshLandmark.highlights != null) _buildInfoText('Highlights', freshLandmark.highlights!, themeColor),
                                        ]
                                        else ...[
                                            LandmarkInfoCard(overview: freshLandmark.overview, historySignificance: freshLandmark.history_significance, highlights: freshLandmark.highlights, themeColor: themeColor),
                                          ],
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
    ).then((_) => setState(() {}));
  }

  Widget _buildInfoText(String title, String content, Color themeColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor)), const SizedBox(height: 4), Text(content, style: TextStyle(color: Colors.grey[800], height: 1.4)), const SizedBox(height: 16)]);
  }

  Widget _buildHeroDashboard(BuildContext context, double percentage, int visitedCount, int totalCount, List<Landmark> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, size: 20, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text('Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Text('${(percentage * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(height: 8, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(height: 8, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)))
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!_isFoodCategory)
                      GestureDetector(
                        onTap: () => _navigateToMap(context, items),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.map_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              const Text('View Map', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    Text(
                        '$visitedCount / $totalCount visited',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)
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

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Consumer<LandmarksProvider>(
      builder: (context, provider, child) {
        final countryProvider = context.watch<CountryProvider>();
        if (provider.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final allRelatedItems = provider.getLandmarksByAttributes(widget.attributes);
        final Map<String, List<Landmark>> groupedMap = _processData(allRelatedItems, provider, countryProvider);
        final List<String> sortedGroupKeys = groupedMap.keys.toList();

        final visitedCount = allRelatedItems.where((i) => provider.visitedLandmarks.contains(i.name)).length;
        final totalCount = allRelatedItems.length;
        final percentage = totalCount > 0 ? (visitedCount / totalCount) : 0.0;
        final themeColor = Theme.of(context).primaryColor;
        final imagePath = _getHeaderImagePath();

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      if (imagePath != null)
                        Positioned.fill(
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          ),
                        ),
                      if (imagePath != null)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                      if (imagePath == null)
                        Positioned.fill(
                          child: Container(
                            color: themeColor,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 24),

                            _buildHeroDashboard(context, percentage, visitedCount, totalCount, allRelatedItems),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              filled: true,
                              fillColor: Colors.white,
                              suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: Icon(Icons.clear, color: Colors.grey[400]), onPressed: () => _searchController.clear()) : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16), // 드롭다운 테두리를 16으로 변경하여 더 둥글게 처리
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<LandmarkSortOption>(
                                    value: _sortOption,
                                    isExpanded: true,
                                    borderRadius: BorderRadius.circular(16), // 드롭다운 메뉴 자체를 둥글게 처리
                                    icon: const Icon(Icons.sort, size: 20),
                                    onChanged: (LandmarkSortOption? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _sortOption = newValue;
                                        });
                                      }
                                    },
                                    items: [
                                      const DropdownMenuItem(
                                        value: LandmarkSortOption.nameAsc,
                                        child: Text("Name (A-Z)", style: TextStyle(fontSize: 14)),
                                      ),
                                      const DropdownMenuItem(
                                        value: LandmarkSortOption.country,
                                        child: Text("Country", style: TextStyle(fontSize: 14)),
                                      ),
                                      if (widget.attributes.contains('River'))
                                        const DropdownMenuItem(
                                          value: LandmarkSortOption.metricDesc,
                                          child: Text("Length", style: TextStyle(fontSize: 14)),
                                        ),
                                      if (widget.attributes.contains('Lake'))
                                        const DropdownMenuItem(
                                          value: LandmarkSortOption.metricDesc,
                                          child: Text("Area", style: TextStyle(fontSize: 14)),
                                        ),
                                      if (widget.attributes.contains('Mountain') || widget.attributes.contains('Falls') || widget.attributes.contains('Waterfall'))
                                        const DropdownMenuItem(
                                          value: LandmarkSortOption.metricDesc,
                                          child: Text("Height", style: TextStyle(fontSize: 14)),
                                        ),
                                      if (widget.attributes.contains('Fast Food'))
                                        const DropdownMenuItem(
                                          value: LandmarkSortOption.metricDesc,
                                          child: Text("Number of Locations", style: TextStyle(fontSize: 14)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilterChip(
                              label: const Text('Visited', style: TextStyle(fontSize: 13)),
                              selected: _showVisitedOnly,
                              onSelected: (bool selected) {
                                setState(() {
                                  _showVisitedOnly = selected;
                                });
                              },
                              backgroundColor: Colors.white,
                              selectedColor: themeColor.withOpacity(0.15),
                              checkmarkColor: themeColor,
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              labelStyle: TextStyle(
                                color: _showVisitedOnly ? themeColor : Colors.grey[700],
                                fontWeight: _showVisitedOnly ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final groupKey = sortedGroupKeys[index];
                        final groupItems = groupedMap[groupKey]!;

                        if (groupKey == 'All') {
                          return Column(
                            children: groupItems.map((item) => _buildLandmarkCard(context, provider, item, showFlag: true)).toList(),
                          );
                        } else {
                          final continentColor = context.read<CountryProvider>().continentColors[groupKey] ?? themeColor;
                          int visitedInGroup = groupItems.where((i) => provider.visitedLandmarks.contains(i.name)).length;

                          Widget? headerBadge;
                          if (_sortOption == LandmarkSortOption.country && !widget.attributes.contains('Food')) {
                            String? headerIso;
                            try {
                              final country = countryProvider.allCountries.firstWhere((c) => c.name == groupKey);
                              headerIso = country.isoA2;
                            } catch(e) {}

                            if (headerIso != null) {
                              headerBadge = ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(width: 28, height: 20, child: CountryFlag.fromCountryCode(headerIso)),
                              );
                            } else {
                              headerBadge = const Icon(Icons.flag, size: 20, color: Colors.grey);
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 20, bottom: 8),
                                child: Row(
                                  children: [
                                    if (headerBadge != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: headerBadge,
                                      ),
                                      const SizedBox(width: 10),
                                    ] else ...[
                                      Container(width: 4, height: 18, color: continentColor, margin: const EdgeInsets.only(right: 8)),
                                    ],

                                    Expanded(
                                      child: Text(
                                          "$groupKey $visitedInGroup/${groupItems.length}",
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...groupItems.map((item) => _buildLandmarkCard(
                                  context,
                                  provider,
                                  item,
                                  showFlag: widget.attributes.contains('Food') || _sortOption != LandmarkSortOption.country
                              )).toList(),
                            ],
                          );
                        }
                      },
                      childCount: sortedGroupKeys.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLandmarkToggle(BuildContext context, Landmark item, bool isVisited, LandmarksProvider provider) async {
    if (isVisited) {
      if (item.visitDates.isNotEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Removal'),
            content: Text('Are you sure you want to remove all visit records for ${item.name}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')
              ),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes, Remove', style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        );

        if (confirm == true) {
          provider.toggleVisitedStatus(item.name);
        }
      } else {
        provider.toggleVisitedStatus(item.name);
      }
    } else {
      provider.toggleVisitedStatus(item.name);
    }
  }

  Widget _buildLandmarkCard(BuildContext context, LandmarksProvider provider, Landmark item, {required bool showFlag}) {
    final isVisited = provider.visitedLandmarks.contains(item.name);
    final isWishlisted = provider.wishlistedLandmarks.contains(item.name);
    final visitedSubCount = provider.getVisitedSubLocationCount(item.name);
    final themeColor = Theme.of(context).primaryColor;

    final countryProvider = context.read<CountryProvider>();
    Widget leadingWidget;

    String? displayIsoA2 = _getDisplayIsoA2(item, countryProvider);

    final List<String> sortedIsoA3 = List.from(item.countriesIsoA3)
      ..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0));

    if (showFlag) {
      if (sortedIsoA3.length == 2) {
        String? iso1, iso2;
        try {
          iso1 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[0])?.isoA2;
          iso2 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[1])?.isoA2;
        } catch(e){}

        if (iso1 != null && iso2 != null) {
          leadingWidget = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48, height: 48,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CountryFlag.fromCountryCode(iso1),
                  ClipPath(clipper: const DiagonalClipper(), child: CountryFlag.fromCountryCode(iso2)),
                ],
              ),
            ),
          );
        } else {
          leadingWidget = Icon(Icons.place, color: isVisited ? themeColor : Colors.grey, size: 24);
        }
      }
      else if (sortedIsoA3.length == 3) {
        String? iso1, iso2, iso3;
        try {
          iso1 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[0])?.isoA2;
          iso2 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[1])?.isoA2;
          iso3 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[2])?.isoA2;
        } catch(e){}

        if (iso1 != null && iso2 != null && iso3 != null) {
          leadingWidget = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 48, height: 48, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: CountryFlag.fromCountryCode(iso1)), Expanded(child: CountryFlag.fromCountryCode(iso2)), Expanded(child: CountryFlag.fromCountryCode(iso3))])),
          );
        } else {
          leadingWidget = Icon(Icons.place, color: isVisited ? themeColor : Colors.grey, size: 24);
        }
      }
      else if (sortedIsoA3.length >= 4) {
        String? iso1, iso2, iso3, iso4;
        try {
          iso1 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[0])?.isoA2;
          iso2 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[1])?.isoA2;
          iso3 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[2])?.isoA2;
          iso4 = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == sortedIsoA3[3])?.isoA2;
        } catch(e){}

        if (iso1 != null && iso2 != null && iso3 != null && iso4 != null) {
          leadingWidget = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 48, height: 48, child: Column(children: [Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: CountryFlag.fromCountryCode(iso1)), Expanded(child: CountryFlag.fromCountryCode(iso2))])), Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: CountryFlag.fromCountryCode(iso3)), Expanded(child: CountryFlag.fromCountryCode(iso4))]))])),
          );
        } else {
          leadingWidget = Icon(Icons.place, color: isVisited ? themeColor : Colors.grey, size: 24);
        }
      }
      else if (displayIsoA2 != null) {
        leadingWidget = ClipRRect(borderRadius: BorderRadius.circular(12), child: CountryFlag.fromCountryCode(displayIsoA2));
      }
      else {
        leadingWidget = Icon(Icons.place, color: isVisited ? themeColor : Colors.grey, size: 24);
      }
    } else {
      leadingWidget = Icon(Icons.circle, size: 12, color: (isVisited || visitedSubCount > 0) ? themeColor : Colors.grey[300]);
    }

    String metricText = _getMetricText(item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (isVisited || visitedSubCount > 0) ? themeColor.withOpacity(0.3) : Colors.grey[200]!, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showLandmarkDetailsModal(context, item, themeColor),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: (isVisited || visitedSubCount > 0) ? themeColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: leadingWidget),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (metricText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(metricText, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey[400], size: 22),
                        onPressed: () => provider.toggleWishlistStatus(item.name),
                      ),
                      Transform.scale(
                        scale: 1.1,
                        child: Checkbox(
                          value: isVisited,
                          activeColor: themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onChanged: (bool? value) {
                            _handleLandmarkToggle(context, item, isVisited, provider);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DiagonalClipper extends CustomClipper<Path> {
  const DiagonalClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width, 0.0);
    path.lineTo(size.width, size.height);
    path.lineTo(0.0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}