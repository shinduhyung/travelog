// lib/screens/passport_visa_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/visa_data_model.dart';
import 'package:latlong2/latlong.dart';

class PassportVisaDetailScreen extends StatelessWidget {
  final String passportName;
  final List<Country> allCountries;
  final Map<String, DestinationVisaInfo> visaInfoMap;
  final String selectedPassportIso;

  const PassportVisaDetailScreen({
    super.key,
    required this.passportName,
    required this.allCountries,
    required this.visaInfoMap,
    required this.selectedPassportIso,
  });

  // [Update] Sovereign Territories Mapping
  // GBR: Added extensive list of overseas territories
  // USA: Added ASM
  // MAR: Mapped ESH (Western Sahara) instead of SML
  static const Map<String, Set<String>> _sovereignTerritories = {
    'USA': {'GUM', 'MNP', 'PRI', 'VIR', 'ASM'},
    'FRA': {'BLM', 'MAF', 'NCL', 'PYF', 'SPM', 'WLF'},
    'NLD': {'ABW', 'CUW', 'SXM'},
    'NZL': {'COK', 'NIU'},
    'AUS': {'NFK'},
    'FIN': {'ALA'},
    'GBR': {
      'GGY', 'IMN', 'JEY', // Crown Dependencies
      'AIA', 'CYM', 'FLK', 'MSR', 'PCN', 'TCA', 'VGB', 'BMU' // Overseas Territories
    },
    'MAR': {'ESH'}, // Western Sahara mapped to Morocco
  };

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
               TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.map_outlined), text: tr('Map View')),
                  Tab(icon: Icon(Icons.list_alt_rounded), text: tr('List View')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMapView(context),
                    _buildListView(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Map View Tab ---

  Widget _buildMapView(BuildContext context) {
    return Stack(
      children: [
        _buildVisaMap(context, allCountries, visaInfoMap, selectedPassportIso),
        _buildMapLegend(context),
      ],
    );
  }

  Widget _buildVisaMap(BuildContext context, List<Country> allCountries, Map<String, DestinationVisaInfo> visaInfoMap, String selectedIso) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    final List<Polygon> allPolygons = [];
    for (var country in allCountries) {
      Color color;

      // Check if home country or sovereign territory (Blue)
      bool isHome = country.isoA3 == selectedIso ||
          (_sovereignTerritories[selectedIso]?.contains(country.isoA3) ?? false);

      if (isHome) {
        color = Colors.blue.shade700;
      } else {
        final visaInfo = visaInfoMap[country.isoA3.toUpperCase()];
        final rawStatus = visaInfo?.rawStatus ?? 'N/A';
        color = _getColorForVisaStatus(rawStatus);
      }

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
              )
          );
        }
      }
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(20, 0),
        initialZoom: 1.5,
        backgroundColor: backgroundColor,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180)),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom | InteractiveFlag.flingAnimation,
        ),
      ),
      children: [
        PolygonLayer(polygons: allPolygons),
      ],
    );
  }

  Widget _buildMapLegend(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 8,
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
            _legendRow(context, Colors.blue.shade700, 'Home Country'),
            const SizedBox(height: 4),
            _legendRow(context, Colors.green.shade600, 'Visa-Free / VOA'),
            _legendRow(context, Colors.amber.shade700, 'e-Visa / eTA'),
            _legendRow(context, Colors.red.shade700, 'Visa Required'),
            _legendRow(context, Colors.grey.shade600, 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(BuildContext context, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
              tr(text),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 11)
          ),
        ],
      ),
    );
  }

  // --- List View Tab ---

  Widget _buildListView(BuildContext context) {
    final Map<String, List<_VisaDisplayItem>> itemsByContinent = {};

    for (var country in allCountries) {
      // Skip home country (e.g., USA) in list, but keep territories
      if (country.isoA3 == selectedPassportIso) continue;

      final continent = country.continent ?? 'Others';
      final visaInfo = visaInfoMap[country.isoA3.toUpperCase()];

      itemsByContinent.putIfAbsent(continent, () => []).add(
          _VisaDisplayItem(
            name: country.name,
            isoA3: country.isoA3,
            visaInfo: visaInfo,
          )
      );
    }

    final sortedContinents = itemsByContinent.keys.toList()..sort();

    final List<Widget> continentTiles = [];
    for (final continent in sortedContinents) {
      final items = itemsByContinent[continent]!;
      items.sort((a, b) => a.name.compareTo(b.name));

      continentTiles.add(
        ExpansionTile(
          title: Text(tr(continent), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          initiallyExpanded: false,
          children: items.map((item) {

            // Force status to 'HOME COUNTRY' for territories
            bool isTerritory = _sovereignTerritories[selectedPassportIso]?.contains(item.isoA3) ?? false;

            String displayStatus = 'N/A';
            String duration = '';
            Color statusColor = Colors.grey.shade600;

            if (isTerritory) {
              displayStatus = 'Home Country';
              statusColor = Colors.blue.shade700;
            } else if (item.visaInfo != null) {
              displayStatus = item.visaInfo!.displayStatus;
              duration = item.visaInfo!.durationText;
              statusColor = _getColorForVisaStatus(item.visaInfo!.rawStatus);
            }

            return ListTile(
              title: Text(item.name),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tr(displayStatus.toUpperCase()),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (duration.isNotEmpty && !isTerritory)
                    Text(
                      tr(duration),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              dense: true,
            );
          }).toList(),
        ),
      );
    }

    return ListView(
      children: continentTiles,
    );
  }

  Color _getColorForVisaStatus(String rawStatus) {
    String statusLower = rawStatus.toLowerCase();

    if (int.tryParse(rawStatus) != null) return Colors.green.shade600;
    if (statusLower.contains('visa free')) return Colors.green.shade600;
    if (statusLower.contains('arrival')) return Colors.green.shade400;

    if (statusLower.contains('eta') || statusLower.contains('e-visa')) {
      return Colors.amber.shade700;
    }

    if (statusLower.contains('visa required')) {
      return Colors.red.shade700;
    }

    if (statusLower.contains('no admiss') || statusLower.contains('refused')) {
      return Colors.black87;
    }
    if (rawStatus == '-1') {
      return Colors.blue.shade700;
    }

    return Colors.grey.shade600;
  }
}

class _VisaDisplayItem {
  final String name;
  final String isoA3;
  final DestinationVisaInfo? visaInfo;

  _VisaDisplayItem({
    required this.name,
    required this.isoA3,
    this.visaInfo,
  });
}