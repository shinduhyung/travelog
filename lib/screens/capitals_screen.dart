// lib/screens/capitals_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:country_flags/country_flags.dart';

class CapitalsScreen extends StatefulWidget {
  final bool isLargestMode;
  const CapitalsScreen({super.key, this.isLargestMode = false});

  @override
  State<CapitalsScreen> createState() => _CapitalsScreenState();
}

class _CapitalsScreenState extends State<CapitalsScreen> {
  final MapController _mapController = MapController();
  List<City> _visibleCities = [];
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  bool _isMapReady = false;
  String? _highlightedCityName;
  String? _tappedCityNameForTag;

  // 마커 및 테마 색상
  final Color _markerColor = Colors.amber;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_updateVisibleCities);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();

    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );

    super.dispose();
  }

  void _onMapChanged(MapPosition position, bool hasGesture) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _updateVisibleCities);
  }

  void _updateVisibleCities() {
    if (!_isMapReady || !mounted) return;

    final bounds = _mapController.camera.visibleBounds;
    final cityProvider = Provider.of<CityProvider>(context, listen: false);
    final targetCities = _getTargetCities(cityProvider, Provider.of<CountryProvider>(context, listen: false));

    final visibleCities = targetCities.where((city) {
      final latLng = LatLng(city.latitude, city.longitude);
      return bounds.contains(latLng);
    }).toList();

    if (mounted) {
      setState(() => _visibleCities = visibleCities);
    }
  }

  List<City> _getTargetCities(CityProvider cityProvider, CountryProvider countryProvider) {
    List<City> targetCities = [];
    final allCountries = countryProvider.allCountries;
    final bool includeTerritories = countryProvider.includeTerritories;

    for (var country in allCountries) {
      // 영토 포함 옵션이 꺼져있을 때 영토는 건너뜀
      if (!includeTerritories && country.isTerritory) continue;

      String targetCityName = '';

      if (widget.isLargestMode) {
        // 최대 도시 모드
        String override = cityProvider.getLargestCityName(country.name);
        if (override.isNotEmpty) {
          targetCityName = override;
        } else {
          // 최대 도시 정보가 없을 경우 수도를 기본값으로 탐색
          final capitalCity = cityProvider.allCities.firstWhereOrNull((c) {
            if (c.country != country.name) return false;
            // 일반 수도 혹은 영토 수도(영토 포함 시) 검색
            return c.capitalStatus == CapitalStatus.capital ||
                (includeTerritories && c.capitalStatus == CapitalStatus.territory);
          });
          targetCityName = capitalCity?.name ?? '';
        }
      } else {
        // 수도 모드: 일반 국가의 수도 혹은 영토의 수도(영토 옵션 On 시) 탐색
        final capitalCity = cityProvider.allCities.firstWhereOrNull((c) {
          if (c.country != country.name) return false;
          // ⭐️ [수정] 영토 수도 처리 로직 반영
          return c.capitalStatus == CapitalStatus.capital ||
              (includeTerritories && c.capitalStatus == CapitalStatus.territory);
        });
        targetCityName = capitalCity?.name ?? '';
      }

      if (targetCityName.isNotEmpty) {
        final cityObj = cityProvider.getCityDetail(targetCityName);
        if (cityObj != null) {
          targetCities.add(cityObj);
        }
      }
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      targetCities = targetCities.where((c) => c.name.toLowerCase().contains(query)).toList();
    }

    return targetCities;
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      _tappedCityNameForTag = null;
      _highlightedCityName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final cityProvider = Provider.of<CityProvider>(context);
    final countryProvider = Provider.of<CountryProvider>(context);

    if (cityProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 3, child: _buildMap(cityProvider, countryProvider)),
            Expanded(flex: 4, child: _buildChecklistSection(cityProvider, countryProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(CityProvider cityProvider, CountryProvider countryProvider) {
    final targetCities = _getTargetCities(cityProvider, countryProvider);
    final allCities = cityProvider.allCities;

    // ⭐️ [수정] 지도 마커를 다시 노란 점(원래 스타일)으로 복구
    final List<Marker> cityMarkers = targetCities.map((city) {
      final isVisited = cityProvider.isVisited(city.name);

      return Marker(
        width: 12,
        height: 12,
        point: LatLng(city.latitude, city.longitude),
        child: GestureDetector(
          onTap: () => setState(() {
            _tappedCityNameForTag = city.name;
            _highlightedCityName = null;
          }),
          child: Icon(
            isVisited ? Icons.circle : Icons.circle_outlined,
            color: _markerColor,
            size: isVisited ? 8 : 6,
            shadows: isVisited ? [const Shadow(color: Colors.black45, blurRadius: 4.0)] : null,
          ),
        ),
      );
    }).toList();

    // 하이라이트 마커
    final List<Marker> highlightMarker = [];
    if (_highlightedCityName != null) {
      final City? city = allCities.firstWhereOrNull((c) => c.name == _highlightedCityName);
      if (city != null) {
        highlightMarker.add(
          Marker(
            width: 32,
            height: 32,
            point: LatLng(city.latitude, city.longitude),
            child: const Icon(
              Icons.location_on,
              color: Colors.redAccent,
              size: 32,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4.0)],
            ),
          ),
        );
      }
    }

    // 태그 마커
    final List<Marker> tagMarker = [];
    if (_tappedCityNameForTag != null) {
      final City? city = allCities.firstWhereOrNull((c) => c.name == _tappedCityNameForTag);
      if (city != null) {
        tagMarker.add(
          Marker(
            point: LatLng(city.latitude, city.longitude),
            width: 150,
            height: 30,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(10, -5),
              child: _buildInfoTag(city, cityProvider),
            ),
          ),
        );
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(20, 0),
            initialZoom: 1.0,
            onPositionChanged: _onMapChanged,
            onMapReady: () {
              if (mounted) {
                setState(() => _isMapReady = true);
                _updateVisibleCities();
              }
            },
            cameraConstraint: CameraConstraint.unconstrained(),
            backgroundColor: Colors.white,
            onTap: _onMapTap,
          ),
          children: [
            PolygonLayer(
              polygons: countryProvider.allCountries.expand((country) {
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
            MarkerLayer(markers: cityMarkers),
            MarkerLayer(markers: highlightMarker),
            MarkerLayer(markers: tagMarker),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTag(City city, CityProvider cityProvider) {
    final isVisited = cityProvider.isVisited(city.name);

    return GestureDetector(
      onTap: () => setState(() => _tappedCityNameForTag = null),
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CountryFlag.fromCountryCode(city.countryIsoA2),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  city.name,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isVisited) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, size: 12, color: Colors.amber),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistSection(CityProvider cityProvider, CountryProvider countryProvider) {
    final targetCitiesForStats = _getTargetCities(cityProvider, countryProvider);
    final total = targetCitiesForStats.length;
    final visitedCount = targetCitiesForStats
        .where((c) => cityProvider.isVisited(c.name))
        .length;
    final percentage = total > 0 ? (visitedCount / total) : 0.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: tr(widget.isLargestMode ? 'Search Largest Cities' : 'Search Capitals'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () => _searchController.clear(),
              )
                  : null,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  borderRadius: BorderRadius.circular(5),
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                tr('$visitedCount / $total (${(percentage * 100).toStringAsFixed(0)}%)'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _visibleCities.length,
            itemBuilder: (context, index) {
              final city = _visibleCities[index];
              final isVisited = cityProvider.isVisited(city.name);

              return ListTile(
                // ⭐️ [수정] 하단 목록에는 국기 아이콘 유지
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipOval(
                    child: CountryFlag.fromCountryCode(city.countryIsoA2),
                  ),
                ),
                title: Text(city.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(tr(city.country), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                onTap: () {
                  setState(() {
                    _highlightedCityName = city.name;
                    _tappedCityNameForTag = null;
                  });
                  _mapController.move(
                    LatLng(city.latitude, city.longitude),
                    max(7.0, _mapController.camera.zoom),
                  );
                },
                trailing: IconButton(
                  icon: Icon(
                    isVisited ? Icons.check_circle : Icons.check_circle_outline,
                    color: isVisited ? Colors.amber : Colors.grey.shade400,
                  ),
                  onPressed: () {
                    cityProvider.toggleVisitedStatus(city.name);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}