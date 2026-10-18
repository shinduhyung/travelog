// lib/screens/ottoman_empire_map_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
// [중요] Path 이름 충돌 방지를 위해 latlong2의 Path 숨김
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

class OttomanEmpireBorder {
  final String name;
  // 단일 덩어리라도 확장성을 위해 List<List<LatLng>> 구조 유지
  final List<List<LatLng>> coordinates;

  OttomanEmpireBorder({required this.name, required this.coordinates});
}

// [핵심 로직] 제국 영토 모양대로 레이어를 잘라내기 위한 Clipper 클래스
class _EmpireClipper extends CustomClipper<Path> {
  final List<List<LatLng>> empirePolygon;
  final MapCamera camera;

  _EmpireClipper(this.empirePolygon, this.camera);

  @override
  Path getClip(Size size) {
    final path = Path();

    // 제국 영토 좌표를 화면 좌표로 변환하여 Path 생성
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
    return true; // 지도가 움직일 때마다 다시 잘라내야 함
  }
}

class OttomanEmpireMapScreen extends StatefulWidget {
  const OttomanEmpireMapScreen({super.key});

  @override
  State<OttomanEmpireMapScreen> createState() => _OttomanEmpireMapScreenState();
}

class _OttomanEmpireMapScreenState extends State<OttomanEmpireMapScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  OttomanEmpireBorder? _ottomanEmpirePolygon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOttomanEmpireData());
  }

  Future<void> _loadOttomanEmpireData() async {
    setState(() => _isLoading = true);
    try {
      final String jsonString = await rootBundle.loadString('assets/ottoman_empire_border.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      final String name = data['name'] ?? 'Ottoman Empire';

      // JSON 구조: coordinates -> [ [x,y], [x,y], ... ] (단일 리스트)
      final List<dynamic> rawCoords = data['coordinates'] ?? [];

      List<List<LatLng>> parsedPolygons = [];
      List<LatLng> allPoints = [];

      // [수정된 파싱 로직] 제공해주신 JSON이 단일 Polygon(점들의 리스트) 형식이므로 단순 루프로 처리
      if (rawCoords.isNotEmpty) {
        List<LatLng> points = [];
        for (var coord in rawCoords) {
          // coord: [longitude, latitude]
          if (coord is List && coord.length >= 2) {
            final latLng = LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
            points.add(latLng);
            allPoints.add(latLng);
          }
        }
        if (points.isNotEmpty) {
          parsedPolygons.add(points);
        }
      }

      _ottomanEmpirePolygon = OttomanEmpireBorder(name: name, coordinates: parsedPolygons);

      // 카메라 자동 이동
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
      debugPrint('Error loading Ottoman data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 1. 모든 국가 테두리 그리기 (배경)
  List<Polygon> _buildUnvisitedPolygons(CountryProvider countryProvider) {
    final List<Polygon> polygons = [];

    for (var country in countryProvider.allCountries) {
      for (var polygonData in country.polygonsData) {
        polygons.add(
          Polygon(
            points: polygonData.first,
            holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
            color: Colors.transparent, // 배경 투명
            borderColor: Colors.grey.withOpacity(0.5), // 회색 테두리
            borderStrokeWidth: 1.0,
            isFilled: true,
          ),
        );
      }
    }
    return polygons;
  }

  // 2. 방문한 국가 그리기 (ClipPath로 인해 제국 안쪽만 보임)
  List<Polygon> _buildVisitedPolygons(CountryProvider countryProvider) {
    final List<Polygon> polygons = [];

    for (var country in countryProvider.allCountries) {
      if (countryProvider.visitedCountries.contains(country.name)) {
        for (var polygonData in country.polygonsData) {
          polygons.add(
            Polygon(
              points: polygonData.first,
              holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
              color: Colors.red.withOpacity(0.5), // 오스만 테마 색상 (빨강)
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

  // 3. 제국 경계선 그리기
  List<Polygon> _buildEmpireBorder() {
    if (_ottomanEmpirePolygon == null) return [];

    return _ottomanEmpirePolygon!.coordinates.map((points) {
      return Polygon(
        points: points,
        color: Colors.transparent,
        borderColor: Colors.black, // 검정색 경계선
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
        title:  Text(tr('Ottoman Empire'), style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              initialCenter: LatLng(39.0, 35.0),
              initialZoom: 4.0,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
            ),
            children: [
              TileLayer(urlTemplate: '', backgroundColor: Colors.white),

              // 1. 배경: 모든 국가 테두리
              PolygonLayer(polygons: _buildUnvisitedPolygons(countryProvider)),

              // 2. 방문한 국가 (ClipPath 적용: 제국 영역 안쪽만 표시)
              if (_ottomanEmpirePolygon != null)
                Builder(
                    builder: (context) {
                      final camera = MapCamera.of(context);
                      return ClipPath(
                        clipper: _EmpireClipper(_ottomanEmpirePolygon!.coordinates, camera),
                        child: PolygonLayer(polygons: _buildVisitedPolygons(countryProvider)),
                      );
                    }
                ),

              // 3. 최상단: 제국 경계선
              PolygonLayer(polygons: _buildEmpireBorder()),
            ],
          ),

          // 범례 (Legend)
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
                  Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.red.withOpacity(0.5), shape: BoxShape.circle)), const SizedBox(width: 8),  Text(tr('Visited (Inside Empire)'))]),
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