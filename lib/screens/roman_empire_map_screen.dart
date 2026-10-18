// lib/screens/roman_empire_map_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
// [중요] Path 이름 충돌 방지 (이제 거리 계산 로직이 없으므로 Distance는 필요 없음)
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

class RomanEmpireBorder {
  final String name;
  final List<List<LatLng>> coordinates;

  RomanEmpireBorder({required this.name, required this.coordinates});
}

// [Clipper] 제국 영토 모양대로 잘라내기
class _EmpireClipper extends CustomClipper<Path> {
  final List<List<LatLng>> empirePolygon;
  final MapCamera camera;

  _EmpireClipper(this.empirePolygon, this.camera);

  @override
  Path getClip(Size size) {
    final path = Path();

    // 분리된 모든 영역(segments)에 대해 Path를 생성합니다.
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

class RomanEmpireMapScreen extends StatefulWidget {
  const RomanEmpireMapScreen({super.key});

  @override
  State<RomanEmpireMapScreen> createState() => _RomanEmpireMapScreenState();
}

class _RomanEmpireMapScreenState extends State<RomanEmpireMapScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  RomanEmpireBorder? _romanEmpirePolygon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRomanEmpireData());
  }

  Future<void> _loadRomanEmpireData() async {
    setState(() => _isLoading = true);
    try {
      // [수정] 파일명이 변경되었다면 assets 경로도 맞춰주세요.
      final String jsonString = await rootBundle.loadString('assets/roman_empire_100_segments.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      final String name = data['name'] ?? 'Roman Empire';

      // [수정] JSON 키가 "coordinates"에서 "segments"로 변경됨 (MultiPolygon 구조)
      final List<dynamic> rawSegments = data['segments'] ?? [];

      List<List<LatLng>> parsedPolygons = [];
      List<LatLng> allPoints = [];

      // 데이터가 이미 덩어리별로 나뉘어 있으므로 단순 이중 루프로 파싱
      if (rawSegments.isNotEmpty) {
        for (var segment in rawSegments) {
          // 각 segment는 점들의 리스트 [[x,y], [x,y]...]
          if (segment is List) {
            List<LatLng> ring = [];
            for (var coord in segment) {
              if (coord is List && coord.length >= 2) {
                // GeoJSON 순서: [longitude, latitude] -> LatLng(lat, long)
                final latLng = LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
                ring.add(latLng);
                allPoints.add(latLng);
              }
            }
            if (ring.isNotEmpty) {
              parsedPolygons.add(ring);
            }
          }
        }
      }

      _romanEmpirePolygon = RomanEmpireBorder(name: name, coordinates: parsedPolygons);

      // 카메라 자동 이동 (로마 중심)
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
      debugPrint('Error loading Roman data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
              color: Colors.purple.shade700.withOpacity(0.5), // 로마 제국 테마색
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

  // 3. 제국 경계선 (여러 덩어리 렌더링)
  List<Polygon> _buildEmpireBorder() {
    if (_romanEmpirePolygon == null) return [];

    return _romanEmpirePolygon!.coordinates.map((points) {
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
        title:  Text(tr('Roman Empire (100 AD)'), style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              initialCenter: LatLng(41.9, 12.5), // 로마
              initialZoom: 4.0,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
            ),
            children: [
              TileLayer(urlTemplate: '', backgroundColor: Colors.white),

              // 1. 배경 레이어
              PolygonLayer(polygons: _buildUnvisitedPolygons(countryProvider)),

              // 2. 방문 국가 레이어 (클리핑)
              if (_romanEmpirePolygon != null)
                Builder(
                    builder: (context) {
                      final camera = MapCamera.of(context);
                      return ClipPath(
                        clipper: _EmpireClipper(_romanEmpirePolygon!.coordinates, camera),
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
                  Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.purple.shade700.withOpacity(0.5), shape: BoxShape.circle)), const SizedBox(width: 8),  Text(tr('Visited (Inside Empire)'))]),
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