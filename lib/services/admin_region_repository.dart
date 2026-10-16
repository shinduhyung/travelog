// lib/services/admin_region_repository.dart
//
// assets/admin1_regions.geojson (약 3.6MB)을 처음 필요할 때 한 번만 파싱해서
// 국가(iso_a2)별로 캐시한다. Provider 트리가 리마운트돼도 다시 파싱하지
// 않도록 static 캐시로 둔다 (지오메트리는 계정과 무관한 정적 데이터).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/admin_region.dart';

Map<String, List<AdminRegion>> _parseRegionsByCountry(String jsonStr) {
  final data = json.decode(jsonStr);
  final features = data['features'] as List;
  final Map<String, List<AdminRegion>> byCountry = {};
  for (final f in features) {
    final region = AdminRegion.fromFeature(f as Map<String, dynamic>);
    // 이름 없는 분쟁/미분류 구역(MX-X01~, RU-X01~ 등)은 제외
    if (region.name.isEmpty || region.countryIsoA2.isEmpty) continue;
    byCountry.putIfAbsent(region.countryIsoA2, () => []).add(region);
  }
  for (final list in byCountry.values) {
    list.sort((a, b) => a.name.compareTo(b.name));
  }
  return byCountry;
}

class AdminRegionRepository {
  AdminRegionRepository._();

  static const String _assetPath = 'assets/admin1_regions.geojson';
  static Future<Map<String, List<AdminRegion>>>? _future;

  /// 국가(iso_a2) → 지역 목록 전체. CountryDex 목록처럼 여러 국가의
  /// 지역 수를 한꺼번에 보여줄 때 사용.
  static Future<Map<String, List<AdminRegion>>> loadAll() => _loadAll();

  static Future<Map<String, List<AdminRegion>>> _loadAll() {
    return _future ??= rootBundle
        .loadString(_assetPath)
        .then((s) => compute(_parseRegionsByCountry, s))
        .catchError((Object e) {
          debugPrint('[AdminRegionRepository] Failed to load regions: $e');
          _future = null; // 다음 진입 시 재시도
          return <String, List<AdminRegion>>{};
        });
  }

  static Future<List<AdminRegion>> regionsFor(String countryIsoA2) async {
    final all = await _loadAll();
    return all[countryIsoA2] ?? const [];
  }

  /// 해외 영토/알래스카/날짜변경선 너머 조각 때문에 자동 bounds가 지나치게
  /// 넓어지는 국가는 본토 기준으로 화면을 맞춘다. (지도는 팬해서 볼 수 있음)
  static final Map<String, LatLngBounds> _fitOverrides = {
    'NZ': LatLngBounds(const LatLng(-47.5, 165.0), const LatLng(-34.0, 179.5)),
    'FJ': LatLngBounds(const LatLng(-21.0, 175.0), const LatLng(-12.0, 180.0)),
    'KI': LatLngBounds(const LatLng(-3.0, 169.0), const LatLng(4.0, 177.0)),
    'US': LatLngBounds(const LatLng(24.0, -125.0), const LatLng(49.5, -66.5)),
    'FR': LatLngBounds(const LatLng(41.3, -5.2), const LatLng(51.1, 9.6)),
    'RU': LatLngBounds(const LatLng(41.0, 19.5), const LatLng(77.0, 180.0)),
    'ES': LatLngBounds(const LatLng(35.9, -9.4), const LatLng(43.8, 4.4)),
    'PT': LatLngBounds(const LatLng(36.9, -9.6), const LatLng(42.2, -6.1)),
    'NL': LatLngBounds(const LatLng(50.7, 3.3), const LatLng(53.6, 7.3)),
  };

  static LatLngBounds? fitBoundsFor(
    String countryIsoA2,
    List<AdminRegion> regions,
  ) {
    final override = _fitOverrides[countryIsoA2];
    if (override != null) return override;

    double? minLat, maxLat, minLng, maxLng;
    for (final region in regions) {
      for (final piece in region.polygonsData) {
        if (piece.isEmpty) continue;
        for (final p in piece.first) {
          if (minLat == null || p.latitude < minLat) minLat = p.latitude;
          if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
          if (minLng == null || p.longitude < minLng) minLng = p.longitude;
          if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
        }
      }
    }
    if (minLat == null || minLng == null || maxLat == null || maxLng == null) {
      return null;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }
}
