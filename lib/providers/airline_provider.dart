// lib/providers/airline_provider.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/airport_model.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FlightScatterPlotPoint {
  final FlightLog flight;
  final double durationMinutes;
  final double distanceKm;
  final Color color;

  FlightScatterPlotPoint({
    required this.flight,
    required this.durationMinutes,
    required this.distanceKm,
    required this.color,
  });
}

// 변경됨: 항공사 이름 대신 ICAO (Code3) 코드로 매핑
const Map<String, String> airlineAlliances = {
  // SkyTeam
  "AMX": "SkyTeam", // Aeroméxico
  "AEA": "SkyTeam", // Air Europa
  "AFR": "SkyTeam", // Air France
  "CAL": "SkyTeam", // China Airlines
  "CES": "SkyTeam", // China Eastern
  "DAL": "SkyTeam", // Delta Air Lines
  "GIA": "SkyTeam", // Garuda Indonesia
  "KLM": "SkyTeam", // KLM
  "KAL": "SkyTeam", // Korean Air
  "MEA": "SkyTeam", // Middle East Airlines
  "SVA": "SkyTeam", // Saudia
  "SAS": "SkyTeam", // Scandinavian Airlines (SAS)
  "ROT": "SkyTeam", // Tarom
  "HVN": "SkyTeam", // Vietnam Airlines
  "VIR": "SkyTeam", // Virgin Atlantic
  "CXA": "SkyTeam", // Xiamen Airlines
  "KQA": "SkyTeam", // Kenya Airways
  "ARG": "SkyTeam", // Aerolineas Argentinas

  // Star Alliance
  "AEE": "Star Alliance", // Aegean Airlines
  "ACA": "Star Alliance", // Air Canada
  "CCA": "Star Alliance", // Air China
  "AIC": "Star Alliance", // Air India
  "ANZ": "Star Alliance", // Air New Zealand
  "ANA": "Star Alliance", // All Nippon Airways
  "AAR": "Star Alliance", // Asiana Airlines
  "AUA": "Star Alliance", // Austrian Airlines
  "AVA": "Star Alliance", // Avianca
  "BEL": "Star Alliance", // Brussels Airlines
  "CMP": "Star Alliance", // Copa Airlines
  "CTN": "Star Alliance", // Croatia Airlines
  "MSR": "Star Alliance", // EgyptAir
  "ETH": "Star Alliance", // Ethiopian Airlines
  "EVA": "Star Alliance", // EVA Air
  "LOT": "Star Alliance", // LOT Polish Airlines
  "DLH": "Star Alliance", // Lufthansa
  "CSZ": "Star Alliance", // Shenzhen Airlines
  "SIA": "Star Alliance", // Singapore Airlines
  "SAA": "Star Alliance", // South African Airways
  "SWR": "Star Alliance", // SWISS International Air Lines
  "TAP": "Star Alliance", // TAP Air Portugal
  "THA": "Star Alliance", // Thai Airways International
  "THY": "Star Alliance", // Turkish Airlines
  "UAL": "Star Alliance", // United Airlines

  // OneWorld
  "ASA": "OneWorld", // Alaska Airlines
  "AAL": "OneWorld", // American Airlines
  "BAW": "OneWorld", // British Airways
  "CPA": "OneWorld", // Cathay Pacific
  "FJI": "OneWorld", // Fiji Airways
  "FIN": "OneWorld", // Finnair
  "IBE": "OneWorld", // Iberia
  "JAL": "OneWorld", // Japan Airlines
  "MAS": "OneWorld", // Malaysia Airlines
  "OMA": "OneWorld", // Oman Air
  "QFA": "OneWorld", // Qantas
  "QTR": "OneWorld", // Qatar Airways
  "RAM": "OneWorld", // Royal Air Maroc
  "RJA": "OneWorld"  // Royal Jordanian
};

enum TimeType { departure, arrival, inFlight }

class AirlineProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Airline> _airlines = [];
  List<FlightConnection> _flightConnections = [];
  List<Itinerary> _itineraries = [];

  bool get isLoading => _isLoading;
  List<Airline> get airlines => _airlines;
  List<FlightConnection> get flightConnections => _flightConnections;
  List<Itinerary> get itineraries => _itineraries;

  List<FlightLog> get allFlightLogs {
    List<FlightLog> logs = [];
    for (var airline in _airlines) {
      logs.addAll(airline.logs.map((log) {
        if (log.itineraryId != null) {
          try {
            final itinerary = _itineraries.firstWhere((i) => i.id == log.itineraryId);
            log.ticketPrice = itinerary.ticketPrice;
            log.isMileageTicket = itinerary.isMileageTicket;
            log.vat = itinerary.vat;
            log.bookingDate = itinerary.bookingDate;
          } catch (e) { }
        }

        return FlightLog(
          id: log.id,
          flightNumber: log.flightNumber,
          times: log.times,
          date: log.date,
          airlineName: airline.name,
          airlineCode: airline.code,
          departureIata: log.departureIata,
          arrivalIata: log.arrivalIata,
          scheduledDepartureTime: log.scheduledDepartureTime,
          scheduledArrivalTime: log.scheduledArrivalTime,
          aircraft: log.aircraft,
          seatClass: log.seatClass,
          ticketPrice: log.ticketPrice,
          vat: log.vat,
          isMileageTicket: log.isMileageTicket,
          mileageAirline: log.mileageAirline,
          bookingDate: log.bookingDate,
          duration: log.duration,
          delay: log.delay,
          isCanceled: log.isCanceled,
          departureTerminal: log.departureTerminal,
          departureGate: log.departureGate,
          arrivalTerminal: log.arrivalTerminal,
          arrivalGate: log.arrivalGate,
          ticketPhoto: log.ticketPhoto,
          memo: log.memo,
          photos: log.photos,
          rating: log.rating,
          itineraryId: log.itineraryId,
          upgradePrice: log.upgradePrice,
          isUpgradedWithMiles: log.isUpgradedWithMiles,
          upgradeVat: log.upgradeVat,
          upgradeDate: log.upgradeDate,
          upgradeMileageAirline: log.upgradeMileageAirline,
        );
      }));
    }
    logs.sort((a, b) {
      final dateA = DateTime.tryParse(a.date);
      final dateB = DateTime.tryParse(b.date);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    return logs;
  }

  List<Purchase> get purchases {
    final List<Purchase> purchaseList = [];
    final Set<String> processedLogIds = {};

    for (final itinerary in _itineraries) {
      if (itinerary.flightLogIds.isEmpty) continue;

      final logsInItinerary = itinerary.flightLogIds
          .map((id) => getFlightLogById(id))
          .whereType<FlightLog>()
          .toList();

      if (logsInItinerary.isEmpty) continue;

      logsInItinerary.sort((a, b) {
        final dateA = DateTime.tryParse(a.date);
        final dateB = DateTime.tryParse(b.date);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      final description = logsInItinerary.map((l) => l.flightNumber).join(', ');

      purchaseList.add(Purchase(
          id: itinerary.id,
          description: 'Itinerary: $description',
          price: itinerary.ticketPrice,
          isMileage: itinerary.isMileageTicket,
          date: itinerary.bookingDate ?? logsInItinerary.first.date,
          isItinerary: true,
          flightCount: logsInItinerary.length,
          route: '${logsInItinerary.first.departureIata} → ${logsInItinerary.last.arrivalIata}'
      ));

      processedLogIds.addAll(itinerary.flightLogIds);
    }

    for (final log in allFlightLogs) {
      if (!processedLogIds.contains(log.id) && !log.isCanceled) {
        purchaseList.add(Purchase(
            id: log.id,
            description: '${log.airlineName} ${log.flightNumber}',
            price: log.ticketPrice,
            isMileage: log.isMileageTicket,
            date: log.bookingDate,
            isItinerary: false,
            flightCount: 1,
            route: '${log.departureIata} → ${log.arrivalIata}'
        ));
      }
    }

    purchaseList.sort((a, b) {
      final dateA = DateTime.tryParse(a.date ?? '');
      final dateB = DateTime.tryParse(b.date ?? '');
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    return purchaseList;
  }

  AirlineProvider() {
    _initializeData();
  }

  String _extractAirlineCode(String flightNumber) {
    final cleanFlightNumber = flightNumber.toUpperCase().replaceAll(' ', '');
    final regex = RegExp(r'^([A-Z0-9]{2,3})');
    final match = regex.firstMatch(cleanFlightNumber);
    return match?.group(1) ?? 'N/A';
  }

  Future<void> _initializeData() async {
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    try {
      final String airlineJsonStr = await rootBundle.loadString('assets/airlines.json');
      final List<dynamic> airlineJson = json.decode(airlineJsonStr);
      // 정적 데이터로 먼저 초기화
      _airlines = airlineJson.map((json) => Airline.fromJson(json)).toList();

      String? savedAirlinesJson = prefs.getString('saved_airlines_data');
      String? savedItinerariesJson = prefs.getString('saved_itineraries_data');
      String? savedConnectionsJson = prefs.getString('saved_flight_connections');

      if (user != null) {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data();
            if (data != null) {
              if (data.containsKey('saved_airlines_data')) {
                savedAirlinesJson = data['saved_airlines_data'];
                await prefs.setString('saved_airlines_data', savedAirlinesJson!);
              }
              if (data.containsKey('saved_itineraries_data')) {
                savedItinerariesJson = data['saved_itineraries_data'];
                await prefs.setString('saved_itineraries_data', savedItinerariesJson!);
              }
              if (data.containsKey('saved_flight_connections')) {
                savedConnectionsJson = data['saved_flight_connections'];
                await prefs.setString('saved_flight_connections', savedConnectionsJson!);
              }
              if (savedAirlinesJson == null && prefs.containsKey('saved_airlines_data')) {
                _saveAllData();
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print("Failed to load airline data from server: $e");
        }
      }

      if (savedAirlinesJson != null && savedAirlinesJson.isNotEmpty) {
        final List<dynamic> decodedData = json.decode(savedAirlinesJson);
        List<Airline> loadedAirlines = decodedData.map((json) => Airline.fromJson(json)).toList();

        for (var loadedAirline in loadedAirlines) {
          int existingIndex = _airlines.indexWhere((a) =>
          (a.code != 'N/A' && a.code.isNotEmpty && a.code == loadedAirline.code) ||
              (a.name == loadedAirline.name)
          );

          if (existingIndex != -1) {
            final staticAirline = _airlines[existingIndex];

            // 정적 데이터(JSON)에 있는 code3가 로드된 데이터에 없을 경우 채워넣음
            final String? mergedCode3 = (loadedAirline.code3 == null || loadedAirline.code3!.isEmpty)
                ? staticAirline.code3
                : loadedAirline.code3;

            _airlines[existingIndex] = Airline(
              name: loadedAirline.name,
              code: loadedAirline.code == 'N/A' ? staticAirline.code : loadedAirline.code,
              code3: mergedCode3,
              themeColorHex: (loadedAirline.themeColorHex == null || loadedAirline.themeColorHex!.isEmpty)
                  ? staticAirline.themeColorHex
                  : loadedAirline.themeColorHex,
              airlineType: (loadedAirline.airlineType == null || loadedAirline.airlineType!.isEmpty)
                  ? staticAirline.airlineType
                  : loadedAirline.airlineType,
              logs: loadedAirline.logs,
              otherUsages: loadedAirline.otherUsages,
              rating: loadedAirline.rating,
              isFavorite: loadedAirline.isFavorite,
              mileageBalance: loadedAirline.mileageBalance,
            );
          } else {
            _airlines.add(loadedAirline);
          }
        }
      }
      _airlines.sort((a, b) => a.name.compareTo(b.name));

      if (savedItinerariesJson != null && savedItinerariesJson.isNotEmpty) {
        final List<dynamic> decodedData = json.decode(savedItinerariesJson);
        _itineraries = decodedData.map((json) => Itinerary.fromJson(json)).toList();
      }

      if (savedConnectionsJson != null && savedConnectionsJson.isNotEmpty) {
        final List<dynamic> decodedData = json.decode(savedConnectionsJson);
        _flightConnections = decodedData.map((json) => FlightConnection.fromJson(json)).toList();
      }

    } catch (e) {
      if (kDebugMode) print('Error during data initialization: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();

    final String airlinesJson = json.encode(_airlines.map((a) => a.toJson()).toList());
    await prefs.setString('saved_airlines_data', airlinesJson);

    final String connectionsJson = json.encode(_flightConnections.map((c) => c.toJson()).toList());
    await prefs.setString('saved_flight_connections', connectionsJson);

    final String itinerariesJson = json.encode(_itineraries.map((i) => i.toJson()).toList());
    await prefs.setString('saved_itineraries_data', itinerariesJson);

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'saved_airlines_data': airlinesJson,
          'saved_flight_connections': connectionsJson,
          'saved_itineraries_data': itinerariesJson,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) print("Failed to save airline data to server: $e");
      }
    }
  }

  void addOrUpdateItinerary(Itinerary itinerary) {
    for (var logId in itinerary.flightLogIds) {
      FlightLog? logToUpdate = getFlightLogById(logId);
      if (logToUpdate != null) {
        logToUpdate.itineraryId = itinerary.id;
        logToUpdate.ticketPrice = itinerary.ticketPrice;
        logToUpdate.isMileageTicket = itinerary.isMileageTicket;
        logToUpdate.vat = itinerary.vat;
        logToUpdate.bookingDate = itinerary.bookingDate;
      }
    }

    final index = _itineraries.indexWhere((i) => i.id == itinerary.id);
    if (index != -1) {
      _itineraries[index] = itinerary;
    } else {
      _itineraries.add(itinerary);
    }
    _saveAllData();
    notifyListeners();
  }

  void removeItinerary(String itineraryId, {List<String> excludedLogIds = const []}) {
    Itinerary? itinerary;
    try {
      itinerary = _itineraries.firstWhere((i) => i.id == itineraryId);
    } catch(e) { return; }

    for (var logId in itinerary.flightLogIds) {
      if (!excludedLogIds.contains(logId)) {
        FlightLog? logToUpdate = getFlightLogById(logId);
        logToUpdate?.itineraryId = null;
      }
    }

    _itineraries.removeWhere((i) => i.id == itineraryId);
    _saveAllData();
    notifyListeners();
  }

  FlightLog? getFlightLogById(String logId) {
    for (var airline in _airlines) {
      try {
        final log = airline.logs.firstWhere((l) => l.id == logId);
        return log;
      } catch (e) { }
    }
    return null;
  }

  void addDetailedFlightLog(String airlineName, FlightLog newLog) {
    final String targetCode = (newLog.airlineCode != null && newLog.airlineCode != 'N/A')
        ? newLog.airlineCode!
        : _extractAirlineCode(newLog.flightNumber);

    final airline = _airlines.firstWhere(
            (a) => (targetCode != 'N/A' && a.code == targetCode) || a.name == airlineName,
        orElse: () {
          final newAirline = Airline(name: airlineName, code: targetCode);
          _airlines.add(newAirline);
          _airlines.sort((a, b) => a.name.compareTo(b.name));
          return newAirline;
        });

    if (newLog.id != null) {
      final existingLogIndex = airline.logs.indexWhere((log) => log.id == newLog.id);
      if (existingLogIndex != -1) {
        airline.logs[existingLogIndex] = newLog;
      } else {
        airline.logs.add(newLog);
      }
    } else {
      final existingLogIndex = airline.logs.indexWhere(
              (log) => log.flightNumber == newLog.flightNumber && log.date == newLog.date);
      if (existingLogIndex != -1) {
        final existingLog = airline.logs[existingLogIndex];
        existingLog.times++;
        airline.logs[existingLogIndex] = FlightLog(
          id: existingLog.id,
          times: existingLog.times,
          flightNumber: newLog.flightNumber,
          date: newLog.date,
          airlineName: airline.name,
          airlineCode: airline.code,
          departureIata: newLog.departureIata,
          arrivalIata: newLog.arrivalIata,
          scheduledDepartureTime: newLog.scheduledDepartureTime,
          scheduledArrivalTime: newLog.scheduledArrivalTime,
          aircraft: newLog.aircraft,
          seatClass: newLog.seatClass,
          ticketPrice: newLog.ticketPrice,
          vat: newLog.vat,
          isMileageTicket: newLog.isMileageTicket,
          mileageAirline: newLog.mileageAirline,
          bookingDate: newLog.bookingDate,
          duration: newLog.duration,
          delay: newLog.delay,
          isCanceled: newLog.isCanceled,
          departureTerminal: newLog.departureTerminal,
          departureGate: newLog.departureGate,
          arrivalTerminal: newLog.arrivalTerminal,
          arrivalGate: newLog.arrivalGate,
          ticketPhoto: newLog.ticketPhoto,
          memo: newLog.memo,
          photos: newLog.photos,
          rating: newLog.rating,
          itineraryId: newLog.itineraryId,
          upgradePrice: newLog.upgradePrice,
          isUpgradedWithMiles: newLog.isUpgradedWithMiles,
          upgradeVat: newLog.upgradeVat,
          upgradeDate: newLog.upgradeDate,
          upgradeMileageAirline: newLog.upgradeMileageAirline,
        );
      } else {
        newLog.airlineName = airline.name;
        newLog.airlineCode = airline.code;
        airline.logs.add(newLog);
      }
    }
    notifyListeners();
    _saveAllData();
  }

  void updateFlightLog(FlightLog oldLog, FlightLog updatedLog) {
    Airline? oldAirlineContainer;
    int oldLogIndex = -1;
    for (var airline in _airlines) {
      oldLogIndex = airline.logs.indexWhere((log) => log.id == oldLog.id);
      if (oldLogIndex != -1) {
        oldAirlineContainer = airline;
        break;
      }
    }
    if (oldAirlineContainer != null) {
      oldAirlineContainer.logs.removeAt(oldLogIndex);
      if (oldAirlineContainer.logs.isEmpty && oldAirlineContainer.rating == 0.0) {
        final isFavorite = oldAirlineContainer.isFavorite;
        if (!isFavorite) {
          _airlines.removeWhere((a) => a.code == oldAirlineContainer!.code && a.name == oldAirlineContainer!.name);
        }
      }
    }
    addDetailedFlightLog(updatedLog.airlineName ?? 'Unknown', updatedLog);
  }

  void removeFlightLog(FlightLog logToRemove) {
    Airline? airline;
    try {
      airline = _airlines.firstWhere((a) => a.logs.any((log) => log.id == logToRemove.id));
    } catch (e) {
      return;
    }
    airline.logs.removeWhere((log) => log.id == logToRemove.id);

    if (airline.logs.isEmpty && airline.rating == 0.0) {
      final isFavorite = airline.isFavorite;
      if (!isFavorite) {
        _airlines.removeWhere((a) => (a.code != 'N/A' && a.code == airline!.code) || a.name == airline!.name);
      }
    }

    if (logToRemove.itineraryId != null) {
      try {
        final itinerary = _itineraries.firstWhere((i) => i.id == logToRemove.itineraryId);
        itinerary.flightLogIds.remove(logToRemove.id);
        if (itinerary.flightLogIds.length < 2) {
          removeItinerary(itinerary.id);
        }
      } catch (e) { }
    }
    _flightConnections.removeWhere((connection) => connection.flightLogIds.contains(logToRemove.id));

    notifyListeners();
    _saveAllData();
  }

  void addOtherMileageUsage(String airlineName, OtherMileageUsage newUsage) {
    final airline = _airlines.firstWhere((a) => a.name == airlineName,
        orElse: () {
          final newAirline = Airline(name: airlineName, code: 'N/A');
          _airlines.add(newAirline);
          _airlines.sort((a, b) => a.name.compareTo(b.name));
          return newAirline;
        });

    airline.otherUsages.add(newUsage);
    notifyListeners();
    _saveAllData();
  }

  void saveFlightConnection(FlightConnection connection) {
    if (connection.flightLogIds.length < 2) return;

    final index = _flightConnections.indexWhere((c) => c.id == connection.id);
    if (index != -1) {
      _flightConnections[index] = connection;
    } else {
      _flightConnections.add(connection);
    }
    _saveAllData();
    notifyListeners();
  }

  void removeFlightConnection(String connectionId) {
    _flightConnections.removeWhere((c) => c.id == connectionId);
    _saveAllData();
    notifyListeners();
  }

  void updateAirlineRating(String airlineName, double newRating) {
    try {
      final airline = _airlines.firstWhere((a) => a.name == airlineName);
      airline.rating = newRating;
      notifyListeners();
      _saveAllData();
    } catch (e) {
      if (kDebugMode) print("Could not find airline $airlineName to update rating.");
    }
  }

  void updateAirlineMileageBalance(String airlineName, double newBalance) {
    try {
      final airline = _airlines.firstWhere((a) => a.name == airlineName);
      airline.mileageBalance = newBalance;
      notifyListeners();
      _saveAllData();
    } catch (e) {
      if (kDebugMode) print("Could not find airline $airlineName to update mileage balance.");
    }
  }

  // 항공사 유형 업데이트 메서드 추가 (필요 시 호출하여 사용)
  void updateAirlineType(String airlineName, String newType) {
    try {
      final airline = _airlines.firstWhere((a) => a.name == airlineName);
      airline.airlineType = newType;
      notifyListeners();
      _saveAllData();
    } catch (e) {
      if (kDebugMode) print("Could not find airline $airlineName to update type.");
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    lat1 = _degreesToRadians(lat1);
    lat2 = _degreesToRadians(lat2);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  List<FlightLog> _filterLogsByDate({DateTime? startDate, DateTime? endDate}) {
    final logs = allFlightLogs;
    return logs.where((log) {
      if (log.date == 'Unknown' || log.date.isEmpty || log.isCanceled) {
        return false;
      }
      final logDate = DateTime.tryParse(log.date);
      if (logDate == null) {
        return false;
      }
      final isAfterStart = startDate == null || logDate.isAfter(startDate.subtract(const Duration(days: 1)));
      final isBeforeEnd = endDate == null || logDate.isBefore(endDate.add(const Duration(days: 1)));
      return isAfterStart && isBeforeEnd;
    }).toList();
  }

  Future<Map<String, dynamic>> _calculateDistancesAndLogs({
    DateTime? startDate,
    DateTime? endDate,
    required AirportProvider airportProvider,
  }) async {
    double totalDistance = 0.0;
    final filteredLogs = _filterLogsByDate(startDate: startDate, endDate: endDate);
    final logsWithDistance = <Map<String, dynamic>>[];

    for (var log in filteredLogs) {
      final departureAirport = airportProvider.allAirports.firstWhere(
            (airport) => airport.iataCode == log.departureIata,
        orElse: () => Airport(iataCode: 'N/A', name: 'Unknown', country: 'Unknown', latitude: 0.0, longitude: 0.0),
      );
      final arrivalAirport = airportProvider.allAirports.firstWhere(
            (airport) => airport.iataCode == log.arrivalIata,
        orElse: () => Airport(iataCode: 'N/A', name: 'Unknown', country: 'Unknown', latitude: 0.0, longitude: 0.0),
      );

      double distance = 0.0;
      if (departureAirport.iataCode != 'N/A' && arrivalAirport.iataCode != 'N/A') {
        distance = calculateDistance(
          departureAirport.latitude,
          departureAirport.longitude,
          arrivalAirport.latitude,
          arrivalAirport.longitude,
        );
      }
      totalDistance += distance;
      logsWithDistance.add({'log': log, 'distance': distance});
    }

    return {'totalDistance': totalDistance, 'logs': logsWithDistance};
  }

  Future<Map<String, double>> calculateDistanceStats({
    DateTime? startDate,
    DateTime? endDate,
    required AirportProvider airportProvider,
  }) async {
    final results = await _calculateDistancesAndLogs(
      startDate: startDate,
      endDate: endDate,
      airportProvider: airportProvider,
    );
    final totalDistance = results['totalDistance'] as double;
    final logs = results['logs'] as List<Map<String, dynamic>>;
    final flightCount = logs.length;
    final averageDistance = flightCount > 0 ? totalDistance / flightCount : 0.0;

    return {
      'total': totalDistance,
      'average': averageDistance,
    };
  }

  Future<Map<String, FlightLog?>> findLongestShortestFlightByDistance({
    DateTime? startDate,
    DateTime? endDate,
    required AirportProvider airportProvider,
  }) async {
    final results = await _calculateDistancesAndLogs(
      startDate: startDate,
      endDate: endDate,
      airportProvider: airportProvider,
    );
    final logsWithDistance = results['logs'] as List<Map<String, dynamic>>;

    if (logsWithDistance.isEmpty) {
      return {'longest': null, 'shortest': null};
    }

    logsWithDistance.sort((a, b) => (b['distance'] as double).compareTo(a['distance'] as double));
    final longestFlight = logsWithDistance.first['log'] as FlightLog;
    final shortestFlight = logsWithDistance.last['log'] as FlightLog;

    return {'longest': longestFlight, 'shortest': shortestFlight};
  }

  int parseDuration(String? duration) {
    if (duration == null || duration.isEmpty) {
      return 0;
    }
    int totalMinutes = 0;
    final parts = duration.split(' ');
    for (var part in parts) {
      if (part.contains('h')) {
        final hours = int.tryParse(part.replaceAll('h', ''));
        if (hours != null) totalMinutes += hours * 60;
      } else if (part.contains('m')) {
        final minutes = int.tryParse(part.replaceAll('m', ''));
        if (minutes != null) totalMinutes += minutes;
      }
    }
    return totalMinutes;
  }

  Future<Map<String, double>> calculateDurationStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final filteredLogs = _filterLogsByDate(startDate: startDate, endDate: endDate);
    int totalMinutes = 0;
    for (var log in filteredLogs) {
      totalMinutes += parseDuration(log.duration);
    }
    final flightCount = filteredLogs.length;
    final averageMinutes = flightCount > 0 ? totalMinutes / flightCount : 0.0;

    return {
      'total': totalMinutes.toDouble(),
      'average': averageMinutes,
    };
  }

  Future<Map<String, FlightLog?>> findLongestShortestFlightByDuration({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final filteredLogs = _filterLogsByDate(startDate: startDate, endDate: endDate);
    if (filteredLogs.isEmpty) {
      return {'longest': null, 'shortest': null};
    }

    filteredLogs.sort((a, b) => parseDuration(b.duration).compareTo(parseDuration(a.duration)));
    final longestFlight = filteredLogs.first;
    final shortestFlight = filteredLogs.last;

    return {'longest': longestFlight, 'shortest': shortestFlight};
  }

  Future<Map<String, double>> calculateFlightCountStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final filteredLogs = _filterLogsByDate(startDate: startDate, endDate: endDate);
    double totalCount = 0;
    for (var log in filteredLogs) {
      totalCount += log.times;
    }

    final daysInPeriod = (endDate != null && startDate != null)
        ? endDate.difference(startDate).inDays + 1
        : 0;

    final averageCount = totalCount > 0 && daysInPeriod > 0 ? totalCount / daysInPeriod : 0.0;

    return {
      'total': totalCount,
      'average': averageCount,
    };
  }

  Future<Map<String, FlightLog?>> findLongestShortestFlightByCount({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final filteredLogs = _filterLogsByDate(startDate: startDate, endDate: endDate);
    if (filteredLogs.isEmpty) {
      return {'longest': null, 'shortest': null};
    }

    filteredLogs.sort((a, b) => b.times.compareTo(a.times));
    final longestFlight = filteredLogs.first;

    filteredLogs.sort((a, b) => a.times.compareTo(b.times));
    final shortestFlight = filteredLogs.first;

    return {'longest': longestFlight, 'shortest': shortestFlight};
  }

  Future<Map<String, dynamic>> calculateMostFrequentPeriod({required DateFormat format}) async {
    final logs = allFlightLogs;
    if (logs.isEmpty) {
      return {'count': 0, 'period': 'N/A'};
    }

    final Map<String, int> periodCounts = {};
    for (var log in logs.where((log) => log.date != 'Unknown' && log.date.isNotEmpty && !log.isCanceled)) {
      final date = DateTime.tryParse(log.date);
      if (date != null) {
        String period;

        if (format.pattern == 'yyyy-ww') {
          final weekNumber = _getWeekNumber(date);
          period = '${date.year}-${weekNumber.toString().padLeft(2, '0')}';
        } else {
          period = format.format(date);
        }

        periodCounts[period] = (periodCounts[period] ?? 0) + log.times;
      }
    }

    if (periodCounts.isEmpty) {
      return {'count': 0, 'period': 'N/A'};
    }

    final sortedPeriods = periodCounts.keys.toList()
      ..sort((a, b) {
        final countComparison = periodCounts[b]!.compareTo(periodCounts[a]!);
        if (countComparison != 0) return countComparison;

        final dateA = _parsePeriod(a, format);
        final dateB = _parsePeriod(b, format);
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

    final mostFrequentPeriod = sortedPeriods.first;
    final mostFrequentCount = periodCounts[mostFrequentPeriod]!;

    return {'count': mostFrequentCount, 'period': mostFrequentPeriod};
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime.utc(date.year, 1, 1);
    final daysOffset = (firstDayOfYear.weekday == DateTime.sunday) ? 6 : firstDayOfYear.weekday - 1;
    final startOfFirstWeek = firstDayOfYear.subtract(Duration(days: daysOffset));
    final daysSinceFirstWeek = date.difference(startOfFirstWeek).inDays;
    return (daysSinceFirstWeek / 7).floor() + 1;
  }

  DateTime? _parsePeriod(String period, DateFormat format) {
    try {
      if (format.pattern == 'yyyy') {
        return DateTime(int.parse(period));
      } else if (format.pattern == 'yyyy-MM') {
        final parts = period.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]));
      } else if (format.pattern == 'yyyy-ww') {
        final parts = period.split('-');
        final year = int.parse(parts[0]);
        final week = int.parse(parts[1]);
        final firstDayOfYear = DateTime(year, 1, 4);
        final dayOfWeek = firstDayOfYear.weekday;
        final firstMonday = firstDayOfYear.subtract(Duration(days: dayOfWeek - 1));
        return firstMonday.add(Duration(days: (week - 1) * 7));
      }
    } catch(e) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>> calculateLongestStreakByMonthWithPeriod() async {
    final validLogs = allFlightLogs.where((log) => log.date != 'Unknown' && !log.isCanceled).toList();
    if (validLogs.isEmpty) return {'count': 0, 'period': ''};

    final uniqueMonths = validLogs
        .map((log) => DateFormat('yyyy-MM').format(DateTime.parse(log.date)))
        .toSet()
        .toList()
      ..sort();

    if (uniqueMonths.isEmpty) return {'count': 0, 'period': ''};

    int maxStreak = 0;
    int currentStreak = 0;
    String longestStreakStartMonth = '';
    String longestStreakEndMonth = '';
    String currentStreakStartMonth = '';

    DateTime? previousMonthDate;

    for (int i = 0; i < uniqueMonths.length; i++) {
      final monthStr = uniqueMonths[i];
      final currentMonthDate = DateTime.parse('$monthStr-01');

      if (previousMonthDate == null) {
        currentStreak = 1;
        currentStreakStartMonth = monthStr;
      } else {
        bool isConsecutive = (currentMonthDate.year == previousMonthDate.year && currentMonthDate.month == previousMonthDate.month + 1) ||
            (currentMonthDate.year == previousMonthDate.year + 1 && currentMonthDate.month == 1 && previousMonthDate.month == 12);

        if (isConsecutive) {
          currentStreak++;
        } else {
          if (currentStreak > maxStreak) {
            maxStreak = currentStreak;
            longestStreakStartMonth = currentStreakStartMonth;
            longestStreakEndMonth = DateFormat('yyyy-MM').format(previousMonthDate);
          }
          currentStreak = 1;
          currentStreakStartMonth = monthStr;
        }
      }

      if (i == uniqueMonths.length - 1) {
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
          longestStreakStartMonth = currentStreakStartMonth;
          longestStreakEndMonth = monthStr;
        }
      }
      previousMonthDate = currentMonthDate;
    }

    if (maxStreak == 0 && uniqueMonths.isNotEmpty) {
      maxStreak = 1;
      longestStreakStartMonth = uniqueMonths.first;
      longestStreakEndMonth = uniqueMonths.first;
    }

    final period = maxStreak > 1 ? '$longestStreakStartMonth ~ $longestStreakEndMonth' : (maxStreak == 1 ? longestStreakStartMonth : '');
    return {'count': maxStreak, 'period': period};
  }

  Future<Map<String, dynamic>> calculateLongestStreakByYearWithPeriod() async {
    final validLogs = allFlightLogs.where((log) => log.date != 'Unknown' && !log.isCanceled).toList();
    if (validLogs.isEmpty) return {'count': 0, 'period': ''};

    final uniqueYears = validLogs
        .map((log) => DateTime.parse(log.date).year)
        .toSet()
        .toList()
      ..sort();

    if (uniqueYears.isEmpty) return {'count': 0, 'period': ''};

    int maxStreak = 0;
    int currentStreak = 0;
    int longestStreakStartYear = 0;
    int longestStreakEndYear = 0;
    int currentStreakStartYear = 0;

    for (int i = 0; i < uniqueYears.length; i++) {
      final year = uniqueYears[i];
      if (i == 0) {
        currentStreak = 1;
        currentStreakStartYear = year;
      } else {
        if (year == uniqueYears[i - 1] + 1) {
          currentStreak++;
        } else {
          if (currentStreak > maxStreak) {
            maxStreak = currentStreak;
            longestStreakStartYear = currentStreakStartYear;
            longestStreakEndYear = uniqueYears[i - 1];
          }
          currentStreak = 1;
          currentStreakStartYear = year;
        }
      }

      if (i == uniqueYears.length - 1) {
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
          longestStreakStartYear = currentStreakStartYear;
          longestStreakEndYear = year;
        }
      }
    }

    if (maxStreak == 0 && uniqueYears.isNotEmpty) {
      maxStreak = 1;
      longestStreakStartYear = uniqueYears.first;
      longestStreakEndYear = uniqueYears.first;
    }

    final period = maxStreak > 1
        ? '$longestStreakStartYear ~ $longestStreakEndYear'
        : (maxStreak == 1 ? '$longestStreakStartYear' : '');

    return {'count': maxStreak, 'period': period};
  }

  Future<Map<String, dynamic>> getFrequencyStats(String pattern) async {
    final logs = allFlightLogs;
    if (logs.isEmpty) {
      return {'distribution': {}, 'most_frequent': 'N/A', 'count': 0};
    }

    final Map<String, int> periodCounts = {};
    final format = DateFormat(pattern);

    for (var log in logs.where((log) => log.date != 'Unknown' && log.date.isNotEmpty && !log.isCanceled)) {
      final date = DateTime.tryParse(log.date);
      if (date != null) {
        String period = format.format(date);
        periodCounts[period] = (periodCounts[period] ?? 0) + log.times;
      }
    }

    if (periodCounts.isEmpty) {
      return {'distribution': {}, 'most_frequent': 'N/A', 'count': 0};
    }

    final sortedPeriods = periodCounts.keys.toList()
      ..sort((a, b) => periodCounts[b]!.compareTo(periodCounts[a]!));

    final mostFrequentPeriod = sortedPeriods.first;
    final mostFrequentCount = periodCounts[mostFrequentPeriod]!;

    return {'distribution': periodCounts, 'most_frequent': mostFrequentPeriod, 'count': mostFrequentCount};
  }

  Future<Map<String, dynamic>> getHourlyFrequencyStats({required TimeType timeType}) async {
    final logs = allFlightLogs;
    if (logs.isEmpty) {
      return {'distribution': {}, 'most_frequent': 'N/A', 'count': 0};
    }

    final Map<int, int> hourlyCounts = {for (var i = 0; i < 24; i++) i: 0};

    for (var log in logs.where((log) => !log.isCanceled)) {
      if (timeType == TimeType.inFlight) {
        final depTimeStr = log.scheduledDepartureTime;
        final arrTimeStr = log.scheduledArrivalTime;
        if (depTimeStr != null && depTimeStr != 'Unknown' && arrTimeStr != null && arrTimeStr != 'Unknown') {
          final depParts = depTimeStr.split(':');
          final arrParts = arrTimeStr.split(':');
          if (depParts.length == 2 && arrParts.length == 2) {
            final startHour = int.tryParse(depParts[0]);
            final endHour = int.tryParse(arrParts[0]);
            if (startHour != null && endHour != null) {
              if (startHour <= endHour) {
                for (int h = startHour; h < endHour; h++) {
                  hourlyCounts[h] = (hourlyCounts[h] ?? 0) + log.times;
                }
              } else {
                for (int h = startHour; h < 24; h++) {
                  hourlyCounts[h] = (hourlyCounts[h] ?? 0) + log.times;
                }
                for (int h = 0; h < endHour; h++) {
                  hourlyCounts[h] = (hourlyCounts[h] ?? 0) + log.times;
                }
              }
            }
          }
        }
      } else {
        final timeString = timeType == TimeType.departure ? log.scheduledDepartureTime : log.scheduledArrivalTime;
        if (timeString != null && timeString != 'Unknown') {
          final timeParts = timeString.split(':');
          if (timeParts.length == 2) {
            final hour = int.tryParse(timeParts[0]);
            if (hour != null && hour >= 0 && hour < 24) {
              hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + log.times;
            }
          }
        }
      }
    }

    if (hourlyCounts.values.every((element) => element == 0)) {
      return {'distribution': {}, 'most_frequent': 'N/A', 'count': 0};
    }

    final sortedHours = hourlyCounts.keys.toList()
      ..sort((a, b) => hourlyCounts[b]!.compareTo(hourlyCounts[a]!));

    final mostFrequentHour = sortedHours.first;
    final mostFrequentCount = hourlyCounts[mostFrequentHour]!;

    final nextHour = (mostFrequentHour + 1) % 24;
    final mostFrequentString = '${mostFrequentHour.toString().padLeft(2, '0')}:00~${nextHour.toString().padLeft(2, '0')}:00';

    final Map<String, int> stringKeyDistribution = hourlyCounts.map((key, value) => MapEntry(key.toString(), value));

    return {
      'distribution': stringKeyDistribution,
      'most_frequent': mostFrequentString,
      'count': mostFrequentCount
    };
  }

  void toggleFavoriteStatus(String airlineName) {
    try {
      final airline = _airlines.firstWhere((a) => a.name == airlineName);
      airline.isFavorite = !airline.isFavorite;
      _saveAllData();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling favorite status: $e');
      }
    }
  }

  Future<Map<String, int>> getDurationDistributionStats() async {
    final logs = allFlightLogs.where((log) => !log.isCanceled && log.duration != null && log.duration != 'Unknown');

    final Map<String, int> distribution = {
      '~1h': 0,
      '1–3h': 0,
      '3–6h': 0,
      '6–10h': 0,
      '10–14h': 0,
      '14h+': 0,
    };

    for (var log in logs) {
      final minutes = parseDuration(log.duration);
      if (minutes > 0) {
        if (minutes < 60) {
          distribution['~1h'] = (distribution['~1h'] ?? 0) + log.times;
        } else if (minutes < 180) {
          distribution['1–3h'] = (distribution['1–3h'] ?? 0) + log.times;
        } else if (minutes < 360) {
          distribution['3–6h'] = (distribution['3–6h'] ?? 0) + log.times;
        } else if (minutes < 600) {
          distribution['6–10h'] = (distribution['6–10h'] ?? 0) + log.times;
        } else if (minutes < 840) {
          distribution['10–14h'] = (distribution['10–14h'] ?? 0) + log.times;
        } else {
          distribution['14h+'] = (distribution['14h+'] ?? 0) + log.times;
        }
      }
    }
    return distribution;
  }

  Future<Map<String, int>> getDistanceDistributionStats({required AirportProvider airportProvider}) async {
    final logs = allFlightLogs.where((log) => !log.isCanceled);

    final Map<String, int> distribution = {
      '~500km': 0,
      '500-1,500km': 0,
      '1,500-4,000km': 0,
      '4,000-8,000km': 0,
      '8,000-12,000km': 0,
      '12,000km+': 0,
    };

    for (var log in logs) {
      final departureAirport = airportProvider.allAirports.firstWhere(
            (airport) => airport.iataCode == log.departureIata,
        orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0),
      );
      final arrivalAirport = airportProvider.allAirports.firstWhere(
            (airport) => airport.iataCode == log.arrivalIata,
        orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0),
      );

      if (departureAirport.iataCode.isNotEmpty && arrivalAirport.iataCode.isNotEmpty) {
        final distance = calculateDistance(
          departureAirport.latitude,
          departureAirport.longitude,
          arrivalAirport.latitude,
          arrivalAirport.longitude,
        );
        if (distance > 0) {
          if (distance < 500) {
            distribution['~500km'] = (distribution['~500km'] ?? 0) + log.times;
          } else if (distance < 1500) {
            distribution['500-1,500km'] = (distribution['500-1,500km'] ?? 0) + log.times;
          } else if (distance < 4000) {
            distribution['1,500-4,000km'] = (distribution['1,500-4,000km'] ?? 0) + log.times;
          } else if (distance < 8000) {
            distribution['4,000-8,000km'] = (distribution['4,000-8,000km'] ?? 0) + log.times;
          } else if (distance < 12000) {
            distribution['8,000-12,000km'] = (distribution['8,000-12,000km'] ?? 0) + log.times;
          } else {
            distribution['12,000km+'] = (distribution['12,000km+'] ?? 0) + log.times;
          }
        }
      }
    }
    return distribution;
  }

  Future<List<FlightScatterPlotPoint>> getScatterPlotData({required AirportProvider airportProvider}) async {
    final List<FlightScatterPlotPoint> plotData = [];
    final logs = allFlightLogs;

    Color colorFromHex(String? hexString, {Color fallback = Colors.grey}) {
      if (hexString == null || hexString.isEmpty) return fallback;
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      try {
        return Color(int.parse(buffer.toString(), radix: 16));
      } catch (e) {
        return fallback;
      }
    }

    for (var log in logs) {
      if (log.duration == null || log.duration == 'Unknown' || log.isCanceled) continue;

      final durationMinutes = parseDuration(log.duration).toDouble();
      if (durationMinutes <= 0) continue;

      final departureAirport = airportProvider.allAirports.firstWhere((a) => a.iataCode == log.departureIata, orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0));
      final arrivalAirport = airportProvider.allAirports.firstWhere((a) => a.iataCode == log.arrivalIata, orElse: () => Airport(iataCode: '', name: '', country: '', latitude: 0, longitude: 0));

      if (departureAirport.iataCode.isEmpty || arrivalAirport.iataCode.isEmpty) continue;

      final distanceKm = calculateDistance(
          departureAirport.latitude,
          departureAirport.longitude,
          arrivalAirport.latitude,
          arrivalAirport.longitude
      );
      if (distanceKm <= 0) continue;

      Color pointColor = Colors.grey;
      if (log.airlineName != null && log.airlineName != 'Unknown') {
        try {
          final airline = _airlines.firstWhere((a) => (log.airlineCode != null && a.code == log.airlineCode) || a.name == log.airlineName);
          pointColor = colorFromHex(airline.themeColorHex, fallback: Colors.grey);
        } catch (e) { }
      }

      plotData.add(FlightScatterPlotPoint(
        flight: log,
        durationMinutes: durationMinutes,
        distanceKm: distanceKm,
        color: pointColor,
      ));
    }
    return plotData;
  }

  bool isDuplicateFlight({
    String? flightNumber,
    String? date,
    String? originIata,
    String? destinationIata,
  }) {
    if (date == null || date.isEmpty || date == 'Unknown') return false;

    if (flightNumber != null && flightNumber.isNotEmpty && flightNumber != 'N/A' && flightNumber != 'Unknown') {
      return allFlightLogs.any((log) =>
      log.flightNumber == flightNumber &&
          log.date == date
      );
    }
    else if (originIata != null && originIata.isNotEmpty && destinationIata != null && destinationIata.isNotEmpty) {
      return allFlightLogs.any((log) =>
      log.departureIata == originIata &&
          log.arrivalIata == destinationIata &&
          log.date == date
      );
    }

    return false;
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  Future<void> reloadFromServer() async {
    await _initializeData();
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveAllData();
  }

}