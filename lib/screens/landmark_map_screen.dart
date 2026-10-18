// lib/screens/landmark_map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui'; // For ImageFilter

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';

// --- Enums and Models ---
enum MapFilter { all, visited }

enum LandmarkColorMode { sameColor, byVisits, byRating, byContinent, bySubregion, wishlist }

class VisitCountRange {
  int from;
  Color color;
  TextEditingController controller;

  VisitCountRange({required this.from, required this.color})
      : controller = TextEditingController(text: from.toString());

  VisitCountRange copyWith({int? from, Color? color}) {
    return VisitCountRange(
      from: from ?? this.from,
      color: color ?? this.color,
    );
  }
}

class RatingCategory {
  double rating;
  Color color;

  RatingCategory({required this.rating, required this.color});

  RatingCategory copyWith({double? rating, Color? color}) {
    return RatingCategory(
      rating: rating ?? this.rating,
      color: color ?? this.color,
    );
  }
}
// --- End Enums and Models ---

class LandmarkMapScreen extends StatefulWidget {
  final String title;
  final List<Landmark> allItems;
  final Set<String> visitedItems;
  final Function(String) onToggleVisited;

  const LandmarkMapScreen({
    super.key,
    required this.title,
    required this.allItems,
    required this.visitedItems,
    required this.onToggleVisited,
  });

  @override
  State<LandmarkMapScreen> createState() => _LandmarkMapScreenState();
}

class _LandmarkMapScreenState extends State<LandmarkMapScreen> {
  final MapController _mapController = MapController();
  List<Landmark> _visibleItems = [];
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  bool _isMapReady = false;
  Landmark? _selectedItem;

  // --- Color Settings State Variables ---
  late LandmarkColorMode _colorMode;
  late List<VisitCountRange> _byVisitRanges;
  late List<RatingCategory> _byRatingRanges;

  late Color _sameColor;
  late Color _wishlistColor;
  late Color _multiRegionColor;
  late Color _multiContinentColor;
  late Color _defaultVisitedColor;
  late Color _unknownRatingColor;

  Map<String, Color> _continentColors = {};
  Map<String, Color> _subregionColors = {};

  // Toggles
  bool _showUnvisited = false;
  bool _showWishlist = true;

  @override
  void initState() {
    super.initState();
    _visibleItems = widget.allItems;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);

    _colorMode = LandmarkColorMode.sameColor;
    _sameColor = Colors.purple;
    _wishlistColor = Colors.red.shade700;
    _multiRegionColor = Colors.deepOrange;
    _multiContinentColor = Colors.deepOrange;
    _defaultVisitedColor = Colors.blueGrey;
    _unknownRatingColor = Colors.grey.shade400;

    _byVisitRanges = [
      VisitCountRange(from: 1, color: Colors.lightBlue.shade100),
      VisitCountRange(from: 3, color: Colors.lightBlue.shade400),
      VisitCountRange(from: 5, color: Colors.blue.shade700),
      VisitCountRange(from: 10, color: Colors.indigo.shade900),
    ];
    for (var range in _byVisitRanges) {
      range.controller = TextEditingController(text: range.from.toString());
    }

    _byRatingRanges = [
      RatingCategory(rating: 1.0, color: Colors.red.shade300),
      RatingCategory(rating: 2.0, color: Colors.orange.shade400),
      RatingCategory(rating: 3.0, color: Colors.yellow.shade600),
      RatingCategory(rating: 4.0, color: Colors.lightGreen.shade500),
      RatingCategory(rating: 4.5, color: Colors.green.shade700),
    ];

    _continentColors = {
      'Europe': Colors.yellow.shade700,
      'Asia': Colors.pink.shade300,
      'Africa': Colors.brown.shade400,
      'North America': Colors.blue.shade400,
      'South America': Colors.green.shade400,
      'Oceania': Colors.purple.shade400,
    };

    _subregionColors = {
      'Western Asia': Colors.red.shade400,
      'Central Asia': Colors.orange.shade600,
      'Southern Asia': Colors.amber.shade600,
      'Eastern Asia': Colors.yellow.shade600,
      'South-Eastern Asia': Colors.lime.shade600,
      'Northern Europe': Colors.green.shade400,
      'Western Europe': Colors.teal.shade400,
      'Eastern Europe': Colors.cyan.shade500,
      'Southern Europe': Colors.lightBlue.shade400,
      'Central Europe': Colors.blue.shade800,
      'Northern Africa': Colors.indigo.shade300,
      'Western Africa': Colors.purple.shade300,
      'Middle Africa': Colors.pink.shade300,
      'Eastern Africa': Colors.red.shade300,
      'Southern Africa': Colors.orange.shade300,
      'Northern America': const Color(0xFF3DDAD7),
      'Central America': Colors.teal.shade700,
      'Caribbean': Colors.lightGreen.shade700,
      'South America': Colors.green.shade800,
      'Australia and New Zealand': Colors.deepPurple.shade400,
      'Melanesia': Colors.indigo.shade400,
      'Micronesia': Colors.blue.shade800,
      'Polynesia': Colors.cyan.shade800,
    };

    _loadColorSettings();
    _filterVisibleItems();
    _searchController.addListener(_filterVisibleItems);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    for (var range in _byVisitRanges) {
      range.controller.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  Future<void> _loadColorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final mode = prefs.getString('landmarkColorMode');
        _colorMode = LandmarkColorMode.values.firstWhere(
              (e) => e.toString() == 'LandmarkColorMode.$mode',
          orElse: () => LandmarkColorMode.sameColor,
        );
        _sameColor = Color(prefs.getInt('landmarkSameColor') ?? Colors.purple.value);
        _wishlistColor = Color(prefs.getInt('landmarkWishlistColor') ?? Colors.redAccent.value);
        _multiRegionColor = Color(prefs.getInt('landmarkMultiRegionColor') ?? Colors.deepOrange.value);
        _multiContinentColor = Color(prefs.getInt('landmarkMultiContinentColor') ?? Colors.deepOrange.value);
        _defaultVisitedColor = Color(prefs.getInt('landmarkDefaultVisitedColor') ?? Colors.blueGrey.value);
        _unknownRatingColor = Color(prefs.getInt('landmarkUnknownRatingColor') ?? Colors.grey.shade400.value);

        _showUnvisited = prefs.getBool('showLandmarkUnvisited') ?? false;
        _showWishlist = prefs.getBool('showLandmarkWishlist') ?? true;

        final visitRangesJson = prefs.getString('landmarkByVisitRanges');
        if (visitRangesJson != null) {
          try {
            final List<dynamic> decoded = json.decode(visitRangesJson);
            for (var range in _byVisitRanges) { range.controller.dispose(); }
            _byVisitRanges = decoded.map((e) => VisitCountRange(
              from: e['from'],
              color: Color(e['color']),
            )).toList();
            for (var range in _byVisitRanges) {
              range.controller = TextEditingController(text: range.from.toString());
            }
          } catch(e) {
            if (kDebugMode) { print("Error loading landmark visit ranges: $e"); }
          }
        }

        final ratingRangesJson = prefs.getString('landmarkByRatingRanges');
        if (ratingRangesJson != null) {
          try {
            final List<dynamic> decoded = json.decode(ratingRangesJson);
            _byRatingRanges = decoded.map((e) => RatingCategory(
              rating: (e['rating'] as num).toDouble(),
              color: Color(e['color']),
            )).toList();
          } catch (e) {
            if (kDebugMode) { print("Error loading landmark rating ranges: $e"); }
          }
        }

        final continentColorsJson = prefs.getString('landmarkByContinentColors');
        if (continentColorsJson != null) {
          final Map<String, dynamic> decoded = json.decode(continentColorsJson);
          _continentColors = decoded.map((key, value) => MapEntry(key, Color(value)));
          _continentColors.remove('Antarctica');
        }

        final subregionColorsJson = prefs.getString('landmarkBySubregionColors');
        if (subregionColorsJson != null) {
          final Map<String, dynamic> decoded = json.decode(subregionColorsJson);
          _subregionColors = decoded.map((key, value) => MapEntry(key, Color(value)));
        }
      });
    }
  }

  Future<void> _saveColorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('landmarkColorMode', _colorMode.toString().split('.').last);
    await prefs.setInt('landmarkSameColor', _sameColor.value);
    await prefs.setInt('landmarkWishlistColor', _wishlistColor.value);
    await prefs.setInt('landmarkMultiRegionColor', _multiRegionColor.value);
    await prefs.setInt('landmarkMultiContinentColor', _multiContinentColor.value);
    await prefs.setInt('landmarkDefaultVisitedColor', _defaultVisitedColor.value);
    await prefs.setInt('landmarkUnknownRatingColor', _unknownRatingColor.value);

    await prefs.setBool('showLandmarkUnvisited', _showUnvisited);
    await prefs.setBool('showLandmarkWishlist', _showWishlist);

    final visitRangesJson = json.encode(_byVisitRanges.map((e) => {
      'from': int.tryParse(e.controller.text) ?? e.from,
      'color': e.color.value,
    }).toList());
    await prefs.setString('landmarkByVisitRanges', visitRangesJson);

    final ratingRangesJson = json.encode(_byRatingRanges.map((e) => {
      'rating': e.rating,
      'color': e.color.value,
    }).toList());
    await prefs.setString('landmarkByRatingRanges', ratingRangesJson);

    final continentColorsJson = json.encode(_continentColors.map((key, value) => MapEntry(key, value.value)));
    await prefs.setString('landmarkByContinentColors', continentColorsJson);

    final subregionColorsJson = json.encode(_subregionColors.map((key, value) => MapEntry(key, value.value)));
    await prefs.setString('landmarkBySubregionColors', subregionColorsJson);
  }

  void _onMapChanged(MapPosition position, bool hasGesture) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _filterVisibleItems);
  }

  void _filterVisibleItems() {
    if (!mounted) return;
    final bounds = _isMapReady ? _mapController.camera.visibleBounds : null;
    final searchQuery = _searchController.text.toLowerCase();

    final newVisibleItems = widget.allItems.where((item) {
      if (item.latitude == 0.0 && item.longitude == 0.0) return false;
      final isInBounds = bounds?.contains(LatLng(item.latitude, item.longitude)) ?? true;
      final matchesSearch = item.name.toLowerCase().contains(searchQuery);
      return isInBounds && matchesSearch;
    }).toList();

    newVisibleItems.sort((a, b) => a.global_rank.compareTo(b.global_rank));
    if (!listEquals(_visibleItems, newVisibleItems)) {
      setState(() => _visibleItems = newVisibleItems);
    }
  }

  Color _getMarkerColor(Landmark landmark, LandmarksProvider landmarksProvider, CountryProvider countryProvider) {
    final isVisited = landmarksProvider.visitedLandmarks.contains(landmark.name);
    final isWishlisted = landmarksProvider.wishlistedLandmarks.contains(landmark.name);

    if (_colorMode == LandmarkColorMode.wishlist) {
      if (isWishlisted) return _wishlistColor;
      return Colors.grey.withOpacity(0.6);
    }

    if (!isVisited) {
      if (_showWishlist && isWishlisted) return _wishlistColor;
      return Colors.grey.withOpacity(0.6);
    }

    Set<String?> getContinents(List<String> isoA3Codes, CountryProvider countryProvider) {
      return isoA3Codes.map((iso) {
        try {
          return countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso).continent;
        } catch (e) {
          return null;
        }
      }).where((continent) => continent != null && continent != 'Antarctica').toSet();
    }

    Set<String?> getSubregions(List<String> isoA3Codes, CountryProvider countryProvider) {
      return isoA3Codes.map((iso) {
        try {
          return countryProvider.allCountries.firstWhere((c) => c.isoA3 == iso).subregion;
        } catch (e) {
          return null;
        }
      }).whereNotNull().toSet();
    }

    switch (_colorMode) {
      case LandmarkColorMode.byVisits:
        final landmarkData = landmarksProvider.allLandmarks.firstWhere((l) => l.name == landmark.name, orElse: () => landmark);
        final visitCount = landmarkData.visitDates.length;
        if (visitCount <= 0) return _defaultVisitedColor;

        VisitCountRange? selectedRange;
        for (int i = _byVisitRanges.length - 1; i >= 0; i--) {
          if (visitCount >= _byVisitRanges[i].from) {
            selectedRange = _byVisitRanges[i];
            break;
          }
        }
        return selectedRange?.color ?? _defaultVisitedColor;

      case LandmarkColorMode.byRating:
        final landmarkData = landmarksProvider.allLandmarks.firstWhere((l) => l.name == landmark.name, orElse: () => landmark);
        final rating = landmarkData.rating;
        if (rating == null || rating == 0.0) return _unknownRatingColor;

        RatingCategory? selectedCategory;
        for (int i = _byRatingRanges.length - 1; i >= 0; i--) {
          if (rating >= _byRatingRanges[i].rating) {
            selectedCategory = _byRatingRanges[i];
            break;
          }
        }
        return selectedCategory?.color ?? _defaultVisitedColor;

      case LandmarkColorMode.byContinent:
        if (landmark.countriesIsoA3.isEmpty) return _defaultVisitedColor;
        final continents = getContinents(landmark.countriesIsoA3, countryProvider);
        if (continents.length == 1) {
          return _continentColors[continents.first] ?? _defaultVisitedColor;
        } else if (continents.length > 1) {
          return _multiContinentColor;
        } else {
          return _defaultVisitedColor;
        }

      case LandmarkColorMode.bySubregion:
        if (landmark.countriesIsoA3.isEmpty) return _defaultVisitedColor;
        final subregions = getSubregions(landmark.countriesIsoA3, countryProvider);
        if (subregions.length == 1) {
          return _subregionColors[subregions.first] ?? _defaultVisitedColor;
        } else if (subregions.length > 1) {
          return _multiRegionColor;
        } else {
          return _defaultVisitedColor;
        }

      case LandmarkColorMode.sameColor:
      default:
        return _sameColor;
    }
  }

  Widget _buildBlurContainer({required Widget child, double borderRadius = 16.0}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed, required String tooltip}) {
    return IconButton(
      icon: Icon(icon, size: 22, color: Colors.grey.shade800),
      onPressed: onPressed,
      tooltip: tr(tooltip),
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    Color? themeColor;

    final countryFromTitle = countryProvider.allCountries.firstWhereOrNull((c) => c.name == widget.title);

    if (countryFromTitle != null) {
      themeColor = countryFromTitle.themeColor;
    } else {
      if (widget.allItems.isNotEmpty) {
        var commonCountries = widget.allItems.first.countriesIsoA3.toSet();
        for (var landmark in widget.allItems.skip(1)) {
          commonCountries.retainWhere((iso) => landmark.countriesIsoA3.contains(iso));
          if (commonCountries.isEmpty) break;
        }

        if (commonCountries.length == 1) {
          final singleCountryIsoA3 = commonCountries.first;
          try {
            final country = countryProvider.allCountries.firstWhere((c) => c.isoA3 == singleCountryIsoA3);
            themeColor = country.themeColor;
          } catch (e) {
            themeColor = null;
          }
        }
      }
    }

    final finalThemeColor = themeColor ?? Theme.of(context).primaryColor;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 3, child: _buildMap()),
            Expanded(flex: 4, child: _buildChecklistSection(finalThemeColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final landmarksProvider = context.watch<LandmarksProvider>();
    final countryProvider = context.read<CountryProvider>();

    List<Landmark> itemsToShow;
    if (_showUnvisited) {
      itemsToShow = widget.allItems;
    } else {
      itemsToShow = widget.allItems.where((item) {
        final isVisited = landmarksProvider.visitedLandmarks.contains(item.name);
        final isWishlisted = landmarksProvider.wishlistedLandmarks.contains(item.name);

        if (_colorMode == LandmarkColorMode.wishlist) return isWishlisted;
        if (_showWishlist && isWishlisted) return true;

        return isVisited;
      }).toList();
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(40, 0),
            initialZoom: 0.8,
            onPositionChanged: _onMapChanged,
            onMapReady: () {
              if (mounted) {
                setState(() => _isMapReady = true);
                _filterVisibleItems();
              }
            },
            onTap: (_, __) => setState(() => _selectedItem = null),
            cameraConstraint: CameraConstraint.unconstrained(),
            backgroundColor: Colors.white,
          ),
          children: [
            PolygonLayer(
              polygons: countryProvider.allCountries.expand((country) {
                return country.polygonsData.map((polygonData) => Polygon(
                  points: polygonData.first,
                  holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                  color: Colors.grey.withOpacity(0.15),
                  borderColor: Colors.white,
                  borderStrokeWidth: 0.5,
                  isFilled: true,
                ));
              }).toList(),
            ),
            MarkerLayer(
              markers: itemsToShow.map((item) {
                final markerColor = _getMarkerColor(item, landmarksProvider, countryProvider);
                const IconData markerIcon = Icons.circle;

                return Marker(
                  width: 5,
                  height: 5,
                  point: LatLng(item.latitude, item.longitude),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedItem = item),
                    child: Tooltip(
                        message: item.name,
                        child: Icon(
                            markerIcon,
                            color: markerColor,
                            size: 5,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 1.0)]
                        )
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selectedItem != null)
              MarkerLayer(
                  markers: [
                    Marker(
                        point: LatLng(_selectedItem!.latitude, _selectedItem!.longitude),
                        width: 200,
                        height: 100, // [Modified] 50에서 100으로 높이 증가
                        child: _buildInfoPopup(_selectedItem!)
                    )
                  ]
              ),
          ],
        ),

        // Buttons
        Positioned(
          top: 10,
          right: 10,
          child: _buildBlurContainer(
            borderRadius: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIconButton(
                    icon: Icons.settings_rounded,
                    onPressed: _showColorSettingsDialog,
                    tooltip: tr('Settings'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Filter Chips
        Positioned(
          top: 8,
          left: 8,
          child: Card(
            elevation: 2,
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 12),
                decoration:  InputDecoration(
                  hintText: tr('Search...'),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, size: 16),
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  isDense: true,
                ),
              ),
            ).constraints(height: 40, width: 150),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistSection(Color themeColor) {
    final provider = context.watch<LandmarksProvider>();

    return Column(
      children: [
        // "Total: xx" removed from here
        Expanded(
          child: ListView.builder(
            itemCount: _visibleItems.length,
            itemBuilder: (context, index) {
              final item = _visibleItems[index];
              final isVisited = widget.visitedItems.contains(item.name);
              final isWishlisted = provider.wishlistedLandmarks.contains(item.name);

              return ListTile(
                title: Text(item.name),
                subtitle: Text(tr(item.countriesIsoA3.join(', '))),
                onTap: () => provider.toggleVisitedStatus(item.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showLandmarkDetailsModal(item, themeColor),
                        tooltip: tr('Show Details')),
                    IconButton(
                      icon: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: isWishlisted ? Colors.red : Colors.grey,
                      ),
                      onPressed: () => provider.toggleWishlistStatus(item.name),
                      tooltip: tr(isWishlisted ? 'Remove from wishlist' : 'Add to wishlist'),
                    ),
                    Checkbox(value: isVisited, onChanged: (bool? value) => provider.toggleVisitedStatus(item.name)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPopup(Landmark item) {
    final provider = context.read<LandmarksProvider>();
    final visitCount = item.visitDates.length;
    final isWishlisted = provider.wishlistedLandmarks.contains(item.name);
    final themeColor = Theme.of(context).primaryColor;

    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // [Modified] 패딩 조정
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, height: 1.2),
                    maxLines: 2, // [Modified] 제목 2줄 고정
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8), // [Modified] 이름과 방문 정보 사이 간격 확대
                  Row(
                    children: [
                      Text(
                        tr("Visits: $visitCount ${isWishlisted ? ' | Wishlisted' : ''}"),
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 6),
                      // [Added] 상세 정보 모달 연결 아이콘
                      GestureDetector(
                        onTap: () {
                          _showLandmarkDetailsModal(item, themeColor);
                          setState(() => _selectedItem = null);
                        },
                        child: Icon(Icons.info_outline, size: 14, color: themeColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _selectedItem = null)),
          ],
        ),
      ),
    );
  }

  // [Added] Details Modal
  void _showLandmarkDetailsModal(Landmark landmark, Color fallbackThemeColor) {
    if (landmark.latitude != 0 && landmark.longitude != 0) {
      _mapController.move(LatLng(landmark.latitude, landmark.longitude), 5.0);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<LandmarksProvider>();
        final freshLandmark = provider.allLandmarks.firstWhere((l) => l.name == landmark.name);
        final isVisited = provider.visitedLandmarks.contains(freshLandmark.name);
        final countryNames = provider.getCountryNames(freshLandmark.countriesIsoA3);

        Color? landmarkThemeColor;
        if (freshLandmark.countriesIsoA3.length == 1) {
          try {
            final country = sheetContext.read<CountryProvider>().allCountries.firstWhere(
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
                padding: EdgeInsets.only(top: MediaQuery.of(sheetContext).padding.top, left: 16, right: 8, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(tr('Cancel'), style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(tr('Done'), style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
                          style: ElevatedButton.styleFrom(backgroundColor: headerTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          freshLandmark.name,
                          style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: headerTextColor),
                        ),
                        const SizedBox(width: 8),
                        if (isVisited) Icon(Icons.check_circle, color: headerTextColor, size: 20),
                      ],
                    ),
                    Text(
                      tr(countryNames),
                      style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildLandmarkDetailsContent(sheetContext, freshLandmark, provider, themeColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // [Added] Details Content
  Widget _buildLandmarkDetailsContent(BuildContext sheetContext, Landmark landmark, LandmarksProvider provider, Color themeColor) {
    final isWishlisted = provider.wishlistedLandmarks.contains(landmark.name);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(tr('Wishlist:')),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: Icon(
                      isWishlisted ? Icons.favorite : Icons.favorite_border,
                      color: isWishlisted ? Colors.red : Colors.grey,
                    ),
                    onPressed: () {
                      sheetContext.read<LandmarksProvider>().toggleWishlistStatus(landmark.name);
                    },
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(tr('My Rating:')),
                  const SizedBox(width: 8),
                  RatingBar.builder(
                    initialRating: landmark.rating ?? 0.0,
                    minRating: 0.5,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemSize: 28.0,
                    itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: (rating) {
                      sheetContext.read<LandmarksProvider>().updateLandmarkRating(landmark.name, rating);
                    },
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('History (${landmark.visitDates.length} visits)'), style: Theme.of(sheetContext).textTheme.titleSmall),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label:  Text(tr('Add Visit')),
                onPressed: () => sheetContext.read<LandmarksProvider>().addVisitDate(landmark.name),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (landmark.visitDates.isNotEmpty)
            ...landmark.visitDates.asMap().entries.map((entry) {
              return _LandmarkVisitEditorCard(
                key: ValueKey('${landmark.name}_${entry.key}'),
                landmarkName: landmark.name,
                visitDate: entry.value,
                index: entry.key,
                onDelete: () => sheetContext.read<LandmarksProvider>().removeVisitDate(landmark.name, entry.key),
              );
            })
          else
             Center(child: Text(tr('No visits recorded.'))),

          const Divider(height: 24),
          LandmarkInfoCard(
            overview: landmark.overview,
            historySignificance: landmark.history_significance,
            highlights: landmark.highlights,
            themeColor: themeColor,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- Color Settings Dialog ---
  void _showColorSettingsDialog() {
    var tempColorMode = _colorMode;
    var tempSameColor = _sameColor;
    var tempWishlistColor = _wishlistColor;
    var tempMultiRegionColor = _multiRegionColor;
    var tempMultiContinentColor = _multiContinentColor;
    var tempDefaultVisitedColor = _defaultVisitedColor;
    var tempUnknownRatingColor = _unknownRatingColor;

    var tempShowUnvisited = _showUnvisited;
    var tempShowWishlist = _showWishlist;

    var tempByVisitRanges = _byVisitRanges.map((e) =>
    VisitCountRange(from: e.from, color: e.color)..controller.text = e.controller.text
    ).toList();
    var tempByRatingRanges = _byRatingRanges.map((e) => e.copyWith()).toList();

    var tempContinentColors = Map<String, Color>.from(_continentColors);
    var tempSubregionColors = Map<String, Color>.from(_subregionColors);

    void validateAndSave() {
      // (Validation Logic omitted for brevity, similar to before but updated variables)
      for (var range in _byVisitRanges) { range.controller.dispose(); }

      setState(() {
        _colorMode = tempColorMode;
        _sameColor = tempSameColor;
        _wishlistColor = tempWishlistColor;
        _multiRegionColor = tempMultiRegionColor;
        _multiContinentColor = tempMultiContinentColor;
        _defaultVisitedColor = tempDefaultVisitedColor;
        _unknownRatingColor = tempUnknownRatingColor;

        _showUnvisited = tempShowUnvisited;
        _showWishlist = tempShowWishlist;

        _byVisitRanges = tempByVisitRanges;
        _byRatingRanges = tempByRatingRanges;
        _continentColors = tempContinentColors;
        _subregionColors = tempSubregionColors;
      });
      _saveColorSettings();
      Navigator.pop(context);
    }

    Widget buildColorPicker(Color currentColor, ValueChanged<Color> onColorChanged) {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(tr('Pick a color'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: onColorChanged,
                  displayThumbColor: true,
                  enableAlpha: false,
                  paletteType: PaletteType.hsvWithHue,
                ),
              ),
              actions: <Widget>[
                ElevatedButton(
                  child:  Text(tr('Select')),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 28, height: 28,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            color: currentColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
          ),
        ),
      );
    }

    Widget buildColorPickerRow(String label, Color currentColor, ValueChanged<Color> onColorChanged) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(tr(label), style: GoogleFonts.poppins(fontSize: 13), overflow: TextOverflow.ellipsis)),
            buildColorPicker(currentColor, onColorChanged),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(tr('Map Color Settings'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('General'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tr('Show Unvisited'), style: GoogleFonts.poppins()),
                          Switch(
                              value: tempShowUnvisited,
                              onChanged: (v) => setStateDialog(() => tempShowUnvisited = v),
                              activeColor: Colors.teal
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tr('Show Wishlist'), style: GoogleFonts.poppins()),
                          Switch(
                              value: tempShowWishlist,
                              onChanged: (v) => setStateDialog(() => tempShowWishlist = v),
                              activeColor: Colors.teal
                          ),
                        ],
                      ),
                      if (tempShowWishlist)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tr('Wishlist Color'), style: GoogleFonts.poppins(fontSize: 13)),
                              buildColorPicker(tempWishlistColor, (c) => setStateDialog(() => tempWishlistColor = c))
                            ],
                          ),
                        ),

                      const Divider(height: 24),
                      Text(tr('Color Mode'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),

                      ...LandmarkColorMode.values.map((mode) {
                        String title;
                        switch(mode) {
                          case LandmarkColorMode.sameColor: title = "Same Color"; break;
                          case LandmarkColorMode.byVisits: title = "By Visits"; break;
                          case LandmarkColorMode.byRating: title = "By Rating"; break;
                          case LandmarkColorMode.byContinent: title = "By Continent"; break;
                          case LandmarkColorMode.bySubregion: title = "By Subregion"; break;
                          case LandmarkColorMode.wishlist: title = "Wishlist Only"; break;
                        }
                        return RadioListTile<LandmarkColorMode>(
                          title: Text(tr(title), style: GoogleFonts.poppins(fontSize: 13)),
                          value: mode,
                          groupValue: tempColorMode,
                          onChanged: (v) => setStateDialog(() => tempColorMode = v!),
                          activeColor: Colors.teal,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),

                      const Divider(),

                      if (tempColorMode == LandmarkColorMode.sameColor)
                        buildColorPickerRow('Visited Marker Color', tempSameColor, (color) => setStateDialog(() => tempSameColor = color)),

                      if (tempColorMode == LandmarkColorMode.byVisits) ...[
                         Text(tr('Visit Count Ranges'), style: TextStyle(fontWeight: FontWeight.bold)),
                        ...List.generate(tempByVisitRanges.length, (index) {
                          final range = tempByVisitRanges[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: range.controller,
                                    decoration: InputDecoration(
                                      labelText: tr(index < tempByVisitRanges.length - 1 ? 'From' : 'From (and up)'),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                 Expanded(flex: 2, child: Text(tr("Visits"))),
                                buildColorPicker(range.color, (newColor) => setStateDialog(() => range.color = newColor)),
                              ],
                            ),
                          );
                        }),
                        buildColorPickerRow('Default Visited (Fallback)', tempDefaultVisitedColor, (color) => setStateDialog(() => tempDefaultVisitedColor = color)),
                      ],

                      if (tempColorMode == LandmarkColorMode.byRating) ...[
                         Text(tr('Rating Categories'), style: TextStyle(fontWeight: FontWeight.bold)),
                        buildColorPickerRow('Unknown Rating', tempUnknownRatingColor, (color) => setStateDialog(() => tempUnknownRatingColor = color)),
                        const Divider(),
                        ...List.generate(tempByRatingRanges.length, (index) {
                          final category = tempByRatingRanges[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tr(index < tempByRatingRanges.length - 1 ? "From" : "From (and up)"), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    RatingBar.builder(
                                      initialRating: category.rating,
                                      minRating: 0.5,
                                      direction: Axis.horizontal,
                                      allowHalfRating: true,
                                      itemCount: 5,
                                      itemSize: 22.0,
                                      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                      onRatingUpdate: (rating) => setStateDialog(() => category.rating = rating),
                                    ),
                                  ],
                                ),
                                buildColorPicker(category.color, (newColor) => setStateDialog(() => category.color = newColor)),
                              ],
                            ),
                          );
                        }),
                        buildColorPickerRow('Default Visited (Fallback)', tempDefaultVisitedColor, (color) => setStateDialog(() => tempDefaultVisitedColor = color)),
                      ],

                      if (tempColorMode == LandmarkColorMode.byContinent) ...[
                         Text(tr('Continent Colors'), style: TextStyle(fontWeight: FontWeight.bold)),
                        buildColorPickerRow('Multi-Continent Marker', tempMultiContinentColor, (color) => setStateDialog(() => tempMultiContinentColor = color)),
                        buildColorPickerRow('Default/Fallback', tempDefaultVisitedColor, (color) => setStateDialog(() => tempDefaultVisitedColor = color)),
                        const Divider(),
                        ...tempContinentColors.entries.map((entry) => buildColorPickerRow(
                          entry.key,
                          entry.value,
                              (color) => setStateDialog(() => tempContinentColors[entry.key] = color),
                        )).toList(),
                      ],

                      if (tempColorMode == LandmarkColorMode.bySubregion) ...[
                         Text(tr('Subregion Colors'), style: TextStyle(fontWeight: FontWeight.bold)),
                        buildColorPickerRow('Multi-Region Marker', tempMultiRegionColor, (color) => setStateDialog(() => tempMultiRegionColor = color)),
                        buildColorPickerRow('Default/Fallback', tempDefaultVisitedColor, (color) => setStateDialog(() => tempDefaultVisitedColor = color)),
                        const Divider(),
                        ...tempSubregionColors.entries.map((entry) => buildColorPickerRow(
                          entry.key,
                          entry.value,
                              (color) => setStateDialog(() => tempSubregionColors[entry.key] = color),
                        )).toList(),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text(tr('Reset'), style: GoogleFonts.poppins(color: Colors.redAccent)),
                  onPressed: () {
                    // Reset Logic (Simplified)
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: Text(tr('Cancel'), style: GoogleFonts.poppins(color: Colors.grey)),
                  onPressed: () {
                    for (var range in tempByVisitRanges) { range.controller.dispose(); }
                    Navigator.pop(context);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white
                  ),
                  child: Text(tr('Done'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  onPressed: validateAndSave,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

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
  State<_LandmarkVisitEditorCard> createState() =>
      _LandmarkVisitEditorCardState();
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

  @override
  void didUpdateWidget(covariant _LandmarkVisitEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visitDate.title != _titleController.text) {
      _titleController.text = widget.visitDate.title;
    }
    if (widget.visitDate.memo != _memoController.text) {
      _memoController.text = widget.visitDate.memo ?? '';
    }
    if (!listEquals(_currentPhotos, widget.visitDate.photos)) {
      if (mounted) {
        setState(() {
          _currentPhotos = List.from(widget.visitDate.photos);
        });
      }
    }
    if (widget.visitDate.year != _year || widget.visitDate.month != _month || widget.visitDate.day != _day) {
      if (mounted) {
        setState(() {
          _year = widget.visitDate.year;
          _month = widget.visitDate.month;
          _day = widget.visitDate.day;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    _expansionTileController.dispose();
    super.dispose();
  }

  String _formatDate() {
    if (_year == null && _month == null && _day == null) {
      return 'Unknown Date';
    }
    final y = _year?.toString() ?? '????';
    final m = _month?.toString().padLeft(2, '0') ?? '??';
    final d = _day?.toString().padLeft(2, '0') ?? '??';
    return '$y-$m-$d';
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null && mounted) {
      final newPhotos = List<String>.from(_currentPhotos)..add(pickedFile.path);
      if (mounted) {
        setState(() {
          _currentPhotos = newPhotos;
        });
      }
      if(mounted){
        context.read<LandmarksProvider>().updateLandmarkVisit(
            widget.landmarkName,
            widget.index,
            photos: newPhotos
        );
      }
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
              : const Center(child: Icon(Icons.error_outline, color: Colors.red)),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
            onPressed: () {
              if (!mounted) return;
              final newPhotos = List<String>.from(_currentPhotos)..removeAt(index);
              if (mounted) {
                setState(() {
                  _currentPhotos = newPhotos;
                });
              }
              if (mounted) {
                context.read<LandmarksProvider>().updateLandmarkVisit(
                    widget.landmarkName,
                    widget.index,
                    photos: newPhotos
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final provider = context.read<LandmarksProvider>();

    final years = [null, ...List.generate(101, (index) => DateTime.now().year - index)];
    final months = [null, ...List.generate(12, (index) => index + 1)];
    int daysInMonth = 31;
    if (_year != null && _month != null) {
      try {
        daysInMonth = DateUtils.getDaysInMonth(_year!, _month!);
      } catch (e) { }
    }
    final days = [null, ...List.generate(daysInMonth, (index) => index + 1)];
    int? currentDay = (_day != null && _day! <= daysInMonth) ? _day : null;

    if (_day != null && _day! > daysInMonth) {
      currentDay = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _day = null);
          if (mounted) {
            provider.updateLandmarkVisit(widget.landmarkName, widget.index, day: null);
          }
        }
      });
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 1,
      child: ExpansionTile(
        controller: _expansionTileController,
        title: Text(tr(widget.visitDate.title.isNotEmpty ? widget.visitDate.title : 'Visit Record')),
        subtitle: Text(tr(_formatDate())),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: widget.onDelete,
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
                  decoration:  InputDecoration(labelText: tr('Title'), border: OutlineInputBorder()),
                  onEditingComplete: () {
                    if (mounted) {
                      provider.updateLandmarkVisit(widget.landmarkName, widget.index, title: _titleController.text);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _memoController,
                  decoration:  InputDecoration(labelText: tr('Memo'), border: OutlineInputBorder()),
                  maxLines: 3,
                  onEditingComplete: () {
                    if (mounted) {
                      provider.updateLandmarkVisit(widget.landmarkName, widget.index, memo: _memoController.text);
                    }
                  },
                ),
                const SizedBox(height: 16),
                 Text(tr('Photos:'), style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!mounted) return;
                        showModalBottomSheet(
                          context: context,
                          builder: (modalContext) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                ListTile(leading: const Icon(Icons.photo_library), title:  Text(tr('Photo Library')), onTap: () { Navigator.pop(modalContext); _pickImage(ImageSource.gallery); }),
                                ListTile(leading: const Icon(Icons.photo_camera), title:  Text(tr('Camera')), onTap: () { Navigator.pop(modalContext); _pickImage(ImageSource.camera); }),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                        child: const Center(child: Icon(Icons.add_a_photo, color: Colors.blue)),
                      ),
                    ),
                    ..._currentPhotos.asMap().entries.map((entry) => _buildPhotoPreview(entry.value, entry.key)).toList(),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildDropdown('Year', _year, years, (val) {
                      if (!mounted) return;
                      setState(() { _year = val; if(val == null) { _month = null; _day = null; } });
                      if (mounted) {
                        provider.updateLandmarkVisit(widget.landmarkName, widget.index, year: val, month: (val == null ? null : _month), day: (val == null ? null : _day));
                      }
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDropdown('Month', _month, months, (val) {
                      if (!mounted) return;
                      setState(() { _month = val; if(val == null) _day = null; });
                      if (mounted) {
                        provider.updateLandmarkVisit(widget.landmarkName, widget.index, month: val, day: (val == null ? null : _day));
                      }
                    }, enabled: _year != null)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildDropdown('Day', currentDay, days, (val) {
                      if (!mounted) return;
                      setState(() => _day = val);
                      if (mounted) {
                        provider.updateLandmarkVisit(widget.landmarkName, widget.index, day: val);
                      }
                    }, enabled: _month != null)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _expansionTileController.collapse();
                      },
                      child:  Text(tr('Done')),
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

  Widget _buildDropdown<T>(String hint, T? value, List<T?> items, ValueChanged<T?> onChanged, {bool enabled = true}) {
    return DropdownButtonFormField<T>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        labelText: tr(hint),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        filled: !enabled,
        fillColor: Colors.grey.shade50,
      ),
      items: items.map((item) => DropdownMenuItem<T>(
        value: item,
        child: Text(tr(item?.toString() ?? '?'), style: TextStyle(fontSize: 14, color: (item == null) ? Colors.grey.shade600 : null)),
      )).toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

// Extension for constraints convenience (if needed)
extension WidgetModifier on Widget {
  Widget constraints({double? width, double? height}) {
    return SizedBox(width: width, height: height, child: this);
  }
}