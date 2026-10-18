import 'package:jidoapp/services/country_region_access.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/country_region_access_gate.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/admin_region.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/services/admin_region_repository.dart';
import 'package:provider/provider.dart';

/// Uses a country outline for the base and only explicitly visited regions
/// for the regional fill. Country visits never imply visits to every region.
class VisitedWorldMapLayer extends StatefulWidget {
  final List<Country> countries;
  final Set<String> visitedCountries;
  final Map<String, Color> continentColors;
  final bool showRegions;
  final Color Function(Country)? regionColor;
  final Color borderColor;
  final Color? unvisitedColor;
  final bool showUnvisitedRegions;

  const VisitedWorldMapLayer({
    super.key,
    required this.countries,
    required this.visitedCountries,
    required this.continentColors,
    required this.showRegions,
    this.regionColor,
    this.borderColor = Colors.white,
    this.unvisitedColor,
    this.showUnvisitedRegions = true,
  });

  @override
  State<VisitedWorldMapLayer> createState() => _VisitedWorldMapLayerState();
}

class _VisitedWorldMapLayerState extends State<VisitedWorldMapLayer> {
  Future<Map<String, List<AdminRegion>>>? _regions;
  static final _unvisited = Colors.grey.withValues(alpha: 0.15);

  List<Polygon> _countryPolygons() {
    return widget.countries.expand((country) {
      final color =
          !widget.showRegions && widget.visitedCountries.contains(country.name)
          ? widget.continentColors[country.continent] ?? Colors.grey
          : widget.unvisitedColor ?? _unvisited;
      return country.polygonsData
          .where((piece) => piece.isNotEmpty)
          .map(
            (piece) => Polygon(
              points: piece.first,
              holePointsList: piece.length > 1 ? piece.sublist(1) : null,
              color: color,
              borderColor: widget.borderColor,
              borderStrokeWidth: 0.5,
              isFilled: true,
            ),
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    if (!widget.showRegions) {
      return PolygonLayer(polygons: _countryPolygons());
    }
    return AnimatedBuilder(
      animation: SubscriptionService.instance,
      builder: (context, _) => _buildRegions(context),
    );
  }

  Widget _buildRegions(BuildContext context) {
    _regions ??= AdminRegionRepository.loadAll();
    return FutureBuilder<Map<String, List<AdminRegion>>>(
      future: _regions,
      builder: (context, snapshot) {
        final regions = snapshot.data;
        if (regions == null) {
          return Stack(
            children: [
              PolygonLayer(polygons: _countryPolygons()),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        return Consumer<SubregionProvider>(
          builder: (context, visits, _) {
            final polygons = _countryPolygons();
            for (final country in widget.countries) {
              if (!CountryRegionAccess.isUnlocked(country.isoA2)) continue;
              final color =
                  widget.regionColor?.call(country) ??
                  widget.continentColors[country.continent] ??
                  Colors.grey;
              for (final region in regions[country.isoA2] ?? <AdminRegion>[]) {
                if (region.isWholeArea) continue;
                final visited = visits.isRegionVisited(country.isoA3, region);
                if (!visited && !widget.showUnvisitedRegions) continue;
                // Leave unvisited interiors transparent so the country base
                // keeps a consistent unvisited fill even where boundaries differ.
                for (final piece in region.polygonsData) {
                  if (piece.isEmpty || piece.first.length < 3) continue;
                  polygons.add(
                    Polygon(
                      points: piece.first,
                      holePointsList: piece.length > 1
                          ? piece.sublist(1)
                          : null,
                      color: visited ? color : Colors.transparent,
                      borderColor: widget.borderColor,
                      borderStrokeWidth: 0.2,
                      isFilled: true,
                    ),
                  );
                }
              }
            }
            return Stack(
              children: [
                PolygonLayer(polygons: polygons),
                if (!SubscriptionService.instance.isPremium)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => showCountryRegionsPremiumDialog(context),
                      icon: const Icon(Icons.lock_outline_rounded, size: 16),
                      label:  Text(tr('More regions with Premium')),
                    ),
                  ),
                 Positioned(
                  left: 8,
                  bottom: 4,
                  child: IgnorePointer(
                    child: Text(
                      tr('Natural Earth • geoBoundaries • © OpenStreetMap contributors'),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.black54,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
