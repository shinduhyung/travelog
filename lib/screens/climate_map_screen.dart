// lib/screens/climate_map_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class ClimateMapScreen extends StatefulWidget {
  const ClimateMapScreen({super.key});

  @override
  State<ClimateMapScreen> createState() => _ClimateMapScreenState();
}

class _ClimateMapScreenState extends State<ClimateMapScreen> {
  // Define colors for each climate zone
  static const Color tropicalColor = Colors.red;
  static const Color dryColor = Colors.yellow; // 갈색으로 변경
  static const Color temperateColor = Colors.green;
  static const Color continentalColor = Colors.indigo; // 남색으로 변경
  static const Color polarColor = Colors.cyan; // 민트색으로 변경
  static const Color defaultClimateColor = Colors.grey;

  Color _getColorForClimateZone(String? climateZone) {
    switch (climateZone) {
      case 'A': return tropicalColor;
      case 'B': return dryColor;
      case 'C': return temperateColor;
      case 'D': return continentalColor;
      case 'E': return polarColor;
      default: return defaultClimateColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final countryProvider = Provider.of<CountryProvider>(context);
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultCountryColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade400;

    if (countryProvider.isLoading) {
      return Scaffold(backgroundColor: backgroundColor, body: const Center(child: CircularProgressIndicator()));
    }

    final List<Polygon> allMapPolygons = [];
    // ✅ 수정: allCountries -> filteredCountries
    for (var country in countryProvider.filteredCountries) {
      final isVisited = countryProvider.visitedCountries.contains(country.name);
      final climateZone = country.climateZone;

      Color finalColor = defaultCountryColor;

      if (climateZone != null) {
        Color baseColor = _getColorForClimateZone(climateZone);
        finalColor = isVisited ? baseColor : baseColor.withOpacity(0.35);
      }

      for (var polygonData in country.polygonsData) {
        if (polygonData.isNotEmpty && polygonData.first.length > 2) {
          allMapPolygons.add(Polygon(
            points: polygonData.first,
            holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
            color: finalColor,
            borderColor: backgroundColor,
            borderStrokeWidth: 0.5,
            isFilled: true,
          ));
        }
      }
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title:  Text(tr('World Climate Map')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(20, 0),
              initialZoom: 1.5,
              backgroundColor: backgroundColor,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180)),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              PolygonLayer(polygons: allMapPolygons),
            ],
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: _buildClimateLegendRows(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClimateLegendRows() {
    return [
      _legendRow(tropicalColor, 'A - Tropical'),
      _legendRow(dryColor, 'B - Dry'),
      _legendRow(temperateColor, 'C - Temperate'),
      _legendRow(continentalColor, 'D - Continental'),
      _legendRow(polarColor, 'E - Polar'),
    ];
  }

  Widget _legendRow(Color color, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 8),
          Text(
            tr(name),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}