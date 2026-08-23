// lib/services/ai_service.dart

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jidoapp/models/trip_log_entry.dart'; // AiLandmarkLog, AirportLog 등 포함
import 'package:jidoapp/services/aero_data_box_service.dart';
import 'package:intl/intl.dart';
import 'package:jidoapp/models/flight_info.dart';
import 'dart:developer' as developer;
import 'package:collection/collection.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class DatedTripItem {
  final DateTime date;
  final String type;
  final dynamic data;

  DatedTripItem({required this.date, required this.type, required this.data});
}

class AiService {
  final String _apiKey = dotenv.env['DEEPSEEK_API_KEY'] ?? 'NO_KEY';
  final String _deepSeekModel = 'deepseek-chat'; // 필요시 'deepseek-reasoner' 로 변경 가능
  static const String _deepSeekEndpoint = 'https://api.deepseek.com/chat/completions';
  final Distance distance = const Distance();
  final double travelThresholdKm = 70.0;

  Future<String> analyzeTripDna(String aggregatedData) async {
    const String systemPrompt = """
You are a savvy travel analyst and psychologist. Your mission is to analyze the user's comprehensive travel data and create a detailed "Trip DNA" profile. Based on the provided data (visited countries, cities, landmarks, airlines, diary entries, etc.), deduce the user's travel style.

Structure your output exactly as follows, using the specified emojis. Be insightful and creative in your analysis.

** traveler's DNA **

👤 **Traveler Type:** [e.g., Urban Explorer, History Buff, Nature Lover, Luxury Seeker, Adventure Junkie, etc.]

🌍 **Preferred Continent/Region:** [e.g., Western Europe, Southeast Asia, North America]

☀️ **Preferred Climate/Environment:** [e.g., Prefers sunny beaches, bustling metropolises, serene mountains, historical old towns]

✈️ **Travel Pace:** [e.g., Fast-paced & efficient, covering many spots; Slow & relaxed, savoring each location]

🏛️ **Main Interests:**
- [Interest 1, e.g., Historical architecture and UNESCO sites]
- [Interest 2, e.g., Modern art museums and culinary experiences]
- [Interest 3, e.g., Natural landscapes and outdoor activities]

📝 **Summary:**
[Provide a 2-3 sentence narrative summary of the user's travel style, combining the elements above into a cohesive description.]
""";
    return _callDeepSeekApi(systemPrompt, aggregatedData);
  }

  Future<String> recommendDestinations(String aggregatedData) async {
    const String systemPrompt = """
You are an expert travel consultant with deep knowledge of destinations worldwide. Based on the user's past travel data, analyze their implicit preferences and recommend THREE new destinations they would love. Do not recommend places they have already visited.

For each recommendation, provide a compelling reason that connects to their past behavior and suggest specific activities. Structure your output exactly as follows:

**✨ Your Next Adventures Await...**

---

**1. [City, Country]** *❤️ Why you'll love it:* [Personalized reason based on user's data. e.g., "Since you enjoyed the historical architecture of Rome and the museums in Paris, you will be captivated by Prague's Old Town Square and rich history."]

*🗺️ Suggested Activities:*
- [Activity 1]
- [Activity 2]
- [Activity 3]

---

**2. [City, Country]**
*❤️ Why you'll love it:* [Personalized reason]

*🗺️ Suggested Activities:*
- [Activity 1]
- [Activity 2]
- [Activity 3]

---

**3. [City, Country]**
*❤️ Why you'll love it:* [Personalized reason]

*🗺️ Suggested Activities:*
- [Activity 1]
- [Activity 2]
- [Activity 3]
""";
    return _callDeepSeekApi(systemPrompt, aggregatedData);
  }

  // Gemini GenerativeModel 호출부를 대체하는 DeepSeek(OpenAI 호환) 공용 헬퍼
  // systemPrompt / userInput을 그대로 받아 기존 함수 시그니처와 호환되게 유지
  Future<String> _callDeepSeekApi(String systemPrompt, String userInput) async {
    if (_apiKey == 'NO_KEY') return "API Key is missing.";

    try {
      final response = await http.post(
        Uri.parse(_deepSeekEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _deepSeekModel,
          'messages': [
            if (systemPrompt.isNotEmpty)
              {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userInput},
          ],
          'stream': false,
        }),
      );

      if (response.statusCode != 200) {
        developer.log(
          'DeepSeek API error: ${response.statusCode} ${response.body}',
          name: 'AiService._callDeepSeekApi',
        );
        return 'Error: Could not connect to the AI service.';
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final text = decoded['choices']?[0]?['message']?['content'] as String?;
      return text ?? 'No response text available.';
    } catch (e) {
      developer.log('Error calling DeepSeek API: $e', name: 'AiService._callDeepSeekApi');
      return 'Error: Could not connect to the AI service.';
    }
  }

  String _extractTextFromQuill(String jsonContent) {
    final buffer = StringBuffer();
    try {
      if (jsonContent.trim().startsWith('[')) {
        final List<dynamic> deltaList = jsonDecode(jsonContent);
        for (final op in deltaList) {
          if (op is Map && op.containsKey('insert')) {
            final insertData = op['insert'];
            if (insertData is String) {
              buffer.write(insertData);
            }
          }
        }
        return buffer.toString();
      } else {
        return jsonContent.replaceAll(RegExp(r'!\[.*?\]\((.*?)\)'), '').trim();
      }
    } catch (e) {
      return jsonContent.replaceAll(RegExp(r'!\[.*?\]\((.*?)\)'), '').trim();
    }
  }

  Future<String> getItineraryFromText(String userInput, String tripTitle) async {
    if (_apiKey == 'NO_KEY') {
      print("API Key not found in .env file.");
      return "API Key is missing.";
    }

    final filteredInput = _extractTextFromQuill(userInput);

    final String prompt = '''
You are an itinerary assistant. A user will input a free-form travel plan. Parse it and summarize it into a clean, day-by-day itinerary.

CRITICAL FORMATTING RULES:
1. Start EACH day strictly with this format: "📅 YYYY-MM-DD (Day)"
2. Do not add any separators like "---" or "|||". The "📅" emoji acts as the separator.
3. Use these emojis for details:
   🛫 Departure
   🛬 Arrival
   ✈️ Flight
   🚄 Train
   🚌 Bus
   🚗 Car
   🏨 Accommodation
   ⛰️ Activity/Visit

Example Output:
📅 2025-05-28 (Wednesday)

🛫 10:00 Incheon Departure
🛬 14:00 Tokyo Arrival
🏨 Shinjuku Prince Hotel

📅 2025-05-29 (Thursday)

⛰️ Tokyo Tower Visit
⛰️ Shibuya Crossing

Now parse:
"""$filteredInput"""
''';

    try {
      // 기존에는 systemPrompt와 userInput 구분 없이 prompt 전체를 한 번에 보냈으므로
      // system 메시지는 비워두고 동일하게 동작하도록 유지
      return await _callDeepSeekApi('', prompt);
    } catch (e) {
      developer.log('DeepSeek Error: $e', name: 'AiService.getItineraryFromText');
      return 'Error: Failed to get itinerary from AI.\nError: $e';
    }
  }

  Future<AiSummary> getSummaryFromText(String text, Map<String, String> countryNameToIso, AeroDataBoxService aeroDataBoxService) async {
    if (_apiKey == 'NO_KEY') {
      print("API Key not found in .env file.");
      return AiSummary();
    }

    final filteredText = _extractTextFromQuill(text);

    const String systemPrompt = """
You are an expert travel data analyst. Extract and structure travel data with precise time and duration analysis.

CRITICAL: Always prioritize explicit times mentioned in the text over any defaults.

Output Format: Use semicolons (;) to separate multiple items. If a category is empty, omit that line.

AIRPORT INFERENCE RULES (STRICTLY ENFORCED):
1. **MANDATORY IATA CODES:** For Origin and Destination in Flights, you MUST output 3-letter IATA codes (e.g., ICN, JFK, LHR).
2. **NEVER USE CITY NAMES:** Do not output 'Seoul', 'Tokyo', 'London'. You MUST guess the most probable airport code.
3. **PROBABILITY GUESSING:** If the text implies a city but not a specific airport, infer the main international hub.
   - "Seoul" -> ICN (Incheon)
   - "Tokyo" -> NRT (Narita)
   - "London" -> LHR (Heathrow)
   - "New York" -> JFK
   - "Paris" -> CDG
   - "Osaka" -> KIX
   - "Bangkok" -> BKK
   - "Singapore" -> SIN
4. **FORMAT:** Flights: Airline: FlightNum(YYYY-MM-DD, IATA-IATA, HH:MM-HH:MM, Duration:X hours, Sequence: X)

TIME EXTRACTION PRIORITY (MANDATORY ORDER):
1. **EXPLICIT TIMES FIRST (HIGHEST PRIORITY):** - Extract EXACT times when mentioned: "Dep 07:42", "Arr 11:05", "departed at 9:30 AM", "arrived around 14:00"
   - Transport departure time from city = city departure time
   - Transport arrival time to city = city arrival time
   - Look for patterns: "Dep XX:XX / Arr XX:XX", "departed XX:XX", "arrived XX:XX"

2. **Time Format Patterns to Extract:**
   - "Dep 07:42 / Arr 11:05" → Departure: 07:42, Arrival: 11:05
   - "Dep 08:55 / Arr 11:46" → Departure: 08:55, Arrival: 11:46
   - "Board 17:30 / Off 18:45" → Departure: 17:30, Arrival: 18:45
   - Any XX:XX format in 24-hour or convert AM/PM

3. **Contextual Clues (ONLY if no explicit times):**
   - Morning → 09:00
   - Lunch → 12:00
   - Afternoon → 14:00
   - Evening → 18:00
   - Late night → 22:00
   - Early morning → 07:00

4. **Default Fallback (LAST RESORT):**
   - Default Arrival: 14:00
   - Default Departure: 09:00

CITY DURATION CALCULATION:
- Calculate from arrival time to departure time in hours
- If departure is next day, add 24 hours
- Example: Arrive 07:42, Depart 08:55 next day = 25 hours 13 minutes = 25 hours

FORMAT REQUIREMENTS:
Countries: Country Name(Arrival:YYYY-MM-DD, Duration: X days)
Cities: CityName(ISO-A2)(Arrival:YYYY-MM-DD HH:MM, Departure:YYYY-MM-DD HH:MM, Duration: X hours)
Airports: IATA-AirportName(YYYY-MM-DD, Transit:true/false)
Flights: Airline: FlightNum(YYYY-MM-DD, ORIGIN-DEST, HH:MM-HH:MM, Duration:X hours, Sequence: X)
Trains: Company: TrainNum(YYYY-MM-DD, Origin City-Destination City, HH:MM-HH:MM, Duration:X hours, Sequence: X)
Buses: Company: (YYYY-MM-DD, Origin City-Destination City, HH:MM-HH:MM, Duration:X hours, Sequence: X)
Ferries: Ferry Name: (YYYY-MM-DD, Origin City-Destination City, HH:MM-HH:MM, Duration:X hours, Sequence: X)
Cars: Car Type: (YYYY-MM-DD, Origin City-Destination City, HH:MM-HH:MM, Duration:X hours, Sequence: X)
Landmarks: LandmarkName(YYYY-MM-DD); LandmarkName(Unknown)
TransitAirports: IATA_Code1; IATA_Code2
startLocation: [First departure point]
endLocation: [Final arrival point]

TRANSPORT EXTRACTION RULES:
- Extract ALL transport with explicit times
- Use full city names for origin/destination
- Include all departure/arrival times exactly as stated
- Calculate durations based on stated times
- Sequence numbers based on chronological order

LANDMARKS:
- Extract only famous tourist attractions, historical sites, natural landmarks
- EXCLUDE: Transport hubs, hotels, restaurants, shops
- **DATE Extraction:** If a specific visit date is mentioned or implied, include it as YYYY-MM-DD. If unknown, use "Unknown".

TRANSIT AIRPORTS:
- Only if explicitly mentioned as layover/transit
- Or stay < 24 hours between flights with no sightseeing

AIRPORTS:
- Extract ALL airports mentioned (departure, arrival, transit, layover)
- Use IATA code (3-letter: ICN, JFK, CDG) if mentioned, otherwise infer from city
- Mark Transit:true ONLY if explicitly mentioned as transit/layover/connection
- Mark Transit:false if it's a regular departure or arrival airport
- Include visit date if available from context (flight date, arrival date)
- Example: "ICN-Incheon International Airport(2025-05-28, Transit:false); NRT-Narita Airport(2025-05-29, Transit:true)"

MANDATORY: If explicit times are mentioned in the text (like "Dep 07:42 / Arr 11:05"), you MUST use those exact times. Never ignore explicit time information.
""";
    try {
      final responseText = await _callDeepSeekApi(systemPrompt, filteredText);
      return await _parseStructuredAiResponse(responseText, countryNameToIso, aeroDataBoxService);
    } catch (e) {
      developer.log('DeepSeek Error: $e', name: 'AiService.getSummaryFromText');
      return AiSummary();
    }
  }

  Future<String> generateItineraryFromSummary(AiSummary summary) async {
    if (_apiKey == 'NO_KEY') {
      return "API Key is missing.";
    }
    String summaryData = _convertSummaryToText(summary);
    const String systemPrompt = """You are a travel itinerary formatter. Based on the provided travel data, create a clean day-by-day itinerary in the exact format shown below.
Use these exact emojis and format:
📅 [Date in Korean format (e.g., 5월 28일 (Wed))]
🛫 [Time] [Airport/Station] Departure
🛬 [Time] [Airport/Station] Arrival
✈️ [Airline + Flight Number]
🚄 [Time] [Station] Departure ([Company])
⏰ [Time] [Station] Arrival
🚌 [Time] [Station] Departure ([Company])
⏰ [Time] [Station] Arrival
🛥️ [Time] [Port] Departure ([Ferry Name])
⏰ [Time] [Port] Arrival
🚗 [Time] [Origin City] Departure ([Car Type])
⏰ [Time] [Destination City] Arrival
🏨 [Hotel Name] ([Booking Platform])
🏡 [Address] (Airbnb)
⛰️ [Activity or exploration info]
---
Separate each day with "---". If exact times are unknown, use approximate times based on typical schedules.
If an entry has no specific time, just omit the time.
CRITICAL: The date format for '📅' must be "YYYY-MM-DD (DayOfWeek in Korean)". For example: "2025-07-15 (화)".
""";

    try {
      return await _callDeepSeekApi(
        systemPrompt,
        'Create an itinerary from this travel data:\n$summaryData',
      );
    } catch (e) {
      developer.log('DeepSeek Error: $e', name: 'AiService.generateItineraryFromSummary');
      return 'Error: Could not connect to AI service for itinerary generation.';
    }
  }

  String _convertSummaryToText(AiSummary summary) {
    StringBuffer buffer = StringBuffer();

    // Countries
    if (summary.countries.isNotEmpty) {
      buffer.writeln('Countries visited:');
      for (var country in summary.countries) {
        buffer.writeln('- ${country.name} (Arrival: ${country.arrivalDate}, Duration: ${country.duration})');
      }
      buffer.writeln();
    }

    // Cities
    if (summary.cities.isNotEmpty) {
      buffer.writeln('Cities visited:');
      for (var cityGroup in summary.cities) {
        buffer.writeln('${cityGroup.countryName}:');
        for (var city in cityGroup.cities) {
          buffer.writeln('  - ${city.name} (Arrival: ${city.arrivalDate}, Departure: ${city.departureDate}, Duration: ${city.duration})');
        }
      }
      buffer.writeln();
    }

    // Airports
    if (summary.airports.isNotEmpty) {
      buffer.writeln('Airports:');
      for (var airport in summary.airports) {
        buffer.writeln('- ${airport.iataCode}-${airport.name} (${airport.visitDate ?? 'Unknown'}, Transit: ${airport.isTransit})');
      }
      buffer.writeln();
    }

    // Flights
    if (summary.flights.isNotEmpty) {
      buffer.writeln('Flights:');
      for (var airline in summary.flights) {
        for (var flight in airline.flights) {
          buffer.writeln('- ${airline.airlineName} ${flight.flightNumber}: ${flight.origin} -> ${flight.destination} (${flight.flightDate} ${flight.departureTime} - ${flight.arrivalTime}) (Sequence: ${flight.sequence})');
        }
      }
      buffer.writeln();
    }

    // Trains
    if (summary.trains.isNotEmpty) {
      buffer.writeln('Trains:');
      for (var train in summary.trains) {
        buffer.writeln('- ${train.trainCompany}: ${train.trainNumber} ${train.origin} -> ${train.destination} (${train.date} ${train.departureTime} - ${train.arrivalTime}) (Sequence: ${train.sequence})');
      }
      buffer.writeln();
    }

    // Buses
    if (summary.buses.isNotEmpty) {
      buffer.writeln('Buses:');
      for (var bus in summary.buses) {
        buffer.writeln('- ${bus.busCompany}: ${bus.origin} -> ${bus.destination} (${bus.date} ${bus.departureTime} - ${bus.arrivalTime}) (Sequence: ${bus.sequence})');
      }
      buffer.writeln();
    }

    // Ferries
    if (summary.ferries.isNotEmpty) {
      buffer.writeln('Ferries:');
      for (var ferry in summary.ferries) {
        buffer.writeln('- ${ferry.ferryName}: ${ferry.origin} -> ${ferry.destination} (${ferry.date} ${ferry.departureTime} - ${ferry.arrivalTime}) (Sequence: ${ferry.sequence})');
      }
      buffer.writeln();
    }

    // Cars
    if (summary.cars.isNotEmpty) {
      buffer.writeln('Cars:');
      for (var car in summary.cars) {
        buffer.writeln('- ${car.carType}: ${car.origin} -> ${car.destination} (${car.date} ${car.departureTime} - ${car.arrivalTime}) (Sequence: ${car.sequence})');
      }
      buffer.writeln();
    }

    // Landmarks [변경됨] AiLandmarkLog 처리
    if (summary.landmarks.isNotEmpty) {
      buffer.writeln('Landmarks:');
      for (var landmark in summary.landmarks) {
        buffer.writeln('- ${landmark.name} (${landmark.visitDate ?? 'Unknown'})');
      }
      buffer.writeln();
    }

    // Transit Airports
    if (summary.transitAirports.isNotEmpty) {
      buffer.writeln('Transit Airports:');
      for (var airport in summary.transitAirports) {
        buffer.writeln('- $airport');
      }
      buffer.writeln();
    }

    // Start/End Location
    if (summary.startLocation != null) {
      buffer.writeln('startLocation: ${summary.startLocation}');
    }
    if (summary.endLocation != null) {
      buffer.writeln('endLocation: ${summary.endLocation}');
    }

    return buffer.toString();
  }


  Future<AiSummary> _parseStructuredAiResponse(String content, Map<String, String> countryNameToIso, AeroDataBoxService aeroDataBoxService) async {
    developer.log('AI Full Response: $content', name: 'AiService._parseStructuredAiResponse');

    final List<CountryLog> countries = [];
    final List<CitiesInCountry> cities = [];
    final List<AirportLog> airports = [];
    final List<AirlineLog> flights = [];
    final List<TrainLog> trains = [];
    final List<BusLog> buses = [];
    final List<FerryLog> ferries = [];
    final List<CarLog> cars = [];
    // 🔄 [수정됨] 타입 변경
    final List<AiLandmarkLog> landmarks = [];
    List<String> transitAirports = [];
    String? startLoc;
    String? endLoc;

    final List<DatedTripItem> datedItems = [];

    DateTime? _tryParseDateTime(String dateStr, String timeStr) {
      if (dateStr == 'Unknown' || timeStr == 'Unknown') return null;
      try {
        final dateTimeStr = '$dateStr $timeStr:00';
        return DateTime.parse(dateTimeStr).toUtc();
      } catch (e) {
        developer.log('❌ Failed to parse DateTime: $dateStr $timeStr. Error: $e', name: 'AiService.parseDateTime');
        return null;
      }
    }

    String normalizedContent = content;
    for (final key in ['Countries:', 'Cities:', 'Airports:', 'Flights:', 'Trains:', 'Buses:', 'Ferries:', 'Cars:', 'Landmarks:', 'TransitAirports:', 'startLocation:', 'endLocation:']) {
      normalizedContent = normalizedContent.replaceAll('$key\n', key);
    }
    final lines = normalizedContent.split('\n');    for (final line in lines) {
      if (line.startsWith('Countries:')) {
        final data = line.substring('Countries:'.length).trim();
        final items = data.split(';');
        for (final item in items) {
          final match = RegExp(r'(.+?)\s*\(Arrival:\s*(.*?),\s*Duration:\s*(.*?)\)').firstMatch(item.trim());
          if (match != null) {
            final countryName = match.group(1)!.trim();
            final isoCode = countryNameToIso[countryName] ?? 'N/A';
            countries.add(CountryLog(
              name: '${match.group(1) ?? ''}($isoCode)',
              arrivalDate: match.group(2)!.trim(),
              duration: match.group(3)!.trim(),
            ));
          }
        }
      } else if (line.startsWith('Cities:')) {
        final data = line.substring('Cities:'.length).trim();
        final RegExp cityItemRegExp = RegExp(r'([^()]+?)\s*\(([A-Z]{2})\)\(Arrival:\s*(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}),\s*Departure:\s*(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}),\s*Duration:\s*([^)]+?)\)');
        final RegExp simpleCityItemRegExp = RegExp(r'([^()]+?)\(Arrival:\s*(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}),\s*Departure:\s*(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}),\s*Duration:\s*([^)]+?)\)');

        final List<String> cityDataItems = data.split(';').map((e) => e.trim().replaceAll(RegExp(r'^[,\s]+'), '')).where((e) => e.isNotEmpty).toList();
        final Set<String> processedCitiesInAiService = {};

        for (final cityDataItem in cityDataItems) {
          Match? match = cityItemRegExp.firstMatch(cityDataItem);
          bool isFullMatch = match != null;

          if (match == null) {
            match = simpleCityItemRegExp.firstMatch(cityDataItem);
          }

          if (match != null) {
            final cityName = (match.group(1) ?? 'Unknown City').trim();
            final countryIsoA2 = isFullMatch ? (match.group(2) ?? 'N/A').trim() : 'N/A';
            final arrivalDate = isFullMatch ? (match.group(3) ?? 'Unknown').trim() : (match.group(2) ?? 'Unknown').trim();
            final arrivalTime = isFullMatch ? (match.group(4) ?? 'Unknown').trim() : (match.group(3) ?? 'Unknown').trim();
            final departureDate = isFullMatch ? (match.group(5) ?? 'Unknown').trim() : (match.group(4) ?? 'Unknown').trim();
            final departureTime = isFullMatch ? (match.group(6) ?? 'Unknown').trim() : (match.group(5) ?? 'Unknown').trim();
            final duration = isFullMatch ? (match.group(7) ?? 'N/A').trim() : (match.group(6) ?? 'N/A').trim();

            if (cityName.isNotEmpty && !processedCitiesInAiService.contains('${cityName.toLowerCase()}_$countryIsoA2')) {
              processedCitiesInAiService.add('${cityName.toLowerCase()}_$countryIsoA2');
              String fullCountryName = countries.firstWhereOrNull(
                    (c) => c.name.contains('($countryIsoA2)'),
              )?.name.split('(').first.trim() ?? 'Unknown Country';

              CitiesInCountry? currentCountryGroup = cities.firstWhereOrNull(
                    (group) => group.countryName.contains('($countryIsoA2)'),
              );

              if (currentCountryGroup == null) {
                currentCountryGroup = CitiesInCountry(countryName: '$fullCountryName($countryIsoA2)', cities: []);
                cities.add(currentCountryGroup);
              }

              final newCityDetail = CityVisitDetail(
                name: cityName,
                arrivalDate: arrivalDate,
                arrivalTime: arrivalTime,
                departureDate: departureDate,
                departureTime: departureTime,
                duration: duration,
              );

              if (!currentCountryGroup.cities.any((c) => c.name.toLowerCase() == newCityDetail.name.toLowerCase())) {
                currentCountryGroup.cities.add(newCityDetail);
              }

              final arrivalDateTime = _tryParseDateTime(arrivalDate, arrivalTime);
              if (arrivalDateTime != null) {
                datedItems.add(DatedTripItem(
                    date: arrivalDateTime,
                    type: 'City',
                    data: newCityDetail
                ));
              }
            }
          }
        }
      } else if (line.startsWith('Airports:')) {
        final data = line.substring('Airports:'.length).trim();
        final items = data.split(';');
        for (final item in items) {
          final match = RegExp(
              r'([A-Z]{3})-([^(]+)\((\d{4}-\d{2}-\d{2}|Unknown),\s*Transit:(true|false)\)'
          ).firstMatch(item.trim());

          if (match != null) {
            final String iataCode = match.group(1)!.trim();
            final String airportName = match.group(2)!.trim();
            final String dateStr = match.group(3)!.trim();
            final bool isTransit = match.group(4) == 'true';

            airports.add(AirportLog(
              iataCode: iataCode,
              name: airportName,
              visitDate: dateStr != 'Unknown' ? dateStr : null,
              isTransit: isTransit,
            ));
          }
        }
      } else if (line.startsWith('Flights:')) {
        final data = line.substring('Flights:'.length).trim();
        final items = data.split(';');
        final validItems = items.where((item) => item.trim().isNotEmpty).toList();

        for (final item in validItems) {
          final RegExp flightRegExp = RegExp(
              r'(?:([^:]+?)(?::\s*|\s+))?([A-Z0-9\s]+?)\s*\(\s*(\d{4}-\d{2}-\d{2}|Unknown)\s*,\s*([^,\-]+?)\s*-\s*([^,\-]+?)\s*,\s*([^,\-]+?)\s*-\s*([^,]+?)\s*,\s*(?:Duration:\s*)?([^,]+?)\s*,\s*Sequence:\s*(\d+)\s*\)',
              caseSensitive: false
          );

          final flightMatch = flightRegExp.firstMatch(item.trim());

          if (flightMatch != null) {
            final String airlineName = (flightMatch.group(1) ?? 'Unknown Airline').trim();
            final String flightNumber = (flightMatch.group(2) ?? 'N/A').trim();
            final String flightDate = (flightMatch.group(3) ?? 'Unknown').trim();

            String origin = (flightMatch.group(4) ?? 'Unknown').trim();
            String destination = (flightMatch.group(5) ?? 'Unknown').trim();

            final String departureTime = (flightMatch.group(6) ?? 'Unknown').trim();
            final String arrivalTime = (flightMatch.group(7) ?? 'Unknown').trim();
            final String duration = (flightMatch.group(8) ?? 'N/A').trim();
            final int sequence = int.parse(flightMatch.group(9)!);

            if (flightNumber != 'N/A' && flightNumber.isNotEmpty) {
              try {
                FlightInfo? flightInfo = await aeroDataBoxService.getFlightInfo(
                    flightNumber,
                    flightDate
                );

                if (flightInfo != null) {
                  if (flightInfo.departureIata != null && flightInfo.departureIata!.isNotEmpty) {
                    origin = flightInfo.departureIata!;
                  }
                  if (flightInfo.arrivalIata != null && flightInfo.arrivalIata!.isNotEmpty) {
                    destination = flightInfo.arrivalIata!;
                  }
                }
              } catch (e) {
                developer.log('⚠️ API lookup failed for $flightNumber', name: 'AiService.Flights');
              }
            }

            final detailToAdd = FlightDetail(
              flightNumber: flightNumber,
              origin: origin,
              destination: destination,
              flightDate: flightDate,
              departureTime: departureTime,
              arrivalTime: arrivalTime,
              duration: duration,
              sequence: sequence,
            );

            AirlineLog? existingAirlineLog = flights.firstWhereOrNull(
                    (log) => log.airlineName.toLowerCase() == airlineName.toLowerCase()
            );

            if (existingAirlineLog != null) {
              if (!existingAirlineLog.flights.any((f) => f.flightNumber == detailToAdd.flightNumber && f.origin == detailToAdd.origin && f.destination == detailToAdd.destination)) {
                existingAirlineLog.flights.add(detailToAdd);
              }
            } else {
              flights.add(AirlineLog(airlineName: airlineName, flights: [detailToAdd]));
            }

            final departureDateTime = _tryParseDateTime(flightDate, departureTime);
            if (departureDateTime != null) {
              datedItems.add(DatedTripItem(
                  date: departureDateTime,
                  type: 'Flight',
                  data: detailToAdd
              ));
            }
          }
        }
      } else if (line.startsWith('Trains:')) {
        final data = line.substring('Trains:'.length).trim();
        final items = data.split(';');
        for (final item in items) {
          final match = RegExp(r'([^:]+):\s*([^()]+)\((\d{4}-\d{2}-\d{2}|Unknown),\s*(.+?)-(.+?),\s*(.*?)-(.*?),\s*(.*?),\s*Sequence:\s*(\d+)\)').firstMatch(item.trim());
          if (match != null) {
            final String trainCompany = (match.group(1) ?? 'Unknown Company').trim();
            final String trainNumber = (match.group(2) ?? 'N/A').trim();
            final String date = (match.group(3) ?? 'Unknown').trim();
            final String origin = (match.group(4) ?? 'Unknown').trim();
            final String destination = (match.group(5) ?? 'Unknown').trim();
            final String departureTime = (match.group(6) ?? 'Unknown').trim();
            final String arrivalTime = (match.group(7) ?? 'Unknown').trim();
            final String duration = (match.group(8) ?? 'N/A').trim();
            final int sequence = int.parse(match.group(9)!);

            final log = TrainLog(
              trainCompany: trainCompany,
              trainNumber: trainNumber,
              date: date,
              origin: origin,
              destination: destination,
              departureTime: departureTime,
              arrivalTime: arrivalTime,
              duration: duration,
              sequence: sequence,
            );
            trains.add(log);

            final departureDateTime = _tryParseDateTime(date, departureTime);
            if (departureDateTime != null) {
              datedItems.add(DatedTripItem(
                  date: departureDateTime,
                  type: 'Train',
                  data: log
              ));
            }
          }
        }
      } else if (line.startsWith('Buses:')) {
        final data = line.substring('Buses:'.length).trim();
        final items = data.split(';');
        for (final item in items) {
          final match = RegExp(r'^(?:([^:]+):\s*)?([^()]*?)\s*\((\d{4}-\d{2}-\d{2}|Unknown),\s*(.+?)-(.+?),\s*(.*?)-(.*?),\s*(.*?),\s*Sequence:\s*(\d+)\)$').firstMatch(item.trim());
          if (match != null) {
            String busCompany = '';
            if ((match.group(1) ?? '').isNotEmpty) {
              busCompany = (match.group(1) ?? '').trim();
              if ((match.group(2) ?? '').isNotEmpty) {
                busCompany = '$busCompany ${(match.group(2) ?? '').trim()}';
              }
            } else {
              busCompany = (match.group(2) ?? '').trim();
            }
            if (busCompany.isEmpty) {
              busCompany = 'Unknown Company';
            }

            final String date = (match.group(3) ?? 'Unknown').trim();
            final String origin = (match.group(4) ?? 'Unknown').trim();
            final String destination = (match.group(5) ?? 'Unknown').trim();
            final String departureTime = (match.group(6) ?? 'Unknown').trim();
            final String arrivalTime = (match.group(7) ?? 'Unknown').trim();
            final String duration = (match.group(8) ?? 'N/A').trim();
            final int sequence = int.parse(match.group(9)!);

            final log = BusLog(
              busCompany: busCompany.trim(),
              date: date,
              origin: origin,
              destination: destination,
              departureTime: departureTime,
              arrivalTime: arrivalTime,
              duration: duration,
              sequence: sequence,
            );
            buses.add(log);

            final departureDateTime = _tryParseDateTime(date, departureTime);
            if (departureDateTime != null) {
              datedItems.add(DatedTripItem(
                  date: departureDateTime,
                  type: 'Bus',
                  data: log
              ));
            }
          }
        }
      } else if (line.startsWith('Ferries:')) {
        final data = line.substring('Ferries:'.length).trim();
        final items = data.split(';');
        for (final item in items) {
          final match = RegExp(r'([^:]+):\s*\((\d{4}-\d{2}-\d{2}|Unknown),\s*(.+?)-(.+?),\s*(.*?)-(.*?),\s*(.*?),\s*Sequence:\s*(\d+)\)').firstMatch(item.trim());
          if (match != null) {
            final String ferryName = (match.group(1) ?? 'Unknown Ferry').trim();
            final String date = (match.group(2) ?? 'Unknown').trim();
            final String origin = (match.group(3) ?? 'Unknown').trim();
            final String destination = (match.group(4) ?? 'Unknown').trim();
            final String departureTime = (match.group(5) ?? 'Unknown').trim();
            final String arrivalTime = (match.group(6) ?? 'Unknown').trim();
            final String duration = (match.group(7) ?? 'N/A').trim();
            final int sequence = int.parse(match.group(8)!);

            final log = FerryLog(
              ferryName: ferryName,
              date: date,
              origin: origin,
              destination: destination,
              departureTime: departureTime,
              arrivalTime: arrivalTime,
              duration: duration,
              sequence: sequence,
            );
            ferries.add(log);

            final departureDateTime = _tryParseDateTime(date, departureTime);
            if (departureDateTime != null) {
              datedItems.add(DatedTripItem(
                  date: departureDateTime,
                  type: 'Ferry',
                  data: log
              ));
            }
          }
        }
      } else if (line.startsWith('Cars:')) {
        final data = line.substring('Cars:'.length).trim();
        final items = data.split(';');
        for (final item in items) {
          final match = RegExp(r'([^:]+):\s*\((\d{4}-\d{2}-\d{2}|Unknown),\s*(.+?)-(.+?),\s*(.*?)-(.*?),\s*(.*?),\s*Sequence:\s*(\d+)\)').firstMatch(item.trim());
          if (match != null) {
            final String carType = (match.group(1) ?? 'Unknown Car').trim();
            final String date = (match.group(2) ?? 'Unknown').trim();
            final String origin = (match.group(3) ?? 'Unknown').trim();
            final String destination = (match.group(4) ?? 'Unknown').trim();
            final String departureTime = (match.group(5) ?? 'Unknown').trim();
            final String arrivalTime = (match.group(6) ?? 'Unknown').trim();
            final String duration = (match.group(7) ?? 'N/A').trim();
            final int sequence = int.parse(match.group(8)!);

            final log = CarLog(
              carType: carType,
              date: date,
              origin: origin,
              destination: destination,
              departureTime: departureTime,
              arrivalTime: arrivalTime,
              duration: duration,
              sequence: sequence,
            );
            cars.add(log);

            final departureDateTime = _tryParseDateTime(date, departureTime);
            if (departureDateTime != null) {
              datedItems.add(DatedTripItem(
                  date: departureDateTime,
                  type: 'Car',
                  data: log
              ));
            }
          }
        }
      } else if (line.startsWith('Landmarks:')) {
        // 🔄 [수정됨] Landmarks 파싱 로직 전체 수정
        final data = line.substring('Landmarks:'.length).trim();
        final rawItems = data.split(';');

        final exclusionKeywords = [
          'airport', 'terminal', 'station', 'bus stop', 'port', 'ferry terminal',
          'gas station', 'hospital', 'school', 'market', 'mall', 'shopping mall',
          'restaurant', 'cafe', 'hotel', 'residence', 'apartment', 'building', 'road', 'bridge', 'highway', 'street',
          'office', 'bank', 'grocery', 'shop', 'house', 'outlet', 'arcade', 'factory', 'industrial complex',
          'subway station', 'underpass', 'tunnel', 'intersection', 'parking lot', 'restroom', 'public phone', 'ATM'
        ];

        for (final item in rawItems) {
          if (item.trim().isEmpty) continue;

          // 포맷: LandmarkName(YYYY-MM-DD) 또는 LandmarkName(Unknown) 파싱
          final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(item.trim());

          String name;
          String? date;

          if (match != null) {
            name = match.group(1)!.trim();
            date = match.group(2)!.trim();
            if (date.toLowerCase() == 'unknown') date = null;
          } else {
            // 괄호가 없는 경우 이름만 처리
            name = item.trim();
            date = null;
          }

          final lowerCaseName = name.toLowerCase();
          final isExcluded = exclusionKeywords.any((k) => lowerCaseName.contains(k));

          if (!isExcluded) {
            landmarks.add(AiLandmarkLog(name: name, visitDate: date));
          }
        }
      } else if (line.startsWith('TransitAirports:')) {
        final data = line.substring('TransitAirports:'.length).trim();
        transitAirports = data.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (line.startsWith('startLocation:')) {
        startLoc = line.substring('startLocation:'.length).trim();
        startLoc = startLoc.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      } else if (line.startsWith('endLocation:')) {
        endLoc = line.substring('endLocation:'.length).trim();
        endLoc = endLoc.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      }
    }

    // (기존 후처리 로직 계속...)
    final List<dynamic> allTransports = <dynamic>[...flights.expand((element) => element.flights), ...trains, ...buses, ...ferries, ...cars];
    allTransports.sort((a, b) => (a as dynamic).sequence.compareTo((b as dynamic).sequence));

    if (startLoc == null || startLoc!.isEmpty || startLoc! == 'Unknown') {
      if (allTransports.isNotEmpty) {
        if (allTransports.first is FlightDetail) {
          startLoc = (allTransports.first as FlightDetail).origin;
        } else if (allTransports.first is TrainLog) {
          startLoc = (allTransports.first as TrainLog).origin;
        } else if (allTransports.first is BusLog) {
          startLoc = (allTransports.first as BusLog).origin;
        } else if (allTransports.first is FerryLog) {
          startLoc = (allTransports.first as FerryLog).origin;
        } else if (allTransports.first is CarLog) {
          startLoc = (allTransports.first as CarLog).origin;
        }
      }
    }

    if (endLoc == null || endLoc!.isEmpty || endLoc! == 'Unknown') {
      if (allTransports.isNotEmpty) {
        if (allTransports.last is FlightDetail) {
          endLoc = (allTransports.last as FlightDetail).destination;
        } else if (allTransports.last is TrainLog) {
          endLoc = (allTransports.last as TrainLog).destination;
        } else if (allTransports.last is BusLog) {
          endLoc = (allTransports.last as BusLog).destination;
        } else if (allTransports.last is FerryLog) {
          endLoc = (allTransports.last as FerryLog).destination;
        } else if (allTransports.last is CarLog) {
          endLoc = (allTransports.last as CarLog).destination;
        }
      }
    }

    return AiSummary(
      countries: countries,
      cities: cities,
      airports: airports,
      flights: flights,
      trains: trains,
      buses: buses,
      ferries: ferries,
      cars: cars,
      landmarks: landmarks, // 🔄 [수정됨]
      transitAirports: transitAirports,
      startLocation: startLoc,
      endLocation: endLoc,
    );
  }
}