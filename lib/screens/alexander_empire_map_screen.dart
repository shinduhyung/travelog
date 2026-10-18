import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
// [중요] Path 이름 충돌 방지
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

class AlexanderEmpireBorder {
  final String name;
  final List<List<LatLng>> coordinates;

  AlexanderEmpireBorder({required this.name, required this.coordinates});
}

// [Clipper] 제국 영토 모양대로 잘라내기
class _EmpireClipper extends CustomClipper<Path> {
  final List<List<LatLng>> empirePolygon;
  final MapCamera camera;

  _EmpireClipper(this.empirePolygon, this.camera);

  @override
  Path getClip(Size size) {
    final path = Path();

    for (var ring in empirePolygon) {
      if (ring.isEmpty) continue;

      final start = camera.latLngToScreenPoint(ring[0]);
      path.moveTo(start.x, start.y);

      for (int i = 1; i < ring.length; i++) {
        final point = camera.latLngToScreenPoint(ring[i]);
        path.lineTo(point.x, point.y);
      }
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _EmpireClipper oldClipper) {
    return true;
  }
}

class AlexanderEmpireMapScreen extends StatefulWidget {
  const AlexanderEmpireMapScreen({super.key});

  @override
  State<AlexanderEmpireMapScreen> createState() => _AlexanderEmpireMapScreenState();
}

class _AlexanderEmpireMapScreenState extends State<AlexanderEmpireMapScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  AlexanderEmpireBorder? _alexanderEmpirePolygon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAlexanderData());
  }

  Future<void> _loadAlexanderData() async {
    setState(() => _isLoading = true);
    try {
      // [수정] segments 파일 로드 (파일명 확인 필수!)
      final String jsonString = await rootBundle.loadString('assets/alexander_empire_bc323_segments.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      final String name = data['name'] ?? 'Empire of Alexander';

      // [수정] JSON 키가 "segments" 또는 "coordinates" 둘 다 확인
      final dynamic rawData = data['segments'] ?? data['coordinates'] ?? [];

      List<List<LatLng>> parsedPolygons = [];
      List<LatLng> allPoints = [];

      // [만능 파싱 로직] 단일/다중 덩어리 모두 처리
      if (rawData is List && rawData.isNotEmpty) {
        final firstItem = rawData[0];

        if (firstItem is List && firstItem.isNotEmpty && firstItem[0] is num) {
          // Case A: [[lat, lng], ...] -> 단일 덩어리
          List<LatLng> ring = _parseRing(rawData);
          if (ring.isNotEmpty) {
            parsedPolygons.add(ring);
            allPoints.addAll(ring);
          }
        } else {
          // Case B: [[[lat, lng]...], ...] -> 여러 덩어리 (MultiPolygon)
          for (var segment in rawData) {
            if (segment is List) {
              List<LatLng> ring = _parseRing(segment);
              if (ring.isNotEmpty) {
                parsedPolygons.add(ring);
                allPoints.addAll(ring);
              }
            }
          }
        }
      }

      _alexanderEmpirePolygon = AlexanderEmpireBorder(name: name, coordinates: parsedPolygons);

      // 카메라 자동 이동 (페르시아/중동 중심)
      if (allPoints.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(allPoints),
              padding: const EdgeInsets.all(50),
            ),
          );
        });
      }

    } catch (e) {
      debugPrint('Error loading Alexander data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 좌표 리스트 파싱 헬퍼 함수
  List<LatLng> _parseRing(List<dynamic> segment) {
    List<LatLng> ring = [];
    for (var coord in segment) {
      if (coord is List && coord.length >= 2) {
        // GeoJSON 순서: [longitude, latitude] -> LatLng(lat, long)
        final latLng = LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
        ring.add(latLng);
      }
    }
    return ring;
  }

  // 1. 배경: 모든 국가 테두리
  List<Polygon> _buildUnvisitedPolygons(CountryProvider countryProvider) {
    final List<Polygon> polygons = [];

    for (var country in countryProvider.allCountries) {
      for (var polygonData in country.polygonsData) {
        polygons.add(
          Polygon(
            points: polygonData.first,
            holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
            color: Colors.transparent,
            borderColor: Colors.grey.withOpacity(0.5),
            borderStrokeWidth: 1.0,
            isFilled: true,
          ),
        );
      }
    }
    return polygons;
  }

  // 2. 방문한 국가 (ClipPath 적용)
  List<Polygon> _buildVisitedPolygons(CountryProvider countryProvider) {
    final List<Polygon> polygons = [];

    for (var country in countryProvider.allCountries) {
      if (countryProvider.visitedCountries.contains(country.name)) {
        for (var polygonData in country.polygonsData) {
          polygons.add(
            Polygon(
              points: polygonData.first,
              holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
              color: Colors.amber.shade900.withOpacity(0.5), // 알렉산더 테마색 (Amber)
              borderColor: Colors.transparent,
              borderStrokeWidth: 0,
              isFilled: true,
            ),
          );
        }
      }
    }
    return polygons;
  }

  // 3. 제국 경계선
  List<Polygon> _buildEmpireBorder() {
    if (_alexanderEmpirePolygon == null) return [];
    return _alexanderEmpirePolygon!.coordinates.map((points) {
      return Polygon(
        points: points,
        color: Colors.transparent,
        borderColor: Colors.black,
        borderStrokeWidth: 2.0,
        isFilled: false,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final countryProvider = Provider.of<CountryProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:  Text(tr('Empire of Alexander'), style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(33.0, 44.0), // 바빌론 중심
              initialZoom: 4.0,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
            ),
            children: [
              TileLayer(urlTemplate: '', backgroundColor: Colors.white),

              // 1. 배경 레이어
              PolygonLayer(polygons: _buildUnvisitedPolygons(countryProvider)),

              // 2. 방문 국가 레이어 (클리핑)
              if (_alexanderEmpirePolygon != null)
                Builder(
                    builder: (context) {
                      final camera = MapCamera.of(context);
                      return ClipPath(
                        clipper: _EmpireClipper(_alexanderEmpirePolygon!.coordinates, camera),
                        child: PolygonLayer(polygons: _buildVisitedPolygons(countryProvider)),
                      );
                    }
                ),

              // 3. 경계선 레이어
              PolygonLayer(polygons: _buildEmpireBorder()),
            ],
          ),

          // 범례
          Positioned(
            bottom: 30, left: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(tr('Legend'), style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.amber.shade900.withOpacity(0.5), shape: BoxShape.circle)), const SizedBox(width: 8),  Text(tr('Visited (Inside Empire)'))]),
                  const SizedBox(height: 4),
                  Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.5)), shape: BoxShape.circle)), const SizedBox(width: 8),  Text(tr('Other Countries'))]),
                  const SizedBox(height: 4),
                  Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2.0), shape: BoxShape.circle)), const SizedBox(width: 8),  Text(tr('Empire Border'))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}