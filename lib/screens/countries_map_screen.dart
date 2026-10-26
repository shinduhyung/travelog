// lib/screens/countries_map_screen.dart

import 'dart:ui'; // 글래스모피즘 효과
import 'package:flutter/material.dart';
import 'package:jidoapp/services/screen_tracking.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/widgets/visited_world_map_layer.dart';
// TODO(old-map): 고지도 모드를 되살릴 때 주석 해제
// import 'package:jidoapp/widgets/old_map_view.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/country_selection_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:math';
import 'dart:convert';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

// -----------------------------------------------------------------------------
// Models & Enums
// -----------------------------------------------------------------------------

enum CountriesColorMode { byVisits, byDuration, byRating, byContinent, bySubregion, sameColor, wishlist }

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

class HighlightGroup {
  String name;
  Color color;
  List<String> countryCodes;
  bool ignoreVisitedOpacity;

  HighlightGroup({
    required this.name,
    required this.color,
    required this.countryCodes,
    this.ignoreVisitedOpacity = false,
  });
}

enum GroupBy { continent, subregion }

// -----------------------------------------------------------------------------
// Main Screen
// -----------------------------------------------------------------------------

class CountriesMapScreen extends StatefulWidget {
  final String? region;
  final bool initialShowRegions;
  final List<HighlightGroup>? highlightGroups;

  const CountriesMapScreen({
    super.key,
    this.region,
    this.initialShowRegions = false,
    this.highlightGroups,
  });

  @override
  State<CountriesMapScreen> createState() => _CountriesMapScreenState();
}

class _CountriesMapScreenState extends State<CountriesMapScreen> {
  final MapController _mapController = MapController();
  bool _useWhiteBorders = false;
  bool _showRegions = false;
  // TODO(old-map): 고지도 모드를 되살릴 때 주석 해제
  // bool _oldMapTheme = false;
  // static const _oldMapInk = Color(0xFFB3261E);

  // --- 색상 설정 관련 상태 변수 ---
  late CountriesColorMode _colorMode;
  late List<VisitCountRange> _byVisitRanges;
  late List<DurationRange> _byDurationRanges;
  late List<RatingCategory> _byRatingRanges;
  late Color _homeColor;
  late Color _nonHomeLivedColor;
  late Color _unknownDurationColor;
  late Color _unknownRatingColor;
  late Color _sameColor;
  late Color _wishlistColor;

  static Map<String, Color> _byContinentColors = {};
  static Map<String, Color> _bySubregionColors = {};

  bool _showLegend = true;
  bool _showUnvisited = true;
  bool _showHome = true;
  bool _showNonHomeLived = true;
  bool _showWishlist = true;
  bool _isFullScreen = false;

  late final bool _isHighlightMode;
  late List<HighlightGroup> _currentHighlightGroups;

  static final Map<String, Map<String, dynamic>> _continentData = {
    'Europe': {'bounds': LatLngBounds(const LatLng(34, -35), const LatLng(72, 50))},
    'Asia': {'bounds': LatLngBounds(const LatLng(-12, 15), const LatLng(82, 190))},
    'Africa': {'bounds': LatLngBounds(const LatLng(-40, -28), const LatLng(40, 75))},
    'North America': {'bounds': LatLngBounds(const LatLng(5, -175), const LatLng(85, -10))},
    'South America': {'bounds': LatLngBounds(const LatLng(-60, -105), const LatLng(15, -25))},
    'Oceania': {'bounds': LatLngBounds(const LatLng(-50, 110), const LatLng(15, 180))},
  };

  static Map<String, Color> get continentColors => _byContinentColors;
  static Map<String, Color> get subregionColors => _bySubregionColors;

  @override
  void initState() {
    super.initState();
    _showRegions = widget.initialShowRegions;

    _isHighlightMode = widget.highlightGroups != null && widget.highlightGroups!.isNotEmpty;
    if (_isHighlightMode) {
      _currentHighlightGroups = widget.highlightGroups!.map((g) => HighlightGroup(
          name: g.name, color: g.color, countryCodes: g.countryCodes, ignoreVisitedOpacity: g.ignoreVisitedOpacity
      )).toList();
    }

    _loadBorderSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isWorldView = widget.region == null;
        final worldBounds = LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180));
        final boundsToFit = isWorldView ? worldBounds : _continentData[widget.region]!['bounds'] as LatLngBounds;

        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: boundsToFit,
            padding: const EdgeInsets.all(25.0),
          ),
        );
      }
    });

    _colorMode = CountriesColorMode.byContinent;
    _sameColor = Colors.blue.shade300;
    _wishlistColor = Colors.red.shade700;
    _homeColor = Colors.black;
    _nonHomeLivedColor = Colors.brown.shade700;
    _unknownDurationColor = Colors.grey.shade300;
    _unknownRatingColor = Colors.grey.shade300;

    // 기본 방문 횟수별 색상
    _byVisitRanges = [
      VisitCountRange(from: 1, color: const Color(0xFFADD8E6)), // 1회
      VisitCountRange(from: 2, color: const Color(0xFF87CEEB)), // 2회
      VisitCountRange(from: 3, color: const Color(0xFF1E90FF)), // 3회
      VisitCountRange(from: 4, color: const Color(0xFF4169E1)), // 4회
      VisitCountRange(from: 5, color: const Color(0xFF6A0DAD)), // 5회
    ];

    _byDurationRanges = [
      DurationRange(fromDays: 1, color: Colors.cyan.shade200),
      DurationRange(fromDays: 7, color: Colors.cyan.shade400),
      DurationRange(fromDays: 30, color: Colors.cyan.shade600),
      DurationRange(fromDays: 90, color: Colors.cyan.shade800),
      DurationRange(fromDays: 365, color: Colors.teal.shade900),
    ];
    _byRatingRanges = [
      RatingCategory(rating: 1.0, color: Colors.red.shade300),
      RatingCategory(rating: 2.0, color: Colors.orange.shade400),
      RatingCategory(rating: 3.0, color: Colors.yellow.shade600),
      RatingCategory(rating: 4.0, color: Colors.lightGreen.shade500),
      RatingCategory(rating: 4.5, color: Colors.green.shade700),
    ];
    _byContinentColors = {
      'Europe': Colors.yellow.shade700,
      'Asia': Colors.pink.shade300,
      'Africa': Colors.brown.shade400,
      'North America': Colors.blue.shade400,
      'South America': Colors.green.shade400,
      'Oceania': Colors.purple.shade400,
      'Antarctica': Colors.lightBlue.shade100,
    };
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

    _loadColorSettings();
  }

  @override
  void dispose() {
    if (!_isHighlightMode) {
      for (var range in _byVisitRanges) {
        range.controller.dispose();
      }
      for (var range in _byDurationRanges) {
        range.controller.dispose();
      }
    }

    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);
    }
  }

  Future<void> _loadBorderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _useWhiteBorders = prefs.getBool('useWhiteBorders') ?? false;
      });
    }
  }

  Future<void> _loadColorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final mode = prefs.getString('countriesColorMode');
        _colorMode = CountriesColorMode.values.firstWhere(
              (e) => e.toString() == 'CountriesColorMode.$mode',
          orElse: () => CountriesColorMode.byContinent,
        );
        _sameColor = Color(prefs.getInt('countriesSameColor') ?? Colors.blue.shade300.value);
        _wishlistColor = Color(prefs.getInt('countryWishlistColor') ?? Colors.red.shade700.value);
        _homeColor = Color(prefs.getInt('homeColor') ?? Colors.black.value);
        _nonHomeLivedColor = Color(prefs.getInt('nonHomeLivedColor') ?? Colors.brown.shade700.value);
        _unknownDurationColor = Color(prefs.getInt('unknownDurationColor') ?? Colors.grey.shade300.value);
        _unknownRatingColor = Color(prefs.getInt('unknownRatingColor') ?? Colors.grey.shade300.value);
        _showHome = prefs.getBool('showHome') ?? true;
        _showNonHomeLived = prefs.getBool('showNonHomeLived') ?? true;
        _showWishlist = prefs.getBool('showCountryWishlist') ?? true;
        _showLegend = prefs.getBool('showCountriesLegend') ?? true;
        _showUnvisited = prefs.getBool('showUnvisited') ?? true;

        final visitRangesJson = prefs.getString('byVisitRanges');
        if (visitRangesJson != null) {
          final List<dynamic> decoded = json.decode(visitRangesJson);
          _byVisitRanges = decoded.map((e) => VisitCountRange(
            from: e['from'],
            color: Color(e['color']),
          )).toList();
          for (var range in _byVisitRanges) {
            range.controller = TextEditingController(text: range.from.toString());
          }
        }

        final durationRangesJson = prefs.getString('byDurationRanges');
        if (durationRangesJson != null) {
          final List<dynamic> decoded = json.decode(durationRangesJson);
          _byDurationRanges = decoded.map((e) => DurationRange(
            fromDays: e['fromDays'],
            color: Color(e['color']),
          )).toList();
          for (var range in _byDurationRanges) {
            range.controller = TextEditingController(text: range.fromDays.toString());
          }
        }
        final ratingRangesJson = prefs.getString('byRatingRanges');
        if (ratingRangesJson != null) {
          final List<dynamic> decoded = json.decode(ratingRangesJson);
          _byRatingRanges = decoded.map((e) => RatingCategory(
            rating: (e['rating'] as num).toDouble(),
            color: Color(e['color']),
          )).toList();
        }

        final continentColorsJson = prefs.getString('byContinentColors');
        if (continentColorsJson != null) {
          final Map<String, dynamic> decoded = json.decode(continentColorsJson);
          _byContinentColors = decoded.map((key, value) => MapEntry(key, Color(value)));
        }

        final subregionColorsJson = prefs.getString('bySubregionColors');
        if (subregionColorsJson != null) {
          final Map<String, dynamic> decoded = json.decode(subregionColorsJson);
          _bySubregionColors = decoded.map((key, value) => MapEntry(key, Color(value)));
        }
      });
    }
  }

  Future<void> _saveColorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('countriesColorMode', _colorMode.toString().split('.').last);
    await prefs.setInt('countriesSameColor', _sameColor.value);
    await prefs.setInt('countryWishlistColor', _wishlistColor.value);
    await prefs.setInt('homeColor', _homeColor.value);
    await prefs.setInt('nonHomeLivedColor', _nonHomeLivedColor.value);
    await prefs.setInt('unknownDurationColor', _unknownDurationColor.value);
    await prefs.setInt('unknownRatingColor', _unknownRatingColor.value);
    await prefs.setBool('showHome', _showHome);
    await prefs.setBool('showNonHomeLived', _showNonHomeLived);
    await prefs.setBool('showCountryWishlist', _showWishlist);
    await prefs.setBool('showCountriesLegend', _showLegend);
    await prefs.setBool('showUnvisited', _showUnvisited);

    final visitRangesJson = json.encode(_byVisitRanges.map((e) => {
      'from': int.tryParse(e.controller.text) ?? e.from,
      'color': e.color.value,
    }).toList());
    await prefs.setString('byVisitRanges', visitRangesJson);

    final durationRangesJson = json.encode(_byDurationRanges.map((e) => {
      'fromDays': int.tryParse(e.controller.text) ?? e.fromDays,
      'color': e.color.value,
    }).toList());
    await prefs.setString('byDurationRanges', durationRangesJson);

    final ratingRangesJson = json.encode(_byRatingRanges.map((e) => {
      'rating': e.rating,
      'color': e.color.value,
    }).toList());
    await prefs.setString('byRatingRanges', ratingRangesJson);

    final continentColorsJson = json.encode(_byContinentColors.map((key, value) => MapEntry(key, value.value)));
    await prefs.setString('byContinentColors', continentColorsJson);

    final subregionColorsJson = json.encode(_bySubregionColors.map((key, value) => MapEntry(key, value.value)));
    await prefs.setString('bySubregionColors', subregionColorsJson);
  }

  // 🔥 [수정됨] 색상 결정 로직 개선
  Color _getPolygonColor(Country country, CountryProvider provider, {bool forceVisited = false}) {
    final details = provider.visitDetails[country.name];
    final bool isVisited = forceVisited || (details?.isVisited ?? false);
    final bool isWishlisted = details?.isWishlisted ?? false;
    final bool isHome = provider.homeCountryIsoA3 == country.isoA3;
    final bool hasLived = details?.hasLived ?? false;

    // 1. Home / Lived 우선 (설정된 경우)
    if (_showHome && isHome) {
      return _homeColor;
    }
    if (_showNonHomeLived && hasLived) {
      return _nonHomeLivedColor;
    }

    // 2. Wishlist Mode: 방문 여부 무시, 오직 위시리스트 여부만 체크
    if (_colorMode == CountriesColorMode.wishlist) {
      if (forceVisited || isWishlisted) {
        return _wishlistColor;
      }
      return Colors.grey.withOpacity(0.35);
    }

    // 3. 방문한 국가 처리
    if (isVisited) {
      Color baseColor;
      switch (_colorMode) {
        case CountriesColorMode.byVisits:
          final count = details?.visitCount ?? 1;
          baseColor = _byVisitRanges.firstWhere(
                  (r) => count >= r.from,
              orElse: () => _byVisitRanges.last
          ).color;
          break;
        case CountriesColorMode.byDuration:
          if (details == null || details.visitDateRanges.any((range) => range.isDurationUnknown)) {
            baseColor = _unknownDurationColor;
          } else {
            int totalDays = details.totalDurationInDays();
            baseColor = _byDurationRanges.firstWhere(
                    (r) => totalDays >= r.fromDays,
                orElse: () => _byDurationRanges.last
            ).color;
          }
          break;
        case CountriesColorMode.byRating:
          final rating = details?.rating ?? 0.0;
          if (rating == 0.0) {
            baseColor = _unknownRatingColor;
          } else {
            baseColor = _byRatingRanges.firstWhere(
                    (r) => rating >= r.rating,
                orElse: () => _byRatingRanges.last
            ).color;
          }
          break;
        case CountriesColorMode.byContinent:
          baseColor = provider.continentColors[country.continent] ?? Colors.grey.shade500;
          break;
        case CountriesColorMode.bySubregion:
          final subregionForColoring = (country.name == 'Iran') ? 'Western Asia' : country.subregion;
          baseColor = provider.subregionColors[subregionForColoring] ?? Colors.grey.shade500;
          break;
        case CountriesColorMode.sameColor:
          baseColor = _sameColor;
          break;
        default:
          baseColor = Colors.grey.shade500;
      }
      return baseColor;
    }

    // 4. 방문은 안 했지만 위시리스트인 경우 (다른 모드 사용 중일 때 오버레이)
    if (_showWishlist && isWishlisted) {
      return _wishlistColor;
    }

    // 5. 그 외 (미방문)
    return Colors.grey.withOpacity(0.35);
  }

  void _showHighlightColorSettingsDialog() {
    List<HighlightGroup> tempGroups = _currentHighlightGroups.map((g) => HighlightGroup(
        name: g.name, color: g.color, countryCodes: g.countryCodes, ignoreVisitedOpacity: g.ignoreVisitedOpacity
    )).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(tr('Legend Color Settings'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(tempGroups.length, (index) {
                    final group = tempGroups[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(tr(group.name), style: GoogleFonts.notoSansKr(), overflow: TextOverflow.ellipsis)),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Text(tr('Pick a color'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: group.color,
                                      onColorChanged: (newColor) {
                                        setStateDialog(() {
                                          tempGroups[index].color = newColor;
                                        });
                                      },
                                      displayThumbColor: true,
                                      enableAlpha: false,
                                      paletteType: PaletteType.hsvWithHue,
                                    ),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                                      child:  Text(tr('Select')),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: group.color,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('Cancel'), style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: () {
                    setState(() {
                      _currentHighlightGroups = tempGroups;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text(tr('Done'), style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // TODO(old-map): ⇄ 버튼에서 지도 모드(국가/지역/고지도)를 고르는 시트. 되살릴 때 주석 해제.
  // void _showMapModeSheet() {
  //   // 0: 국가 색칠, 1: 주(지역) 색칠, 2: 고지도(이드리시)
  //   final modes = <(IconData, String, String, bool)>[
  //     (Icons.public_rounded, tr('Visited countries'), tr('Color the countries you have visited'), !_showRegions && !_oldMapTheme),
  //     (Icons.grid_view_rounded, tr('Visited regions'), tr('Color the regions you have visited'), _showRegions && !_oldMapTheme),
  //     (Icons.auto_stories_rounded, tr('Idrisi map (1154)'), tr('Your countries on a medieval Islamic world map'), _oldMapTheme),
  //   ];
  //   showModalBottomSheet<void>(
  //     context: context,
  //     showDragHandle: true,
  //     builder: (sheetContext) => SafeArea(
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           for (var i = 0; i < modes.length; i++)
  //             ListTile(
  //               leading: Icon(modes[i].$1),
  //               title: Text(modes[i].$2),
  //               subtitle: Text(modes[i].$3),
  //               trailing: modes[i].$4 ? const Icon(Icons.check_rounded, color: Colors.teal) : null,
  //               onTap: () {
  //                 Navigator.of(sheetContext).pop();
  //                 setState(() {
  //                   _oldMapTheme = i == 2;
  //                   _showRegions = i == 1;
  //                 });
  //               },
  //             ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

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

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final seamlessBackgroundColor = const Color(0xfff5f5f5);
    final provider = Provider.of<CountryProvider>(context);

    return Scaffold(
      backgroundColor: seamlessBackgroundColor,
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.teal.shade300))
          : Stack(
        children: [
          // TODO(old-map): 되살릴 때 아래 블록을 주석 해제하고, 바로 뒤의 `FlutterMap(` 앞에 `else`를 붙인다.
          // if (_oldMapTheme)
          //   Builder(builder: (context) {
          //     final byIso = {for (final c in provider.allCountries) c.isoA3: c};
          //     final highlightMap = _isHighlightMode
          //         ? {for (final g in _currentHighlightGroups) for (final c in g.countryCodes) c: g}
          //         : const <String, HighlightGroup>{};
          //     return OldMapView(
          //       colorFor: (iso) {
          //         final country = byIso[iso];
          //         if (country == null) return null;
          //         if (widget.region != null && country.continent != widget.region) return null;
          //         // 고지도에서는 국가별로 색을 나누지 않고 한 가지 잉크색만 쓴다.
          //         if (_isHighlightMode) return highlightMap.containsKey(iso) ? _oldMapInk : null;
          //         final d = provider.visitDetails[country.name];
          //         final active = (d?.isVisited ?? false) ||
          //             (d?.hasLived ?? false) ||
          //             provider.homeCountryIsoA3 == iso;
          //         return active ? _oldMapInk : null;
          //       },
          //     );
          //   })
          // else
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              backgroundColor: Colors.transparent,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              Builder(
                builder: (context) {
                  final Map<String, HighlightGroup> highlightMap = _isHighlightMode ? { for (var g in _currentHighlightGroups) for (var c in g.countryCodes) c: g } : {};

                  final isWorldView = widget.region == null;
                  final countriesForThisView = isWorldView ? provider.allCountries : provider.allCountries.where((c) => c.continent == widget.region).toList();
                  if (_showRegions) {
                    return VisitedWorldMapLayer(
                      countries: countriesForThisView,
                      visitedCountries: provider.visitedCountries,
                      continentColors: provider.continentColors,
                      showRegions: true,
                      borderColor: _useWhiteBorders ? Colors.white70 : Colors.black26,
                      unvisitedColor: _showUnvisited ? Colors.grey.withValues(alpha: 0.35) : Colors.transparent,
                      showUnvisitedRegions: _showUnvisited,
                      regionColor: (country) => _isHighlightMode
                          ? highlightMap[country.isoA3]?.color ?? Colors.grey
                          : _getPolygonColor(country, provider, forceVisited: true),
                    );
                  }
                  final List<Polygon> polygonsToDraw = [];

                  for (var country in countriesForThisView) {
                    Color polygonColor;

                    if (_isHighlightMode) {
                      final highlightGroup = highlightMap[country.isoA3];
                      if (highlightGroup != null) {
                        final isVisited = provider.visitedCountries.contains(country.name);
                        if (!highlightGroup.ignoreVisitedOpacity && !isVisited) {
                          polygonColor = highlightGroup.color.withOpacity(0.35);
                        } else {
                          polygonColor = highlightGroup.color;
                        }
                      } else {
                        polygonColor = Colors.grey.withOpacity(0.2);
                      }
                    } else {
                      polygonColor = _getPolygonColor(country, provider);
                    }

                    for (var polygonData in country.polygonsData) {
                      polygonsToDraw.add(Polygon(
                        points: polygonData.first,
                        holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                        color: polygonColor,
                        borderColor: _useWhiteBorders ? Colors.white70 : Colors.black26,
                        borderStrokeWidth: 0.5,
                        isFilled: true,
                      ));
                    }
                  }
                  return PolygonLayer(polygons: polygonsToDraw);
                },
              ),
            ],
          ),

          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 16,
            // TODO(old-map): 되살릴 때 `_oldMapTheme ? const SizedBox.shrink() :`를 child 맨 앞에 추가(고지도에서는 범례 숨김)
            child: _isHighlightMode
                ? _buildHighlightLegend(_currentHighlightGroups)
                : (_showLegend ? _buildLegendWidget() : const SizedBox.shrink()),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: SafeArea(
              child: _buildBlurContainer(
                borderRadius: 30,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TODO(old-map): 되살릴 때 조건 맨 앞에 `!_oldMapTheme &&` 추가(고지도에서는 Show All 스위치 숨김)
                      if (!_isHighlightMode && (_colorMode == CountriesColorMode.byContinent || _colorMode == CountriesColorMode.bySubregion))
                        Padding(
                          padding: const EdgeInsets.only(left: 4, right: 12.0),
                          child: Row(
                            children: [
                              Text(tr('Show All'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 24,
                                width: 36,
                                child: Switch(
                                  value: _showUnvisited,
                                  onChanged: (value) {
                                    setState(() {
                                      _showUnvisited = value;
                                      _saveColorSettings();
                                    });
                                  },
                                  activeColor: Colors.teal,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),

                      Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 4)),

                      // TODO(old-map): 되살릴 때 아래 버튼을 다음으로 교체하고 _showMapModeSheet 주석 해제
                      // _buildIconButton(
                      //   icon: Icons.swap_horiz_rounded,
                      //   selected: _showRegions || _oldMapTheme,
                      //   onPressed: _showMapModeSheet,
                      //   tooltip: tr('Map style'),
                      // ),
                      _buildIconButton(
                        icon: Icons.swap_horiz_rounded,
                        selected: _showRegions,
                        onPressed: () => setState(() => _showRegions = !_showRegions),
                        tooltip: tr(_showRegions ? 'Show visited countries' : 'Show visited regions'),
                      ),
                      _buildIconButton(
                        icon: Icons.settings_rounded,
                        onPressed: _isHighlightMode ? _showHighlightColorSettingsDialog : _showColorSettingsDialog,
                        tooltip: tr('Settings'),
                      ),
                      if (!_isHighlightMode)
                        _buildIconButton(
                          icon: _showLegend ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          onPressed: () => setState(() => _showLegend = !_showLegend),
                          tooltip: tr(_showLegend ? 'Hide Legend' : 'Show Legend'),
                        ),
                      _buildIconButton(
                        icon: _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                        onPressed: _toggleFullScreen,
                        tooltip: tr(_isFullScreen ? 'Exit Fullscreen' : 'Fullscreen'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: provider.isLoading ? null : () {
          List<Country> countriesForSelection;
          if (widget.highlightGroups != null && widget.highlightGroups!.isNotEmpty) {
            final allHighlightedCodes = widget.highlightGroups!.expand((group) => group.countryCodes).toSet();
            countriesForSelection = provider.allCountries.where((country) => allHighlightedCodes.contains(country.isoA3)).toList();
          } else {
            final isWorldView = widget.region == null;
            countriesForSelection = isWorldView ? provider.allCountries : provider.allCountries.where((c) => c.continent == widget.region).toList();
          }

          showModalBottomSheet(
            context: context, isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => DraggableScrollableSheet(
              expand: false, initialChildSize: 0.8, maxChildSize: 0.9, minChildSize: 0.5,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: AnalyticsScreen(
                    name: 'country_selection',
                    child: CountrySelectionScreen(
                      allCountries: countriesForSelection,
                      groupBy: widget.region == null ? GroupBy.continent : GroupBy.subregion,
                      scrollController: scrollController,
                    ),
                  ),
                );
              },
            ),
          );
        },
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed, required String tooltip, bool selected = false}) {
    return IconButton(
      icon: Icon(icon, size: 22, color: selected ? Colors.teal : Colors.grey.shade800),
      onPressed: onPressed,
      tooltip: tr(tooltip),
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }

  Widget _buildLegendWidget() {
    final provider = Provider.of<CountryProvider>(context, listen: false);
    Widget content;

    switch (_colorMode) {
      case CountriesColorMode.byVisits:
        content = _buildVisitCountLegendContent();
        break;
      case CountriesColorMode.byDuration:
        content = _buildDurationLegendContent();
        break;
      case CountriesColorMode.byRating:
        content = _buildRatingLegendContent();
        break;
      case CountriesColorMode.byContinent:
      case CountriesColorMode.bySubregion:
        content = _buildColorModeLegendContent(provider);
        break;
      case CountriesColorMode.sameColor:
        content = _buildSameColorLegendContent();
        break;
      case CountriesColorMode.wishlist:
        content = _buildWishlistLegendContent();
        break;
      default:
        content = const SizedBox.shrink();
    }

    return _buildBlurContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: content,
        )
    );
  }

  Widget _buildWishlistLegendContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendRow(_wishlistColor, 'Wishlist'),
      ],
    );
  }

  Widget _buildColorModeLegendContent(CountryProvider provider) {
    final Set<String> addedLegendItems = {};
    final List<Widget> legendItems = [];

    _addCommonLegendItems(legendItems, addedLegendItems);

    if (_colorMode == CountriesColorMode.byContinent) {
      legendItems.addAll(provider.continentColors.entries
          .where((entry) => !addedLegendItems.contains(entry.key) && entry.key != 'Antarctica')
          .map((entry) => _legendRow(entry.value, entry.key))
          .toList());
    }
    if (_colorMode == CountriesColorMode.bySubregion) {
      legendItems.addAll(provider.subregionColors.entries
          .where((entry) => !addedLegendItems.contains(entry.key) && entry.key != 'Antarctica')
          .map((entry) => _legendRow(entry.value, entry.key))
          .toList());
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: legendItems
    );
  }

  Widget _buildHighlightLegend(List<HighlightGroup> groups) {
    return _buildBlurContainer(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: groups.map((group) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(color: group.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(tr(group.name), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildVisitCountLegendContent() {
    final Set<String> addedLegendItems = {};
    final List<Widget> legendItems = [];
    _addCommonLegendItems(legendItems, addedLegendItems);

    legendItems.addAll(_byVisitRanges.asMap().entries.map((entry) {
      final index = entry.key;
      final range = entry.value;
      String label;
      if (index == _byVisitRanges.length - 1) {
        label = '${range.from}+';
      } else {
        final nextRange = _byVisitRanges[index + 1];
        if (range.from == nextRange.from - 1) {
          label = '${range.from}';
        } else {
          label = '${range.from}-${nextRange.from - 1}';
        }
      }
      return _legendRow(range.color, label, suffix: " Visits");
    }).toList());

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: legendItems
    );
  }

  Widget _buildDurationLegendContent() {
    final Set<String> addedLegendItems = {};
    final List<Widget> legendItems = [];
    _addCommonLegendItems(legendItems, addedLegendItems);

    legendItems.add(_legendRow(_unknownDurationColor, 'Unknown'));
    legendItems.addAll(_byDurationRanges.asMap().entries.map((entry) {
      final index = entry.key;
      final range = entry.value;
      String label;
      if (index == _byDurationRanges.length - 1) {
        label = '${range.fromDays}+';
      } else {
        final nextRange = _byDurationRanges[index + 1];
        if (range.fromDays == nextRange.fromDays - 1) {
          label = '${range.fromDays}';
        } else {
          label = '${range.fromDays}-${nextRange.fromDays - 1}';
        }
      }
      return _legendRow(range.color, label, suffix: " Days");
    }).toList());

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: legendItems
    );
  }

  Widget _buildRatingLegendContent() {
    final Set<String> addedLegendItems = {};
    final List<Widget> legendItems = [];
    _addCommonLegendItems(legendItems, addedLegendItems);

    legendItems.add(_legendRow(_unknownRatingColor, 'Unknown'));
    legendItems.addAll(_byRatingRanges.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      String label;
      if (index == _byRatingRanges.length - 1) {
        label = '${category.rating}+';
      } else {
        final nextCategory = _byRatingRanges[index + 1];
        label = '${category.rating} - ${(nextCategory.rating - 0.5)}';
      }
      return _legendRow(category.color, label, suffix: " Stars");
    }).toList());

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: legendItems
    );
  }

  Widget _buildSameColorLegendContent() {
    final Set<String> addedLegendItems = {};
    final List<Widget> legendItems = [];
    _addCommonLegendItems(legendItems, addedLegendItems);

    legendItems.add(_legendRow(_sameColor, 'Visited'));
    legendItems.add(_legendRow(Colors.grey.withOpacity(0.35), 'Not Visited'));

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: legendItems
    );
  }

  void _addCommonLegendItems(List<Widget> legendItems, Set<String> addedLegendItems) {
    bool added = false;
    if (_showHome && !addedLegendItems.contains('Home')) {
      legendItems.add(_legendRow(_homeColor, 'Home'));
      addedLegendItems.add('Home');
      added = true;
    }
    if (_showNonHomeLived && !addedLegendItems.contains('Lived')) {
      legendItems.add(_legendRow(_nonHomeLivedColor, 'Lived'));
      addedLegendItems.add('Lived');
      added = true;
    }
    if (_showWishlist && !addedLegendItems.contains('Wishlist')) {
      legendItems.add(_legendRow(_wishlistColor, 'Wishlist'));
      addedLegendItems.add('Wishlist');
      added = true;
    }
    if (added) {
      legendItems.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0),
        child: Divider(height: 1, thickness: 0.5),
      ));
    }
  }

  Widget _legendRow(Color color, String name, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              text: tr(name),
              style: GoogleFonts.poppins(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
              children: suffix != null ? [
                TextSpan(text: tr(suffix), style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 11))
              ] : [],
            ),
          ),
        ],
      ),
    );
  }

  void _showColorSettingsDialog() {
    var tempColorMode = _colorMode;
    var tempHomeColor = _homeColor;
    var tempNonHomeLivedColor = _nonHomeLivedColor;
    var tempUnknownDurationColor = _unknownDurationColor;
    var tempUnknownRatingColor = _unknownRatingColor;
    var tempSameColor = _sameColor;
    var tempWishlistColor = _wishlistColor;
    var tempShowHome = _showHome;
    var tempShowNonHomeLived = _showNonHomeLived;
    var tempShowWishlist = _showWishlist;
    var tempShowLegend = _showLegend;
    var tempShowUnvisited = _showUnvisited;

    var tempByVisitRanges = _byVisitRanges.map((e) => VisitCountRange(
      from: int.tryParse(e.controller.text) ?? e.from,
      color: e.color,
    )).toList();
    for (var range in tempByVisitRanges) {
      range.controller = TextEditingController(text: range.from.toString());
    }

    var tempByDurationRanges = _byDurationRanges.map((e) => DurationRange(
      fromDays: int.tryParse(e.controller.text) ?? e.fromDays,
      color: e.color,
    )).toList();
    for (var range in tempByDurationRanges) {
      range.controller = TextEditingController(text: range.fromDays.toString());
    }

    var tempByRatingRanges = _byRatingRanges.map((e) => e.copyWith()).toList();

    var tempByContinentColors = Map<String, Color>.from(_byContinentColors);
    var tempBySubregionColors = Map<String, Color>.from(_bySubregionColors);

    void validateAndSave() {
      // 텍스트 필드 값 int로 반영
      for (var range in tempByVisitRanges) {
        range.from = int.tryParse(range.controller.text) ?? range.from;
      }
      for (var range in tempByDurationRanges) {
        range.fromDays = int.tryParse(range.controller.text) ?? range.fromDays;
      }

      // 기존 컨트롤러 dispose
      for (var range in _byVisitRanges) range.controller.dispose();
      for (var range in _byDurationRanges) range.controller.dispose();

      setState(() {
        _colorMode = tempColorMode;
        _sameColor = tempSameColor;
        _wishlistColor = tempWishlistColor;
        _homeColor = tempHomeColor;
        _nonHomeLivedColor = tempNonHomeLivedColor;
        _unknownDurationColor = tempUnknownDurationColor;
        _unknownRatingColor = tempUnknownRatingColor;
        _showHome = tempShowHome;
        _showNonHomeLived = tempShowNonHomeLived;
        _showWishlist = tempShowWishlist;
        _showLegend = tempShowLegend;
        _showUnvisited = tempShowUnvisited;
        _byContinentColors = tempByContinentColors;
        _bySubregionColors = tempBySubregionColors;

        _byVisitRanges = tempByVisitRanges;
        _byDurationRanges = tempByDurationRanges;
        _byRatingRanges = tempByRatingRanges;
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
                  style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
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
              title: Text(tr('Map Color Settings'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ----- 기본 설정 -----
                      if (widget.highlightGroups == null) ...[
                        Text(tr('Home, Lived & Wishlist'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(tr('Show Home'), style: GoogleFonts.poppins()),
                            Switch(
                                value: tempShowHome,
                                onChanged: (v) => setStateDialog(() => tempShowHome = v),
                                activeColor: Colors.teal
                            ),
                          ],
                        ),
                        if (tempShowHome)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, left: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [Text(tr('Home Color'), style: GoogleFonts.poppins(fontSize: 13)), buildColorPicker(tempHomeColor, (c) => setStateDialog(() => tempHomeColor = c))],
                            ),
                          ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(tr('Show Lived'), style: GoogleFonts.poppins()),
                            Switch(
                                value: tempShowNonHomeLived,
                                onChanged: (v) => setStateDialog(() => tempShowNonHomeLived = v),
                                activeColor: Colors.teal
                            ),
                          ],
                        ),
                        if (tempShowNonHomeLived)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, left: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [Text(tr('Lived Color'), style: GoogleFonts.poppins(fontSize: 13)), buildColorPicker(tempNonHomeLivedColor, (c) => setStateDialog(() => tempNonHomeLivedColor = c))],
                            ),
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
                              children: [Text(tr('Wishlist Color'), style: GoogleFonts.poppins(fontSize: 13)), buildColorPicker(tempWishlistColor, (c) => setStateDialog(() => tempWishlistColor = c))],
                            ),
                          ),

                        const Divider(height: 24),
                        Text(tr('Color Mode'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),

                        ...CountriesColorMode.values.map((mode) {
                          String title = mode.toString().split('.').last;
                          if(mode == CountriesColorMode.byVisits) title = "By Visits";
                          else if(mode == CountriesColorMode.byDuration) title = "By Duration";
                          else if(mode == CountriesColorMode.byRating) title = "By Rating";
                          else if(mode == CountriesColorMode.byContinent) title = "By Continent";
                          else if(mode == CountriesColorMode.bySubregion) title = "By Subregion";
                          else if(mode == CountriesColorMode.sameColor) title = "Same Color";
                          else if(mode == CountriesColorMode.wishlist) title = "Wishlist Only";

                          return RadioListTile<CountriesColorMode>(
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

                        // 1. Same Color 모드
                        if (tempColorMode == CountriesColorMode.sameColor)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tr('Visited Color'), style: GoogleFonts.poppins()),
                              buildColorPicker(tempSameColor, (c) => setStateDialog(() => tempSameColor = c))
                            ],
                          ),

                        // 2. By Visits 모드
                        if (tempColorMode == CountriesColorMode.byVisits) ...[
                          const SizedBox(height: 8),
                          Text(tr('Visit Count Colors'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
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
                                      tr(index == tempByVisitRanges.length - 1 ? 'Visits +' : 'Visits'),
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

                        // 3. By Duration 모드
                        if (tempColorMode == CountriesColorMode.byDuration) ...[
                          const SizedBox(height: 8),
                          Text(tr('Duration Colors (Days)'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          ...tempByDurationRanges.asMap().entries.map((entry) {
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
                                      tr(index == tempByDurationRanges.length - 1 ? 'Days +' : 'Days'),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tr('Unknown Duration'), style: GoogleFonts.poppins(fontSize: 13)),
                              buildColorPicker(tempUnknownDurationColor, (c) => setStateDialog(() => tempUnknownDurationColor = c))
                            ],
                          )
                        ],

                        // 4. By Rating 모드
                        if (tempColorMode == CountriesColorMode.byRating) ...[
                          const SizedBox(height: 8),
                          Text(tr('Rating Colors'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          ...tempByRatingRanges.asMap().entries.map((entry) {
                            int index = entry.key;
                            var category = entry.value;
                            String label;
                            if (index == tempByRatingRanges.length - 1) {
                              label = '${category.rating}+ Stars';
                            } else {
                              final nextCategory = tempByRatingRanges[index + 1];
                              label = '${category.rating} - ${(nextCategory.rating - 0.5)} Stars';
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(tr(label), style: GoogleFonts.poppins(fontSize: 13)),
                                  buildColorPicker(category.color, (newColor) {
                                    setStateDialog(() {
                                      category.color = newColor;
                                    });
                                  }),
                                ],
                              ),
                            );
                          }).toList(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tr('No Rating'), style: GoogleFonts.poppins(fontSize: 13)),
                              buildColorPicker(tempUnknownRatingColor, (c) => setStateDialog(() => tempUnknownRatingColor = c))
                            ],
                          )
                        ],

                        // 5. By Continent 모드
                        if (tempColorMode == CountriesColorMode.byContinent)
                          ExpansionTile(
                            title: Text(tr('Continent Colors'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                            initiallyExpanded: false,
                            tilePadding: EdgeInsets.zero,
                            children: tempByContinentColors.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(tr(entry.key), style: GoogleFonts.poppins(fontSize: 13)),
                                    buildColorPicker(entry.value, (newColor) {
                                      setStateDialog(() {
                                        tempByContinentColors[entry.key] = newColor;
                                      });
                                    }),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                        // 6. By Subregion 모드
                        if (tempColorMode == CountriesColorMode.bySubregion)
                          ExpansionTile(
                            title: Text(tr('Subregion Colors'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                            initiallyExpanded: false,
                            tilePadding: EdgeInsets.zero,
                            children: tempBySubregionColors.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(tr(entry.key), style: GoogleFonts.poppins(fontSize: 13))),
                                    buildColorPicker(entry.value, (newColor) {
                                      setStateDialog(() {
                                        tempBySubregionColors[entry.key] = newColor;
                                      });
                                    }),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text(tr('Reset'), style: GoogleFonts.poppins(color: Colors.redAccent)),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: Text(tr('Cancel'), style: GoogleFonts.poppins(color: Colors.grey)),
                  onPressed: () {
                    for (var range in tempByVisitRanges) range.controller.dispose();
                    for (var range in tempByDurationRanges) range.controller.dispose();
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
