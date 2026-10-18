// lib/screens/cities_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_flags/country_flags.dart';
import 'cities_map_share.dart';

enum CitiesColorMode { byVisits, byDuration, byRating, byContinent, bySubregion, sameColor }
enum SizingMode { population, duration, visitCount }

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

class DurationRange {
  int fromDays;
  Color color;
  TextEditingController controller;

  DurationRange({required this.fromDays, required this.color})
      : controller = TextEditingController(text: fromDays.toString());

  DurationRange copyWith({int? fromDays, Color? color}) {
    return DurationRange(
      fromDays: fromDays ?? this.fromDays,
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

class CitiesScreen extends StatefulWidget {
  const CitiesScreen({super.key});

  @override
  State<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<CitiesScreen> {
  final MapController _mapController = MapController();
  List<City> _visibleCities = [];
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  bool _isMapReady = false;
  String? _highlightedCityName;
  String? _tappedCityNameForTag;

  CitiesColorMode _colorMode = CitiesColorMode.sameColor;
  List<VisitCountRange> _byVisitRanges = [];
  List<DurationRange> _byDurationRanges = [];
  List<RatingCategory> _byRatingRanges = [];

  Color _homeColor = Colors.black;
  Color _livedColor = Colors.brown;
  Color _sameColor = Colors.amber;
  Color _unknownDurationColor = Colors.grey;
  Color _unknownRatingColor = Colors.grey;

  Map<String, Color> _byContinentColors = {};
  Map<String, Color> _bySubregionColors = {};

  bool _showHome = true;
  bool _showLived = true;
  bool _showUnvisited = false;
  bool _showLegend = true;

  bool _showFlags = true;

  bool _filterVisited = false;
  bool _filterWishlist = false;
  bool _filterHome = false;
  bool _filterLived = false;

  SizingMode? _sizingMode = SizingMode.population;
  double _fixedMarkerRadius = 2.5;
  bool _showWishlist = true;
  Color _wishlistColor = Colors.red;

  static const List<String> continentFullNames = ['Asia', 'Europe', 'Africa', 'North America', 'South America', 'Oceania'];
  static const Color unvisitedColor = Colors.transparent;

  LatLng? _tappedLocation;

  double _getMarkerRadius(City city, CityProvider cityProvider) {
    if (_sizingMode == null) {
      return _fixedMarkerRadius;
    }

    const double minRadius = 1.0;
    const double maxRadius = 6.0;

    final detail = cityProvider.visitDetails[city.name];

    switch (_sizingMode!) {
      case SizingMode.population:
        if (city.population <= 0) return 0.5;
        double radius = 1.0 + 0.8 * (log(city.population / 50000));
        return radius.clamp(minRadius, maxRadius);

      case SizingMode.visitCount:
        final visitCount = detail?.visitDateRanges.length ?? 0;
        if (visitCount <= 0) return minRadius;
        final count = min(visitCount, 10);
        final k = 3.0 / sqrt(3);
        final radius = k * sqrt(count) * 1.3;
        return radius.clamp(minRadius, maxRadius);

      case SizingMode.duration:
        final durationInDays = detail?.totalDurationInDays() ?? 0;
        if (durationInDays <= 0) return minRadius;
        final duration = min(durationInDays, 1000);
        final logDuration = log(duration + 1);
        if (logDuration <= 0) return minRadius;
        final k = maxRadius / sqrt(log(1001));
        final radius = k * sqrt(logDuration) * 1.5;
        return radius.clamp(minRadius, maxRadius);
    }
  }


  @override
  void initState() {
    super.initState();
    _searchController.addListener(_updateVisibleCities);
    _loadColorSettings();
    _loadFilterSettings();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    for (var range in _byVisitRanges) {
      range.controller.dispose();
    }
    for (var range in _byDurationRanges) {
      range.controller.dispose();
    }

    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );

    super.dispose();
  }

  void _onMapChanged(MapPosition position, bool hasGesture) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _updateVisibleCities);

    if (hasGesture) {
      setState(() {
        _highlightedCityName = null;
        _tappedCityNameForTag = null;
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _tappedLocation = latLng;
      _highlightedCityName = null;
      _tappedCityNameForTag = null;

      final clickedCity = _findCityAtTap(latLng);
      if (clickedCity != null) {
        _tappedCityNameForTag = clickedCity.name;
      }
    });
  }

  City? _findCityAtTap(LatLng tapPoint) {
    const double clickTolerance = 10.0;
    final cityProvider = Provider.of<CityProvider>(context, listen: false);

    final visibleVisitedCities = _visibleCities.where((c) => cityProvider.isVisited(c.name)).toList();

    for (final city in visibleVisitedCities) {
      final LatLng cityPoint = LatLng(city.latitude, city.longitude);

      final Point<double> cityScreenPoint = _mapController.camera.latLngToScreenPoint(cityPoint);
      final Point<double> tapScreenPoint = _mapController.camera.latLngToScreenPoint(tapPoint);

      final double distance = sqrt(
          pow(cityScreenPoint.x - tapScreenPoint.x, 2) +
              pow(cityScreenPoint.y - tapScreenPoint.y, 2)
      );

      double radius = _getMarkerRadius(city, cityProvider);
      if (_showFlags) {
        radius *= 2.0;
      }

      if (distance <= radius + clickTolerance) {
        return city;
      }
    }
    return null;
  }

  void _updateVisibleCities() {
    if (!mounted || !_isMapReady) return;

    final cityProvider = Provider.of<CityProvider>(context, listen: false);
    final bounds = _mapController.camera.visibleBounds;
    final searchQuery = _searchController.text.toLowerCase();

    final newVisibleCities = cityProvider.allCities.where((city) {
      final isInBounds = bounds.contains(LatLng(city.latitude, city.longitude));
      final matchesSearch = city.name.toLowerCase().contains(searchQuery);

      if (!isInBounds) return false;
      if (!matchesSearch) return false;

      final detail = cityProvider.visitDetails[city.name];
      final isVisited = cityProvider.isVisited(city.name);
      final isWishlisted = detail?.isWishlisted ?? false;
      final isHome = cityProvider.getCityHomeStatus(city.name);
      final hasLived = detail?.hasLived ?? false;

      if (_filterVisited && !isVisited) return false;

      if (_filterWishlist && !isWishlisted) return false;

      if (_filterHome && !isHome) return false;

      if (_filterLived && !hasLived) return false;

      return true;
    }).toList();

    newVisibleCities.sort((a, b) => b.population.compareTo(a.population));

    if (mounted && !listEquals(_visibleCities, newVisibleCities)) {
      setState(() => _visibleCities = newVisibleCities);
    }
  }

  Future<void> _loadColorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final colorModeStr = prefs.getString('citiesColorMode');
        _colorMode = CitiesColorMode.values.firstWhere(
              (e) => e.toString() == 'CitiesColorMode.$colorModeStr',
          orElse: () => CitiesColorMode.sameColor,
        );

        final sizingModeStr = prefs.getString('citiesSizingMode');
        if (sizingModeStr == 'null') {
          _sizingMode = null;
        } else if (sizingModeStr != null) {
          _sizingMode = SizingMode.values.firstWhereOrNull(
                (e) => e.toString() == 'SizingMode.$sizingModeStr',
          );
        } else {
          _sizingMode = null;
        }

        _homeColor = Color(prefs.getInt('cityHomeColor') ?? Colors.black.value);
        _livedColor = Color(prefs.getInt('cityLivedColor') ?? Colors.brown.shade700.value);
        _sameColor = Color(prefs.getInt('citiesSameColor') ?? Colors.amber.value);
        _unknownDurationColor = Color(prefs.getInt('cityUnknownDurationColor') ?? Colors.grey.shade300.value);
        _unknownRatingColor = Color(prefs.getInt('cityUnknownRatingColor') ?? Colors.grey.shade300.value);
        _showHome = prefs.getBool('showCityHome') ?? true;
        _showLived = prefs.getBool('showCityLived') ?? true;
        _showUnvisited = prefs.getBool('showCityUnvisited') ?? false;
        _showLegend = prefs.getBool('showCitiesLegend') ?? true;
        _fixedMarkerRadius = prefs.getDouble('fixedMarkerRadius') ?? 2.5;
        _showWishlist = prefs.getBool('showCityWishlist') ?? true;
        _wishlistColor = Color(prefs.getInt('cityWishlistColor') ?? Colors.red.shade700.value);

        _showFlags = prefs.getBool('showCityFlags') ?? true;

        final visitRangesJson = prefs.getString('byCityVisitRanges');
        if (visitRangesJson != null) {
          final List<dynamic> decoded = json.decode(visitRangesJson);
          _byVisitRanges = decoded.map((e) => VisitCountRange(
            from: e['from'],
            color: Color(e['color']),
          )).toList();
          for (var range in _byVisitRanges) {
            range.controller = TextEditingController(text: range.from.toString());
          }
        } else {
          _byVisitRanges = [
            VisitCountRange(from: 1, color: const Color(0xFFADD8E6)),
            VisitCountRange(from: 2, color: const Color(0xFF87CEEB)),
            VisitCountRange(from: 3, color: const Color(0xFF1E90FF)),
            VisitCountRange(from: 4, color: const Color(0xFF4169E1)),
            VisitCountRange(from: 5, color: const Color(0xFF6A0DAD)),
          ];
        }

        final durationRangesJson = prefs.getString('byCityDurationRanges');
        if (durationRangesJson != null) {
          final List<dynamic> decoded = json.decode(durationRangesJson);
          _byDurationRanges = decoded.map((e) => DurationRange(
            fromDays: e['fromDays'],
            color: Color(e['color']),
          )).toList();
          for (var range in _byDurationRanges) {
            range.controller = TextEditingController(text: range.fromDays.toString());
          }
        } else {
          _byDurationRanges = [
            DurationRange(fromDays: 0, color: Colors.indigo.shade100),
            DurationRange(fromDays: 1, color: Colors.cyan.shade200),
            DurationRange(fromDays: 3, color: Colors.cyan.shade400),
            DurationRange(fromDays: 7, color: Colors.cyan.shade600),
            DurationRange(fromDays: 30, color: Colors.cyan.shade800),
            DurationRange(fromDays: 90, color: Colors.teal.shade900),
          ];
        }

        final ratingRangesJson = prefs.getString('byCityRatingRanges');
        if (ratingRangesJson != null) {
          final List<dynamic> decoded = json.decode(ratingRangesJson);
          _byRatingRanges = decoded.map((e) => RatingCategory(
            rating: (e['rating'] as num).toDouble(),
            color: Color(e['color']),
          )).toList();
        } else {
          _byRatingRanges = [
            RatingCategory(rating: 1.0, color: Colors.red.shade300),
            RatingCategory(rating: 2.0, color: Colors.orange.shade400),
            RatingCategory(rating: 3.0, color: Colors.yellow.shade600),
            RatingCategory(rating: 4.0, color: Colors.lightGreen.shade500),
            RatingCategory(rating: 4.5, color: Colors.green.shade700),
          ];
        }

        final continentColorsJson = prefs.getString('byContinentColors');
        if (continentColorsJson != null) {
          final Map<String, dynamic> decoded = json.decode(continentColorsJson);
          _byContinentColors = decoded.map((key, value) => MapEntry(key, Color(value)));
        } else {
          _byContinentColors = {
            'Europe': Colors.yellow.shade700,
            'Asia': Colors.pink.shade300,
            'Africa': Colors.brown.shade400,
            'North America': Colors.blue.shade400,
            'South America': Colors.green.shade400,
            'Oceania': Colors.purple.shade400,
          };
        }

        final subregionColorsJson = prefs.getString('bySubregionColors');
        if (subregionColorsJson != null) {
          final Map<String, dynamic> decoded = json.decode(subregionColorsJson);
          _bySubregionColors = decoded.map((key, value) => MapEntry(key, Color(value)));
        } else {
          _bySubregionColors = {
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
        }
      });
    }
  }

  Future<void> _loadFilterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _filterVisited = prefs.getBool('filterVisited') ?? false;
        _filterWishlist = prefs.getBool('filterWishlist') ?? false;
        _filterHome = prefs.getBool('filterHome') ?? false;
        _filterLived = prefs.getBool('filterLived') ?? false;
      });
    }
  }

  Future<void> _saveColorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('citiesColorMode', _colorMode.toString().split('.').last);
    await prefs.setString('citiesSizingMode', _sizingMode != null ? _sizingMode.toString().split('.').last : 'null');

    await prefs.setInt('cityHomeColor', _homeColor.value);
    await prefs.setInt('cityLivedColor', _livedColor.value);
    await prefs.setInt('citiesSameColor', _sameColor.value);
    await prefs.setInt('cityUnknownDurationColor', _unknownDurationColor.value);
    await prefs.setInt('cityUnknownRatingColor', _unknownRatingColor.value);
    await prefs.setBool('showCityHome', _showHome);
    await prefs.setBool('showCityLived', _showLived);
    await prefs.setBool('showCitiesLegend', _showLegend);
    await prefs.setBool('showCityUnvisited', _showUnvisited);
    await prefs.setDouble('fixedMarkerRadius', _fixedMarkerRadius);
    await prefs.setBool('showCityWishlist', _showWishlist);
    await prefs.setInt('cityWishlistColor', _wishlistColor.value);

    await prefs.setBool('showCityFlags', _showFlags);

    await prefs.setBool('filterVisited', _filterVisited);
    await prefs.setBool('filterWishlist', _filterWishlist);
    await prefs.setBool('filterHome', _filterHome);
    await prefs.setBool('filterLived', _filterLived);

    final visitRangesJson = json.encode(_byVisitRanges.map((e) => {
      'from': int.tryParse(e.controller.text) ?? e.from,
      'color': e.color.value,
    }).toList());
    await prefs.setString('byCityVisitRanges', visitRangesJson);

    final durationRangesJson = json.encode(_byDurationRanges.asMap().entries.map((entry) {
      final e = entry.value;
      final fromDays = entry.key == 0 ? 0 : (int.tryParse(e.controller.text) ?? e.fromDays);
      return {
        'fromDays': fromDays,
        'color': e.color.value,
      };
    }).toList());
    await prefs.setString('byCityDurationRanges', durationRangesJson);

    final ratingRangesJson = json.encode(_byRatingRanges.map((e) => {
      'rating': e.rating,
      'color': e.color.value,
    }).toList());
    await prefs.setString('byCityRatingRanges', ratingRangesJson);

    final continentColorsJson = json.encode(_byContinentColors.map((key, value) => MapEntry(key, value.value)));
    await prefs.setString('byContinentColors', continentColorsJson);

    final subregionColorsJson = json.encode(_bySubregionColors.map((key, value) => MapEntry(key, value.value)));
    await prefs.setString('bySubregionColors', subregionColorsJson);
  }

  void _showAddCityDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController latController = TextEditingController(text: _tappedLocation?.latitude.toStringAsFixed(4) ?? '');
    final TextEditingController lonController = TextEditingController(text: _tappedLocation?.longitude.toStringAsFixed(4) ?? '');
    final TextEditingController countryIsoController = TextEditingController();
    final TextEditingController populationController = TextEditingController();

    String? selectedContinent;
    String? selectedSubregion;

    final cityProvider = Provider.of<CityProvider>(context, listen: false);
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);

    final List<String> continents = countryProvider.allCountries
        .map((c) => c.continent)
        .whereType<String>()
        .where((c) => continentFullNames.contains(c))
        .toSet()
        .toList()
      ..sort();

    List<String> getSubregionsForContinent(String continent) {
      return countryProvider.allCountries
          .where((c) => c.continent == continent)
          .map((c) => c.subregion)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
    }


    void validateAndAddCity(StateSetter setStateDialog) async {
      final cityName = nameController.text.trim();
      final lat = double.tryParse(latController.text.trim());
      final lon = double.tryParse(lonController.text.trim());
      final population = populationController.text.trim().isEmpty ? 0 : (int.tryParse(populationController.text.trim()) ?? 0);
      final countryIsoA2 = countryIsoController.text.trim().toUpperCase();
      final continent = selectedContinent;

      if (cityName.isEmpty || lat == null || lon == null || countryIsoA2.isEmpty || continent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(tr('Please fill in all required fields (Name, Lat/Lon, ISO, Continent).'))),
        );
        return;
      }

      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(tr('Latitude must be between -90 and 90, and Longitude between -180 and 180.'))),
        );
        return;
      }

      cityProvider.addCustomCity(cityName, lat, lon, countryIsoA2, continent, population);

      cityProvider.updateCityVisitDetail(cityName, CityVisitDetail(
        name: cityName,
        hasLived: false,
        isHome: false,
        isWishlisted: true,
        rating: 0.0,
        visitDateRanges: [],
        memo: 'Custom city added by user.',
        photos: [],
        arrivalDate: '', departureDate: '', duration: '',
        arrivalTime: null, departureTime: null,
      ));

      _updateVisibleCities();
      _mapController.move(LatLng(lat, lon), max(7.0, _mapController.camera.zoom));
      setState(() {
        _highlightedCityName = cityName;
        _tappedLocation = null;
      });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('City "$cityName" added successfully!', entities: [cityName]))),
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title:  Text(tr('Add New Custom City')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration:  InputDecoration(labelText: tr('City Name'))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            decoration:  InputDecoration(labelText: tr('Latitude')),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lonController,
                            decoration:  InputDecoration(labelText: tr('Longitude')),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.touch_app, size: 18),
                        label:  Text(tr('Tap on map to select'), style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text(tr('Tap a location on the map, then re-open the Add City dialog.'))),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: countryIsoController,
                      decoration:  InputDecoration(labelText: tr('Country ISO A2 (e.g., US)'), counterText: ''),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedContinent,
                      decoration:  InputDecoration(labelText: tr('Continent'), border: OutlineInputBorder()),
                      hint:  Text(tr('Select Continent')),
                      items: continents.map((continent) {
                        return DropdownMenuItem(value: continent, child: Text(tr(continent)));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          selectedContinent = newValue;
                          selectedSubregion = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedSubregion,
                      decoration:  InputDecoration(labelText: tr('Subregion'), border: OutlineInputBorder()),
                      hint:  Text(tr('Select Subregion (Optional)')),
                      items: selectedContinent != null
                          ? getSubregionsForContinent(selectedContinent!).map((subregion) {
                        return DropdownMenuItem(value: subregion, child: Text(tr(subregion)));
                      }).toList()
                          : [],
                      onChanged: selectedContinent != null
                          ? (String? newValue) {
                        setStateDialog(() {
                          selectedSubregion = newValue;
                        });
                      }
                          : null,
                      disabledHint:  Text(tr('Select a Continent first')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: populationController,
                      decoration:  InputDecoration(labelText: tr('Population (Leave blank for Unknown)')),
                      keyboardType: TextInputType.number,
                    ),
                     Padding(padding: EdgeInsets.only(top: 10), child: Text(tr('Unknown population will be set to 0 in data.'), style: TextStyle(fontSize: 12, color: Colors.grey))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child:  Text(tr('Cancel'))),
                ElevatedButton(onPressed: () => validateAndAddCity(setStateDialog), child:  Text(tr('Add City'))),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSwitches() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Visited',
              icon: Icons.check_circle_outline,
              value: _filterVisited,
              onChanged: (val) {
                setState(() {
                  _filterVisited = val;
                  _saveColorSettings();
                  _updateVisibleCities();
                });
              },
            ),
            _buildFilterChip(
              label: 'Wishlist',
              icon: Icons.favorite_border,
              value: _filterWishlist,
              onChanged: (val) {
                setState(() {
                  _filterWishlist = val;
                  _saveColorSettings();
                  _updateVisibleCities();
                });
              },
            ),
            _buildFilterChip(
              label: 'Home',
              icon: Icons.home_outlined,
              value: _filterHome,
              onChanged: (val) {
                setState(() {
                  _filterHome = val;
                  _saveColorSettings();
                  _updateVisibleCities();
                });
              },
            ),
            _buildFilterChip(
              label: 'Lived',
              icon: Icons.person_outline,
              value: _filterLived,
              onChanged: (val) {
                setState(() {
                  _filterLived = val;
                  _saveColorSettings();
                  _updateVisibleCities();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, required IconData icon, required bool value, required ValueChanged<bool> onChanged}) {
    final Color activeColor = Colors.amber;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Row(
          children: [
            Icon(icon, size: 18, color: value ? Colors.white : activeColor),
            const SizedBox(width: 4),
            Text(tr(label)),
          ],
        ),
        selected: value,
        onSelected: onChanged,
        backgroundColor: Colors.grey.shade100,
        selectedColor: activeColor,
        labelStyle: TextStyle(
          color: value ? Colors.white : Colors.black87,
          fontWeight: value ? FontWeight.bold : FontWeight.normal,
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildInfoTag(City city, CityProvider cityProvider) {
    final Color tagColor = _getCircleColor(city, cityProvider);
    final Color tagTextColor = ThemeData.estimateBrightnessForColor(tagColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            city.name,
            style: TextStyle(
              color: tagTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              _showCityDetailsModal(city, cityProvider);
              setState(() {
                _tappedCityNameForTag = null;
              });
            },
            child: Icon(
              Icons.info_outline,
              color: tagTextColor,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      body: Consumer2<CityProvider, CountryProvider>(
        builder: (context, cityProvider, countryProvider, child) {
          if (cityProvider.isLoading || countryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SafeArea(
            child: Column(
              children: [
                Expanded(flex: 3, child: _buildMap(cityProvider.allCities, cityProvider, countryProvider)),
                Expanded(flex: 4, child: _buildChecklistSection(cityProvider, countryProvider)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMap(List<City> allCities, CityProvider cityProvider, CountryProvider countryProvider) {
    final List<Marker> tempMarkers = [];
    if (_tappedLocation != null) {
      tempMarkers.add(
        Marker(
          width: 32,
          height: 32,
          point: _tappedLocation!,
          child: const Icon(
            Icons.pin_drop,
            color: Colors.red,
            size: 32,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4.0)],
          ),
        ),
      );
    }

    final List<Marker> wishlistMarkers = _showWishlist
        ? cityProvider.visitDetails.values
        .where((detail) => detail.isWishlisted)
        .map((detail) {
      final City? city = allCities.firstWhereOrNull((c) => c.name == detail.name);
      if (city == null) return null;

      final double radius = _getMarkerRadius(city, cityProvider);
      final double iconSize = radius * 2.0;

      return Marker(
        width: iconSize * 2,
        height: iconSize * 2,
        point: LatLng(city.latitude, city.longitude),
        child: Icon(
          Icons.favorite,
          color: _wishlistColor,
          size: iconSize,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 3.0)],
        ),
      );
    }).whereType<Marker>().toList()
        : [];

    final List<Marker> highlightMarker = [];
    if (_highlightedCityName != null) {
      final City? city = allCities.firstWhereOrNull((c) => c.name == _highlightedCityName);
      if (city != null) {
        highlightMarker.add(
          Marker(
            width: 32,
            height: 32,
            point: LatLng(city.latitude, city.longitude),
            child: const Icon(
              Icons.location_on,
              color: Colors.grey,
              size: 32,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4.0)],
            ),
          ),
        );
      }
    }

    final List<Marker> tagMarker = [];
    if (_tappedCityNameForTag != null) {
      final City? city = allCities.firstWhereOrNull((c) => c.name == _tappedCityNameForTag);
      if (city != null) {
        tagMarker.add(
          Marker(
            point: LatLng(city.latitude, city.longitude),
            width: 150,
            height: 30,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(
                  _getMarkerRadius(city, cityProvider) * 1.2,
                  -_getMarkerRadius(city, cityProvider) * 0.8
              ),
              child: _buildInfoTag(city, cityProvider),
            ),
          ),
        );
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(30, 0),
            initialZoom: 1.0,
            onPositionChanged: _onMapChanged,
            onMapReady: () {
              if (mounted) {
                setState(() => _isMapReady = true);
                _updateVisibleCities();
              }
            },
            cameraConstraint: CameraConstraint.unconstrained(),
            backgroundColor: Colors.white,
            onTap: _onMapTap,
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

            if (_showFlags)
              MarkerLayer(
                markers: cityProvider.allCities
                    .where((c) => cityProvider.isVisited(c.name))
                    .map((city) {
                  double radius = _getMarkerRadius(city, cityProvider);
                  double size = radius * 4.0;

                  return Marker(
                    width: size,
                    height: size,
                    point: LatLng(city.latitude, city.longitude),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.0),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 2.0)
                        ],
                      ),
                      child: ClipOval(
                        child: CountryFlag.fromCountryCode(
                          city.countryIsoA2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              CircleLayer(
                circles: allCities.where((c) => cityProvider.isVisited(c.name)).map((city) {
                  Color color = _getCircleColor(city, cityProvider);
                  return CircleMarker(
                    point: LatLng(city.latitude, city.longitude),
                    color: color,
                    radius: _getMarkerRadius(city, cityProvider),
                    useRadiusInMeter: false,
                    borderColor: Colors.white,
                    borderStrokeWidth: 1.0,
                  );
                }).toList(),
              ),

            MarkerLayer(markers: highlightMarker),
            MarkerLayer(markers: wishlistMarkers),
            MarkerLayer(markers: tempMarkers),
            MarkerLayer(markers: tagMarker),
          ],
        ),

        Positioned(
          top: 8,
          left: 8,
          child: Row(
            children: [
              Card(
                elevation: 2,
                shape: const CircleBorder(),
                color: Colors.white.withOpacity(0.9),
                child: IconButton(
                  icon: const Icon(Icons.settings, size: 20),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: _showColorSettingsDialog,
                  tooltip: tr('Color Settings'),
                ),
              ),
              const SizedBox(width: 4),
              Card(
                elevation: 2,
                shape: const CircleBorder(),
                color: Colors.white.withOpacity(0.9),
                child: IconButton(
                  icon: Icon(_showLegend ? Icons.visibility_off : Icons.visibility, size: 20),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: () => setState(() {
                    _showLegend = !_showLegend;
                    _saveColorSettings();
                  }),
                  tooltip: tr(_showLegend ? 'Hide Legend' : 'Show Legend'),
                ),
              ),
            ],
          ),
        ),

        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              Card(
                elevation: 2,
                shape: const CircleBorder(),
                color: Colors.white.withOpacity(0.9),
                child: IconButton(
                  icon: const Icon(Icons.share, size: 20),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: () async {
                    final cityProvider = Provider.of<CityProvider>(context, listen: false);
                    final countryProvider = Provider.of<CountryProvider>(context, listen: false);

                    final visitedCities = cityProvider.allCities
                        .where((c) => cityProvider.isVisited(c.name))
                        .toList();

                    await CitiesMapShare.share(
                      context: context,
                      visitedCities: visitedCities,
                      allCountries: countryProvider.allCountries,
                      visitDetails: cityProvider.visitDetails,
                      initialCenter: const LatLng(20, 0),
                      initialZoom: 1.5,
                      showFlags: true,
                      visitedColor: Colors.amber,
                      nonVisitedColor: Colors.grey,
                      populationFactor: 1.0,
                      stayFactor: 1.0,
                    );
                  },
                  tooltip: tr('Share Map'),
                ),
              ),
              const SizedBox(width: 4),
              Card(
                elevation: 2,
                shape: const CircleBorder(),
                color: Colors.white.withOpacity(0.9),
                child: IconButton(
                  icon: const Icon(Icons.add_location_alt, size: 20),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: () => _showAddCityDialog(context),
                  tooltip: tr('Add Custom City'),
                ),
              ),
            ],
          ),
        ),

        Positioned(
          bottom: 10,
          left: 10,
          child: _showLegend ? _buildLegendWidget() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Color _getCircleColor(City city, CityProvider cityProvider) {
    final details = cityProvider.visitDetails[city.name];
    final bool isVisited = details != null;
    final bool isHome = cityProvider.homeCityName == city.name;
    final bool hasLived = details?.hasLived ?? false;

    if (!isVisited) {
      return unvisitedColor;
    }

    if (_showHome && isHome) {
      return _homeColor;
    }

    if (_showLived && hasLived) {
      return _livedColor;
    }

    switch (_colorMode) {
      case CitiesColorMode.byVisits:
        return _byVisitRanges.lastWhere((r) => details!.visitDateRanges.length >= r.from, orElse: () => _byVisitRanges.last).color;
      case CitiesColorMode.byDuration:
        int totalDays = details.totalDurationInDays();

        if (totalDays < 0 || details!.visitDateRanges.any((range) => range.isDurationUnknown)) {
          return _unknownDurationColor;
        }

        DurationRange? selectedRange;

        for (int i = 0; i < _byDurationRanges.length; i++) {
          final current = _byDurationRanges[i];

          if (i == _byDurationRanges.length - 1) {
            if (totalDays >= current.fromDays) {
              selectedRange = current;
              break;
            }
          } else {
            final next = _byDurationRanges[i + 1];
            if (totalDays >= current.fromDays) {
              if (totalDays < next.fromDays) {
                selectedRange = current;
                break;
              }
            }
          }
        }
        return selectedRange?.color ?? _unknownDurationColor;


      case CitiesColorMode.byRating:
        final rating = details!.rating;
        if (rating == 0.0) return _unknownRatingColor;
        return _byRatingRanges.firstWhere((r) => rating >= r.rating, orElse: () => _byRatingRanges.last).color;
      case CitiesColorMode.byContinent:
        final continent = city.continent;
        return _byContinentColors[continent] ?? Colors.grey.shade500;
      case CitiesColorMode.bySubregion:
        final countryProvider = context.read<CountryProvider>();
        final country = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2 == city.countryIsoA2);
        final subregion = country?.subregion;
        return _bySubregionColors[subregion] ?? Colors.grey.shade500;
      case CitiesColorMode.sameColor:
        return _sameColor;
    }
  }

  Widget _buildChecklistSection(CityProvider cityProvider, CountryProvider countryProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: tr('Search Cities'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear())
                  : null,
            ),
          ),
        ),
        _buildFilterSwitches(),
        Expanded(
          child: ListView.builder(
            itemCount: _visibleCities.length,
            itemBuilder: (context, index) {
              final city = _visibleCities[index];
              final countryName = city.country;
              final detail = cityProvider.visitDetails[city.name];
              final bool isWishlisted = detail?.isWishlisted ?? false;
              final Color wishlistColor = _wishlistColor;
              final bool showWishlistControls = _showWishlist;


              return CityVisitControlTile(
                key: ValueKey(city.name),
                city: city,
                countryName: countryName,
                onTap: () => _showCityDetailsModal(city, cityProvider),
                onCenterMap: () {
                  setState(() {
                    _mapController.move(LatLng(city.latitude, city.longitude), max(7.0, _mapController.camera.zoom));
                    _highlightedCityName = city.name;
                    _tappedLocation = null;
                  });
                },
                onToggleWishlist: () {
                  cityProvider.toggleCityWishlistStatus(city.name);
                },
                onToggleVisited: (bool value) async {
                  final provider = Provider.of<CityProvider>(context, listen: false);
                  if (value) {
                    provider.setVisitedStatus(city.name, true);
                  } else {
                    final visitDetails = provider.visitDetails[city.name];
                    if (visitDetails != null && visitDetails.visitDateRanges.isNotEmpty) {
                      final int recordCount = visitDetails.visitDateRanges.length;

                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(tr('Confirm Removal'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
                          content: Text(
                              tr('Are you sure you want to remove all $recordCount visit records for ${city.name}?'),
                              style: GoogleFonts.poppins(color: Colors.black54)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(tr('Cancel'), style: GoogleFonts.poppins(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(tr('Yes, Remove'), style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        provider.clearVisitHistory(city.name);
                      }
                    } else {
                      provider.setVisitedStatus(city.name, false);
                    }
                  }
                },
                isWishlisted: isWishlisted,
                wishlistColor: wishlistColor,
                showWishlistControls: showWishlistControls,
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMemoAndPhotoDialog(BuildContext context, String cityName, String initialMemo, List<String> initialPhotos, Function(String, List<String>) onSave) {
    final TextEditingController memoController = TextEditingController(text: initialMemo);
    List<String> currentPhotos = List.from(initialPhotos);

    void _pickImage(ImageSource source, StateSetter setStateDialog) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setStateDialog(() {
          currentPhotos.add(pickedFile.path);
        });
      }
    }

    Widget _buildPhotoPreview(String photoPath, int index, StateSetter setStateDialog) {
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
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
              onPressed: () {
                setStateDialog(() {
                  currentPhotos.removeAt(index);
                });
              },
            ),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(tr('Memo & Photos for $cityName', entities: [cityName])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: memoController,
                      maxLines: 3,
                      decoration:  InputDecoration(
                        labelText: tr('Memo'),
                        border: OutlineInputBorder(),
                      ),
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
                            showModalBottomSheet(
                              context: context,
                              builder: (modalContext) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title:  Text(tr('Photo Library')),
                                      onTap: () {
                                        Navigator.pop(modalContext);
                                        _pickImage(ImageSource.gallery, setStateDialog);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_camera),
                                      title:  Text(tr('Camera')),
                                      onTap: () {
                                        Navigator.pop(modalContext);
                                        _pickImage(ImageSource.camera, setStateDialog);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Icon(Icons.add_a_photo, color: Colors.blue)),
                          ),
                        ),
                        ...currentPhotos.asMap().entries.map((entry) {
                          return _buildPhotoPreview(entry.value, entry.key, setStateDialog);
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child:  Text(tr('Cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    onSave(memoController.text, currentPhotos);
                    Navigator.pop(dialogContext);
                  },
                  child:  Text(tr('Save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCityDetailsModal(City city, CityProvider cityProvider) {
    _mapController.move(LatLng(city.latitude, city.longitude), 5.0);
    setState(() {
      _highlightedCityName = null;
      _tappedLocation = null;
      _tappedCityNameForTag = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Consumer2<CityProvider, CountryProvider>(
          builder: (context, provider, countryProvider, child) {
            final cityVisitDetail = provider.visitDetails[city.name];
            final hasLived = cityVisitDetail?.hasLived ?? false;
            final isHome = provider.getCityHomeStatus(city.name);
            final isVisited = provider.isVisited(city.name);
            final isWishlisted = cityVisitDetail?.isWishlisted ?? false;

            final tappedCityCountry = countryProvider.allCountries.firstWhereOrNull(
                  (c) => c.isoA2 == city.countryIsoA2,
            );

            final countryName = tappedCityCountry?.name ?? city.countryIsoA2;
            final headerColor = tappedCityCountry?.themeColor ?? Theme.of(context).primaryColor;

            const headerTextColor = Colors.white;

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
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    headerColor,
                                    headerColor.withOpacity(0.9),
                                  ],
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
                                    Colors.black.withOpacity(0.8),
                                  ],
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
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                      },
                                      child:  Text(tr('Cancel'), style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: headerTextColor,
                                      ),
                                      child: Text(tr('Done'), style: TextStyle(fontWeight: FontWeight.bold, color: headerColor)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              city.name,
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: headerTextColor, fontSize: 26),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (isVisited)
                                            const Icon(Icons.check_circle, color: headerTextColor, size: 24),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.note_alt_outlined, color: headerTextColor),
                                      onPressed: () {
                                        final memo = provider.visitDetails[city.name]?.memo ?? '';
                                        final photos = provider.visitDetails[city.name]?.photos ?? [];
                                        _showMemoAndPhotoDialog(context, city.name, memo, photos, (newMemo, newPhotos) {
                                          provider.updateCityMemoAndPhotos(city.name, newMemo, newPhotos);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tr('$countryName | Lived: ${hasLived ? 'Yes' : 'No'} | Home: ${isHome ? 'Yes' : 'No'} | Wishlist: ${isWishlisted ? 'Yes' : 'No'}'),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildCityDetailsContent(context, city, provider),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCityDetailsContent(BuildContext context, City city, CityProvider provider) {
    final cityVisitDetail = provider.visitDetails[city.name];
    final hasLived = cityVisitDetail?.hasLived ?? false;
    final isHome = provider.getCityHomeStatus(city.name);
    final isWishlisted = cityVisitDetail?.isWishlisted ?? false;
    final visitedCount = cityVisitDetail?.visitDateRanges.length ?? 0;
    final totalDuration = cityVisitDetail?.totalDurationInDays() ?? 0;
    final rating = cityVisitDetail?.rating ?? 0.0;
    final wishlistColor = _wishlistColor;


    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                icon: Icon(
                  isHome ? Icons.home_rounded : Icons.home_outlined,
                  color: isHome ? Theme.of(context).primaryColor : Colors.grey,
                ),
                onPressed: () {
                  provider.setCityHomeStatus(city.name, !isHome);
                },
              ),
              const SizedBox(width: 6),
               Text(tr('Lived:'), style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Checkbox(
                visualDensity: VisualDensity.compact,
                value: hasLived,
                onChanged: (bool? value) {
                  provider.toggleCityLivedStatus(city.name);
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                icon: Icon(
                  isWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: isWishlisted ? wishlistColor : Colors.grey,
                ),
                onPressed: () {
                  provider.toggleCityWishlistStatus(city.name);
                },
              ),
              const Spacer(),
              _StarRating(
                rating: cityVisitDetail?.rating ?? 0.0,
                onRatingChanged: (rating) {
                  provider.setCityRating(city.name, rating);
                },
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('History ($visitedCount visits, $totalDuration days)'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label:  Text(tr('Add Visit')),
                onPressed: () {
                  provider.addCityDateRange(city.name);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (cityVisitDetail != null && cityVisitDetail.visitDateRanges.isNotEmpty)
            ...cityVisitDetail.visitDateRanges.asMap().entries.map((entry) {
              final index = entry.key;
              final dateRange = entry.value;
              return _CityVisitDetailEditorSheet(
                key: ValueKey('${city.name}_visit_$index'),
                range: dateRange,
                onSave: (updatedRange) {
                  provider.updateCityDateRange(city.name, index, updatedRange);
                },
                onDelete: () {
                  provider.removeCityDateRange(city.name, index);
                },
              );
            }).toList()
          else
             Center(child: Text(tr('No visits recorded.'))),
        ],
      ),
    );
  }

  Widget _buildLegendWidget() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showHome) _legendRow(_homeColor, 'Home'),
            if (_showLived) _legendRow(_livedColor, 'Lived'),
            if (_showWishlist) _legendRow(_wishlistColor, 'Wishlist'),
            const Divider(height: 6, thickness: 0.5),
            _colorMode == CitiesColorMode.byVisits ? _buildVisitCountLegendContent() :
            _colorMode == CitiesColorMode.byDuration ? _buildDurationLegendContent() :
            _colorMode == CitiesColorMode.byRating ? _buildRatingLegendContent() :
            _colorMode == CitiesColorMode.byContinent ? _buildContinentLegendContent() :
            _colorMode == CitiesColorMode.bySubregion ? _buildSubregionLegendContent() :
            _colorMode == CitiesColorMode.sameColor ? _buildSameColorLegendContent() :
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCountLegendContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _byVisitRanges.asMap().entries.map((entry) {
        final index = entry.key;
        final range = entry.value;
        String label;

        if (index == _byVisitRanges.length - 1) {
          label = '${range.from}+ Visits';
        } else {
          final nextRange = _byVisitRanges[index + 1];
          if (nextRange.from - 1 == range.from) {
            label = '${range.from} Visit${range.from > 1 ? 's' : ''}';
          } else {
            label = '${range.from}-${nextRange.from - 1} Visits';
          }
        }
        return _legendRow(range.color, label);
      }).toList(),
    );
  }

  Widget _buildDurationLegendContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendRow(_unknownDurationColor, 'Unknown / Invalid'),
        ..._byDurationRanges.asMap().entries.map((entry) {
          final index = entry.key;
          final range = entry.value;
          String label;

          if (index == _byDurationRanges.length - 1) {
            label = '${range.fromDays}+ Days';
          } else {
            final nextRange = _byDurationRanges[index + 1];
            if (nextRange.fromDays - 1 == range.fromDays) {
              label = '${range.fromDays} Day${range.fromDays > 1 ? 's' : ''}';
            } else {
              label = '${range.fromDays}-${nextRange.fromDays - 1} Days';
            }
          }
          return _legendRow(range.color, label);
        }).toList(),
      ],
    );
  }

  Widget _buildRatingLegendContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendRow(_unknownRatingColor, 'Unknown'),
        ..._byRatingRanges.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          String label;
          if (index == _byRatingRanges.length - 1) {
            label = '${category.rating.toStringAsFixed(1)}+ Stars';
          } else {
            final nextCategory = _byRatingRanges[index + 1];
            label = '${category.rating.toStringAsFixed(1)} - ${(nextCategory.rating - 0.5).toStringAsFixed(1)} Stars';
          }
          return _legendRow(category.color, label);
        }).toList(),
      ],
    );
  }

  Widget _buildContinentLegendContent() {
    final countryProvider = context.read<CountryProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: countryProvider.allCountries
          .map((c) => c.continent)
          .whereType<String>()
          .toSet()
          .where((continent) => continentFullNames.contains(continent))
          .map((continent) {
        final color = _byContinentColors[continent] ?? Colors.grey.shade500;
        return _legendRow(color, continent);
      }).toList(),
    );
  }

  Widget _buildSubregionLegendContent() {
    final countryProvider = context.read<CountryProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: countryProvider.allCountries
          .map((c) => c.subregion)
          .whereType<String>()
          .toSet()
          .map((subregion) {
        final color = _bySubregionColors[subregion] ?? Colors.grey.shade500;
        return _legendRow(color, subregion);
      }).toList(),
    );
  }

  Widget _buildSameColorLegendContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendRow(_sameColor, 'Visited Cities'),
      ],
    );
  }

  Widget _legendRow(Color color, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 6),
          Text(tr(name), style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  void _showColorSettingsDialog() {
    var tempSizingMode = _sizingMode;
    var tempFixedMarkerRadius = _fixedMarkerRadius;

    var tempColorMode = _colorMode;
    var tempHomeColor = _homeColor;
    var tempLivedColor = _livedColor;
    var tempSameColor = _sameColor;
    var tempUnknownDurationColor = _unknownDurationColor;
    var tempUnknownRatingColor = _unknownRatingColor;
    var tempShowHome = _showHome;
    var tempShowLived = _showLived;
    var tempShowUnvisited = _showUnvisited;
    var tempShowLegend = _showLegend;
    var tempShowWishlist = _showWishlist;
    var tempWishlistColor = _wishlistColor;

    var tempShowFlags = _showFlags;

    var tempByVisitRanges = _byVisitRanges.map((e) => e.copyWith(
        from: int.tryParse(e.controller.text) ?? e.from
    )).toList();
    for (var range in tempByVisitRanges) {
      range.controller = TextEditingController(text: range.from.toString());
    }

    var tempByDurationRanges = _byDurationRanges.asMap().entries.map((entry) {
      final e = entry.value;
      final fromDays = entry.key == 0 ? 0 : (int.tryParse(e.controller.text) ?? e.fromDays);
      return e.copyWith(fromDays: fromDays);
    }).toList();
    for (var range in tempByDurationRanges) {
      range.controller = TextEditingController(text: range.fromDays.toString());
    }


    var tempByRatingRanges = _byRatingRanges.map((e) => e.copyWith()).toList();
    var tempByContinentColors = Map<String, Color>.from(_byContinentColors);
    var tempBySubregionColors = Map<String, Color>.from(_bySubregionColors);

    void updateSizingMode(StateSetter setStateDialog, SizingMode mode, bool isEnabled) {
      setStateDialog(() {
        if (isEnabled) {
          tempSizingMode = mode;
        } else {
          if (tempSizingMode == mode) {
            tempSizingMode = null;
          }
        }
      });
    }

    void showInvalidInputError(String message) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title:  Text(tr('Invalid Input')),
          content: Text(tr(message)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child:  Text(tr('OK')))],
        ),
      );
    }

    void validateAndSave() {
      if (tempColorMode == CitiesColorMode.byDuration) {
        if (tempByDurationRanges.length < 2 || tempByDurationRanges.length > 10) {
          showInvalidInputError('Visit duration categories must be between 2 and 10.');
          return;
        }

        for (int i = 1; i < tempByDurationRanges.length; i++) {
          final from = int.tryParse(tempByDurationRanges[i].controller.text);
          final prevFrom = int.tryParse(tempByDurationRanges[i - 1].controller.text);

          if (from == null || from < 1) {
            showInvalidInputError('Duration days must be a positive number (except for the fixed 0-day category).');
            return;
          }
          if (from <= (prevFrom ?? 0)) {
            showInvalidInputError('Duration days must be in strictly increasing order.');
            return;
          }
        }
      }

      if (tempColorMode == CitiesColorMode.byVisits) {
        if (tempByVisitRanges.length < 2 || tempByVisitRanges.length > 10) {
          showInvalidInputError('Visit count categories must be between 2 and 10.');
          return;
        }
        for (int i = 0; i < tempByVisitRanges.length; i++) {
          final from = int.tryParse(tempByVisitRanges[i].controller.text);
          if (from == null || from < 1) {
            showInvalidInputError('Visit count must be a positive number.');
            return;
          }
          if (i > 0) {
            final prevFrom = int.tryParse(tempByVisitRanges[i - 1].controller.text);
            if (from <= prevFrom!) {
              showInvalidInputError('Visit counts must be in increasing order.');
              return;
            }
          }
        }
      }
      if (tempColorMode == CitiesColorMode.byRating) {
        if (tempByRatingRanges.length < 2 || tempByRatingRanges.length > 10) {
          showInvalidInputError('Rating categories must be between 2 and 10.');
          return;
        }
        for (int i = 0; i < tempByRatingRanges.length; i++) {
          if (i > 0) {
            if (tempByRatingRanges[i].rating <= tempByRatingRanges[i - 1].rating) {
              showInvalidInputError('Ratings must be in increasing order.');
              return;
            }
          }
        }
      }


      setState(() {
        _sizingMode = tempSizingMode;
        _fixedMarkerRadius = tempFixedMarkerRadius;

        _colorMode = tempColorMode;
        _homeColor = tempHomeColor;
        _livedColor = tempLivedColor;
        _sameColor = tempSameColor;
        _unknownDurationColor = tempUnknownDurationColor;
        _unknownRatingColor = tempUnknownRatingColor;
        _showHome = tempShowHome;
        _showLived = tempShowLived;
        _showUnvisited = tempShowUnvisited;
        _showLegend = tempShowLegend;
        _showWishlist = tempShowWishlist;
        _wishlistColor = tempWishlistColor;

        _showFlags = tempShowFlags;

        for (var range in _byVisitRanges) {
          range.controller.dispose();
        }
        for (var range in tempByVisitRanges) {
          range.from = int.parse(range.controller.text);
        }
        _byVisitRanges = tempByVisitRanges;

        for (var range in _byDurationRanges) {
          range.controller.dispose();
        }
        for (int i = 0; i < tempByDurationRanges.length; i++) {
          final range = tempByDurationRanges[i];
          range.fromDays = i == 0 ? 0 : int.parse(range.controller.text);
        }
        _byDurationRanges = tempByDurationRanges;

        _byRatingRanges = tempByRatingRanges;
        _byContinentColors = tempByContinentColors;
        _bySubregionColors = tempBySubregionColors;
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
              title:  Text(tr('Pick a color')),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: onColorChanged,
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
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            color: currentColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 1.5),
          ),
        ),
      );
    }

    Widget buildColorPickerRow(String label, Color currentColor, ValueChanged<Color> onColorChanged) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(tr(label)),
            buildColorPicker(currentColor, onColorChanged),
          ],
        ),
      );
    }

    Widget buildHomeLivedSettings(StateSetter setStateDialog) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(tr('Home & Lived Colors'), style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(tr('Show Home Color')),
              Switch(
                value: tempShowHome,
                onChanged: (value) => setStateDialog(() => tempShowHome = value),
              ),
            ],
          ),
          if (tempShowHome)
            buildColorPickerRow('Home Color', tempHomeColor, (color) => setStateDialog(() => tempHomeColor = color)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(tr('Show Lived Color')),
              Switch(
                value: tempShowLived,
                onChanged: (value) => setStateDialog(() => tempShowLived = value),
              ),
            ],
          ),
          if (tempShowLived)
            buildColorPickerRow('Lived Color', tempLivedColor, (color) => setStateDialog(() => tempLivedColor = color)),
          const Divider(),
           Text(tr('Wishlist'), style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(tr('Show Wishlist')),
              Switch(
                value: tempShowWishlist,
                onChanged: (value) => setStateDialog(() => tempShowWishlist = value),
              ),
            ],
          ),
          if (tempShowWishlist)
            buildColorPickerRow('Wishlist Color', tempWishlistColor, (color) => setStateDialog(() => tempWishlistColor = color)),
          const Divider(),
        ],
      );
    }


    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title:  Text(tr('City Map Color Settings')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(tr('Marker Style'), style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(tr('Show Flags instead of Dots')),
                        Switch(
                          value: tempShowFlags,
                          onChanged: (val) => setStateDialog(() => tempShowFlags = val),
                        ),
                      ],
                    ),
                    const Divider(),

                     Text(tr('Marker Sizing'), style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(tr('By Population')),
                        Switch(
                          value: tempSizingMode == SizingMode.population,
                          onChanged: (val) => updateSizingMode(setStateDialog, SizingMode.population, val),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(tr('By Duration')),
                        Switch(
                          value: tempSizingMode == SizingMode.duration,
                          onChanged: (val) => updateSizingMode(setStateDialog, SizingMode.duration, val),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(tr('By Visit Count')),
                        Switch(
                          value: tempSizingMode == SizingMode.visitCount,
                          onChanged: (val) => updateSizingMode(setStateDialog, SizingMode.visitCount, val),
                        ),
                      ],
                    ),

                    if (tempSizingMode == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(tr('Fixed Marker Size: ${tempFixedMarkerRadius.toStringAsFixed(1)} (1.0 ~ 6.0)')),
                          Slider(
                            value: tempFixedMarkerRadius,
                            min: 1.0,
                            max: 6.0,
                            divisions: 50,
                            label: tempFixedMarkerRadius.toStringAsFixed(1),
                            onChanged: (double value) {
                              setStateDialog(() {
                                tempFixedMarkerRadius = value;
                              });
                            },
                          ),
                        ],
                      ),
                    const Divider(),
                    buildHomeLivedSettings(setStateDialog),
                     Text(tr('Color Mode'), style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<CitiesColorMode>(
                      title:  Text(tr('Same Color')),
                      value: CitiesColorMode.sameColor,
                      groupValue: tempColorMode,
                      onChanged: (value) => setStateDialog(() => tempColorMode = value!),
                    ),
                    if (tempColorMode == CitiesColorMode.sameColor)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 4.0),
                        child: buildColorPickerRow('Visited Cities Color', tempSameColor, (color) => setStateDialog(() => tempSameColor = color)),
                      ),
                    RadioListTile<CitiesColorMode>(
                      title:  Text(tr('By Visits')),
                      value: CitiesColorMode.byVisits,
                      groupValue: tempColorMode,
                      onChanged: (value) => setStateDialog(() => tempColorMode = value!),
                    ),
                    RadioListTile<CitiesColorMode>(
                      title:  Text(tr('By Duration')),
                      value: CitiesColorMode.byDuration,
                      groupValue: tempColorMode,
                      onChanged: (value) => setStateDialog(() => tempColorMode = value!),
                    ),
                    RadioListTile<CitiesColorMode>(
                      title:  Text(tr('By Rating')),
                      value: CitiesColorMode.byRating,
                      groupValue: tempColorMode,
                      onChanged: (value) => setStateDialog(() => tempColorMode = value!),
                    ),
                    RadioListTile<CitiesColorMode>(
                      title:  Text(tr('By Continent')),
                      value: CitiesColorMode.byContinent,
                      groupValue: tempColorMode,
                      onChanged: (value) => setStateDialog(() => tempColorMode = value!),
                    ),
                    RadioListTile<CitiesColorMode>(
                      title:  Text(tr('By Subregion')),
                      value: CitiesColorMode.bySubregion,
                      groupValue: tempColorMode,
                      onChanged: (value) => setStateDialog(() => tempColorMode = value!),
                    ),
                    const Divider(),
                    if (tempColorMode == CitiesColorMode.byVisits) ...[
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
                                ),
                              ),
                              const SizedBox(width: 10),
                               Expanded(flex: 2, child: Text(tr("Visits"))),
                              buildColorPicker(range.color, (newColor) => setStateDialog(() => range.color = newColor)),
                            ],
                          ),
                        );
                      }),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (tempByVisitRanges.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => setStateDialog(() {
                                tempByVisitRanges.removeLast();
                              }),
                            ),
                          Text(tr('${tempByVisitRanges.length} Categories')),
                          if (tempByVisitRanges.length < 10)
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () => setStateDialog(() {
                                final lastFrom = int.tryParse(tempByVisitRanges.last.controller.text) ?? tempByVisitRanges.last.from;
                                tempByVisitRanges.add(VisitCountRange(from: lastFrom + 1, color: Colors.primaries[Random().nextInt(Colors.primaries.length)]));
                              }),
                            ),
                        ],
                      ),
                    ],

                    if (tempColorMode == CitiesColorMode.byDuration) ...[
                       Text(tr('Visit Duration Ranges (in days)'), style: TextStyle(fontWeight: FontWeight.bold)),
                      buildColorPickerRow('Unknown / Invalid Duration', tempUnknownDurationColor, (color) => setStateDialog(() => tempUnknownDurationColor = color)),
                      const Divider(),
                      ...List.generate(tempByDurationRanges.length, (index) {
                        final range = tempByDurationRanges[index];
                        final isFixedZero = index == 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: range.controller,
                                  decoration: InputDecoration(
                                    labelText: tr(index < tempByDurationRanges.length - 1 ? 'From' : 'From (and up)'),
                                    isDense: true,
                                    filled: isFixedZero,
                                    fillColor: isFixedZero ? Colors.grey.shade200 : null,
                                  ),
                                  keyboardType: TextInputType.number,
                                  readOnly: isFixedZero,
                                ),
                              ),
                              const SizedBox(width: 10),
                               Expanded(flex: 2, child: Text(tr("Days"))),
                              buildColorPicker(range.color, (newColor) => setStateDialog(() => range.color = newColor)),
                            ],
                          ),
                        );
                      }),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (tempByDurationRanges.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => setStateDialog(() {
                                tempByDurationRanges.removeLast();
                              }),
                            ),
                          Text(tr('${tempByDurationRanges.length} Categories')),
                          if (tempByDurationRanges.length < 10)
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () => setStateDialog(() {
                                final lastRange = tempByDurationRanges.last;
                                final lastFrom = int.tryParse(lastRange.controller.text) ?? lastRange.fromDays;
                                tempByDurationRanges.add(DurationRange(fromDays: lastFrom + 1, color: Colors.primaries[Random().nextInt(Colors.primaries.length)]));
                              }),
                            ),
                        ],
                      ),
                    ],

                    if (tempColorMode == CitiesColorMode.byRating) ...[
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (tempByRatingRanges.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => setStateDialog(() {
                                tempByRatingRanges.removeLast();
                              }),
                            ),
                          Text(tr('${tempByRatingRanges.length} Categories')),
                          if (tempByRatingRanges.length < 10)
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () => setStateDialog(() {
                                final lastRating = tempByRatingRanges.last.rating;
                                tempByRatingRanges.add(RatingCategory(rating: min(lastRating + 0.5, 5.0), color: Colors.primaries[Random().nextInt(Colors.primaries.length)]));
                              }),
                            ),
                        ],
                      ),
                    ],
                    if (tempColorMode == CitiesColorMode.byContinent) ...[
                       Text(tr('Continent Colors'), style: TextStyle(fontWeight: FontWeight.bold)),
                      ...tempByContinentColors.entries.map((entry) => buildColorPickerRow(
                        entry.key,
                        entry.value,
                            (color) => setStateDialog(() => tempByContinentColors[entry.key] = color),
                      )).toList(),
                    ],

                    if (tempColorMode == CitiesColorMode.bySubregion) ...[
                       Text(tr('Subregion Colors'), style: TextStyle(fontWeight: FontWeight.bold)),
                      ...tempBySubregionColors.entries.map((entry) => buildColorPickerRow(
                        entry.key,
                        entry.value,
                            (color) => setStateDialog(() => tempBySubregionColors[entry.key] = color),
                      )).toList(),
                    ],
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).buttonTheme.colorScheme?.secondary ?? Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child:  Text(tr('Defaults'), style: TextStyle(fontSize: 8)),
                          onPressed: () {
                            setStateDialog(() {
                              tempSizingMode = SizingMode.population;
                              tempFixedMarkerRadius = 2.5;

                              tempColorMode = CitiesColorMode.sameColor;
                              tempSameColor = Colors.amber;
                              tempHomeColor = Colors.black;
                              tempLivedColor = Colors.brown.shade700;
                              tempUnknownDurationColor = Colors.grey.shade300;
                              tempUnknownRatingColor = Colors.grey.shade300;
                              tempShowHome = true;
                              tempShowLived = true;
                              tempShowUnvisited = false;
                              tempShowLegend = true;
                              tempShowWishlist = true;
                              tempWishlistColor = Colors.red.shade700;

                              tempShowFlags = true;

                              for (var range in tempByVisitRanges) {
                                range.controller.dispose();
                              }
                              tempByVisitRanges = [
                                VisitCountRange(from: 1, color: const Color(0xFFADD8E6)),
                                VisitCountRange(from: 2, color: const Color(0xFF87CEEB)),
                                VisitCountRange(from: 3, color: const Color(0xFF1E90FF)),
                                VisitCountRange(from: 4, color: const Color(0xFF4169E1)),
                                VisitCountRange(from: 5, color: const Color(0xFF6A0DAD)),
                              ];
                              for (var range in tempByVisitRanges) {
                                range.controller = TextEditingController(text: range.from.toString());
                              }

                              for (var range in tempByDurationRanges) {
                                range.controller.dispose();
                              }
                              tempByDurationRanges = [
                                DurationRange(fromDays: 0, color: Colors.indigo.shade100),
                                DurationRange(fromDays: 1, color: Colors.cyan.shade200),
                                DurationRange(fromDays: 3, color: Colors.cyan.shade400),
                                DurationRange(fromDays: 7, color: Colors.cyan.shade600),
                                DurationRange(fromDays: 30, color: Colors.cyan.shade800),
                                DurationRange(fromDays: 90, color: Colors.teal.shade900),
                              ];
                              for (var range in tempByDurationRanges) {
                                range.controller = TextEditingController(text: range.fromDays.toString());
                              }

                              tempByRatingRanges = [
                                RatingCategory(rating: 1.0, color: Colors.red.shade300),
                                RatingCategory(rating: 2.0, color: Colors.orange.shade400),
                                RatingCategory(rating: 3.0, color: Colors.yellow.shade600),
                                RatingCategory(rating: 4.0, color: Colors.lightGreen.shade500),
                                RatingCategory(rating: 4.5, color: Colors.green.shade700),
                              ];

                              tempByContinentColors = {
                                'Europe': Colors.yellow.shade700,
                                'Asia': Colors.pink.shade300,
                                'Africa': Colors.brown.shade400,
                                'North America': Colors.blue.shade400,
                                'South America': Colors.green.shade400,
                                'Oceania': Colors.purple.shade400,
                              };
                              tempBySubregionColors = {
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
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ElevatedButton(
                          child:  Text(tr('Cancel'), style: TextStyle(fontSize: 9)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child:  Text(tr('Done'), style: TextStyle(fontSize: 9)),
                          onPressed: validateAndSave,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

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
    Localizations.maybeLocaleOf(context);
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


class CityVisitControlTile extends StatelessWidget {
  final City city;
  final String countryName;
  final VoidCallback onTap;
  final VoidCallback onCenterMap;
  final VoidCallback onToggleWishlist;
  final Function(bool) onToggleVisited;
  final bool isWishlisted;
  final Color wishlistColor;
  final bool showWishlistControls;

  const CityVisitControlTile({
    super.key,
    required this.city,
    required this.countryName,
    required this.onTap,
    required this.onCenterMap,
    required this.onToggleWishlist,
    required this.onToggleVisited,
    required this.isWishlisted,
    required this.wishlistColor,
    required this.showWishlistControls,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final cityProvider = context.watch<CityProvider>();
    final isVisited = cityProvider.isVisited(city.name);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipOval(
                  child: CountryFlag.fromCountryCode(
                    city.countryIsoA2,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(city.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                        tr('$countryName  ${NumberFormat.compact().format(city.population)}'),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                    ),
                  ],
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.explore, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: onCenterMap,
                    tooltip: tr('Center map'),
                  ),
                  if (showWishlistControls)
                    IconButton(
                      icon: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: isWishlisted ? wishlistColor : Colors.grey,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleWishlist,
                      tooltip: tr(isWishlisted ? 'Remove from wishlist' : 'Add to wishlist'),
                    ),
                ],
              ),

              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  isVisited ? Icons.check_circle : Icons.check_circle_outline,
                  color: isVisited ? Colors.amber : Colors.grey.shade400,
                  size: 24,
                ),
                onPressed: () => onToggleVisited(!isVisited),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityVisitDetailEditorSheet extends StatefulWidget {
  final DateRange range;
  final ValueChanged<DateRange> onSave;
  final VoidCallback onDelete;

  const _CityVisitDetailEditorSheet({
    super.key,
    required this.range,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_CityVisitDetailEditorSheet> createState() =>
      _CityVisitDetailEditorSheetState();
}

class _CityVisitDetailEditorSheetState extends State<_CityVisitDetailEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late final TextEditingController _durationController;
  late bool _isLayover;
  late bool _isTransfer;

  int? _arrivalYear, _arrivalMonth, _arrivalDay;
  int? _departureYear, _departureMonth, _departureDay;
  List<String> _currentPhotos = [];
  late final TextEditingController _citiesController;

  final ExpansionTileController _expansionTileController = ExpansionTileController();


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
    if (_arrivalYear == null || _arrivalMonth == null || _arrivalDay == null ||
        _departureYear == null || _departureMonth == null || _departureDay == null) {
      return null;
    }

    final arrivalDate = DateTime(_arrivalYear!, _arrivalMonth!, _arrivalDay!);
    final departureDate = DateTime(_departureYear!, _departureMonth!, _departureDay!);

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
           SnackBar(content: Text(tr('Departure date cannot be before arrival date.'))),
        );
        return;
      }
    }

    final isAllDatesKnown = _arrivalYear != null && _arrivalMonth != null && _arrivalDay != null &&
        _departureYear != null && _departureMonth != null && _departureDay != null;

    final calculatedDuration = isAllDatesKnown ? _calculateDuration() : null;
    final finalDuration = userDuration ?? calculatedDuration;

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
      departure: _departureYear != null && _departureMonth != null && _departureDay != null
          ? DateTime(_departureYear!, _departureMonth!, _departureDay!)
          : null,
      photos: _currentPhotos,
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

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final int? calculatedDuration = _calculateDuration();
    final int? finalDuration = widget.range.userDefinedDuration ?? calculatedDuration;
    final String durationText = finalDuration?.toString() ?? (widget.range.isDurationUnknown ? 'Unknown' : '');

    if (widget.range.userDefinedDuration == null) {
      if (finalDuration != null && _durationController.text != finalDuration.toString()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted) {
            _durationController.text = finalDuration.toString();
          }
        });
      } else if (finalDuration == null && _durationController.text.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted) {
            _durationController.text = '';
          }
        });
      }
    }


    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 1,
      child: ExpansionTile(
        controller: _expansionTileController,
        title: Text(tr(widget.range.title.isNotEmpty ? widget.range.title : 'Visit Record')),
        subtitle: Text(tr('${widget.range.arrival != null ? DateFormat('yyyy-MM-dd').format(widget.range.arrival!) : 'Unknown'} - '
            '${widget.range.departure != null ? DateFormat('yyyy-MM-dd').format(widget.range.departure!) : 'Unknown'} (Duration: $durationText days)')),
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
                  onChanged: (val) {
                    final updatedRange = widget.range.copyWith(title: val);
                    widget.onSave(updatedRange);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _memoController,
                  decoration:  InputDecoration(labelText: tr('Memo'), border: const OutlineInputBorder()),
                  maxLines: 3,
                  onChanged: (val) {
                    final updatedRange = widget.range.copyWith(memo: val);
                    widget.onSave(updatedRange);
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
                _buildDateSection('Arrival', _arrivalYear, _arrivalMonth, _arrivalDay, (y, m, d) {
                  setState(() {
                    _arrivalYear = y;
                    _arrivalMonth = m;
                    _arrivalDay = d;
                    widget.range.userDefinedDuration = null;

                    final updatedRange = widget.range.copyWith(
                      arrival: y != null && m != null && d != null ? DateTime(y, m, d) : null,
                    );
                    widget.onSave(updatedRange);
                  });
                }),
                const SizedBox(height: 12),
                _buildDateSection('Departure', _departureYear, _departureMonth, _departureDay, (y, m, d) {
                  setState(() {
                    _departureYear = y;
                    _departureMonth = m;
                    _departureDay = d;
                    widget.range.userDefinedDuration = null;

                    final updatedRange = widget.range.copyWith(
                      departure: y != null && m != null && d != null ? DateTime(y, m, d) : null,
                    );
                    widget.onSave(updatedRange);
                  });
                }),
                const SizedBox(height: 12),
                TextField(
                  controller: _durationController,
                  decoration:  InputDecoration(labelText: tr('Duration (days)'), border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (val) {
                    final duration = int.tryParse(val);
                    final updatedRange = widget.range.copyWith(
                      userDefinedDuration: duration,
                    );
                    widget.onSave(updatedRange);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Text(tr('Transfer')),
                          Checkbox(
                            value: _isTransfer,
                            onChanged: (val) {
                              setState(() => _isTransfer = val ?? false);
                              widget.onSave(widget.range.copyWith(isTransfer: val ?? false));
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Text(tr('Layover')),
                          Checkbox(
                            value: _isLayover,
                            onChanged: (val) {
                              setState(() => _isLayover = val ?? false);
                              widget.onSave(widget.range.copyWith(isLayover: val ?? false));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onDelete,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        child:  Text(tr('Delete'), style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        child:  Text(tr('Save')),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(label), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
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
    );
  }

  Widget _buildDropdown<T>(
      String hint, T? value, List<T> items, ValueChanged<T?> onChanged) {
    return DropdownButtonFormField<T>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
          labelText: tr(hint),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
      items: items
          .map((item) => DropdownMenuItem<T>(
        value: item,
        child: Text(
          tr(item?.toString() ?? 'Unknown'),
          style: TextStyle(
            fontSize: (item == null) ? 11.0 : 15.0,
            color: (item == null) ? Colors.grey.shade600 : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

void showExternalCityDetailsModal(BuildContext context, City city) {
  final cityProvider = Provider.of<CityProvider>(context, listen: false);
  final countryProvider = Provider.of<CountryProvider>(context, listen: false);

  void showMemoAndPhotoDialog(BuildContext context, String cityName, String initialMemo, List<String> initialPhotos, Function(String, List<String>) onSave) {
    final TextEditingController memoController = TextEditingController(text: initialMemo);
    List<String> currentPhotos = List.from(initialPhotos);

    void pickImage(ImageSource source, StateSetter setStateDialog) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setStateDialog(() {
          currentPhotos.add(pickedFile.path);
        });
      }
    }

    Widget buildPhotoPreview(String photoPath, int index, StateSetter setStateDialog) {
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
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
              onPressed: () {
                setStateDialog(() {
                  currentPhotos.removeAt(index);
                });
              },
            ),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(tr('Memo & Photos for $cityName', entities: [cityName])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: memoController,
                      maxLines: 3,
                      decoration:  InputDecoration(
                        labelText: tr('Memo'),
                        border: OutlineInputBorder(),
                      ),
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
                            showModalBottomSheet(
                              context: context,
                              builder: (modalContext) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title:  Text(tr('Photo Library')),
                                      onTap: () {
                                        Navigator.pop(modalContext);
                                        pickImage(ImageSource.gallery, setStateDialog);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.photo_camera),
                                      title:  Text(tr('Camera')),
                                      onTap: () {
                                        Navigator.pop(modalContext);
                                        pickImage(ImageSource.camera, setStateDialog);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Icon(Icons.add_a_photo, color: Colors.blue)),
                          ),
                        ),
                        ...currentPhotos.asMap().entries.map((entry) {
                          return buildPhotoPreview(entry.value, entry.key, setStateDialog);
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child:  Text(tr('Cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    onSave(memoController.text, currentPhotos);
                    Navigator.pop(dialogContext);
                  },
                  child:  Text(tr('Save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return Consumer2<CityProvider, CountryProvider>(
        builder: (context, provider, countryProvider, child) {
          final cityVisitDetail = provider.visitDetails[city.name];
          final hasLived = cityVisitDetail?.hasLived ?? false;
          final isHome = provider.getCityHomeStatus(city.name);
          final isVisited = provider.isVisited(city.name);
          final isWishlisted = cityVisitDetail?.isWishlisted ?? false;

          final tappedCityCountry = countryProvider.allCountries.firstWhereOrNull(
                (c) => c.isoA2 == city.countryIsoA2,
          );

          final countryName = tappedCityCountry?.name ?? city.countryIsoA2;
          final headerColor = tappedCityCountry?.themeColor ?? Theme.of(context).primaryColor;

          const headerTextColor = Colors.white;

          final visitedCount = cityVisitDetail?.visitDateRanges.length ?? 0;
          final totalDuration = cityVisitDetail?.totalDurationInDays() ?? 0;
          final wishlistColor = Colors.red.shade700;

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
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  headerColor,
                                  headerColor.withOpacity(0.9),
                                ],
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
                                  Colors.black.withOpacity(0.8),
                                ],
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
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                    },
                                    child:  Text(tr('Cancel'), style: TextStyle(color: headerTextColor, fontWeight: FontWeight.bold)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: headerTextColor,
                                    ),
                                    child: Text(tr('Done'), style: TextStyle(fontWeight: FontWeight.bold, color: headerColor)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            city.name,
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: headerTextColor, fontSize: 26),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isVisited)
                                          const Icon(Icons.check_circle, color: headerTextColor, size: 24),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.note_alt_outlined, color: headerTextColor),
                                    onPressed: () {
                                      final memo = provider.visitDetails[city.name]?.memo ?? '';
                                      final photos = provider.visitDetails[city.name]?.photos ?? [];
                                      showMemoAndPhotoDialog(context, city.name, memo, photos, (newMemo, newPhotos) {
                                        provider.updateCityMemoAndPhotos(city.name, newMemo, newPhotos);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tr('$countryName | Lived: ${hasLived ? 'Yes' : 'No'} | Home: ${isHome ? 'Yes' : 'No'} | Wishlist: ${isWishlisted ? 'Yes' : 'No'}'),
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: headerTextColor.withOpacity(0.8)),
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
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  icon: Icon(
                                    isHome ? Icons.home_rounded : Icons.home_outlined,
                                    color: isHome ? Theme.of(context).primaryColor : Colors.grey,
                                  ),
                                  onPressed: () {
                                    provider.setCityHomeStatus(city.name, !isHome);
                                  },
                                ),
                                const SizedBox(width: 6),
                                 Text(tr('Lived:'), style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Checkbox(
                                  visualDensity: VisualDensity.compact,
                                  value: hasLived,
                                  onChanged: (bool? value) {
                                    provider.toggleCityLivedStatus(city.name);
                                  },
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  icon: Icon(
                                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                                    color: isWishlisted ? wishlistColor : Colors.grey,
                                  ),
                                  onPressed: () {
                                    provider.toggleCityWishlistStatus(city.name);
                                  },
                                ),
                                const Spacer(),
                                _StarRating(
                                  rating: cityVisitDetail?.rating ?? 0.0,
                                  onRatingChanged: (rating) {
                                    provider.setCityRating(city.name, rating);
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tr('History ($visitedCount visits, $totalDuration days)'),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label:  Text(tr('Add Visit')),
                                  onPressed: () {
                                    provider.addCityDateRange(city.name);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (cityVisitDetail != null && cityVisitDetail.visitDateRanges.isNotEmpty)
                              ...cityVisitDetail.visitDateRanges.asMap().entries.map((entry) {
                                final index = entry.key;
                                final dateRange = entry.value;
                                return _CityVisitDetailEditorSheet(
                                  key: ValueKey('${city.name}_visit_$index'),
                                  range: dateRange,
                                  onSave: (updatedRange) {
                                    provider.updateCityDateRange(city.name, index, updatedRange);
                                  },
                                  onDelete: () {
                                    provider.removeCityDateRange(city.name, index);
                                  },
                                );
                              }).toList()
                            else
                               Center(child: Text(tr('No visits recorded.'))),
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
      );
    },
  );
}
