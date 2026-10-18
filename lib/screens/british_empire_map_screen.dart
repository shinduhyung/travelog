// lib/screens/british_empire_map_screen.dart

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

class BritishEmpireBorder {
  final String name;
  final List<List<LatLng>> coordinates;

  BritishEmpireBorder({required this.name, required this.coordinates});
}

// [Clipper] 제국 영토 모양대로 잘라내기 (마스킹 효과)
class _EmpireClipper extends CustomClipper<Path> {
  final List<List<LatLng>> empirePolygon;
  final MapCamera camera;

  _EmpireClipper(this.empirePolygon, this.camera);

  @override
  Path getClip(Size size) {
    final path = Path();

    // 분리된 모든 영역(segments)에 대해 Path 생성
    for (var ring in empirePolygon) {
      if (ring.isEmpty) continue;

      // 시작점 이동
      final start = camera.latLngToScreenPoint(ring[0]);
      path.moveTo(start.x, start.y);

      // 나머지 점들 연결
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
    return true; // 지도가 움직일 때마다 다시 계산
  }
}

class BritishEmpireMapScreen extends StatefulWidget {
  const BritishEmpireMapScreen({super.key});

  @override
  State<BritishEmpireMapScreen> createState() => _BritishEmpireMapScreenState();
}

class _BritishEmpireMapScreenState extends State<BritishEmpireMapScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  BritishEmpireBorder? _britishEmpirePolygon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBritishEmpireData());
  }

  Future<void> _loadBritishEmpireData() async {
    setState(() => _isLoading = true);
    try {
      // 1. assets에 저장된 세그먼트 파일 로드
      final String jsonString = await rootBundle.loadString('assets/british_empire_1920_segments.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      final String name = data['name'] ?? 'British Empire';

      // 2. segments 키에서 데이터 읽기 (또는 coordinates)
      final dynamic rawData = data['segments'] ?? data['coordinates'] ?? [];

      List<List<LatLng>> parsedPolygons = [];
      List<LatLng> allPoints = [];

      if (rawData is List && rawData.isNotEmpty) {
        // 데이터 구조 확인 및 파싱 (MultiPolygon 구조 대응)
        final firstItem = rawData[0];

        // [[lat, lng], ...] 형태의 단일 덩어리인 경우 리스트로 감싸줌
        if (firstItem is List && firstItem.isNotEmpty && firstItem[0] is num) {
          List<LatLng> ring = _parseRing(rawData);
          if (ring.isNotEmpty) {
            parsedPolygons.add(ring);
            allPoints.addAll(ring);
          }
        } else {
          // [[[lat, lng]...], ...] 형태의 여러 덩어리(Segments)인 경우
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

      _britishEmpirePolygon = BritishEmpireBorder(name: name, coordinates: parsedPolygons);

      // 3. 카메라 자동 이동 (전 세계 보기 적절한 줌 레벨)
      if (allPoints.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(const LatLng(20.0, 0.0), 2.0);
        });
      }

    } catch (e) {
      debugPrint('Error loading British data: $e');
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
        // GeoJSON 순서: [longitude, latitude] -> LatLng(latitude, longitude)
        final latLng = LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
        ring.add(latLng);
      }
    }
    return ring;
  }

  // 1. 배경: 모든 국가 테두리 (회색)
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

  // 2. 방문한 국가 (분홍색, 클리핑 적용됨)
  List<Polygon> _buildVisitedPolygons(CountryProvider countryProvider) {
    final List<Polygon> polygons = [];

    for (var country in countryProvider.allCountries) {
      if (countryProvider.visitedCountries.contains(country.name)) {
        for (var polygonData in country.polygonsData) {
          polygons.add(
            Polygon(
              points: polygonData.first,
              holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
              color: Colors.pink.shade700.withOpacity(0.5), // 대영제국 테마색
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

  // 3. 제국 경계선 (검정색 실선)
  List<Polygon> _buildEmpireBorder() {
    if (_britishEmpirePolygon == null) return [];

    return _britishEmpirePolygon!.coordinates.map((points) {
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
        title:  Text(tr('British Empire (1920)'), style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              initialCenter: LatLng(20.0, 0.0), // 전 세계 중심
              initialZoom: 2.0,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
            ),
            children: [
              TileLayer(urlTemplate: '', backgroundColor: Colors.white),

              // 1. 배경 레이어
              PolygonLayer(polygons: _buildUnvisitedPolygons(countryProvider)),

              // 2. 방문 국가 레이어 (클리핑 적용)
              if (_britishEmpirePolygon != null)
                Builder(
                    builder: (context) {
                      final camera = MapCamera.of(context);
                      return ClipPath(
                        clipper: _EmpireClipper(_britishEmpirePolygon!.coordinates, camera),
                        child: PolygonLayer(polygons: _buildVisitedPolygons(countryProvider)),
                      );
                    }
                ),

              // 3. 경계선 레이어
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
                  Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.pink.shade700.withOpacity(0.5), shape: BoxShape.circle)), const SizedBox(width: 8),  Text(tr('Visited (Inside Empire)'))]),
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