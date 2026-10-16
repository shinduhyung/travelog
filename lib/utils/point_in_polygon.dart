// lib/utils/point_in_polygon.dart
//
// flutter_map의 PolygonLayer는 탭 이벤트를 주지 않으므로,
// 지도 탭 좌표가 어느 폴리곤 안에 있는지 직접 판정한다 (ray-casting).

import 'package:latlong2/latlong.dart';

bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  bool inside = false;
  int j = polygon.length - 1;
  for (int i = 0; i < polygon.length; i++) {
    final xi = polygon[i].longitude, yi = polygon[i].latitude;
    final xj = polygon[j].longitude, yj = polygon[j].latitude;

    final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
    j = i;
  }
  return inside;
}

/// polygonsData 구조: [ [외곽 ring, 구멍 ring...], [다른 조각의 ring들], ... ]
/// (Country.polygonsData / AdminRegion.polygonsData 공통)
bool isPointInRegion(LatLng point, List<List<List<LatLng>>> polygonsData) {
  for (final piece in polygonsData) {
    if (piece.isEmpty) continue;
    if (!isPointInPolygon(point, piece.first)) continue;

    bool inHole = false;
    for (int i = 1; i < piece.length; i++) {
      if (isPointInPolygon(point, piece[i])) {
        inHole = true;
        break;
      }
    }
    if (!inHole) return true;
  }
  return false;
}
