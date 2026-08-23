// lib/services/flight_price_service.dart
//
// Client-side service that calls the getFlightPrice / getFlightBookingLink
// Cloud Functions. The RapidAPI key lives only on the server (Cloud Function)
// and is never exposed to the app.

import 'package:cloud_functions/cloud_functions.dart';

class FlightPriceResult {
  final bool found;
  final int? priceRaw;
  final String? priceFormatted;
  final int? stopCount;
  final int? durationInMinutes;
  final String? carrier;
  final String? itineraryId;
  final String? sessionId;
  // 'trip.com' when the server found a Trip.com-specific pricing option,
  // 'lowest-available' when it fell back to the cheapest fare across all
  // agents in the aggregator response (may not match Trip.com's actual price).
  final String? priceSource;

  const FlightPriceResult({
    required this.found,
    this.priceRaw,
    this.priceFormatted,
    this.stopCount,
    this.durationInMinutes,
    this.carrier,
    this.itineraryId,
    this.sessionId,
    this.priceSource,
  });

  bool get isDirect => stopCount == 0;
  bool get isTripComPrice => priceSource == 'trip.com';

  factory FlightPriceResult.fromMap(Map<String, dynamic> map) {
    return FlightPriceResult(
      found: map['found'] as bool? ?? false,
      priceRaw: (map['priceRaw'] as num?)?.toInt(),
      priceFormatted: map['priceFormatted'] as String?,
      stopCount: (map['stopCount'] as num?)?.toInt(),
      durationInMinutes: (map['durationInMinutes'] as num?)?.toInt(),
      carrier: map['carrier'] as String?,
      itineraryId: map['itineraryId'] as String?,
      sessionId: map['sessionId'] as String?,
      priceSource: map['priceSource'] as String?,
    );
  }
}

class FlightPriceService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Fetches the cheapest fare for hub airport -> destination on a given date
  /// (the Cloud Function handles 24h caching).
  static Future<FlightPriceResult> getPrice({
    required String originIata,
    required String destinationIata,
    required String date, // 'YYYY-MM-DD'
    String? stops, // 'direct' | null (any)
  }) async {
    final callable = _functions.httpsCallable('getFlightPrice');
    final result = await callable.call<Map<String, dynamic>>({
      'originIata': originIata,
      'destinationIata': destinationIata,
      'date': date,
      if (stops != null) 'stops': stops,
    });
    return FlightPriceResult.fromMap(Map<String, dynamic>.from(result.data));
  }

  /// Fetches the booking deep link for a specific itinerary (call this only
  /// when the "Book" button is tapped).
  static Future<String> getBookingLink({
    required String itineraryId,
    required String sessionId,
  }) async {
    final callable = _functions.httpsCallable('getFlightBookingLink');
    final result = await callable.call<Map<String, dynamic>>({
      'itineraryId': itineraryId,
      'sessionId': sessionId,
    });
    final data = Map<String, dynamic>.from(result.data);
    return data['deepLink'] as String;
  }
}