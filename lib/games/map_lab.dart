// lib/games/map_lab.dart
//
// SELF-CONTAINED Map Lab.
// No flutter_map, no latlong2, no CountryProvider, no country model import.
//
// Required:
//   shared_preferences
//   assets/custom.geo.json

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MapLabTheme {
  antique,
  nautical,
  night,
  blueprint,
  classic,
}

class MapLabScreen extends StatefulWidget {
  const MapLabScreen({super.key});

  @override
  State<MapLabScreen> createState() => _MapLabScreenState();
}

class _MapLabScreenState extends State<MapLabScreen> {
  final TransformationController _transformController =
  TransformationController();

  final List<_MapCountry> _countries = <_MapCountry>[];
  final Map<String, _VisitState> _visitDetails = <String, _VisitState>{};

  bool _loading = true;
  String? _error;

  MapLabTheme _theme = MapLabTheme.antique;

  /// Distortion is fixed at a medium strength rather than user-adjustable
  /// -- always on, always this strength. Change this one constant if you
  /// want the fixed level to be stronger/weaker later.
  static const bool _warpEnabled = true;
  static const double _warpStrength = 0.5;

  bool _showDecorations = true;
  bool _visitedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final geoJsonText =
      await rootBundle.loadString('assets/custom.geo.json');
      final decoded = json.decode(geoJsonText);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid GeoJSON root.');
      }

      final features = decoded['features'];
      if (features is! List) {
        throw const FormatException('GeoJSON "features" array not found.');
      }

      final loadedCountries = <_MapCountry>[];

      for (final raw in features) {
        if (raw is! Map) continue;

        try {
          final country = _MapCountry.fromGeoJson(
            Map<String, dynamic>.from(raw),
          );

          if (country.polygonsData.isEmpty) continue;
          if (_skipCountry(country.name)) continue;

          loadedCountries.add(country);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('MapLab: skipped invalid feature: $e');
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final visitsRaw = prefs.getString('visit_details_v2');
      final loadedVisits = <String, _VisitState>{};

      if (visitsRaw != null && visitsRaw.trim().isNotEmpty) {
        try {
          final visitDecoded = json.decode(visitsRaw);

          if (visitDecoded is Map) {
            for (final entry in visitDecoded.entries) {
              if (entry.value is! Map) continue;

              final value =
              Map<String, dynamic>.from(entry.value as Map);

              loadedVisits[entry.key.toString()] = _VisitState(
                isVisited: value['isVisited'] == true,
                isWishlisted: value['isWishlisted'] == true,
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('MapLab: visit_details_v2 parse failed: $e');
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _countries
          ..clear()
          ..addAll(loadedCountries);

        _visitDetails
          ..clear()
          ..addAll(loadedVisits);

        _loading = false;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('MapLab load error: $e');
        debugPrintStack(stackTrace: st);
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool _skipCountry(String name) {
    const skipped = <String>{
      'Antarctica',
      'Siachen Glacier',
      'Indian Ocean Ter.',
      'Ashmore and Cartier Is.',
    };
    return skipped.contains(name);
  }

  int get _visitedCount =>
      _visitDetails.values.where((v) => v.isVisited).length;

  Future<void> _openCountrySelector() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const MapLabCountrySelector(),
      ),
    );

    if (changed == true) {
      await _loadData();
    }
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }

  _ThemeStyle get _style {
    switch (_theme) {
      case MapLabTheme.antique:
      // Palette modeled on real 18th-century copperplate atlases (e.g.
      // "Monde Connu des Anciens"): the paper itself IS the land color
      // -- there's no flat fill, just ink linework and hatching -- and
      // the only saturated color is the thin hand-painted wash along
      // borders. Ocean and land are deliberately close in value so the
      // coastline (ink stroke + hatch), not a color boundary, is what
      // defines the shape.
        return const _ThemeStyle(
          title: 'Antique Explorer',
          subtitle: 'Copperplate engraving on aged parchment',
          ocean: Color(0xFFCBAA6C),
          land: Color(0xFFDCC48D),
          visited: Color(0xFFA8481F),
          wishlist: Color(0xFF5C6B37),
          border: Color(0xFF2B1D0E),
          visitedBorder: Color(0xFF4A200D),
          accent: Color(0xFF2B1D0E),
          uiForeground: Color(0xFF241A0C),
          darkUi: false,
        );

      case MapLabTheme.nautical:
        return const _ThemeStyle(
          title: 'Nautical Chart',
          subtitle: 'Sea grid, compass details and exploration colors',
          ocean: Color(0xFFBBD3CE),
          land: Color(0xFFE8DFC3),
          visited: Color(0xFFB86843),
          wishlist: Color(0xFF557A72),
          border: Color(0xFF506760),
          visitedBorder: Color(0xFF70402D),
          accent: Color(0xFF315E62),
          uiForeground: Color(0xFF23484C),
          darkUi: false,
        );

      case MapLabTheme.night:
        return const _ThemeStyle(
          title: 'Night Earth',
          subtitle: 'Dark atlas with luminous visited countries',
          ocean: Color(0xFF050A12),
          land: Color(0xFF111D2A),
          visited: Color(0xFF25D7C4),
          wishlist: Color(0xFF667AF2),
          border: Color(0xFF293B50),
          visitedBorder: Color(0xFFA4FFF4),
          accent: Color(0xFF25D7C4),
          uiForeground: Color(0xFFE8FFFC),
          darkUi: true,
        );

      case MapLabTheme.blueprint:
        return const _ThemeStyle(
          title: 'Blueprint',
          subtitle: 'Technical grid and cyan linework',
          ocean: Color(0xFF0B2E54),
          land: Color(0xFF174C7B),
          visited: Color(0xFF6ED7FF),
          wishlist: Color(0xFF99CBFF),
          border: Color(0xFF63A9D4),
          visitedBorder: Color(0xFFDCF8FF),
          accent: Color(0xFF8CE4FF),
          uiForeground: Color(0xFFE7F9FF),
          darkUi: true,
        );

      case MapLabTheme.classic:
        return const _ThemeStyle(
          title: 'Classic',
          subtitle: 'Clean modern Travelog map',
          ocean: Color(0xFFF1F3F5),
          land: Color(0xFFDDE2E7),
          visited: Color(0xFF4D8CFF),
          wishlist: Color(0xFFE76B79),
          border: Color(0xFF9AA4AE),
          visitedBorder: Color(0xFF315FAB),
          accent: Color(0xFF3E63DD),
          uiForeground: Color(0xFF1F2933),
          darkUi: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final style = _style;

    return Scaffold(
      backgroundColor: style.ocean,
      body: _loading
          ? Center(
        child: CircularProgressIndicator(
          color: style.accent,
        ),
      )
          : _error != null
          ? _buildError(style)
          : Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1.0,
                maxScale: 8.0,
                panEnabled: true,
                scaleEnabled: true,
                clipBehavior: Clip.hardEdge,
                child: SizedBox.expand(
                  child: CustomPaint(
                    painter: _WorldMapPainter(
                      countries: _countries,
                      visitDetails: _visitDetails,
                      theme: _theme,
                      style: style,
                      warpEnabled: _warpEnabled,
                      warpStrength: _warpStrength,
                      showDecorations: _showDecorations,
                      visitedOnly: _visitedOnly,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildTopBar(style),
          _buildBottomControls(style),
        ],
      ),
    );
  }

  Widget _buildError(_ThemeStyle style) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: style.uiForeground,
            ),
            const SizedBox(height: 12),
            Text(
              tr('Map data could not be loaded.'),
              style: TextStyle(
                color: style.uiForeground,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(_error ?? ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: style.uiForeground.withOpacity(.65),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadData,
              child:  Text(tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(_ThemeStyle style) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GlassButton(
                dark: style.darkUi,
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GlassPanel(
                  dark: style.darkUi,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(style.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: style.uiForeground,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('$_visitedCount countries highlighted'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: style.uiForeground.withOpacity(.66),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _GlassButton(
                dark: style.darkUi,
                icon: Icons.checklist_rounded,
                onTap: _openCountrySelector,
              ),
              const SizedBox(width: 8),
              _GlassButton(
                dark: style.darkUi,
                icon: Icons.center_focus_strong_rounded,
                onTap: _resetView,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(_ThemeStyle style) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: MediaQuery.of(context).padding.bottom + 12,
      child: _GlassPanel(
        dark: style.darkUi,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(style.subtitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.uiForeground.withOpacity(.72),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MiniToggle(
                  label: 'Decor',
                  value: _showDecorations,
                  dark: style.darkUi,
                  accent: style.accent,
                  onChanged: (value) {
                    setState(() => _showDecorations = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_showDecorations) ...[
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _IconToggle(
                    tooltip: tr('Visited only'),
                    icon: Icons.visibility_rounded,
                    selected: _visitedOnly,
                    dark: style.darkUi,
                    accent: style.accent,
                    foreground: style.uiForeground,
                    onTap: () {
                      setState(() => _visitedOnly = !_visitedOnly);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapPoint {
  final double lat;
  final double lng;

  const _MapPoint(this.lat, this.lng);
}

class _MapCountry {
  final String name;
  final String isoA2;
  final String isoA3;

  /// country -> polygon -> ring -> point
  final List<List<List<_MapPoint>>> polygonsData;

  const _MapCountry({
    required this.name,
    required this.isoA2,
    required this.isoA3,
    required this.polygonsData,
  });

  factory _MapCountry.fromGeoJson(Map<String, dynamic> feature) {
    final rawProperties = feature['properties'];
    final rawGeometry = feature['geometry'];

    if (rawProperties is! Map || rawGeometry is! Map) {
      throw const FormatException('Invalid GeoJSON feature.');
    }

    final properties =
    Map<String, dynamic>.from(rawProperties);
    final geometry =
    Map<String, dynamic>.from(rawGeometry);

    final polygons =
    <List<List<_MapPoint>>>[];

    final coordinates = geometry['coordinates'];

    List<_MapPoint> parseRing(dynamic rawRing) {
      if (rawRing is! List) {
        return const <_MapPoint>[];
      }

      final points = <_MapPoint>[];

      for (final rawPoint in rawRing) {
        if (rawPoint is! List || rawPoint.length < 2) continue;

        final lng = rawPoint[0];
        final lat = rawPoint[1];

        if (lng is! num || lat is! num) continue;

        points.add(
          _MapPoint(
            lat.toDouble(),
            lng.toDouble(),
          ),
        );
      }

      return points;
    }

    void addPolygon(dynamic rawPolygon) {
      if (rawPolygon is! List) return;

      final rings = <List<_MapPoint>>[];

      for (final rawRing in rawPolygon) {
        final ring = parseRing(rawRing);

        if (ring.length >= 3) {
          rings.add(ring);
        }
      }

      if (rings.isNotEmpty) {
        polygons.add(rings);
      }
    }

    switch (geometry['type']) {
      case 'Polygon':
        addPolygon(coordinates);
        break;

      case 'MultiPolygon':
        if (coordinates is List) {
          for (final rawPolygon in coordinates) {
            addPolygon(rawPolygon);
          }
        }
        break;
    }

    String asString(
        dynamic value, {
          String fallback = '',
        }) {
      final text = value?.toString().trim();

      if (text == null || text.isEmpty) {
        return fallback;
      }

      return text;
    }

    final isoA3 = asString(
      properties['iso_a3_eh'] ?? properties['iso_a3'],
      fallback: 'N/A',
    );

    return _MapCountry(
      name: asString(
        properties['name'],
        fallback: isoA3,
      ),
      isoA2: asString(
        properties['iso_a2'],
        fallback: 'N/A',
      ),
      isoA3: isoA3,
      polygonsData: polygons,
    );
  }
}

class _VisitState {
  final bool isVisited;
  final bool isWishlisted;

  const _VisitState({
    required this.isVisited,
    required this.isWishlisted,
  });
}

class _WorldMapPainter extends CustomPainter {
  final List<_MapCountry> countries;
  final Map<String, _VisitState> visitDetails;
  final MapLabTheme theme;
  final _ThemeStyle style;
  final bool warpEnabled;
  final double warpStrength;
  final bool showDecorations;
  final bool visitedOnly;

  const _WorldMapPainter({
    required this.countries,
    required this.visitDetails,
    required this.theme,
    required this.style,
    required this.warpEnabled,
    required this.warpStrength,
    required this.showDecorations,
    required this.visitedOnly,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = style.ocean,
    );

    final worldRect = _worldRect(size);

    if (showDecorations) {
      _paintBackground(
        canvas,
        size,
        worldRect,
      );
    }

    canvas.save();
    canvas.clipRect(worldRect);

    for (final country in countries) {
      _paintCountry(
        canvas,
        worldRect,
        country,
      );
    }

    canvas.restore();

    if (showDecorations) {
      _paintForeground(
        canvas,
        size,
        worldRect,
      );
    }
  }

  Rect _worldRect(Size size) {
    const usableTop = 92.0;
    const usableBottom = 285.0;

    final availableHeight = math.max(
      1.0,
      size.height - usableTop - usableBottom,
    );

    final availableWidth = math.max(
      1.0,
      size.width,
    );

    // The map is rendered TALL (portrait) on purpose -- fit a 1:2
    // (width:height) rect instead of the world's natural 2:1 landscape
    // shape, then swap axes in _project() below. The whole world still
    // fits with nothing cropped; the user just rotates their device to
    // landscape to see it north-up, the way you'd unfold a real paper map.
    double height = availableHeight;
    double width = height / 2.0;

    if (width > availableWidth) {
      width = availableWidth;
      height = width * 2.0;
    }

    return Rect.fromLTWH(
      (size.width - width) / 2,
      usableTop +
          (availableHeight - height) / 2,
      width,
      height,
    );
  }

  void _paintCountry(
      Canvas canvas,
      Rect worldRect,
      _MapCountry country,
      ) {
    final details = visitDetails[country.name];

    final isVisited =
        details?.isVisited ?? false;

    final isWishlisted =
        details?.isWishlisted ?? false;

    final isAntiqueFamily =
        theme == MapLabTheme.antique || theme == MapLabTheme.nautical;

    // Land is opaque "paper" (nearly the same tone as the ocean, just a
    // touch lighter) so it fully covers the ocean's wave-hachure texture
    // underneath -- on a real chart, land isn't tinted at all, it's just
    // the sheet showing through. Visited/wishlisted get a faint watercolor
    // wash on top, the way old charts were lightly hand-tinted by hand.
    final fillColor = isVisited
        ? (isAntiqueFamily
        ? Color.alphaBlend(style.visited.withOpacity(.12), style.land)
        : style.visited)
        : isWishlisted
        ? (isAntiqueFamily
        ? Color.alphaBlend(style.wishlist.withOpacity(.10), style.land)
        : style.wishlist.withOpacity(.92))
        : visitedOnly
        ? style.land.withOpacity(.08)
        : style.land;

    // Borders are a single faint hairline -- old atlas plates barely mark
    // internal political lines at all, and modern country borders would
    // otherwise turn the map into a busy patchwork that doesn't match a
    // real engraving. Visited gets a touch more presence so it still
    // reads as "selected", not because it's meant to stand out much.
    final borderColor = isAntiqueFamily
        ? style.border.withOpacity(isVisited ? .22 : .13)
        : (isVisited
        ? style.visitedBorder
        : style.border.withOpacity(.82));

    final path = Path()
      ..fillType = PathFillType.evenOdd;

    for (final polygon in country.polygonsData) {
      if (polygon.isEmpty) continue;

      for (final ring in polygon) {
        if (ring.length < 3) continue;

        final first =
        _project(worldRect, ring.first);

        path.moveTo(
          first.dx,
          first.dy,
        );

        for (int i = 1;
        i < ring.length;
        i++) {
          final p =
          _project(worldRect, ring[i]);

          path.lineTo(
            p.dx,
            p.dy,
          );
        }

        path.close();
      }
    }

    if (path.getBounds().isEmpty) {
      return;
    }

    if (theme == MapLabTheme.night &&
        isVisited) {
      canvas.drawPath(
        path,
        Paint()
          ..color =
          style.visited.withOpacity(.22)
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            5.0,
          ),
      );
    }

    canvas.drawPath(
      path,
      Paint()..color = fillColor,
    );

    // Engraved cross-hatch on top of the wash for visited countries -- a
    // flat translucent color alone still reads as a modern "highlight";
    // real hand-tinted plates show the underlying engraving lines right
    // through the wash. Kept faint so it reads as texture, not a block
    // of color.
    if (isAntiqueFamily && isVisited) {
      _paintHatch(
        canvas,
        path,
        style.visitedBorder.withOpacity(.16),
        true,
      );
    }

    // Fine coastal hachure ticks -- short strokes perpendicular to every
    // coastline segment, clipped to the landmass so only the inward half
    // survives. This is the single detail most responsible for the "hand
    // engraved" look of a real antique plate versus a clean vector outline.
    if (isAntiqueFamily) {
      canvas.save();
      canvas.clipPath(path);

      final hachureColor =
      style.border.withOpacity(isVisited ? .18 : .10);

      for (final polygon in country.polygonsData) {
        for (final ring in polygon) {
          if (ring.length < 2) continue;
          _paintRingHachures(
            canvas,
            worldRect,
            ring,
            hachureColor,
            isVisited ? 7.0 : 6.0,
          );
        }
      }

      canvas.restore();
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth =
        isAntiqueFamily
            ? (isVisited ? .55 : .35)
            : (isVisited ? .95 : .46)
        ..color = borderColor,
    );
  }

  /// Short tick marks perpendicular to a coastline ring, spaced along its
  /// length. Drawn as full segments straddling the boundary and then
  /// clipped by the caller to the country path, so only the inward half of
  /// each tick survives -- regardless of the ring's winding direction, the
  /// result is a consistent "hairy coastline" fringe just inside the coast.
  void _paintRingHachures(
      Canvas canvas,
      Rect worldRect,
      List<_MapPoint> ring,
      Color color,
      double tickLength,
      ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5
      ..color = color;

    const spacing = 8.5;

    Offset prev = _project(worldRect, ring.first);
    double carried = 0;

    for (int i = 1; i < ring.length; i++) {
      final curr = _project(worldRect, ring[i]);
      final segment = curr - prev;
      final segLen = segment.distance;

      if (segLen < 0.0001) {
        prev = curr;
        continue;
      }

      final dir = Offset(segment.dx / segLen, segment.dy / segLen);
      final normal = Offset(-dir.dy, dir.dx);

      var dist = carried;
      while (dist < segLen) {
        final t = dist / segLen;
        final point = Offset(
          prev.dx + segment.dx * t,
          prev.dy + segment.dy * t,
        );

        canvas.drawLine(
          point - normal * (tickLength / 2),
          point + normal * (tickLength / 2),
          paint,
        );

        dist += spacing;
      }

      carried = dist - segLen;
      prev = curr;
    }
  }

  /// Parallel diagonal hatch lines clipped to `path` -- the classic
  /// copper-plate-engraving texture fill. Visited countries get a denser
  /// cross-hatch (two directions) so they read as "filled in" at a
  /// glance even at small zoom, matching how old atlases often marked
  /// regions of particular interest.
  void _paintHatch(
      Canvas canvas,
      Path path,
      Color color,
      bool crossHatch,
      ) {
    final bounds = path.getBounds();
    if (bounds.width <= 0 || bounds.height <= 0) return;

    canvas.save();
    canvas.clipPath(path);

    final hatchPaint = Paint()
      ..color = color
      ..strokeWidth = .55;

    const spacing = 3.6;
    final diagonal = bounds.width + bounds.height;

    // One direction, always.
    for (double offset = -diagonal; offset < diagonal; offset += spacing) {
      canvas.drawLine(
        Offset(bounds.left + offset, bounds.top),
        Offset(bounds.left + offset + bounds.height, bounds.top + bounds.height),
        hatchPaint,
      );
    }

    // Second direction, only for visited countries -- proper cross-hatch.
    if (crossHatch) {
      for (double offset = -diagonal; offset < diagonal; offset += spacing) {
        canvas.drawLine(
          Offset(bounds.left + offset, bounds.top + bounds.height),
          Offset(bounds.left + offset + bounds.height, bounds.top),
          hatchPaint,
        );
      }
    }

    canvas.restore();
  }

  Offset _project(
      Rect rect,
      _MapPoint point,
      ) {
    var nx =
        (point.lng + 180.0) / 360.0;

    var ny =
        (90.0 - point.lat) / 180.0;

    if (warpEnabled) {
      final s =
      warpStrength.clamp(0.0, 1.0);

      // Layered low-frequency waves -- this is what actually reads as
      // "hand-surveyed old map" rather than a modern precise projection.
      // Several overlapping frequencies avoid the single-sine-wave look
      // of a too-regular ripple.
      final w1 = math.sin(
        (ny * math.pi * 2.15) + .40,
      ) * .034 * s;

      final w2 = math.cos(
        (nx * math.pi * 1.65) - .90,
      ) * .027 * s;

      final w3 = math.sin(
        (nx + ny) * math.pi * 3.05,
      ) * .015 * s;

      final w4 = math.cos(
        (nx - ny) * math.pi * 2.55 + 1.15,
      ) * .012 * s;

      nx += w1 + w3;
      ny += w2 - w4;

      // Radial bulge toward the edges -- old flat projections routinely
      // stretched land near the poles and the map's outer edges far more
      // than the center. This exaggerates that visibly instead of the
      // barely-perceptible pull the original version had.
      final cx = nx - .5;
      final cy = ny - .5;

      nx += cx * (cy * cy) * .095 * s;
      ny += cy * (cx * cx) * .055 * s;

      // Tiny per-point jitter, seeded deterministically from the point's
      // own coordinates (so it's stable across repaints, not flickering
      // noise) -- reads as a hand-traced, slightly imprecise coastline.
      final seed =
          math.sin(point.lat * 12.9898 + point.lng * 78.233) * 43758.5453;
      final jitterA = seed - seed.floorToDouble();
      final seed2 = math.sin(point.lng * 39.346 + point.lat * 11.135) * 24634.6345;
      final jitterB = seed2 - seed2.floorToDouble();

      nx += (jitterA - .5) * .006 * s;
      ny += (jitterB - .5) * .006 * s;
    }

    return Offset(
      // Axes swapped on purpose (latitude -> horizontal, longitude ->
      // vertical) so the map fills the tall portrait rect from
      // _worldRect() above instead of being letterboxed. The latitude
      // axis is also MIRRORED (1-ny instead of ny) so the device has to
      // rotate the opposite direction from before to land north-up.
      rect.left + (1 - ny) * rect.width,
      rect.top + nx * rect.height,
    );
  }

  void _paintBackground(
      Canvas canvas,
      Size size,
      Rect worldRect,
      ) {
    switch (theme) {
      case MapLabTheme.antique:
        _paintAntiquePaper(
          canvas,
          size,
        );

        _paintOceanHachures(
          canvas,
          worldRect,
        );
        break;

      case MapLabTheme.nautical:
        _paintNauticalGrid(
          canvas,
          worldRect,
        );
        break;

      case MapLabTheme.night:
        _paintNightTexture(
          canvas,
          size,
        );
        break;

      case MapLabTheme.blueprint:
        _paintBlueprintGrid(
          canvas,
          worldRect,
        );
        break;

      case MapLabTheme.classic:
        _paintClassic(
          canvas,
          size,
        );
        break;
    }
  }

  void _paintForeground(
      Canvas canvas,
      Size size,
      Rect worldRect,
      ) {
    if (theme == MapLabTheme.antique ||
        theme == MapLabTheme.nautical) {
      _paintRhumbNetwork(
        canvas,
        worldRect,
      );

      _paintCompass(
        canvas,
        worldRect,
      );
    }

    if (theme == MapLabTheme.antique) {
      _paintAntiqueEdges(
        canvas,
        size,
      );

      _paintDecorativeRoutes(
        canvas,
        worldRect,
      );

      _paintSeaMonsters(
        canvas,
        worldRect,
      );

      _paintGraticuleTicks(
        canvas,
        worldRect,
      );

      _paintAgedBorderFrame(
        canvas,
        size,
      );
    }

    if (theme == MapLabTheme.nautical) {
      _paintDecorativeRoutes(
        canvas,
        worldRect,
      );

      _paintSeaMonsters(
        canvas,
        worldRect,
      );

      _paintGraticuleTicks(
        canvas,
        worldRect,
      );
    }

    if (theme == MapLabTheme.night) {
      _paintNightVignette(
        canvas,
        size,
      );
    }
  }

  void _paintAntiquePaper(
      Canvas canvas,
      Size size,
      ) {
    final wash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.2, -.1),
        radius: 1.15,
        colors: [
          const Color(0xFFF1E3B8)
              .withOpacity(.33),
          const Color(0xFF8B6337)
              .withOpacity(.17),
        ],
      ).createShader(
        Offset.zero & size,
      );

    canvas.drawRect(
      Offset.zero & size,
      wash,
    );

    // Foxing / age stains -- a handful of soft, irregular blotches, the
    // way old paper actually discolors, not an even wash. Positions are
    // hashed from index so they're stable across repaints.
    for (int i = 0; i < 6; i++) {
      final sx = ((i * 227 + 61) % 977) / 977 * size.width;
      final sy = ((i * 151 + 89) % 953) / 953 * size.height;
      final r = 26.0 + (i * 37 % 40);

      canvas.drawCircle(
        Offset(sx, sy),
        r,
        Paint()
          ..color = const Color(0xFF6E4A26).withOpacity(.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    // Two crossed fiber directions (instead of one) reads as woven paper
    // pulp rather than a pile of scratches all leaning the same way, and
    // at roughly 4x the density of the original.
    final fiberA = Paint()
      ..color = const Color(0xFF66482F).withOpacity(.065)
      ..strokeWidth = .55;

    final fiberB = Paint()
      ..color = const Color(0xFF4A331F).withOpacity(.05)
      ..strokeWidth = .5;

    for (int i = 0; i < 380; i++) {
      final x = ((i * 89) % 991) / 991 * size.width;
      final y = ((i * 37) % 997) / 997 * size.height;

      canvas.drawLine(
        Offset(x, y),
        Offset(
          math.min(size.width, x + 14 + i % 30),
          y + ((i % 5) - 2),
        ),
        fiberA,
      );
    }

    for (int i = 0; i < 260; i++) {
      final x = ((i * 151 + 40) % 983) / 983 * size.width;
      final y = ((i * 211 + 17) % 967) / 967 * size.height;

      canvas.drawLine(
        Offset(x, y),
        Offset(
          x + ((i % 7) - 3),
          math.min(size.height, y + 12 + i % 26),
        ),
        fiberB,
      );
    }

    // Fine stipple grain across the whole sheet -- this is the detail
    // that most reads as "engraved plate print" rather than flat color.
    final grain = Paint()..color = const Color(0xFF3E2C1A).withOpacity(.05);

    for (int i = 0; i < 900; i++) {
      final x = ((i * 311 + 71) % 1009) / 1009 * size.width;
      final y = ((i * 179 + 133) % 1013) / 1013 * size.height;

      canvas.drawCircle(
        Offset(x, y),
        .5 + (i % 3) * .18,
        grain,
      );
    }
  }

  /// Thin wavy engraved lines across the sea -- the classic copperplate
  /// way of marking open water (versus the blank, unmarked paper used for
  /// land). Drawn once as part of the background, before country polygons
  /// are painted, so land automatically covers it wherever it overlaps.
  void _paintOceanHachures(
      Canvas canvas,
      Rect rect,
      ) {
    canvas.save();
    canvas.clipRect(rect);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..color = style.border.withOpacity(.16);

    const rowSpacing = 7.5;
    const segment = 10.0;
    const waveHeight = 1.6;

    var row = 0;
    for (double y = rect.top; y < rect.bottom; y += rowSpacing) {
      // Alternate rows are offset half a segment so the ripple pattern
      // doesn't line up into a rigid grid -- reads as hand-engraved
      // rather than machine-ruled.
      final phase = row.isEven ? 0.0 : segment / 2;
      row++;

      final path = Path();
      var x = rect.left - segment;
      var started = false;

      while (x < rect.right + segment) {
        final localX = x + phase;
        final wave = math.sin((localX - rect.left) / segment * math.pi) *
            waveHeight;
        final point = Offset(localX, y + wave);

        if (!started) {
          path.moveTo(point.dx, point.dy);
          started = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }

        x += segment;
      }

      canvas.drawPath(path, linePaint);
    }

    canvas.restore();
  }

  void _paintNauticalGrid(
      Canvas canvas,
      Rect rect,
      ) {
    final p = Paint()
      ..color =
      style.accent.withOpacity(.13)
      ..strokeWidth = .65;

    for (int i = 0;
    i <= 12;
    i++) {
      final x =
          rect.left +
              rect.width * i / 12;

      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        p,
      );
    }

    for (int i = 0;
    i <= 6;
    i++) {
      final y =
          rect.top +
              rect.height * i / 6;

      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        p,
      );
    }

    final diagonal = Paint()
      ..color =
      style.accent.withOpacity(.07)
      ..strokeWidth = .5;

    for (double start =
        rect.left - rect.height;
    start < rect.right;
    start += rect.width / 7) {
      canvas.drawLine(
        Offset(
          start,
          rect.top,
        ),
        Offset(
          start + rect.height,
          rect.bottom,
        ),
        diagonal,
      );
    }
  }

  void _paintNightTexture(
      Canvas canvas,
      Size size,
      ) {
    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(.2, -.35),
        radius: .95,
        colors: [
          const Color(0xFF164D63)
              .withOpacity(.20),
          Colors.transparent,
        ],
      ).createShader(
        Offset.zero & size,
      );

    canvas.drawRect(
      Offset.zero & size,
      glow,
    );

    final star = Paint()
      ..color =
      Colors.white.withOpacity(.10);

    for (int i = 0;
    i < 90;
    i++) {
      final x =
          ((i * 83) % 997) /
              997 *
              size.width;

      final y =
          ((i * 47) % 991) /
              991 *
              size.height;

      canvas.drawCircle(
        Offset(x, y),
        .5 + (i % 3) * .22,
        star,
      );
    }
  }

  void _paintBlueprintGrid(
      Canvas canvas,
      Rect rect,
      ) {
    final minor = Paint()
      ..color =
      const Color(0xFF9EDBFF)
          .withOpacity(.08)
      ..strokeWidth = .5;

    final major = Paint()
      ..color =
      const Color(0xFFBEE8FF)
          .withOpacity(.15)
      ..strokeWidth = .8;

    const divisionsX = 24;
    const divisionsY = 12;

    for (int i = 0;
    i <= divisionsX;
    i++) {
      final x =
          rect.left +
              rect.width *
                  i /
                  divisionsX;

      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        i % 4 == 0
            ? major
            : minor,
      );
    }

    for (int i = 0;
    i <= divisionsY;
    i++) {
      final y =
          rect.top +
              rect.height *
                  i /
                  divisionsY;

      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        i % 4 == 0
            ? major
            : minor,
      );
    }
  }

  void _paintClassic(
      Canvas canvas,
      Size size,
      ) {
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(.10),
          Colors.transparent,
        ],
      ).createShader(
        Offset.zero & size,
      );

    canvas.drawRect(
      Offset.zero & size,
      p,
    );
  }

  /// The single most recognizable feature of a real portolan chart: a
  /// handful of "rose" points scattered across the ocean, each one
  /// connected to every other by a dead-straight rhumb line, forming a
  /// dense criss-crossing web. Real charts drew these because a straight
  /// line on the chart was a constant-bearing sailing course; here it's
  /// purely decorative, but the crossing-web pattern is exactly what
  /// reads as "old nautical chart" at a glance.
  void _paintRhumbNetwork(
      Canvas canvas,
      Rect rect,
      ) {
    // Fixed fractional positions within the map rect -- chosen to land
    // mostly over open ocean rather than on top of major landmasses.
    const positions = [
      Offset(.18, .22),
      Offset(.62, .12),
      Offset(.88, .30),
      Offset(.10, .58),
      Offset(.50, .52),
      Offset(.85, .68),
      Offset(.30, .85),
      Offset(.68, .90),
    ];

    final points = positions
        .map((p) => Offset(rect.left + p.dx * rect.width, rect.top + p.dy * rect.height))
        .toList();

    final linePaint = Paint()
      ..color = style.accent.withOpacity(.20)
      ..strokeWidth = .55;

    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        canvas.drawLine(points[i], points[j], linePaint);
      }
    }

    // A small rose (just the 8-point star, no "N" label -- that's
    // reserved for the one main compass drawn separately) at every node
    // except the first, which the main _paintCompass call already covers
    // at roughly this chart's focal point.
    for (int i = 1; i < points.length; i++) {
      _paintMinorRose(canvas, points[i], 16 + (i.isEven ? 4 : 0));
    }
  }

  void _paintMinorRose(
      Canvas canvas,
      Offset center,
      double radius,
      ) {
    final spike = Paint()
      ..color = style.accent.withOpacity(.38)
      ..strokeWidth = .7;

    for (int i = 0; i < 8; i++) {
      final angle = (math.pi / 4) * i;
      final len = i.isEven ? radius : radius * .55;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * len,
          center.dy + math.sin(angle) * len,
        ),
        spike,
      );
    }

    canvas.drawCircle(
      center,
      1.6,
      Paint()..color = style.accent.withOpacity(.55),
    );
  }

  void _paintCompass(
      Canvas canvas,
      Rect rect,
      ) {
    final radius = math.min(
      28.0,
      rect.width * .055,
    );

    final center = Offset(
      rect.right - radius - 16,
      rect.top + radius + 16,
    );

    final line = Paint()
      ..color =
      style.accent.withOpacity(.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fill = Paint()
      ..color =
      style.accent.withOpacity(.07)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      radius,
      fill,
    );

    canvas.drawCircle(
      center,
      radius,
      line,
    );

    canvas.drawCircle(
      center,
      radius * .70,
      line..strokeWidth = .6,
    );

    final north = Path()
      ..moveTo(
        center.dx,
        center.dy - radius * .9,
      )
      ..lineTo(
        center.dx - 4.5,
        center.dy + 2,
      )
      ..lineTo(
        center.dx,
        center.dy - 2,
      )
      ..lineTo(
        center.dx + 4.5,
        center.dy + 2,
      )
      ..close();

    canvas.drawPath(
      north,
      Paint()
        ..color =
        style.accent.withOpacity(.76),
    );

    final cross = Paint()
      ..color =
      style.accent.withOpacity(.44)
      ..strokeWidth = .8;

    canvas.drawLine(
      Offset(
        center.dx - radius,
        center.dy,
      ),
      Offset(
        center.dx + radius,
        center.dy,
      ),
      cross,
    );

    canvas.drawLine(
      Offset(
        center.dx,
        center.dy - radius,
      ),
      Offset(
        center.dx,
        center.dy + radius,
      ),
      cross,
    );

    // Four smaller intercardinal spikes (NE/SE/SW/NW) so the rose reads
    // as a proper old-chart compass rather than a plain plus-cross.
    final diagPaint = Paint()
      ..color = style.accent.withOpacity(.30)
      ..strokeWidth = .6;

    final diagLen = radius * .82;
    for (final angle in [
      math.pi / 4,
      3 * math.pi / 4,
      5 * math.pi / 4,
      7 * math.pi / 4,
    ]) {
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * diagLen,
          center.dy + math.sin(angle) * diagLen,
        ),
        diagPaint,
      );
    }

    // Tiny "N" label above the north spike -- the single most recognizable
    // detail of a real compass rose.
    final textPainter = TextPainter(
      text: TextSpan(
        text: tr('N'),
        style: TextStyle(
          color: style.accent.withOpacity(.80),
          fontSize: radius * .34,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - radius - textPainter.height - 2,
      ),
    );
  }

  void _paintDecorativeRoutes(
      Canvas canvas,
      Rect rect,
      ) {
    final p = Paint()
      ..color =
      style.accent.withOpacity(.14)
      ..strokeWidth = .8
      ..style = PaintingStyle.stroke;

    final route1 = Path()
      ..moveTo(
        rect.left +
            rect.width * .17,
        rect.top +
            rect.height * .48,
      )
      ..cubicTo(
        rect.left +
            rect.width * .32,
        rect.top +
            rect.height * .25,
        rect.left +
            rect.width * .47,
        rect.top +
            rect.height * .67,
        rect.left +
            rect.width * .63,
        rect.top +
            rect.height * .43,
      );

    final route2 = Path()
      ..moveTo(
        rect.left +
            rect.width * .51,
        rect.top +
            rect.height * .53,
      )
      ..cubicTo(
        rect.left +
            rect.width * .65,
        rect.top +
            rect.height * .28,
        rect.left +
            rect.width * .77,
        rect.top +
            rect.height * .64,
        rect.left +
            rect.width * .88,
        rect.top +
            rect.height * .45,
      );

    canvas.drawPath(
      route1,
      p,
    );

    canvas.drawPath(
      route2,
      p,
    );
  }

  void _paintSeaMonsters(
      Canvas canvas,
      Rect rect,
      ) {
    final scale = math.min(1.0, rect.width / 900.0).clamp(.6, 1.0);
    final color = style.accent.withOpacity(.50);

    _paintSeaMonster(
      canvas,
      Offset(
        rect.left + rect.width * .12,
        rect.top + rect.height * .78,
      ),
      scale,
      color,
      flipped: false,
    );

    _paintSeaMonster(
      canvas,
      Offset(
        rect.left + rect.width * .90,
        rect.top + rect.height * .18,
      ),
      scale * .85,
      color,
      flipped: true,
    );
  }

  void _paintSeaMonster(
      Canvas canvas,
      Offset origin,
      double scale,
      Color color, {
        required bool flipped,
      }) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    if (flipped) canvas.scale(-1, 1);

    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..strokeCap = StrokeCap.round;

    // A simple undulating serpent body -- several humps breaking the
    // surface, drawn as smooth curves rather than a straight sine plot so
    // it reads as a creature rather than a graph.
    final body = Path()..moveTo(0, 0);
    const humpCount = 4;
    for (int i = 1; i <= humpCount; i++) {
      final x = i * 15.0 * scale;
      final peak = (i.isOdd) ? -11.0 : 3.0;
      body.quadraticBezierTo(
        x - 7.5 * scale,
        peak * scale,
        x,
        0,
      );
    }
    canvas.drawPath(body, bodyPaint);

    // Small fin spikes on the two humps that break the surface.
    final finPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final hump in [1, 3]) {
      final hx = (hump * 15.0 - 7.5) * scale;
      final tri = Path()
        ..moveTo(hx - 3.2 * scale, -6 * scale)
        ..lineTo(hx, -15 * scale)
        ..lineTo(hx + 3.2 * scale, -6 * scale)
        ..close();
      canvas.drawPath(tri, finPaint);
    }

    // Head with a small eye and a curved snout, at the tail end of the
    // path so the "front" of the creature leads the humps.
    final headCenter = Offset(-8 * scale, -6 * scale);
    canvas.drawCircle(headCenter, 6 * scale, Paint()..color = color);

    final snout = Path()
      ..moveTo(headCenter.dx - 5.5 * scale, headCenter.dy - 1 * scale)
      ..quadraticBezierTo(
        headCenter.dx - 11 * scale,
        headCenter.dy + 2 * scale,
        headCenter.dx - 7 * scale,
        headCenter.dy + 4.5 * scale,
      )
      ..close();
    canvas.drawPath(snout, Paint()..color = color);

    canvas.drawCircle(
      Offset(headCenter.dx - 1.6 * scale, headCenter.dy - 2 * scale),
      1.1 * scale,
      Paint()..color = Colors.white.withOpacity(.85),
    );

    canvas.restore();
  }

  /// A ruled border of small tick marks and degree numbers along all four
  /// edges of the map -- the numbered-margin look every real antique
  /// atlas plate has. Horizontal edges mark latitude (the map's axes are
  /// swapped for the tall layout, so latitude runs left-to-right);
  /// vertical edges mark longitude.
  void _paintGraticuleTicks(
      Canvas canvas,
      Rect rect,
      ) {
    final tickPaint = Paint()
      ..color = style.uiForeground.withOpacity(.55)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: style.uiForeground.withOpacity(.62),
      fontSize: 8.5,
      fontWeight: FontWeight.w600,
    );

    void drawLabel(String text, Offset anchor, {bool rotated = false}) {
      final tp = TextPainter(
        text: TextSpan(text: tr(text), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      if (rotated) canvas.rotate(-math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Latitude ticks along the top and bottom edges, every 30 degrees.
    const latSteps = 6; // 90N .. 90S in 30-degree steps = 7 marks
    for (int i = 0; i <= latSteps; i++) {
      final x = rect.left + rect.width * i / latSteps;
      final lat = 90 - (180 * i / latSteps).round();
      final label = lat == 0 ? '0°' : '${lat.abs()}°${lat > 0 ? 'N' : 'S'}';

      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.top - 6),
        tickPaint,
      );
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x, rect.bottom + 6),
        tickPaint,
      );

      drawLabel(label, Offset(x, rect.top - 13));
      drawLabel(label, Offset(x, rect.bottom + 13));
    }

    // Longitude ticks along the left and right edges, every 30 degrees.
    const lngSteps = 12; // 180W .. 180E in 30-degree steps = 13 marks
    for (int i = 0; i <= lngSteps; i++) {
      final y = rect.top + rect.height * i / lngSteps;
      final lng = -180 + (360 * i / lngSteps).round();
      final label = lng == 0 ? '0°' : '${lng.abs()}°${lng > 0 ? 'E' : 'W'}';

      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.left - 6, y),
        tickPaint,
      );
      canvas.drawLine(
        Offset(rect.right, y),
        Offset(rect.right + 6, y),
        tickPaint,
      );

      drawLabel(label, Offset(rect.left - 15, y), rotated: true);
      drawLabel(label, Offset(rect.right + 15, y), rotated: true);
    }
  }

  void _paintAgedBorderFrame(
      Canvas canvas,
      Size size,
      ) {
    // A rough, slightly irregular double border -- old charts were framed
    // by hand, never a perfectly clean rectangle.
    final outer = Paint()
      ..color = const Color(0xFF3A2C18).withOpacity(.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;

    final inner = Paint()
      ..color = const Color(0xFF3A2C18).withOpacity(.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const margin = 10.0;
    final outerRect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );
    final innerRect = outerRect.deflate(6);

    canvas.drawRect(outerRect, outer);
    canvas.drawRect(innerRect, inner);

    // Small corner flourishes, one per corner.
    final flourish = Paint()
      ..color = const Color(0xFF3A2C18).withOpacity(.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final corner in [
      outerRect.topLeft,
      outerRect.topRight,
      outerRect.bottomLeft,
      outerRect.bottomRight,
    ]) {
      canvas.drawCircle(corner, 5, flourish);
    }
  }

  void _paintAntiqueEdges(
      Canvas canvas,
      Size size,
      ) {
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: .95,
        colors: [
          Colors.transparent,
          const Color(0xFF2A1B0C).withOpacity(.20),
          const Color(0xFF190F05).withOpacity(.52),
        ],
        stops: const [
          .48,
          .82,
          1,
        ],
      ).createShader(
        Offset.zero & size,
      );

    canvas.drawRect(
      Offset.zero & size,
      vignette,
    );

    // A second, off-center scorch mark -- real aged sheets darken
    // unevenly, not in a perfect ring, so one corner reads noticeably
    // more burnt than the others.
    final scorch = Paint()
      ..shader = RadialGradient(
        center: const Alignment(.86, -.92),
        radius: .55,
        colors: [
          const Color(0xFF241407).withOpacity(.30),
          Colors.transparent,
        ],
      ).createShader(
        Offset.zero & size,
      );

    canvas.drawRect(
      Offset.zero & size,
      scorch,
    );
  }

  void _paintNightVignette(
      Canvas canvas,
      Size size,
      ) {
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: .92,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(.32),
        ],
        stops: const [
          .57,
          1,
        ],
      ).createShader(
        Offset.zero & size,
      );

    canvas.drawRect(
      Offset.zero & size,
      vignette,
    );
  }

  @override
  bool shouldRepaint(
      covariant _WorldMapPainter oldDelegate,
      ) {
    return oldDelegate.countries !=
        countries ||
        oldDelegate.visitDetails !=
            visitDetails ||
        oldDelegate.theme != theme ||
        oldDelegate.style != style ||
        oldDelegate.warpEnabled !=
            warpEnabled ||
        oldDelegate.warpStrength !=
            warpStrength ||
        oldDelegate.showDecorations !=
            showDecorations ||
        oldDelegate.visitedOnly !=
            visitedOnly;
  }
}

class _ThemeStyle {
  final String title;
  final String subtitle;
  final Color ocean;
  final Color land;
  final Color visited;
  final Color wishlist;
  final Color border;
  final Color visitedBorder;
  final Color accent;
  final Color uiForeground;
  final bool darkUi;

  const _ThemeStyle({
    required this.title,
    required this.subtitle,
    required this.ocean,
    required this.land,
    required this.visited,
    required this.wishlist,
    required this.border,
    required this.visitedBorder,
    required this.accent,
    required this.uiForeground,
    required this.darkUi,
  });
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final bool dark;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    required this.dark,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (
            dark
                ? const Color(0xFF08111D)
                : Colors.white
        ).withOpacity(
          dark ? .80 : .84,
        ),
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: (
              dark
                  ? Colors.white
                  : Colors.black
          ).withOpacity(
            dark ? .10 : .05,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              dark ? .22 : .08,
            ),
            blurRadius: 20,
            offset:
            const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GlassButton extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({
    required this.dark,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Material(
      color: (
          dark
              ? const Color(0xFF08111D)
              : Colors.white
      ).withOpacity(
        dark ? .82 : .86,
      ),
      borderRadius:
      BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(16),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: dark
                ? Colors.white
                .withOpacity(.92)
                : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool value;
  final bool dark;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _MiniToggle({
    required this.label,
    required this.value,
    required this.dark,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final fg =
    dark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius:
      BorderRadius.circular(10),
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: value
              ? accent.withOpacity(.16)
              : fg.withOpacity(.05),
          borderRadius:
          BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? accent.withOpacity(.48)
                : fg.withOpacity(.06),
          ),
        ),
        child: Text(
          tr(label),
          style: TextStyle(
            color: value
                ? accent
                : fg.withOpacity(.60),
            fontSize: 10.5,
            fontWeight:
            FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final bool dark;
  final Color accent;
  final Color foreground;
  final VoidCallback onTap;

  const _IconToggle({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.dark,
    required this.accent,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Tooltip(
      message: tr(tooltip),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: selected
                ? accent.withOpacity(
              dark ? .24 : .15,
            )
                : foreground.withOpacity(.05),
            borderRadius:
            BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? accent.withOpacity(.52)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: selected
                ? accent
                : foreground
                .withOpacity(.62),
          ),
        ),
      ),
    );
  }
}

class MapLabCountrySelector extends StatefulWidget {
  const MapLabCountrySelector({super.key});

  @override
  State<MapLabCountrySelector> createState() => _MapLabCountrySelectorState();
}

class _MapLabCountrySelectorState extends State<MapLabCountrySelector> {
  static const mint = Color(0xFF26A69A);
  static const mintDark = Color(0xFF00796B);
  static const mintLight = Color(0xFFE0F2F1);

  final _searchController = TextEditingController();
  final List<_CountryItem> _countries = [];
  final Set<String> _selected = {};
  Map<String, dynamic> _rawVisits = {};

  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final geoText = await rootBundle.loadString('assets/custom.geo.json');
      final geo = json.decode(geoText);

      if (geo is! Map || geo['features'] is! List) {
        throw const FormatException('Invalid custom.geo.json');
      }

      final loaded = <_CountryItem>[];

      for (final feature in geo['features'] as List) {
        if (feature is! Map || feature['properties'] is! Map) continue;

        final p = Map<String, dynamic>.from(feature['properties'] as Map);
        final name = (p['name'] ?? '').toString().trim();
        final isoA2 = (p['iso_a2'] ?? '').toString().trim();
        final continent = (p['continent'] ?? 'Other').toString().trim();

        if (name.isEmpty || _skip(name)) continue;

        loaded.add(
          _CountryItem(
            name: name,
            isoA2: isoA2,
            continent: continent.isEmpty ? 'Other' : continent,
          ),
        );
      }

      loaded.sort((a, b) {
        final c = a.continent.compareTo(b.continent);
        return c != 0 ? c : a.name.compareTo(b.name);
      });

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('visit_details_v2');

      final rawVisits = <String, dynamic>{};
      final selected = <String>{};

      if (saved != null && saved.trim().isNotEmpty) {
        try {
          final decoded = json.decode(saved);

          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final key = entry.key.toString();
              final value = entry.value;

              if (value is Map) {
                final copied = Map<String, dynamic>.from(value);
                rawVisits[key] = copied;

                if (copied['isVisited'] == true) {
                  selected.add(key);
                }
              } else {
                rawVisits[key] = value;
              }
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _countries
          ..clear()
          ..addAll(loaded);
        _rawVisits = rawVisits;
        _selected
          ..clear()
          ..addAll(selected);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool _skip(String name) {
    const skip = {
      'Antarctica',
      'Siachen Glacier',
      'Indian Ocean Ter.',
      'Ashmore and Cartier Is.',
    };
    return skip.contains(name);
  }

  List<_CountryItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _countries;

    return _countries
        .where((c) =>
    c.name.toLowerCase().contains(q) ||
        c.isoA2.toLowerCase().contains(q))
        .toList();
  }

  void _toggle(_CountryItem country) {
    setState(() {
      if (!_selected.add(country.name)) {
        _selected.remove(country.name);
      }
    });
  }

  Future<void> _apply() async {
    for (final country in _countries) {
      final old = _rawVisits[country.name];
      final details =
      old is Map ? Map<String, dynamic>.from(old) : <String, dynamic>{};

      // Preserve every other field; only change visit state.
      details['isVisited'] = _selected.contains(country.name);
      _rawVisits[country.name] = details;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('visit_details_v2', json.encode(_rawVisits));

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFA),
      appBar: AppBar(
        title:  Text(
          tr('Select Countries'),
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: mint,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: mint))
          : _error != null
          ? _errorView()
          : Column(
        children: [
          _searchBox(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr('${_selected.length} countries selected'),
                style: const TextStyle(
                  color: mintDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(child: _list()),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      color: mint,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          hintText: tr('Search country...'),
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _list() {
    final items = _filtered;
    if (items.isEmpty) return  Center(child: Text(tr('No countries found.')));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final c = items[index];
        final selected = _selected.contains(c.name);
        final showHeader = index == 0 ||
            items[index - 1].continent != c.continent;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                child: Text(
                  tr(c.continent),
                  style: const TextStyle(
                    color: mintDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              elevation: 0,
              color: selected ? mintLight : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: selected ? mint : const Color(0xFFE9EEEE),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggle(c),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? mint : Colors.white,
                          border: Border.all(
                            color: selected ? mint : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(tr(_flag(c.isoA2)),
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 15.5,
                            color: selected ? mintDark : Colors.black87,
                            fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child:  Text(tr('Cancel')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _apply,
              style: FilledButton.styleFrom(backgroundColor: mint),
              child:  Text(tr('Apply')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: mintDark),
            const SizedBox(height: 12),
            Text(tr(_error ?? 'Unknown error'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: mint),
              child:  Text(tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryItem {
  final String name;
  final String isoA2;
  final String continent;

  const _CountryItem({
    required this.name,
    required this.isoA2,
    required this.continent,
  });
}

String _flag(String isoA2) {
  final code = isoA2.trim().toUpperCase();
  if (code.length != 2) return '';

  final units = code.codeUnits;
  if (units.any((c) => c < 65 || c > 90)) return '';

  const base = 0x1F1E6 - 0x41;
  return String.fromCharCode(base + units[0]) +
      String.fromCharCode(base + units[1]);
}