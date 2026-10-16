// lib/models/admin_region.dart
//
// Natural Earth admin-1 (주/도/현 등) feature 하나를 파싱한 결과.
// 원본: travelogstates 프로토타입 → assets/admin1_regions.geojson

import 'package:latlong2/latlong.dart';

class AdminRegion {
  final String name; // "California"
  final String iso31662; // "US-CA" — 저장 키로 사용 (이름은 국가 내 중복이 있음)
  final String countryIsoA2; // "US"
  final String? storageKey; // Unique source key when ISO codes collide.
  final bool isWholeArea; // Outline only; not a visitable subdivision.
  final String typeLabel; // "State", "Province", "Prefecture" 등
  final List<List<List<LatLng>>> polygonsData;

  const AdminRegion({
    required this.name,
    required this.iso31662,
    required this.countryIsoA2,
    required this.typeLabel,
    required this.polygonsData,
    this.storageKey,
    this.isWholeArea = false,
  });

  String get stableKey =>
      storageKey ?? (iso31662.isNotEmpty ? iso31662 : '$countryIsoA2::$name');

  factory AdminRegion.fromFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>;

    final List<List<List<LatLng>>> polygonsData = [];
    final coordinates = geometry['coordinates'] as List;

    void addPolygon(List polygonCoords) {
      final List<List<LatLng>> rings = [];
      for (var ring in polygonCoords) {
        final points = (ring as List)
            .map(
              (p) => LatLng(
                ((p as List)[1] as num).toDouble(),
                (p[0] as num).toDouble(),
              ),
            )
            .toList();
        rings.add(points);
      }
      polygonsData.add(rings);
    }

    if (geometry['type'] == 'Polygon') {
      addPolygon(coordinates);
    } else if (geometry['type'] == 'MultiPolygon') {
      for (var poly in coordinates) {
        addPolygon(poly as List);
      }
    }

    return AdminRegion(
      name: (props['name'] ?? '') as String,
      iso31662: (props['iso_3166_2'] ?? '') as String,
      countryIsoA2: (props['iso_a2'] ?? '') as String,
      typeLabel: (props['type_en'] ?? '') as String,
      storageKey: props['storage_key'] as String?,
      isWholeArea: props['whole_area'] == true,
      polygonsData: polygonsData,
    );
  }
}
