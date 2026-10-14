// lib/screens/flight_route_map_screen.dart

import 'dart:io'; // ⭐️ [DEBUG] 타일 URL 직접 요청 테스트용
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/my_tile_layer.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jidoapp/providers/flight_map_settings_provider.dart';

// 이동할 화면 import
import 'package:jidoapp/screens/flight_log_list_screen.dart';

class MappedRoute {
  final String routeKey;
  final List<FlightLog> logs;
  final int totalTimes;
  final List<List<LatLng>> segments;

  MappedRoute({
    required this.routeKey,
    required this.logs,
    required this.totalTimes,
    required this.segments,
  });

  // 대표 로그: 정렬을 위해 가장 최근 로그를 반환
  FlightLog get representativeLog => logs.first;
}

class FlightRouteMapScreen extends StatefulWidget {
  const FlightRouteMapScreen({super.key});

  @override
  State<FlightRouteMapScreen> createState() => _FlightRouteMapScreenState();
}

class _FlightRouteMapScreenState extends State<FlightRouteMapScreen>
    with TickerProviderStateMixin {
  List<MappedRoute> _mappedRoutes = [];
  Map<String, Airport> _airportMap = {};

  bool _isLoading = true;

  AnimationController? _lineAnimationController;
  Animation<double>? _gradientOffset;

  AnimationController? _markerAnimationController;
  Animation<double>? _markerPulse;

  @override
  void initState() {
    super.initState();

    _lineAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _gradientOffset =
    Tween<double>(begin: 0.0, end: 1.0).animate(_lineAnimationController!)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: false);

    _markerPulse = Tween<double>(begin: 0.5, end: 2.0).animate(
      CurvedAnimation(
        parent: _markerAnimationController!,
        curve: Curves.easeOutQuad,
      ),
    );

    // ⭐️ [DEBUG] 타일 서버에 직접 요청을 날려서 상태 코드/에러를 로그로 확인
    _debugTestTileUrl();
  }

  // ⭐️ [DEBUG] 실제 타일 URL 하나를 직접 fetch해서 statusCode/에러를 로그에 출력
  Future<void> _debugTestTileUrl() async {
    const testUrl =
        'https://basemaps.cartocdn.com/rastertiles/voyager/2/2/1.png?key=cb1_3gig_1_69cf9f203f105d92c0cc26b2';
    debugPrint('[TileDebug] === 타일 URL 직접 요청 테스트 시작 ===');
    debugPrint('[TileDebug] URL: $testUrl');
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(testUrl));
      final response = await request.close();
      debugPrint('[TileDebug] statusCode: ${response.statusCode}');
      debugPrint('[TileDebug] headers: ${response.headers}');
      if (response.statusCode != 200) {
        final body = await response.transform(const SystemEncoding().decoder).join();
        debugPrint('[TileDebug] error body: $body');
      }
      client.close();
    } catch (e, st) {
      debugPrint('[TileDebug] 요청 자체가 실패함 (네트워크/DNS/SSL 등): $e');
      debugPrint('[TileDebug] stackTrace: $st');
    }
    debugPrint('[TileDebug] === 타일 URL 직접 요청 테스트 종료 ===');
  }

  // 데이터 로딩이 완료되거나 변경될 때마다 맵 데이터를 다시 준비
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final airlineProvider = Provider.of<AirlineProvider>(context);
    final airportProvider = Provider.of<AirportProvider>(context);

    if (!airlineProvider.isLoading && !airportProvider.isLoading) {
      _prepareMapData(airlineProvider, airportProvider);
    }
  }

  @override
  void dispose() {
    _lineAnimationController?.dispose();
    _markerAnimationController?.dispose();
    super.dispose();
  }

  List<LatLng> _getGreatCirclePoints(LatLng start, LatLng end, {int steps = 20}) {
    if (start == end) return [start];
    double lat1 = start.latitudeInRad;
    double lon1 = start.longitudeInRad;
    double lat2 = end.latitudeInRad;
    double lon2 = end.longitudeInRad;
    double d = math.acos(math.sin(lat1) * math.sin(lat2) +
        math.cos(lat1) * math.cos(lat2) * math.cos(lon2 - lon1));
    if (d < 0.01) return [start, end];
    List<LatLng> points = [];
    for (int i = 0; i <= steps; i++) {
      double f = i / steps;
      double a = math.sin((1 - f) * d) / math.sin(d);
      double b = math.sin(f * d) / math.sin(d);
      double x = a * math.cos(lat1) * math.cos(lon1) +
          b * math.cos(lat2) * math.cos(lon2);
      double y = a * math.cos(lat1) * math.sin(lon1) +
          b * math.cos(lat2) * math.sin(lon2);
      double z = a * math.sin(lat1) + b * math.sin(lat2);
      double lat = math.atan2(z, math.sqrt(x * x + y * y));
      double lon = math.atan2(y, x);
      points.add(LatLng(lat * 180 / math.pi, lon * 180 / math.pi));
    }
    return points;
  }

  List<List<LatLng>> _splitGreatCircleForAntiMeridian(LatLng start, LatLng end) {
    final allPoints = _getGreatCirclePoints(start, end, steps: 50);
    int splitIndex = -1;
    for (int i = 0; i < allPoints.length - 1; i++) {
      double lonDiff = (allPoints[i + 1].longitude - allPoints[i].longitude).abs();
      if (lonDiff > 180) {
        splitIndex = i;
        break;
      }
    }
    if (splitIndex == -1) return [allPoints];
    final List<LatLng> segment1 = allPoints.sublist(0, splitIndex + 1);
    final List<LatLng> segment2 = allPoints.sublist(splitIndex + 1);
    final lastLon = segment1.last.longitude;
    final boundaryLon1 = lastLon > 0 ? 180.0 : -180.0;
    segment1.last = LatLng(segment1.last.latitude, boundaryLon1);
    final firstLon = segment2.first.longitude;
    final boundaryLon2 = firstLon > 0 ? 180.0 : -180.0;
    segment2.insert(0, LatLng(segment2.first.latitude, boundaryLon2));
    return [segment1, segment2];
  }

  // ⭐️ [FlightLogListScreen과 동일한 색상 파싱 로직]
  Color _colorFromHex(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  String _getIsoCode(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty || countryCode == 'Unknown') return '';
    return countryCode.toUpperCase();
  }

  void _prepareMapData(AirlineProvider airlineProvider, AirportProvider airportProvider) {
    final airportMap = {
      for (var airport in airportProvider.allAirports) airport.iataCode: airport
    };

    final allLogs = airlineProvider.allFlightLogs;
    final Map<String, List<FlightLog>> groupedRoutes = {};

    for (final log in allLogs) {
      final depIata = log.departureIata;
      final arrIata = log.arrivalIata;
      if (depIata != null && depIata.isNotEmpty && arrIata != null && arrIata.isNotEmpty) {
        final routeKey = '$depIata-$arrIata';
        groupedRoutes.putIfAbsent(routeKey, () => []).add(log);
      }
    }

    final List<MappedRoute> mappedRoutes = [];

    for (final entry in groupedRoutes.entries) {
      final routeKey = entry.key;
      final logs = entry.value;

      logs.sort((a, b) {
        final dateA = DateTime.tryParse(a.date) ?? DateTime(1900);
        final dateB = DateTime.tryParse(b.date) ?? DateTime(1900);
        return dateB.compareTo(dateA);
      });

      final totalTimes = logs.fold(0, (sum, log) => sum + log.times);

      final depIata = routeKey.split('-')[0];
      final arrIata = routeKey.split('-')[1];
      final Airport? depAirport = airportMap[depIata];
      final Airport? arrAirport = airportMap[arrIata];

      if (depAirport != null && arrAirport != null) {
        final LatLng depLatLng = LatLng(depAirport.latitude, depAirport.longitude);
        final LatLng arrLatLng = LatLng(arrAirport.latitude, arrAirport.longitude);
        final List<List<LatLng>> segments = _splitGreatCircleForAntiMeridian(depLatLng, arrLatLng);

        mappedRoutes.add(MappedRoute(
          routeKey: routeKey,
          logs: logs,
          totalTimes: totalTimes,
          segments: segments,
        ));
      }
    }

    mappedRoutes.sort((a, b) {
      final logA = a.representativeLog;
      final logB = b.representativeLog;
      final dateA = DateTime.tryParse(logA.date);
      final dateB = DateTime.tryParse(logB.date);

      if (dateA != null && dateB != null) return dateB.compareTo(dateA);
      if (dateA != null && dateB == null) return -1;
      if (dateA == null && dateB != null) return 1;
      return a.routeKey.compareTo(b.routeKey);
    });

    if (mounted) {
      setState(() {
        _airportMap = airportMap;
        _mappedRoutes = mappedRoutes;
        _isLoading = false;
      });
    }
  }

  double _calculateStrokeWidth(int times, bool useThickness) {
    if (!useThickness) return 2.0;
    if (times <= 1) return 2.0;
    const double minWidth = 2.0;
    const double targetTimes = 10.0;
    const double maxWidth = 6.0;
    if (times >= targetTimes) return maxWidth;
    final double log10 = math.log(targetTimes);
    final double A = (maxWidth - minWidth) / log10;
    final double logThickness = A * math.log(times.toDouble()) + minWidth;
    return math.min(math.max(logThickness, minWidth), maxWidth);
  }

  Widget _buildColorPicker(Color currentColor, ValueChanged<Color> onColorChanged) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Pick a color', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: currentColor,
                onColorChanged: onColorChanged,
                displayThumbColor: true,
                enableAlpha: false,
                paletteType: PaletteType.hsvWithHue,
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                child: const Text('Select'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final settings = Provider.of<FlightMapSettingsProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return Consumer<FlightMapSettingsProvider>(
          builder: (context, settingsProvider, child) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Map Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text('Thicker lines for frequent routes', style: GoogleFonts.poppins(fontSize: 14)),
                      value: settingsProvider.useThicknessByFrequency,
                      activeColor: Colors.teal,
                      onChanged: (val) => settingsProvider.setThicknessByFrequency(val),
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: Text('Highlight Hub Airports', style: GoogleFonts.poppins(fontSize: 14)),
                      value: settingsProvider.showHubs,
                      activeColor: Colors.teal,
                      onChanged: (val) => settingsProvider.setShowHubs(val),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Route Gradient', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                          Row(
                            children: [
                              _buildColorPicker(settingsProvider.routeColor1, (c) => settingsProvider.setRouteColor1(c)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                              ),
                              _buildColorPicker(settingsProvider.routeColor2, (c) => settingsProvider.setRouteColor2(c)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => settingsProvider.resetSettings(),
                  child: Text('Reset', style: GoogleFonts.poppins(color: Colors.redAccent)),
                ),
                TextButton(
                  child: Text('Close', style: GoogleFonts.poppins(color: Colors.grey)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<FlightMapSettingsProvider>(context);
    final airlineProvider = Provider.of<AirlineProvider>(context); // ⭐️ Provider 추가
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);

    final List<Map<String, dynamic>> visibleRouteData = [];

    for (var route in _mappedRoutes) {
      final visibleLogs = route.logs.where((log) => !settings.isLogHidden(log.id)).toList();

      if (visibleLogs.isNotEmpty) {
        final visibleTotalTimes = visibleLogs.fold(0, (sum, log) => sum + log.times);

        visibleRouteData.add({
          'route': route,
          'visibleLogs': visibleLogs,
          'visibleTotalTimes': visibleTotalTimes,
        });
      }
    }

    final visibleIataCodes = <String>{};
    for (final data in visibleRouteData) {
      final route = data['route'] as MappedRoute;
      if (route.representativeLog.departureIata != null) visibleIataCodes.add(route.representativeLog.departureIata!);
      if (route.representativeLog.arrivalIata != null) visibleIataCodes.add(route.representativeLog.arrivalIata!);
    }

    final List<Marker> visibleMarkers = visibleIataCodes.map((iata) {
      final airport = _airportMap[iata];
      if (airport == null || _markerPulse == null) return null;

      final bool isHubHighlighted = settings.showHubs && airportProvider.isHub(iata);

      final countryIso = _getIsoCode(airport.country);
      final tooltipMsg = countryIso.isNotEmpty
          ? '${airport.name} (${airport.iataCode}, $countryIso)'
          : '${airport.name} (${airport.iataCode})';

      return Marker(
        width: 20,
        height: 20,
        point: LatLng(airport.latitude, airport.longitude),
        child: Tooltip(
          message: tooltipMsg,
          child: isHubHighlighted
              ? Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: ReverseAnimation(_markerAnimationController!),
                child: ScaleTransition(
                  scale: _markerPulse!,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.pink.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.pink,
                  border: Border.all(color: Colors.white, width: 1.0),
                ),
              ),
            ],
          )
              : Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple,
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.0),
              ),
            ),
          ),
        ),
      );
    }).whereType<Marker>().toList();

    final int totalGradientSteps = 20;
    final int chunkStepSize = 3;
    final double currentOffset = _gradientOffset?.value ?? 0.0;
    final int startStep = (currentOffset * totalGradientSteps).floor();

    final List<Color> animatedGradientColors = [];
    for (int i = 0; i < totalGradientSteps; i++) {
      bool isColor1 = false;
      for (int j = 0; j < chunkStepSize; j++) {
        if ((startStep + j) % totalGradientSteps == i) {
          isColor1 = true;
          break;
        }
      }
      animatedGradientColors.add(isColor1 ? settings.routeColor1 : settings.routeColor2);
    }

    final List<Polyline> visiblePolylines = visibleRouteData.expand((data) {
      final route = data['route'] as MappedRoute;
      final visibleTotalTimes = data['visibleTotalTimes'] as int;

      final double strokeWidth = _calculateStrokeWidth(visibleTotalTimes, settings.useThicknessByFrequency);

      return route.segments.map((segmentPoints) {
        return Polyline(
          points: segmentPoints,
          strokeWidth: strokeWidth,
          gradientColors: animatedGradientColors,
        );
      });
    }).toList();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                    ),
                    initialCenter: const LatLng(-5, 0),
                    initialZoom: 0.5,
                    minZoom: 0.5,
                    maxZoom: 18.0,
                    maxBounds: LatLngBounds(
                      const LatLng(-90, -180),
                      const LatLng(90, 180),
                    ),
                  ),
                  children: [
                    MyTileLayer(
                      // ⭐️ [DEBUG] 개별 타일 로드 실패 시 로그 출력
                      onTileError: (tile, error, stackTrace) {
                        debugPrint(
                            '[TileDebug] 타일 로드 실패 - coords: ${tile.coordinates}, error: $error');
                      },
                    ),
                    PolylineLayer(polylines: visiblePolylines),
                    MarkerLayer(markers: visibleMarkers),
                  ],
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: _showSettingsDialog,
                      tooltip: 'Map Settings',
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E2C),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Routes',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: settings.routeColor1.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: settings.routeColor1.withOpacity(0.5)),
                          ),
                          child: Text(
                            '${visibleRouteData.length} Routes',
                            style: GoogleFonts.poppins(
                              color: settings.routeColor1,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _mappedRoutes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final route = _mappedRoutes[index];
                        final depIata = route.routeKey.split('-')[0];
                        final arrIata = route.routeKey.split('-')[1];

                        final depAirport = _airportMap[depIata];
                        final arrAirport = _airportMap[arrIata];

                        final depCountryIso = depAirport != null ? _getIsoCode(depAirport.country) : '';
                        final arrCountryIso = arrAirport != null ? _getIsoCode(arrAirport.country) : '';

                        final depText = depCountryIso.isNotEmpty ? '$depIata ($depCountryIso)' : depIata;
                        final arrText = arrCountryIso.isNotEmpty ? '$arrIata ($arrCountryIso)' : arrIata;

                        final visibleLogCount = route.logs.where((l) => !settings.isLogHidden(l.id)).length;
                        final bool isEntireRouteHidden = visibleLogCount == 0;

                        return Container(
                          decoration: BoxDecoration(
                            color: isEntireRouteHidden ? const Color(0xFF252535) : const Color(0xFF2D2D44),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              iconColor: Colors.white70,
                              collapsedIconColor: Colors.grey,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      depText,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Icon(
                                      Icons.flight_takeoff,
                                      // ⭐️ 헤더 아이콘: 중립 색상 적용 (기본 테마 색상)
                                      color: isEntireRouteHidden ? Colors.grey : settings.routeColor1,
                                      size: 16,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      arrText,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  if (visibleLogCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        // ⭐️ 뱃지 배경: 중립 색상 적용
                                        color: Colors.black38,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        visibleLogCount > 1 ? 'x$visibleLogCount' : '1',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[300],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                                  ),
                                  child: Column(
                                    children: route.logs.map((log) {
                                      final bool isLogVisible = !settings.isLogHidden(log.id);

                                      // ⭐️ [핵심: FlightLogListScreen과 동일한 로직 적용] ⭐️
                                      // log.airlineCode를 이용하여 전체 항공사 목록에서 일치하는 객체를 실시간으로 찾습니다.
                                      final airline = airlineProvider.airlines.firstWhere(
                                            (a) => a.code == log.airlineCode,
                                        orElse: () => Airline(
                                          name: 'Unknown',
                                          code: '',
                                          themeColorHex: '#673AB7', // 기본 색상 (보라색)
                                        ),
                                      );

                                      // 찾은 항공사 정보에서 색상 추출
                                      Color airlineColor = _colorFromHex(airline.themeColorHex);

                                      // ❌ [수정]: 이 색상 보정 로직을 제거하여 FlightLogListScreen과 동일하게 고유 색상 사용
                                      // if (airlineColor.computeLuminance() < 0.2) airlineColor = Colors.grey[400]!;

                                      return InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => FlightLogListScreen(
                                                highlightLogId: log.id,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                                          child: Row(
                                            children: [
                                              // 1. Timeline (항공사 색상 적용)
                                              Column(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      // ⭐️ 점(Dot) 색상 적용
                                                      color: isLogVisible ? airlineColor : Colors.grey[800],
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  Container(
                                                    width: 2,
                                                    height: 30,
                                                    // ⭐️ 선(Line) 색상 적용
                                                    color: isLogVisible ? airlineColor.withOpacity(0.5) : Colors.grey[800],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 16),

                                              // 2. Info
                                              Expanded(
                                                child: Opacity(
                                                  opacity: isLogVisible ? 1.0 : 0.4,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${log.airlineName} ${log.flightNumber}',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${log.date}  •  ${log.times} flight(s)',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.grey[500],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // 3. Switch (항공사 색상 적용)
                                              Transform.scale(
                                                scale: 0.8,
                                                child: Switch(
                                                  value: isLogVisible,
                                                  // ⭐️ 스위치 색상 적용
                                                  activeColor: airlineColor,
                                                  inactiveThumbColor: Colors.grey,
                                                  inactiveTrackColor: Colors.grey[700],
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  onChanged: (bool value) {
                                                    settings.toggleLogVisibility(log.id, value);
                                                  },
                                                ),
                                              ),

                                              const SizedBox(width: 8),

                                              Icon(
                                                Icons.arrow_forward_ios,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}