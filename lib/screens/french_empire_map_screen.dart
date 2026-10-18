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

class FrenchEmpireBorder {
  final String name;
  final List<List<LatLng>> coordinates;

  FrenchEmpireBorder({required this.name, required this.coordinates});
}

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

class FrenchEmpireMapScreen extends StatefulWidget {
  const FrenchEmpireMapScreen({super.key});

  @override
  State<FrenchEmpireMapScreen> createState() => _FrenchEmpireMapScreenState();
}

class _FrenchEmpireMapScreenState extends State<FrenchEmpireMapScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  FrenchEmpireBorder? _frenchEmpirePolygon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFrenchEmpireData());
  }

  Future<void> _loadFrenchEmpireData() async {
    setState(() => _isLoading = true);
    try {
      // [파일 로드] 프랑스 제국 파일
      final String jsonString = await rootBundle.loadString('assets/french_empire_1920_segments.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      final String name = data['name'] ?? 'French Empire';

      // [파싱] segments 구조 읽기
      final dynamic rawData = data['segments'] ?? data['coordinates'] ?? [];

      List<List<LatLng>> parsedPolygons = [];
      List<LatLng> allPoints = [];

      if (rawData is List && rawData.isNotEmpty) {
        final firstItem = rawData[0];

        if (firstItem is List && firstItem.isNotEmpty && firstItem[0] is num) {
          // 단일 덩어리
          List<LatLng> ring = _parseRing(rawData);
          if (ring.isNotEmpty) {
            parsedPolygons.add(ring);
            allPoints.addAll(ring);
          }
        } else {
          // 여러 덩어리 (MultiPolygon)
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

      _frenchEmpirePolygon = FrenchEmpireBorder(name: name, coordinates: parsedPolygons);

      if (allPoints.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 아프리카/유럽 중심 뷰
          _mapController.move(const LatLng(20.0, 10.0), 2.5);
        });
      }

    } catch (e) {
      debugPrint('Error loading French data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<LatLng> _parseRing(List<dynamic> segment) {
    List<LatLng> ring = [];
    for (var coord in segment) {
      if (coord is List && coord.length >= 2) {
        final latLng = LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
        ring.add(latLng);
      }
    }
    return ring;
  }

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

  List<Polygon> _buildVisitedPolygons(CountryProvider countryProvider) {
    final List<Polygon> polygons = [];
    for (var country in countryProvider.allCountries) {
      if (countryProvider.visitedCountries.contains(country.name)) {
        for (var polygonData in country.polygonsData) {
          polygons.add(
            Polygon(
              points: polygonData.first,
              holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
              color: Colors.indigo.withOpacity(0.5), // 프랑스 제국 테마색 (인디고)
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

  List<Polygon> _buildEmpireBorder() {
    if (_frenchEmpirePolygon == null) return [];
    return _frenchEmpirePolygon!.coordinates.map((points) {
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
        title:  Text(tr('French Empire (1920)'), style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              initialCenter: LatLng(20.0, 10.0),
              initialZoom: 2.5,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
            ),
            children: [
              TileLayer(urlTemplate: '', backgroundColor: Colors.white),
              PolygonLayer(polygons: _buildUnvisitedPolygons(countryProvider)),
              if (_frenchEmpirePolygon != null)
                Builder(
                    builder: (context) {
                      final camera = MapCamera.of(context);
                      return ClipPath(
                        clipper: _EmpireClipper(_frenchEmpirePolygon!.coordinates, camera),
                        child: PolygonLayer(polygons: _buildVisitedPolygons(countryProvider)),
                      );
                    }
                ),
              PolygonLayer(polygons: _buildEmpireBorder()),
            ],
          ),
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
                  Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.5), shape: BoxShape.circle)), const SizedBox(width: 8),  Text(tr('Visited (Inside Empire)'))]),
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