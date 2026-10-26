// lib/services/travel_persona_engine.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:jidoapp/models/trip_log_entry.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/services/persona_scorer.dart';
import 'package:jidoapp/services/traveler_type_store.dart';
import 'package:jidoapp/services/travel_quantifier.dart';
import 'package:jidoapp/travel_persona/travel_features.dart';
import 'package:provider/provider.dart';

import 'package:jidoapp/providers/personality_provider.dart';

class TravelPersonaEngine {
  TravelPersonaEngine._internal();

  static final TravelPersonaEngine _instance = TravelPersonaEngine._internal();

  factory TravelPersonaEngine() => _instance;

  String? _apiKey;
  static const String _deepSeekModel = 'deepseek-chat';
  static const String _deepSeekEndpoint = 'https://api.deepseek.com/chat/completions';

  // 주의: 예전 코드에 하드코딩되어 있던 Gemini fallback 키는 완전히 제거했습니다.
  // 소스코드에 API 키를 하드코딩하는 것은 심각한 보안 위험이므로 .env 값이 없으면
  // 바로 예외를 던지도록 변경했습니다.
  void _ensureModel() {
    if (_apiKey != null) return;
    final envKey = dotenv.env['DEEPSEEK_API_KEY'];
    if (envKey == null || envKey.isEmpty) {
      _apiKey = null;
      return;
    }
    _apiKey = envKey;
  }

  static const String _archetypePrototypesJson = r'''
[
  {
    "id": "identity_seeker",
    "label": "Identity Seeker",
    "data": {
      "solo_social": {"P": 1.0, "W": 3}, "nature_culture": {"P": 0.2, "W": 2}, "relaxed_intensive": {"P": -0.6, "W": 2}, "planned_spontaneous": {"P": 0.4, "W": 1}, "budget_luxury": {"P": 0.3, "W": 1}, "transit_drive": {"P": 0.4, "W": 1}, "documenter_minimalist": {"P": -0.5, "W": 2}, "morning_night": {"P": 0.6, "W": 1},
      "continentDistribution": {"P": 0.2, "W": 1}, "countryDistribution": {"P": 0.0, "W": 0}, "cityDistribution": {"P": -0.4, "W": 1}, "airportDistribution": {"P": 0.0, "W": 0}, "airlineDistribution": {"P": 0.0, "W": 0},
      "countryWealth": {"P": -0.4, "W": 1}, "cityWealth": {"P": -0.3, "W": 1}, "countryType": {"P": -0.2, "W": 1}, "cityType": {"P": -0.5, "W": 1}, "countryNightlife": {"P": -0.7, "W": 1}, "cityNightlife": {"P": -0.8, "W": 1},
      "airlineTime": {"P": 0.5, "W": 1}, "transferAirportScore": {"P": 0.3, "W": 1}, "transferFlightScore": {"P": 0.3, "W": 1},
      "landmark_culture_nature": {"P": -0.4, "W": 1}, "landmark_ancient_modern": {"P": -0.9, "W": 1}, "landmark_urban_rural": {"P": 0.6, "W": 2}, "landmark_adventure_relax": {"P": 0.3, "W": 1}, "landmark_art_science": {"P": -0.5, "W": 1}, "landmark_spiritual_secular": {"P": -1.0, "W": 2}, "landmark_crowd": {"P": -0.9, "W": 1}, "landmark_budget_luxury": {"P": -0.3, "W": 1}, "landmark_local_tourist": {"P": -0.7, "W": 1}, "landmark_calm_nightlife": {"P": -0.8, "W": 1}
    }
  },
  {
    "id": "wildlife_earth_enthusiast",
    "label": "Wildlife & Earth Enthusiast",
    "data": {
      "solo_social": {"P": 0.7, "W": 2}, "nature_culture": {"P": 1.0, "W": 3}, "relaxed_intensive": {"P": 0.4, "W": 1}, "planned_spontaneous": {"P": 0.2, "W": 2}, "budget_luxury": {"P": 0.5, "W": 2}, "transit_drive": {"P": -0.8, "W": 2}, "documenter_minimalist": {"P": 0.2, "W": 1}, "morning_night": {"P": 0.9, "W": 2},
      "continentDistribution": {"P": 0.3, "W": 1}, "countryDistribution": {"P": 0.0, "W": 1}, "cityDistribution": {"P": -0.8, "W": 1}, "airportDistribution": {"P": -0.5, "W": 1}, "airlineDistribution": {"P": 0.0, "W": 1},
      "countryWealth": {"P": 0.0, "W": 0}, "cityWealth": {"P": 0.0, "W": 0}, "countryType": {"P": -1.0, "W": 2}, "cityType": {"P": -1.0, "W": 2}, "countryNightlife": {"P": -0.9, "W": 1}, "cityNightlife": {"P": -1.0, "W": 1},
      "airlineTime": {"P": 0.4, "W": 1}, "transferAirportScore": {"P": 0.6, "W": 1}, "transferFlightScore": {"P": 0.6, "W": 1},
      "landmark_culture_nature": {"P": -1.0, "W": 2}, "landmark_ancient_modern": {"P": 0.0, "W": 0}, "landmark_urban_rural": {"P": 1.0, "W": 2}, "landmark_adventure_relax": {"P": -0.6, "W": 1}, "landmark_art_science": {"P": 0.0, "W": 0}, "landmark_spiritual_secular": {"P": -0.6, "W": 1}, "landmark_crowd": {"P": -1.0, "W": 2}, "landmark_budget_luxury": {"P": -0.5, "W": 1}, "landmark_local_tourist": {"P": -0.8, "W": 1}, "landmark_calm_nightlife": {"P": -0.9, "W": 1}
    }
  },
  {
    "id": "cultural_decoder",
    "label": "Cultural Decoder",
    "data": {
      "solo_social": {"P": -0.2, "W": 2}, "nature_culture": {"P": -1.0, "W": 3}, "relaxed_intensive": {"P": -0.3, "W": 1}, "planned_spontaneous": {"P": -0.4, "W": 1}, "budget_luxury": {"P": -0.6, "W": 2}, "transit_drive": {"P": 0.8, "W": 2}, "documenter_minimalist": {"P": -0.8, "W": 2}, "morning_night": {"P": -0.3, "W": 2},
      "continentDistribution": {"P": 0.0, "W": 0}, "countryDistribution": {"P": 0.0, "W": 0}, "cityDistribution": {"P": 0.8, "W": 1}, "airportDistribution": {"P": 0.6, "W": 1}, "airlineDistribution": {"P": 0.0, "W": 0},
      "countryWealth": {"P": 0.6, "W": 1}, "cityWealth": {"P": 0.8, "W": 1}, "countryType": {"P": 0.9, "W": 2}, "cityType": {"P": 1.0, "W": 2}, "countryNightlife": {"P": 0.3, "W": 1}, "cityNightlife": {"P": 0.5, "W": 1},
      "airlineTime": {"P": 0.0, "W": 0}, "transferAirportScore": {"P": -0.5, "W": 1}, "transferFlightScore": {"P": -0.5, "W": 1},
      "landmark_culture_nature": {"P": 1.0, "W": 2}, "landmark_ancient_modern": {"P": -0.7, "W": 1}, "landmark_urban_rural": {"P": -1.0, "W": 2}, "landmark_adventure_relax": {"P": 0.7, "W": 1}, "landmark_art_science": {"P": -0.9, "W": 2}, "landmark_spiritual_secular": {"P": 0.3, "W": 1}, "landmark_crowd": {"P": 0.3, "W": 1}, "landmark_budget_luxury": {"P": 0.4, "W": 1}, "landmark_local_tourist": {"P": 0.5, "W": 1}, "landmark_calm_nightlife": {"P": 0.0, "W": 0}
    }
  },
  {
    "id": "global_connector",
    "label": "Global Connector",
    "data": {
      "solo_social": {"P": -0.9, "W": 3}, "nature_culture": {"P": 0.0, "W": 1}, "relaxed_intensive": {"P": 0.6, "W": 2}, "planned_spontaneous": {"P": 0.9, "W": 3}, "budget_luxury": {"P": 1.0, "W": 3}, "transit_drive": {"P": 0.9, "W": 2}, "documenter_minimalist": {"P": -0.4, "W": 1}, "morning_night": {"P": -0.8, "W": 2},
      "continentDistribution": {"P": 0.6, "W": 1}, "countryDistribution": {"P": 0.7, "W": 1}, "cityDistribution": {"P": 0.8, "W": 1}, "airportDistribution": {"P": 0.7, "W": 1}, "airlineDistribution": {"P": 0.9, "W": 1},
      "countryWealth": {"P": -0.7, "W": 1}, "cityWealth": {"P": -0.6, "W": 1}, "countryType": {"P": 0.2, "W": 1}, "cityType": {"P": 0.4, "W": 1}, "countryNightlife": {"P": 0.8, "W": 1}, "cityNightlife": {"P": 0.9, "W": 2},
      "airlineTime": {"P": 0.2, "W": 1}, "transferAirportScore": {"P": 0.8, "W": 1}, "transferFlightScore": {"P": 0.8, "W": 1},
      "landmark_culture_nature": {"P": 0.3, "W": 1}, "landmark_ancient_modern": {"P": 0.0, "W": 0}, "landmark_urban_rural": {"P": -0.3, "W": 1}, "landmark_adventure_relax": {"P": -0.5, "W": 1}, "landmark_art_science": {"P": -0.2, "W": 0}, "landmark_spiritual_secular": {"P": 0.5, "W": 1}, "landmark_crowd": {"P": 0.6, "W": 1}, "landmark_budget_luxury": {"P": -0.9, "W": 1}, "landmark_local_tourist": {"P": 0.3, "W": 1}, "landmark_calm_nightlife": {"P": 0.8, "W": 1}
    }
  },
  {
    "id": "joy_collector",
    "label": "Joy Collector",
    "data": {
      "solo_social": {"P": -0.5, "W": 2}, "nature_culture": {"P": -0.3, "W": 2}, "relaxed_intensive": {"P": -1.0, "W": 3}, "planned_spontaneous": {"P": -0.6, "W": 2}, "budget_luxury": {"P": -1.0, "W": 3}, "transit_drive": {"P": -0.5, "W": 2}, "documenter_minimalist": {"P": 0.6, "W": 1}, "morning_night": {"P": 0.0, "W": 0},
      "continentDistribution": {"P": -0.5, "W": 1}, "countryDistribution": {"P": -0.6, "W": 1}, "cityDistribution": {"P": -0.5, "W": 1}, "airportDistribution": {"P": 0.0, "W": 0}, "airlineDistribution": {"P": -0.7, "W": 1},
      "countryWealth": {"P": 0.7, "W": 1}, "cityWealth": {"P": 0.9, "W": 2}, "countryType": {"P": 0.3, "W": 1}, "cityType": {"P": 0.2, "W": 1}, "countryNightlife": {"P": 0.2, "W": 1}, "cityNightlife": {"P": 0.4, "W": 1},
      "airlineTime": {"P": -0.2, "W": 1}, "transferAirportScore": {"P": -0.9, "W": 1}, "transferFlightScore": {"P": -0.9, "W": 1},
      "landmark_culture_nature": {"P": 0.5, "W": 1}, "landmark_ancient_modern": {"P": 0.6, "W": 0}, "landmark_urban_rural": {"P": -0.4, "W": 1}, "landmark_adventure_relax": {"P": 1.0, "W": 2}, "landmark_art_science": {"P": 0.0, "W": 0}, "landmark_spiritual_secular": {"P": 0.8, "W": 1}, "landmark_crowd": {"P": -0.7, "W": 1}, "landmark_budget_luxury": {"P": 1.0, "W": 2}, "landmark_local_tourist": {"P": 0.2, "W": 1}, "landmark_calm_nightlife": {"P": -0.3, "W": 1}
    }
  },
  {
    "id": "achievement_hunter",
    "label": "Achievement Hunter",
    "data": {
      "solo_social": {"P": 0.5, "W": 3}, "nature_culture": {"P": 0.0, "W": 2}, "relaxed_intensive": {"P": 1.0, "W": 3}, "planned_spontaneous": {"P": -0.8, "W": 3}, "budget_luxury": {"P": 0.0, "W": 2}, "transit_drive": {"P": 0.6, "W": 2}, "documenter_minimalist": {"P": -1.0, "W": 2}, "morning_night": {"P": 0.7, "W": 1},
      "continentDistribution": {"P": 1.0, "W": 2}, "countryDistribution": {"P": 1.0, "W": 2}, "cityDistribution": {"P": 1.0, "W": 2}, "airportDistribution": {"P": 1.0, "W": 2}, "airlineDistribution": {"P": 0.8, "W": 1},
      "countryWealth": {"P": 0.0, "W": 1}, "cityWealth": {"P": 0.0, "W": 1}, "countryType": {"P": 0.0, "W": 0}, "cityType": {"P": 0.0, "W": 0}, "countryNightlife": {"P": 0.0, "W": 1}, "cityNightlife": {"P": 0.0, "W": 1},
      "airlineTime": {"P": -0.6, "W": 1}, "transferAirportScore": {"P": 0.4, "W": 1}, "transferFlightScore": {"P": 0.4, "W": 1},
      "landmark_culture_nature": {"P": 0.0, "W": 1}, "landmark_ancient_modern": {"P": 0.0, "W": 1}, "landmark_urban_rural": {"P": 0.0, "W": 1}, "landmark_adventure_relax": {"P": 0.0, "W": 0}, "landmark_art_science": {"P": 0.0, "W": 0}, "landmark_spiritual_secular": {"P": 0.0, "W": 0}, "landmark_crowd": {"P": 0.8, "W": 1}, "landmark_budget_luxury": {"P": 0.4, "W": 1}, "landmark_local_tourist": {"P": 1.0, "W": 2}, "landmark_calm_nightlife": {"P": 0.0, "W": 0}
    }
  },
  {
    "id": "efficiency_maximizer",
    "label": "Efficiency Maximizer",
    "data": {
      "solo_social": {"P": -1.0, "W": 3}, "nature_culture": {"P": -0.5, "W": 1}, "relaxed_intensive": {"P": 1.0, "W": 3}, "planned_spontaneous": {"P": -1.0, "W": 3}, "budget_luxury": {"P": -0.4, "W": 2}, "transit_drive": {"P": -0.7, "W": 2}, "documenter_minimalist": {"P": -0.2, "W": 1}, "morning_night": {"P": 0.5, "W": 1},
      "continentDistribution": {"P": -0.8, "W": 1}, "countryDistribution": {"P": -0.9, "W": 1}, "cityDistribution": {"P": -0.7, "W": 1}, "airportDistribution": {"P": -0.8, "W": 1}, "airlineDistribution": {"P": -0.6, "W": 1},
      "countryWealth": {"P": 0.8, "W": 1}, "cityWealth": {"P": 0.7, "W": 1}, "countryType": {"P": 0.5, "W": 1}, "cityType": {"P": 0.4, "W": 1}, "countryNightlife": {"P": -0.6, "W": 1}, "cityNightlife": {"P": -0.8, "W": 1},
      "airlineTime": {"P": -0.5, "W": 1}, "transferAirportScore": {"P": -0.8, "W": 1}, "transferFlightScore": {"P": -0.8, "W": 1},
      "landmark_culture_nature": {"P": 0.2, "W": 1}, "landmark_ancient_modern": {"P": 0.4, "W": 1}, "landmark_urban_rural": {"P": -0.5, "W": 1}, "landmark_adventure_relax": {"P": 0.8, "W": 1}, "landmark_art_science": {"P": 0.4, "W": 1}, "landmark_spiritual_secular": {"P": 0.4, "W": 1}, "landmark_crowd": {"P": -0.4, "W": 1}, "landmark_budget_luxury": {"P": 0.4, "W": 1}, "landmark_local_tourist": {"P": 0.8, "W": 1}, "landmark_calm_nightlife": {"P": -0.9, "W": 1}
    }
  },
  {
    "id": "inner_sanctuary_seeker",
    "label": "Inner Sanctuary Seeker",
    "data": {
      "solo_social": {"P": 0.0, "W": 2}, "nature_culture": {"P": 0.8, "W": 2}, "relaxed_intensive": {"P": 0.9, "W": 3}, "planned_spontaneous": {"P": 0.5, "W": 3}, "budget_luxury": {"P": 0.2, "W": 2}, "transit_drive": {"P": -0.3, "W": 2}, "documenter_minimalist": {"P": 0.8, "W": 2}, "morning_night": {"P": 0.4, "W": 1},
      "continentDistribution": {"P": 0.4, "W": 1}, "countryDistribution": {"P": 0.3, "W": 1}, "cityDistribution": {"P": 0.0, "W": 1}, "airportDistribution": {"P": 0.0, "W": 1}, "airlineDistribution": {"P": 0.0, "W": 0},
      "countryWealth": {"P": 0.0, "W": 0}, "cityWealth": {"P": 0.0, "W": 0}, "countryType": {"P": -0.6, "W": 3}, "cityType": {"P": -0.4, "W": 1}, "countryNightlife": {"P": 0.3, "W": 1}, "cityNightlife": {"P": 0.4, "W": 1},
      "airlineTime": {"P": 0.0, "W": 0}, "transferAirportScore": {"P": 0.3, "W": 0}, "transferFlightScore": {"P": 0.3, "W": 0},
      "landmark_culture_nature": {"P": -0.8, "W": 3}, "landmark_ancient_modern": {"P": 0.0, "W": 0}, "landmark_urban_rural": {"P": 0.7, "W": 3}, "landmark_adventure_relax": {"P": -1.0, "W": 3}, "landmark_art_science": {"P": 0.0, "W": 0}, "landmark_spiritual_secular": {"P": 0.0, "W": 0}, "landmark_crowd": {"P": -0.2, "W": 1}, "landmark_budget_luxury": {"P": -0.2, "W": 1}, "landmark_local_tourist": {"P": -0.4, "W": 1}, "landmark_calm_nightlife": {"P": 0.0, "W": 0}
    }
  },
  {
    "id": "sensory_immersionist",
    "label": "Sensory Immersionist",
    "data": {
      "solo_social": {"P": -0.4, "W": 2}, "nature_culture": {"P": -0.2, "W": 2}, "relaxed_intensive": {"P": -0.9, "W": 3}, "planned_spontaneous": {"P": 0.7, "W": 2}, "budget_luxury": {"P": 0.4, "W": 1}, "transit_drive": {"P": 0.5, "W": 1}, "documenter_minimalist": {"P": 0.9, "W": 2}, "morning_night": {"P": 0.0, "W": 2},
      "continentDistribution": {"P": -0.4, "W": 1}, "countryDistribution": {"P": -0.7, "W": 1}, "cityDistribution": {"P": -0.9, "W": 2}, "airportDistribution": {"P": -0.8, "W": 1}, "airlineDistribution": {"P": -0.6, "W": 1},
      "countryWealth": {"P": -0.3, "W": 1}, "cityWealth": {"P": -0.2, "W": 1}, "countryType": {"P": -0.4, "W": 1}, "cityType": {"P": -0.5, "W": 1}, "countryNightlife": {"P": -0.4, "W": 1}, "cityNightlife": {"P": -0.5, "W": 1},
      "airlineTime": {"P": 0.0, "W": 0}, "transferAirportScore": {"P": 0.0, "W": 0}, "transferFlightScore": {"P": -0.5, "W": 0},
      "landmark_culture_nature": {"P": 0.0, "W": 1}, "landmark_ancient_modern": {"P": 0.7, "W": 1}, "landmark_urban_rural": {"P": 0.4, "W": 1}, "landmark_adventure_relax": {"P": 0.2, "W": 1}, "landmark_art_science": {"P": -0.4, "W": 1}, "landmark_spiritual_secular": {"P": -0.3, "W": 1}, "landmark_crowd": {"P": -0.8, "W": 1}, "landmark_budget_luxury": {"P": -0.5, "W": 1}, "landmark_local_tourist": {"P": -1.0, "W": 2}, "landmark_calm_nightlife": {"P": -0.6, "W": 1}
    }
  },
  {
    "id": "freedom_drifter",
    "label": "Freedom Drifter",
    "data": {
      "solo_social": {"P": 0.8, "W": 2}, "nature_culture": {"P": -0.6, "W": 2}, "relaxed_intensive": {"P": -0.5, "W": 2}, "planned_spontaneous": {"P": 1.0, "W": 3}, "budget_luxury": {"P": 0.4, "W": 2}, "transit_drive": {"P": 0.7, "W": 2}, "documenter_minimalist": {"P": 0.5, "W": 2}, "morning_night": {"P": -0.4, "W": 2},
      "continentDistribution": {"P": 0.2, "W": 1}, "countryDistribution": {"P": -0.3, "W": 1}, "cityDistribution": {"P": -0.6, "W": 1}, "airportDistribution": {"P": -0.5, "W": 1}, "airlineDistribution": {"P": 0.0, "W": 0},
      "countryWealth": {"P": 0.3, "W": 1}, "cityWealth": {"P": 0.4, "W": 1}, "countryType": {"P": 0.6, "W": 1}, "cityType": {"P": 0.8, "W": 2}, "countryNightlife": {"P": 0.2, "W": 1}, "cityNightlife": {"P": 0.3, "W": 1},
      "airlineTime": {"P": 0.0, "W": 0}, "transferAirportScore": {"P": 0.0, "W": 0}, "transferFlightScore": {"P": 0.0, "W": 0},
      "landmark_culture_nature": {"P": 0.6, "W": 1}, "landmark_ancient_modern": {"P": 0.7, "W": 1}, "landmark_urban_rural": {"P": -0.8, "W": 2}, "landmark_adventure_relax": {"P": 0.2, "W": 1}, "landmark_art_science": {"P": 0.8, "W": 3}, "landmark_spiritual_secular": {"P": 0.6, "W": 1}, "landmark_crowd": {"P": -0.3, "W": 1}, "landmark_budget_luxury": {"P": 0.0, "W": 0}, "landmark_local_tourist": {"P": -0.3, "W": 1}, "landmark_calm_nightlife": {"P": 0.0, "W": 0}
    }
  }
]
''';

  Future<String> analyze(
      PersonalityProvider personalityProvider,
      CountryProvider countryProvider,
      CityProvider cityProvider,
      AirlineProvider airlineProvider,
      AirportProvider airportProvider,
      TripLogProvider tripLogProvider,
      ) async {
    _ensureModel();

    if (_apiKey == null) {
      throw Exception('DeepSeek API key initialization failed');
    }

    if (!personalityProvider.isCalculated) {
      personalityProvider.calculateScores();
    }
    final dnaScores = personalityProvider.finalScores;

    Map<String, double> dnaNormalized = {};
    for (final entry in dnaScores.entries) {
      final v = entry.value;
      dnaNormalized[entry.key] = ((v - 50.0) / 50.0).clamp(-1.0, 1.0);
    }

    final quantifier = TravelQuantifier(
      countryProvider: countryProvider,
      cityProvider: cityProvider,
      airlineProvider: airlineProvider,
      airportProvider: airportProvider,
    );

    final calculatedFeatures = quantifier.quantify();

    // 값이 없는 축은 0.0으로 채우지 않고 빼둔다 (PersonaScorer가 계산에서 제외).
    final fullFeatureVector = <String, double>{
      ...dnaNormalized,
      "continentDistribution": calculatedFeatures.continentDistribution,
      "countryDistribution": calculatedFeatures.countryDistribution,
      "cityDistribution": calculatedFeatures.cityDistribution,
      "airportDistribution": calculatedFeatures.airportDistribution,
      "airlineDistribution": calculatedFeatures.airlineDistribution,
      "countryWealth": calculatedFeatures.countryWealth,
      "countryType": calculatedFeatures.countryType,
      "countryNightlife": calculatedFeatures.countryNightlife,
      "airlineTime": calculatedFeatures.airlineTime,
      "transferAirportScore": calculatedFeatures.transferAirportScore,
      "transferFlightScore": calculatedFeatures.transferFlightScore,
    };

    final rawCityVisitData = _getRawCityVisitList(cityProvider);
    final rawTripLogs = _getRawTripLogList(tripLogProvider);
    final prototypes = jsonDecode(_archetypePrototypesJson) as List<dynamic>;

    // 1단계: AI는 도시/랜드마크 13개 축만 추정한다 (점수 계산은 하지 않음).
    String aiNote = 'Success';
    try {
      final axesPayload = {
        "visited_cities": rawCityVisitData,
        "trip_logs": rawTripLogs,
        "user_rating_distribution": _getAllRatingsForAI(countryProvider, cityProvider),
      };
      final axesJson = await _callDeepSeek(_axesSystemPrompt, jsonEncode(axesPayload));
      final axes = (jsonDecode(axesJson) as Map<String, dynamic>)['axes'] as Map<String, dynamic>? ?? {};
      for (final key in _aiAxisKeys) {
        final v = axes[key];
        if (v is num && v.isFinite) {
          fullFeatureVector[key] = v.toDouble().clamp(-1.0, 1.0).toDouble();
        }
      }
    } catch (e) {
      // AI 실패해도 설문 + 여행 통계 축만으로 계산은 계속한다.
      aiNote = 'Partial: AI axes unavailable ($e)';
    }

    // 2단계: 점수는 코드로 결정적으로 계산.
    final result = PersonaScorer.score(prototypes, fullFeatureVector);
    final personaScores = [
      for (final s in result.scores) {"id": s.id, "label": s.label, "score": s.score},
    ];

    // 3단계: AI는 설명문만 작성 (실패해도 점수 결과는 유지).
    var explanation = '';
    try {
      final top = result.scores.take(3).map((s) => {"label": s.label, "score": s.score}).toList();
      final explainPayload = {
        "top_types": top,
        "is_close": result.isClose,
        "full_feature_vector": fullFeatureVector,
        "visited_cities": rawCityVisitData,
        "trip_logs": rawTripLogs,
        "meta_data": {
          "total_countries": countryProvider.visitedCountries.length,
          "total_cities": cityProvider.visitedCities.length,
          "total_flights": airlineProvider.allFlightLogs.length,
        },
      };
      final explainJson = await _callDeepSeek(_explainSystemPrompt, jsonEncode(explainPayload));
      explanation = ((jsonDecode(explainJson) as Map<String, dynamic>)['ai_explanation'] as String?) ?? '';
    } catch (e) {
      explanation = 'Explanation unavailable: $e';
    }

    return jsonEncode({
      "engine_version": TravelerTypeStore.currentVersion,
      "generated_at": DateTime.now().millisecondsSinceEpoch,
      "full_feature_vector": fullFeatureVector,
      "summary": {
        "ai_explanation": explanation,
        "persona_scores": personaScores,
        "is_close": result.isClose,
        "low_data": result.lowData,
        "score_gap": result.gap,
        "data_coverage": result.coverage,
        "debug_info": aiNote,
      },
    });
  }

  static const List<String> _aiAxisKeys = [
    'cityWealth', 'cityType', 'cityNightlife',
    'landmark_culture_nature', 'landmark_ancient_modern', 'landmark_urban_rural',
    'landmark_adventure_relax', 'landmark_art_science', 'landmark_spiritual_secular',
    'landmark_crowd', 'landmark_budget_luxury', 'landmark_local_tourist',
    'landmark_calm_nightlife',
  ];

  static const String _axesSystemPrompt = r"""
You estimate 13 travel-trait axes for one traveler from raw data. Each axis is a number in [-1.0, 1.0].
Weight each visited city / landmark by the user's rating (higher rating = more weight, z-score style).
If there is not enough data for an axis, OMIT that key (do not output 0.0 as a guess).
Axes: cityWealth (poor -1 .. rich +1), cityType (nature/small-town -1 .. big metropolis +1),
cityNightlife (calm -1 .. lively +1), landmark_culture_nature (nature -1 .. culture +1),
landmark_ancient_modern (modern -1 .. ancient +1), landmark_urban_rural (rural -1 .. urban +1),
landmark_adventure_relax (relax -1 .. adventure +1), landmark_art_science (science -1 .. art +1),
landmark_spiritual_secular (secular -1 .. spiritual +1), landmark_crowd (quiet -1 .. crowded +1),
landmark_budget_luxury (budget -1 .. luxury +1), landmark_local_tourist (local -1 .. touristy +1),
landmark_calm_nightlife (calm -1 .. nightlife +1).
Use ONLY the provided data. Output STRICT JSON: {"axes": {"cityWealth": 0.3, ...}}
""";

  static const String _explainSystemPrompt = r"""
You write a short, friendly explanation of a traveler's result. The scores are already computed; do NOT recompute them.
Explain why the top type fits using ONLY the provided raw data (countries, cities, logs). Do not hallucinate.
If is_close is true, say the traveler is a blend of the top two types.
Do not mention formulas or statistics terms (distance, z-score, weights).
Output STRICT JSON: {"ai_explanation": "..."}
""";

  Future<String> _callDeepSeek(String systemPrompt, String userContent) async {
    final response = await http.post(
      Uri.parse(_deepSeekEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _deepSeekModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0,
        'stream': false,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('DeepSeek API error: ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final text = decoded['choices']?[0]?['message']?['content'] as String?;
    return text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
  }

  List<Map<String, dynamic>> _getRawCityVisitList(CityProvider cityProvider) {
    final List<Map<String, dynamic>> rawData = [];
    final homeCity = cityProvider.homeCityName;

    for (var entry in cityProvider.visitDetails.entries) {
      final detail = entry.value;
      final cityName = entry.key;

      if (cityName == homeCity || detail.hasLived) continue;

      final cityModel = cityProvider.getCityDetail(cityName);

      rawData.add({
        "name": cityName,
        "country_iso": cityModel?.countryIsoA2,
        "rating": detail.rating,
        "visit_count": detail.visitDateRanges.length,
        "arrival_date": detail.arrivalDate,
        "departure_date": detail.departureDate,
        "duration": detail.formattedStayDuration,
        "memo_length": detail.memo?.length ?? 0,
        "photos_count": detail.photos.length,
        "city_tourist_ratio": cityModel?.cityTouristRatio ?? 0.0,
      });
    }
    return rawData;
  }

  List<Map<String, dynamic>> _getRawTripLogList(TripLogProvider tripLogProvider) {
    final List<Map<String, dynamic>> rawData = [];

    for (var entry in tripLogProvider.entries) {
      final summary = entry.summary;

      if (summary == null) continue;

      rawData.add({
        "id": entry.id,
        "title": entry.title,
        "content_snippet": entry.content.substring(0, min(entry.content.length, 500)),
        // Fixed: Extract only names (Strings) from landmark objects to avoid "Instance of" issue
        "extracted_landmarks": summary.landmarks.map((l) => l.name).toList(),
        "cities_visited_in_log": summary.cities.map((c) => c.toMap()).toList(),
      });
    }

    return rawData;
  }

  Map<String, double> _getAllRatingsForAI(CountryProvider countryProvider, CityProvider cityProvider) {
    final Map<String, double> allRatings = {};

    countryProvider.visitDetails.forEach((name, detail) {
      if (detail.rating > 0.0) {
        allRatings['country:$name'] = detail.rating;
      }
    });

    cityProvider.visitDetails.forEach((name, detail) {
      if (detail.rating > 0.0) {
        allRatings['city:$name'] = detail.rating;
      }
    });

    return allRatings;
  }
}