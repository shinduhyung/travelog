// lib/screens/visa_map_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/visa_data_model.dart';
import 'package:latlong2/latlong.dart';

class VisaMapScreen extends StatelessWidget {
  final List<Country> allCountries;
  final Map<String, DestinationVisaInfo> visaInfoMap;

  const VisaMapScreen({
    super.key,
    required this.allCountries,
    required this.visaInfoMap,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final List<Polygon> allPolygons = [];

    for (var country in allCountries) {
      final visaInfo = visaInfoMap[country.isoA3.toUpperCase()];
      // [Update] Use rawStatus instead of visaRequirement due to model changes
      final rawStatus = visaInfo?.rawStatus ?? 'no information';
      final color = _getColorForVisaStatus(rawStatus);

      for (var polygonData in country.polygonsData) {
        if (polygonData.isNotEmpty && polygonData.first.isNotEmpty) {
          allPolygons.add(
            Polygon(
              points: polygonData.first,
              holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
              color: color.withOpacity(0.8),
              borderColor: Colors.white.withOpacity(0.5),
              borderStrokeWidth: 0.5,
              isFilled: true,
            ),
          );
        }
      }
    }

    // Set world map bounds
    final worldBounds = LatLngBounds(
        const LatLng(-90, -180),
        const LatLng(90, 180)
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: worldBounds,
                  padding: const EdgeInsets.only(top: 20, bottom: 100),
                ),
                minZoom: 0.1,
                backgroundColor: backgroundColor,
                cameraConstraint: CameraConstraint.contain(
                  bounds: worldBounds,
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                PolygonLayer(polygons: allPolygons),
              ],
            ),
            // Floating title overlay for the map
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child:  Text(
                    tr('Visa Requirements Map'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            _buildMapLegend(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLegend(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendRow(context, Colors.green.shade600, 'Visa-Free / VOA'),
            _legendRow(context, Colors.amber.shade700, 'e-Visa / eTA'),
            _legendRow(context, Colors.red.shade700, 'Visa Required'),
            _legendRow(context, Colors.grey.shade400, 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(BuildContext context, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
              tr(text),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500
              )
          ),
        ],
      ),
    );
  }

  // [Core] Update color determination logic
  Color _getColorForVisaStatus(String rawStatus) {
    String statusLower = rawStatus.toLowerCase();

    // 1. [Green] Visa-Free & Visa on Arrival
    // If numeric (days) (e.g., "90", "30") -> Visa-Free
    if (int.tryParse(rawStatus) != null) {
      return Colors.green.shade600;
    }
    // Explicit visa-free text
    if (statusLower.contains('visa free')) {
      return Colors.green.shade600;
    }
    // Visa on Arrival -> 1 point (equivalent to visa-free) in Henley Index, so green
    if (statusLower.contains('arrival')) {
      return Colors.green.shade400;
    }

    // 2. [Yellow/Orange] e-TA & e-Visa
    // ETA, e-Visa -> Requires prior online application
    if (statusLower.contains('eta') || statusLower.contains('e-visa')) {
      return Colors.amber.shade700;
    }

    // 3. [Red] Visa Required (Embassy visit)
    if (statusLower.contains('visa required')) {
      return Colors.red.shade700;
    }

    // 4. [Black/Grey] Special cases
    if (statusLower.contains('no admiss') || statusLower.contains('refused')) {
      return Colors.black87; // Entry Refused
    }
    if (rawStatus == '-1') {
      return Colors.grey.shade700; // Home Country
    }

    // No information
    return Colors.grey.shade300;
  }
}