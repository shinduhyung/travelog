import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:country_flags/country_flags.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/screens/cities_screen.dart';

class CitiesMapShare {
  static Future<void> share({
    required BuildContext context,
    required List<City> visitedCities,
    required List<Country> allCountries,
    required Map<String, dynamic> visitDetails,
    required LatLng initialCenter,
    required double initialZoom,
    bool showFlags = false,
    SizingMode? sizingMode,
    IconData? markerIcon,
    Color? markerColor,
    Color visitedColor = Colors.amber,
    Color nonVisitedColor = Colors.grey,
    double populationFactor = 1.0,
    double stayFactor = 1.0,
  }) async {
    final screenshotController = ScreenshotController();
    final primaryColor = Colors.amber;

    try {
      final directory = await getTemporaryDirectory();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating map image...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final Uint8List mapImage = await screenshotController.captureFromWidget(
        _buildMapLayout(
          context: context,
          visitedCities: visitedCities,
          allCountries: allCountries,
          visitDetails: visitDetails,
          initialCenter: initialCenter,
          initialZoom: initialZoom,
          showFlags: showFlags,
          sizingMode: sizingMode,
          markerIcon: markerIcon,
          markerColor: markerColor,
          visitedColor: visitedColor,
          nonVisitedColor: nonVisitedColor,
          populationFactor: populationFactor,
          stayFactor: stayFactor,
          primaryColor: primaryColor,
        ),
        delay: const Duration(milliseconds: 1500),
        pixelRatio: 3.0,
        context: context,
      );

      final imagePath = await File('${directory.path}/travellog_cities_share.png').create();
      await imagePath.writeAsBytes(mapImage);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Check out my city travels! I have visited ${visitedCities.length} cities via Travelog.',
      );
    } catch (e) {
      debugPrint("Share Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate share image: $e')),
        );
      }
    }
  }

  static Widget _buildMapLayout({
    required BuildContext context,
    required List<City> visitedCities,
    required List<Country> allCountries,
    required Map<String, dynamic> visitDetails,
    required LatLng initialCenter,
    required double initialZoom,
    required bool showFlags,
    required SizingMode? sizingMode,
    required IconData? markerIcon,
    required Color? markerColor,
    required Color visitedColor,
    required Color nonVisitedColor,
    required double populationFactor,
    required double stayFactor,
    required Color primaryColor,
  }) {
    final totalCities = visitedCities.length;

    // [줌아웃 계산] 요청하신 대로 40% 정도 축소 효과를 위해 줌 레벨을 0.8 낮춥니다.
    // (지도에서 값 1.0 차이는 2배 스케일 차이이므로, 0.8 정도가 적절합니다)
    final double adjustedZoom = initialZoom - 0.8;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      width: 800,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ========== 헤더 ==========
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/icons/app_logo_large.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) => const Icon(Icons.public, size: 32),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Travelog',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: -0.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalCities',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        decoration: TextDecoration.none,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'Cities',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ========== 지도 ==========
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 450,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: initialCenter,
                  // ⭐️ [수정] 40% 줌아웃 반영
                  initialZoom: adjustedZoom,
                  // ⭐️ [수정] 180도 회전 (90.0) -> 북쪽이 왼쪽을 향함
                  // (이전 코드 -90.0의 반대)
                  initialRotation: 90.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                  cameraConstraint: CameraConstraint.unconstrained(),
                  backgroundColor: const Color(0xFFF5F5F5),
                ),
                children: [
                  // 1. 국가 폴리곤
                  PolygonLayer(
                    polygons: allCountries.expand((country) {
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

                  // 2. 마커 렌더링
                  if (markerIcon != null && !showFlags)
                    MarkerLayer(
                      markers: visitedCities.map((city) {
                        final detail = visitDetails[city.name];
                        final visitCount = detail?.visitDateRanges.length ?? 0;
                        final durationInDays = detail?.totalDurationInDays() ?? 0;

                        final double calculatedMarkerSize = _getIconMarkerSize(
                          city: city,
                          visitCount: visitCount,
                          durationInDays: durationInDays,
                          sizingMode: sizingMode,
                        );

                        // 줌아웃된 만큼 아이콘 크기도 약간 조정하고 싶다면 비율을 조절하세요 (현재 유지)
                        final double iconSize = calculatedMarkerSize * 0.7;

                        return Marker(
                          width: iconSize,
                          height: iconSize,
                          point: LatLng(city.latitude, city.longitude),
                          // ⭐️ 지도 회전에 맞춰 아이콘도 돌리고 싶다면 rotate: true 추가 (선택)
                          // rotate: true,
                          child: Icon(
                            markerIcon,
                            color: markerColor ?? visitedColor,
                            size: iconSize,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 4.0)],
                          ),
                        );
                      }).toList(),
                    )
                  else if (showFlags)
                    MarkerLayer(
                      markers: visitedCities.map((city) {
                        double radius = _getFlagOrCircleRadius(
                          city: city,
                          visitDetails: visitDetails,
                          populationFactor: populationFactor,
                          stayFactor: stayFactor,
                        );
                        double size = radius * 2.5;
                        return Marker(
                          width: size,
                          height: size,
                          point: LatLng(city.latitude, city.longitude),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.0),
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 1.5)],
                            ),
                            child: ClipOval(
                              child: CountryFlag.fromCountryCode(city.countryIsoA2),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    CircleLayer(
                      circles: visitedCities.map((city) {
                        return CircleMarker(
                          point: LatLng(city.latitude, city.longitude),
                          color: visitedColor,
                          radius: _getFlagOrCircleRadius(
                            city: city,
                            visitDetails: visitDetails,
                            populationFactor: populationFactor,
                            stayFactor: stayFactor,
                          ),
                          useRadiusInMeter: false,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.0,
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static double _getIconMarkerSize({
    required City city,
    required int visitCount,
    required int durationInDays,
    required SizingMode? sizingMode,
  }) {
    const double minRadius = 1.0;
    const double maxRadius = 6.0;

    if (sizingMode == null) {
      return 2.5 * 2.0;
    }

    double calculatedRadius;

    switch (sizingMode) {
      case SizingMode.population:
        if (city.population <= 0) {
          calculatedRadius = 0.5;
        } else {
          calculatedRadius = 1.0 + 0.8 * log(city.population / 50000);
        }
        break;
      case SizingMode.visitCount:
        if (visitCount <= 0) {
          calculatedRadius = minRadius;
        } else {
          final count = min(visitCount, 10);
          final k = 3.0 / sqrt(3);
          calculatedRadius = k * sqrt(count) * 1.3;
        }
        break;
      case SizingMode.duration:
        if (durationInDays <= 0) {
          calculatedRadius = minRadius;
        } else {
          final duration = min(durationInDays, 1000);
          final logDuration = log(duration + 1);
          final k = maxRadius / sqrt(log(1001));
          calculatedRadius = k * sqrt(logDuration) * 1.5;
        }
        break;
    }
    calculatedRadius = calculatedRadius.clamp(minRadius, maxRadius);
    return calculatedRadius * 2.0;
  }

  static double _getFlagOrCircleRadius({
    required City city,
    required Map<String, dynamic> visitDetails,
    required double populationFactor,
    required double stayFactor,
  }) {
    double baseRadius = 3.0;
    double popBonus = (city.population / 10000000) * populationFactor * 0.5;
    int visits = 0;
    if (visitDetails.containsKey(city.name)) {
      final detail = visitDetails[city.name];
      visits = detail?.visitDateRanges.length ?? 0;
    }
    double stayBonus = (visits * stayFactor * 0.5);
    return (baseRadius + popBonus + stayBonus).clamp(2.0, 15.0);
  }
}