// lib/screens/trip_map_screen.dart

import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // 이 단일 임포트만으로 모든 관련 클래스를 사용하도록 합니다.
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/city_model.dart'; // City 모델 임포트
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/my_tile_layer.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart'; // 🆕 이 줄을 추가하세요.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer; // developer.log 사용을 위해 추가
import 'package:collection/collection.dart'; // firstWhereOrNull 사용을 위해 추가

// 마커에 대한 원본 데이터를 저장하기 위한 내부 클래스 (파일 최상단으로 이동)
class _MarkerData {
  final LatLng point;
  final String? markerChar; // D, A, H, T 또는 null (일반 도시)
  final String duration; // 일반 도시의 경우 체류 기간
  final String cityDisplayName; // 표시될 도시/공항 이름
  final Color markerColor; // 마커 색상
  final String? countryIsoA2; // 국가 코드 (국기 표시용)

  _MarkerData({
    required this.point,
    this.markerChar,
    required this.duration,
    required this.cityDisplayName,
    required this.markerColor,
    this.countryIsoA2,
  });

  // Equals와 hashCode를 오버라이드하여 Set에서 객체 비교가 가능하도록 함
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _MarkerData &&
              runtimeType == other.runtimeType &&
              point == other.point &&
              markerChar == other.markerChar &&
              duration == other.duration &&
              cityDisplayName == other.cityDisplayName &&
              markerColor == other.markerColor &&
              countryIsoA2 == other.countryIsoA2;

  @override
  int get hashCode =>
      point.hashCode ^ markerChar.hashCode ^ duration.hashCode ^ cityDisplayName.hashCode ^ markerColor.hashCode ^ countryIsoA2.hashCode;
}

// TripLeg에 Key를 부여하여 선택 및 수정을 용이하게 함
class EditableTripLeg extends TripLeg {
  final Key key;
  final Color customColor;
  final String lineStyle;
  final int sequence; // 🆕 이 줄 추가!

  EditableTripLeg({
    required this.key,
    required LatLng originPoint,
    required LatLng destinationPoint,
    required String transportType,
    String? transportIdentifier,
    String? companyName,
    String? date,
    String? duration,
    Airport? originAirport,
    Airport? destinationAirport,
    String? originCityName,
    String? destinationCityName,
    Color? customColor,
    String? lineStyle,
    int? sequence,
  }) : customColor = customColor ?? Colors.blue,
        lineStyle = lineStyle ?? "solid",
        sequence = sequence ?? 0,
        super(
        originPoint: originPoint,
        destinationPoint: destinationPoint,
        transportType: transportType,
        transportIdentifier: transportIdentifier,
        companyName: companyName,
        date: date,
        duration: duration,
        originAirport: originAirport,
        destinationAirport: destinationAirport,
        originCityName: originCityName,
        destinationCityName: destinationCityName,
      );

  // EditableTripLeg의 속성을 변경하여 새로운 인스턴스를 생성하는 copyWith
  EditableTripLeg copyWith({
    LatLng? originPoint,
    LatLng? destinationPoint,
    String? transportType,
    String? transportIdentifier,
    String? companyName,
    String? date,
    String? duration,
    Airport? originAirport,
    Airport? destinationAirport,
    String? originCityName,
    String? destinationCityName,
    Color? customColor,
    String? lineStyle,
    int? sequence,  // 이 줄 추가
  }) {
    return EditableTripLeg(
      key: key,
      originPoint: originPoint ?? this.originPoint,
      destinationPoint: destinationPoint ?? this.destinationPoint,
      transportType: transportType ?? this.transportType,
      transportIdentifier: transportIdentifier ?? this.transportIdentifier,
      companyName: companyName ?? this.companyName,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      originAirport: originAirport ?? this.originAirport,
      destinationAirport: destinationAirport ?? this.destinationAirport,
      originCityName: originCityName ?? this.originCityName,
      destinationCityName: destinationCityName ?? this.destinationCityName,
      customColor: customColor ?? this.customColor,
      lineStyle: lineStyle ?? this.lineStyle,
      sequence: sequence ?? this.sequence,  // 이 줄 추가

    );

  }
}

// 도시 체류 정보를 담는 클래스
class CityStay {
  final LatLng point;
  final String cityName;
  final String arrivalDate;
  final String departureDate;
  final int durationDays;
  final Key key;

  CityStay({
    required this.point,
    required this.cityName,
    required this.arrivalDate,
    required this.departureDate,
    required this.durationDays,
    required this.key,
  });
}


List<City> _parseCities(String jsonStr) {
  final List<dynamic> parsedJson = json.decode(jsonStr);
  return parsedJson.map((json) => City.fromJson(json)).toList();
}

class TripLeg {
  final LatLng originPoint;
  final LatLng destinationPoint;
  final String transportType;
  final String? transportIdentifier;
  final String? companyName;
  final String? date;
  final String? duration;
  final Airport? originAirport;
  final Airport? destinationAirport;
  final String? originCityName;
  final String? destinationCityName;
  final int sequence; // 🆕 추가


  bool isRoundTrip = false;
  int legIndex = 0;

  TripLeg({
    required this.originPoint,
    required this.destinationPoint,
    required this.transportType,
    this.transportIdentifier,
    this.companyName,
    this.date,
    this.duration,
    this.originAirport,
    this.destinationAirport,
    this.originCityName,
    this.destinationCityName,
    this.sequence = 0, // 🆕 기본값
  });

  Color get legColor {
    final colors = [
      Colors.cyan,
      Colors.orange,
      Colors.purple,
      Colors.green,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.teal,
    ];
    return colors[legIndex % colors.length];
  }
}

class TripMapScreen extends StatefulWidget {
  final AiSummary summary;
  final List<Map<String, dynamic>> matchedCitiesWithDetails;

  const TripMapScreen({
    super.key,
    required this.summary,
    required this.matchedCitiesWithDetails,
  });

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Map<String, List<Map<String, dynamic>>>? _cachedTransportData;


  // Google Maps API 키 추가
  final String _googleMapsApiKey = 'AIzaSyD0n7Lg_t4qdVElZITPc_gBNhifvwavblw';
  Map<String, List<Map<String, dynamic>>> _processedTransportData = {};
  bool _isTransportDataProcessed = false;


  bool _isCityDataLoading = false;
  bool _showCitiesAirportsIcons = true; // New state for Cities/Airports Icons switch
  bool _showCitiesAirportsNames = true; // New state for Cities/Airports Names switch
  bool _showTransportation = true; // New state for Transportation switch
  String? _selectedTransportId; // 선택된 교통편의 고유 ID
  double _markerIconSize = 1.0; // 아이콘 크기 배율 (0.5 ~ 2.0)
  double _markerNameSize = 1.0; // 이름 크기 배율 (0.5 ~ 2.0)
  double _transportationWidth = 1.0; // 경로 굵기 배율 (0.5 ~ 3.0)

  Widget _buildAnimationControlPanel() {
    return Positioned(
      top: 100, // AppBar 아래쪽
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 속도 조절 라벨
            const Text(
              'Speed:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 감속 버튼 (1시간당 1초)
            _buildAnimationButton(
              icon: Icons.speed,
              label: '0.5x',
              color: _animationSpeedMultiplier == 0.5 ? Colors.yellow : Colors.orange,
              onPressed: () {
                setState(() {
                  _animationSpeedMultiplier = 0.5;
                  _updateAnimationSpeed();
                });
              },
            ),
            // 기본속도 버튼 (1시간당 2초)
            _buildAnimationButton(
              icon: Icons.play_circle_outline,
              label: '1x',
              color: _animationSpeedMultiplier == 1.0 ? Colors.yellow : Colors.blue,
              onPressed: () {
                setState(() {
                  _animationSpeedMultiplier = 1.0;
                  _updateAnimationSpeed();
                });
              },
            ),
            // 가속 버튼 (1시간당 4초)
            _buildAnimationButton(
              icon: Icons.fast_forward,
              label: '2x',
              color: _animationSpeedMultiplier == 2.0 ? Colors.yellow : Colors.purple,
              onPressed: () {
                setState(() {
                  _animationSpeedMultiplier = 2.0;
                  _updateAnimationSpeed();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // 애니메이션 속도 조절 버튼 위젯 헬퍼
  Widget _buildAnimationButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10),
        ),
      ],
    );
  }

  Map<String, String> _transportLineStyles = {
    'flight': 'solid',
    'train': 'dotted',
    'bus': 'spring',
    'ferry': 'wavy',
    'car': 'shadow',
  };

  // 여기에 새 변수들 추가!
  bool _showLocationPanel = false;  // 위치 패널 표시 여부
  bool _showTransportPanel = false; // 이동수단 패널 표시 여부
  Set<String> _highlightedItems = {}; // 선택된 항목들

  // 애니메이션 관련 변수들
  Map<Key, AnimationController> _legAnimationControllers = {};
  Map<Key, Animation<double>> _legAnimations = {};
  bool _isAnimationPlaying = false;
  double _animationSpeedMultiplier = 1.0; // 기본 속도 (1시간당 2초)
  DateTime? _currentTripTime; // 🆕 이 줄을 추가하세요.



  bool _isEditMode = false; // 편집 모드 상태
  Set<Key> _selectedMarkerKeys = {}; // 선택된 마커의 키를 저장 (마커 데이터 자체를 참조)
  Set<Key> _selectedLegKeys = {}; // 선택된 경로의 키를 저장

  List<Marker> _currentLocationMarkers = [];
  List<EditableTripLeg> _currentTripLegs = []; // 이제 TripLeg 대신 EditableTripLeg 사용
  List<CityStay> _cityStays = []; // 도시 체류 정보 리스트
  // 지도 클릭으로 새로운 마커를 추가할 때 임시로 저장될 위치
  LatLng? _newMarkerLatLng;

  // 새로운 경로 추가를 위한 임시 상태 변수
  bool _isAddingNewLeg = false;
  LatLng? _newLegOriginLatLng;
  LatLng? _newLegDestinationLatLng;

  late Future<List<TripLeg>> _tripLegsFuture;
  late Future<List<Marker>> _locationMarkersFuture;


  @override
  void initState() {
    super.initState();

    _tripLegsFuture = _loadTripLegs().then((legs) {
      setState(() {
        // 기존 TripLegs를 EditableTripLegs로 변환하여 저장
        _currentTripLegs = legs.map((leg) => EditableTripLeg(
          key: UniqueKey(), // 각 기존 TripLeg에 UniqueKey 부여
          originPoint: leg.originPoint,
          destinationPoint: leg.destinationPoint,
          transportType: leg.transportType,
          transportIdentifier: leg.transportIdentifier,
          companyName: leg.companyName,
          date: leg.date,
          duration: leg.duration,
          originAirport: leg.originAirport,
          destinationAirport: leg.destinationAirport,
          originCityName: leg.originCityName,
          destinationCityName: leg.destinationCityName,
          customColor: leg.legColor, // 기존 legColor를 customColor로 사용
          // 기존 transportType에 따라 lineStyle 설정 (_buildPathLines 로직과 유사하게)
          lineStyle: _getInitialLineStyle(leg.transportType),
        )).toList();
      });
      return legs;
    });
    _locationMarkersFuture = _loadLocationMarkers().then((markers) {
      setState(() {
        _currentLocationMarkers = markers;
      });
      return markers;
    });

    _tripLegsFuture.then((_) {
      // 체류 정보 로드
      _loadCityStays();
      // 경로 로드가 완료된 후 애니메이션 컨트롤러 생성
      _createAnimationControllers();
    });

  }

  String _getInitialLineStyle(String transportType) {
    return _transportLineStyles[transportType] ?? 'solid';
  }


  Future<List<TripLeg>> _loadTripLegs() async {
    final List<TripLeg> tripLegs = [];
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);
    final cityProvider = Provider.of<CityProvider>(context, listen: false); // Use cityProvider

    // Create a map for quick lookup of city LatLng from matchedCitiesWithDetails
    // 이 맵에는 ai_summary_screen.dart에서 매칭된 도시 이름과 좌표가 포함됩니다.
    // AI가 제공한 이름과 Google Maps API를 통해 얻은 정확한 이름을 모두 포함할 수 있도록 합니다.
    final Map<String, LatLng> cityLatLngMap = {};
    for (var cityDetailMap in widget.matchedCitiesWithDetails) {
      final City city = cityDetailMap['city'] as City;
      // 매칭된 도시의 정확한 이름 (DB/Google Maps)
      cityLatLngMap[city.name.toLowerCase()] = LatLng(city.latitude, city.longitude);

      // AI가 제공한 원본 이름이 있다면, 그 이름도 맵에 추가하여 검색 가능하도록 합니다.
      // ai_summary_screen.dart에서 'aiProvidedName' 키를 통해 원본 AI 이름을 전달하도록 가정합니다.
      final String? aiProvidedName = cityDetailMap['aiProvidedName'] as String?;
      if (aiProvidedName != null && aiProvidedName.isNotEmpty) {
        // AI 제공 이름에서 괄호 안의 국가 코드 등을 제거한 cleaned 이름으로도 매핑 시도
        final aiCityMatch = RegExp(r'\s*\((.*?)\)$').firstMatch(aiProvidedName);
        String cleanedAiName = aiProvidedName;
        if (aiCityMatch != null) {
          cleanedAiName = aiProvidedName.replaceAll(aiCityMatch.group(0)!, '').trim();
        }
        cityLatLngMap[cleanedAiName.toLowerCase()] = LatLng(city.latitude, city.longitude);
        // AI가 제공한 이름 그대로도 매핑 (예: "Paris (FRA)")
        cityLatLngMap[aiProvidedName.toLowerCase()] = LatLng(city.latitude, city.longitude);
      }
    }
    Future<City?> _getCityInfoFromGoogleMaps(String cityNameForSearch, {String? countryIsoA2}) async {
      Map<String, String> params = {
        'address': cityNameForSearch,
        'key': _googleMapsApiKey,
      };
      if (countryIsoA2 != null && countryIsoA2.isNotEmpty && countryIsoA2 != 'N/A') {
        params['components'] = 'country:$countryIsoA2';
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        params,
      );

      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final decodedResponse = json.decode(utf8.decode(response.bodyBytes));
          if (decodedResponse['status'] == 'OK' && decodedResponse['results'].isNotEmpty) {
            final result = decodedResponse['results'][0];
            final location = result['geometry']['location'];
            final double lat = (location['lat'] as num).toDouble();
            final double lng = (location['lng'] as num).toDouble();
            String countryName = 'Unknown';
            String countryIsoA2Result = 'N/A';

            for (var component in result['address_components']) {
              if (component['types'].contains('country')) {
                countryName = component['long_name'];
                countryIsoA2Result = component['short_name'];
                break;
              }
            }
            String resolvedCityName = cityNameForSearch;
            for (var component in result['address_components']) {
              if (component['types'].contains('locality')) {
                resolvedCityName = component['long_name'];
                break;
              } else if (component['types'].contains('administrative_area_level_2')) {
                resolvedCityName = component['long_name'];
                break;
              } else if (component['types'].contains('airport')) {
                resolvedCityName = result['formatted_address'].split(',')[0].trim();
                if(resolvedCityName.toLowerCase().endsWith('airport')) {
                  resolvedCityName = resolvedCityName.replaceAll(RegExp(r'\sAirport$', caseSensitive: false), '').trim();
                }
                break;
              }
            }

            return City(
              name: resolvedCityName,
              country: countryName,
              countryIsoA2: countryIsoA2Result,
              continent: 'Unknown',
              population: 0,
              latitude: lat,
              longitude: lng,
              capitalStatus: CapitalStatus.none,
              annualVisitors: 0,
              avgTemp: 0.0,
              avgPrecipitation: 0,
              altitude: 0,
              gdpNominal: 0.0,
              gdpPpp: 0.0,
            );
          } else {
            return null;
          }
        } else {
          return null;
        }
      } catch (e) {
        return null;
      }
    }


    // Helper to get LatLng for a city name (공항 데이터베이스 검색 로직 제거)
    Future<LatLng?> _getCityCoordinates(String? cityName) async {
      if (cityName == null || cityName.isEmpty) {
        return null;
      }
      final normalizedCityName = cityName.toLowerCase();

      // 1. cityLatLngMap (matchedCitiesWithDetails에서 생성된 맵)에서 도시 이름으로 검색
      if (cityLatLngMap.containsKey(normalizedCityName)) {
        developer.log('Found city "$cityName" in cityLatLngMap.', name: 'TripMapScreen._getCityCoordinates');
        return cityLatLngMap[normalizedCityName];
      }

      // 2. cityProvider (통합된 cities.json) 에서 도시 이름으로 검색
      try {
        final foundCity = cityProvider.allCities.firstWhere(
              (c) => c.name.toLowerCase() == normalizedCityName,
        );
        developer.log('Found city "$cityName" in cityProvider.', name: 'TripMapScreen._getCityCoordinates');
        return LatLng(foundCity.latitude, foundCity.longitude);
      } catch (e) {
        developer.log('City "$cityName" not found in DB, trying Google Maps...', name: 'TripMapScreen._getCityCoordinates');
      }

      // 3. Google Maps API에서 검색
      try {
        final googleCity = await _getCityInfoFromGoogleMaps(cityName);
        if (googleCity != null) {
          developer.log('Found city "$cityName" via Google Maps API.', name: 'TripMapScreen._getCityCoordinates');
          return LatLng(googleCity.latitude, googleCity.longitude);
        }
      } catch (e) {
        developer.log('Google Maps API failed for "$cityName": $e', name: 'TripMapScreen._getCityCoordinates');
      }

      return null;
    }


    int currentLegIndex = 0; // TripLeg 인덱스 초기화

    // Process Flights
    final List<FlightDetail> allFlights = widget.summary.flights.expand((airlineLog) => airlineLog.flights).toList();
    final Set<String> transitAirportsFromSummary = widget.summary.transitAirports.toSet(); // 경유 공항 목록 가져오기

    for (int i = 0; i < allFlights.length; i++) {
      final flightDetail = allFlights[i];
      Airport? originAirport;
      Airport? destinationAirport;
      LatLng? originCityPoint;
      LatLng? destinationCityPoint;


      // 1. IATA 코드로 공항 찾기
      if (_isAirportCode(flightDetail.origin)) {
        try {
          originAirport = airportProvider.allAirports.firstWhere(
                (a) => a.iataCode.toUpperCase() == flightDetail.origin.toUpperCase(),
          );
        } catch (e) {
          developer.log('Origin airport IATA ${flightDetail.origin} not found: $e', name: 'TripMapScreen._loadTripLegs');
        }
      }
      if (_isAirportCode(flightDetail.destination)) {
        try {
          destinationAirport = airportProvider.allAirports.firstWhere(
                (a) => a.iataCode.toUpperCase() == flightDetail.destination.toUpperCase(),
          );
        } catch (e) {
          developer.log('Destination airport IATA ${flightDetail.destination} not found: $e', name: 'TripMapScreen._loadTripLegs');
        }
      }

      // 2. 공항을 찾지 못했다면 도시 이름으로 좌표 찾기
      if (originAirport == null) {
        originCityPoint = await _getCityCoordinates(flightDetail.origin);
        if (originCityPoint == null) {
          developer.log('Could not resolve origin city/airport for flight: ${flightDetail.origin}', name: 'TripMapScreen._loadTripLegs');
          continue; // 출발지 또는 목적지 불분명 시 건너뛰기
        }
      }
      if (destinationAirport == null) {
        destinationCityPoint = await _getCityCoordinates(flightDetail.destination);
        if (destinationCityPoint == null) {
          developer.log('Could not resolve destination city/airport for flight: ${flightDetail.destination}', name: 'TripMapScreen._loadTripLegs');
          continue; // 출발지 또는 목적지 불분명 시 건너뛰기
        }
      }


      LatLng finalOriginPoint = originAirport != null ? LatLng(originAirport.latitude, originAirport.longitude) : originCityPoint!;
      LatLng finalDestinationPoint = destinationAirport != null ? LatLng(destinationAirport.latitude, destinationAirport.longitude) : destinationCityPoint!;

      // AI Summary의 duration이 유효한지 확인하는 함수
      bool _isValidDuration(String? duration) {
        if (duration == null || duration.isEmpty) return false;
        final lowerDuration = duration.toLowerCase();
        return !['unknown', 'n/a', 'null'].contains(lowerDuration);
      }

// 교통수단이 현재 애니메이션 중인지 확인하는 함수
      bool _isTransportItemAnimating(Map<String, dynamic> item) {
        for (final leg in _currentTripLegs) {
          if (leg.transportType != item['transportType']) continue;

          final itemTitle = item['title'] as String;
          final legTitle = '${leg.originCityName ?? ''} → ${leg.destinationCityName ?? ''}';

          if (itemTitle == legTitle) {
            final controller = _legAnimationControllers[leg.key];
            return controller != null && controller.isAnimating;
          }
        }
        return false;
      }

// 교통수단의 애니메이션 진행률 가져오는 함수
      double? _getTransportItemProgress(Map<String, dynamic> item) {
        for (final leg in _currentTripLegs) {
          if (leg.transportType != item['transportType']) continue;

          final itemTitle = item['title'] as String;
          final legTitle = '${leg.originCityName ?? ''} → ${leg.destinationCityName ?? ''}';

          if (itemTitle == legTitle) {
            final animation = _legAnimations[leg.key];
            return animation?.value;
          }
        }
        return null;
      }

// Flight duration 결정 로직
      // AI Summary의 duration을 그대로 사용
      String finalFlightDuration = flightDetail.duration ?? 'Unknown';

      TripLeg currentLeg = TripLeg(
        originPoint: finalOriginPoint,
        destinationPoint: finalDestinationPoint,
        transportType: 'flight',
        transportIdentifier: flightDetail.flightNumber,
        companyName: widget.summary.flights.firstWhere((log) => log.flights.contains(flightDetail)).airlineName,
        date: flightDetail.flightDate,
        duration: finalFlightDuration, // 수정된 부분
        originAirport: originAirport,
        destinationAirport: destinationAirport,
        originCityName: flightDetail.origin,
        destinationCityName: flightDetail.destination,
        sequence: flightDetail.sequence ?? 0, // 🆕 추가

      );

      // 경유 항공편 처리 로직 (이전과 동일)
      if (originAirport != null && destinationAirport != null) { // IATA 코드로 찾은 경우에만 경유 로직 적용
        if (transitAirportsFromSummary.contains(currentLeg.originAirport!.iataCode) ||
            transitAirportsFromSummary.contains(currentLeg.destinationAirport!.iataCode)
        ) {
          if (i > 0 && tripLegs.last.transportType == 'flight' &&
              tripLegs.last.destinationAirport?.iataCode == currentLeg.originAirport?.iataCode &&
              transitAirportsFromSummary.contains(currentLeg.originAirport!.iataCode)) {
            currentLeg.legIndex = tripLegs.last.legIndex;
          } else {
            currentLegIndex++;
            currentLeg.legIndex = currentLegIndex;
          }
        } else {
          currentLegIndex++;
          currentLeg.legIndex = currentLegIndex;
        }
      } else { // IATA 코드가 없어 도시 이름으로 매칭된 항공편은 항상 새로운 색상 그룹
        currentLegIndex++;
        currentLeg.legIndex = currentLegIndex;
      }
      tripLegs.add(currentLeg);
    }
    print('🔍 ===== AI Summary 원본 데이터 확인 =====');
    for (final trainLog in widget.summary.trains) {
      print('🚆 Train: ${trainLog.origin} → ${trainLog.destination}, Date: ${trainLog.date}, Sequence: ${trainLog.sequence}');
    }
    for (final airlineLog in widget.summary.flights) {
      for (final flight in airlineLog.flights) {
        print('✈️ Flight: ${flight.origin} → ${flight.destination}, Date: ${flight.flightDate}, Sequence: ${flight.sequence}');
      }
    }

    for (final bus in widget.summary.buses) {
      print('🚌 Bus: ${bus.origin} → ${bus.destination}, Date: ${bus.date}, Sequence: ${bus.sequence}');
    }

    for (final ferry in widget.summary.ferries) {
      print('⛴️ Ferry: ${ferry.origin} → ${ferry.destination}, Date: ${ferry.date}, Sequence: ${ferry.sequence}');
    }

    for (final car in widget.summary.cars) {
      print('🚗 Car: ${car.origin} → ${car.destination}, Date: ${car.date}, Sequence: ${car.sequence}');
    }


    // Process Trains
    for (final trainLog in widget.summary.trains) {
      // trainLog.origin, trainLog.destination이 String? 타입이므로, null 체크 후 함수 호출
      if (trainLog.origin == null || trainLog.destination == null) {
        developer.log('Skipping train log due to null origin or destination: ${trainLog.origin} -> ${trainLog.destination}', name: 'TripMapScreen._loadTripLegs');
        continue;
      }
      LatLng? originPoint = await _getCityCoordinates(trainLog.origin); // 도시 좌표 검색 함수 사용
      LatLng? destinationPoint = await _getCityCoordinates(trainLog.destination); // 도시 좌표 검색 함수 사용

      if (originPoint != null && destinationPoint != null) {
        String finalTrainDuration = trainLog.duration ?? 'Unknown';
        tripLegs.add(TripLeg(
          originPoint: originPoint,
          destinationPoint: destinationPoint,
          transportType: 'train',
          companyName: trainLog.trainCompany,
          date: trainLog.date,
          duration: finalTrainDuration,
          originCityName: trainLog.origin,
          destinationCityName: trainLog.destination,
          sequence: trainLog.sequence ?? 0, // 🆕 추가


        )..legIndex = currentLegIndex++);
      } else {
        developer.log('Skipping train log due to missing coordinates for: ${trainLog.origin} -> ${trainLog.destination}', name: 'TripMapScreen._loadTripLegs');
      }
    }

    // Process Buses
    for (final busLog in widget.summary.buses) {
      if (busLog.origin == null || busLog.destination == null) {
        developer.log('Skipping bus log due to null origin or destination: ${busLog.origin} -> ${busLog.destination}', name: 'TripMapScreen._loadTripLegs');
        continue;
      }
      LatLng? originPoint = await _getCityCoordinates(busLog.origin); // 도시 좌표 검색 함수 사용
      LatLng? destinationPoint = await _getCityCoordinates(busLog.destination); // 도시 좌표 검색 함수 사용

      if (originPoint != null && destinationPoint != null) {
        String finalBusDuration = busLog.duration ?? 'Unknown';
        tripLegs.add(TripLeg(
          originPoint: originPoint,
          destinationPoint: destinationPoint,
          transportType: 'bus',
          companyName: busLog.busCompany,
          date: busLog.date,
          duration: finalBusDuration,  // ← 이렇게 바뀜
          originCityName: busLog.origin,
          destinationCityName: busLog.destination,
          sequence: busLog.sequence ?? 0, // 🆕 추가

        )..legIndex = currentLegIndex++);
      } else {
        developer.log('Skipping bus log due to missing coordinates for: ${busLog.origin} -> ${busLog.destination}', name: 'TripMapScreen._loadTripLegs');
      }
    }

    // Process Ferries
    for (final ferryLog in widget.summary.ferries) {
      if (ferryLog.origin == null || ferryLog.destination == null) {
        developer.log('Skipping ferry log due to null origin or destination: ${ferryLog.origin} -> ${ferryLog.destination}', name: 'TripMapScreen._loadTripLegs');
        continue;
      }
      LatLng? originPoint = await _getCityCoordinates(ferryLog.origin); // 도시 좌표 검색 함수 사용
      LatLng? destinationPoint = await _getCityCoordinates(ferryLog.destination); // 도시 좌표 검색 함수 사용

      if (originPoint != null && destinationPoint != null) {
        String finalFerryDuration = ferryLog.duration ?? 'Unknown';

        tripLegs.add(TripLeg(
          originPoint: originPoint,
          destinationPoint: destinationPoint,
          transportType: 'ferry',
          companyName: ferryLog.ferryName,
          date: ferryLog.date,
          duration: finalFerryDuration,
          originCityName: ferryLog.origin,
          destinationCityName: ferryLog.destination,
          sequence: ferryLog.sequence ?? 0, // 🆕 추가

        )..legIndex = currentLegIndex++);
      } else {
        developer.log('Skipping ferry log due to missing coordinates for: ${ferryLog.origin} -> ${ferryLog.destination}', name: 'TripMapScreen._loadTripLegs');
      }
    }


    // Process Cars
    for (final carLog in widget.summary.cars) {
      if (carLog.origin == null || carLog.destination == null) {
        developer.log('Skipping car log due to null origin or destination: ${carLog.origin} -> ${carLog.destination}', name: 'TripMapScreen._loadTripLegs');
        continue;
      }
      LatLng? originPoint = await _getCityCoordinates(carLog.origin); // 도시 좌표 검색 함수 사용
      LatLng? destinationPoint = await _getCityCoordinates(carLog.destination); // 도시 좌표 검색 함수 사용

      if (originPoint != null && destinationPoint != null) {
        String finalCarDuration = carLog.duration ?? 'Unknown';
        tripLegs.add(TripLeg(
          originPoint: originPoint,
          destinationPoint: destinationPoint,
          transportType: 'car',
          companyName: carLog.carType,
          date: carLog.date,
          duration: finalCarDuration,          originCityName: carLog.origin,
          destinationCityName: carLog.destination,
          sequence: carLog.sequence ?? 0, // 🆕 추가

        )..legIndex = currentLegIndex++);
      } else {
        developer.log('Skipping car log due to missing coordinates for: ${carLog.origin} -> ${carLog.destination}', name: 'TripMapScreen._loadTripLegs');
      }
    }
    List<TripLeg> _reorderSequenceNumbers(List<TripLeg> tripLegs) {
      developer.log('🔧 Starting sequence reordering for ${tripLegs.length} legs', name: 'TripMapScreen._reorderSequenceNumbers');

      // 원본 sequence 상태 로깅
      for (final leg in tripLegs) {
        developer.log('📋 ${leg.transportType}: ${leg.originCityName} → ${leg.destinationCityName}, Date: ${leg.date}, Original Sequence: ${leg.sequence}',
            name: 'TripMapScreen._reorderSequenceNumbers');
      }

      // 날짜별로 그룹화
      Map<String, List<TripLeg>> legsByDate = {};

      for (final leg in tripLegs) {
        final dateKey = leg.date ?? 'Unknown';
        if (!legsByDate.containsKey(dateKey)) {
          legsByDate[dateKey] = [];
        }
        legsByDate[dateKey]!.add(leg);
      }

      List<TripLeg> reorderedLegs = [];

      // 날짜순으로 정렬된 키 가져오기
      final sortedDateKeys = legsByDate.keys.toList()
        ..sort((a, b) {
          if (a == 'Unknown' && b == 'Unknown') return 0;
          if (a == 'Unknown') return 1;
          if (b == 'Unknown') return -1;
          return a.compareTo(b);
        });

      for (final dateKey in sortedDateKeys) {
        final legs = legsByDate[dateKey]!;

        // 기존 sequence 기준으로 정렬
        legs.sort((a, b) => a.sequence.compareTo(b.sequence));

        developer.log('📅 Date $dateKey: Original sequences: ${legs.map((l) => l.sequence).join(", ")}',
            name: 'TripMapScreen._reorderSequenceNumbers');

        // 빈 번호 찾기 및 연속된 sequence 번호로 재할당
        for (int i = 0; i < legs.length; i++) {
          final leg = legs[i];
          final newSequence = i + 1; // 1부터 시작하는 연속 번호

          // 새로운 TripLeg 인스턴스 생성 (sequence만 변경)
          final reorderedLeg = TripLeg(
            originPoint: leg.originPoint,
            destinationPoint: leg.destinationPoint,
            transportType: leg.transportType,
            transportIdentifier: leg.transportIdentifier,
            companyName: leg.companyName,
            date: leg.date,
            duration: leg.duration,
            originAirport: leg.originAirport,
            destinationAirport: leg.destinationAirport,
            originCityName: leg.originCityName,
            destinationCityName: leg.destinationCityName,
            sequence: newSequence, // 🆕 새로운 연속 번호
          );

          // 기존 속성들 복사
          reorderedLeg.isRoundTrip = leg.isRoundTrip;
          reorderedLeg.legIndex = leg.legIndex;

          reorderedLegs.add(reorderedLeg);

          developer.log('🔄 ${leg.transportType}: ${leg.originCityName} → ${leg.destinationCityName}, Sequence: ${leg.sequence} → $newSequence',
              name: 'TripMapScreen._reorderSequenceNumbers');
        }

        developer.log('📅 Date $dateKey: New sequences: ${List.generate(legs.length, (index) => index + 1).join(", ")}',
            name: 'TripMapScreen._reorderSequenceNumbers');
      }

      developer.log('✅ Sequence reordering completed. Total legs: ${reorderedLegs.length}',
          name: 'TripMapScreen._reorderSequenceNumbers');

      return reorderedLegs;
    }


    // 모든 교통수단 처리 후 sequence 재정렬 실행
    final reorderedTripLegs = _reorderSequenceNumbers(tripLegs);

    developer.log('✅ Loaded ${reorderedTripLegs.length} trip legs with reordered sequences.', name: 'TripMapScreen._loadTripLegs');
    return reorderedTripLegs;
  }


  Future<List<Marker>> _loadLocationMarkers() async {
    final List<Marker> locationMarkers = [];
    Set<Map<String, dynamic>> addedLocationDetails = {}; // LatLng와 markerChar를 함께 저장

    final String? overallStartLocationName = widget.summary.startLocation;
    final String? overallEndLocationName = widget.summary.endLocation;
    final Set<String> transitAirportsFromSummary = widget.summary.transitAirports.toSet();

    developer.log('Overall Start Location from Summary: $overallStartLocationName', name: 'TripMapScreen._loadLocationMarkers');
    developer.log('Overall End Location from Summary: $overallEndLocationName', name: 'TripMapScreen._loadLocationMarkers');
    developer.log('Transit Airports from Summary: $transitAirportsFromSummary', name: 'TripMapScreen._loadLocationMarkers');

    LatLng? startPoint;
    String? startDisplayName;
    LatLng? endPoint;
    String? endDisplayName;

    final airportProvider = Provider.of<AirportProvider>(context, listen: false); // AirportProvider로 변경
    final cityProvider = Provider.of<CityProvider>(context, listen: false);
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);

    // Overall Start Location Resolve
    if (overallStartLocationName != null && overallStartLocationName.toLowerCase() != 'unknown') {
      if (_isAirportCode(overallStartLocationName)) {
        try { // try-catch로 firstWhereOrNull 대체
          final airport = airportProvider.allAirports.firstWhere(
                  (a) => a.iataCode.toLowerCase() == overallStartLocationName.toLowerCase());
          if (airport != null) {
            startPoint = LatLng(airport.latitude, airport.longitude);
            startDisplayName = airport.iataCode;
            developer.log('Resolved Start Location (Airport): ${airport.iataCode}', name: 'TripMapScreen._loadLocationMarkers');
          }
        } catch (e) {
          developer.log('Start airport IATA ${overallStartLocationName} not found: $e', name: 'TripMapScreen._loadLocationMarkers');
        }
      }
      if (startPoint == null) {
        City? city = cityProvider.allCities.firstWhereOrNull(
                (c) => c.name.toLowerCase() == overallStartLocationName.toLowerCase());

        if (city != null) {
          startPoint = LatLng(city.latitude, city.longitude);
          startDisplayName = city.name;
          developer.log('Resolved Start Location (City): ${city.name}', name: 'TripMapScreen._loadLocationMarkers');
        }
      }
    }

    // Overall End Location Resolve
    if (overallEndLocationName != null && overallEndLocationName.toLowerCase() != 'unknown') {
      if (_isAirportCode(overallEndLocationName)) {
        try { // try-catch로 firstWhereOrNull 대체
          final airport = airportProvider.allAirports.firstWhere(
                  (a) => a.iataCode.toLowerCase() == overallEndLocationName.toLowerCase());
          if (airport != null) {
            endPoint = LatLng(airport.latitude, airport.longitude);
            endDisplayName = airport.iataCode;
            developer.log('Resolved End Location (Airport): ${airport.iataCode}', name: 'TripMapScreen._loadLocationMarkers');
          }
        } catch (e) {
          developer.log('End airport IATA ${overallEndLocationName} not found: $e', name: 'TripMapScreen._loadLocationMarkers');
        }
      }
      if (endPoint == null) {
        City? city = cityProvider.allCities.firstWhereOrNull(
                (c) => c.name.toLowerCase() == overallEndLocationName.toLowerCase());

        if (city != null) {
          endPoint = LatLng(city.latitude, city.longitude);
          endDisplayName = city.name;
          developer.log('Resolved End Location (City): ${city.name}', name: 'TripMapScreen._loadLocationMarkers');
        }
      }
    }

    // 일반 도시 마커 추가
    for (final cityDetailMap in widget.matchedCitiesWithDetails) {
      final City city = cityDetailMap['city'] as City;
      final String? duration = cityDetailMap['duration'] as String?;
      // LatLng와 markerChar를 결합한 고유 키 생성
      final Map<String, dynamic> locationKey = {
        'point': LatLng(city.latitude, city.longitude),
        'char': null // 일반 도시는 특정 마커 문자 없음
      };

      // 해당 도시가 경유 공항이거나 시작/종료 지점이 아니라면 일반 도시 마커를 추가
      final bool isTransitAirport = transitAirportsFromSummary.contains(city.name.toUpperCase()) ||
          transitAirportsFromSummary.contains(city.countryIsoA2.toUpperCase());
      final bool isStartOrEndPoint = (startPoint != null && city.latitude == startPoint.latitude && city.longitude == startPoint.longitude) ||
          (endPoint != null && city.latitude == endPoint.latitude && city.longitude == endPoint.longitude);

      if (!isTransitAirport && !isStartOrEndPoint && !addedLocationDetails.contains(locationKey)) {
        addedLocationDetails.add(locationKey);
        final String durationToDisplay = _formatDurationDays(duration);
        locationMarkers.add(
          Marker(
            point: LatLng(city.latitude, city.longitude),
            width: 120,
            height: 120,
            // _MarkerData를 마커의 `key`로 저장하여 나중에 데이터를 쉽게 재구성할 수 있도록 합니다.
            key: ValueKey<_MarkerData>( _MarkerData(
              point: LatLng(city.latitude, city.longitude),
              markerChar: null,
              duration: durationToDisplay,
              cityDisplayName: city.name,
              markerColor: Colors.red[600]!, // 기본 색상 설정
              countryIsoA2: city.countryIsoA2, // 국가 코드 추가
            )),
            child: _buildStayCityMarker(
                null,
                LatLng(city.latitude, city.longitude),
                durationToDisplay,
                city.name,
                _showCitiesAirportsIcons,
                _showCitiesAirportsNames,
                false,
                Colors.red[600]!, // 마커 색상 전달
                city.countryIsoA2 // 국기 표시를 위한 국가 코드
            ),
          ),
        );
      } else if (isTransitAirport) {
        developer.log('Skipping regular city marker for ${city.name} (${city.countryIsoA2}) as it is identified as a transit airport.', name: 'TripMapScreen._loadLocationMarkers');
      } else if (isStartOrEndPoint) {
        developer.log('Skipping regular city marker for ${city.name} (${city.countryIsoA2}) as it is a start/end point.', name: 'TripMapScreen._loadLocationMarkers');
      }
    }

    // D, A, H 마커를 별도로 추가
    if (startPoint != null && endPoint != null &&
        startPoint.latitude == endPoint.latitude && startPoint.longitude == endPoint.longitude) {
      final Map<String, dynamic> homeKey = {'point': startPoint, 'char': 'H'};
      if (!addedLocationDetails.contains(homeKey)) {
        addedLocationDetails.add(homeKey);
        locationMarkers.add(
          Marker(
            point: startPoint,
            width: 120,
            height: 120,
            key: ValueKey<_MarkerData>( _MarkerData(
              point: startPoint,
              markerChar: 'H',
              duration: '0',
              cityDisplayName: startDisplayName ?? overallStartLocationName!,
              markerColor: Colors.deepOrange[600]!, // H 마커 색상
              countryIsoA2: null,
            )),
            child: _buildStayCityMarker(
                'H',
                startPoint,
                '0',
                startDisplayName ?? overallStartLocationName!,
                _showCitiesAirportsIcons,
                _showCitiesAirportsNames,
                false,
                Colors.deepOrange[600]!, // 마커 색상 전달
                null // H 마커는 국기 대신 문자 표시
            ),
          ),
        );
        developer.log('Added HOME (H) marker for ${startDisplayName ?? overallStartLocationName!}.', name: 'TripMapScreen._loadLocationMarkers');
      }
    } else {
      if (startPoint != null) {
        final Map<String, dynamic> startKey = {'point': startPoint, 'char': 'D'};
        if (!addedLocationDetails.contains(startKey)) {
          addedLocationDetails.add(startKey);
          locationMarkers.add(
            Marker(
              point: startPoint,
              width: 120,
              height: 120,
              key: ValueKey<_MarkerData>( _MarkerData(
                point: startPoint,
                markerChar: 'D',
                duration: '0',
                cityDisplayName: startDisplayName ?? overallStartLocationName!,
                markerColor: Colors.blue[600]!, // D 마커 색상
                countryIsoA2: null,
              )),
              child: _buildStayCityMarker(
                  'D',
                  startPoint,
                  '0',
                  startDisplayName ?? overallStartLocationName!,
                  _showCitiesAirportsIcons,
                  _showCitiesAirportsNames,
                  false,
                  Colors.blue[600]!, // 마커 색상 전달
                  null // D 마커는 국기 대신 문자 표시
              ),
            ),
          );
          developer.log('Added DEPARTURE (D) marker for ${startDisplayName ?? overallStartLocationName!}.', name: 'TripMapScreen._loadLocationMarkers');
        }
      }
      if (endPoint != null) {
        final Map<String, dynamic> endKey = {'point': endPoint, 'char': 'A'};
        if (!addedLocationDetails.contains(endKey)) {
          addedLocationDetails.add(endKey);
          locationMarkers.add(
            Marker(
              point: endPoint,
              width: 120,
              height: 120,
              key: ValueKey<_MarkerData>( _MarkerData(
                point: endPoint,
                markerChar: 'A',
                duration: '0',
                cityDisplayName: endDisplayName ?? overallEndLocationName!,
                markerColor: Colors.purple[600]!, // A 마커 색상
                countryIsoA2: null,
              )),
              child: _buildStayCityMarker(
                  'A',
                  endPoint,
                  '0',
                  endDisplayName ?? overallEndLocationName!,
                  _showCitiesAirportsIcons,
                  _showCitiesAirportsNames,
                  false,
                  Colors.purple[600]!, // 마커 색상 전달
                  null // A 마커는 국기 대신 문자 표시
              ),
            ),
          );
          developer.log('Added ARRIVAL (A) marker for ${endDisplayName ?? overallEndLocationName!}.', name: 'TripMapScreen._loadLocationMarkers');
        }
      }
    }

    // 경유 공항 마커 추가
    for (final transitAirportIata in transitAirportsFromSummary) {
      final airport = airportProvider.allAirports.firstWhereOrNull(
              (a) => a.iataCode.toUpperCase() == transitAirportIata.toUpperCase()
      );
      if (airport != null) {
        final Map<String, dynamic> transitKey = {'point': LatLng(airport.latitude, airport.longitude), 'char': 'T'};
        // D, A, H 마커와 겹치지 않도록 추가
        if (!addedLocationDetails.contains(transitKey)) {
          addedLocationDetails.add(transitKey);
          locationMarkers.add(
            Marker(
              point: LatLng(airport.latitude, airport.longitude),
              width: 120,
              height: 120,
              key: ValueKey<_MarkerData>( _MarkerData(
                point: LatLng(airport.latitude, airport.longitude),
                markerChar: 'T',
                duration: '0',
                cityDisplayName: airport.iataCode,
                markerColor: Colors.grey[600]!, // T 마커 색상
                countryIsoA2: null,
              )),
              child: _buildStayCityMarker(
                  'T',
                  LatLng(airport.latitude, airport.longitude),
                  '0',
                  airport.iataCode,
                  _showCitiesAirportsIcons,
                  _showCitiesAirportsNames,
                  false,
                  Colors.grey[600]!, // 마커 색상 전달
                  null // T 마커는 국기 대신 문자 표시
              ),
            ),
          );
          developer.log('Added TRANSIT (T) marker for ${airport.iataCode}.', name: 'TripMapScreen._loadLocationMarkers');
        } else {
          developer.log('Skipping TRANSIT (T) marker for ${airport.iataCode} as another special marker already exists at this location.', name: 'TripMapScreen._loadLocationMarkers');
        }
      }
    }

    return locationMarkers;
  }

  // 위치 문자열(도시 이름 또는 IATA 코드)을 City 객체로 변환하는 헬퍼 함수
  Future<City?> _resolveLocationToCity(String locationString) async {
    if (!mounted || locationString.isEmpty || locationString.toLowerCase() == 'unknown') {
      return null;
    }
    final normalizedLocation = locationString.toLowerCase();

    final cityProvider = Provider.of<CityProvider>(context, listen: false);
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);

    // 1. CityProvider (통합된 cities.json)에서 도시 이름으로 찾기
    City? city = cityProvider.allCities.firstWhereOrNull(
            (c) => c.name.toLowerCase() == normalizedLocation
    );
    if (city != null) {
      developer.log('Resolved "$locationString" to city entry: ${city.name}', name: 'TripMapScreen._resolveLocationToCity');
      return city;
    }

    // 2. Airport Provider에서 IATA 코드로 찾기
    if (_isAirportCode(locationString)) {
      final Airport? airport = airportProvider.allAirports.firstWhereOrNull(
              (a) => a.iataCode.toLowerCase() == normalizedLocation
      );
      if (airport != null) {
        // 공항을 가상의 City 객체로 변환 (공항 이름 또는 해당 도시 이름으로)
        final airportCityName = airport.name.replaceAll(' International Airport', '').trim(); // municipality 필드는 원래 없었으므로 name에서 파싱
        final countryName = countryProvider.allCountries.firstWhereOrNull(
                (c) => c.isoA2.toLowerCase() == airport.country.toLowerCase() // 원래 country 필드 사용
        )?.name ?? 'Unknown';

        developer.log('Resolved "$locationString" to Airport entry: ${airport.name}', name: 'TripMapScreen._resolveLocationToCity');
        return City(
          name: airportCityName, country: countryName, countryIsoA2: airport.country, // 원래 country 필드 사용
          latitude: airport.latitude, longitude: airport.longitude,
          continent: 'Unknown', population: 0, capitalStatus: CapitalStatus.none,
          annualVisitors: 0, avgTemp: 0.0, avgPrecipitation: 0, altitude: 0, gdpNominal: 0.0, gdpPpp: 0.0,
        );
      }
    }
    developer.log('Could not resolve "$locationString" to any known City or Airport.', name: 'TripMapScreen._resolveLocationToCity');
    return null;
  }

  bool _isAirportCode(String location) {
    return location.length == 3 && location.toUpperCase() == location; // 3글자 대문자 문자열이면 공항 코드로 간주
  }
  bool _isValidDuration(String? duration) {
    if (duration == null || duration.isEmpty) return false;
    final lowerDuration = duration.toLowerCase();
    return !['unknown', 'n/a', 'null'].contains(lowerDuration);
  }
  bool _isTransportItemAnimating(Map<String, dynamic> item) {
    for (final leg in _currentTripLegs) {
      if (leg.transportType != item['transportType']) continue;

      final itemTitle = item['title'] as String;
      final legTitle = '${leg.originCityName ?? ''} → ${leg.destinationCityName ?? ''}';

      if (itemTitle == legTitle) {
        final controller = _legAnimationControllers[leg.key];
        return controller != null && controller.isAnimating;
      }
    }
    return false;
  }

  // 교통수단의 애니메이션 진행률 가져오는 함수
  double? _getTransportItemProgress(Map<String, dynamic> item) {
    // _currentTripLegs에서 매칭되는 경로 찾기
    for (final leg in _currentTripLegs) {
      // 교통수단 타입이 같은지 확인
      if (leg.transportType != item['transportType']) continue;

      // 출발지와 도착지 이름으로 매칭
      final itemTitle = item['title'] as String;
      final legTitle = '${leg.originCityName ?? ''} → ${leg.destinationCityName ?? ''}';

      if (itemTitle == legTitle) {
        final animation = _legAnimations[leg.key];
        return animation?.value;
      }
    }
    return null;
  }


  // 도시 체류 정보 로드
  void _loadCityStays() {
    _cityStays.clear();

    for (final cityDetailMap in widget.matchedCitiesWithDetails) {
      final City city = cityDetailMap['city'] as City;
      final String? arrivalDate = cityDetailMap['arrivalDate'] as String?;
      final String? departureDate = cityDetailMap['departureDate'] as String?;
      final String? duration = cityDetailMap['duration'] as String?;

      if (arrivalDate != null && arrivalDate != 'Unknown' &&
          departureDate != null && departureDate != 'Unknown') {

        int durationDays = 0;
        if (duration != null) {
          final match = RegExp(r'(\d+)').firstMatch(duration);
          if (match != null) {
            durationDays = int.tryParse(match.group(1)!) ?? 0;
          }
        }

        _cityStays.add(CityStay(
          point: LatLng(city.latitude, city.longitude),
          cityName: city.name,
          arrivalDate: arrivalDate,
          departureDate: departureDate,
          durationDays: durationDays,
          key: UniqueKey(),
        ));
      }
    }

    developer.log('Loaded ${_cityStays.length} city stays', name: 'TripMapScreen._loadCityStays');
  }

  @override
  void dispose() {
    // 애니메이션 컨트롤러들 정리
    for (var controller in _legAnimationControllers.values) {
      controller.dispose();
    }
    _legAnimationControllers.clear();
    _legAnimations.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Marker>>(
      future: _locationMarkersFuture, // 마커 로딩 퓨처를 감시
      builder: (context, locationMarkersSnapshot) {
        if (locationMarkersSnapshot.connectionState == ConnectionState.waiting) {
          // 마커 로딩 중이면 로딩 인디케이터 표시
          return Scaffold(
            appBar: AppBar(
              title: const Text('여행 지도 로딩 중...'),
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (locationMarkersSnapshot.hasError) {
          // 에러 발생 시 에러 메시지 표시
          developer.log("Error loading location markers: ${locationMarkersSnapshot.error}", name: 'TripMapScreen.build');
          return Scaffold(
            appBar: AppBar(
              title: const Text('여행 지도'),
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Text('위치 마커 로딩 중 오류 발생: ${locationMarkersSnapshot.error}'),
            ),
          );
        } else if (locationMarkersSnapshot.hasData) {
          // 마커 로딩 완료 및 데이터가 있을 경우 지도 표시
          // final List<Marker> locationMarkers = locationMarkersSnapshot.data!; // 이미 _currentLocationMarkers에 저장됨

          return Scaffold(
            // lib/screens/trip_map_screen.dart

// ... (생략) ...

            appBar: AppBar(
              backgroundColor: Colors.blueGrey[900],
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
              title: Row( // 나머지 버튼들을 이 Row 안에 넣습니다.
                mainAxisAlignment: MainAxisAlignment.spaceAround, // 버튼 간격을 균등하게!
                children: [
                  // Locations 버튼
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showLocationPanel = !_showLocationPanel;
                        _showTransportPanel = false; // 다른 패널은 닫기
                      });
                    },
                    icon: Icon(
                      Icons.location_city,
                      color: _showLocationPanel ? Colors.yellow : Colors.white,
                    ),
                    tooltip: 'Locations',
                  ),
                  // Transportation 버튼
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showTransportPanel = !_showTransportPanel;
                        _showLocationPanel = false; // 다른 패널은 닫기
                      });
                    },
                    icon: Icon(
                      Icons.directions,
                      color: _showTransportPanel ? Colors.yellow : Colors.white,
                    ),
                    tooltip: 'Transportation',
                  ),
                  // Edit Mode 버튼
                  IconButton(
                    icon: Icon(
                      _isEditMode ? Icons.edit_off : Icons.edit,
                      color: _isEditMode ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isEditMode = !_isEditMode;
                        if (!_isEditMode) {
                          _selectedMarkerKeys.clear();
                          _selectedLegKeys.clear();
                          _newMarkerLatLng = null;
                          _isAddingNewLeg = false;
                          _newLegOriginLatLng = null;
                          _newLegDestinationLatLng = null;
                        }
                      });
                    },
                    tooltip: 'Edit Mode',
                  ),
                  // 재생/일시정지 버튼
                  IconButton(
                    icon: Icon(
                      _isAnimationPlaying ? Icons.pause : Icons.play_arrow,
                      color: _isAnimationPlaying ? Colors.green : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_isAnimationPlaying) {
                          for (var controller in _legAnimationControllers.values) {
                            controller.stop();
                          }
                          _isAnimationPlaying = false;
                        } else {
                          _startAnimation();
                        }
                      });
                    },
                    tooltip: 'Play/Pause Animation',
                  ),
                  // 정지 버튼
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        for (var controller in _legAnimationControllers.values) {
                          controller.stop();
                          controller.reset();
                        }
                        _isAnimationPlaying = false;
                      });
                    },
                    tooltip: 'Stop Animation',
                  ),
                  // 설정 버튼 (PopupMenuButton)
                  PopupMenuButton<int>(
                    onSelected: (item) {}, // No specific action needed for selection
                    itemBuilder: (context) => [
                      // Edit Mode Switch (설정 메뉴 안에도 있지만, 이미 밖으로 빼냈으니 제거해도 됩니다.)
                      PopupMenuItem(
                        child: StatefulBuilder(
                          builder: (BuildContext context, StateSetter menuSetState) {
                            return SwitchListTile(
                              title: const Text(
                                'Edit Mode',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                              ),
                              value: _isEditMode,
                              onChanged: (bool value) {
                                menuSetState(() {
                                  setState(() {
                                    _isEditMode = value;
                                    if (!_isEditMode) {
                                      _selectedMarkerKeys.clear();
                                      _selectedLegKeys.clear();
                                      _newMarkerLatLng = null;
                                      _isAddingNewLeg = false;
                                      _newLegOriginLatLng = null;
                                      _newLegDestinationLatLng = null;
                                    }
                                  });
                                });
                              },
                              activeColor: Colors.redAccent,
                            );
                          },
                        ),
                      ),
                      // Cities/Airports Icons
                      PopupMenuItem(
                        child: StatefulBuilder(
                          builder: (BuildContext context, StateSetter menuSetState) {
                            return Column(
                              children: [
                                SwitchListTile(
                                  title: const Text(
                                    'Cities/Airports Icons',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                                  ),
                                  value: _showCitiesAirportsIcons,
                                  onChanged: (bool value) {
                                    menuSetState(() {
                                      setState(() {
                                        _showCitiesAirportsIcons = value;
                                      });
                                    });
                                  },
                                  activeColor: Colors.blueAccent,
                                ),
                                if (_showCitiesAirportsIcons)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      children: [
                                        const Text('Size:', style: TextStyle(fontSize: 12)),
                                        Expanded(
                                          child: Slider(
                                            value: _markerIconSize,
                                            min: 0.5,
                                            max: 2.0,
                                            divisions: 15,
                                            onChanged: (value) {
                                              menuSetState(() {
                                                setState(() {
                                                  _markerIconSize = value;
                                                });
                                              });
                                            },
                                          ),
                                        ),
                                        Text('${(_markerIconSize * 100).round()}%',
                                            style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Cities/Airports Names
                      PopupMenuItem(
                        child: StatefulBuilder(
                          builder: (BuildContext context, StateSetter menuSetState) {
                            return Column(
                              children: [
                                SwitchListTile(
                                  title: const Text(
                                    'Cities/Airports Names',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                                  ),
                                  value: _showCitiesAirportsNames,
                                  onChanged: (bool value) {
                                    menuSetState(() {
                                      setState(() {
                                        _showCitiesAirportsNames = value;
                                      });
                                    });
                                  },
                                  activeColor: Colors.blueAccent,
                                ),
                                if (_showCitiesAirportsNames)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      children: [
                                        const Text('Size:', style: TextStyle(fontSize: 12)),
                                        Expanded(
                                          child: Slider(
                                            value: _markerNameSize,
                                            min: 0.5,
                                            max: 2.0,
                                            divisions: 15,
                                            onChanged: (value) {
                                              menuSetState(() {
                                                setState(() {
                                                  _markerNameSize = value;
                                                });
                                              });
                                            },
                                          ),
                                        ),
                                        Text('${(_markerNameSize * 100).round()}%',
                                            style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Transportation
                      PopupMenuItem(
                        child: StatefulBuilder(
                          builder: (BuildContext context, StateSetter menuSetState) {
                            return Column(
                              children: [
                                SwitchListTile(
                                  title: const Text(
                                    'Transportation',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                                  ),
                                  value: _showTransportation,
                                  onChanged: (bool value) {
                                    menuSetState(() {
                                      setState(() {
                                        _showTransportation = value;
                                      });
                                    });
                                  },
                                  activeColor: Colors.blueAccent,
                                ),
                                if (_showTransportation)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      children: [
                                        const Text('Width:', style: TextStyle(fontSize: 12)),
                                        Expanded(
                                          child: Slider(
                                            value: _transportationWidth,
                                            min: 0.5,
                                            max: 3.0,
                                            divisions: 25,
                                            onChanged: (value) {
                                              menuSetState(() {
                                                setState(() {
                                                  _transportationWidth = value;
                                                });
                                              });
                                            },
                                          ),
                                        ),
                                        Text('${(_transportationWidth * 100).round()}%',
                                            style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.settings),
                    tooltip: 'Settings',
                  ),
                  // 제자리 버튼 (Fit Bounds)
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: () => _fitBounds(_currentLocationMarkers),
                    tooltip: 'Fit Bounds',
                  ),
                ],
              ),
            ),
            body: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blueGrey[900]!,
                        Colors.blueGrey[700]!,
                        Colors.blueGrey[600]!,
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentLocationMarkers.isNotEmpty ?
                        _currentLocationMarkers.first.point : const LatLng(30, 0),
                        initialZoom: 2.5,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180)),
                        ),
                        // 편집 모드에서만 지도 탭을 통해 위치 선택 가능
                        onTap: _isEditMode ? (tapPosition, latLng) {
                          setState(() {
                            if (_isAddingNewLeg) {
                              if (_newLegOriginLatLng == null) {
                                _newLegOriginLatLng = latLng;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Origin selected. Tap destination on the map!')),
                                );
                              } else if (_newLegDestinationLatLng == null) {
                                _newLegDestinationLatLng = latLng;
                                _isAddingNewLeg = false; // 선택 완료
                                _showAddLegDetailsDialog(
                                  originLatLng: _newLegOriginLatLng!,
                                  destinationLatLng: _newLegDestinationLatLng!,
                                );
                                _newLegOriginLatLng = null; // 초기화
                                _newLegDestinationLatLng = null; // 초기화
                              }
                            } else {
                              _newMarkerLatLng = latLng;
                              developer.log('Map tapped at: $latLng', name: 'TripMapScreen.onTap');
                              // 지도 탭 후 자동으로 정보 입력 다이얼로그 열기
                              if (_newMarkerLatLng != null) {
                                _showAddMarkerInfoDialog(initialLatLng: _newMarkerLatLng!);
                                _newMarkerLatLng = null; // 다이얼로그가 열렸으니 임시 위치 초기화
                              }
                            }
                          });
                        } : null,
                      ),
                      children: [
                        const MyTileLayer(),
                        _buildGridLines(),
                        MarkerLayer(
                          markers: [
                            ..._currentLocationMarkers.map((marker) {
                              // marker.key를 _MarkerData 타입으로 캐스팅하여 원본 데이터 접근
                              final _MarkerData? markerData = marker.key is ValueKey<_MarkerData>
                                  ? (marker.key as ValueKey<_MarkerData>).value
                                  : null;

                              // _MarkerData가 있다면 그 값을 사용하고, 없다면 기본값 사용 (fallback)
                              final String? char = markerData?.markerChar;
                              final String dur = markerData?.duration ?? '0';
                              final String name = markerData?.cityDisplayName ?? '';
                              final Color color = markerData?.markerColor ?? Colors.red[600]!;
                              final String? countryCode = markerData?.countryIsoA2;


                              final bool isSelected = _selectedMarkerKeys.contains(marker.key);

                              return Marker(
                                point: marker.point,
                                width: marker.width,
                                height: marker.height,
                                child: GestureDetector(
                                  onLongPress: _isEditMode ? () {
                                    setState(() {
                                      if (marker.key != null) { // key가 null이 아닌 경우에만 처리
                                        if (_selectedMarkerKeys.contains(marker.key)) {
                                          _selectedMarkerKeys.remove(marker.key);
                                        } else {
                                          _selectedMarkerKeys.add(marker.key!);
                                        }
                                      }
                                    });
                                  } : null,
                                  child: _buildStayCityMarker(
                                    char,
                                    marker.point,
                                    dur,
                                    name,
                                    _showCitiesAirportsIcons,
                                    _showCitiesAirportsNames,
                                    isSelected, // 선택 상태 전달
                                    color, // 마커 색상 전달
                                    countryCode, // 국가 코드 전달
                                  ),
                                ),
                              );
                            }).toList(),
                            // 새 마커 추가 시 임시로 표시될 마커 (사용자가 클릭한 위치)
                            // 이 마커는 사용자가 지도를 탭했을 때 즉시 나타남
                            if (_newMarkerLatLng != null && _isEditMode && !_isAddingNewLeg) // 새 마커 추가 모드일 때는 안 보여줌
                              Marker(
                                point: _newMarkerLatLng!,
                                width: 80,
                                height: 80,
                                child: Icon(
                                  Icons.add_location_alt, // 새 마커 선택 중임을 나타내는 아이콘
                                  color: Colors.lightGreenAccent[700],
                                  size: 40,
                                ),
                              ),
                            // 새로운 경로 추가 중일 때 출발지/도착지 표시
                            if (_isAddingNewLeg) ...[
                              if (_newLegOriginLatLng != null)
                                Marker(
                                  point: _newLegOriginLatLng!,
                                  width: 80,
                                  height: 80,
                                  child: Icon(
                                    Icons.fiber_manual_record,
                                    color: Colors.green[700],
                                    size: 20,
                                  ),
                                ),
                              if (_newLegDestinationLatLng != null)
                                Marker(
                                  point: _newLegDestinationLatLng!,
                                  width: 80,
                                  height: 80,
                                  child: Icon(
                                    Icons.flag,
                                    color: Colors.red[700],
                                    size: 20,
                                  ),
                                ),
                            ],
                            ..._buildAnimationMarkers(),
                          ],
                        ),
                        if (_showTransportation) // Conditionally render transportation
                          FutureBuilder<List<TripLeg>>(
                            future: _tripLegsFuture,
                            builder: (context, tripLegsSnapshot) {
                              if (tripLegsSnapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox.shrink(); // 로딩 중에는 아무것도 표시하지 않음
                              } else if (tripLegsSnapshot.hasError) {
                                developer.log("Error loading trip legs for drawing: ${tripLegsSnapshot.error}", name: 'TripMapScreen.build.Trips');
                                return const SizedBox.shrink();
                              } else {
                                // 기존 TripLegs 대신 _currentTripLegs 사용
                                return _buildAnimatedRouteLayers(_currentTripLegs);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                // 편집 모드에 따라 하단 패널 표시
                if (_isEditMode)
                  _buildTransportStylePanel(),
                if (_isEditMode)
                  _showBottomEditPanel(),
                // 새로 추가되는 패널들
                if (_showLocationPanel)
                  _buildLocationPanel(),
                if (_showTransportPanel)
                  _buildTransportationPanel(),
                if (_isAnimationPlaying) // 애니메이션이 재생 중일 때만 속도 조절 패널을 보여줍니다.
                  _buildAnimationControlPanel(),

              ],
            ),
          );
        } else {
          // 데이터가 없지만 오류도 아닌 경우 (빈 리스트일 때 등)
          return Scaffold(
            appBar: AppBar(
              title: const Text('여행 지도'),
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text('표시할 도시 정보가 없습니다.'),
            ),
          );
        }
      },
    );
  }

  // 선택된 마커 개수에 따라 다른 하단 패널을 보여주는 위젯
  Widget _showBottomEditPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blueGrey[800]!.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _selectedMarkerKeys.isNotEmpty || _selectedLegKeys.isNotEmpty
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cancel 버튼 추가
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedMarkerKeys.clear();
                  _selectedLegKeys.clear();
                });
              },
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              ),
            ),
            const SizedBox(width: 10),
            // 삭제 버튼 (텍스트 수정)
            ElevatedButton.icon(
              onPressed: () {
                if (_selectedMarkerKeys.isNotEmpty) {
                  _deleteSelectedMarkers();
                } else if (_selectedLegKeys.isNotEmpty) {
                  _deleteSelectedLegs();
                }
              },
              icon: const Icon(Icons.delete),
              label: Text(
                  _selectedMarkerKeys.isNotEmpty
                      ? 'Delete (${_selectedMarkerKeys.length})'
                      : 'Delete (${_selectedLegKeys.length})'
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              ),
            ),
            const SizedBox(width: 10),
            // 수정 버튼 (단일 선택 시 활성화)
            if (_selectedMarkerKeys.length == 1 || _selectedLegKeys.length == 1)
              ElevatedButton.icon(
                onPressed: () {
                  if (_selectedMarkerKeys.length == 1) {
                    final Marker? selectedMarker = _currentLocationMarkers.firstWhereOrNull(
                            (m) => m.key == _selectedMarkerKeys.first);
                    if (selectedMarker != null) {
                      _showEditMarkerDialog(selectedMarker);
                    }
                  } else if (_selectedLegKeys.length == 1) {
                    final EditableTripLeg? selectedLeg = _currentTripLegs.firstWhereOrNull(
                            (leg) => leg.key == _selectedLegKeys.first);
                    if (selectedLeg != null) {
                      _showEditLegDialog(selectedLeg);
                    }
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                ),
              ),
          ],
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 새 마커 추가 버튼
            ElevatedButton.icon(
              onPressed: () {
                // 'Add New Location' 버튼을 누르면 먼저 지도에서 위치 선택을 유도
                _newMarkerLatLng = null; // 새 추가 시작 시 기존 임시 위치 초기화
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tap on the map to select a location for a new marker!')),
                );
                // 지도를 탭하여 위치를 선택하면 자동으로 _showAddMarkerInfoDialog가 열릴 것임
              },
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add New Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              ),
            ),
            const SizedBox(width: 10),
            // 새 경로 추가 버튼
            ElevatedButton.icon(
              onPressed: () {
                _startAddLegProcess();
              },
              icon: const Icon(Icons.alt_route),
              label: const Text('Add New Route'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 선택된 마커 삭제 로직
  void _deleteSelectedMarkers() {
    setState(() {
      _currentLocationMarkers.removeWhere((marker) => _selectedMarkerKeys.contains(marker.key));
      _selectedMarkerKeys.clear(); // 선택 해제
      _isTransportDataProcessed = false;

    });
    developer.log('Deleted selected markers. Remaining: ${_currentLocationMarkers.length}', name: 'TripMapScreen._deleteSelectedMarkers');
  }

  // 선택된 경로 삭제 로직
  void _deleteSelectedLegs() {
    setState(() {
      _currentTripLegs.removeWhere((leg) => _selectedLegKeys.contains(leg.key));
      _selectedLegKeys.clear(); // 선택 해제
      _isTransportDataProcessed = false;
    });
    developer.log('Deleted selected legs. Remaining: ${_currentTripLegs.length}', name: 'TripMapScreen._deleteSelectedLegs');
  }


  // 마커 수정 다이얼로그
  void _showEditMarkerDialog(Marker markerToEdit) {
    final _MarkerData? originalData = markerToEdit.key is ValueKey<_MarkerData>
        ? (markerToEdit.key as ValueKey<_MarkerData>).value
        : null;

    if (originalData == null) {
      developer.log('Error: Could not retrieve marker data for editing.', name: 'TripMapScreen._showEditMarkerDialog');
      return;
    }

    final TextEditingController nameController = TextEditingController(text: originalData.cityDisplayName);
    final TextEditingController durationController = TextEditingController(text: originalData.duration);
    String? currentMarkerChar = originalData.markerChar;
    Color selectedColor = originalData.markerColor; // 현재 마커의 색상

    // 선택 가능한 색상 목록
    final Map<String, Color> availableColors = {
      'Red': Colors.red[600]!,
      'Orange': Colors.orange[600]!,
      'Yellow': Colors.yellow[600]!,
      'Green': Colors.green[600]!,
      'Blue': Colors.blue[600]!,
      'Purple': Colors.purple[600]!,
      'Pink': Colors.pink[600]!,
      'Brown': Colors.brown[600]!,
      'Grey': Colors.grey[600]!,
      'Black': Colors.black,
    };

    // 현재 마커 색상에 해당하는 이름 찾기
    String? initialColorName = availableColors.entries.firstWhereOrNull(
            (entry) => entry.value.value == selectedColor.value)?.key;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Edit Location'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Location Name'),
                    ),
                    if (currentMarkerChar == null) // 일반 도시 마커일 때만 기간 편집 가능
                      TextFormField(
                        controller: durationController,
                        decoration: const InputDecoration(labelText: 'Duration (days)'),
                        keyboardType: TextInputType.number,
                      ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: initialColorName, // 초기 선택 값
                      decoration: const InputDecoration(labelText: 'Marker Color'),
                      items: availableColors.keys.map((String colorName) {
                        return DropdownMenuItem<String>(
                          value: colorName,
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: availableColors[colorName],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(colorName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateInDialog(() {
                            selectedColor = availableColors[newValue]!;
                            initialColorName = newValue; // UI 갱신
                          });
                        }
                      },
                    ),
                    // TODO: 아이콘 변경 기능은 나중에 추가
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _selectedMarkerKeys.clear(); // 취소 시 선택 해제
                    });
                  },
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () {
                    setState(() {
                      final int index = _currentLocationMarkers.indexOf(markerToEdit);
                      if (index != -1) {
                        final String newName = nameController.text;
                        final String newDuration = currentMarkerChar == null ? durationController.text : '0';

                        final _MarkerData updatedData = _MarkerData(
                          point: originalData.point,
                          markerChar: originalData.markerChar,
                          duration: newDuration,
                          cityDisplayName: newName,
                          markerColor: selectedColor, // 업데이트된 색상 적용
                          countryIsoA2: originalData.countryIsoA2, // 기존 국가 코드 유지
                        );

                        _currentLocationMarkers[index] = Marker(
                          point: markerToEdit.point,
                          width: markerToEdit.width,
                          height: markerToEdit.height,
                          key: ValueKey<_MarkerData>(updatedData), // 업데이트된 데이터로 Key 재생성
                          child: GestureDetector(
                            onLongPress: _isEditMode ? () {
                              setState(() {
                                if (markerToEdit.key != null) {
                                  if (_selectedMarkerKeys.contains(markerToEdit.key)) {
                                    _selectedMarkerKeys.remove(markerToEdit.key);
                                  } else {
                                    _selectedMarkerKeys.add(markerToEdit.key!);
                                  }
                                }
                              });
                            } : null,
                            child: _buildStayCityMarker(
                              updatedData.markerChar,
                              updatedData.point,
                              updatedData.duration,
                              updatedData.cityDisplayName,
                              _showCitiesAirportsIcons,
                              _showCitiesAirportsNames,
                              false, // 수정 완료 후에는 선택 해제
                              updatedData.markerColor, // 업데이트된 색상 전달
                              updatedData.countryIsoA2, // 국가 코드 전달
                            ),
                          ),
                        );
                        _selectedMarkerKeys.clear(); // 수정 후 선택 해제
                        _isTransportDataProcessed = false;
                      }
                    });
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 새 마커 추가 다이얼로그 (이 함수가 지도 탭 이벤트를 처리하고 정보 입력 다이얼로그를 띄움)
  void _showAddMarkerDialog() {
    // 이 함수는 더 이상 초기 다이얼로그를 직접 띄우지 않고,
    // 지도 탭 이벤트를 통해 _newMarkerLatLng가 설정되면 _showAddMarkerInfoDialog를 호출하도록 변경되었습니다.
    // 따라서, 단순히 사용자에게 지도를 탭하도록 안내하는 역할만 수행합니다.
    _newMarkerLatLng = null; // 새 추가 시작 시 기존 임시 위치 초기화
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap on the map to select a location for a new marker!')),
    );
  }

  // 새 마커 정보 입력 다이얼로그 (위치가 선택된 후 호출됨)
  void _showAddMarkerInfoDialog({required LatLng initialLatLng}) {
    String? selectedMarkerType;
    final TextEditingController newNameController = TextEditingController();
    final TextEditingController newDurationController = TextEditingController();
    LatLng locationToAdd = initialLatLng;

    // 현재 선택된 위치를 문자열로 표시
    String locationText = 'Selected: ${initialLatLng.latitude.toStringAsFixed(3)}, ${initialLatLng.longitude.toStringAsFixed(3)}';

    // 기본 색상 설정
    Color selectedColor = Colors.red[600]!;
    final Map<String, Color> availableColors = {
      'Red': Colors.red[600]!,
      'Orange': Colors.orange[600]!,
      'Yellow': Colors.yellow[600]!,
      'Green': Colors.green[600]!,
      'Blue': Colors.blue[600]!,
      'Purple': Colors.purple[600]!,
      'Pink': Colors.pink[600]!,
      'Brown': Colors.brown[600]!,
      'Grey': Colors.grey[600]!,
      'Black': Colors.black,
    };
    String? initialColorName = 'Red'; // 기본값

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Add New Location Details'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(locationText), // 지도에서 선택된 위치 표시
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedMarkerType,
                      hint: const Text('Select Marker Type'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'city',
                          child: Text('City (Normal)'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'D',
                          child: Text('Departure (D)'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'A',
                          child: Text('Arrival (A)'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'H',
                          child: Text('Home/Round Trip (H)'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'T',
                          child: Text('Transit (T)'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        setStateInDialog(() {
                          selectedMarkerType = newValue;
                          // 마커 타입 변경 시 기간 입력 필드 가시성 변경
                          if (selectedMarkerType != 'city') {
                            newDurationController.text = '0'; // 특수 마커는 기간 0으로 초기화
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: newNameController,
                      decoration: const InputDecoration(labelText: 'Location Name'),
                    ),
                    if (selectedMarkerType == 'city' || selectedMarkerType == null) // 일반 도시 마커일 때만 기간 입력 필드 표시
                      TextFormField(
                        controller: newDurationController,
                        decoration: const InputDecoration(labelText: 'Duration (days)'),
                        keyboardType: TextInputType.number,
                      ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: initialColorName, // 초기 선택 값
                      decoration: const InputDecoration(labelText: 'Marker Color'),
                      items: availableColors.keys.map((String colorName) {
                        return DropdownMenuItem<String>(
                          value: colorName,
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: availableColors[colorName],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(colorName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateInDialog(() {
                            selectedColor = availableColors[newValue]!;
                            initialColorName = newValue; // UI 갱신
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _newMarkerLatLng = null; // 취소 시 임시 위치도 초기화
                    });
                  },
                ),
                TextButton(
                  child: const Text('Add'),
                  onPressed: () {
                    final String finalSelectedMarkerType = selectedMarkerType ?? 'city';
                    final String? finalMarkerChar = (finalSelectedMarkerType == 'city') ? null : finalSelectedMarkerType;
                    final String finalDuration = (finalSelectedMarkerType == 'city') ? newDurationController.text : '0';
                    final String finalName = newNameController.text.isNotEmpty ? newNameController.text : 'New Location';

                    setState(() {
                      final newMarkerData = _MarkerData(
                        point: locationToAdd,
                        markerChar: finalMarkerChar,
                        duration: finalDuration,
                        cityDisplayName: finalName,
                        markerColor: selectedColor, // 선택된 색상 적용
                        countryIsoA2: null, // 수동 추가 마커는 국가 코드 없음
                      );

                      _currentLocationMarkers.add(Marker(
                        point: newMarkerData.point,
                        width: 120,
                        height: 120,
                        key: ValueKey<_MarkerData>(newMarkerData),
                        child: _buildStayCityMarker(
                          newMarkerData.markerChar,
                          newMarkerData.point,
                          newMarkerData.duration,
                          newMarkerData.cityDisplayName,
                          _showCitiesAirportsIcons,
                          _showCitiesAirportsNames,
                          false,
                          newMarkerData.markerColor,
                          newMarkerData.countryIsoA2, // 국가 코드 전달
                        ),
                      ));
                      _newMarkerLatLng = null; // 마커 추가 후 임시 위치 초기화
                      _isTransportDataProcessed = false;

                    });

                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New marker added!')),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 새로운 경로 추가 시작 함수
  void _startAddLegProcess() {
    setState(() {
      _isAddingNewLeg = true;
      _newLegOriginLatLng = null;
      _newLegDestinationLatLng = null;
      _selectedMarkerKeys.clear(); // 마커 선택 초기화
      _selectedLegKeys.clear(); // 경로 선택 초기화
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap on the map to select the origin for the new route!')),
    );
  }

  // 새 경로 정보 입력 다이얼로그 (출발지/도착지 선택 후 호출됨)
  void _showAddLegDetailsDialog({
    required LatLng originLatLng,
    required LatLng destinationLatLng,
  }) {
    String? selectedTransportType;
    Color selectedColor = Colors.blue[600]!; // 경로의 기본 색상
    String? selectedLineStyle; // "solid", "dotted", "spring", "wavy"
    String? errorMessage; // ← 이 줄 추가
    // 새로 추가할 변수들
    final TextEditingController originController = TextEditingController();
    final TextEditingController destinationController = TextEditingController();
    final TextEditingController dateController = TextEditingController(); // 날짜용 추가
    final TextEditingController identifierController = TextEditingController(); // 편명용
    final TextEditingController hoursController = TextEditingController();
    final TextEditingController minutesController = TextEditingController();
    DateTime? selectedDate; // 선택된 날짜

    // 다음 순서 번호 계산하는 함수
    int calculateNextSequenceNumber(String? selectedDate) {
      if (selectedDate == null) return 1;

      int maxSequence = 0;

      for (final leg in _currentTripLegs) {
        if (leg.date == selectedDate) {
          maxSequence = math.max(maxSequence, leg.sequence ?? 0);
        }
      }

      return maxSequence + 1;
    }

    final Map<String, Color> availableColors = {
      'Cyan': Colors.cyan,
      'Orange': Colors.orange,
      'Purple': Colors.purple,
      'Green': Colors.green,
      'Pink': Colors.pink,
      'Amber': Colors.amber,
      'Indigo': Colors.indigo,
      'Teal': Colors.teal,
    };
    String? initialColorName = 'Cyan';

    final Map<String, String> availableLineStyles = {
      'Solid': 'solid',
      'Dotted': 'dotted',
      'Spring': 'spring',
      'Wavy': 'wavy',
      'Shadow': 'shadow',
    };
    String? initialLineStyleName = 'Solid';







    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Add New Route Details'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    TextFormField(
                      controller: originController,
                      decoration: const InputDecoration(
                        labelText: 'Origin (출발지)',
                        hintText: 'e.g., ICN, Seoul, Paris',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination (도착지)',
                        hintText: 'e.g., CDG, Tokyo, London',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: identifierController,
                      decoration: const InputDecoration(
                        labelText: 'Flight Number / Train Name (선택사항)',
                        hintText: 'e.g., KE901, TGV, optional',
                      ),
                    ),

                    const SizedBox(height: 10),
// 날짜 선택 필드
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setStateInDialog(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 10),
                            Text(
                              selectedDate != null
                                  ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                                  : 'Select Date (날짜 선택)',
                              style: TextStyle(
                                color: selectedDate != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
// 소요시간 입력 필드
                    // 소요시간 입력 필드 (시간과 분 분리)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: hoursController,
                            decoration: const InputDecoration(
                              labelText: 'Hours (시간)',
                              hintText: '0',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('h'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: minutesController,
                            decoration: const InputDecoration(
                              labelText: 'Minutes (분)',
                              hintText: '0',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('m'),
                      ],
                    ),

                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedTransportType,
                      hint: const Text('Select Transport Type'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'flight', child: Text('Flight')),
                        DropdownMenuItem<String>(value: 'train', child: Text('Train')),
                        DropdownMenuItem<String>(value: 'bus', child: Text('Bus')),
                        DropdownMenuItem<String>(value: 'ferry', child: Text('Ferry')),
                        DropdownMenuItem<String>(value: 'car', child: Text('Car')),
                      ],
                      onChanged: (String? newValue) {
                        setStateInDialog(() {
                          selectedTransportType = newValue;
                          // 교통수단 타입에 따라 자동으로 Line Style 설정
                          if (newValue != null) {
                            selectedLineStyle = _transportLineStyles[newValue] ?? 'solid';
                            initialLineStyleName = availableLineStyles.entries
                                .firstWhereOrNull((entry) => entry.value == selectedLineStyle)?.key ?? 'Solid';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: initialColorName,
                      decoration: const InputDecoration(labelText: 'Route Color'),
                      items: availableColors.keys.map((String colorName) {
                        return DropdownMenuItem<String>(
                          value: colorName,
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: availableColors[colorName],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(colorName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateInDialog(() {
                            selectedColor = availableColors[newValue]!;
                            initialColorName = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: initialLineStyleName,
                      decoration: const InputDecoration(labelText: 'Line Style'),
                      items: availableLineStyles.keys.map((String styleName) {
                        return DropdownMenuItem<String>(
                          value: styleName,
                          child: Text(styleName),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateInDialog(() {
                            selectedLineStyle = availableLineStyles[newValue];
                            initialLineStyleName = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _isAddingNewLeg = false; // 경로 추가 취소
                      _newLegOriginLatLng = null;
                      _newLegDestinationLatLng = null;
                    });
                  },
                ),
                TextButton(
                  child: const Text('Add Route'),
                  onPressed: () {
                    if (selectedTransportType == null) {
                      setStateInDialog(() {
                        errorMessage = 'Please select a transport type.';
                      });
                      return;
                    }
                    if (originController.text.trim().isEmpty) {
                      setStateInDialog(() {
                        errorMessage = 'Please enter origin.';
                      });
                      return;
                    }
                    if (destinationController.text.trim().isEmpty) {
                      setStateInDialog(() {
                        errorMessage = 'Please enter destination.';
                      });
                      return;
                    }
                    if (selectedDate == null) {
                      setStateInDialog(() {
                        errorMessage = 'Please select a date.';
                      });
                      return;
                    }
                    final hours = int.tryParse(hoursController.text) ?? 0;
                    final minutes = int.tryParse(minutesController.text) ?? 0;
                    if (hours == 0 && minutes == 0) {
                      setStateInDialog(() {
                        errorMessage = 'Please enter duration (hours or minutes).';
                      });
                      return;
                    }

                    setState(() {
                      // 소요시간 계산
                      String calculatedDuration = '';
                      final hours = int.tryParse(hoursController.text) ?? 0;
                      final minutes = int.tryParse(minutesController.text) ?? 0;
                      if (hours > 0) calculatedDuration += '${hours}h';
                      if (minutes > 0) calculatedDuration += '${minutes}m';
                      if (calculatedDuration.isEmpty) calculatedDuration = 'Unknown';

                      // 자동으로 순서 번호 계산
                      final selectedDateStr = selectedDate != null
                          ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                          : null;
                      final autoSequence = calculateNextSequenceNumber(selectedDateStr);

                      final newLeg = EditableTripLeg(
                        key: UniqueKey(),
                        originPoint: originLatLng,
                        destinationPoint: destinationLatLng,
                        transportType: selectedTransportType!,
                        sequence: autoSequence,
                        transportIdentifier: identifierController.text.isNotEmpty ? identifierController.text : null,
                        originCityName: originController.text.isNotEmpty ? originController.text : null,
                        destinationCityName: destinationController.text.isNotEmpty ? destinationController.text : null,
                        date: selectedDate != null ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}' : null,
                        duration: calculatedDuration,
                        customColor: selectedColor,
                        lineStyle: selectedLineStyle!,
                      );
                      _currentTripLegs.add(newLeg);

                      _isAddingNewLeg = false; // 경로 추가 완료
                      _newLegOriginLatLng = null;
                      _newLegDestinationLatLng = null;
                      _isTransportDataProcessed = false;
                    });
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New route added!')),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 경로 수정 다이얼로그
  void _showEditLegDialog(EditableTripLeg legToEdit) {
    String selectedTransportType = legToEdit.transportType;
    Color selectedColor = legToEdit.customColor;
    String selectedLineStyle = legToEdit.lineStyle;

    // 새로 추가할 컨트롤러들
    final TextEditingController originController = TextEditingController(text: legToEdit.originCityName ?? '');
    final TextEditingController destinationController = TextEditingController(text: legToEdit.destinationCityName ?? '');
    final TextEditingController identifierController = TextEditingController(text: legToEdit.transportIdentifier ?? '');
    final TextEditingController hoursController = TextEditingController();
    final TextEditingController minutesController = TextEditingController();

    // 기존 날짜 파싱
    DateTime? selectedDate;
    if (legToEdit.date != null) {
      try {
        selectedDate = DateTime.parse(legToEdit.date!);
      } catch (e) {
        selectedDate = null;
      }
    }

    // 기존 소요시간 파싱
    if (legToEdit.duration != null) {
      final duration = legToEdit.duration!;
      final hoursMatch = RegExp(r'(\d+)h').firstMatch(duration);
      final minutesMatch = RegExp(r'(\d+)m').firstMatch(duration);
      if (hoursMatch != null) hoursController.text = hoursMatch.group(1)!;
      if (minutesMatch != null) minutesController.text = minutesMatch.group(1)!;
    }
    final Map<String, Color> availableColors = {
      'Cyan': Colors.cyan, 'Orange': Colors.orange, 'Purple': Colors.purple,
      'Green': Colors.green, 'Pink': Colors.pink, 'Amber': Colors.amber,
      'Indigo': Colors.indigo, 'Teal': Colors.teal,
    };
    String? initialColorName = availableColors.entries.firstWhereOrNull(
            (entry) => entry.value.value == selectedColor.value)?.key;

    final Map<String, String> availableLineStyles = {
      'Solid': 'solid', 'Dotted': 'dotted', 'Spring': 'spring', 'Wavy': 'wavy', 'Shadow': 'shadow',
    };
    String? initialLineStyleName = availableLineStyles.entries.firstWhereOrNull(
            (entry) => entry.value == selectedLineStyle)?.key;


    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('Edit Route'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    TextFormField(
                      controller: originController,
                      decoration: const InputDecoration(
                        labelText: 'Origin (출발지)',
                        hintText: 'e.g., ICN, Seoul, Paris',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination (도착지)',
                        hintText: 'e.g., CDG, Tokyo, London',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: identifierController,
                      decoration: const InputDecoration(
                        labelText: 'Flight Number / Train Name (선택사항)',
                        hintText: 'e.g., KE901, TGV, optional',
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 날짜 선택 필드
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setStateInDialog(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 10),
                            Text(
                              selectedDate != null
                                  ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                                  : 'Select Date (날짜 선택)',
                              style: TextStyle(
                                color: selectedDate != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 소요시간 입력 필드 (시간과 분 분리)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: hoursController,
                            decoration: const InputDecoration(
                              labelText: 'Hours (시간)',
                              hintText: '0',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('h'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: minutesController,
                            decoration: const InputDecoration(
                              labelText: 'Minutes (분)',
                              hintText: '0',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('m'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedTransportType,
                      decoration: const InputDecoration(labelText: 'Transport Type'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'flight', child: Text('Flight')),
                        DropdownMenuItem<String>(value: 'train', child: Text('Train')),
                        DropdownMenuItem<String>(value: 'bus', child: Text('Bus')),
                        DropdownMenuItem<String>(value: 'ferry', child: Text('Ferry')),
                        DropdownMenuItem<String>(value: 'car', child: Text('Car')),
                      ],
                      onChanged: (String? newValue) {
                        setStateInDialog(() {
                          selectedTransportType = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: initialColorName,
                      decoration: const InputDecoration(labelText: 'Route Color'),
                      items: availableColors.keys.map((String colorName) {
                        return DropdownMenuItem<String>(
                          value: colorName,
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: availableColors[colorName],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(colorName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateInDialog(() {
                            selectedColor = availableColors[newValue]!;
                            initialColorName = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: initialLineStyleName,
                      decoration: const InputDecoration(labelText: 'Line Style'),
                      items: availableLineStyles.keys.map((String styleName) {
                        return DropdownMenuItem<String>(
                          value: styleName,
                          child: Text(styleName),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateInDialog(() {
                            selectedLineStyle = availableLineStyles[newValue]!;
                            initialLineStyleName = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _selectedLegKeys.clear();
                    });
                  },
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () {
                    setState(() {
                      final int index = _currentTripLegs.indexOf(legToEdit);
                      if (index != -1) {
                        // 소요시간 계산
                        String calculatedDuration = '';
                        final hours = int.tryParse(hoursController.text) ?? 0;
                        final minutes = int.tryParse(minutesController.text) ?? 0;
                        if (hours > 0) calculatedDuration += '${hours}h';
                        if (minutes > 0) calculatedDuration += '${minutes}m';
                        if (calculatedDuration.isEmpty) calculatedDuration = 'Unknown';

                        _currentTripLegs[index] = legToEdit.copyWith(
                          transportType: selectedTransportType,
                          transportIdentifier: identifierController.text.isNotEmpty ? identifierController.text : null,
                          originCityName: originController.text.isNotEmpty ? originController.text : null,
                          destinationCityName: destinationController.text.isNotEmpty ? destinationController.text : null,
                          date: selectedDate != null ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}' : null,
                          duration: calculatedDuration,
                          customColor: selectedColor,
                          lineStyle: selectedLineStyle,
                        );
                        _selectedLegKeys.clear();
                        _isTransportDataProcessed = false;
                      }
                    });
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildGridLines() {
    return PolylineLayer(
      polylines: [
        for (int i = -180; i <= 180; i += 30)
          Polyline(
            points: [LatLng(-85, i.toDouble()), LatLng(85, i.toDouble())],
            color: Colors.white.withOpacity(0.1),
            strokeWidth: 0.5,
          ),
        for (int i = -60; i <= 60; i += 30)
          Polyline(
            points: [LatLng(i.toDouble(), -180), LatLng(i.toDouble(), 180)],
            color: Colors.white.withOpacity(0.1),
            strokeWidth: 0.5,
          ),
      ],
    );
  }

  // Helper for generating wavy/curvy paths
  List<LatLng> _generateWavyPath(LatLng p1, LatLng p2, double amplitude, double frequency, int numSegments) {
    final List<LatLng> points = [];
    // Calculate the direct vector from p1 to p2
    final double dx = p2.longitude - p1.longitude;
    final double dy = p2.latitude - p1.latitude;
    final double length = sqrt(dx * dx + dy * dy);

    // If points are too close, just return a straight line
    if (length < 0.000001) { // A very small threshold for floating point comparison
      return [p1, p2];
    }

    // Calculate the perpendicular vector (normalized)
    // Rotate (dx, dy) by 90 degrees counter-clockwise: (-dy, dx)
    // Normalize by dividing by length
    final double perpDx = -dy / length;
    final double perpDy = dx / length;

    for (int i = 0; i <= numSegments; i++) {
      double t = i / numSegments; // t from 0.0 to 1.0

      // Linear interpolation for the base point
      final double lat = p1.latitude + t * (p2.latitude - p1.latitude);
      final double lng = p1.longitude + t * (p2.longitude - p1.longitude);

      // Calculate the sinusoidal offset
      // The given formulas imply amplitude in degrees, not meters, because LatLng operations are direct
      final double offsetAmount = amplitude * sin(t * pi * frequency);

      // Apply the offset perpendicular to the line
      final double wavyLat = lat + offsetAmount * perpDy;
      final double wavyLng = lng + offsetAmount * perpDx;

      points.add(LatLng(wavyLat, wavyLng));
    }
    return points;
  }

  // Helper for generating spring-like paths
  List<LatLng> _generateSpringPath(LatLng p1, LatLng p2, double amplitude, double frequency, int numSegments) {
    final List<LatLng> points = [];
    final double dx = p2.longitude - p1.longitude;
    final double dy = p2.latitude - p1.latitude;
    final double length = sqrt(dx * dx + dy * dy);

    if (length < 0.000001) {
      return [p1, p2];
    }

    final double perpDx = -dy / length;
    final double perpDy = dx / length;

    for (int i = 0; i <= numSegments; i++) {
      double t = i / numSegments;
      double lat = p1.latitude + t * (p2.latitude - p1.latitude);
      double lng = p1.longitude + t * (p2.longitude - p1.longitude);

      // compression is sin(t * pi) * 0.5 + 0.5; // 0~1 사이값
      // The formula provided was return sin(t * pi * 20) * 0.05 * compression;
      // Re-integrating the compression logic into offsetAmount calculation
      double compressionFactor = sin(t * pi) * 0.5 + 0.5; // 0 (at t=0,1) to 1 (at t=0.5)
      double offsetAmount = sin(t * pi * frequency) * amplitude * compressionFactor;

      final double springLat = lat + offsetAmount * perpDy;
      final double springLng = lng + offsetAmount * perpDx;

      points.add(LatLng(springLat, springLng));
    }
    return points;
  }

  // Helper for generating zigzag paths (unused for car now, but kept for reference)
  List<LatLng> _generateZigzagPath(LatLng p1, LatLng p2, double amplitude, double frequency, int numSegments) {
    final List<LatLng> points = [];
    final double dx = p2.longitude - p1.longitude;
    final double dy = p2.latitude - p1.latitude;
    final double length = sqrt(dx * dx + dy * dy);

    if (length < 0.000001) {
      return [p1, p2];
    }

    final double perpDx = -dy / length;
    final double perpDy = dx / length;

    for (int i = 0; i <= numSegments; i++) {
      double t = i / numSegments;
      double lat = p1.latitude + t * (p2.latitude - p1.latitude);
      double lng = p1.longitude + t * (p2.longitude - p1.longitude);

      // Simple sawtooth wave for zigzag
      // Triangle wave from -1 to 1, scaled by amplitude
      double zigzagFactor;
      double localT = t * frequency;
      double fractionalPart = localT - localT.floor(); // 0.0 to 1.0 within each cycle

      if (fractionalPart < 0.5) {
        zigzagFactor = 2 * fractionalPart; // Rises from 0 to 1
      } else {
        zigzagFactor = 2 * (1 - fractionalPart); // Falls from 1 to 0
      }
      zigzagFactor = zigzagFactor * 2 - 1; // Scale to -1 to 1

      double offsetAmount = amplitude * zigzagFactor;

      final double zigzagLat = lat + offsetAmount * perpDy;
      final double zigzagLng = lng + offsetAmount * perpDx;

      points.add(LatLng(zigzagLat, zigzagLng));
    }
    return points;
  }
// Transportation Panel에서 선택된 교통편이 지도의 경로와 매칭되는지 확인
  bool _isLegSelectedInTransportPanel(EditableTripLeg leg) {
    if (_selectedTransportId == null) return false;

    // 새로운 uniqueId 형식: flight_0_Geneva_Frankfurt
    final selectedParts = _selectedTransportId!.split('_');
    if (selectedParts.length < 4) return false;

    final selectedType = selectedParts[0]; // 'flight'
    final selectedIndex = selectedParts[1]; // '0' (무시)
    final selectedOrigin = selectedParts[2]; // 'Geneva'
    final selectedDestination = selectedParts[3]; // 'Frankfurt'
    // 교통수단 타입이 같은지 확인
    if (leg.transportType != selectedType) return false;

    // 출발지와 도착지가 매칭되는지 확인
    final legOrigin = leg.originCityName ?? '';
    final legDestination = leg.destinationCityName ?? '';

    if (legOrigin.toLowerCase() == selectedOrigin.toLowerCase() &&
        legDestination.toLowerCase() == selectedDestination.toLowerCase()) {
      return true;
    }


    return false;
  }
  // 왕복 경로인지 확인하는 함수
  bool _isRoundTrip(EditableTripLeg leg1, EditableTripLeg leg2) {
    return leg1.originPoint.latitude == leg2.destinationPoint.latitude &&
        leg1.originPoint.longitude == leg2.destinationPoint.longitude &&
        leg1.destinationPoint.latitude == leg2.originPoint.latitude &&
        leg1.destinationPoint.longitude == leg2.originPoint.longitude;
  }

// 왕복 경로용 오프셋된 좌표 생성 함수
  List<LatLng> _getOffsetPoints(LatLng origin, LatLng destination, double offsetDistance) {
    // 두 점 사이의 중점 계산
    final midLat = (origin.latitude + destination.latitude) / 2;
    final midLng = (origin.longitude + destination.longitude) / 2;

    // 수직 방향으로 오프셋 계산 (위도 기준)
    final latOffset = offsetDistance * 0.15; // 0.01에서 0.5로 크게 증가

    return [
      LatLng(origin.latitude + latOffset, origin.longitude),
      LatLng(destination.latitude + latOffset, destination.longitude)
    ];
  }

  Widget _buildAnimatedRouteLayers(List<EditableTripLeg> tripLegs) { // List<TripLeg> -> List<EditableTripLeg>
    if (tripLegs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: tripLegs.map((leg) {
        List<LatLng> points;
        bool isDottedLine = false; // 기본은 실선

        if (leg.lineStyle == 'solid') {
          // 왕복 경로 offset 로직 제거 - 모든 경로를 직선으로
          points = [leg.originPoint, leg.destinationPoint];
        } else if (leg.lineStyle == 'wavy') {
          points = _generateWavyPath(leg.originPoint, leg.destinationPoint, 0.12, 4.0, 50);
        } else if (leg.lineStyle == 'spring') {
          points = _generateSpringPath(leg.originPoint, leg.destinationPoint, 0.05, 20.0, 100);
        } else if (leg.lineStyle == 'dotted') {
          points = [leg.originPoint, leg.destinationPoint];
          isDottedLine = true;
        } else { // 기본
          points = [leg.originPoint, leg.destinationPoint];
        }

        // 편집 모드에서의 선택 확인
        final bool isEditSelected = _selectedLegKeys.contains(leg.key);

        // Transportation Panel에서의 선택 확인
        final bool isTransportSelected = _isLegSelectedInTransportPanel(leg);

        // 둘 중 하나라도 선택되면 하이라이트
        final bool isSelected = isEditSelected || isTransportSelected;

        return GestureDetector(
          onLongPress: _isEditMode ? () {
            setState(() {
              if (_selectedLegKeys.contains(leg.key)) {
                _selectedLegKeys.remove(leg.key);
              } else {
                _selectedLegKeys.add(leg.key);
              }
            });
          } : null,
          child: PolylineLayer(
            polylines: leg.lineStyle == 'shadow'
                ? [
              // 자동차는 음영만 표시
              Polyline(
                points: points,
                color: isSelected ? Colors.yellow.withOpacity(0.5) : Colors.black.withOpacity(0.3),
                strokeWidth: (isSelected ? 10.0 : 8.0) * _transportationWidth,
                isDotted: isDottedLine,
              ),
            ]
                : [
              // 다른 교통수단은 기존대로 (그림자 + 실제 선)
              Polyline(
                points: points,
                color: isSelected ? Colors.yellow.withOpacity(0.5) : Colors.black.withOpacity(0.3),
                strokeWidth: (isSelected ? 10.0 : 8.0) * _transportationWidth,
                isDotted: isDottedLine,
              ),
              Polyline(
                points: points,
                color: isSelected ? Colors.yellow : Colors.black, // 선 색상을 검은색으로 변경
                strokeWidth: (isSelected ? 6.0 : 4.0) * _transportationWidth, // 선 굵기를 두껍게
                isDotted: isDottedLine,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // _buildTopStatsPanel 및 _buildBottomInfoPanel은 사용자 요청에 따라 제거되었습니다.
  Widget _buildTopStatsPanel(List<TripLeg> tripLegs, Set<String> stayCityNames) {
    return const SizedBox.shrink();
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return const SizedBox.shrink();
  }

  Widget _buildBottomInfoPanel(List<TripLeg> tripLegs) {
    return const SizedBox.shrink();
  }

  List<Polyline> _buildShadowLines(List<TripLeg> tripLegs) {
    return tripLegs.map((leg) {
      final List<LatLng> points;
      // 항공편 포함 모든 경로를 직선으로 그립니다.
      points = [leg.originPoint, leg.destinationPoint];

      return Polyline(
        points: points,
        color: leg.legColor.withOpacity(0.3),
        strokeWidth: 8.0,
      );
    }).toList();
  }


  // 기존 _buildPathLines 대신 _buildAnimatedRouteLayers가 경로를 그림
  // List<Polyline> _buildPathLines(List<TripLeg> tripLegs) { return []; }


  // _buildTransportInfoMarkers 및 _buildDirectionalTransportMarkers는 사용자 요청에 따라 제거되었습니다.
  List<Marker> _buildTransportInfoMarkers(List<TripLeg> tripLegs) {
    return [];
  }

  List<Marker> _buildDirectionalTransportMarkers(List<TripLeg> tripLegs) {
    return [];
  }


  double _getRotationAngle(String transportType, double baseAngle) {
    // For flights, make them point along the curve or generally upwards
    if (transportType == 'flight') {
      return -pi / 2; // Pointing upwards (adjust as needed)
    }
    // For other transport types, rotate based on direction of travel
    return baseAngle;
  }


  IconData _getTransportIcon(String transportType, String? transportIdentifier) {
    switch (transportType) {
      case 'flight':
        return Icons.airplanemode_active;
      case 'train':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      case 'ferry':
        return Icons.directions_boat;
      default:
        return Icons.help;
    }
  }

  Widget _buildStayCityMarker(String? markerChar, LatLng point, String duration, String cityDisplayName, bool showIcon, bool showName, bool isSelected, Color markerColor, String? countryIsoA2) {
    String nameToDisplay = cityDisplayName; // 도시 이름 그대로 사용
    Color bgColor = markerColor; // _MarkerData에서 전달받은 색상 사용
    Color borderColor = Colors.white;
    String charToDisplay = duration; // 기본값은 기간

    // 마커 문자에 따른 기본 색상 오버라이드 (추가/수정 시 색상 변경 가능)
    // 이제 markerColor를 사용하므로 아래 초기 색상 설정은 주석 처리 또는 제거
    if (markerChar == 'D') {
      charToDisplay = 'D';
      // bgColor = Colors.blue[600]!;
      borderColor = Colors.blue.shade200;
    } else if (markerChar == 'A') {
      charToDisplay = 'A';
      // bgColor = Colors.purple[600]!;
      borderColor = Colors.purple.shade200;
    } else if (markerChar == 'H') {
      charToDisplay = 'H';
      // bgColor = Colors.deepOrange[600]!;
      borderColor = Colors.deepOrange.shade200;
    } else if (markerChar == 'T') { // 경유지 마커
      charToDisplay = 'T';
      // bgColor = Colors.grey[600]!;
      borderColor = Colors.grey.shade200;
    }

    // 선택된 마커인 경우 테두리 색상 변경
    if (isSelected) {
      borderColor = Colors.yellowAccent;
    }

    // 아이콘과 이름이 모두 숨겨지면 아무것도 렌더링하지 않음
    if (!showIcon && !showName) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showIcon) // showCitiesAirportsIcons 스위치에 따라 아이콘 렌더링
          Container(
            width: 30 * _markerIconSize,
            height: 30 * _markerIconSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: isSelected ? 3 : 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: countryIsoA2 != null && countryIsoA2.isNotEmpty && countryIsoA2 != 'N/A'
                  ? Image.network(
                'https://flagcdn.com/w80/${countryIsoA2.toLowerCase()}.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 국기 로딩 실패 시 기본 마커 표시
                  return Container(
                    color: bgColor,
                    child: Center(
                      child: Text(
                        charToDisplay,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.0 * _markerIconSize,
                        ),
                      ),
                    ),
                  );
                },
              )
                  : Container(
                color: bgColor,
                child: Center(
                  child: Text(
                    charToDisplay,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0 * _markerIconSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (showIcon && showName) // 아이콘과 이름 모두 표시될 때만 간격 추가
          const SizedBox(height: 10),
        if (showName) // showCitiesAirportsNames 스위치에 따라 이름 렌더링
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.9),
                  Colors.black.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: isSelected ? 3 : 1), // 선택 시 테두리 두껍게
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  nameToDisplay,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.0 * _markerNameSize,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }


  Widget _buildTransportInfoTextContent(TripLeg leg) {
    String info = '';
    if (leg.transportType == 'flight' && leg.transportIdentifier != null) {
      info = leg.transportIdentifier!;
    } else if (leg.companyName != null) {
      info = leg.companyName!;
    } else {
      info = leg.transportType;
    }
    return Text(
      info,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _fitBounds(List<Marker> markers) {
    if (markers.isEmpty) return;

    double minLat = markers.first.point.latitude;
    double maxLat = markers.first.point.latitude;
    double minLng = markers.first.point.longitude;
    double maxLng = markers.first.point.longitude;

    for (final marker in markers) {
      minLat = min(minLat, marker.point.latitude);
      maxLat = max(maxLat, marker.point.latitude);
      minLng = min(minLng, marker.point.longitude);
      maxLng = max(maxLng, marker.point.longitude);
    }

    final bounds = LatLngBounds(
      LatLng(minLat - 3, minLng - 3),
      LatLng(maxLat + 3, maxLng + 3),
    );

    _mapController.fitCamera(CameraFit.bounds(bounds: bounds));
  }


  List<LatLng> _getBezierCurvePoints(LatLng p0, LatLng p1, LatLng p2, int numPoints) {
    final List<LatLng> points = [];
    for (int i = 0; i <= numPoints; i++) {
      double t = i / numPoints;
      double u = 1 - t;
      double tt = t * t;
      double uu = u * u;

      double x = uu * p0.longitude + 2 * u * t * p1.longitude + tt * p2.longitude;
      double y = uu * p0.latitude + 2 * u * t * p1.latitude + tt * p2.latitude;
      points.add(LatLng(y, x));
    }
    return points;
  }

  String? _getCityNameFromLatLng(LatLng point) {
    return null; // 더 이상 사용되지 않음
  }

  String _getShortLocationName(LatLng point) {
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);
    try {
      final foundAirport = airportProvider.allAirports.firstWhere(
            (a) => (a.latitude - point.latitude).abs() < 0.1 && (a.longitude - point.longitude).abs() < 0.1,
      );
      return foundAirport.iataCode;
    } catch (e) {
      return '${point.latitude.toStringAsFixed(1)},${point.longitude.toStringAsFixed(1)}';
    }
  }

  String _formatDurationDays(String? duration) {
    if (duration == null || duration.isEmpty || duration.toLowerCase() == 'unknown') {
      return '0';
    }
    final match = RegExp(r'(\d+)\s*days?').firstMatch(duration.toLowerCase());
    if (match != null) {
      return match.group(1)!;
    }
    final int? days = int.tryParse(duration.trim());
    if (days != null) {
      return days.toString();
    }
    return '0';
  }

  String _formatDuration(String? duration) {
    if (duration == null || duration.isEmpty || duration.toLowerCase() == 'unknown') {
      return '알 수 없음';
    }

    if (duration.contains('h') || duration.contains('m')) {
      return duration;
    }

    final int? minutes = int.tryParse(duration);
    if (minutes != null) {
      if (minutes < 60) {
        return '${minutes}분';
      } else {
        final hours = minutes ~/ 60;
        final remainingMinutes = minutes % 60;
        return '${hours}시간 ${remainingMinutes}분'.trim();
      }
    }
    return duration;
  }

  String _calculateApproximateDuration(String? departureTime, String? arrivalTime) {
    if (departureTime == null || arrivalTime == null || departureTime == 'Unknown' || arrivalTime == 'Unknown') {
      return 'Unknown';
    }

    try {
      final depParts = departureTime.split(':').map(int.parse).toList();
      final arrParts = arrivalTime.split(':').map(int.parse).toList();

      final depHour = depParts[0];
      final depMinute = depParts[1];
      final arrHour = arrParts[0];
      final arrMinute = arrParts[1];

      int durationMinutes = (arrHour * 60 + arrMinute) - (depHour * 60 + depMinute);

      if (durationMinutes < 0) {
        durationMinutes += 24 * 60;
      }

      if (durationMinutes == 0) return '0m';

      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;

      String result = '';
      if (hours > 0) result += '${hours}h';
      if (minutes > 0) result += '${minutes}m';

      return result.isEmpty ? 'Unknown' : result;
    } catch (e) {
      developer.log('Error calculating approximate duration: $e', name: 'TripMapScreen._calculateApproximateDuration');
      return 'Unknown';
    }
  } // ← _calculateApproximateDuration 함수 끝

// 이동시간을 초 단위로 변환하는 함수 (새로 추가)
  int _parseDurationToSeconds(String? duration) {
    print('🔍 받은 duration: $duration');
    if (duration == null || duration.isEmpty || duration == 'Unknown') {
      return 3600; // 기본값: 1시간
    }

    int totalSeconds = 0;

    // "2h30m" 형태 파싱
    final hourMatch = RegExp(r'(\d+)h').firstMatch(duration);
    final minuteMatch = RegExp(r'(\d+)m').firstMatch(duration);

    if (hourMatch != null) {
      totalSeconds += int.parse(hourMatch.group(1)!) * 3600; // 시간을 초로 변환
    }

    if (minuteMatch != null) {
      totalSeconds += int.parse(minuteMatch.group(1)!) * 60; // 분을 초로 변환
    }

    // 만약 시간이나 분이 없으면 숫자만 있는지 확인 (분 단위로 가정)
    if (totalSeconds == 0) {
      final numberMatch = RegExp(r'(\d+)').firstMatch(duration);
      if (numberMatch != null) {
        totalSeconds = int.parse(numberMatch.group(1)!) * 60; // 분으로 가정
      }
    }

    return totalSeconds > 0 ? totalSeconds : 3600; // 최소 1시간
  }

// 경로별 애니메이션 컨트롤러 생성 (새로 추가)
  // 경로별 애니메이션 컨트롤러 생성
  // ## 1. 이 메서드 전체를 복사해서 기존 코드를 덮어쓰세요. ##

  void _createAnimationControllers() {
    // 기존 컨트롤러들 정리
    for (var controller in _legAnimationControllers.values) {
      controller.dispose();
    }
    _legAnimationControllers.clear();
    _legAnimations.clear();

    // 날짜순으로 정렬
    final sortedLegs = List<EditableTripLeg>.from(_currentTripLegs);
    sortedLegs.sort((a, b) {
      if (a.date == null && b.date == null) {
        return a.sequence.compareTo(b.sequence); // 날짜가 둘 다 없으면 sequence로
      }
      if (a.date == null) return 1;
      if (b.date == null) return -1;

      final dateComparison = a.date!.compareTo(b.date!);
      if (dateComparison != 0) return dateComparison; // 날짜가 다르면 날짜순

      return a.sequence.compareTo(b.sequence); // 같은 날짜면 sequence순
    });

    // 첫 번째 경로의 날짜로 현재 시간 초기화
    if (sortedLegs.isNotEmpty && sortedLegs.first.date != null) {
      _currentTripTime = DateTime.tryParse(sortedLegs.first.date!);
    }

    // 각 경로별로 애니메이션 컨트롤러 생성
    for (int i = 0; i < sortedLegs.length; i++) {
      final leg = sortedLegs[i];

      // 이동시간을 초로 변환
      final durationInSeconds = _parseDurationToSeconds(leg.duration);

      // 1시간당 2초로 애니메이션 시간 계산 (최소 1초)
      final animationDuration = Duration(
          milliseconds: max(1000, ((durationInSeconds / 3600) * 2000 / _animationSpeedMultiplier).round())
      );
      // 애니메이션 컨트롤러 생성
      final controller = AnimationController(
        duration: animationDuration,
        vsync: this,
      );

      // 애니메이션 값 생성 (0.0에서 1.0까지)
      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.linear, // 일정한 속도로 이동
      ));

      // 애니메이션 완료 시 다음 애니메이션 시작
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            // 다음 애니메이션이 있으면 시작
            if (i + 1 < sortedLegs.length) {
              final nextLeg = sortedLegs[i + 1];
              final nextController = _legAnimationControllers[nextLeg.key];
              if (nextController != null) {
                nextController.forward();
              }
            } else {
              // 모든 애니메이션 완료
              _isAnimationPlaying = false;
            }
          });
        }
      });

      _legAnimationControllers[leg.key] = controller;
      _legAnimations[leg.key] = animation;
    }

    // 도시 체류 애니메이션 컨트롤러 생성
    for (final stay in _cityStays) {
      final animationDuration = Duration(
          milliseconds: (stay.durationDays * 2000 / _animationSpeedMultiplier).round()
      );

      final controller = AnimationController(
        duration: animationDuration,
        vsync: this,
      );

      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.linear,
      ));

      animation.addListener(() {
        if (mounted && controller.isAnimating) {
          try {
            final stayStartDate = DateTime.parse(stay.arrivalDate);
            final totalStaySeconds = stay.durationDays * 24 * 3600;
            final elapsedSeconds = (totalStaySeconds * animation.value).toInt();

            setState(() {
              _currentTripTime = stayStartDate.add(Duration(seconds: elapsedSeconds));
            });
          } catch (e) {
            developer.log('Error updating stay time: $e', name: 'TripMapScreen');
          }
        }
      });

      _legAnimationControllers[stay.key] = controller;
      _legAnimations[stay.key] = animation;
    }

    // 각 애니메이션에 리스너 추가 (실시간 업데이트)
    for (int i = 0; i < sortedLegs.length; i++) {
      final leg = sortedLegs[i];
      final animation = _legAnimations[leg.key];
      if (animation != null) {
        animation.addListener(() {
          if (mounted) {
            try {
              final controller = _legAnimationControllers[leg.key];
              if (controller == null || !controller.isAnimating) return;

              if (leg.date == null) return;

              // AI Summary에서 해당 leg의 출발 시간 찾기
              DateTime legStartDateTime;

              // Flight 정보에서 시간 찾기
              if (leg.transportType == 'flight') {
                final flightDetail = widget.summary.flights
                    .expand((log) => log.flights)
                    .firstWhereOrNull((f) =>
                f.origin == leg.originCityName &&
                    f.destination == leg.destinationCityName &&
                    f.flightDate == leg.date);

                if (flightDetail != null && flightDetail.departureTime != null && flightDetail.departureTime != 'Unknown') {
                  // "HH:mm" 형식의 시간을 파싱
                  final timeParts = flightDetail.departureTime!.split(':');
                  if (timeParts.length == 2) {
                    final hour = int.tryParse(timeParts[0]) ?? 0;
                    final minute = int.tryParse(timeParts[1]) ?? 0;
                    legStartDateTime = DateTime.parse(leg.date!).add(Duration(hours: hour, minutes: minute));
                  } else {
                    legStartDateTime = DateTime.parse(leg.date!);
                  }
                } else {
                  legStartDateTime = DateTime.parse(leg.date!);
                }
              } else {
                // 다른 교통수단은 날짜만 사용 (시간 정보 없음)
                legStartDateTime = DateTime.parse(leg.date!);
              }

              // leg의 총 소요 시간 (초 단위)
              final totalLegDurationInSeconds = _parseDurationToSeconds(leg.duration);

              // 애니메이션 진행률에 따른 경과 시간 (초 단위)
              final elapsedSeconds = (totalLegDurationInSeconds * animation.value).toInt();

              setState(() {
                // 시작 시간에 경과 시간을 더해 현재 시간 업데이트
                _currentTripTime = legStartDateTime.add(Duration(seconds: elapsedSeconds));
              });
            } catch (e) {
              developer.log('Error updating trip time: $e', name: 'TripMapScreen._createAnimationControllers');
              if (_currentTripTime == null && leg.date != null) {
                setState(() {
                  _currentTripTime = DateTime.tryParse(leg.date!);
                });
              }
            }
          }
        });
      }
    }
  }
  // 애니메이션 마커들 생성
  List<Marker> _buildAnimationMarkers() {
    List<Marker> animationMarkers = [];

    for (final leg in _currentTripLegs) {
      final animation = _legAnimations[leg.key];
      final controller = _legAnimationControllers[leg.key];

      // 애니메이션이 진행 중일 때만 마커 표시 (완료된 것은 제외)
      if (animation != null && controller != null && controller.isAnimating) {  // ← isCompleted 조건 제거

        final progress = animation.value;

        final lat = leg.originPoint.latitude +
            (leg.destinationPoint.latitude - leg.originPoint.latitude) * progress;
        final lng = leg.originPoint.longitude +
            (leg.destinationPoint.longitude - leg.originPoint.longitude) * progress;

        final deltaLat = leg.destinationPoint.latitude - leg.originPoint.latitude;
        final deltaLng = leg.destinationPoint.longitude - leg.originPoint.longitude;
        final angle = atan2(deltaLng, deltaLat);

        double finalAngle = angle;
        switch (leg.transportType) {
          case 'flight':
            finalAngle = angle + (pi / 2) - (pi / 4);
            break;
          case 'train':
          case 'bus':
          case 'car':
            finalAngle = angle;
            break;
          case 'ferry':
            finalAngle = angle - (pi / 4);
            break;
          default:
            finalAngle = angle;
        }

        animationMarkers.add(Marker(
          point: LatLng(lat, lng),
          width: 30,
          height: 30,
          child: Transform.rotate(
            angle: finalAngle,
            child: Container(
              decoration: BoxDecoration(
                color: leg.customColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: leg.customColor.withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                _getTransportIcon(leg.transportType, leg.transportIdentifier),
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ));
      }
    }

    // 체류 중인 도시에 사람 아이콘 표시
    for (final stay in _cityStays) {
      final controller = _legAnimationControllers[stay.key];

      if (controller != null && controller.isAnimating) {
        animationMarkers.add(Marker(
          point: stay.point,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.6),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
        ));
      }
    }

    return animationMarkers;
  }

  Widget _buildTransportStylePanel() {
    return Positioned(
      left: 20,
      bottom: 120,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey[800]!.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transport Styles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ..._transportLineStyles.entries.map((entry) {
              return _buildTransportStyleItem(entry.key, entry.value);
            }).toList(),
          ],
        ),
      ),
    );


  }
  // 위치 패널 (국가/도시)
  // 위치 패널 (국가/도시)
  Widget _buildLocationPanel() {
    // 날짜별로 데이터 정리
    Map<String, List<Map<String, dynamic>>> groupedData = {};

    // 도시 정보에서 날짜 가져오기
    // 도시 정보에서 날짜 가져오기 (머무는 모든 날짜에 표시)
    for (final cityDetailMap in widget.matchedCitiesWithDetails) {
      final City city = cityDetailMap['city'] as City;
      final String? duration = cityDetailMap['duration'] as String?;
      final String? aiProvidedName = cityDetailMap['aiProvidedName'] as String?;
      final String? arrivalDate = cityDetailMap['arrivalDate'] as String?;
      final String? departureDate = cityDetailMap['departureDate'] as String?;

      // 도착일과 출발일이 모두 있으면 머무는 모든 날짜에 추가
      if (arrivalDate != null && arrivalDate != 'Unknown' &&
          departureDate != null && departureDate != 'Unknown') {
        try {
          final arrival = DateTime.parse(arrivalDate);
          final departure = DateTime.parse(departureDate);

          // 도착일부터 출발일까지 모든 날짜에 추가
          for (int i = 0; i <= departure.difference(arrival).inDays; i++) {
            final currentDate = arrival.add(Duration(days: i));
            final dateKey = currentDate.toIso8601String().split('T')[0]; // YYYY-MM-DD

            if (!groupedData.containsKey(dateKey)) {
              groupedData[dateKey] = [];
            }

            // 각 날짜에 해당 도시 정보 추가
            groupedData[dateKey]!.add({
              'type': 'city',
              'name': city.name,
              'duration': duration,
              'arrivalDate': arrivalDate,
              'departureDate': departureDate,
              'stayInfo': i == 0 ? 'Arrival' : (i == departure.difference(arrival).inDays ? 'Departure' : 'Stay'),
              'point': LatLng(city.latitude, city.longitude),
            });
          }
        } catch (e) {
          // 날짜 파싱 실패 시 기존 방식으로 폴백
          String dateKey = arrivalDate;
          if (!groupedData.containsKey(dateKey)) {
            groupedData[dateKey] = [];
          }
          groupedData[dateKey]!.add({
            'type': 'city',
            'name': city.name,
            'duration': duration,
            'arrivalDate': arrivalDate,
            'departureDate': departureDate,
            'stayInfo': 'Stay',
            'point': LatLng(city.latitude, city.longitude),
          });
        }
      } else {
        // 날짜 정보가 불완전한 경우 기존 방식
        String dateKey = arrivalDate ?? 'Unknown Date';
        if (!groupedData.containsKey(dateKey)) {
          groupedData[dateKey] = [];
        }
        groupedData[dateKey]!.add({
          'type': 'city',
          'name': city.name,
          'duration': duration,
          'arrivalDate': arrivalDate,
          'departureDate': departureDate,
          'stayInfo': 'Stay',
          'point': LatLng(city.latitude, city.longitude),
        });
      }
    }
    // 날짜순으로 정렬
    var sortedEntries = groupedData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));





    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      bottom: 100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.location_city, color: Colors.white),
                  const SizedBox(width: 10),
                  const Text(
                    'Locations',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showLocationPanel = false;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // 내용
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: sortedEntries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 날짜 헤더
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 해당 날짜의 항목들
                      ...entry.value.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_city, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    if (item['duration'] != null)
                                      Text(
                                        '${item['stayInfo']} ${item['duration'] != null ? "(${item['duration']})" : ""}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 이동수단 패널
  // 이동수단 패널
  // 이동수단 패널 (O버전 스타일)
  // 이동수단 패널 (O버전과 동일한 스타일)
  // 교통수단 항목과 지도 경로의 색상을 매칭하는 함수
  Color _getMatchingLegColor(Map<String, dynamic> transportItem) {
    // 지도에 그려진 경로들(_currentTripLegs)에서 매칭되는 경로 찾기
    for (final leg in _currentTripLegs) {
      bool isMatching = false;

      // 교통수단 타입이 같은지 확인
      if (leg.transportType == transportItem['transportType']) {
        // 출발지와 도착지 이름으로 매칭 시도
        final itemTitle = transportItem['title'] as String;
        final legTitle = '${leg.originCityName ?? ''} → ${leg.destinationCityName ?? ''}';

        if (itemTitle == legTitle) {
          isMatching = true;
        } else if (transportItem['identifier'] != null &&
            leg.transportIdentifier != null &&
            transportItem['identifier'] == leg.transportIdentifier) {
          // 편명/식별자로 매칭 시도
          isMatching = true;
        }
      }

      if (isMatching) {
        return leg.customColor; // 지도 경로의 색상 반환
      }
    }

    // 매칭되는 경로가 없으면 검은색 반환
    return Colors.black;
  }
  Widget _buildTransportationPanel() {
    //print('🔄 _buildTransportationPanel 호출됨');
    //print('📊 _isTransportDataProcessed: $_isTransportDataProcessed');
    //print('📦 _processedTransportData.isEmpty: ${_processedTransportData.isEmpty}');



    if (_isTransportDataProcessed && _processedTransportData.isNotEmpty) {
      final sortedTransportEntries = _processedTransportData.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      // 일단 빈 공간으로 둠 (나중에 처리)
    }



    // 날짜별로 이동수단 데이터 정리
    Map<String, List<Map<String, dynamic>>> groupedTransportData = {};


    final List<FlightDetail> allFlights = widget.summary.flights.expand((airlineLog) => airlineLog.flights).toList();
    for (final flightDetail in allFlights) {
      try {
        String dateKey = flightDetail.flightDate ?? 'Unknown Date';

        if (!groupedTransportData.containsKey(dateKey)) {
          groupedTransportData[dateKey] = [];
        }

        String? airlineName;
        try {
          airlineName = widget.summary.flights.firstWhere((log) => log.flights.contains(flightDetail)).airlineName;
        } catch (e) {
          airlineName = 'Unknown Airline';
        }

        // flight의 실제 duration 찾기
        String flightDuration = 'Unknown';

        for (final leg in _currentTripLegs) {
          if (leg.transportType == 'flight' &&
              leg.originCityName == flightDetail.origin &&
              leg.destinationCityName == flightDetail.destination) {
            flightDuration = leg.duration ?? 'Unknown';
            break;
          }
        }

        // duration이 없거나 Unknown이면 AI Summary 직접 사용
        if (flightDuration == 'Unknown' || flightDuration.isEmpty) {

          if (flightDetail.duration != null &&
              flightDetail.duration!.isNotEmpty &&
              flightDetail.duration! != 'Unknown' &&
              flightDetail.duration! != 'N/A') {
            flightDuration = flightDetail.duration!;
          } else {
            flightDuration = 'Calculating...';
          }
        }


        final flightIndex = allFlights.indexOf(flightDetail);
        final flightData = {
          'title': '${flightDetail.origin} → ${flightDetail.destination}',
          'company': airlineName,
          'identifier': flightDetail.flightNumber,
          'duration': flightDuration,
          'transportType': 'flight',
          'sequence': flightDetail.sequence, // 🆕 이 줄을 추가해주세요!
          'isSelected': false,
          'legIndex': 0,
          'date': flightDetail.flightDate,
        };

        flightData['legColor'] = _getMatchingLegColor(flightData);
        flightData['uniqueId'] = 'flight_${flightIndex}_${flightDetail.origin}_${flightDetail.destination}';

        if (groupedTransportData[dateKey] != null) {
          groupedTransportData[dateKey]!.add(flightData);
        }
      } catch (e) {
        print('Error processing flight: $e');
      }
    }

    // 2. 기차 데이터 추가
    for (final trainLog in widget.summary.trains) {
      final trainIndex = widget.summary.trains.indexOf(trainLog);
      String dateKey = trainLog.date ?? 'Unknown Date';

      if (!groupedTransportData.containsKey(dateKey)) {
        groupedTransportData[dateKey] = [];
      }

      final trainData = {
        'title': '${trainLog.origin ?? 'Unknown'} → ${trainLog.destination ?? 'Unknown'}',
        'company': trainLog.trainCompany,
        'identifier': trainLog.trainCompany,
        'duration': trainLog.duration ?? 'Unknown',
        'transportType': 'train',
        'sequence': trainLog.sequence, // 🆕 이 줄 추가!
        'isSelected': false,
        'legIndex': 0,
      };

      trainData['legColor'] = _getMatchingLegColor(trainData);
      trainData['uniqueId'] = 'train_${trainIndex}_${trainLog.origin ?? 'unknown'}_${trainLog.destination ?? 'unknown'}';

      groupedTransportData[dateKey]!.add(trainData);
    }
    // 3. 버스 데이터 추가
    for (final busLog in widget.summary.buses) {
      final busIndex = widget.summary.buses.indexOf(busLog);
      String dateKey = busLog.date ?? 'Unknown Date';

      if (!groupedTransportData.containsKey(dateKey)) {
        groupedTransportData[dateKey] = [];
      }

      final busData = {
        'title': '${busLog.origin ?? 'Unknown'} → ${busLog.destination ?? 'Unknown'}',
        'company': busLog.busCompany,
        'identifier': busLog.busCompany,
        'duration': busLog.duration ?? 'Unknown',
        'transportType': 'bus',
        'sequence': busLog.sequence, // 🆕 이 줄 추가!
        'isSelected': false,
        'legIndex': 0,
      };

      busData['legColor'] = _getMatchingLegColor(busData);
      busData['uniqueId'] = 'bus_${busIndex}_${busLog.origin ?? 'unknown'}_${busLog.destination ?? 'unknown'}';

      groupedTransportData[dateKey]!.add(busData);
    }
    // 4. 페리 데이터 추가
    for (final ferryLog in widget.summary.ferries) {
      final ferryIndex = widget.summary.ferries.indexOf(ferryLog);
      String dateKey = ferryLog.date ?? 'Unknown Date';

      if (!groupedTransportData.containsKey(dateKey)) {
        groupedTransportData[dateKey] = [];
      }

      final ferryData = {
        'title': '${ferryLog.origin ?? 'Unknown'} → ${ferryLog.destination ?? 'Unknown'}',
        'company': ferryLog.ferryName,
        'identifier': ferryLog.ferryName,
        'duration': ferryLog.duration ?? 'Unknown',
        'transportType': 'ferry',
        'sequence': ferryLog.sequence, // 🆕 이 줄 추가!
        'isSelected': false,
        'legIndex': 0,
      };

      ferryData['legColor'] = _getMatchingLegColor(ferryData);
      ferryData['uniqueId'] = 'ferry_${ferryIndex}_${ferryLog.origin ?? 'unknown'}_${ferryLog.destination ?? 'unknown'}';

      groupedTransportData[dateKey]!.add(ferryData);
    }
    // 5. 자동차 데이터 추가
    for (final carLog in widget.summary.cars) {
      final carIndex = widget.summary.cars.indexOf(carLog);
      String dateKey = carLog.date ?? 'Unknown Date';

      if (!groupedTransportData.containsKey(dateKey)) {
        groupedTransportData[dateKey] = [];
      }

      final carData = {
        'title': '${carLog.origin ?? 'Unknown'} → ${carLog.destination ?? 'Unknown'}',
        'company': carLog.carType,
        'identifier': carLog.carType,
        'duration': carLog.duration ?? 'Unknown',
        'transportType': 'car',
        'sequence': carLog.sequence, // 🆕 이 줄 추가!
        'isSelected': false,
        'legIndex': 0,
      };

      carData['legColor'] = _getMatchingLegColor(carData);
      carData['uniqueId'] = 'car_${carIndex}_${carLog.origin ?? 'unknown'}_${carLog.destination ?? 'unknown'}';

      groupedTransportData[dateKey]!.add(carData);
    }
    // 6. 사용자가 실제로 추가한 교통수단만 데이터 추가
    for (final customLeg in _currentTripLegs) {
      bool isUserAdded = true;

      // 원본 항공편과 비교
      for (final airlineLog in widget.summary.flights) {
        for (final flight in airlineLog.flights) {

          if (customLeg.originCityName == flight.origin &&
              customLeg.destinationCityName == flight.destination &&
              customLeg.transportType == 'flight') {
            isUserAdded = false;
            break;
          }
        }
        if (!isUserAdded) break;
      }

      // 원본 기차와 비교
      if (isUserAdded) {
        for (final train in widget.summary.trains) {
          if (customLeg.originCityName == train.origin &&
              customLeg.destinationCityName == train.destination &&
              customLeg.transportType == 'train') {
            isUserAdded = false;
            break;
          }
        }
      }

      // 원본 버스와 비교
      if (isUserAdded) {
        for (final bus in widget.summary.buses) {
          if (customLeg.originCityName == bus.origin &&
              customLeg.destinationCityName == bus.destination &&
              customLeg.transportType == 'bus') {
            isUserAdded = false;
            break;
          }
        }
      }

      // 원본 페리와 비교
      if (isUserAdded) {
        for (final ferry in widget.summary.ferries) {
          if (customLeg.originCityName == ferry.origin &&
              customLeg.destinationCityName == ferry.destination &&
              customLeg.transportType == 'ferry') {
            isUserAdded = false;
            break;
          }
        }
      }

      // 원본 자동차와 비교
      if (isUserAdded) {
        for (final car in widget.summary.cars) {
          if (customLeg.originCityName == car.origin &&
              customLeg.destinationCityName == car.destination &&
              customLeg.transportType == 'car') {
            isUserAdded = false;
            break;
          }
        }
      }

      // 정말 사용자가 추가한 것만 추가
      if (isUserAdded) {
        String dateKey = customLeg.date ?? 'Unknown Date';

        if (!groupedTransportData.containsKey(dateKey)) {
          groupedTransportData[dateKey] = [];
        }

        groupedTransportData[dateKey]!.add({
          'title': '${customLeg.originCityName ?? 'Custom Origin'} → ${customLeg.destinationCityName ?? 'Custom Destination'}',
          'company': customLeg.transportIdentifier,
          'identifier': customLeg.transportIdentifier,
          'duration': customLeg.duration ?? 'Custom',
          'transportType': customLeg.transportType,
          'legColor': customLeg.customColor,
          'isSelected': false,
          'legIndex': customLeg.legIndex,
          'uniqueId': 'custom_${customLeg.originCityName ?? 'unknown'}_${customLeg.destinationCityName ?? 'unknown'}_${customLeg.transportType}_${DateTime.now().millisecondsSinceEpoch}',
        });
      }
    }
    groupedTransportData.forEach((dateKey, items) {
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
      }
    });


    _cachedTransportData = groupedTransportData;
    groupedTransportData.forEach((dateKey, items) {
      items.sort((a, b) {
        final sequenceA = a['sequence'] as int? ?? 0;
        final sequenceB = b['sequence'] as int? ?? 0;
        return sequenceA.compareTo(sequenceB);
      });
    });

    var sortedTransportEntries = groupedTransportData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    _processedTransportData = groupedTransportData;
    _isTransportDataProcessed = true;
    //print('💾 캐시에 데이터 저장 완료');
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        height: 200, // X버전과 동일한 높이
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.black.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // 헤더 부분 (X버전과 동일)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.directions, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Transportation',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showTransportPanel = false;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // 날짜별 섹션들
            // 날짜 헤더와 교통수단 카드를 함께 가로 배치
            Expanded(
              child: sortedTransportEntries.isEmpty
                  ? const Center(
                child: Text(
                  'No transportation data available',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              )
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: sortedTransportEntries.length,
                itemBuilder: (context, dateIndex) {
                  final entry = sortedTransportEntries[dateIndex];

                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 날짜 헤더
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              color: Colors.yellow,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // 해당 날짜의 교통수단 카드들
                        Expanded(
                          child: Row(
                            children: entry.value.map((item) {
                              final index = entry.value.indexOf(item);
                              final bool isAnimating = _isTransportItemAnimating(item);
                              final double? animationProgress = _getTransportItemProgress(item);
                              return _buildTransportCard(item, index, isAnimating, animationProgress);
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

// 2단계: 개별 이동수단 카드 위젯 생성 (X버전 스타일)
  Widget _buildTransportCard(Map<String, dynamic> item, int index, bool isAnimating, double? animationProgress) {
    final String? itemId = item['uniqueId'] as String?;
    final isSelected = _selectedTransportId == itemId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTransportId = isSelected ? null : itemId;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? item['legColor'].withOpacity(0.3)
              : isAnimating
              ? item['legColor'].withOpacity(0.4)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? item['legColor']
                : isAnimating
                ? item['legColor'].withOpacity(0.8)
                : Colors.transparent,
            width: isAnimating ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: item['legColor'],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  item['title'],
                  style: TextStyle(
                    color: isAnimating ? Colors.yellow : Colors.white,
                    fontWeight: isAnimating ? FontWeight.w900 : FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 메인 식별자 (항공편 번호, 기차/버스 회사, 페리 이름)
            Text(
              item['identifier'] ?? item['company'] ?? item['transportType'],
              style: TextStyle(
                color: isAnimating
                    ? Colors.white
                    : Colors.white.withOpacity(0.8),
                fontSize: 10,
                fontWeight: isAnimating ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // 이동 시간 정보
            // 이동 시간 정보
            if (item['duration'] != null && item['duration'] != 'Unknown')
              Text(
                _formatDuration(item['duration']),
                style: TextStyle(
                  color: isAnimating
                      ? Colors.white.withOpacity(0.9)
                      : Colors.white.withOpacity(0.6),
                  fontSize: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassMorphicCard({
    required String title,
    required String imagePath,
    required List<Color> gradient,
    required IconData icon,
    String? company,
    String? identifier,
    String? duration,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(1, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        if (company != null || identifier != null)
                          Text(
                            '${company ?? ""}${identifier != null ? " $identifier" : ""}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (duration != null && duration != 'Unknown')
                          Text(
                            duration,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white60,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

// 이동수단별 그라디언트 색상 (O버전과 동일)
  List<Color> _getTransportGradient(String transportType) {
    switch (transportType) {
      case 'flight':
        return [const Color(0xFF6B73FF), const Color(0xFF9B59B6)];
      case 'train':
        return [const Color(0xFF11998E), const Color(0xFF38EF7D)];
      case 'bus':
        return [const Color(0xFFFF9A8B), const Color(0xFFA8E6CF)];
      case 'ferry':
        return [const Color(0xFF48CAE4), const Color(0xFF0077B6)];
      case 'car':
        return [const Color(0xFF834D9B), const Color(0xFFD04ED6)];
      default:
        return [const Color(0xFF667EEA), const Color(0xFF764BA2)];
    }
  }

// 이동수단별 색상 반환 헬퍼 함수
  Color _getTransportColor(String transportType) {
    switch (transportType) {
      case 'flight':
        return Colors.blue;
      case 'train':
        return Colors.green;
      case 'bus':
        return Colors.orange;
      case 'ferry':
        return Colors.teal;
      case 'car':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

// 각 교통수단별 스타일 아이템
  Widget _buildTransportStyleItem(String transportType, String currentStyle) {
    // 교통수단 아이콘 매핑
    IconData getIcon() {
      switch (transportType) {
        case 'flight': return Icons.airplanemode_active;
        case 'train': return Icons.train;
        case 'bus': return Icons.directions_bus;
        case 'ferry': return Icons.directions_boat;
        case 'car': return Icons.directions_car;
        default: return Icons.help;
      }
    }

    // 선 스타일 한글명 매핑
    String getStyleName(String style) {
      switch (style) {
        case 'solid': return 'Solid';
        case 'dotted': return 'Dotted';
        case 'spring': return 'Spring';
        case 'wavy': return 'Wavy';
        case 'shadow': return 'Shadow';
        default: return 'Solid';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(getIcon(), color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              transportType.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () {
              _showStyleChangeDialog(transportType, currentStyle);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                getStyleName(currentStyle),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

// 스타일 변경 다이얼로그
  void _showStyleChangeDialog(String transportType, String currentStyle) {
    final Map<String, String> styleOptions = {
      'Solid': 'solid',
      'Dotted': 'dotted',
      'Spring': 'spring',
      'Wavy': 'wavy',
      'Shadow': 'shadow',
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change ${transportType.toUpperCase()} Line Style'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: styleOptions.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                leading: Radio<String>(
                  value: entry.value,
                  groupValue: currentStyle,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        _transportLineStyles[transportType] = value;
                        // 기존 경로들의 스타일도 업데이트
                        for (int i = 0; i < _currentTripLegs.length; i++) {
                          if (_currentTripLegs[i].transportType == transportType) {
                            _currentTripLegs[i] = _currentTripLegs[i].copyWith(lineStyle: value);
                          }
                        }
                      });
                      Navigator.of(context).pop();
                    }
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // 애니메이션 속도 업데이트 함수
  void _updateAnimationSpeed() {
    if (!_isAnimationPlaying) return;

    bool hasRunningAnimation = false;
    EditableTripLeg? currentRunningLeg;

    for (var controller in _legAnimationControllers.values) {
      if (controller.isAnimating) {
        hasRunningAnimation = true;
        currentRunningLeg = _currentTripLegs.firstWhereOrNull((leg) =>
        _legAnimationControllers[leg.key] == controller);
        break;
      }
    }

    if (hasRunningAnimation && currentRunningLeg != null) {
      final controller = _legAnimationControllers[currentRunningLeg.key]!;
      final currentValue = controller.value;

      controller.stop();

      final durationInSeconds = _parseDurationToSeconds(currentRunningLeg.duration);
      final newDuration = Duration(
          milliseconds: max(1000, ((durationInSeconds / 3600) * 2000 / _animationSpeedMultiplier).round())
      );

      final newController = AnimationController(
        duration: newDuration,
        vsync: this,
      );

      newController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            final sortedLegs = List<EditableTripLeg>.from(_currentTripLegs);
            sortedLegs.sort((a, b) {
              if (a.date == null && b.date == null) return 0;
              if (a.date == null) return 1;
              if (b.date == null) return -1;
              return a.date!.compareTo(b.date!);
            });

            final currentIndex = sortedLegs.indexOf(currentRunningLeg!);
            if (currentIndex != -1 && currentIndex + 1 < sortedLegs.length) {
              final nextLeg = sortedLegs[currentIndex + 1];
              final nextController = _legAnimationControllers[nextLeg.key];
              if (nextController != null) {
                nextController.forward();
              }
            } else {
              _isAnimationPlaying = false;
            }
          });
        }
      });

      newController.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      newController.value = currentValue;
      _legAnimationControllers[currentRunningLeg.key] = newController;
      _legAnimations[currentRunningLeg.key] = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: newController,
        curve: Curves.linear,
      ));

      newController.forward();
    }
  }

  void _startAnimation() {
    for (var controller in _legAnimationControllers.values) {
      controller.reset();
    }

    final sortedLegs = List<EditableTripLeg>.from(_currentTripLegs);
    sortedLegs.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });

    if (sortedLegs.isNotEmpty) {
      final firstController = _legAnimationControllers[sortedLegs.first.key];
      if (firstController != null) {
        firstController.forward();
        _isAnimationPlaying = true;
      }
    }
  }
}





// Color Extension (Triplog_entry.dart에 이어서 추가)
extension ColorExtension on Color {
  Color darker([int percent = 10]) {
    assert(percent >= 0 && percent <= 100);
    final p = percent / 100.0;
    return Color.fromARGB(
      alpha,
      (red * (1.0 - p)).round(),
      (green * (1.0 - p)).round(),
      (blue * (1.0 - p)).round(),
    );
  }
}