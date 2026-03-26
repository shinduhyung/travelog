// lib/screens/unesco_map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui'; // For ImageFilter

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_flags/country_flags.dart';

import 'package:jidoapp/models/unesco_model.dart';
import 'package:jidoapp/models/visit_date_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/widgets/landmark_info_card.dart';

enum UnescoColorMode { sameColor, byVisits, byType, byRating, byContinent, wishlist }

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

class UnescoMapScreen extends StatefulWidget {
  final String title;
  final List<UnescoSite> allItems;
  final Set<String> visitedItems;
  final Function(String) onToggleVisited;

  const UnescoMapScreen({
    super.key,
    required this.title,
    required this.allItems,
    required this.visitedItems,
    required this.onToggleVisited,
  });

  @override
  State<UnescoMapScreen> createState() => _UnescoMapScreenState();
}

class _UnescoMapScreenState extends State<UnescoMapScreen> {
  final MapController _mapController = MapController();
  List<UnescoSite> _visibleItems = [];
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  bool _isMapReady = false;

  // Highlighting State
  UnescoSite? _selectedItem; // For the large popup
  LatLng? _tempHighlightLocation; // For the grey dot (List tap)
  String? _highlightedId; // To track selection state in list (border)

  // --- Color Settings State Variables ---
  late UnescoColorMode _colorMode;
  late List<VisitCountRange> _byVisitRanges;
  late List<RatingCategory> _byRatingRanges;
  late Color _sameColor;
  late Color _multiRegionColor;
  late Color _multiContinentColor;
  late Color _defaultVisitedColor;
  late Color _unknownRatingColor;
  late Color _wishlistColor;

  Map<String, Color> _continentColors = {};
  Map<String, Color> _typeColors = {}; // Colors for Types

  // Toggles
  bool _showUnvisited = false;
  bool _showWishlist = true;

  @override
  void initState() {
    super.initState();
    _visibleItems = widget.allItems;

    _typeColors = {
      'Cultural': Colors.orange.shade600,
      'Natural': Colors.green.shade600,
      'Mixed': Colors.teal.shade600,
    };

    _colorMode = UnescoColorMode.sameColor;
    _sameColor = _typeColors['Cultural']!;
    _wishlistColor = Colors.red.shade700;
    _multiRegionColor = Colors.deepOrange;
    _multiContinentColor = Colors.deepOrange;
    _defaultVisitedColor = Colors.blueGrey;
    _unknownRatingColor = Colors.grey.shade400;

    _byVisitRanges = [
      VisitCountRange(from: 1, color: Colors.lightGreen.shade200),
      VisitCountRange(from: 2, color: Colors.green.shade400),
      VisitCountRange(from: 3, color: Colors.green.shade700),
      VisitCountRange(from: 5, color: Colors.teal.shade900),
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
    super.dispose();
  }

  Future<void> _loadColorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final mode = prefs.getString('unescoColorMode');
        _colorMode = UnescoColorMode.values.firstWhere(
              (e) => e.toString() == 'UnescoColorMode.$mode',
          orElse: () => UnescoColorMode.sameColor,
        );
        _sameColor = Color(
            prefs.getInt('unescoSameColor') ?? _typeColors['Cultural']!.value);
        _wishlistColor = Color(
            prefs.getInt('unescoWishlistColor') ?? Colors.red.shade700.value);

        _showUnvisited = prefs.getBool('showUnescoUnvisited') ?? false;
        _showWishlist = prefs.getBool('showUnescoWishlist') ?? true;

        final visitRangesJson = prefs.getString('unescoByVisitRanges');
        if (visitRangesJson != null) {
          try {
            final List<dynamic> decoded = json.decode(visitRangesJson);
            for (var range in _byVisitRanges) {
              range.controller.dispose();
            }
            _byVisitRanges = decoded
                .map((e) => VisitCountRange(
              from: e['from'],
              color: Color(e['color']),
            ))
                .toList();
            for (var range in _byVisitRanges) {
              range.controller =
                  TextEditingController(text: range.from.toString());
            }
          } catch (e) {
            if (kDebugMode) print('Error loading visit ranges: $e');
          }
        }

        final typeColorsJson = prefs.getString('unescoTypeColors');
        if (typeColorsJson != null) {
          final Map<String, dynamic> decoded = json.decode(typeColorsJson);
          _typeColors = decoded.map((key, value) => MapEntry(key, Color(value)));
        }
      });
    }
  }

  Future<void> _saveColorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'unescoColorMode', _colorMode.toString().split('.').last);
    await prefs.setInt('unescoSameColor', _sameColor.value);
    await prefs.setInt('unescoWishlistColor', _wishlistColor.value);

    await prefs.setBool('showUnescoUnvisited', _showUnvisited);
    await prefs.setBool('showUnescoWishlist', _showWishlist);

    final visitRangesJson = json.encode(_byVisitRanges
        .map((e) => {
      'from': int.tryParse(e.controller.text) ?? e.from,
      'color': e.color.value,
    })
        .toList());
    await prefs.setString('unescoByVisitRanges', visitRangesJson);

    final typeColorsJson = json.encode(_typeColors.map((key, value) => MapEntry(key, value.value)));
    await prefs.setString('unescoTypeColors', typeColorsJson);
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
      bool anyLocationInBounds = false;
      if (bounds != null) {
        for (var loc in item.locations) {
          if (bounds.contains(LatLng(loc.latitude, loc.longitude))) {
            anyLocationInBounds = true;
            break;
          }
        }
      } else {
        anyLocationInBounds = true;
      }

      final matchesSearch = item.name.toLowerCase().contains(searchQuery);
      return anyLocationInBounds && matchesSearch;
    }).toList();

    newVisibleItems.sort((a, b) => a.name.compareTo(b.name));
    if (!listEquals(_visibleItems, newVisibleItems)) {
      setState(() => _visibleItems = newVisibleItems);
    }
  }

  // --- Territory Flag Helper ---
  String? _getDisplayIsoA2(UnescoSite site, CountryProvider countryProvider) {
    if (site.city.contains('Macao') || site.countriesIsoA3.contains('MAC')) return 'MO';
    if (site.countriesIsoA3.contains('GRL')) return 'GL';
    if (site.countriesIsoA3.contains('PYF')) return 'PF';
    if (site.countriesIsoA3.contains('PRI')) return 'PR';
    if (site.countriesIsoA3.contains('BMU')) return 'BM';
    if (site.countriesIsoA3.contains('GIB')) return 'GI';
    if (site.countriesIsoA3.contains('PCN')) return 'PN';

    if (site.countriesIsoA3.length > 1) {
      return null;
    } else if (site.countriesIsoA3.isNotEmpty) {
      final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == site.countriesIsoA3.first);
      return c?.isoA2;
    }
    return null;
  }

  Color _getMarkerColor(UnescoSite site, UnescoProvider unescoProvider,
      CountryProvider countryProvider, bool isSubVisited) {
    final isMainVisited = unescoProvider.visitedSites.contains(site.name);
    final isVisited = isMainVisited || isSubVisited;
    final isWishlisted = unescoProvider.wishlistedSites.contains(site.name);

    if (_colorMode == UnescoColorMode.wishlist) {
      if (isWishlisted) return _wishlistColor;
      return Colors.grey.withOpacity(0.6);
    }

    if (!isVisited) {
      if (_showWishlist && isWishlisted) return _wishlistColor;
      return Colors.grey.withOpacity(0.6);
    }

    Set<String?> getContinents(List<String> isoA3Codes) {
      return isoA3Codes.map((iso) {
        try {
          return countryProvider.allCountries
              .firstWhere((c) => c.isoA3 == iso)
              .continent;
        } catch (e) {
          return null;
        }
      }).where((c) => c != null && c != 'Antarctica').toSet();
    }

    switch (_colorMode) {
      case UnescoColorMode.byType:
        return _typeColors[site.type] ?? _typeColors['Cultural']!;

      case UnescoColorMode.byVisits:
        final visitCount = site.visitDates.length;
        if (visitCount <= 0 && !isSubVisited) return _defaultVisitedColor;

        VisitCountRange? selectedRange;
        for (int i = _byVisitRanges.length - 1; i >= 0; i--) {
          if (visitCount >= _byVisitRanges[i].from) {
            selectedRange = _byVisitRanges[i];
            break;
          }
        }
        return selectedRange?.color ?? _defaultVisitedColor;

      case UnescoColorMode.byRating:
        final rating = site.rating;
        if (rating == null || rating == 0.0) return _unknownRatingColor;
        RatingCategory? selectedCategory;
        for (int i = _byRatingRanges.length - 1; i >= 0; i--) {
          if (rating >= _byRatingRanges[i].rating) {
            selectedCategory = _byRatingRanges[i];
            break;
          }
        }
        return selectedCategory?.color ?? _defaultVisitedColor;

      case UnescoColorMode.byContinent:
        final continents = getContinents(site.countriesIsoA3);
        if (continents.length == 1) {
          return _continentColors[continents.first] ?? _defaultVisitedColor;
        } else if (continents.length > 1) {
          return _multiContinentColor;
        }
        return _defaultVisitedColor;

      case UnescoColorMode.sameColor:
      default:
        return _sameColor;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Natural':
        return Icons.landscape;
      case 'Mixed':
        return Icons.auto_awesome;
      case 'Cultural':
      default:
        return Icons.account_balance;
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

  void _onListItemTap(UnescoSite item, UnescoSubLocation? specificLocation) {
    String currentId = specificLocation != null
        ? "${item.name}_${specificLocation.name}"
        : item.name;

    if (_highlightedId == currentId) {
      setState(() {
        _highlightedId = null;
        _tempHighlightLocation = null;
      });
    } else {
      final targetLat = specificLocation?.latitude ?? item.locations.first.latitude;
      final targetLng = specificLocation?.longitude ?? item.locations.first.longitude;
      final targetPoint = LatLng(targetLat, targetLng);

      _mapController.move(targetPoint, _mapController.camera.zoom);

      setState(() {
        _highlightedId = currentId;
        _tempHighlightLocation = targetPoint;
        _selectedItem = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 3, child: _buildMap()),
            Expanded(flex: 4, child: _buildChecklistSection(themeColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final unescoProvider = context.watch<UnescoProvider>();
    final countryProvider = context.read<CountryProvider>();

    List<UnescoSite> itemsToShow;

    if (_showUnvisited) {
      itemsToShow = widget.allItems;
    } else {
      itemsToShow = widget.allItems.where((item) {
        final visitedSubCount = unescoProvider.getVisitedSubLocationCount(item.name);
        final isVisited = unescoProvider.visitedSites.contains(item.name) || visitedSubCount > 0;
        final isWishlisted = unescoProvider.wishlistedSites.contains(item.name);

        if (_colorMode == UnescoColorMode.wishlist) return isWishlisted;
        if (_showWishlist && isWishlisted) return true;

        return isVisited;
      }).toList();
    }

    List<Marker> markers = [];
    for (var site in itemsToShow) {
      for (var location in site.locations) {
        final isSubVisited = unescoProvider.isSubLocationVisited(site.name, location.name);
        final markerColor = _getMarkerColor(
            site, unescoProvider, countryProvider, isSubVisited);

        markers.add(
          Marker(
            width: 5,
            height: 5,
            point: LatLng(location.latitude, location.longitude),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedItem = site;
                _tempHighlightLocation = null;
                _highlightedId = null;
              }),
              child: Tooltip(
                message: "${site.name}\n(${location.name})",
                child: Icon(
                  Icons.circle,
                  color: markerColor,
                  size: 5,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 1.0)
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    if (_tempHighlightLocation != null) {
      markers.add(
        Marker(
          width: 14,
          height: 14,
          point: _tempHighlightLocation!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
          ),
        ),
      );
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
            onTap: (_, __) => setState(() {
              _selectedItem = null;
              _tempHighlightLocation = null;
              _highlightedId = null;
            }),
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
            MarkerLayer(markers: markers),
            if (_selectedItem != null)
              MarkerLayer(markers: [
                Marker(
                    point: LatLng(_selectedItem!.locations.first.latitude,
                        _selectedItem!.locations.first.longitude),
                    width: 280,
                    height: 100,
                    child: _buildInfoPopup(_selectedItem!))
              ]),
          ],
        ),

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
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed, required String tooltip}) {
    return IconButton(
      icon: Icon(icon, size: 22, color: Colors.grey.shade800),
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }

  Widget _buildInfoPopup(UnescoSite item) {
    final provider = context.read<UnescoProvider>();
    final countryProvider = context.read<CountryProvider>();
    final visitedSubCount = provider.getVisitedSubLocationCount(item.name);
    final totalSubCount = item.locations.length;
    final themeColor = Theme.of(context).primaryColor;

    String statusText;
    if (totalSubCount > 1) {
      statusText = "Progress: $visitedSubCount / $totalSubCount";
    } else {
      statusText = "Visits: ${item.visitDates.length}";
    }

    // Flag logic for popup
    String? territoryIsoA2 = _getDisplayIsoA2(item, countryProvider);
    List<String> displayIsos = [];
    if (territoryIsoA2 != null) {
      displayIsos = [territoryIsoA2];
    } else {
      final List<String> sortedIsoA3 = List.from(item.countriesIsoA3)
        ..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0));
      for (var isoA3 in sortedIsoA3) {
        final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == isoA3);
        if (c != null) displayIsos.add(c.isoA2);
      }
    }

    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Icon(_getTypeIcon(item.type),
                  size: 14, color: Colors.grey[700]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, height: 1.2, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Displaying flags instead of ISO codes
                  if (displayIsos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: displayIsos.take(3).map((iso) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(width: 16, height: 11, child: CountryFlag.fromCountryCode(iso)),
                          ),
                        )).toList(),
                      ),
                    ),
                  Row(
                    children: [
                      Text(statusText,
                          style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          _showUnescoSiteDetailsModal(item, themeColor);
                          setState(() => _selectedItem = null);
                        },
                        child: Icon(Icons.info_outline, size: 13, color: themeColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _selectedItem = null)),
          ],
        ),
      ),
    );
  }

  void _showColorSettingsDialog() {
    var tempColorMode = _colorMode;
    var tempSameColor = _sameColor;
    var tempWishlistColor = _wishlistColor;
    var tempShowUnvisited = _showUnvisited;
    var tempShowWishlist = _showWishlist;

    var tempByVisitRanges = _byVisitRanges.map((e) => VisitCountRange(
      from: int.tryParse(e.controller.text) ?? e.from,
      color: e.color,
    )).toList();
    for (var range in tempByVisitRanges) {
      range.controller = TextEditingController(text: range.from.toString());
    }

    var tempTypeColors = Map<String, Color>.from(_typeColors);

    void validateAndSave() {
      for (var range in tempByVisitRanges) {
        range.from = int.tryParse(range.controller.text) ?? range.from;
      }
      for (var range in _byVisitRanges) range.controller.dispose();

      setState(() {
        _colorMode = tempColorMode;
        _sameColor = tempSameColor;
        _wishlistColor = tempWishlistColor;
        _showUnvisited = tempShowUnvisited;
        _showWishlist = tempShowWishlist;
        _byVisitRanges = tempByVisitRanges;
        _typeColors = tempTypeColors;
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
              title: Text('Pick a color', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
                  style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                  child: const Text('Select'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 28,
          height: 28,
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

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Map Color Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('General', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Show Unvisited', style: GoogleFonts.poppins()),
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
                          Text('Show Wishlist', style: GoogleFonts.poppins()),
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
                              Text('Wishlist Color', style: GoogleFonts.poppins(fontSize: 13)),
                              buildColorPicker(tempWishlistColor, (c) => setStateDialog(() => tempWishlistColor = c))
                            ],
                          ),
                        ),

                      const Divider(height: 24),
                      Text('Color Mode', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),

                      ...UnescoColorMode.values.map((mode) {
                        String title;
                        switch(mode) {
                          case UnescoColorMode.sameColor: title = "Same Color"; break;
                          case UnescoColorMode.byVisits: title = "By Visits"; break;
                          case UnescoColorMode.byType: title = "By Type"; break;
                          case UnescoColorMode.byRating: title = "By Rating"; break;
                          case UnescoColorMode.byContinent: title = "By Continent"; break;
                          case UnescoColorMode.wishlist: title = "Wishlist Only"; break;
                        }

                        return RadioListTile<UnescoColorMode>(
                          title: Text(title, style: GoogleFonts.poppins(fontSize: 13)),
                          value: mode,
                          groupValue: tempColorMode,
                          onChanged: (v) => setStateDialog(() => tempColorMode = v!),
                          activeColor: Colors.teal,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),

                      const Divider(),

                      if (tempColorMode == UnescoColorMode.sameColor)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Visited Color', style: GoogleFonts.poppins()),
                            buildColorPicker(tempSameColor, (c) => setStateDialog(() => tempSameColor = c))
                          ],
                        ),

                      if (tempColorMode == UnescoColorMode.byVisits) ...[
                        const SizedBox(height: 8),
                        Text('Visit Count Colors', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        ...tempByVisitRanges.asMap().entries.map((entry) {
                          int index = entry.key;
                          var range = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: TextField(
                                    controller: range.controller,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.poppins(fontSize: 13),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    index == tempByVisitRanges.length - 1 ? 'Visits +' : 'Visits',
                                    style: GoogleFonts.poppins(fontSize: 13)
                                ),
                                const Spacer(),
                                buildColorPicker(range.color, (newColor) {
                                  setStateDialog(() {
                                    range.color = newColor;
                                  });
                                }),
                              ],
                            ),
                          );
                        }).toList(),
                      ],

                      if (tempColorMode == UnescoColorMode.byType) ...[
                        const SizedBox(height: 8),
                        Text('Type Colors', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        ...tempTypeColors.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key, style: GoogleFonts.poppins(fontSize: 13)),
                                buildColorPicker(entry.value, (newColor) {
                                  setStateDialog(() {
                                    tempTypeColors[entry.key] = newColor;
                                  });
                                }),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Reset', style: GoogleFonts.poppins(color: Colors.redAccent)),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                  onPressed: () {
                    for (var range in tempByVisitRanges) range.controller.dispose();
                    Navigator.pop(context);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white
                  ),
                  child: Text('Done', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  onPressed: validateAndSave,
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUnescoSiteDetailsModal(UnescoSite site, Color fallbackThemeColor) {
    if (site.locations.isNotEmpty) {
      _mapController.move(
          LatLng(site.locations.first.latitude, site.locations.first.longitude),
          5.0);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 투명 배경 설정
      builder: (BuildContext sheetContext) {
        final provider = sheetContext.watch<UnescoProvider>();
        final countryProvider = sheetContext.read<CountryProvider>();
        final freshSite = provider.allSites.firstWhere((l) => l.name == site.name);
        final isVisited = provider.visitedSites.contains(freshSite.name);
        final isWishlisted = provider.wishlistedSites.contains(freshSite.name);
        final visitedSubCount = provider.getVisitedSubLocationCount(freshSite.name);
        final totalSubCount = freshSite.locations.length;

        Color? siteThemeColor;
        if (freshSite.countriesIsoA3.length == 1) {
          try {
            final country = sheetContext
                .read<CountryProvider>()
                .allCountries
                .firstWhere((c) => c.isoA3 == freshSite.countriesIsoA3.first);
            siteThemeColor = country.themeColor;
          } catch (e) {}
        }
        final themeColor = siteThemeColor ?? fallbackThemeColor;
        const headerTextColor = Colors.white;

        // Flag logic for modal
        String? modalFlagIso = _getDisplayIsoA2(freshSite, countryProvider);
        List<String> displayIsos = [];
        final List<String> sortedIsoA3 = List.from(freshSite.countriesIsoA3)
          ..sort((a, b) => a == 'CHN' ? -1 : (b == 'CHN' ? 1 : 0));

        if (modalFlagIso != null) {
          displayIsos = [modalFlagIso];
        } else {
          for (var isoA3 in sortedIsoA3) {
            final c = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3 == isoA3);
            if (c != null) displayIsos.add(c.isoA2);
          }
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
                // LandmarksList 스타일의 그라데이션 헤더
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    children: [
                      // 배경 그라데이션
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [themeColor, themeColor.withOpacity(0.9)],
                            ),
                          ),
                        ),
                      ),
                      // 다크 오버레이
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.8)],
                            ),
                          ),
                        ),
                      ),
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
                                    freshSite.name,
                                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      color: headerTextColor,
                                    ),
                                  ),
                                ),
                                if (isVisited || visitedSubCount > 0)
                                  const Icon(Icons.check_circle, color: headerTextColor, size: 24),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: headerTextColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: headerTextColor.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(_getTypeIcon(freshSite.type), size: 12, color: headerTextColor),
                                      const SizedBox(width: 4),
                                      Text(freshSite.type, style: const TextStyle(color: headerTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (displayIsos.isNotEmpty)
                                  Row(
                                    children: displayIsos.map((isoA2) => Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        height: 18,
                                        width: 24,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: headerTextColor.withOpacity(0.3), width: 1),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(2),
                                          child: CountryFlag.fromCountryCode(isoA2),
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                              ],
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Wishlist:'),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : Colors.grey),
                                    onPressed: () => provider.toggleWishlistStatus(freshSite.name),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('My Rating:'),
                                  const SizedBox(width: 8),
                                  RatingBar.builder(
                                    initialRating: freshSite.rating ?? 0.0,
                                    minRating: 0,
                                    direction: Axis.horizontal,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    itemSize: 28.0,
                                    itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                    onRatingUpdate: (rating) => provider.updateLandmarkRating(freshSite.name, rating),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          if (totalSubCount > 1) ...[
                            Text("Components / Locations", style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                children: freshSite.locations.map((loc) {
                                  final isLocVisited = provider.isSubLocationVisited(freshSite.name, loc.name);
                                  return CheckboxListTile(
                                    title: Text(loc.name, style: const TextStyle(fontSize: 14)),
                                    value: isLocVisited,
                                    activeColor: themeColor,
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    onChanged: (val) {
                                      provider.toggleSubLocation(freshSite.name, loc.name);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            const Divider(height: 24),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('History (${freshSite.visitDates.length} entries)', style: Theme.of(sheetContext).textTheme.titleSmall),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add Visit'),
                                onPressed: () => provider.addVisitDate(freshSite.name),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (freshSite.visitDates.isNotEmpty)
                            ...freshSite.visitDates.asMap().entries.map((entry) => _UnescoVisitEditorCard(
                              key: ValueKey('${freshSite.name}_${entry.key}'),
                              siteName: freshSite.name,
                              visitDate: entry.value,
                              index: entry.key,
                              onDelete: () => provider.removeVisitDate(freshSite.name, entry.key),
                              availableLocations: freshSite.locations,
                            ))
                          else
                            const Center(child: Text('No visits recorded.')),
                          const Divider(height: 24),
                          LandmarkInfoCard(
                            overview: freshSite.overview,
                            historySignificance: freshSite.history_significance,
                            highlights: freshSite.highlights,
                            themeColor: themeColor,
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
    ).then((_) => setState(() {}));
  }

  Widget _buildChecklistSection(Color themeColor) {
    final provider = context.watch<UnescoProvider>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search',
              prefixIcon: const Icon(Icons.search),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear())
                  : null,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _visibleItems.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final item = _visibleItems[index];
              final isVisited = provider.visitedSites.contains(item.name);
              final visitedSubCount = provider.getVisitedSubLocationCount(item.name);
              final totalSubCount = item.locations.length;

              final Color typeColor = _typeColors[item.type] ?? Colors.grey;
              final Color bgColor = typeColor.withOpacity(0.15);

              // Check if highlighted to show border
              final bool isHighlighted = _highlightedId == item.name;

              if (totalSubCount > 1) {
                return Card(
                  elevation: 0,
                  color: bgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isHighlighted
                        ? BorderSide(color: Colors.grey.shade700, width: 2)
                        : BorderSide.none,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$visitedSubCount/$totalSubCount",
                          style: TextStyle(
                            fontSize: 12,
                            color: visitedSubCount == totalSubCount
                                ? Colors.green
                                : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () =>
                              _showUnescoSiteDetailsModal(item, themeColor),
                          tooltip: 'Info',
                          visualDensity: VisualDensity.compact,
                        ),
                        AnimatedRotation(
                          turns: 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more,
                            color: isVisited ? themeColor : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    children: item.locations.map((loc) {
                      final isLocVisited = provider.isSubLocationVisited(item.name, loc.name);
                      // Generate ID for sub-location
                      final String subLocId = "${item.name}_${loc.name}";
                      final bool isSubHighlighted = _highlightedId == subLocId;

                      return Container(
                        decoration: BoxDecoration(
                          border: isSubHighlighted
                              ? Border(left: BorderSide(color: Colors.grey.shade700, width: 4))
                              : null,
                        ),
                        child: ListTile(
                          title: Text(loc.name, style: const TextStyle(fontSize: 12)),
                          contentPadding: const EdgeInsets.only(left: 16, right: 8),
                          dense: true,
                          onTap: () => _onListItemTap(item, loc),
                          trailing: Checkbox(
                            value: isLocVisited,
                            activeColor: themeColor,
                            onChanged: (val) {
                              provider.toggleSubLocation(item.name, loc.name);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }

              return Card(
                elevation: 0,
                color: bgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  // Border for single item
                  side: isHighlighted
                      ? BorderSide(color: Colors.grey.shade700, width: 2)
                      : BorderSide.none,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 16, right: 8),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onTap: () => _onListItemTap(item, null),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () =>
                              _showUnescoSiteDetailsModal(item, themeColor),
                          tooltip: 'Info'),
                      Checkbox(
                        value: isVisited,
                        onChanged: (bool? value) =>
                            provider.toggleVisitedStatus(item.name),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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

  void _toggleLocationInVisit(String locName, bool isSelected) {
    final provider = context.read<UnescoProvider>();
    List<String> currentDetails = List.from(widget.visitDate.visitedDetails);
    if (isSelected) {
      if (!currentDetails.contains(locName)) {
        currentDetails.add(locName);
        if (!provider.isSubLocationVisited(widget.siteName, locName)) {
          provider.toggleSubLocation(widget.siteName, locName);
        }
      }
    } else {
      currentDetails.remove(locName);
    }
    provider.updateLandmarkVisit(widget.siteName, widget.index, visitedDetails: currentDetails);
    setState(() {});
  }

  Widget _buildPhotoPreview(String path, int i) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(width: 60, height: 60, margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover))),
      if (_isEditing) Positioned(top: -6, right: 6,
          child: GestureDetector(onTap: () => setState(() => _currentPhotos.removeAt(i)),
              child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.cancel, color: Colors.red, size: 22)))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;
    return Card(
      elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        controller: _expansionTileController,
        initiallyExpanded: _isEditing,
        title: Text(_displayTitle.isNotEmpty ? _displayTitle : 'Visit Record',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text('Date: $_year-$_month-$_day', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
          onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Delete Visit Record'),
              content: const Text('Are you sure you want to delete this visit record?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () { Navigator.pop(ctx); widget.onDelete(); },
                    child: const Text('Delete', style: TextStyle(color: Colors.red))),
              ])),
        ),
        children: [Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_isEditing) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Visit Date: $_year-$_month-$_day', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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

            if (widget.availableLocations != null && widget.availableLocations!.isNotEmpty) ...[
              const Text("Locations included in this visit:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 4),
              IgnorePointer(ignoring: !_isEditing,
                  child: Wrap(spacing: 8.0, runSpacing: 4.0,
                      children: widget.availableLocations!.map((loc) {
                        final isChecked = widget.visitDate.visitedDetails.contains(loc.name);
                        return FilterChip(
                          label: Text(loc.name, style: const TextStyle(fontSize: 11)),
                          selected: isChecked,
                          selectedColor: themeColor.withOpacity(0.2),
                          checkmarkColor: themeColor,
                          onSelected: (bool selected) => _toggleLocationInVisit(loc.name, selected),
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
                    style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0)),
              ] else
                OutlinedButton.icon(onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit, size: 16), label: const Text('Edit Record'),
                    style: OutlinedButton.styleFrom(foregroundColor: themeColor,
                        side: BorderSide(color: themeColor.withOpacity(0.5)))),
            ]),
          ]),
        )],
      ),
    );
  }
}