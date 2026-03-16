// lib/screens/ai_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 이 줄을 추가하세요.
import 'package:jidoapp/screens/ai_itinerary_view.dart'; // 👈 이 줄 추가
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/models/city_model.dart'; // City 모델 임포트
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/unesco_model.dart'; // 🆕 UNESCO 모델 추가
import 'package:jidoapp/models/unesco_model.dart'; // 🆕 UNESCO 모델 추가
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/models/visit_details_model.dart'; // DateRange 포함
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart'; // 🆕 UNESCO 프로바이더 추가
import 'package:jidoapp/providers/unesco_provider.dart'; // 🆕 UNESCO 프로바이더 추가
import 'package:jidoapp/screens/trip_map_screen.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math'; // For Haversine formula
import 'package:collection/collection.dart';
import 'package:jidoapp/services/ai_service.dart'; // AiService 임포트 추가
import 'package:jidoapp/models/city_visit_detail_model.dart'; // CityVisitDetail 명확히 임포트
import 'package:intl/intl.dart'; // 날짜 포맷팅을 위해 추가
import 'package:shared_preferences/shared_preferences.dart'; // 추가
import 'dart:developer' as developer; // 🆕 이 줄을 추가하세요
import 'package:country_flags/country_flags.dart';


enum _AiViewMode { summary, itinerary }

class AiSummaryScreen extends StatefulWidget {
  // 🔄 final AiSummary summary; -> final TripLogEntry entry;
  final TripLogEntry entry;

  // 🔄 생성자 변경
  const AiSummaryScreen({super.key, required this.entry});

  @override
  State<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

class _AiSummaryScreenState extends State<AiSummaryScreen> {
  _AiViewMode _currentView = _AiViewMode.summary;
  Future<String>? _itineraryFuture;

  // 🆕 [추가] 초기 국가 매칭 중인지 확인하는 변수
  bool _isInitialResolving = true;

  final Map<String, FlightDetail> _matchedFlightsDetails = {};
  final List<Airport> _matchedAirports = [];
  final List<Country> _matchedCountries = [];

  // 모든 매칭된 도시를 국가별로 그룹화하여 저장할 최종 리스트
  final List<CitiesInCountry> _groupedCitiesByCountry = [];

  // TripMapScreen에 전달할 City 객체와 Duration을 포함한 리스트 (이전과 동일한 역할)
  final List<Map<String, dynamic>> _matchedCitiesForMap = [];

  final List<Landmark> _matchedLandmarks = [];
  final List<UnescoSite> _matchedUnescoSites = []; // 🆕 UNESCO 매칭 결과 저장

  // 🆕 Attribute Sets for Classification (country_detail_screen과 동일)
  final Set<String> _naturalAttributes = {
    'Mountain', 'Volcano', 'Desert', 'River', 'Lake', 'Sea', 'Beach',
    'Waterfall', 'Falls', 'Cave', 'Island', 'Unique Landscape', 'Glacier',
    'Canyon', 'Geothermal'
  };

  final Set<String> _activityAttributes = {
    'Painting', 'Artwork', 'Library', 'Bookstore', 'Filming Location',
    'Theater', 'Performing Art', 'Food', 'Restaurant', 'Brewery', 'Winery',
    'Cafe', 'Fast Food', 'Festival', 'Event', 'Amusement Park',
    'Football Stadium', 'Zoo', 'Aquarium', 'Cruise Tour', 'Cable Car'
  };
  String _formatTime(String? time) {
    if (time != null && time.isNotEmpty) {
      return ' $time'; // 시간 앞에 공백을 추가하여 날짜와 구분합니다.
    }
    return ''; // 시간이 없으면 빈 문자열을 반환합니다.
  }
  // 🆕 [추가] 시간 포맷팅 헬퍼 (예: 49h -> 2d 1h)
  String _formatDuration(String? duration) {
    if (duration == null || duration.isEmpty || duration == 'N/A') return 'N/A';

    // "49h" 또는 "36 hours" 형식 처리
    String lowerDuration = duration.toLowerCase().trim();

    // "36 hours" 형식 처리
    if (lowerDuration.contains('hours') && !lowerDuration.contains('d')) {
      String cleanStr = lowerDuration.replaceAll('hours', '').trim();
      int? hours = int.tryParse(cleanStr);

      if (hours != null && hours >= 24) {
        int d = hours ~/ 24;
        int h = hours % 24;
        return h > 0 ? '${d}d ${h}h' : '${d}d';
      }
    }

    // "49h" 형식 처리
    if (lowerDuration.endsWith('h') && !lowerDuration.contains('d')) {
      String cleanStr = lowerDuration.replaceAll('h', '').trim();
      int? hours = int.tryParse(cleanStr);

      if (hours != null && hours >= 24) {
        int d = hours ~/ 24;
        int h = hours % 24;
        return h > 0 ? '${d}d ${h}h' : '${d}d';
      }
    }

    return duration; // 이미 포맷팅 되어있거나 다른 형식이면 그대로 반환
  }


  bool _isMatching = true;
  bool _isSending = false;

  // 새로 추가할 변수들
  String _generatedItinerary = '';
  bool _isGeneratingItinerary = false;
  bool _showItinerary = false;

  // AI Service에서 반환된 최종 AiSummary를 저장할 변수
  // 사용자가 수정한 내용을 반영하기 위해 이 객체를 직접 수정합니다.
  late AiSummary _processedSummary;

  // 저장 관련 변수들 추가
  bool _isSavingModifications = false;
  bool _hasUnsavedChanges = false;
  String? _summaryId; // 각 summary를 구분하기 위한 ID

  // Google Maps Geocoding API 키 (사용자 요청에 따라 직접 사용되지 않음, 좌표 기반 계산)
  final String _googleMapsApiKey = 'AIzaSyD0n7Lg_t4qdVElZITPc_gBNhifvwavblw';


  @override
  void initState() {
    super.initState();
    _summaryId = _generateSummaryId(widget.entry.summary!);
    _processedSummary = _deepCopyAiSummary(widget.entry.summary!);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. 화면 보여주기 전에 "Unknown" 국가명을 실제 국가명으로 복구
      await _resolveInitialCountryNames();

      // 2. 복구된 데이터를 바탕으로 UI 리스트 구성
      _refreshCityGroupsUI();

      // 3. 로딩 해제 및 화면 표시
      if (mounted) {
        setState(() {
          _isInitialResolving = false;
          _itineraryFuture = Provider.of<TripLogProvider>(context, listen: false)
              .getOrGenerateItinerary(widget.entry.id);
        });
      }

      // 4. 하단 DB 매칭 실행
      _performMatching();
    });
  }

  // 🆕 [수정] 초기 국가명 복구 (Map을 이용한 즉시 조회로 A2/A3 완벽 지원)
  Future<void> _resolveInitialCountryNames() async {
    final cityProvider = context.read<CityProvider>();
    final countryProvider = context.read<CountryProvider>();

    final List<CitiesInCountry> resolvedGroups = [];

    // CountryProvider의 검색용 맵 가져오기 (A2->이름, A3->이름)
    final a2Map = countryProvider.isoA2ToCountryNameMap;
    final a3Map = countryProvider.isoToCountryNameMap;

    for (var group in _processedSummary.cities) {
      String resolvedCountryName = group.countryName;

      // 1. 기존 이름에서 불필요한 괄호/코드 제거한 깔끔한 이름 준비
      String cleanName = group.countryName.replaceAll(RegExp(r'\s*\([A-Z0-9]{2,3}\)'), '').trim();

      // 2. 힌트 코드 추출 (예: "Unknown (CN)" -> "CN")
      final codeMatch = RegExp(r'\(([A-Z]{2,3})\)', caseSensitive: false).firstMatch(group.countryName);
      String? hintCode = codeMatch?.group(1)?.toUpperCase();

      String? matchedName;

      // A. 힌트 코드로 Map 조회 (가장 빠름)
      if (hintCode != null) {
        matchedName = a2Map[hintCode] ?? a3Map[hintCode];
      }

      // B. 이름으로 직접 검색 (힌트가 없거나 실패 시)
      if (matchedName == null &&
          !cleanName.toLowerCase().contains('unknown') &&
          !cleanName.toLowerCase().contains('temporary')) {
        final country = countryProvider.allCountries.firstWhereOrNull(
                (c) => c.name.toLowerCase() == cleanName.toLowerCase()
        );
        matchedName = country?.name;
      }

      // C. 도시 목록을 뒤져서 국가 찾기 (가장 강력함)
      if (matchedName == null) {
        for (var city in group.cities) {
          // 도시 이름에 포함된 코드 확인 ("City|Code")
          if (city.name.contains('|')) {
            final parts = city.name.split('|');
            final code = parts[1].trim().toUpperCase();
            matchedName = a2Map[code] ?? a3Map[code];
          }
          if (matchedName != null) break;

          // CityProvider에서 도시 데이터 상세 조회
          final simpleName = city.name.split('|').first.trim();
          final foundCity = cityProvider.allCities.firstWhereOrNull(
                  (c) => c.name.toLowerCase() == simpleName.toLowerCase()
          );

          if (foundCity != null) {
            // 🔴 [핵심] 도시 데이터의 국가 코드로 Map 조회 (A2, A3 모두 시도)
            final code = foundCity.countryIsoA2.toUpperCase();
            matchedName = a2Map[code] ?? a3Map[code];

            // 코드로 못 찾으면, 도시 데이터의 국가 이름 필드 사용 (cities.json의 경우)
            if (matchedName == null && foundCity.country.isNotEmpty && foundCity.country != 'Unknown') {
              final country = countryProvider.allCountries.firstWhereOrNull(
                      (c) => c.name.toLowerCase() == foundCity.country.toLowerCase()
              );
              matchedName = country?.name;
            }
          }
          if (matchedName != null) break;
        }
      }

      // 3. 최종 이름 적용
      if (matchedName != null) {
        resolvedCountryName = matchedName; // 찾은 정식 국가명 사용
      } else {
        // 못 찾았으면 힌트 코드라도 보여주거나, 깔끔한 이름 유지
        if (cleanName.toLowerCase().contains('unknown') && hintCode != null) {
          resolvedCountryName = hintCode;
        } else {
          resolvedCountryName = cleanName;
        }
      }

      resolvedGroups.add(CitiesInCountry(
        countryName: resolvedCountryName,
        cities: group.cities,
      ));
    }

    _processedSummary = AiSummary(
      countries: _processedSummary.countries,
      cities: resolvedGroups,
      airports: _processedSummary.airports,
      flights: _processedSummary.flights,
      trains: _processedSummary.trains,
      buses: _processedSummary.buses,
      ferries: _processedSummary.ferries,
      cars: _processedSummary.cars,
      landmarks: _processedSummary.landmarks,
      transitAirports: _processedSummary.transitAirports,
      startLocation: _processedSummary.startLocation,
      endLocation: _processedSummary.endLocation,
    );
  }

  AiSummary _deepCopyAiSummary(AiSummary original) {
    return AiSummary(
      countries: original.countries.map((c) => CountryLog(name: c.name, arrivalDate: c.arrivalDate, duration: c.duration)).toList(),
      cities: original.cities.map((cic) => CitiesInCountry(
        countryName: cic.countryName,
        cities: cic.cities.map((cvd) => CityVisitDetail(
          name: cvd.name,
          arrivalDate: cvd.arrivalDate,
          arrivalTime: cvd.arrivalTime,
          departureDate: cvd.departureDate,
          departureTime: cvd.departureTime,
          duration: cvd.duration,
          hasLived: cvd.hasLived,
          rating: cvd.rating,
          visitDateRanges: cvd.visitDateRanges.map((dr) => DateRange(arrival: dr.arrival, departure: dr.departure)).toList(),
        )).toList(),
      )).toList(),
      airports: original.airports.map((al) => AirportLog(
        iataCode: al.iataCode,
        name: al.name,
        visitDate: al.visitDate,
        isTransit: al.isTransit,
      )).toList(),
      flights: original.flights.map((al) => AirlineLog(
        airlineName: al.airlineName,
        flights: al.flights.map((fd) => FlightDetail(
          flightNumber: fd.flightNumber,
          origin: fd.origin,
          destination: fd.destination,
          flightDate: fd.flightDate,
          duration: fd.duration,
          sequence: fd.sequence,
        )).toList(),
      )).toList(),
      trains: original.trains.map((tl) => TrainLog(
        trainCompany: tl.trainCompany,
        trainNumber: tl.trainNumber,
        origin: tl.origin,
        destination: tl.destination,
        date: tl.date,
        departureTime: tl.departureTime,
        arrivalTime: tl.arrivalTime,
        duration: tl.duration,
        sequence: tl.sequence,
      )).toList(),
      buses: original.buses.map((bl) => BusLog(
        busCompany: bl.busCompany,
        origin: bl.origin,
        destination: bl.destination,
        date: bl.date,
        departureTime: bl.departureTime,
        arrivalTime: bl.arrivalTime,
        duration: bl.duration,
        sequence: bl.sequence,
      )).toList(),
      ferries: original.ferries.map((fl) => FerryLog(
        ferryName: fl.ferryName,
        origin: fl.origin,
        destination: fl.destination,
        date: fl.date,
        departureTime: fl.departureTime,
        arrivalTime: fl.arrivalTime,
        duration: fl.duration,
        sequence: fl.sequence,
      )).toList(),
      cars: original.cars.map((cl) => CarLog(
        carType: cl.carType,
        origin: cl.origin,
        destination: cl.destination,
        date: cl.date,
        departureTime: cl.departureTime,
        arrivalTime: cl.arrivalTime,
        duration: cl.duration,
        sequence: cl.sequence,
      )).toList(),
      // 🔄 [수정됨] AiLandmarkLog 객체 복사
      landmarks: original.landmarks.map((l) => l.copyWith()).toList(),

      transitAirports: List.from(original.transitAirports),
      startLocation: original.startLocation,
      endLocation: original.endLocation,
    );
  }

  // 🆕 [새로 추가] DB 매칭 없이 현재 요약 데이터로만 상단 UI 그룹을 갱신하는 함수
  void _refreshCityGroupsUI() {
    setState(() {
      _groupedCitiesByCountry.clear();

      // _processedSummary의 데이터를 기반으로 그룹 다시 생성
      for (var group in _processedSummary.cities) {
        // 이미 존재하는 그룹인지 확인
        CitiesInCountry? uiGroup = _groupedCitiesByCountry.firstWhereOrNull(
                (g) => g.countryName == group.countryName
        );

        if (uiGroup == null) {
          // 깊은 복사로 새 그룹 생성
          uiGroup = CitiesInCountry(
              countryName: group.countryName,
              cities: []
          );
          _groupedCitiesByCountry.add(uiGroup);
        }

        // 도시 목록 복사
        for (var city in group.cities) {
          uiGroup.cities.add(city.copyWith());
        }
      }

      // 정렬
      _groupedCitiesByCountry.sort((a, b) => a.countryName.compareTo(b.countryName));
      for (var group in _groupedCitiesByCountry) {
        group.cities.sort((a, b) => a.name.compareTo(b.name));
      }
    });
  }
  String _generateSummaryId(AiSummary summary) {
    final cities = summary.cities.map((c) => c.countryName + c.cities.map((city) => city.name).join(',')).join('|');
    final flights = summary.flights.map((f) => f.airlineName + f.flights.map((flight) => flight.flightNumber).join(',')).join('|');
    // 🔄 [수정됨] landmark.name 사용
    final landmarks = summary.landmarks.map((l) => l.name).join(',');

    final combined = cities + flights + landmarks;
    return 'summary_${combined.hashCode.abs()}';
  }

  // 🆕 [수정됨] 화면의 수정 사항을 실제 여행 로그(DB)에 영구 저장
  Future<void> _saveModifications() async {
    setState(() {
      _isSavingModifications = true;
    });

    try {
      // 1. Provider를 통해 실제 여행 로그 파일(DB) 업데이트
      // (통계 데이터는 건드리지 않고, 이 화면의 내용만 저장합니다)
      await context.read<TripLogProvider>().updateEntrySummary(
          widget.entry.id,
          _processedSummary
      );

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _isSavingModifications = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved to this trip log!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingModifications = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 저장된 수정사항을 SharedPreferences에서 로드
  Future<void> _loadSavedModifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('modified_$_summaryId');

      if (savedJson != null) {
        final decodedJson = json.decode(savedJson);
        _processedSummary = _aiSummaryFromJson(decodedJson);
      } else {
        // 저장된 수정사항이 없으면 원본을 사용
        _processedSummary = _deepCopyAiSummary(widget.entry.summary!);
      }
    } catch (e) {
      // 에러 발생 시 원본 사용
      _processedSummary = _deepCopyAiSummary(widget.entry.summary!);
    }
  }

  // AiSummary를 JSON으로 변환
  Map<String, dynamic> _aiSummaryToJson(AiSummary summary) {
    return {
      'countries': summary.countries.map((c) => {
        'name': c.name,
        'arrivalDate': c.arrivalDate,
        'duration': c.duration,
      }).toList(),
      'cities': summary.cities.map((cic) => {
        'countryName': cic.countryName,
        'cities': cic.cities.map((cvd) => {
          'name': cvd.name,
          'arrivalDate': cvd.arrivalDate,
          'arrivalTime': cvd.arrivalTime,
          'departureDate': cvd.departureDate,
          'departureTime': cvd.departureTime,
          'duration': cvd.duration,
          'hasLived': cvd.hasLived,
          'rating': cvd.rating,
          'visitDateRanges': cvd.visitDateRanges.map((dr) => dr.toJson()).toList(),
        }).toList(),
      }).toList(),
      'airports': summary.airports.map((al) => {
        'iataCode': al.iataCode,
        'name': al.name,
        'visitDate': al.visitDate,
        'isTransit': al.isTransit,
      }).toList(),
      'flights': summary.flights.map((al) => {
        'airlineName': al.airlineName,
        'flights': al.flights.map((fd) => {
          'flightNumber': fd.flightNumber,
          'origin': fd.origin,
          'destination': fd.destination,
          'flightDate': fd.flightDate,
          'duration': fd.duration,
          'sequence': fd.sequence,

        }).toList(),
      }).toList(),
      'trains': summary.trains.map((tl) => {
        'trainCompany': tl.trainCompany,
        'trainNumber': tl.trainNumber,
        'origin': tl.origin,
        'destination': tl.destination,
        'date': tl.date,
        'departureTime': tl.departureTime,
        'arrivalTime': tl.arrivalTime,
        'duration': tl.duration,
        'sequence': tl.sequence,
      }).toList(),
      'buses': summary.buses.map((bl) => {
        'busCompany': bl.busCompany,
        'origin': bl.origin,
        'destination': bl.destination,
        'date': bl.date,
        'departureTime': bl.departureTime,
        'arrivalTime': bl.arrivalTime,
        'duration': bl.duration,
        'sequence': bl.sequence,
      }).toList(),
      'ferries': summary.ferries.map((fl) => {
        'ferryName': fl.ferryName,
        'origin': fl.origin,
        'destination': fl.destination,
        'date': fl.date,
        'departureTime': fl.departureTime,
        'arrivalTime': fl.arrivalTime,
        'duration': fl.duration,
        'sequence': fl.sequence,
      }).toList(),
      'cars': summary.cars.map((cl) => {
        'carType': cl.carType,
        'origin': cl.origin,
        'destination': cl.destination,
        'date': cl.date,
        'departureTime': cl.departureTime,
        'arrivalTime': cl.arrivalTime,
        'duration': cl.duration,
        'sequence': cl.sequence,
      }).toList(),
      // 🔄 [수정됨] AiLandmarkLog -> JSON
      'landmarks': summary.landmarks.map((l) => l.toMap()).toList(),
      'transitAirports': summary.transitAirports,
      'startLocation': summary.startLocation,
      'endLocation': summary.endLocation,
    };
  }

  AiSummary _aiSummaryFromJson(Map<String, dynamic> json) {
    return AiSummary(
      countries: (json['countries'] as List<dynamic>).map((c) => CountryLog(
        name: c['name'] as String,
        arrivalDate: c['arrivalDate'] as String,
        duration: c['duration'] as String,
      )).toList(),
      cities: (json['cities'] as List<dynamic>).map((cic) => CitiesInCountry(
        countryName: cic['countryName'] as String,
        cities: (cic['cities'] as List<dynamic>).map((cvd) => CityVisitDetail(
          name: cvd['name'] as String,
          arrivalDate: cvd['arrivalDate'] as String,
          arrivalTime: cvd['arrivalTime'] as String?,
          departureDate: cvd['departureDate'] as String? ?? 'Unknown',
          departureTime: cvd['departureTime'] as String?,
          duration: cvd['duration'] as String,
          hasLived: cvd['hasLived'] as bool? ?? false,
          rating: (cvd['rating'] as num?)?.toDouble() ?? 0.0,
          visitDateRanges: (cvd['visitDateRanges'] as List<dynamic>)
              .map((dr) => DateRange.fromJson(dr as Map<String, dynamic>))
              .toList(),
        )).toList(),
      )).toList(),
      airports: (json['airports'] as List<dynamic>?)?.map((al) => AirportLog(
        iataCode: al['iataCode'] as String,
        name: al['name'] as String,
        visitDate: al['visitDate'] as String?,
        isTransit: al['isTransit'] as bool? ?? false,
      )).toList() ?? [],
      flights: (json['flights'] as List<dynamic>).map((al) => AirlineLog(
        airlineName: al['airlineName'] as String,
        flights: (al['flights'] as List<dynamic>).map((fd) => FlightDetail(
          flightNumber: fd['flightNumber'] as String,
          origin: fd['origin'] as String,
          destination: fd['destination'] as String,
          flightDate: fd['flightDate'] as String?,
          duration: fd['duration'] as String?,
          sequence: (fd['sequence'] as num?)?.toInt() ?? 0,

        )).toList(),
      )).toList(),
      trains: (json['trains'] as List<dynamic>).map((tl) => TrainLog(
        trainCompany: tl['trainCompany'] as String?,
        trainNumber: tl['trainNumber'] as String?,
        origin: tl['origin'] as String?,
        destination: tl['destination'] as String?,
        date: tl['date'] as String?,
        departureTime: tl['departureTime'] as String?,
        arrivalTime: tl['arrivalTime'] as String?,
        duration: tl['duration'] as String?,
        sequence: (tl['sequence'] as num?)?.toInt() ?? 0,

      )).toList(),
      buses: (json['buses'] as List<dynamic>).map((bl) => BusLog(
        busCompany: bl['busCompany'] as String?,
        origin: bl['origin'] as String?,
        destination: bl['destination'] as String?,
        date: bl['date'] as String?,
        departureTime: bl['departureTime'] as String?,
        arrivalTime: bl['arrivalTime'] as String?,
        duration: bl['duration'] as String?,
        sequence: (bl['sequence'] as num?)?.toInt() ?? 0,

      )).toList(),
      ferries: (json['ferries'] as List<dynamic>).map((fl) => FerryLog(
        ferryName: fl['ferryName'] as String?,
        origin: fl['origin'] as String?,
        destination: fl['destination'] as String?,
        date: fl['date'] as String?,
        departureTime: fl['departureTime'] as String?,
        arrivalTime: fl['arrivalTime'] as String?,
        duration: fl['duration'] as String?,
        sequence: (fl['sequence'] as num?)?.toInt() ?? 0,

      )).toList(),
      cars: (json['cars'] as List<dynamic>).map((cl) => CarLog(
        carType: cl['carType'] as String?,
        origin: cl['origin'] as String?,
        destination: cl['destination'] as String?,
        date: cl['date'] as String?,
        departureTime: cl['departureTime'] as String?,
        arrivalTime: cl['arrivalTime'] as String?,
        duration: cl['duration'] as String?,
        sequence: (cl['sequence'] as num?)?.toInt() ?? 0,

      )).toList(),
      // 🔄 [수정됨] JSON -> AiLandmarkLog
      landmarks: (json['landmarks'] as List<dynamic>).map((l) => AiLandmarkLog.fromMap(l)).toList(),
      transitAirports: List<String>.from(json['transitAirports'] as List<dynamic>),
      startLocation: json['startLocation'] as String?,
      endLocation: json['endLocation'] as String?,
    );
  }

  // 변경사항이 있음을 표시하는 함수
  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

// Duration이 유효한지 확인하는 함수
  bool _isValidDuration(String? duration) {
    if (duration == null || duration.isEmpty) return false;
    final lowerDuration = duration.toLowerCase().trim();
    return !['unknown', 'n/a', 'null', ''].contains(lowerDuration);
  }

  // 🆕 [추가] 공항 이름 포맷팅 함수 (International Airport / Airport 제거)
  String _formatAirportName(String fullName) {
    // 정규식을 사용하여 대소문자 구분 없이 끝부분의 "International Airport" 또는 "Airport" 제거
    return fullName.replaceAll(RegExp(r'\s*(International\s+)?Airport$', caseSensitive: false), '').trim();
  }

  // Google Maps Geocoding API를 사용하여 도시 정보 가져오기 (실제 매칭용)
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
          final double lat = (location['lat'] as num).toDouble(); // num을 double로 명시적 캐스팅
          final double lng = (location['lng'] as num).toDouble(); // num을 double로 명시적 캐스팅
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

  Future<City?> _findCity(String nameToSearch, String aiProvidedCountryIsoA2) async {
    final cityProvider = context.read<CityProvider>();
    final countryProvider = context.read<CountryProvider>();

    // CityProvider의 allCities에서 검색 (cities15000 + cities 병합됨)
    City? foundCity;
    if (aiProvidedCountryIsoA2 != 'N/A' && aiProvidedCountryIsoA2.isNotEmpty) {
      // 국가 코드가 있으면 국가 코드로 필터링
      foundCity = cityProvider.allCities.firstWhereOrNull(
              (c) => c.name.toLowerCase() == nameToSearch.toLowerCase() &&
              c.countryIsoA2.toLowerCase() == aiProvidedCountryIsoA2.toLowerCase()
      );
    } else {
      // 국가 코드 없으면 이름만으로 검색
      foundCity = cityProvider.allCities.firstWhereOrNull(
              (c) => c.name.toLowerCase() == nameToSearch.toLowerCase()
      );
    }

    if (foundCity != null) {
      // countryIsoA2가 비어있으면 country 이름으로 찾아서 채워줌
      if (foundCity.countryIsoA2.isEmpty || foundCity.countryIsoA2 == 'N/A') {
        final matchedCountry = countryProvider.allCountries.firstWhereOrNull(
              (c) => c.name.toLowerCase() == foundCity!.country.toLowerCase(),
        );
        if (matchedCountry != null) {
          return City(
            name: foundCity.name,
            country: foundCity.country,
            countryIsoA2: matchedCountry.isoA2,
            continent: foundCity.continent,
            population: foundCity.population,
            latitude: foundCity.latitude,
            longitude: foundCity.longitude,
            capitalStatus: foundCity.capitalStatus,
            annualVisitors: foundCity.annualVisitors,
            avgTemp: foundCity.avgTemp,
            avgPrecipitation: foundCity.avgPrecipitation,
            altitude: foundCity.altitude,
            gdpNominal: foundCity.gdpNominal,
            gdpPpp: foundCity.gdpPpp,
            starbucksCount: foundCity.starbucksCount,
            millionaires: foundCity.millionaires,
            billionaires: foundCity.billionaires,
            cityTouristRatio: foundCity.cityTouristRatio,
            stationsCount: foundCity.stationsCount,
            studentScore: foundCity.studentScore,
            safetyScore: foundCity.safetyScore,
            liveabilityScore: foundCity.liveabilityScore,
            surveillanceCameraCount: foundCity.surveillanceCameraCount,
            skyscraperCount: foundCity.skyscraperCount,
            pollutionScore: foundCity.pollutionScore,
            homicideRate: foundCity.homicideRate,
            trafficTimeMinutes: foundCity.trafficTimeMinutes,
            hollywoodScore: foundCity.hollywoodScore,
            gawcTier: foundCity.gawcTier,
          );
        }
      }
      return foundCity;
    }

    // CityProvider에서 못 찾으면 Google Maps API로 검색
    final googleCity = await _getCityInfoFromGoogleMaps(nameToSearch, countryIsoA2: aiProvidedCountryIsoA2);
    if (googleCity != null) {
      return googleCity;
    } else {
      return null;
    }
  }

  // Haversine formula to calculate distance between two lat/lng points
  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Estimated duration calculation based on distance and average speeds
  String _calculateEstimatedDuration(double distanceKm, String transportType) {
    double speed; // km/h
    switch (transportType) {
      case 'flight':
        speed = 850.0;
        break;
      case 'train':
        speed = 200.0;
        break;
      case 'bus':
        speed = 80.0;
        break;
      case 'car':
        speed = 100.0;
        break;
      case 'ferry':
        speed = 35.0;
        break;
      default:
        return 'N/A'; // Unknown transport type
    }

    if (distanceKm < 1 && distanceKm > 0) return 'Less than 1 min'; // Very short distances
    if (distanceKm == 0 || speed == 0) return '0 min';

    final totalHours = distanceKm / speed;
    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).round();

    if (hours == 0) return '${minutes}m';      // ← 이렇게 바꿔주세요
    if (minutes == 0) return '${hours}h';     // ← 이렇게 바꿔주세요
    return '${hours}h${minutes}m';            // ← 이렇게 바꿔주세요
  }


  void _performMatching() async {
    setState(() {
      _isMatching = true;
      _matchedFlightsDetails.clear();
      _matchedAirports.clear();
      _matchedCountries.clear();
      _matchedCitiesForMap.clear();
      _matchedLandmarks.clear();
      _matchedUnescoSites.clear(); // 🆕 UNESCO Sites 초기화
    });

    final countryProvider = context.read<CountryProvider>();
    final landmarkProvider = context.read<LandmarksProvider>();
    final airportProvider = context.read<AirportProvider>();
    final cityProvider = context.read<CityProvider>();
    final airlineProvider = context.read<AirlineProvider>();

    // =========================================================
    // 🛠️ [수정됨] 항공사 이름 & 비행편명(Code+Number) 보정 로직
    // 1. 항공사 이름을 "American Airlines"로 교체
    // 2. 비행편명이 "4350" 숫자만 있으면 "AA4350"으로 교체
    // =========================================================
    for (int i = 0; i < _processedSummary.flights.length; i++) {
      var airlineLog = _processedSummary.flights[i];
      String currentName = airlineLog.airlineName.trim();
      String detectedCode = '';

      // 1. 이름 자체가 코드인 경우 (예: "AA", "KE")
      if (currentName.length == 2 || (currentName.length == 3 && currentName.toUpperCase() == currentName)) {
        detectedCode = currentName.toUpperCase();
      }
      // 2. 이름에 편명이 섞인 경우 (예: "AA4350")
      else if (RegExp(r'^([A-Z0-9]{2})[0-9]+').hasMatch(currentName)) {
        final match = RegExp(r'^([A-Z0-9]{2})[0-9]+').firstMatch(currentName);
        detectedCode = match?.group(1) ?? '';
      }

      // 3. 항공사 이름이 "Unknown"이거나 비어있는데, 비행편명(flightNumber)이 "AA4350" 형태인 경우
      if (detectedCode.isEmpty && (currentName.toLowerCase().contains('unknown') || currentName.isEmpty)) {
        if (airlineLog.flights.isNotEmpty) {
          final firstFlightNum = airlineLog.flights.first.flightNumber.trim();
          final match = RegExp(r'^([A-Z0-9]{2})[0-9]+').firstMatch(firstFlightNum);
          if (match != null) {
            detectedCode = match.group(1) ?? '';
          }
        }
      }

      // 🎯 코드가 감지되었다면 DB에서 이름 찾고 + 편명 수정하기
      if (detectedCode.isNotEmpty) {
        final matchedAirline = airlineProvider.airlines.firstWhereOrNull(
                (a) => a.code.toUpperCase() == detectedCode
        );

        if (matchedAirline != null) {
          // ✈️ [추가됨] 비행편명 리스트도 순회하며 코드를 붙여줌 (4350 -> AA4350)
          final List<FlightDetail> correctedFlights = airlineLog.flights.map((f) {
            String newNum = f.flightNumber;
            // 편명이 숫자로만 되어있거나, 코드로 시작하지 않으면 코드 붙이기
            if (!newNum.toUpperCase().startsWith(matchedAirline.code.toUpperCase())) {
              newNum = '${matchedAirline.code}$newNum'; // "AA" + "4350"
            }
            // FlightDetail 객체 재생성 (내용 업데이트)
            return FlightDetail(
              flightNumber: newNum,
              origin: f.origin,
              destination: f.destination,
              flightDate: f.flightDate,
              departureTime: f.departureTime,
              arrivalTime: f.arrivalTime,
              duration: f.duration,
              sequence: f.sequence,
            );
          }).toList();

          // AirlineLog 교체 (이름 변경 + 편명 수정된 리스트 적용)
          _processedSummary.flights[i] = AirlineLog(
            airlineName: matchedAirline.name,
            flights: correctedFlights,
          );
          developer.log('✅ Fixed Airline: "${matchedAirline.name}" & Flight Nums (Code: $detectedCode)', name: 'Matching');
        }
      }
    }

    // =========================================================
    // 아래는 기존 매칭 로직 (변경 없음)
    // =========================================================

    // 1. Flights 매칭
    for (final airlineLog in _processedSummary.flights) {
      for (final flightDetail in airlineLog.flights) {
        final uniqueKey = '${flightDetail.flightNumber}_${flightDetail.flightDate ?? 'UnknownDate'}_${flightDetail.origin}-${flightDetail.destination}';
        if (flightDetail.flightNumber.isNotEmpty && flightDetail.flightNumber != 'N/A' && !_matchedFlightsDetails.containsKey(uniqueKey)) {
          _matchedFlightsDetails[uniqueKey] = flightDetail;
        }
      }
    }

    // 2. Countries 매칭
    for (final countryLog in _processedSummary.countries) {
      final match = RegExp(r'\((.*?)\)').firstMatch(countryLog.name);
      if (match?.group(1) != null) {
        try {
          final foundCountry = countryProvider.allCountries.firstWhere((c) => c.isoA3 == match!.group(1));
          if (!_matchedCountries.contains(foundCountry)) _matchedCountries.add(foundCountry);
        } catch (e) {}
      }
    }

    // 3. Airports 매칭
    for (final airportLog in _processedSummary.airports) {
      try {
        final foundAirport = airportProvider.allAirports.firstWhere((a) => a.iataCode.toUpperCase() == airportLog.iataCode.toUpperCase());
        if (!_matchedAirports.contains(foundAirport)) _matchedAirports.add(foundAirport);
      } catch (e) {}
    }

    // 4. Cities 매칭
    final Set<String> processedCityNames = {};
    for (var citiesInCountry in _processedSummary.cities) {
      for (var cityDetail in citiesInCountry.cities) {
        if (processedCityNames.contains(cityDetail.name)) continue;
        processedCityNames.add(cityDetail.name);

        String nameForSearch = cityDetail.name;
        String targetIsoA2 = 'N/A';

        if (cityDetail.name.contains('|')) {
          final parts = cityDetail.name.split('|');
          if (parts.length == 2) {
            nameForSearch = parts[0].trim();
            targetIsoA2 = parts[1].trim().toUpperCase();
          }
        } else {
          final aiCityMatch = RegExp(r'([^()]+)\s*\(([A-Z]{2})\)\(Arrival:').firstMatch(cityDetail.name);
          if (aiCityMatch != null) {
            nameForSearch = aiCityMatch.group(1)!.trim();
            targetIsoA2 = aiCityMatch.group(2)!.trim().toUpperCase();
          } else {
            nameForSearch = cityDetail.name.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
          }
        }

        City? foundCity;

        if (targetIsoA2 != 'N/A' && targetIsoA2.isNotEmpty) {
          foundCity = cityProvider.allCities.firstWhereOrNull(
                  (c) => c.name.toLowerCase() == nameForSearch.toLowerCase() &&
                  c.countryIsoA2.toUpperCase() == targetIsoA2
          );
        } else {
          foundCity = cityProvider.allCities.firstWhereOrNull(
                  (c) => c.name.toLowerCase() == nameForSearch.toLowerCase()
          );
        }

        if (foundCity != null) {
          if (!_matchedCitiesForMap.any((map) => (map['city'] as City).name == foundCity!.name && (map['city'] as City).countryIsoA2 == foundCity!.countryIsoA2)) {
            _matchedCitiesForMap.add({
              'city': foundCity,
              'duration': cityDetail.duration,
              'aiProvidedName': nameForSearch,
              'arrivalDate': cityDetail.arrivalDate,
              'departureDate': cityDetail.departureDate,
            });
          }
        }
      }
    }

    // 5. Landmarks 매칭
    final allLandmarkItems = landmarkProvider.allLandmarks;
    // 🔄 [수정됨] AiLandmarkLog에서 이름을 추출하여 매칭
    final aiLandmarkNames = _processedSummary.landmarks.map((l) => l.name.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim()).toSet();

    for (final landmarkName in aiLandmarkNames) {
      try {
        final foundLandmark = allLandmarkItems.firstWhere((l) => l.name.toLowerCase() == landmarkName.toLowerCase());
        if (!_matchedLandmarks.contains(foundLandmark)) _matchedLandmarks.add(foundLandmark);
      } catch (e) {}

      // 🆕 6. UNESCO Sites 매칭
      final unescoProvider = context.read<UnescoProvider>();
      final allUnescoSites = unescoProvider.allSites;
      for (final landmarkName in aiLandmarkNames) {
        try {
          final foundUnescoSite = allUnescoSites.firstWhere((u) => u.name.toLowerCase() == landmarkName.toLowerCase());
          if (!_matchedUnescoSites.contains(foundUnescoSite)) _matchedUnescoSites.add(foundUnescoSite);
        } catch (e) {}
      }
    }

    if (mounted) {
      setState(() { _isMatching = false; });
    }
  }

  bool _isAirportCode(String location) {
    return location.length == 3 && location.toUpperCase() == location;
  }

  void _generateItinerary() async {
    if (mounted) {
      setState(() {
        _isGeneratingItinerary = true;
      });
    }
    try {
      final aiService = AiService();
      final itinerary = await aiService.generateItineraryFromSummary(_processedSummary);
      if (mounted) {
        setState(() {
          _generatedItinerary = itinerary;
          _isGeneratingItinerary = false;
        });

        // AI 생성 완료 후 자동으로 저장
        await _saveModifications();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New AI itinerary generated and saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generatedItinerary = 'Error generating itinerary: $e';
          _isGeneratingItinerary = false;
        });
      }
    }
  }

  Future<void> _sendDataToProviders() async {
    if (mounted) {
      setState(() { _isSending = true; });
    }

    final countryProvider = context.read<CountryProvider>();
    final cityProvider = context.read<CityProvider>();
    final landmarkProvider = context.read<LandmarksProvider>();
    final airportProvider = context.read<AirportProvider>();
    final unescoProvider = context.read<UnescoProvider>();
    final airlineProvider = context.read<AirlineProvider>();

    // 1. Countries
    final List<Country> countriesToAdd = [];
    final List<String> countryAddReasons = [];

    for (final country in _matchedCountries) {
      final countryLog = _processedSummary.countries.firstWhereOrNull(
            (c) => c.name.contains(country.isoA3),
      );

      bool hasValidDates = false;
      if (countryLog != null) {
        final bool hasArrival = countryLog.arrivalDate != null &&
            countryLog.arrivalDate!.isNotEmpty &&
            !countryLog.arrivalDate!.toLowerCase().contains('unknown') &&
            countryLog.arrivalDate != 'N/A';

        final bool hasDuration = countryLog.duration != null &&
            countryLog.duration!.isNotEmpty &&
            !countryLog.duration!.toLowerCase().contains('unknown') &&
            countryLog.duration != 'N/A';

        if (hasArrival && hasDuration) {
          hasValidDates = true;
        }
      }

      if (!hasValidDates) {
        developer.log('🚫 Skipping country ${country.name} due to missing dates', name: 'sendDataToProviders');
        continue;
      }

      final isAlreadyVisited = countryProvider.visitedCountries.contains(country.name);

      if (!isAlreadyVisited) {
        countriesToAdd.add(country);
        countryAddReasons.add('New');
      } else {
        try {
          final newArrivalDate = DateTime.parse(countryLog!.arrivalDate!);
          final existingVisitDetails = countryProvider.getVisitDetails(country.name);

          bool isDifferentDate = true;
          if (existingVisitDetails != null && existingVisitDetails.visitDateRanges.isNotEmpty) {
            for (var existingRange in existingVisitDetails.visitDateRanges) {
              if (existingRange.arrival != null) {
                if (existingRange.arrival!.year == newArrivalDate.year &&
                    existingRange.arrival!.month == newArrivalDate.month &&
                    existingRange.arrival!.day == newArrivalDate.day) {
                  isDifferentDate = false;
                  break;
                }
              }
            }
          }

          if (isDifferentDate) {
            countriesToAdd.add(country);
            countryAddReasons.add('Revisit');
          }
        } catch (e) {
          developer.log('⚠️ Failed to check date for ${country.name}: $e', name: 'sendDataToProviders');
        }
      }
    }

    final newLandmarks = _matchedLandmarks.where((l) => !landmarkProvider.visitedLandmarks.contains(l.name)).toList();
    final newUnescoSites = _matchedUnescoSites.where((u) => !unescoProvider.visitedSites.contains(u.name)).toList();

    // 2. Airports (Visit Date 사용)
    final List<AirportLog> validAirportLogs = [];
    final Set<String> validAirportIataCodes = {};

    for (final airportLog in _processedSummary.airports) {
      if (airportLog.visitDate == null ||
          airportLog.visitDate!.isEmpty ||
          airportLog.visitDate!.toLowerCase().contains('unknown') ||
          airportLog.visitDate == 'N/A') {
        continue;
      }

      DateTime? visitDate;
      try {
        visitDate = DateTime.parse(airportLog.visitDate!);
      } catch (e) {
        continue;
      }

      bool isDuplicate = airportProvider.isDuplicateVisit(airportLog.iataCode, visitDate);

      if (!isDuplicate) {
        validAirportLogs.add(airportLog);
        validAirportIataCodes.add(airportLog.iataCode);
      }
    }

    // 3. Cities
    final List<City> citiesToAdd = [];
    final List<String> cityAddReasons = [];

    for (var group in _groupedCitiesByCountry) {
      for (var cityDetail in group.cities) {
        String cleanName = cityDetail.name;
        String? code;
        if (cityDetail.name.contains('|')) {
          final parts = cityDetail.name.split('|');
          cleanName = parts[0].trim();
          if (parts.length > 1) code = parts[1].trim();
        } else {
          final codeMatch = RegExp(r'\(([A-Z]{2,3})\)$').firstMatch(cleanName);
          if (codeMatch != null) {
            code = codeMatch.group(1);
            cleanName = cleanName.replaceAll(RegExp(r'\s*\([A-Z]{2,3}\)$'), '').trim();
          }
        }

        String? targetIsoA2 = code;
        if (code != null && code.length == 3) {
          final country = countryProvider.allCountries.firstWhereOrNull(
                  (c) => c.isoA3.toUpperCase() == code!.toUpperCase()
          );
          if (country != null) targetIsoA2 = country.isoA2;
        }

        City? matchedCity = cityProvider.getCityDetail(cleanName);
        if (matchedCity == null && targetIsoA2 != null) {
          matchedCity = cityProvider.allCities.firstWhereOrNull(
                  (c) => c.name.toLowerCase() == cleanName.toLowerCase() &&
                  c.countryIsoA2.toUpperCase() == targetIsoA2!.toUpperCase()
          );
        }

        if (matchedCity == null) continue;

        if (cityDetail.arrivalDate != null &&
            cityDetail.arrivalDate != 'Unknown' &&
            cityDetail.departureDate != null &&
            cityDetail.departureDate != 'Unknown') {
          try {
            final arrivalDateOnly = cityDetail.arrivalDate!.split(' ')[0];
            final departureDateOnly = cityDetail.departureDate!.split(' ')[0];
            if (arrivalDateOnly == departureDateOnly) {
              continue;
            }
          } catch (e) {}
        }

        final isAlreadyVisited = cityProvider.isVisited(matchedCity.name);

        if (!isAlreadyVisited) {
          citiesToAdd.add(matchedCity);
          cityAddReasons.add('New');
        } else {
          if (cityDetail.arrivalDate != null && cityDetail.arrivalDate != 'Unknown') {
            try {
              final arrivalDateOnly = cityDetail.arrivalDate!.split(' ')[0];
              final newArrivalDate = DateTime.parse(arrivalDateOnly);

              final existingVisitDetail = cityProvider.getCityVisitDetail(matchedCity.name);
              bool isDifferentDate = true;

              if (existingVisitDetail != null && existingVisitDetail.visitDateRanges.isNotEmpty) {
                for (var existingRange in existingVisitDetail.visitDateRanges) {
                  if (existingRange.arrival != null) {
                    if (existingRange.arrival!.year == newArrivalDate.year &&
                        existingRange.arrival!.month == newArrivalDate.month &&
                        existingRange.arrival!.day == newArrivalDate.day) {
                      isDifferentDate = false;
                      break;
                    }
                  }
                }
              }

              if (isDifferentDate && existingVisitDetail != null) {
                if (existingVisitDetail.arrivalDate != null &&
                    existingVisitDetail.arrivalDate != 'Unknown') {
                  try {
                    final existingArrivalDateOnly = existingVisitDetail.arrivalDate!.split(' ')[0];
                    final existingArrivalDate = DateTime.parse(existingArrivalDateOnly);

                    if (existingArrivalDate.year == newArrivalDate.year &&
                        existingArrivalDate.month == newArrivalDate.month &&
                        existingArrivalDate.day == newArrivalDate.day) {
                      isDifferentDate = false;
                    }
                  } catch (e) {}
                }
              }

              if (isDifferentDate) {
                citiesToAdd.add(matchedCity);
                cityAddReasons.add('Revisit');
              }
            } catch (e) {}
          }
        }
      }
    }

    // 4. Flights
    final Map<String, FlightDetail> filteredFlightsForDialog = {};
    for (final airlineLog in _processedSummary.flights) {
      for (final flightDetail in airlineLog.flights) {
        final flightNumber = flightDetail.flightNumber;
        final origin = flightDetail.origin;
        final destination = flightDetail.destination;
        final flightDate = flightDetail.flightDate;

        if (origin.isEmpty || destination.isEmpty || flightDate == null || flightDate.isEmpty || flightDate == 'Unknown' || origin == 'N/A' || destination == 'N/A') {
          continue;
        }

        bool isDuplicate = false;
        if (flightNumber.isNotEmpty && flightNumber != 'N/A' && flightNumber != 'Unknown') {
          isDuplicate = airlineProvider.isDuplicateFlight(flightNumber: flightNumber, date: flightDate);
        } else {
          isDuplicate = airlineProvider.isDuplicateFlight(originIata: origin, destinationIata: destination, date: flightDate);
        }

        if (!isDuplicate) {
          final uniqueKey = '${flightNumber}_${flightDate}_${origin}-${destination}';
          if (!filteredFlightsForDialog.containsKey(uniqueKey)) {
            filteredFlightsForDialog[uniqueKey] = flightDetail;
          }
        }
      }
    }

    if (countriesToAdd.isEmpty && citiesToAdd.isEmpty && newLandmarks.isEmpty && newUnescoSites.isEmpty && validAirportLogs.isEmpty && filteredFlightsForDialog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No new items to add or update.')),
      );
      if (mounted) {
        setState(() { _isSending = false; });
      }
      return;
    }

    // Dialog
    final Map<String, dynamic>? selectedItems = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _buildSelectionDialog(
        context: ctx,
        flights: filteredFlightsForDialog,
        airports: validAirportLogs,
        countries: countriesToAdd,
        countryReasons: countryAddReasons,
        cities: citiesToAdd,
        cityReasons: cityAddReasons,
        landmarks: newLandmarks,
        unescoSites: newUnescoSites,
        airlineProvider: airlineProvider,
      ),
    );

    if (selectedItems == null || selectedItems.isEmpty) {
      if (mounted) {
        setState(() { _isSending = false; });
      }
      return;
    }

    final selectedFlights = selectedItems['flights'] as List<FlightDetail>? ?? [];
    final selectedAirportLogs = selectedItems['airports'] as List<AirportLog>? ?? [];
    final selectedCountries = selectedItems['countries'] as List<Country>? ?? [];
    final selectedCities = selectedItems['cities'] as List<City>? ?? [];
    final selectedLandmarks = selectedItems['landmarks'] as List<Landmark>? ?? [];
    final selectedUnescoSites = selectedItems['unescoSites'] as List<UnescoSite>? ?? [];

    if (selectedItems.isNotEmpty) {
      final uuid = const Uuid();

      // Flights 저장
      for (final flightDetail in selectedFlights) {
        final flightNumber = flightDetail.flightNumber;
        final originalAirlineLog = _processedSummary.flights.firstWhere(
                (log) => log.flights.any((detail) => detail.flightNumber == flightNumber),
            orElse: () => AirlineLog(airlineName: 'Unknown Airline', flights: [])
        );

        final newFlightLog = FlightLog(
          id: uuid.v4(),
          flightNumber: flightDetail.flightNumber,
          times: 1,
          date: flightDetail.flightDate ?? 'Unknown',
          airlineName: originalAirlineLog.airlineName.isNotEmpty ? originalAirlineLog.airlineName : 'Unknown Airline',
          airlineCode: originalAirlineLog.airlineName.isNotEmpty ? null : 'N/A',
          departureIata: flightDetail.origin,
          arrivalIata: flightDetail.destination,
          scheduledDepartureTime: flightDetail.departureTime,
          scheduledArrivalTime: flightDetail.arrivalTime,
          duration: flightDetail.duration,
        );

        airlineProvider.addDetailedFlightLog(newFlightLog.airlineName ?? 'Unknown Airline', newFlightLog);
      }

      // Countries 저장
      for (final country in selectedCountries) {
        final countryLog = _processedSummary.countries.firstWhereOrNull(
              (c) => c.name.contains(country.isoA3),
        );

        if (countryLog != null && countryLog.arrivalDate != null && countryLog.arrivalDate != 'Unknown') {
          DateTime? arrivalDate;
          DateTime? departureDate;

          try {
            arrivalDate = DateTime.parse(countryLog.arrivalDate!);
          } catch (e) {}

          DateTime? latestDeparture;
          for (var citiesInCountry in _processedSummary.cities) {
            if (citiesInCountry.countryName.contains(country.isoA3) ||
                citiesInCountry.countryName.contains(country.isoA2)) {
              for (var cityDetail in citiesInCountry.cities) {
                if (cityDetail.departureDate != null && cityDetail.departureDate != 'Unknown') {
                  try {
                    String departureDateTimeStr = cityDetail.departureDate!;
                    if (cityDetail.departureTime != null && cityDetail.departureTime != 'N/A' && cityDetail.departureTime!.isNotEmpty) {
                      departureDateTimeStr += ' ${cityDetail.departureTime}:00';
                    } else {
                      departureDateTimeStr += ' 23:59:00';
                    }
                    final cityDeparture = DateTime.parse(departureDateTimeStr);
                    if (latestDeparture == null || cityDeparture.isAfter(latestDeparture)) {
                      latestDeparture = cityDeparture;
                    }
                  } catch (e) {}
                }
              }
            }
          }
          departureDate = latestDeparture;

          int? durationDays;
          if (arrivalDate != null && departureDate != null) {
            final durationHours = departureDate.difference(arrivalDate).inHours;
            durationDays = (durationHours / 24).ceil();
            if (durationDays < 1) durationDays = 1;
          }

          countryProvider.addVisitWithDetails(
            country.name,
            arrival: arrivalDate,
            departure: departureDate,
            userDefinedDuration: durationDays,
          );
        } else {
          countryProvider.setVisitedStatus(country.name, true);
        }
      }

      // Cities 저장
      for (final city in selectedCities) {
        CityVisitDetail? cityDetailFromSummary;
        for (var group in _groupedCitiesByCountry) {
          for (var cityDetail in group.cities) {
            String detailNameClean = cityDetail.name.split('|')[0].trim();
            if (detailNameClean == city.name) {
              cityDetailFromSummary = cityDetail;
              break;
            }
          }
          if (cityDetailFromSummary != null) break;
        }

        if (cityDetailFromSummary != null) {
          DateTime? arrivalDate;
          DateTime? departureDate;

          if (cityDetailFromSummary.arrivalDate != null && cityDetailFromSummary.arrivalDate != 'Unknown') {
            try {
              String arrivalDateTimeStr = cityDetailFromSummary.arrivalDate!;
              if (cityDetailFromSummary.arrivalTime != null && cityDetailFromSummary.arrivalTime != 'N/A' && cityDetailFromSummary.arrivalTime!.isNotEmpty) {
                arrivalDateTimeStr += ' ${cityDetailFromSummary.arrivalTime}:00';
              } else {
                arrivalDateTimeStr += ' 00:00:00';
              }
              arrivalDate = DateTime.parse(arrivalDateTimeStr);
            } catch (e) {}
          }

          if (cityDetailFromSummary.departureDate != null && cityDetailFromSummary.departureDate != 'Unknown') {
            try {
              String departureDateTimeStr = cityDetailFromSummary.departureDate!;
              if (cityDetailFromSummary.departureTime != null && cityDetailFromSummary.departureTime != 'N/A' && cityDetailFromSummary.departureTime!.isNotEmpty) {
                departureDateTimeStr += ' ${cityDetailFromSummary.departureTime}:00';
              } else {
                departureDateTimeStr += ' 23:59:00';
              }
              departureDate = DateTime.parse(departureDateTimeStr);
            } catch (e) {}
          }

          int durationDays = 1;
          if (arrivalDate != null && departureDate != null) {
            final durationHours = departureDate.difference(arrivalDate).inHours;
            durationDays = (durationHours / 24).ceil();
            if (durationDays < 1) durationDays = 1;
          }

          final existingDetail = cityProvider.getCityVisitDetail(city.name);
          final existingRanges = existingDetail?.visitDateRanges ?? [];

          final updatedDetail = cityDetailFromSummary.copyWith(
            visitDateRanges: existingRanges,
          );
          cityProvider.updateCityVisitDetail(city.name, updatedDetail);

          await cityProvider.addVisitWithDetails(
            city.name,
            arrival: arrivalDate,
            departure: departureDate,
            userDefinedDuration: durationDays,
          );
        } else {
          cityProvider.toggleVisitedStatus(city.name);
        }
      }

      // Landmarks 저장
      for (final landmark in selectedLandmarks) {
        final logs = _processedSummary.landmarks
            .where((l) => l.name.toLowerCase() == landmark.name.toLowerCase())
            .toList();

        if (logs.isEmpty) {
          landmarkProvider.toggleVisitedStatus(landmark.name);
        } else {
          for (var log in logs) {
            if (log.visitDate != null && log.visitDate!.isNotEmpty && log.visitDate!.toLowerCase() != 'unknown') {
              try {
                final visitDate = DateTime.parse(log.visitDate!);
                landmarkProvider.addVisitDate(landmark.name, date: visitDate);
              } catch (e) {
                landmarkProvider.toggleVisitedStatus(landmark.name);
              }
            } else {
              landmarkProvider.toggleVisitedStatus(landmark.name);
            }
          }
        }
      }

      // UNESCO Sites 저장
      for (final unescoSite in selectedUnescoSites) {
        final logs = _processedSummary.landmarks
            .where((l) => l.name.toLowerCase() == unescoSite.name.toLowerCase())
            .toList();

        if (logs.isEmpty) {
          unescoProvider.toggleVisitedStatus(unescoSite.name);
        } else {
          for (var log in logs) {
            if (log.visitDate != null && log.visitDate!.isNotEmpty && log.visitDate!.toLowerCase() != 'unknown') {
              try {
                final visitDate = DateTime.parse(log.visitDate!);
                unescoProvider.addVisitDate(unescoSite.name, date: visitDate);
              } catch (e) {
                unescoProvider.toggleVisitedStatus(unescoSite.name);
              }
            } else {
              unescoProvider.toggleVisitedStatus(unescoSite.name);
            }
          }
        }
      }

      // 🆕 [수정됨] Airports 저장 (AirportVisitEntry 모델에 맞춰 단일 날짜로 저장)
      for (final airportLog in selectedAirportLogs) {
        DateTime? visitDate;
        bool isTransit = false;

        if (airportLog.visitDate != null && airportLog.visitDate!.isNotEmpty && airportLog.visitDate != 'Unknown') {
          isTransit = airportLog.isTransit;
          try {
            visitDate = DateTime.parse(airportLog.visitDate!);
          } catch (e) {}
        }

        // AirportProvider.addVisitEntry 호출 (year, month, day 전달)
        airportProvider.addVisitEntry(
          airportLog.iataCode,
          year: visitDate?.year,
          month: visitDate?.month,
          day: visitDate?.day,
          isTransfer: isTransit,
          isLayover: false,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visited information has been updated!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() { _isSending = false; });
      }
    } else {
      if (mounted) {
        setState(() { _isSending = false; });
      }
    }
  }

  // =================== [ 수정된 build 메서드 ] ===================

  @override
  Widget build(BuildContext context) {
    // 1) 처음 국가/도시 매칭 중일 때 로딩 화면
    if (_isInitialResolving) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Resolving Country Data..."),
            ],
          ),
        ),
      );
    }

    // 2) 실제 화면: Summary / Itinerary 탭
    return Scaffold(
      body: Column(
        children: [
          // 상단 탭 버튼 (SegmentedButton)
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: SegmentedButton<_AiViewMode>(
                segments: const <ButtonSegment<_AiViewMode>>[
                  ButtonSegment<_AiViewMode>(
                    value: _AiViewMode.summary,
                    label: Text('Summary'),
                    icon: Icon(Icons.analytics_outlined),
                  ),
                  ButtonSegment<_AiViewMode>(
                    value: _AiViewMode.itinerary,
                    label: Text('Itinerary'),
                    icon: Icon(Icons.route_outlined),
                  ),
                ],
                selected: <_AiViewMode>{_currentView},
                onSelectionChanged: (Set<_AiViewMode> newSelection) {
                  setState(() {
                    _currentView = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.blue.withOpacity(0.2),
                  selectedForegroundColor: Colors.blue.shade800,
                ),
              ),
            ),
          ),

          // ⭐ 핵심: 아래 Expanded 부분에서 _buildItineraryView() 대신 AiItineraryView 사용
          Expanded(
            child: _currentView == _AiViewMode.summary
                ? _buildSummaryView() // Summary 탭
                : AiItineraryView(    // Itinerary 탭
              title: widget.entry.title,
              entryId: widget.entry.id,
              sourceType: ItinerarySourceType.tripLog,
              // 캘린더에서 온 게 아니므로 처음 페이지부터 시작
              initialDate: null,
            ),
          ),
        ],
      ),
    );
  }


// 2. 기존 body 내용을 담을 _buildSummaryView 메서드 추가
  Widget _buildSummaryView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 기존 build 메서드의 body에 있던 위젯들이 여기에 위치 ---
            if (_showItinerary) _buildItineraryCard(),
            if (_showItinerary) const SizedBox(height: 16),

            // 지도 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SizedBox( // width 속성 대신 SizedBox 사용
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View on Map'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripMapScreen(
                            summary: _processedSummary,
                            matchedCitiesWithDetails: _matchedCitiesForMap,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white, // styleFrom 내부로 이동
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // shape 내부로 이동
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ================================
            // ⭐ NEW SECTIONS INSERTED HERE ⭐
            // ================================

            // 🗺️ Countries & Cities 섹션
            if (_processedSummary.countries.isNotEmpty ||
                _processedSummary.cities.isNotEmpty)
              _buildCitiesCard(context, _groupedCitiesByCountry),

            const SizedBox(height: 16),

            // 🛫 Airports 섹션
            if (_processedSummary.airports.isNotEmpty)
              _buildAirportsSection(context),

            const SizedBox(height: 16),

            // ✈️ Flights 섹션
            if (_processedSummary.flights.isNotEmpty)
              _buildFlightsCard(context, _processedSummary.flights),

            const SizedBox(height: 24),

            // ================================
            // ⭐ 기존 Summary 부분 계속 진행 ⭐
            // ================================

            _buildTrainsCard(context, _processedSummary.trains),
            const SizedBox(height: 16),
            _buildBusesCard(context, _processedSummary.buses),
            const SizedBox(height: 16),
            _buildFerriesCard(context, _processedSummary.ferries),
            const SizedBox(height: 16),
            _buildCarsCard(context, _processedSummary.cars),
            const SizedBox(height: 16),
            _buildLandmarksCard(context, _processedSummary.landmarks),

            const SizedBox(height: 24),
            const Divider(thickness: 2),
            const SizedBox(height: 16),

            if (_hasUnsavedChanges)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isSavingModifications
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.save_outlined),
                        label: _isSavingModifications
                            ? const Text('Saving Modifications...')
                            : const Text('Save Modifications'),
                        onPressed: _isSavingModifications ? null : _saveModifications,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isMatching
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.refresh),
                  label: _isMatching
                      ? const Text('Matching...')
                      : const Text('Re-run Database Matching'),
                  onPressed: _isMatching
                      ? null
                      : () {
                    _performMatching();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSending
                      ? const SizedBox.shrink()
                      : const Icon(Icons.save),
                  label: _isSending
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                      : const Text('Save Changes to My Data'),
                  onPressed: _isSending ? null : _sendDataToProviders,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            _buildMatchedItemsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildItineraryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Generated AI Itinerary', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            if (_isGeneratingItinerary)
              const Center(child: CircularProgressIndicator())
            else if (_generatedItinerary.isNotEmpty)
              SelectableText(
                _generatedItinerary,
                style: const TextStyle(fontFamily: 'monospace', height: 1.5, fontSize: 12),
              )
            else
              const Text('Press the "Re-run AI" button to generate an itinerary based on the summary.'),
          ],
        ),
      ),
    );
  }




  // _buildCountriesCard는 이제 _buildCitiesCard에 통합되므로 제거합니다.
  Widget _buildCountriesCard(BuildContext context, List<CountryLog> countries) {
    return const SizedBox.shrink();
  }

  // _buildCitiesCard를 수정하여 국가별로 그룹화된 도시를 표시합니다.
  // _buildCitiesCard 메서드를 다음과 같이 수정하세요
  Widget _buildCitiesCard(BuildContext context, List<CitiesInCountry> citiesByCountry) {
    const Color pinkTheme = Color(0xFFE91E63); // 기본 핑크색 테마

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.location_city, color: pinkTheme, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Countries & Cities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddCityDialog(context),
                color: pinkTheme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_processedSummary.cities.isEmpty && !_isMatching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No cities to display for this trip.'),
              ),
            ),
          if (_isMatching && citiesByCountry.isEmpty) // _processedSummary 대신 파라미터 사용
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
          // 🆕 파라미터로 전달받은 정렬된 리스트(citiesByCountry)를 사용해야 함
          ...citiesByCountry.map((cbc) {
            if (cbc.cities.isEmpty) return const SizedBox.shrink();

            return _buildCountryCityGroup(context, cbc);
          }).toList(),
          // ... 생략
        ],
      ),
    );
  }

  Widget _buildCountryCityGroup(BuildContext context, CitiesInCountry citiesInCountry) {
    final countryProvider = context.watch<CountryProvider>();

    // 1. 국가명과 코드를 분리하여 정확한 매칭 시도
    String rawName = citiesInCountry.countryName;
    String cleanName = rawName.replaceAll(RegExp(r'\s*\([A-Z0-9]{2,3}\)'), '').trim();
    String? code;

    final codeMatch = RegExp(r'\(([A-Z0-9]{2,3})\)').firstMatch(rawName);
    if (codeMatch != null) {
      code = codeMatch.group(1);
    }

    // 2. Country 객체 찾기 (이름 -> 3글자 코드 -> 2글자 코드 순서로 검색)
    Country? matchedCountry;

    // A. 이름으로 찾기
    matchedCountry = countryProvider.allCountries.firstWhereOrNull(
            (c) => c.name.toLowerCase() == cleanName.toLowerCase()
    );

    // B. 코드로 찾기 (A2 또는 A3)
    if (matchedCountry == null && code != null) {
      matchedCountry = countryProvider.allCountries.firstWhereOrNull(
              (c) => c.isoA2.toUpperCase() == code || c.isoA3.toUpperCase() == code
      );
    }

    // 3. 색상 결정 (매칭 안되면 기본 핑크)
    Color themeColor = const Color(0xFFE91E63);
    if (matchedCountry != null && matchedCountry.themeColor != null) {
      themeColor = matchedCountry.themeColor!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Country Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // 국기 표시
                if (matchedCountry != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 32,
                        height: 24,
                        child: CountryFlag.fromCountryCode(
                          matchedCountry.isoA2,
                        ),
                      ),
                    ),
                  ),
                // 국가명 텍스트
                Text(
                  matchedCountry?.name ?? citiesInCountry.countryName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ],
            ),
          ),
          // Cities List
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: citiesInCountry.cities.map((cityDetail) {
                return _buildCityItem(context, cityDetail, themeColor);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityItem(BuildContext context, CityVisitDetail cityDetail, Color themeColor) {
    final displayCityName = cityDetail.name.split('|').first.trim().replaceAll(RegExp(r'\s*\(.*\)$'), '').trim();

    // 날짜 포맷팅
    String arrivalDateText = '';
    if (cityDetail.arrivalDate != null && cityDetail.arrivalDate != 'Unknown' && cityDetail.arrivalDate != 'TBD') {
      try {
        final date = DateTime.parse(cityDetail.arrivalDate!);
        arrivalDateText = DateFormat('MMM d').format(date);
      } catch (e) {
        arrivalDateText = cityDetail.arrivalDate!;
      }
    }

    String departureDateText = '';
    if (cityDetail.departureDate != null && cityDetail.departureDate != 'Unknown' && cityDetail.departureDate != 'TBD') {
      try {
        final date = DateTime.parse(cityDetail.departureDate!);
        departureDateText = DateFormat('MMM d').format(date);
      } catch (e) {
        departureDateText = cityDetail.departureDate!;
      }
    }

    // 🆕 헬퍼 함수 사용하여 기간 포맷팅 (49h -> 2d 1h)
    String displayDuration = _formatDuration(cityDetail.duration);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _showEditCityDialog(context, cityDetail),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: themeColor.withOpacity(0.2), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: themeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        displayCityName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _confirmAndDeleteCity(context, cityDetail.name),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Arrival
                    if (arrivalDateText.isNotEmpty)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.flight_land, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              arrivalDateText,
                              style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            ),
                            if (cityDetail.arrivalTime != null && cityDetail.arrivalTime != 'N/A')
                              Text(
                                ' ${cityDetail.arrivalTime}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                    // Departure
                    if (departureDateText.isNotEmpty)
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.flight_takeoff, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              departureDateText,
                              style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            ),
                            if (cityDetail.departureTime != null && cityDetail.departureTime != 'N/A')
                              Text(
                                ' ${cityDetail.departureTime}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (displayDuration != 'N/A')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          displayDuration,
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCityDialog(BuildContext context) async {
    final cityProvider = context.read<CityProvider>();
    final countryProvider = context.read<CountryProvider>();

    final TextEditingController citySearchController = TextEditingController();
    final TextEditingController countrySearchController = TextEditingController();
    final TextEditingController arrivalDateController = TextEditingController();
    final TextEditingController arrivalTimeController = TextEditingController();
    final TextEditingController departureDateController = TextEditingController();
    final TextEditingController departureTimeController = TextEditingController();
    final TextEditingController durationDaysController = TextEditingController();
    final TextEditingController durationHoursController = TextEditingController();

    List<City> filteredCities = [];
    List<Country> filteredCountries = [];
    bool isCityListVisible = false;
    bool isCountryListVisible = false;

    // 🆕 Duration 자동 계산 로직
    void _calculateAutoDuration() {
      if (arrivalDateController.text.isNotEmpty && arrivalTimeController.text.isNotEmpty &&
          departureDateController.text.isNotEmpty && departureTimeController.text.isNotEmpty) {
        try {
          final start = DateTime.parse('${arrivalDateController.text} ${arrivalTimeController.text}:00');
          final end = DateTime.parse('${departureDateController.text} ${departureTimeController.text}:00');
          final diff = end.difference(start);

          if (!diff.isNegative) {
            final totalHours = diff.inHours;
            final days = totalHours ~/ 24;
            final hours = totalHours % 24;

            durationDaysController.text = days.toString();
            durationHoursController.text = hours.toString();
          }
        } catch (e) {
          // 파싱 실패시 무시
        }
      }
    }

    Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
        _calculateAutoDuration(); // 날짜 선택 후 계산 시도
      }
    }

    Future<void> _selectTimeHelper(BuildContext context, TextEditingController controller) async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) {
        controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _calculateAutoDuration(); // 시간 선택 후 계산 시도
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New City'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 도시 검색 (Hint 제거)
                      TextField(
                        controller: citySearchController,
                        decoration: const InputDecoration(
                          labelText: 'City Name',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value.isEmpty) {
                              filteredCities = [];
                              isCityListVisible = false;
                            } else {
                              filteredCities = cityProvider.allCities.where((city) {
                                return city.name.toLowerCase().contains(value.toLowerCase());
                              }).take(5).toList();
                              isCityListVisible = true;
                            }
                          });
                        },
                      ),
                      if (isCityListVisible)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              if (citySearchController.text.isNotEmpty)
                                ListTile(
                                  leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                  title: Text('Add "${citySearchController.text}" as custom'),
                                  onTap: () {
                                    setState(() {
                                      isCityListVisible = false;
                                    });
                                  },
                                ),
                              const Divider(height: 1),
                              ...filteredCities.map((city) => ListTile(
                                title: Text(city.name),
                                subtitle: Text(city.country),
                                onTap: () {
                                  citySearchController.text = city.name;
                                  final cityCode = city.countryIsoA2.toUpperCase();
                                  Country? matchedCountry;
                                  if (cityCode.isNotEmpty && cityCode.length == 2) {
                                    matchedCountry = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA2.toUpperCase() == cityCode);
                                  }
                                  if (matchedCountry == null && cityCode.isNotEmpty && cityCode.length == 3) {
                                    matchedCountry = countryProvider.allCountries.firstWhereOrNull((c) => c.isoA3.toUpperCase() == cityCode);
                                  }
                                  if (matchedCountry == null && city.country.isNotEmpty && city.country != 'Unknown') {
                                    matchedCountry = countryProvider.allCountries.firstWhereOrNull((c) => c.name.toLowerCase() == city.country.toLowerCase());
                                  }
                                  if (matchedCountry != null) {
                                    countrySearchController.text = matchedCountry.name;
                                  }
                                  setState(() {
                                    isCityListVisible = false;
                                  });
                                },
                              )),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // 2. 국가 검색 (Hint 제거)
                      TextField(
                        controller: countrySearchController,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          prefixIcon: Icon(Icons.flag),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value.isEmpty) {
                              filteredCountries = [];
                              isCountryListVisible = false;
                            } else {
                              filteredCountries = countryProvider.allCountries.where((c) {
                                return c.name.toLowerCase().contains(value.toLowerCase());
                              }).take(5).toList();
                              isCountryListVisible = true;
                            }
                          });
                        },
                      ),
                      if (isCountryListVisible)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: filteredCountries.map((country) => ListTile(
                              title: Text(country.name),
                              onTap: () {
                                countrySearchController.text = country.name;
                                setState(() {
                                  isCountryListVisible = false;
                                });
                              },
                            )).toList(),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // 3. Arrival (Hint 제거)
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectDate(dialogContext, arrivalDateController),
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: arrivalDateController,
                                  decoration: InputDecoration(
                                    labelText: 'Arrival Date',
                                    suffixIcon: Icon(Icons.calendar_today),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: arrivalTimeController,
                              decoration: InputDecoration(
                                labelText: 'Time',
                                // hintText 제거됨
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time),
                                  onPressed: () => _selectTimeHelper(dialogContext, arrivalTimeController),
                                ),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 4. Departure (Hint 제거)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: departureDateController,
                              decoration: InputDecoration(
                                labelText: 'Departure Date',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today_outlined),
                                  onPressed: () => _selectDate(dialogContext, departureDateController),
                                ),
                              ),
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: departureTimeController,
                              decoration: InputDecoration(
                                labelText: 'Time',
                                // hintText 제거됨
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time_outlined),
                                  onPressed: () => _selectTimeHelper(dialogContext, departureTimeController),
                                ),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 5. Duration
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: durationDaysController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Days',
                                suffixText: 'days',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: durationHoursController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Hours',
                                suffixText: 'h',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: const Text('Add'),
                  onPressed: () {
                    // (저장 로직은 기존과 동일)
                    final String cityName = citySearchController.text.trim();
                    final String countryName = countrySearchController.text.trim();

                    if (cityName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('City name is required.')));
                      return;
                    }

                    String countryIso = 'N/A';
                    if (countryName.isNotEmpty) {
                      final matchedCountry = countryProvider.allCountries.firstWhereOrNull(
                              (c) => c.name.toLowerCase() == countryName.toLowerCase()
                      );
                      if (matchedCountry != null) {
                        countryIso = matchedCountry.isoA2;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a valid country.')));
                        return;
                      }
                    }

                    // Duration 계산
                    final int days = int.tryParse(durationDaysController.text.trim()) ?? 0;
                    final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                    final totalHours = (days * 24) + hours;

                    String durationStr = 'N/A';
                    if (totalHours > 0) {
                      // 저장할 때는 항상 시간 단위(h)로 통일하거나, 날짜로 포맷팅 (여기서는 h 유지)
                      durationStr = '${totalHours}h';
                    }

                    String finalCityName = cityName;
                    if (countryIso != 'N/A') {
                      finalCityName = '$cityName|$countryIso';
                    }

                    final newCityVisitDetail = CityVisitDetail(
                      name: finalCityName,
                      arrivalDate: arrivalDateController.text.isNotEmpty ? arrivalDateController.text : 'Unknown',
                      arrivalTime: arrivalTimeController.text.isNotEmpty ? arrivalTimeController.text : null,
                      departureDate: departureDateController.text.isNotEmpty ? departureDateController.text : 'Unknown',
                      departureTime: departureTimeController.text.isNotEmpty ? departureTimeController.text : null,
                      duration: durationStr,
                    );

                    String countryDisplayName = countryName.isNotEmpty ? countryName : "Unknown Country";

                    List<CitiesInCountry> updatedProcessedSummaryCities = List.from(_processedSummary.cities);
                    CitiesInCountry? existingGroup = updatedProcessedSummaryCities.firstWhereOrNull(
                            (group) => group.countryName == countryDisplayName
                    );

                    if (existingGroup == null) {
                      updatedProcessedSummaryCities.add(CitiesInCountry(
                        countryName: countryDisplayName,
                        cities: [newCityVisitDetail],
                      ));
                    } else {
                      existingGroup.cities.add(newCityVisitDetail);
                    }

                    _processedSummary = AiSummary(
                      countries: _processedSummary.countries,
                      cities: updatedProcessedSummaryCities,
                      airports: _processedSummary.airports,
                      flights: _processedSummary.flights,
                      trains: _processedSummary.trains,
                      buses: _processedSummary.buses,
                      ferries: _processedSummary.ferries,
                      cars: _processedSummary.cars,
                      landmarks: _processedSummary.landmarks,
                      transitAirports: _processedSummary.transitAirports,
                      startLocation: _processedSummary.startLocation,
                      endLocation: _processedSummary.endLocation,
                    );

                    Navigator.of(dialogContext).pop();
                    _markAsChanged();
                    _refreshCityGroupsUI();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('City added!'), backgroundColor: Colors.green),
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

// 1. 시간 선택을 위한 새로운 헬퍼 함수
  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    // 현재 컨트롤러의 텍스트를 파싱하여 초기 시간 설정
    TimeOfDay initialTime = TimeOfDay.now();
    try {
      if (controller.text.isNotEmpty) {
        final parts = controller.text.split(':');
        initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      // 파싱 실패 시 현재 시간으로 대체
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      // 24시간 형식(HH:mm)으로 저장
      controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }


// 2. 🆕 [수정] Edit City Dialog with same UI as Add New City
  Future<void> _showEditCityDialog(BuildContext context, CityVisitDetail originalCityDetail) async {
    final cityProvider = context.read<CityProvider>();
    final countryProvider = context.read<CountryProvider>();

    String initialCityName = originalCityDetail.name.split('|').first.trim().replaceAll(RegExp(r'\s*\(.*\)$'), '').trim();
    String initialCountryCode = 'N/A';
    String initialCountryName = '';

    if (originalCityDetail.name.contains('|')) {
      final parts = originalCityDetail.name.split('|');
      if (parts.length > 1) initialCountryCode = parts[1].trim().toUpperCase();
    } else {
      final aiCityMatch = RegExp(r'\(([A-Z]{2,3})\)$', caseSensitive: false).firstMatch(originalCityDetail.name);
      if (aiCityMatch != null) initialCountryCode = aiCityMatch.group(1)!.trim();
    }

    if (initialCountryCode != 'N/A' && initialCountryCode.isNotEmpty) {
      final matchedCountry = countryProvider.allCountries.firstWhereOrNull(
              (c) => c.isoA2.toUpperCase() == initialCountryCode || c.isoA3.toUpperCase() == initialCountryCode
      );
      if (matchedCountry != null) initialCountryName = matchedCountry.name;
    }

    // Duration 파싱 (기존 값)
    int initialDurationDays = 0;
    int initialDurationHours = 0;

    // "26h" 같은 형식이거나 "1d 2h" 형식이 들어올 수 있음
    String rawDur = originalCityDetail.duration;
    if (rawDur.isNotEmpty && rawDur != 'N/A') {
      int totalH = 0;
      if (rawDur.contains('d')) {
        // 1d 2h 파싱 (단순화)
        final dMatch = RegExp(r'(\d+)d').firstMatch(rawDur);
        final hMatch = RegExp(r'(\d+)h').firstMatch(rawDur);
        if (dMatch != null) totalH += int.parse(dMatch.group(1)!) * 24;
        if (hMatch != null) totalH += int.parse(hMatch.group(1)!);
      } else if (rawDur.contains('h')) {
        final hMatch = RegExp(r'(\d+)h').firstMatch(rawDur);
        if (hMatch != null) totalH = int.parse(hMatch.group(1)!);
      }
      initialDurationDays = totalH ~/ 24;
      initialDurationHours = totalH % 24;
    }

    final TextEditingController citySearchController = TextEditingController(text: initialCityName);
    final TextEditingController countrySearchController = TextEditingController(text: initialCountryName);
    final TextEditingController arrivalDateController = TextEditingController(text: originalCityDetail.arrivalDate != 'Unknown' ? originalCityDetail.arrivalDate : '');
    final TextEditingController arrivalTimeController = TextEditingController(text: originalCityDetail.arrivalTime ?? '');
    final TextEditingController departureDateController = TextEditingController(text: originalCityDetail.departureDate ?? '');
    final TextEditingController departureTimeController = TextEditingController(text: originalCityDetail.departureTime ?? '');
    final TextEditingController durationDaysController = TextEditingController(text: initialDurationDays > 0 ? initialDurationDays.toString() : '');
    final TextEditingController durationHoursController = TextEditingController(text: initialDurationHours > 0 ? initialDurationHours.toString() : '');

    List<City> filteredCities = [];
    List<Country> filteredCountries = [];
    bool isCityListVisible = false;
    bool isCountryListVisible = false;

    // 🆕 Duration 자동 계산
    void _calculateAutoDuration() {
      if (arrivalDateController.text.isNotEmpty && arrivalTimeController.text.isNotEmpty &&
          departureDateController.text.isNotEmpty && departureTimeController.text.isNotEmpty) {
        try {
          final start = DateTime.parse('${arrivalDateController.text} ${arrivalTimeController.text}:00');
          final end = DateTime.parse('${departureDateController.text} ${departureTimeController.text}:00');
          final diff = end.difference(start);

          if (!diff.isNegative) {
            final totalHours = diff.inHours;
            final days = totalHours ~/ 24;
            final hours = totalHours % 24;

            durationDaysController.text = days.toString();
            durationHoursController.text = hours.toString();
          }
        } catch (e) {}
      }
    }

    Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
        _calculateAutoDuration();
      }
    }

    Future<void> _selectTimeHelper(BuildContext context, TextEditingController controller) async {
      TimeOfDay initialTime = TimeOfDay.now();
      if(controller.text.isNotEmpty) {
        try {
          final parts = controller.text.split(':');
          initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        } catch(e) {}
      }
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );
      if (picked != null) {
        controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _calculateAutoDuration();
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit City Visit'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 도시 검색 (Hint 제거)
                      TextField(
                        controller: citySearchController,
                        decoration: const InputDecoration(
                          labelText: 'City Name',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value.isEmpty) {
                              filteredCities = [];
                              isCityListVisible = false;
                            } else {
                              filteredCities = cityProvider.allCities.where((city) {
                                return city.name.toLowerCase().contains(value.toLowerCase());
                              }).take(5).toList();
                              isCityListVisible = true;
                            }
                          });
                        },
                      ),
                      if (isCityListVisible)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              if (citySearchController.text.isNotEmpty)
                                ListTile(
                                  leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                  title: Text('Use "${citySearchController.text}" as custom'),
                                  onTap: () {
                                    setState(() {
                                      isCityListVisible = false;
                                    });
                                  },
                                ),
                              const Divider(height: 1),
                              ...filteredCities.map((city) => ListTile(
                                title: Text(city.name),
                                subtitle: Text(city.country),
                                onTap: () {
                                  citySearchController.text = city.name;
                                  // (국가 자동완성 로직 생략 - 위와 동일)
                                  setState(() { isCityListVisible = false; });
                                },
                              )),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // 2. 국가 검색 (Hint 제거)
                      TextField(
                        controller: countrySearchController,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          prefixIcon: Icon(Icons.flag),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value.isEmpty) {
                              filteredCountries = [];
                              isCountryListVisible = false;
                            } else {
                              filteredCountries = countryProvider.allCountries.where((c) {
                                return c.name.toLowerCase().contains(value.toLowerCase());
                              }).take(5).toList();
                              isCountryListVisible = true;
                            }
                          });
                        },
                      ),
                      if (isCountryListVisible)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: filteredCountries.map((country) => ListTile(
                              title: Text(country.name),
                              subtitle: Text(country.isoA2),
                              onTap: () {
                                countrySearchController.text = country.name;
                                setState(() { isCountryListVisible = false; });
                              },
                            )).toList(),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // 3. Arrival
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectDate(dialogContext, arrivalDateController),
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: arrivalDateController,
                                  decoration: InputDecoration(
                                    labelText: 'Arrival Date',
                                    suffixIcon: Icon(Icons.calendar_today),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: arrivalTimeController,
                              decoration: InputDecoration(
                                labelText: 'Arrival Time',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time),
                                  onPressed: () => _selectTimeHelper(dialogContext, arrivalTimeController),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 4. Departure
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectDate(dialogContext, departureDateController),
                              child: AbsorbPointer(
                                child: TextField(
                                  controller: departureDateController,
                                  decoration: InputDecoration(
                                    labelText: 'Departure Date',
                                    suffixIcon: Icon(Icons.calendar_today),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: departureTimeController,
                              decoration: InputDecoration(
                                labelText: 'Departure Time',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time),
                                  onPressed: () => _selectTimeHelper(dialogContext, departureTimeController),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 5. Duration
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: durationDaysController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Days',
                                suffixText: 'days',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: durationHoursController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Hours',
                                suffixText: 'h',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    // (저장 로직은 위와 동일하게 duration 계산)
                    final String cityName = citySearchController.text.trim();
                    final String countryName = countrySearchController.text.trim();

                    if (cityName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('City name is required.')));
                      return;
                    }

                    String countryIso = 'N/A';
                    if (countryName.isNotEmpty) {
                      final matchedCountry = countryProvider.allCountries.firstWhereOrNull(
                              (c) => c.name.toLowerCase() == countryName.toLowerCase()
                      );
                      if (matchedCountry != null) {
                        countryIso = matchedCountry.isoA2;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a valid country.')));
                        return;
                      }
                    }

                    final int days = int.tryParse(durationDaysController.text.trim()) ?? 0;
                    final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                    final totalHours = (days * 24) + hours;

                    String durationStr = 'N/A';
                    if (totalHours > 0) {
                      durationStr = '${totalHours}h';
                    }

                    String finalCityName = cityName;
                    if (countryIso != 'N/A') {
                      finalCityName = '$cityName|$countryIso';
                    }

                    final updatedCityDetail = CityVisitDetail(
                      name: finalCityName,
                      arrivalDate: arrivalDateController.text.isNotEmpty ? arrivalDateController.text : 'Unknown',
                      arrivalTime: arrivalTimeController.text.isNotEmpty ? arrivalTimeController.text : null,
                      departureDate: departureDateController.text.isNotEmpty ? departureDateController.text : 'Unknown',
                      departureTime: departureTimeController.text.isNotEmpty ? departureTimeController.text : null,
                      duration: durationStr,
                      hasLived: originalCityDetail.hasLived,
                      rating: originalCityDetail.rating,
                      visitDateRanges: originalCityDetail.visitDateRanges,
                    );

                    // --- _processedSummary 업데이트 로직 (기존과 동일) ---
                    final List<CitiesInCountry> newCitiesInCountryList = [];
                    for (var group in _processedSummary.cities) {
                      final List<CityVisitDetail> remainingCities = [];
                      for (var city in group.cities) {
                        if (city.name != originalCityDetail.name) {
                          remainingCities.add(city);
                        }
                      }
                      if (remainingCities.isNotEmpty) {
                        newCitiesInCountryList.add(CitiesInCountry(
                            countryName: group.countryName,
                            cities: remainingCities
                        ));
                      }
                    }

                    String targetCountryName = countryName.isNotEmpty ? countryName : "Unknown Country";
                    CitiesInCountry? targetGroup = newCitiesInCountryList.firstWhereOrNull(
                            (g) => g.countryName == targetCountryName
                    );

                    if (targetGroup != null) {
                      targetGroup.cities.add(updatedCityDetail);
                    } else {
                      newCitiesInCountryList.add(CitiesInCountry(
                          countryName: targetCountryName,
                          cities: [updatedCityDetail]
                      ));
                    }

                    _processedSummary = AiSummary(
                      countries: _processedSummary.countries,
                      cities: newCitiesInCountryList,
                      airports: _processedSummary.airports,
                      flights: _processedSummary.flights,
                      trains: _processedSummary.trains,
                      buses: _processedSummary.buses,
                      ferries: _processedSummary.ferries,
                      cars: _processedSummary.cars,
                      landmarks: _processedSummary.landmarks,
                      transitAirports: _processedSummary.transitAirports,
                      startLocation: _processedSummary.startLocation,
                      endLocation: _processedSummary.endLocation,
                    );

                    Navigator.of(dialogContext).pop();
                    _markAsChanged();
                    _refreshCityGroupsUI();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('City updated!'),
                        backgroundColor: Colors.green,
                      ),
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


  Future<void> _confirmAndDeleteCity(BuildContext context, String cityName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete City'),
          content: Text('Are you sure you want to delete "$cityName"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final List<CitiesInCountry> updatedCitiesInCountry = [];
                for (var group in _processedSummary.cities) {
                  final updatedCities = group.cities.where((cityDetail) => cityDetail.name != cityName).toList();
                  if (updatedCities.isNotEmpty) {
                    updatedCitiesInCountry.add(CitiesInCountry(countryName: group.countryName, cities: updatedCities));
                  }
                }

                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: updatedCitiesInCountry,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: _processedSummary.buses,
                  ferries: _processedSummary.ferries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );

                Navigator.of(dialogContext).pop(true);
                _markAsChanged();
                // 🛑 UI 갱신만 수행
                _refreshCityGroupsUI();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$cityName" removed!'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlightsCard(BuildContext context, List<AirlineLog> flights) {
    const Color purpleTheme = Color(0xFF9C27B0); // 보라색 테마

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.flight_takeoff, color: purpleTheme, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Flights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddFlightDialog(context),
                color: purpleTheme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (flights.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No flights for this trip.'),
              ),
            )
          else
            ...flights.expand((airlineLog) {
              final sortedFlights = List<FlightDetail>.from(airlineLog.flights)
                ..sort((a, b) => a.sequence.compareTo(b.sequence));

              return sortedFlights.map((detail) {
                return _buildFlightItem(context, detail, airlineLog, purpleTheme);
              });
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildFlightItem(BuildContext context, FlightDetail detail, AirlineLog airlineLog, Color themeColor) {
    // 날짜 포맷팅
    String dateText = '';
    if (detail.flightDate != null && detail.flightDate!.isNotEmpty && detail.flightDate != 'Unknown') {
      try {
        final date = DateTime.parse(detail.flightDate!);
        dateText = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        dateText = detail.flightDate!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showEditFlightDialog(context, airlineLog, detail),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 항공편명
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        detail.flightNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 항공사명
                    Expanded(
                      child: Text(
                        airlineLog.airlineName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 삭제 버튼
                    GestureDetector(
                      onTap: () => _confirmAndDeleteFlight(context, detail.flightNumber, airlineLog.airlineName),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 경로 및 시간
                Row(
                  children: [
                    Text(
                      detail.origin,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16, color: themeColor),
                    const SizedBox(width: 8),
                    Text(
                      detail.destination,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 날짜 및 시간 정보
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (dateText.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            dateText,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    if (detail.departureTime != null && detail.departureTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flight_takeoff, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            detail.departureTime!,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    if (detail.arrivalTime != null && detail.arrivalTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flight_land, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            detail.arrivalTime!,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    if (detail.duration != null && detail.duration!.isNotEmpty && detail.duration != 'N/A')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            detail.duration!,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddFlightDialog(BuildContext context) async {
    final airlineProvider = context.read<AirlineProvider>(); //
    final TextEditingController airlineNameController = TextEditingController();
    final TextEditingController flightNumberController = TextEditingController();
    final TextEditingController originController = TextEditingController();
    final TextEditingController destinationController = TextEditingController();
    final TextEditingController flightDateController = TextEditingController();
    final TextEditingController departureTimeController = TextEditingController();
    final TextEditingController arrivalTimeController = TextEditingController();
    final TextEditingController durationHoursController = TextEditingController();
    final TextEditingController durationMinutesController = TextEditingController();

    List<Airline> filteredAirlines = [];
    bool isAirlineListVisible = false;

    Future<void> _selectFlightDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        flightDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Flight'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: airlineNameController,
                          decoration: const InputDecoration(
                            labelText: 'Airline Name',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value.isEmpty) {
                                filteredAirlines = [];
                                isAirlineListVisible = false;
                              } else {
                                filteredAirlines = airlineProvider.airlines.where((a) { //
                                  return a.name.toLowerCase().contains(value.toLowerCase()) ||
                                      a.code.toLowerCase().contains(value.toLowerCase());
                                }).take(5).toList();
                                isAirlineListVisible = true;
                              }
                            });
                          },
                        ),
                        if (isAirlineListVisible && filteredAirlines.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredAirlines.length,
                              separatorBuilder: (ctx, idx) => const Divider(height: 1),
                              itemBuilder: (ctx, index) {
                                final airline = filteredAirlines[index]; //
                                return ListTile(
                                  dense: true,
                                  title: Text(airline.name),
                                  subtitle: Text(airline.code),
                                  onTap: () {
                                    setState(() {
                                      airlineNameController.text = airline.name;
                                      isAirlineListVisible = false;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: flightNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Flight Number',
                        hintText: 'e.g. KE123, UA456',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: originController,
                      decoration: const InputDecoration(
                        labelText: 'Origin ',
                        hintText: 'e.g. ICN, LAX',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination ',
                        hintText: 'e.g. JFK, NRT',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: flightDateController,
                      decoration: InputDecoration(
                        labelText: 'Flight Date',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectFlightDate(dialogContext),
                        ),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: departureTimeController,
                            decoration: InputDecoration(
                              labelText: 'Departure Time',
                              hintText: 'e.g., 08:30, 14:00',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: () => _selectTime(dialogContext, departureTimeController),
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: arrivalTimeController,
                            decoration: InputDecoration(
                              labelText: 'Arrival Time',
                              hintText: 'e.g., 10:45, 16:30',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationHoursController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration ',
                              hintText: 'e.g., 2',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: durationMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration ',
                              hintText: 'e.g., 30',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Add'),
                  onPressed: () {
                    final String airlineName = airlineNameController.text.trim();
                    final String flightNumber = flightNumberController.text.trim();
                    final String origin = originController.text.trim().toUpperCase();
                    final String destination = destinationController.text.trim().toUpperCase();
                    final String flightDate = flightDateController.text.trim();
                    final String? duration;

                    final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                    final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                    if (hours == 0 && minutes == 0) {
                      duration = null;
                    } else if (hours == 0) {
                      duration = '$minutes min';
                    } else if (minutes == 0) {
                      duration = '$hours hours';
                    } else {
                      duration = '$hours hours $minutes min';
                    }

                    if (airlineName.isEmpty || flightNumber.isEmpty || origin.isEmpty || destination.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('All fields are required.'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final allFlightDetails = _processedSummary.flights.expand((al) => al.flights).toList();
                    final int nextSequence = allFlightDetails.isEmpty
                        ? 1
                        : (allFlightDetails.map((fd) => fd.sequence).reduce(max)) + 1;

                    final newFlightDetail = FlightDetail(
                      flightNumber: flightNumber,
                      origin: origin,
                      destination: destination,
                      flightDate: flightDate.isNotEmpty ? flightDate : null,
                      departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                      arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                      duration: duration,
                      sequence: nextSequence,
                    );

                    final List<AirlineLog> updatedFlights = List.from(_processedSummary.flights);
                    AirlineLog? existingAirlineLog = updatedFlights.firstWhereOrNull(
                          (log) => log.airlineName == airlineName,
                    );
                    if (existingAirlineLog == null) {
                      updatedFlights.add(AirlineLog(
                        airlineName: airlineName,
                        flights: [newFlightDetail],
                      ));
                    } else {
                      if (!existingAirlineLog.flights.any((f) =>
                      f.flightNumber == newFlightDetail.flightNumber &&
                          f.origin == newFlightDetail.origin &&
                          f.destination == newFlightDetail.destination &&
                          f.flightDate == newFlightDetail.flightDate
                      )) {
                        existingAirlineLog.flights.add(newFlightDetail);
                      }
                    }

                    _processedSummary = AiSummary(
                      countries: _processedSummary.countries,
                      cities: _processedSummary.cities,
                      airports: _processedSummary.airports,
                      flights: updatedFlights,
                      trains: _processedSummary.trains,
                      buses: _processedSummary.buses,
                      ferries: _processedSummary.ferries,
                      cars: _processedSummary.cars,
                      landmarks: _processedSummary.landmarks,
                      transitAirports: _processedSummary.transitAirports,
                      startLocation: _processedSummary.startLocation,
                      endLocation: _processedSummary.endLocation,
                    );
                    Navigator.of(dialogContext).pop();
                    _markAsChanged();
                    _performMatching();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Flight added!'),
                        backgroundColor: Colors.green,
                      ),
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

  Future<void> _showEditFlightDialog(BuildContext context, AirlineLog originalAirlineLog, FlightDetail originalFlightDetail) async {
    final airlineProvider = context.read<AirlineProvider>(); //
    final TextEditingController airlineNameController = TextEditingController(text: originalAirlineLog.airlineName);
    final TextEditingController flightNumberController = TextEditingController(text: originalFlightDetail.flightNumber);
    final TextEditingController originController = TextEditingController(text: originalFlightDetail.origin);
    final TextEditingController destinationController = TextEditingController(text: originalFlightDetail.destination);
    final TextEditingController flightDateController = TextEditingController(text: originalFlightDetail.flightDate);
    final TextEditingController departureTimeController = TextEditingController(text: originalFlightDetail.departureTime);
    final TextEditingController arrivalTimeController = TextEditingController(text: originalFlightDetail.arrivalTime);

    // Duration 파싱
    int initialDurationHours = 0;
    int initialDurationMinutes = 0;
    if (originalFlightDetail.duration != null && originalFlightDetail.duration!.isNotEmpty && originalFlightDetail.duration != 'N/A') {
      final parts = originalFlightDetail.duration!.split(' ');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].toLowerCase().contains('hour')) {
          initialDurationHours = int.tryParse(parts[i - 1]) ?? 0;
        } else if (parts[i].toLowerCase().contains('min')) {
          initialDurationMinutes = int.tryParse(parts[i - 1]) ?? 0;
        }
      }
    }
    final TextEditingController durationHoursController = TextEditingController(text: initialDurationHours.toString());
    final TextEditingController durationMinutesController = TextEditingController(text: initialDurationMinutes.toString());

    List<Airline> filteredAirlines = [];
    bool isAirlineListVisible = false;

    Future<void> _selectFlightDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(flightDateController.text) ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        flightDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Flight'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: airlineNameController,
                          decoration: const InputDecoration(
                            labelText: 'Airline Name',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value.isEmpty) {
                                filteredAirlines = [];
                                isAirlineListVisible = false;
                              } else {
                                filteredAirlines = airlineProvider.airlines.where((a) { //
                                  return a.name.toLowerCase().contains(value.toLowerCase()) ||
                                      a.code.toLowerCase().contains(value.toLowerCase());
                                }).take(5).toList();
                                isAirlineListVisible = true;
                              }
                            });
                          },
                        ),
                        if (isAirlineListVisible && filteredAirlines.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredAirlines.length,
                              separatorBuilder: (ctx, idx) => const Divider(height: 1),
                              itemBuilder: (ctx, index) {
                                final airline = filteredAirlines[index]; //
                                return ListTile(
                                  dense: true,
                                  title: Text(airline.name),
                                  subtitle: Text(airline.code),
                                  onTap: () {
                                    setState(() {
                                      airlineNameController.text = airline.name;
                                      isAirlineListVisible = false;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: flightNumberController,
                      decoration: const InputDecoration(labelText: 'Flight Number'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: originController,
                      decoration: const InputDecoration(labelText: 'Origin '),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: destinationController,
                      decoration: const InputDecoration(labelText: 'Destination '),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: flightDateController,
                      decoration: InputDecoration(
                        labelText: 'Flight Date',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectFlightDate(dialogContext),
                        ),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: departureTimeController,
                            decoration: InputDecoration(
                              labelText: 'Departure Time',
                              hintText: 'e.g., 08:30, 14:00',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: () => _selectTime(dialogContext, departureTimeController),
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: arrivalTimeController,
                            decoration: InputDecoration(
                              labelText: 'Arrival Time',
                              hintText: 'e.g., 10:45, 16:30',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationHoursController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration ',
                              hintText: 'e.g., 2',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: durationMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration ',
                              hintText: 'e.g., 30',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    final String airlineName = airlineNameController.text.trim();
                    final String flightNumber = flightNumberController.text.trim();
                    final String origin = originController.text.trim().toUpperCase();
                    final String destination = destinationController.text.trim().toUpperCase();
                    final String flightDate = flightDateController.text.trim();
                    final String? duration;
                    final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                    final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                    if (hours == 0 && minutes == 0) {
                      duration = null;
                    } else if (hours == 0) {
                      duration = '$minutes min';
                    } else if (minutes == 0) {
                      duration = '$hours hours';
                    } else {
                      duration = '$hours hours $minutes min';
                    }

                    if (airlineName.isEmpty || flightNumber.isEmpty || origin.isEmpty || destination.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('All fields are required.'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final updatedFlightDetail = FlightDetail(
                      flightNumber: flightNumber,
                      origin: origin,
                      destination: destination,
                      flightDate: flightDate.isNotEmpty ? flightDate : null,
                      departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                      arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                      duration: duration,
                      sequence: originalFlightDetail.sequence,
                    );

                    final List<AirlineLog> newFlightsList = [];
                    for (var airlineLog in _processedSummary.flights) {
                      if (airlineLog.airlineName == originalAirlineLog.airlineName) {
                        final List<FlightDetail> updatedFlightDetails = airlineLog.flights.map((detail) {
                          if (detail == originalFlightDetail) {
                            return updatedFlightDetail;
                          }
                          return detail;
                        }).toList();
                        newFlightsList.add(AirlineLog(
                          airlineName: airlineName,
                          flights: updatedFlightDetails,
                        ));
                      } else {
                        newFlightsList.add(airlineLog);
                      }
                    }

                    _processedSummary = AiSummary(
                      countries: _processedSummary.countries,
                      cities: _processedSummary.cities,
                      airports: _processedSummary.airports,
                      flights: newFlightsList,
                      trains: _processedSummary.trains,
                      buses: _processedSummary.buses,
                      ferries: _processedSummary.ferries,
                      cars: _processedSummary.cars,
                      landmarks: _processedSummary.landmarks,
                      transitAirports: _processedSummary.transitAirports,
                      startLocation: _processedSummary.startLocation,
                      endLocation: _processedSummary.endLocation,
                    );

                    Navigator.of(dialogContext).pop();
                    _markAsChanged();
                    _performMatching();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Flight updated!'),
                        backgroundColor: Colors.green,
                      ),
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

  Future<void> _confirmAndDeleteFlight(BuildContext context, String flightNumber, String airlineName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Flight'),
          content: Text('Are you sure you want to delete flight "$flightNumber" from $airlineName?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final List<AirlineLog> updatedFlights = [];
                for (var airlineLog in _processedSummary.flights) {
                  final updatedFlightDetails = airlineLog.flights.where((flight) => flight.flightNumber != flightNumber).toList();
                  if (updatedFlightDetails.isNotEmpty) {
                    updatedFlights.add(AirlineLog(
                      airlineName: airlineLog.airlineName,
                      flights: updatedFlightDetails,
                    ));
                  }
                }
                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  flights: updatedFlights,
                  trains: _processedSummary.trains,
                  buses: _processedSummary.buses,
                  ferries: _processedSummary.ferries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop(true);
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Flight "$flightNumber" removed! Click "Save & AI" to update itinerary.'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Train 관련 메서드들
  Widget _buildTrainsCard(BuildContext context, List<TrainLog> trains) {
    const Color greenTheme = Color(0xFF4CAF50); // 초록색 테마

    final sortedTrains = List<TrainLog>.from(trains)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.train, color: greenTheme, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Trains',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddTrainDialog(context),
                color: greenTheme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (trains.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No trains for this trip.'),
              ),
            )
          else
            ...sortedTrains.map((train) {
              return _buildTrainItem(context, train, greenTheme);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTrainItem(BuildContext context, TrainLog train, Color themeColor) {
    String dateText = '';
    if (train.date != null && train.date!.isNotEmpty && train.date != 'Unknown') {
      try {
        final date = DateTime.parse(train.date!);
        dateText = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        dateText = train.date!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showEditTrainDialog(context, train),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        train.trainNumber ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        train.trainCompany ?? 'Unknown Company',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _confirmAndDeleteTrain(context, train),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        train.origin ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16, color: themeColor),
                    ),
                    Expanded(
                      child: Text(
                        train.destination ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (dateText.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(dateText, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (train.departureTime != null && train.departureTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.departure_board, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(train.departureTime!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (train.arrivalTime != null && train.arrivalTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(train.arrivalTime!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (train.duration != null && train.duration!.isNotEmpty && train.duration != 'N/A')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(train.duration!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTrainDialog(BuildContext context) async {
    final TextEditingController companyController = TextEditingController();
    final TextEditingController numberController = TextEditingController();
    final TextEditingController originController = TextEditingController();
    final TextEditingController destinationController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController departureTimeController = TextEditingController();
    final TextEditingController arrivalTimeController = TextEditingController();
    final TextEditingController durationHoursController = TextEditingController();
    final TextEditingController durationMinutesController = TextEditingController();

    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Train Journey'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Train Company')),
                const SizedBox(height: 10),
                TextField(controller: numberController, decoration: const InputDecoration(labelText: 'Train Number')),
                const SizedBox(height: 10),
                TextField(controller: originController, decoration: const InputDecoration(labelText: 'Origin')),
                const SizedBox(height: 10),
                TextField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destination')),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(dialogContext),
                    ),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: departureTimeController,
                        decoration: InputDecoration(
                          labelText: 'Departure Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, departureTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: arrivalTimeController,
                        decoration: InputDecoration(
                          labelText: 'Arrival Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 30',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                final String? duration;
                final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                if (hours == 0 && minutes == 0) {
                  duration = null;
                } else if (hours == 0) {
                  duration = '$minutes min';
                } else if (minutes == 0) {
                  duration = '$hours hours';
                } else {
                  duration = '$hours hours $minutes min';
                }

                final newTrain = TrainLog(
                  trainCompany: companyController.text.trim().isNotEmpty ? companyController.text.trim() : null,
                  trainNumber: numberController.text.trim().isNotEmpty ? numberController.text.trim() : null,
                  origin: originController.text.trim().isNotEmpty ? originController.text.trim() : null,
                  destination: destinationController.text.trim().isNotEmpty ? destinationController.text.trim() : null,
                  date: dateController.text.trim().isNotEmpty ? dateController.text.trim() : null,
                  departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                  arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                  duration: duration,
                  sequence: (_processedSummary.trains.map((t) => t.sequence).reduce(max) ?? 0) + 1,
                );

                if (newTrain.trainCompany == null && newTrain.trainNumber == null &&
                    newTrain.origin == null && newTrain.destination == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('At least company/number or origin/destination must be provided.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final updatedTrains = List<TrainLog>.from(_processedSummary.trains)..add(newTrain);
                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: updatedTrains,
                  buses: _processedSummary.buses,
                  ferries: _processedSummary.ferries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop();
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Train journey added! If you want to save your changes, click the "Save" button.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditTrainDialog(BuildContext context, TrainLog originalTrainLog) async {
    final TextEditingController companyController = TextEditingController(text: originalTrainLog.trainCompany);
    final TextEditingController numberController = TextEditingController(text: originalTrainLog.trainNumber);
    final TextEditingController originController = TextEditingController(text: originalTrainLog.origin);
    final TextEditingController destinationController = TextEditingController(text: originalTrainLog.destination);
    final TextEditingController dateController = TextEditingController(text: originalTrainLog.date);
    final TextEditingController departureTimeController = TextEditingController(text: originalTrainLog.departureTime);
    final TextEditingController arrivalTimeController = TextEditingController(text: originalTrainLog.arrivalTime);

    // Duration 파싱
    int initialDurationHours = 0;
    int initialDurationMinutes = 0;
    if (originalTrainLog.duration != null && originalTrainLog.duration!.isNotEmpty && originalTrainLog.duration != 'N/A') {
      final parts = originalTrainLog.duration!.split(' ');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].toLowerCase().contains('hour')) {
          initialDurationHours = int.tryParse(parts[i - 1]) ?? 0;
        } else if (parts[i].toLowerCase().contains('min')) {
          initialDurationMinutes = int.tryParse(parts[i - 1]) ?? 0;
        }
      }
    }
    final TextEditingController durationHoursController = TextEditingController(text: initialDurationHours.toString());
    final TextEditingController durationMinutesController = TextEditingController(text: initialDurationMinutes.toString());

    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Train Journey'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Train Company')),
                const SizedBox(height: 10),
                TextField(controller: numberController, decoration: const InputDecoration(labelText: 'Train Number')),
                const SizedBox(height: 10),
                TextField(controller: originController, decoration: const InputDecoration(labelText: 'Origin')),
                const SizedBox(height: 10),
                TextField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destination')),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(dialogContext),
                    ),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: departureTimeController,
                        decoration: InputDecoration(
                          labelText: 'Departure Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, departureTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: arrivalTimeController,
                        decoration: InputDecoration(
                          labelText: 'Arrival Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 30',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final String? duration;
                final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                if (hours == 0 && minutes == 0) {
                  duration = null;
                } else if (hours == 0) {
                  duration = '$minutes min';
                } else if (minutes == 0) {
                  duration = '$hours hours';
                } else {
                  duration = '$hours hours $minutes min';
                }

                final updatedTrain = TrainLog(
                  trainCompany: companyController.text.trim().isNotEmpty ? companyController.text.trim() : null,
                  trainNumber: numberController.text.trim().isNotEmpty ? numberController.text.trim() : null,
                  origin: originController.text.trim().isNotEmpty ? originController.text.trim() : null,
                  destination: destinationController.text.trim().isNotEmpty ? destinationController.text.trim() : null,
                  date: dateController.text.trim().isNotEmpty ? dateController.text.trim() : null,
                  departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                  arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                  duration: duration,
                  sequence: originalTrainLog.sequence, // sequence 보존
                );

                final updatedTrains = _processedSummary.trains.map((t) =>
                t == originalTrainLog ? updatedTrain : t
                ).toList();

                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: updatedTrains,
                  buses: _processedSummary.buses,
                  ferries: _processedSummary.ferries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop();
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Train journey updated! If you want to save your changes, click the "Save" button.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDeleteTrain(BuildContext context, TrainLog train) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Train Journey'),
          content: Text('Are you sure you want to delete the train journey from ${train.origin ?? 'Unknown'} to ${train.destination ?? 'Unknown'} on ${train.date ?? 'Unknown'}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final updatedTrains = _processedSummary.trains.where((t) =>
                t != train
                ).toList();
                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: updatedTrains,
                  buses: _processedSummary.buses,
                  ferries: _processedSummary.ferries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop(true);
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Train journey removed! Click "Save & AI" to update itinerary.'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Bus 관련 메서드들
  Widget _buildBusesCard(BuildContext context, List<BusLog> buses) {
    const Color orangeTheme = Color(0xFFFF9800); // 주황색 테마

    final sortedBuses = List<BusLog>.from(buses)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_bus, color: orangeTheme, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Buses',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddBusDialog(context),
                color: orangeTheme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (buses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No buses for this trip.'),
              ),
            )
          else
            ...sortedBuses.map((bus) {
              return _buildBusItem(context, bus, orangeTheme);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildBusItem(BuildContext context, BusLog bus, Color themeColor) {
    String dateText = '';
    if (bus.date != null && bus.date!.isNotEmpty && bus.date != 'Unknown') {
      try {
        final date = DateTime.parse(bus.date!);
        dateText = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        dateText = bus.date!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showEditBusDialog(context, bus),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_bus, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'BUS',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bus.busCompany ?? 'Unknown Company',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _confirmAndDeleteBus(context, bus),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bus.origin ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16, color: themeColor),
                    ),
                    Expanded(
                      child: Text(
                        bus.destination ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (dateText.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(dateText, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (bus.departureTime != null && bus.departureTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.departure_board, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(bus.departureTime!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (bus.arrivalTime != null && bus.arrivalTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(bus.arrivalTime!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (bus.duration != null && bus.duration!.isNotEmpty && bus.duration != 'N/A')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(bus.duration!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddBusDialog(BuildContext context) async {
    final TextEditingController companyController = TextEditingController();
    final TextEditingController originController = TextEditingController();
    final TextEditingController destinationController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController departureTimeController = TextEditingController();
    final TextEditingController arrivalTimeController = TextEditingController();
    final TextEditingController durationHoursController = TextEditingController();
    final TextEditingController durationMinutesController = TextEditingController();

    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Bus Journey'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Bus Company')),
                const SizedBox(height: 10),
                TextField(controller: originController, decoration: const InputDecoration(labelText: 'Origin')),
                const SizedBox(height: 10),
                TextField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destination')),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(dialogContext),
                    ),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: departureTimeController,
                        decoration: InputDecoration(
                          labelText: 'Departure Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, departureTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: arrivalTimeController,
                        decoration: InputDecoration(
                          labelText: 'Arrival Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 30',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                final String? duration;
                final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                if (hours == 0 && minutes == 0) {
                  duration = null;
                } else if (hours == 0) {
                  duration = '$minutes min';
                } else if (minutes == 0) {
                  duration = '$hours hours';
                } else {
                  duration = '$hours hours $minutes min';
                }

                final newBus = BusLog(
                  busCompany: companyController.text.trim().isNotEmpty ? companyController.text.trim() : null,
                  origin: originController.text.trim().isNotEmpty ? originController.text.trim() : null,
                  destination: destinationController.text.trim().isNotEmpty ? destinationController.text.trim() : null,
                  date: dateController.text.trim().isNotEmpty ? dateController.text.trim() : null,
                  departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                  arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                  duration: duration,
                  sequence: (_processedSummary.buses.map((b) => b.sequence).reduce(max) ?? 0) + 1,
                );

                if (newBus.busCompany == null && newBus.origin == null && newBus.destination == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('At least company or origin/destination must be provided.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final updatedBuses = List<BusLog>.from(_processedSummary.buses)..add(newBus);
                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: updatedBuses,
                  ferries: _processedSummary.ferries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop();
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bus journey added! If you want to save your changes, click the "Save" button.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditBusDialog(BuildContext context, BusLog originalBusLog) async {
    final TextEditingController companyController = TextEditingController(text: originalBusLog.busCompany);
    final TextEditingController originController = TextEditingController(text: originalBusLog.origin);
    final TextEditingController destinationController = TextEditingController(text: originalBusLog.destination);
    final TextEditingController dateController = TextEditingController(text: originalBusLog.date);
    final TextEditingController departureTimeController = TextEditingController(text: originalBusLog.departureTime);
    final TextEditingController arrivalTimeController = TextEditingController(text: originalBusLog.arrivalTime);

    // Duration 파싱
    int initialDurationHours = 0;
    int initialDurationMinutes = 0;
    if (originalBusLog.duration != null && originalBusLog.duration!.isNotEmpty && originalBusLog.duration != 'N/A') {
      final parts = originalBusLog.duration!.split(' ');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].toLowerCase().contains('hour')) {
          initialDurationHours = int.tryParse(parts[i - 1]) ?? 0;
        } else if (parts[i].toLowerCase().contains('min')) {
          initialDurationMinutes = int.tryParse(parts[i - 1]) ?? 0;
        }
      }
    }
    final TextEditingController durationHoursController = TextEditingController(text: initialDurationHours.toString());
    final TextEditingController durationMinutesController = TextEditingController(text: initialDurationMinutes.toString());

    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Bus Journey'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Bus Company')),
                const SizedBox(height: 10),
                TextField(controller: originController, decoration: const InputDecoration(labelText: 'Origin')),
                const SizedBox(height: 10),
                TextField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destination')),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(dialogContext),
                    ),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: departureTimeController,
                        decoration: InputDecoration(
                          labelText: 'Departure Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, departureTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: arrivalTimeController,
                        decoration: InputDecoration(
                          labelText: 'Arrival Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 30',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final String? duration;
                final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                if (hours == 0 && minutes == 0) {
                  duration = null;
                } else if (hours == 0) {
                  duration = '$minutes min';
                } else if (minutes == 0) {
                  duration = '$hours hours';
                } else {
                  duration = '$hours hours $minutes min';
                }

                final updatedBus = BusLog(
                  busCompany: companyController.text.trim().isNotEmpty ? companyController.text.trim() : null,
                  origin: originController.text.trim().isNotEmpty ? originController.text.trim() : null,
                  destination: destinationController.text.trim().isNotEmpty ? destinationController.text.trim() : null,
                  date: dateController.text.trim().isNotEmpty ? dateController.text.trim() : null,
                  departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                  arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                  duration: duration,
                  sequence: originalBusLog.sequence, // sequence 보존
                );

                final updatedBuses = _processedSummary.buses.map((b) =>
                b == originalBusLog ? updatedBus : b
                ).toList();

                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: updatedBuses,
                  ferries: _processedSummary.ferries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop();
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bus journey updated! If you want to save your changes, click the "Save" button.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDeleteBus(BuildContext context, BusLog bus) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Bus Journey'),
          content: Text('Are you sure you want to delete the bus journey from ${bus.origin ?? 'Unknown'} to ${bus.destination ?? 'Unknown'} on ${bus.date ?? 'Unknown'}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final updatedBuses = _processedSummary.buses.where((b) =>
                b != bus
                ).toList();
                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: updatedBuses,
                  ferries: _processedSummary.ferries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop(true);
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bus journey removed! Click "Save & AI" to update itinerary.'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Ferry 관련 메서드들
  Widget _buildFerriesCard(BuildContext context, List<FerryLog> ferries) {
    const Color tealTheme = Color(0xFF00BCD4); // 청록색 테마

    final sortedFerries = List<FerryLog>.from(ferries)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_boat, color: tealTheme, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Ferries',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddFerryDialog(context),
                color: tealTheme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ferries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No ferries for this trip.'),
              ),
            )
          else
            ...sortedFerries.map((ferry) {
              return _buildFerryItem(context, ferry, tealTheme);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildFerryItem(BuildContext context, FerryLog ferry, Color themeColor) {
    String dateText = '';
    if (ferry.date != null && ferry.date!.isNotEmpty && ferry.date != 'Unknown') {
      try {
        final date = DateTime.parse(ferry.date!);
        dateText = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        dateText = ferry.date!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showEditFerryDialog(context, ferry),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_boat, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'FERRY',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ferry.ferryName ?? 'Unknown Ferry',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _confirmAndDeleteFerry(context, ferry),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ferry.origin ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16, color: themeColor),
                    ),
                    Expanded(
                      child: Text(
                        ferry.destination ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (dateText.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(dateText, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (ferry.departureTime != null && ferry.departureTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.departure_board, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(ferry.departureTime!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (ferry.arrivalTime != null && ferry.arrivalTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(ferry.arrivalTime!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (ferry.duration != null && ferry.duration!.isNotEmpty && ferry.duration != 'N/A')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(ferry.duration!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddFerryDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController originController = TextEditingController();
    final TextEditingController destinationController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController departureTimeController = TextEditingController();
    final TextEditingController arrivalTimeController = TextEditingController();
    final TextEditingController durationHoursController = TextEditingController();
    final TextEditingController durationMinutesController = TextEditingController();

    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Ferry Journey'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Ferry Name')),
                const SizedBox(height: 10),
                TextField(controller: originController, decoration: const InputDecoration(labelText: 'Origin')),
                const SizedBox(height: 10),
                TextField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destination')),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(dialogContext),
                    ),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: departureTimeController,
                        decoration: InputDecoration(
                          labelText: 'Departure Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, departureTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: arrivalTimeController,
                        decoration: InputDecoration(
                          labelText: 'Arrival Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 30',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                final String? duration;
                final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                if (hours == 0 && minutes == 0) {
                  duration = null;
                } else if (hours == 0) {
                  duration = '$minutes min';
                } else if (minutes == 0) {
                  duration = '$hours hours';
                } else {
                  duration = '$hours hours $minutes min';
                }

                final newFerry = FerryLog(
                  ferryName: nameController.text.trim().isNotEmpty ? nameController.text.trim() : null,
                  origin: originController.text.trim().isNotEmpty ? originController.text.trim() : null,
                  destination: destinationController.text.trim().isNotEmpty ? destinationController.text.trim() : null,
                  date: dateController.text.trim().isNotEmpty ? dateController.text.trim() : null,
                  departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                  arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                  duration: duration,
                  sequence: (_processedSummary.ferries.map((f) => f.sequence).reduce(max) ?? 0) + 1,
                );

                if (newFerry.ferryName == null && newFerry.origin == null && newFerry.destination == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('At least ferry name or origin/destination must be provided.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final updatedFerries = List<FerryLog>.from(_processedSummary.ferries)..add(newFerry);
                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: _processedSummary.buses,
                  ferries: updatedFerries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop();
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ferry journey added! If you want to save your changes, click the "Save" button.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditFerryDialog(BuildContext context, FerryLog originalFerryLog) async {
    final TextEditingController nameController = TextEditingController(text: originalFerryLog.ferryName);
    final TextEditingController originController = TextEditingController(text: originalFerryLog.origin);
    final TextEditingController destinationController = TextEditingController(text: originalFerryLog.destination);
    final TextEditingController dateController = TextEditingController(text: originalFerryLog.date);
    final TextEditingController departureTimeController = TextEditingController(text: originalFerryLog.departureTime);
    final TextEditingController arrivalTimeController = TextEditingController(text: originalFerryLog.arrivalTime);

    // Duration 파싱
    int initialDurationHours = 0;
    int initialDurationMinutes = 0;
    if (originalFerryLog.duration != null && originalFerryLog.duration!.isNotEmpty && originalFerryLog.duration != 'N/A') {
      final parts = originalFerryLog.duration!.split(' ');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].toLowerCase().contains('hour')) {
          initialDurationHours = int.tryParse(parts[i - 1]) ?? 0;
        } else if (parts[i].toLowerCase().contains('min')) {
          initialDurationMinutes = int.tryParse(parts[i - 1]) ?? 0;
        }
      }
    }
    final TextEditingController durationHoursController = TextEditingController(text: initialDurationHours.toString());
    final TextEditingController durationMinutesController = TextEditingController(text: initialDurationMinutes.toString());

    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Ferry Journey'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Ferry Name')),
                const SizedBox(height: 10),
                TextField(controller: originController, decoration: const InputDecoration(labelText: 'Origin')),
                const SizedBox(height: 10),
                TextField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destination')),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(dialogContext),
                    ),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: departureTimeController,
                        decoration: InputDecoration(
                          labelText: 'Departure Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, departureTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: arrivalTimeController,
                        decoration: InputDecoration(
                          labelText: 'Arrival Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 30',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final String? duration;
                final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                if (hours == 0 && minutes == 0) {
                  duration = null;
                } else if (hours == 0) {
                  duration = '$minutes min';
                } else if (minutes == 0) {
                  duration = '$hours hours';
                } else {
                  duration = '$hours hours $minutes min';
                }

                final updatedFerry = FerryLog(
                  ferryName: nameController.text.trim().isNotEmpty ? nameController.text.trim() : null,
                  origin: originController.text.trim().isNotEmpty ? originController.text.trim() : null,
                  destination: destinationController.text.trim().isNotEmpty ? destinationController.text.trim() : null,
                  date: dateController.text.trim().isNotEmpty ? dateController.text.trim() : null,
                  departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                  arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                  duration: duration,
                  sequence: originalFerryLog.sequence, // sequence 보존
                );

                final updatedFerries = _processedSummary.ferries.map((f) =>
                f == originalFerryLog ? updatedFerry : f
                ).toList();

                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: _processedSummary.buses,
                  ferries: updatedFerries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop();
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ferry journey updated! If you want to save your changes, click the "Save" button.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDeleteFerry(BuildContext context, FerryLog ferry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Ferry Journey'),
          content: Text('Are you sure you want to delete the ferry journey from ${ferry.origin ?? 'Unknown'} to ${ferry.destination ?? 'Unknown'} on ${ferry.date ?? 'Unknown'}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final updatedFerries = _processedSummary.ferries.where((f) =>
                f != ferry
                ).toList();
                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: _processedSummary.buses,
                  ferries: updatedFerries,
                  cars: _processedSummary.cars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop(true);
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ferry journey removed! Click "Save & AI" to update itinerary.'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Car 관련 메서드들
  Widget _buildCarsCard(BuildContext context, List<CarLog> cars) {
    const Color redTheme = Color(0xFFF44336); // 빨간색 테마

    final sortedCars = List<CarLog>.from(cars)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car, color: redTheme, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Cars',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddCarDialog(context),
                color: redTheme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (cars.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No cars for this trip.'),
              ),
            )
          else
            ...sortedCars.map((car) {
              return _buildCarItem(context, car, redTheme);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildCarItem(BuildContext context, CarLog car, Color themeColor) {
    String dateText = '';
    if (car.date != null && car.date!.isNotEmpty && car.date != 'Unknown') {
      try {
        final date = DateTime.parse(car.date!);
        dateText = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        dateText = car.date!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showEditCarDialog(context, car),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_car, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'CAR',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        car.carType ?? 'Unknown Type',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _confirmAndDeleteCar(context, car),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        car.origin ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16, color: themeColor),
                    ),
                    Expanded(
                      child: Text(
                        car.destination ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (dateText.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(dateText, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (car.departureTime != null && car.departureTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.departure_board, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(car.departureTime!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (car.arrivalTime != null && car.arrivalTime!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(car.arrivalTime!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                    if (car.duration != null && car.duration!.isNotEmpty && car.duration != 'N/A')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(car.duration!, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddCarDialog(BuildContext context) async {
    final TextEditingController carTypeController = TextEditingController();
    final TextEditingController originController = TextEditingController();
    final TextEditingController destinationController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController departureTimeController = TextEditingController();
    final TextEditingController arrivalTimeController = TextEditingController();
    final TextEditingController durationHoursController = TextEditingController();
    final TextEditingController durationMinutesController = TextEditingController();

    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Car Journey'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(controller: carTypeController, decoration: const InputDecoration(labelText: 'Car Type ')),
                const SizedBox(height: 10),
                TextField(controller: originController, decoration: const InputDecoration(labelText: 'Origin')),
                const SizedBox(height: 10),
                TextField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destination')),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(dialogContext),
                    ),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: departureTimeController,
                        decoration: InputDecoration(
                          labelText: 'Departure Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, departureTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: arrivalTimeController,
                        decoration: InputDecoration(
                          labelText: 'Arrival Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 30',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                final String? duration;
                final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                if (hours == 0 && minutes == 0) {
                  duration = null;
                } else if (hours == 0) {
                  duration = '$minutes min';
                } else if (minutes == 0) {
                  duration = '$hours hours';
                } else {
                  duration = '$hours hours $minutes min';
                }

                final newCar = CarLog(
                  carType: carTypeController.text.trim().isNotEmpty ? carTypeController.text.trim() : null,
                  origin: originController.text.trim().isNotEmpty ? originController.text.trim() : null,
                  destination: destinationController.text.trim().isNotEmpty ? destinationController.text.trim() : null,
                  date: dateController.text.trim().isNotEmpty ? dateController.text.trim() : null,
                  departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                  arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                  duration: duration,
                  sequence: (_processedSummary.cars.map((c) => c.sequence).reduce(max) ?? 0) + 1,
                );

                if (newCar.origin == null && newCar.destination == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Origin and Destination must be provided.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final updatedCars = List<CarLog>.from(_processedSummary.cars)..add(newCar);
                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: _processedSummary.buses,
                  ferries: _processedSummary.ferries,
                  cars: updatedCars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop();
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Car journey added! If you want to save your changes, click the "Save" button.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditCarDialog(BuildContext context, CarLog originalCarLog) async {
    final TextEditingController carTypeController = TextEditingController(text: originalCarLog.carType);
    final TextEditingController originController = TextEditingController(text: originalCarLog.origin);
    final TextEditingController destinationController = TextEditingController(text: originalCarLog.destination);
    final TextEditingController dateController = TextEditingController(text: originalCarLog.date);
    final TextEditingController departureTimeController = TextEditingController(text: originalCarLog.departureTime);
    final TextEditingController arrivalTimeController = TextEditingController(text: originalCarLog.arrivalTime);

    // Duration 파싱
    int initialDurationHours = 0;
    int initialDurationMinutes = 0;
    if (originalCarLog.duration != null && originalCarLog.duration!.isNotEmpty && originalCarLog.duration != 'N/A') {
      final parts = originalCarLog.duration!.split(' ');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].toLowerCase().contains('hour')) {
          initialDurationHours = int.tryParse(parts[i - 1]) ?? 0;
        } else if (parts[i].toLowerCase().contains('min')) {
          initialDurationMinutes = int.tryParse(parts[i - 1]) ?? 0;
        }
      }
    }
    final TextEditingController durationHoursController = TextEditingController(text: initialDurationHours.toString());
    final TextEditingController durationMinutesController = TextEditingController(text: initialDurationMinutes.toString());

    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Car Journey'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(controller: carTypeController, decoration: const InputDecoration(labelText: 'Car Type ')),
                const SizedBox(height: 10),
                TextField(controller: originController, decoration: const InputDecoration(labelText: 'Origin')),
                const SizedBox(height: 10),
                TextField(controller: destinationController, decoration: const InputDecoration(labelText: 'Destination')),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(dialogContext),
                    ),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: departureTimeController,
                        decoration: InputDecoration(
                          labelText: 'Departure Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, departureTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: arrivalTimeController,
                        decoration: InputDecoration(
                          labelText: 'Arrival Time',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () => _selectTime(dialogContext, arrivalTimeController),
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationHoursController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration ',
                          hintText: 'e.g., 30',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final String? duration;
                final int hours = int.tryParse(durationHoursController.text.trim()) ?? 0;
                final int minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;

                if (hours == 0 && minutes == 0) {
                  duration = null;
                } else if (hours == 0) {
                  duration = '$minutes min';
                } else if (minutes == 0) {
                  duration = '$hours hours';
                } else {
                  duration = '$hours hours $minutes min';
                }

                final updatedCar = CarLog(
                  carType: carTypeController.text.trim().isNotEmpty ? carTypeController.text.trim() : null,
                  origin: originController.text.trim().isNotEmpty ? originController.text.trim() : null,
                  destination: destinationController.text.trim().isNotEmpty ? destinationController.text.trim() : null,
                  date: dateController.text.trim().isNotEmpty ? dateController.text.trim() : null,
                  departureTime: departureTimeController.text.trim().isNotEmpty ? departureTimeController.text.trim() : null,
                  arrivalTime: arrivalTimeController.text.trim().isNotEmpty ? arrivalTimeController.text.trim() : null,
                  duration: duration,
                  sequence: originalCarLog.sequence, // sequence 보존
                );

                final updatedCars = _processedSummary.cars.map((c) =>
                c == originalCarLog ? updatedCar : c
                ).toList();

                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: _processedSummary.buses,
                  ferries: _processedSummary.ferries,
                  cars: updatedCars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop();
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Car journey updated! If you want to save your changes, click the "Save" button.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndDeleteCar(BuildContext context, CarLog car) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Car Journey'),
          content: Text('Are you sure you want to delete the car journey from ${car.origin ?? 'Unknown'} to ${car.destination ?? 'Unknown'} on ${car.date ?? 'Unknown'}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final updatedCars = _processedSummary.cars.where((c) =>
                c != car
                ).toList();
                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: _processedSummary.buses,
                  ferries: _processedSummary.ferries,
                  cars: updatedCars,
                  landmarks: _processedSummary.landmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop(true);
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Car journey removed! Click "Save & AI" to update itinerary.'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLandmarksCard(BuildContext context, List<AiLandmarkLog> landmarks) {
    if (landmarks.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.explore, color: Colors.indigo, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Explore',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _showAddLandmarkDialog(context),
                  color: Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No landmarks for this trip.'),
              ),
            ),
          ],
        ),
      );
    }

    final landmarkProvider = context.watch<LandmarksProvider>();
    final unescoProvider = context.watch<UnescoProvider>();

    final cultural = <AiLandmarkLog>[];
    final natural = <AiLandmarkLog>[];
    final activities = <AiLandmarkLog>[];
    final unesco = <AiLandmarkLog>[];

    for (var landmarkLog in landmarks) {
      final cleanName = landmarkLog.name.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();

      final isUnesco = unescoProvider.allSites.any((site) =>
      site.name.toLowerCase() == cleanName.toLowerCase());

      if (isUnesco) {
        unesco.add(landmarkLog);
        continue;
      }

      final landmark = landmarkProvider.allLandmarks.firstWhereOrNull(
              (l) => l.name.toLowerCase() == cleanName.toLowerCase());

      if (landmark != null) {
        if (landmark.attributes.any((a) => _naturalAttributes.contains(a))) {
          natural.add(landmarkLog);
        } else if (landmark.attributes.any((a) => _activityAttributes.contains(a))) {
          activities.add(landmarkLog);
        } else {
          cultural.add(landmarkLog);
        }
      } else {
        cultural.add(landmarkLog);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.explore, color: Colors.indigo, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Explore',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddLandmarkDialog(context),
                color: Colors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (cultural.isNotEmpty) ...[
            _buildCategorySection(
              context: context,
              title: 'Cultural Landmarks',
              icon: Icons.public,
              color: Colors.indigo,
              landmarks: cultural,
            ),
            const SizedBox(height: 16),
          ],

          if (natural.isNotEmpty) ...[
            _buildCategorySection(
              context: context,
              title: 'Natural Wonders',
              icon: Icons.landscape,
              color: Colors.green,
              landmarks: natural,
            ),
            const SizedBox(height: 16),
          ],

          if (activities.isNotEmpty) ...[
            _buildCategorySection(
              context: context,
              title: 'Activities',
              icon: Icons.local_activity,
              color: Colors.pink,
              landmarks: activities,
            ),
            const SizedBox(height: 16),
          ],

          if (unesco.isNotEmpty) ...[
            _buildCategorySection(
              context: context,
              title: 'UNESCO World Heritage',
              icon: Icons.account_balance,
              color: Colors.orange,
              landmarks: unesco,
            ),
          ],
        ],
      ),
    );
  }

  // 🆕 [수정] Wrap 제거하고 Column 사용 (한 줄에 하나씩)
  Widget _buildCategorySection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required List<AiLandmarkLog> landmarks,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // 텍스트 길이만큼만 차지
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${landmarks.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 🆕 Column으로 변경하여 수직 나열
        Column(
          children: landmarks.map((landmarkLog) {
            return _buildLandmarkChip(context, landmarkLog, color);
          }).toList(),
        ),
      ],
    );
  }

  // 🆕 [수정] 칩 스타일 변경 (너비 꽉 채움)
  Widget _buildLandmarkChip(BuildContext context, AiLandmarkLog landmarkLog, Color themeColor) {
    final RegExp cityRegex = RegExp(r'\s*\((.*?)\)\s*$');
    final match = cityRegex.firstMatch(landmarkLog.name);
    final cityName = match?.group(1);
    final cleanedLandmarkName = landmarkLog.name.replaceAll(cityRegex, '').trim();

    String dateText = '';
    if (landmarkLog.visitDate != null && landmarkLog.visitDate != 'Unknown') {
      try {
        final date = DateTime.parse(landmarkLog.visitDate!);
        dateText = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        dateText = landmarkLog.visitDate!;
      }
    }

    return Container(
      width: double.infinity, // 가로 꽉 채움
      margin: const EdgeInsets.only(bottom: 8), // 아래 간격
      child: Material(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showEditLandmarkDialog(context, landmarkLog),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cleanedLandmarkName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (dateText.isNotEmpty)
                        Text(
                          dateText,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey[700],
                              fontWeight: FontWeight.w600),
                        )
                      else if (cityName != null)
                        Text(
                          cityName,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _confirmAndDeleteLandmark(context, landmarkLog.name),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🆕 [수정] 힌트 텍스트 제거
  void _showAddLandmarkDialog(BuildContext context) {
    final landmarkProvider = context.read<LandmarksProvider>();
    final searchController = TextEditingController();
    final dateController = TextEditingController();

    List<Landmark> filteredLandmarks = [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            void _addLandmark(String name) {
              if (name.trim().isEmpty) return;

              final String? visitDate = dateController.text.isNotEmpty ? dateController.text : null;

              final updatedLandmarks = List<AiLandmarkLog>.from(_processedSummary.landmarks)
                ..add(AiLandmarkLog(name: name.trim(), visitDate: visitDate));

              _processedSummary = AiSummary(
                countries: _processedSummary.countries,
                cities: _processedSummary.cities,
                airports: _processedSummary.airports,
                flights: _processedSummary.flights,
                trains: _processedSummary.trains,
                buses: _processedSummary.buses,
                ferries: _processedSummary.ferries,
                cars: _processedSummary.cars,
                landmarks: updatedLandmarks,
                transitAirports: _processedSummary.transitAirports,
                startLocation: _processedSummary.startLocation,
                endLocation: _processedSummary.endLocation,
              );

              Navigator.of(ctx).pop();
              _markAsChanged();
              _performMatching();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"$name" added!'), backgroundColor: Colors.green),
              );
            }

            Future<void> _pickDate() async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() {
                  dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                });
              }
            }

            return AlertDialog(
              title: const Text('Add New Landmark'),
              content: SizedBox(
                width: double.maxFinite,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      controller: dateController,
                      decoration: InputDecoration(
                        labelText: 'Visit Date ',
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() => dateController.clear()),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search or type custom name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        // 🆕 [수정] hintText 제거
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value.isEmpty) {
                            filteredLandmarks = [];
                          } else {
                            filteredLandmarks = landmarkProvider.allLandmarks.where((landmark) {
                              return landmark.name.toLowerCase().contains(value.toLowerCase());
                            }).take(20).toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: ListView(
                        children: [
                          if (searchController.text.trim().isNotEmpty)
                            ListTile(
                              leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                              title: Text(
                                'Add "${searchController.text}" as new',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                              subtitle: const Text('Custom landmark (not in database)'),
                              onTap: () => _addLandmark(searchController.text),
                            ),

                          if (searchController.text.trim().isNotEmpty && filteredLandmarks.isNotEmpty)
                            const Divider(),

                          if (filteredLandmarks.isEmpty && searchController.text.isNotEmpty)
                            const Padding(padding: EdgeInsets.all(16), child: Text("No matching database landmarks.")),

                          ...filteredLandmarks.map((landmark) {
                            Color dotColor = Colors.indigo;
                            if (landmark.attributes.any((a) => _naturalAttributes.contains(a))) dotColor = Colors.green;
                            else if (landmark.attributes.any((a) => _activityAttributes.contains(a))) dotColor = Colors.pink;

                            return ListTile(
                              leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                              title: Text(landmark.name),
                              subtitle: Text(landmark.city),
                              onTap: () => _addLandmark(landmark.name),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🆕 [수정] 랜드마크 편집 다이얼로그 (날짜 수정 포함)
  Future<void> _showEditLandmarkDialog(BuildContext context, AiLandmarkLog originalLog) async {
    final TextEditingController landmarkNameController = TextEditingController(text: originalLog.name);
    final TextEditingController dateController = TextEditingController(text: originalLog.visitDate ?? '');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( // 날짜 갱신을 위해 StatefulBuilder 사용
            builder: (context, setDialogState) {
              Future<void> _pickDate() async {
                final DateTime initial = DateTime.tryParse(dateController.text) ?? DateTime.now();
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setDialogState(() {
                    dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                  });
                }
              }

              return AlertDialog(
                title: const Text('Edit Landmark'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: landmarkNameController,
                      decoration: const InputDecoration(
                        labelText: 'Landmark Name',
                        hintText: 'e.g. Eiffel Tower',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: dateController,
                      decoration: InputDecoration(
                        labelText: 'Visit Date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() => dateController.clear()),
                        ),
                      ),
                      readOnly: true,
                      onTap: _pickDate,
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                  ElevatedButton(
                    child: const Text('Save'),
                    onPressed: () {
                      final String newLandmarkName = landmarkNameController.text.trim();
                      final String? newDate = dateController.text.isNotEmpty ? dateController.text : null;

                      if (newLandmarkName.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Landmark name cannot be empty.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      // 🔴 [수정] 객체 비교 및 업데이트 (날짜 포함)
                      final updatedLandmarks = _processedSummary.landmarks.map((l) =>
                      l == originalLog
                          ? l.copyWith(name: newLandmarkName, visitDate: newDate)
                          : l
                      ).toList();

                      _processedSummary = AiSummary(
                        countries: _processedSummary.countries,
                        cities: _processedSummary.cities,
                        airports: _processedSummary.airports,
                        flights: _processedSummary.flights,
                        trains: _processedSummary.trains,
                        buses: _processedSummary.buses,
                        ferries: _processedSummary.ferries,
                        cars: _processedSummary.cars,
                        landmarks: updatedLandmarks,
                        transitAirports: _processedSummary.transitAirports,
                        startLocation: _processedSummary.startLocation,
                        endLocation: _processedSummary.endLocation,
                      );
                      Navigator.of(dialogContext).pop();
                      _markAsChanged();
                      _performMatching();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Landmark updated!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }

  Future<void> _confirmAndDeleteLandmark(BuildContext context, String landmarkName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Landmark'),
          content: Text('Are you sure you want to delete "$landmarkName" from this trip summary?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                // 🔄 [수정됨] 객체에서 이름 비교하여 삭제
                final updatedLandmarks = _processedSummary.landmarks
                    .where((l) => l.name != landmarkName)
                    .toList();

                _processedSummary = AiSummary(
                  countries: _processedSummary.countries,
                  cities: _processedSummary.cities,
                  airports: _processedSummary.airports,
                  flights: _processedSummary.flights,
                  trains: _processedSummary.trains,
                  buses: _processedSummary.buses,
                  ferries: _processedSummary.ferries,
                  cars: _processedSummary.cars,
                  landmarks: updatedLandmarks,
                  transitAirports: _processedSummary.transitAirports,
                  startLocation: _processedSummary.startLocation,
                  endLocation: _processedSummary.endLocation,
                );
                Navigator.of(dialogContext).pop(true);
                _markAsChanged();
                _performMatching();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$landmarkName" removed! Click "Save & AI" to update itinerary.'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        );
      },
    );
  }
  // 🆕 Airports 섹션 빌더
  // 🆕 [수정] Airports 섹션 (Wrap -> Column)
  Widget _buildAirportsSection(BuildContext context) {
    final airportProvider = context.watch<AirportProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.flight_takeoff, color: Theme.of(context).primaryColor, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Airports',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showAddAirportDialog(context, airportProvider),
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 🆕 Column으로 변경하여 한 줄에 하나씩 표시
          Column(
            children: _processedSummary.airports.map((airportLog) {
              return _buildAirportChip(context, airportLog, airportProvider);
            }).toList(),
          ),
        ],
      ),
    );
  }
  // Airport용 국기 표시 함수
  // Airport용 국기 표시 함수 (FlagCDN URL 사용)
  Widget _buildCountryFlagWidget(String countryName) {
    if (countryName.isEmpty || countryName == 'Unknown') {
      return const Icon(Icons.public, color: Colors.grey, size: 24);
    }

    try {
      final countryProvider = context.read<CountryProvider>();

      // 1. 입력값 정제 (공백 제거, 소문자 변환)
      String cleanInput = countryName.trim().toLowerCase();

      // 2. 괄호가 있다면 제거하고 내부 코드나 이름 추출 시도 (예: "Japan (JP)" -> "JP" 또는 "Japan")
      // 코드 우선 추출
      final codeMatch = RegExp(r'\(([A-Za-z0-9]{2,3})\)').firstMatch(countryName);
      if (codeMatch != null) {
        cleanInput = codeMatch.group(1)!.toLowerCase();
      } else {
        // 괄호와 그 안의 내용 제거 후 이름만 남김
        cleanInput = countryName.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '').trim().toLowerCase();
      }

      // 3. 강력한 검색 (ISO A2, ISO A3, Name 순서로 확인)
      final country = countryProvider.allCountries.firstWhereOrNull(
            (c) =>
        c.isoA2.toLowerCase() == cleanInput ||      // 2글자 코드 확인 (예: KR)
            c.isoA3.toLowerCase() == cleanInput ||      // 3글자 코드 확인 (예: KOR)
            c.name.toLowerCase() == cleanInput,         // 전체 이름 확인 (예: South Korea)
      );

      if (country != null) {
        // CountryDex와 동일한 URL 로직 적용 (용량을 위해 w80 사이즈 사용)
        final flagUrl = 'https://flagcdn.com/w80/${country.isoA2.toLowerCase()}.png';

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 32,
            height: 24,
            child: Image.network(
              flagUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // 이미지 로드 실패 시 회색 깃발 아이콘
                return const Icon(Icons.flag, color: Colors.grey, size: 20);
              },
            ),
          ),
        );
      }
    } catch (e) {
      // 에러 발생 시
    }
    // 국가를 못 찾았을 경우
    return const Icon(Icons.flag, color: Colors.grey, size: 24);
  }
  // 🆕 [수정] 공항 칩: 국기 위젯 적용
  Widget _buildAirportChip(BuildContext context, AirportLog airportLog, AirportProvider airportProvider) {
    final airport = airportProvider.allAirports.firstWhereOrNull(
          (a) => a.iataCode.toUpperCase() == airportLog.iataCode.toUpperCase(),
    );

    final isMatched = airport != null;

    String dateTimeText = '';
    if (airportLog.visitDate != null && airportLog.visitDate!.isNotEmpty) {
      try {
        final date = DateTime.parse(airportLog.visitDate!);
        dateTimeText = DateFormat('MMM d, yyyy').format(date);
      } catch (e) {
        dateTimeText = airportLog.visitDate!;
      }
    } else {
      dateTimeText = 'Date unknown';
    }

    final rawName = airport?.name ?? airportLog.name;
    final airportFullName = _formatAirportName(rawName);
    final countryName = airport?.country ?? 'Unknown';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isMatched ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            _showEditAirportDialog(context, airportLog: airportLog, airportData: airport);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // 🆕 국기 위젯 사용
                _buildCountryFlagWidget(countryName),

                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              airportFullName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isMatched ? Colors.black87 : Colors.grey[800],
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
                            ),
                            child: Text(
                              airportLog.iataCode,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 10, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            dateTimeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: isMatched ? Colors.grey[700] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (airportLog.isTransit)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.compare_arrows, size: 12, color: Colors.orange[800]),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Transit',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _removeAirport(airportLog),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // 🆕 [수정] 공항 수정 다이얼로그 (Transit 문구 변경)
  // 🆕 [수정] 공항 수정 다이얼로그 (Transit 질문 제거)
  void _showEditAirportDialog(BuildContext context, {AirportLog? airportLog, Airport? airportData}) {
    final String iataCode = airportLog?.iataCode ?? airportData?.iataCode ?? '';
    final String name = airportLog?.name ?? airportData?.name ?? '';
    final String country = airportData?.country ?? 'Unknown';

    final TextEditingController dateController = TextEditingController(
        text: airportLog?.visitDate ?? ''
    );

    bool isTransit = airportLog?.isTransit ?? false;

    Future<void> _pickDate(StateSetter setDialogState) async {
      final DateTime initialDate = DateTime.tryParse(dateController.text) ?? DateTime.now();
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1990),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        setDialogState(() {
          dateController.text = DateFormat('yyyy-MM-dd').format(picked);
        });
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(airportLog == null ? 'Add Airport Details' : 'Edit Airport Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name ($iataCode)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    country,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // 날짜 입력
                  GestureDetector(
                    onTap: () => _pickDate(setDialogState),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: dateController,
                        decoration: InputDecoration(
                          labelText: 'Visit Date',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setDialogState(() => dateController.clear()),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🆕 Transit 스위치 (질문 제거)
                  SwitchListTile(
                    title: const Text('Transit'),
                    subtitle: null, // 🆕 질문 제거됨
                    value: isTransit,
                    onChanged: (bool value) {
                      setDialogState(() {
                        isTransit = value;
                      });
                    },
                    secondary: const Icon(Icons.connecting_airports),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    final String? finalDate = dateController.text.isNotEmpty ? dateController.text : null;

                    if (finalDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a visit date'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    final newLog = AirportLog(
                      iataCode: iataCode,
                      name: name,
                      visitDate: finalDate,
                      isTransit: isTransit,
                    );

                    if (airportLog == null) {
                      _addAirportWithDetails(newLog);
                    } else {
                      _updateAirportWithDetails(airportLog, newLog);
                    }

                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


// 🆕 공항 추가 다이얼로그
  // 🆕 [수정] 공항 추가 다이얼로그 (목록 UI 변경: 국기 표시, IATA 코드 위치 이동)
  // 🆕 [수정] 공항 추가 다이얼로그 (목록에 국기 위젯 적용)
  void _showAddAirportDialog(BuildContext context, AirportProvider airportProvider) {
    final searchController = TextEditingController();
    final dateController = TextEditingController();
    List<Airport> filteredAirports = airportProvider.allAirports;
    bool isTransit = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> _pickDate() async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1990),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() {
                  dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                });
              }
            }

            void _addAirportWithDate(Airport airport) {
              if (dateController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a visit date'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final newLog = AirportLog(
                iataCode: airport.iataCode,
                name: airport.name,
                visitDate: dateController.text,
                isTransit: isTransit,
              );

              _addAirportWithDetails(newLog);
              Navigator.of(ctx).pop();
            }

            return AlertDialog(
              title: const Text('Add Airport'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    // 날짜 선택
                    TextField(
                      controller: dateController,
                      decoration: InputDecoration(
                        labelText: 'Visit Date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() => dateController.clear()),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),

                    // Transit 스위치
                    SwitchListTile(
                      title: const Text('Transit'),
                      value: isTransit,
                      onChanged: (bool value) {
                        setDialogState(() {
                          isTransit = value;
                        });
                      },
                      secondary: const Icon(Icons.connecting_airports),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),

                    // 공항 검색
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search airports',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value.isEmpty) {
                            filteredAirports = airportProvider.allAirports;
                          } else {
                            filteredAirports = airportProvider.allAirports.where((airport) {
                              return airport.name.toLowerCase().contains(value.toLowerCase()) ||
                                  airport.iataCode.toLowerCase().contains(value.toLowerCase()) ||
                                  airport.country.toLowerCase().contains(value.toLowerCase());
                            }).toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // 공항 목록
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredAirports.length,
                        separatorBuilder: (ctx, idx) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final airport = filteredAirports[index];
                          final formattedName = _formatAirportName(airport.name);

                          return ListTile(
                            leading: _buildCountryFlagWidget(airport.country),
                            title: Text(
                              formattedName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${airport.iataCode} • ${airport.country}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            onTap: () => _addAirportWithDate(airport),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }



  void _addAirportWithDetails(AirportLog airportLog) {
    setState(() {
      final updatedAirports = List<AirportLog>.from(_processedSummary.airports)..add(airportLog);

      _processedSummary = AiSummary(
        countries: _processedSummary.countries,
        cities: _processedSummary.cities,
        airports: updatedAirports,
        flights: _processedSummary.flights,
        trains: _processedSummary.trains,
        buses: _processedSummary.buses,
        ferries: _processedSummary.ferries,
        cars: _processedSummary.cars,
        landmarks: _processedSummary.landmarks,
        transitAirports: _processedSummary.transitAirports,
        startLocation: _processedSummary.startLocation,
        endLocation: _processedSummary.endLocation,
      );
      _markAsChanged();
      _performMatching();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${airportLog.iataCode}" added with date ${airportLog.visitDate}!'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _updateAirportWithDetails(AirportLog oldLog, AirportLog newLog) {
    setState(() {
      final index = _processedSummary.airports.indexWhere(
              (a) => a.iataCode == oldLog.iataCode && a.visitDate == oldLog.visitDate
      );
      if (index != -1) {
        final updatedAirports = List<AirportLog>.from(_processedSummary.airports);
        updatedAirports[index] = newLog;

        _processedSummary = AiSummary(
          countries: _processedSummary.countries,
          cities: _processedSummary.cities,
          airports: updatedAirports,
          flights: _processedSummary.flights,
          trains: _processedSummary.trains,
          buses: _processedSummary.buses,
          ferries: _processedSummary.ferries,
          cars: _processedSummary.cars,
          landmarks: _processedSummary.landmarks,
          transitAirports: _processedSummary.transitAirports,
          startLocation: _processedSummary.startLocation,
          endLocation: _processedSummary.endLocation,
        );
        _markAsChanged();
        _performMatching();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${newLog.iataCode}" updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
// 🆕 공항 추가

// 🆕 공항 제거
  void _removeAirport(AirportLog airportLog) {
    setState(() {
      final updatedAirports = _processedSummary.airports.where(
              (a) => !(a.iataCode == airportLog.iataCode && a.visitDate == airportLog.visitDate)
      ).toList();

      _processedSummary = AiSummary(
        countries: _processedSummary.countries,
        cities: _processedSummary.cities,
        airports: updatedAirports,
        flights: _processedSummary.flights,
        trains: _processedSummary.trains,
        buses: _processedSummary.buses,
        ferries: _processedSummary.ferries,
        cars: _processedSummary.cars,
        landmarks: _processedSummary.landmarks,
        transitAirports: _processedSummary.transitAirports,
        startLocation: _processedSummary.startLocation,
        endLocation: _processedSummary.endLocation,
      );
      _markAsChanged();
      _performMatching();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${airportLog.name} removed!'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  // 🆕 [수정] Database Matching에서 도시 표시 (기간 포맷팅 적용)
  Widget _buildCitiesChipSection(String title, List<Map<String, dynamic>> itemsWithDetails, Set<String> visitedCities, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Column(
            children: itemsWithDetails.map((itemMap) {
              final City city = itemMap['city'] as City;
              // 🆕 헬퍼 함수 적용
              final String formattedDuration = _formatDuration(itemMap['duration'] as String?);
              final bool isVisited = visitedCities.contains(city.name);

              final String displayIso = (city.countryIsoA2.isNotEmpty && city.countryIsoA2 != 'N/A')
                  ? city.countryIsoA2
                  : 'N/A';

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isVisited ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isVisited ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isVisited ? Icons.check_circle : icon,
                      size: 18,
                      color: isVisited ? Colors.green : Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${city.name} ($displayIso) ($formattedDuration)',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedItemsCard(BuildContext context) {
    if (_matchedFlightsDetails.isEmpty && _matchedAirports.isEmpty && _matchedCountries.isEmpty && _matchedCitiesForMap.isEmpty && _matchedLandmarks.isEmpty && _matchedUnescoSites.isEmpty && !_isMatching) {
      return const SizedBox.shrink();
    }

    final airlineProvider = context.watch<AirlineProvider>();
    final airportProvider = context.watch<AirportProvider>();
    final countryProvider = context.watch<CountryProvider>();
    final cityProvider = context.watch<CityProvider>();
    final landmarkProvider = context.watch<LandmarksProvider>();
    final unescoProvider = context.watch<UnescoProvider>();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Database Matching Results', style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            if (_isMatching)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_matchedFlightsDetails.isNotEmpty)
                _buildSimpleFlightChipSection('Flights', _matchedFlightsDetails, airlineProvider, Icons.flight_takeoff),
              if (_matchedAirports.isNotEmpty)
                _buildChipSection('Airports', _matchedAirports, airportProvider.visitedAirports, Icons.local_airport, (item) => item.iataCode),
              if (_matchedCountries.isNotEmpty)
                _buildChipSection('Countries', _matchedCountries, countryProvider.visitedCountries, Icons.flag, (item) => item.name),
              if (_matchedCitiesForMap.isNotEmpty)
                _buildCitiesChipSection('Cities', _matchedCitiesForMap, cityProvider.visitedCities, Icons.location_city),
              if (_matchedLandmarks.isNotEmpty)
                _buildChipSection('Landmarks', _matchedLandmarks, landmarkProvider.visitedLandmarks, Icons.account_balance, (item) => item.name),
              if (_matchedUnescoSites.isNotEmpty)
                _buildChipSection('UNESCO Sites', _matchedUnescoSites, unescoProvider.visitedSites, Icons.account_balance, (item) => item.name),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleFlightChipSection(String title, Map<String, FlightDetail> items, AirlineProvider airlineProvider, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Column(
            children: items.values.map((flightDetail) {
              final bool isVisited = airlineProvider.isDuplicateFlight(
                flightNumber: flightDetail.flightNumber,
                date: flightDetail.flightDate,
              );

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isVisited ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isVisited ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isVisited ? Icons.check_circle : icon,
                      size: 18,
                      color: isVisited ? Colors.green : Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${flightDetail.flightNumber} (${flightDetail.flightDate ?? 'Unknown'})',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChipSection(String title, List<dynamic> items, Set<String> visitedItems, IconData icon, String Function(dynamic item) getId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Column(
            children: items.map((item) {
              String displayLabel = item.name;
              if (item is Airport) {
                displayLabel = '${_formatAirportName(item.name)} (${item.iataCode})';
              }

              final bool isVisited = visitedItems.contains(getId(item));

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isVisited ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isVisited ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isVisited ? Icons.check_circle : icon,
                      size: 18,
                      color: isVisited ? Colors.green : Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayLabel,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 🆕 개선된 선택 가능한 다이얼로그
  // 🆕 개선된 선택 가능한 다이얼로그
  Widget _buildSelectionDialog({
    required BuildContext context,
    required Map<String, FlightDetail> flights,
    required List<AirportLog> airports, // 🆕 Airport -> AirportLog로 변경
    required List<Country> countries,
    required List<String> countryReasons,
    required List<City> cities,
    required List<String> cityReasons,
    required List<Landmark> landmarks,
    required AirlineProvider airlineProvider,
    required List<UnescoSite> unescoSites, // 🆕 UNESCO Sites 추가
  }) {
    // 선택 상태 관리
    final selectedFlights = <FlightDetail>[...flights.values]; // 기본 전체 선택
    final selectedAirports = <AirportLog>[...airports]; // 🆕 AirportLog 리스트
    final selectedCountries = <Country>[...countries];
    final selectedCities = <City>[...cities];
    final selectedLandmarks = <Landmark>[...landmarks];

    final selectedUnescoSites = <UnescoSite>[...unescoSites]; // 🆕 UNESCO Sites 선택
    return StatefulBuilder(
      builder: (context, setState) {
        final totalCount = selectedFlights.length + selectedAirports.length +
            selectedCountries.length + selectedCities.length + selectedLandmarks.length + selectedUnescoSites.length;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.storage, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Add to Database',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$totalCount selected',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 컨텐츠
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Flights 섹션
                        if (flights.isNotEmpty) ...[
                          _buildCategoryHeader(
                            icon: Icons.flight,
                            title: 'Flights',
                            count: flights.length,
                            selectedCount: selectedFlights.length,
                            color: const Color(0xFF9C27B0),
                            onSelectAll: () {
                              setState(() {
                                if (selectedFlights.length == flights.length) {
                                  selectedFlights.clear();
                                } else {
                                  selectedFlights.clear();
                                  selectedFlights.addAll(flights.values);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          ...flights.values.map((flight) {
                            final isSelected = selectedFlights.contains(flight);

                            // ✈️ [수정됨] 기존 카운트 로직 제거 -> 단순 'New' 표시
                            // sendDataToProviders에서 이미 중복은 필터링 되었으므로,
                            // 여기에 뜨는 것은 모두 DB에 없는 '새로운' 항목들입니다.

                            return _buildSelectableItem(
                              isSelected: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedFlights.add(flight);
                                  } else {
                                    selectedFlights.remove(flight);
                                  }
                                });
                              },
                              icon: Icons.flight_takeoff,
                              color: const Color(0xFF9C27B0),
                              title: flight.flightNumber,
                              // 날짜와 경로를 subtitle에 표시
                              subtitle: '${flight.origin} → ${flight.destination} (${flight.flightDate ?? 'Unknown'})',
                              trailing: '🆕', // 숫자 증가 대신 New 배지 사용
                            );
                          }).toList(),
                          const Divider(height: 24),
                        ],

                        // Airports 섹션 (수정됨)
                        if (airports.isNotEmpty) ...[
                          _buildCategoryHeader(
                            icon: Icons.local_airport,
                            title: 'Airports (Visits)',
                            count: airports.length,
                            selectedCount: selectedAirports.length,
                            color: const Color(0xFF2196F3),
                            onSelectAll: () {
                              setState(() {
                                if (selectedAirports.length == airports.length) {
                                  selectedAirports.clear();
                                } else {
                                  selectedAirports.clear();
                                  selectedAirports.addAll(airports);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          ...airports.map((airportLog) { // 🆕 AirportLog 순회
                            final isSelected = selectedAirports.contains(airportLog);
                            final dateStr = airportLog.visitDate ?? 'Unknown Date';
                            final transitStr = airportLog.isTransit ? ' (Transit)' : '';

                            return _buildSelectableItem(
                              isSelected: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedAirports.add(airportLog);
                                  } else {
                                    selectedAirports.remove(airportLog);
                                  }
                                });
                              },
                              icon: Icons.flight,
                              color: const Color(0xFF2196F3),
                              title: airportLog.name,
                              subtitle: '${airportLog.iataCode} / $dateStr$transitStr', // IATA + 날짜 표시
                              trailing: '🆕 Visit',
                            );
                          }).toList(),
                          const Divider(height: 24),
                        ],

                        // Countries 섹션
                        if (countries.isNotEmpty) ...[
                          _buildCategoryHeader(
                            icon: Icons.flag,
                            title: 'Countries',
                            count: countries.length,
                            selectedCount: selectedCountries.length,
                            color: const Color(0xFFE91E63),
                            onSelectAll: () {
                              setState(() {
                                if (selectedCountries.length == countries.length) {
                                  selectedCountries.clear();
                                } else {
                                  selectedCountries.clear();
                                  selectedCountries.addAll(countries);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(countries.length, (index) {
                            final country = countries[index];
                            final reason = countryReasons[index];
                            final isSelected = selectedCountries.contains(country);
                            final badge = reason == 'New' ? '🆕 New' : '🔄 Revisit';

                            return _buildSelectableItem(
                              isSelected: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedCountries.add(country);
                                  } else {
                                    selectedCountries.remove(country);
                                  }
                                });
                              },
                              icon: Icons.public,
                              color: const Color(0xFFE91E63),
                              title: country.name,
                              subtitle: null,
                              trailing: badge,
                            );
                          }).toList(),
                          const Divider(height: 24),
                        ],

                        // Cities 섹션
                        if (cities.isNotEmpty) ...[
                          _buildCategoryHeader(
                            icon: Icons.location_city,
                            title: 'Cities',
                            count: cities.length,
                            selectedCount: selectedCities.length,
                            color: const Color(0xFF00BCD4),
                            onSelectAll: () {
                              setState(() {
                                if (selectedCities.length == cities.length) {
                                  selectedCities.clear();
                                } else {
                                  selectedCities.clear();
                                  selectedCities.addAll(cities);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(cities.length, (index) {
                            final city = cities[index];
                            final reason = cityReasons[index];
                            final isSelected = selectedCities.contains(city);
                            final badge = reason == 'New' ? '🆕 New' : '🔄 Revisit';

                            return _buildSelectableItem(
                              isSelected: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedCities.add(city);
                                  } else {
                                    selectedCities.remove(city);
                                  }
                                });
                              },
                              icon: Icons.location_on,
                              color: const Color(0xFF00BCD4),
                              title: city.name,
                              subtitle: city.country,
                              trailing: badge,
                            );
                          }).toList(),
                          const Divider(height: 24),
                        ],

                        // Landmarks 섹션
                        // Landmarks 섹션
                        if (landmarks.isNotEmpty) ...[
                          _buildCategoryHeader(
                            icon: Icons.museum,
                            title: 'Landmarks',
                            count: landmarks.length,
                            selectedCount: selectedLandmarks.length,
                            color: const Color(0xFF3F51B5),
                            onSelectAll: () {
                              setState(() {
                                if (selectedLandmarks.length == landmarks.length) {
                                  selectedLandmarks.clear();
                                } else {
                                  selectedLandmarks.clear();
                                  selectedLandmarks.addAll(landmarks);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          // 🆕 Column으로 변경
                          Column(
                            children: landmarks.map((landmark) {
                              final isSelected = selectedLandmarks.contains(landmark);

                              // 해당 랜드마크의 날짜 찾기
                              final log = _processedSummary.landmarks.firstWhereOrNull(
                                      (l) => l.name.toLowerCase() == landmark.name.toLowerCase()
                              );
                              final dateStr = log?.visitDate ?? 'Unknown';

                              return _buildSelectableItem(
                                isSelected: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedLandmarks.add(landmark);
                                    } else {
                                      selectedLandmarks.remove(landmark);
                                    }
                                  });
                                },
                                icon: Icons.place,
                                color: const Color(0xFF3F51B5),
                                title: landmark.name,
                                subtitle: dateStr, // 날짜 표시
                                trailing: '🆕',
                              );
                            }).toList(),
                          ),
                        ],

                        // UNESCO Sites Section
                        if (unescoSites.isNotEmpty) ...[
                          _buildCategoryHeader(
                            icon: Icons.account_balance,
                            title: 'UNESCO Sites',
                            count: unescoSites.length,
                            selectedCount: selectedUnescoSites.length,
                            color: const Color(0xFF8B4513),
                            onSelectAll: () {
                              setState(() {
                                if (selectedUnescoSites.length == unescoSites.length) {
                                  selectedUnescoSites.clear();
                                } else {
                                  selectedUnescoSites.clear();
                                  selectedUnescoSites.addAll(unescoSites);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          // 🆕 Column으로 변경
                          Column(
                            children: unescoSites.map((unescoSite) {
                              final isSelected = selectedUnescoSites.contains(unescoSite);

                              final log = _processedSummary.landmarks.firstWhereOrNull(
                                      (l) => l.name.toLowerCase() == unescoSite.name.toLowerCase()
                              );
                              final dateStr = log?.visitDate ?? 'Unknown';

                              return _buildSelectableItem(
                                isSelected: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedUnescoSites.add(unescoSite);
                                    } else {
                                      selectedUnescoSites.remove(unescoSite);
                                    }
                                  });
                                },
                                icon: Icons.location_city,
                                color: const Color(0xFF8B4513),
                                title: unescoSite.name,
                                subtitle: '$dateStr (${unescoSite.type})', // 날짜 및 타입
                                trailing: '🆕',
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // 하단 버튼
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: totalCount == 0
                              ? null
                              : () {
                            Navigator.of(context).pop({
                              'flights': selectedFlights,
                              'airports': selectedAirports,
                              'countries': selectedCountries,
                              'cities': selectedCities,
                              'landmarks': selectedLandmarks,
                              'unescoSites': selectedUnescoSites, // 🆕 UNESCO Sites 반환
                            });
                          },
                          icon: const Icon(Icons.save, size: 20),
                          label: Text(
                            'Add $totalCount ${totalCount == 1 ? 'Item' : 'Items'}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 카테고리 헤더
  Widget _buildCategoryHeader({
    required IconData icon,
    required String title,
    required int count,
    required int selectedCount,
    required Color color,
    required VoidCallback onSelectAll,
  }) {
    final allSelected = selectedCount == count;

    return InkWell(
      onTap: onSelectAll,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$selectedCount/$count',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            Text(
              allSelected ? 'Deselect All' : 'Select All',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              allSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // 선택 가능한 아이템
  Widget _buildSelectableItem({
    required bool isSelected,
    required ValueChanged<bool?> onChanged,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    String? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? color.withOpacity(0.3) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: onChanged,
              activeColor: color,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ],
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        )
            : null,
        trailing: trailing != null
            ? Text(
          trailing,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        )
            : null,
        onTap: () => onChanged(!isSelected),
      ),
    );
  }
}