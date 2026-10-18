// lib/screens/historical_empire_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart' as fm; // fm 별칭 사용
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/historical_empire_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

// 1. StatefulWidget으로 변경
class HistoricalEmpireScreen extends StatefulWidget {
  final HistoricalEmpire empire;

  const HistoricalEmpireScreen({super.key, required this.empire});

  @override
  State<HistoricalEmpireScreen> createState() => _HistoricalEmpireScreenState();
}

class _HistoricalEmpireScreenState extends State<HistoricalEmpireScreen> {
  // 2. 'Show Territory' 스위치 상태 변수 추가
  bool _showTerritory = true;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final countryProvider = Provider.of<CountryProvider>(context);
    if (countryProvider.isLoading) {
      return Scaffold(
          appBar: AppBar(title: Text(widget.empire.name)),
          body: const Center(child: CircularProgressIndicator()));
    }

    final countriesInEmpire = countryProvider.allCountries
        .where((c) => widget.empire.countries.contains(c.name))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.empire.name),
        // 3. AppBar에 스위치 추가
        actions: [
          Row(
            children: [
               Text(tr('Show Territory'), style: TextStyle(fontSize: 12)),
              Switch(
                value: _showTerritory,
                onChanged: (value) {
                  setState(() {
                    _showTerritory = value;
                  });
                },
              ),
            ],
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildMap(context, countryProvider.allCountries,
                countryProvider.visitedCountries),
          ),
          Expanded(
            flex: 2,
            // 4. 하단 영역을 체크리스트로 교체
            child: _buildChecklist(context, countriesInEmpire,
                countryProvider.visitedCountries),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, List<Country> allCountries,
      Set<String> visitedCountries) {

    final List<fm.Polygon> empirePolygons = [];
    if (_showTerritory && widget.empire.polygonCoordinates != null) {
      for (var polygonRing in widget.empire.polygonCoordinates!) {
        empirePolygons.add(
          fm.Polygon(
            points: polygonRing,
            color: Colors.red.withOpacity(0.2),
            borderColor: Colors.red.shade400,
            borderStrokeWidth: 1.5,
            isFilled: true,
          ),
        );
      }
    }

    List<fm.Polygon> visitedCountryPolygons = [];
    for (var country in allCountries) {
      if (widget.empire.countries.contains(country.name) && visitedCountries.contains(country.name)) {
        for (var polygonData in country.polygonsData) {
          visitedCountryPolygons.add(
            fm.Polygon(
              points: polygonData.first,
              holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
              color: Colors.blue.withOpacity(0.7),
              borderColor: Colors.white.withOpacity(0.6),
              borderStrokeWidth: 0.5,
              isFilled: true,
            ),
          );
        }
      }
    }

    // 5. fm. 접두사를 일관되게 적용하여 오류의 근본 원인 해결
    return fm.FlutterMap(
      options: fm.MapOptions(
        initialCenter: const LatLng(40, 60),
        initialZoom: 2.5,
        cameraConstraint: fm.CameraConstraint.contain(
          bounds: fm.LatLngBounds(
            const LatLng(-60, -180),
            const LatLng(85, 180),
          ),
        ),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png?key=cb1_3gig_1_69cf9f203f105d92c0cc26b2',
          subdomains: const ['a', 'b', 'c'],
        ),
        fm.PolygonLayer(polygons: empirePolygons),
        fm.PolygonLayer(polygons: visitedCountryPolygons),
      ],
    );
  }

  // 6. 통계 위젯을 대체하는 새로운 체크리스트 위젯
  Widget _buildChecklist(BuildContext context, List<Country> countriesInEmpire, Set<String> visitedCountries) {
    final provider = Provider.of<CountryProvider>(context, listen: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            tr('Countries in this Territory (${countriesInEmpire.length})'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: countriesInEmpire.length,
            itemBuilder: (context, index) {
              final country = countriesInEmpire[index];
              final isVisited = visitedCountries.contains(country.name);

              return CheckboxListTile(
                title: Text(tr(country.name)),
                value: isVisited,
                onChanged: (bool? value) {
                  if (value == true) {
                    provider.setVisitCount(country.name, 1);
                  } else {
                    provider.setVisitCount(country.name, 0);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}