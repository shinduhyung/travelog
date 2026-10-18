// lib/screens/city_stats_map_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/cities_screen.dart'; // showExternalCityDetailsModal 사용
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:country_flags/country_flags.dart';

class CityStatsMapScreen extends StatefulWidget {
  final List<City> cities;
  final String title;
  final Color markerColor;

  const CityStatsMapScreen({
    super.key,
    required this.cities,
    required this.title,
    this.markerColor = Colors.amber,
  });

  @override
  State<CityStatsMapScreen> createState() => _CityStatsMapScreenState();
}

class _CityStatsMapScreenState extends State<CityStatsMapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final cityProvider = Provider.of<CityProvider>(context);
    final countryProvider = Provider.of<CountryProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(flex: 3, child: _buildMap(cityProvider, countryProvider)),
              Expanded(flex: 4, child: _buildChecklistSection(cityProvider)),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.8),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(CityProvider cityProvider, CountryProvider countryProvider) {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(20, 0),
        initialZoom: 1.2,
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
          markers: widget.cities.map((city) {
            final isVisited = cityProvider.isVisited(city.name);
            return Marker(
              width: 12,
              height: 12,
              point: LatLng(city.latitude, city.longitude),
              child: GestureDetector(
                onTap: () => showExternalCityDetailsModal(context, city),
                child: Icon(
                  isVisited ? Icons.circle : Icons.circle_outlined,
                  color: widget.markerColor,
                  size: isVisited ? 8 : 6,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChecklistSection(CityProvider cityProvider) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: widget.cities.length,
            itemBuilder: (context, index) {
              final city = widget.cities[index];
              final isVisited = cityProvider.isVisited(city.name);
              final detail = cityProvider.getCityVisitDetail(city.name);
              final isWishlisted = detail?.isWishlisted ?? false;

              return CityVisitControlTile(
                city: city,
                countryName: city.country,
                onTap: () => showExternalCityDetailsModal(context, city),
                onCenterMap: () {
                  _mapController.move(LatLng(city.latitude, city.longitude), 7.0);
                },
                onToggleWishlist: () => cityProvider.toggleCityWishlistStatus(city.name),
                onToggleVisited: (bool value) async {
                  if (value) {
                    cityProvider.setVisitedStatus(city.name, true);
                  } else {
                    final visitDetails = cityProvider.getCityVisitDetail(city.name);
                    if (visitDetails != null && visitDetails.visitDateRanges.isNotEmpty) {
                      final int recordCount = visitDetails.visitDateRanges.length;

                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(tr('Confirm Removal'),
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
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
                              child: Text(tr('Yes, Remove'),
                                  style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        cityProvider.clearVisitHistory(city.name);
                      }
                    } else {
                      cityProvider.setVisitedStatus(city.name, false);
                    }
                  }
                },
                isWishlisted: isWishlisted,
                wishlistColor: Colors.red.shade700,
                showWishlistControls: true,
              );
            },
          ),
        ),
      ],
    );
  }
}