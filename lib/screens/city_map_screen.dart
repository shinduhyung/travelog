// lib/screens/city_map_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart'; // CountryProvider 추가
import 'package:jidoapp/my_tile_layer.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:jidoapp/screens/cities_screen.dart';
import 'package:jidoapp/screens/cities_map_share.dart'; // 공유 유틸리티 import

class CityMapScreen extends StatefulWidget {
  final String title;
  final List<City> cities;
  final IconData markerIcon;
  final Color markerColor;

  const CityMapScreen({
    super.key,
    required this.title,
    required this.cities,
    required this.markerIcon,
    required this.markerColor,
  });

  @override
  State<CityMapScreen> createState() => _CityMapScreenState();
}

class _CityMapScreenState extends State<CityMapScreen> {
  SizingMode? _sizingMode = SizingMode.population;

  void _updateSizingMode(SizingMode toggledMode, bool isEnabled) {
    setState(() {
      if (isEnabled) {
        _sizingMode = toggledMode;
      } else {
        if (_sizingMode == toggledMode) {
          _sizingMode = null;
        }
      }
    });
  }

  double _getMarkerSizeFromCitiesScreenLogic({
    required City city,
    required int visitCount,
    required int durationInDays,
    required CityProvider cityProvider,
  }) {
    // ... (기존 로직 동일)
    const double minRadius = 1.0;
    const double maxRadius = 6.0;

    if (_sizingMode == null) {
      return 2.5 * 2.0;
    }

    double calculatedRadius;

    switch (_sizingMode!) {
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

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final cityProvider = Provider.of<CityProvider>(context);
    final countryProvider = Provider.of<CountryProvider>(context); // 공유 시 국가 데이터 필요
    final visitDetails = cityProvider.visitDetails;
    const double sizeRatio = 0.7;

    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.title))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSizingSwitch('Size by Population', SizingMode.population),
                _buildSizingSwitch('Size by Duration', SizingMode.duration),
                _buildSizingSwitch('Size by Visit Count', SizingMode.visitCount),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(const LatLng(-60, -180), const LatLng(85, 180)),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                ),
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds(const LatLng(-60, -180), const LatLng(85, 180)),
                  padding: const EdgeInsets.all(8.0),
                ),
              ),
              children: [
                const MyTileLayer(),
                MarkerLayer(
                  markers: widget.cities.map((city) {
                    final CityVisitDetail? detail = visitDetails[city.name];
                    final bool isVisited = detail?.visitDateRanges != null && detail!.visitDateRanges.isNotEmpty;

                    final double calculatedMarkerSize = _getMarkerSizeFromCitiesScreenLogic(
                      city: city,
                      visitCount: detail?.visitDateRanges.length ?? 0,
                      durationInDays: detail?.totalDurationInDays() ?? 0,
                      cityProvider: cityProvider,
                    );

                    final double iconSize = calculatedMarkerSize * sizeRatio;
                    final double markerSize = iconSize;

                    return Marker(
                      width: markerSize,
                      height: markerSize,
                      point: LatLng(city.latitude, city.longitude),
                      child: Tooltip(
                        message: city.name,
                        child: Icon(
                          widget.markerIcon,
                          color: isVisited ? widget.markerColor : widget.markerColor.withOpacity(0.6),
                          size: iconSize,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 4.0)],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
      // 💡 [추가] 공유 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 화면에 보이는 도시들만 공유할지, 전체 방문 도시를 공유할지 선택
          // 여기서는 '현재 화면에 표시된 리스트(widget.cities)' 중 방문한 곳을 기준으로 공유합니다.
          // 만약 전체를 공유하고 싶다면 cityProvider.allCities를 사용하세요.

          final shareCities = widget.cities.where((c) {
            final detail = visitDetails[c.name];
            return detail != null && detail.visitDateRanges.isNotEmpty;
          }).toList();

          await CitiesMapShare.share(
            context: context,
            visitedCities: shareCities.isNotEmpty ? shareCities : widget.cities, // 방문 필터링 혹은 전체
            allCountries: countryProvider.allCountries,
            visitDetails: visitDetails,
            initialCenter: const LatLng(20, 0),
            initialZoom: 1.0,

            // 🔥 화면의 설정 값을 그대로 전달
            sizingMode: _sizingMode,
            markerColor: widget.markerColor,
            markerIcon: widget.markerIcon,
          );
        },
        child: const Icon(Icons.share),
      ),
    );
  }

  Widget _buildSizingSwitch(String label, SizingMode mode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr(label), style: const TextStyle(fontSize: 12)),
        Switch(
          value: _sizingMode == mode,
          onChanged: (value) {
            _updateSizingMode(mode, value);
          },
        ),
      ],
    );
  }
}