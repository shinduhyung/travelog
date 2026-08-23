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

    final fullFeatureVector = {
      ...dnaNormalized,
      "continentDistribution": calculatedFeatures.continentDistribution,
      "countryDistribution": calculatedFeatures.countryDistribution,
      "cityDistribution": calculatedFeatures.cityDistribution,
      "airportDistribution": calculatedFeatures.airportDistribution,
      "airlineDistribution": calculatedFeatures.airlineDistribution,
      "countryWealth": calculatedFeatures.countryWealth,
      "countryType": calculatedFeatures.countryType,
      "countryNightlife": calculatedFeatures.countryNightlife,
      "cityWealth": 0.0,
      "cityType": 0.0,
      "cityNightlife": 0.0,
      "airlineTime": calculatedFeatures.airlineTime,
      "transferAirportScore": calculatedFeatures.transferAirportScore,
      "transferFlightScore": calculatedFeatures.transferFlightScore,
      "landmark_culture_nature": 0.0,
      "landmark_ancient_modern": 0.0,
      "landmark_urban_rural": 0.0,
      "landmark_adventure_relax": 0.0,
      "landmark_art_science": 0.0,
      "landmark_spiritual_secular": 0.0,
      "landmark_crowd": 0.0,
      "landmark_budget_luxury": 0.0,
      "landmark_local_tourist": 0.0,
      "landmark_calm_nightlife": 0.0,
    };

    final rawCityVisitData = _getRawCityVisitList(cityProvider);
    final rawTripLogs = _getRawTripLogList(tripLogProvider);

    final inputPayload = {
      "full_feature_vector": fullFeatureVector,
      "raw_data_for_AI_scoring": {
        "visited_cities": rawCityVisitData,
        "trip_logs": rawTripLogs,
        "user_rating_distribution": _getAllRatingsForAI(countryProvider, cityProvider),
      },
      "meta_data": {
        "total_countries": countryProvider.visitedCountries.length,
        "total_cities": cityProvider.visitedCities.length,
        "total_flights": airlineProvider.allFlightLogs.length,
      },
      "archetype_prototypes": jsonDecode(_archetypePrototypesJson),
    };

    final systemPrompt = r'''
You are **TravelPersonaEngine**. Your task is to provide the final travel persona analysis using a **Distance-Based Match Scoring** model.

**[I. Pre-Calculations]**
1. **Calculate Missing Axes**: You must analyze the 'raw_data_for_AI_scoring' to calculate the 3 City Trait axes and 10 Landmark Trait axes. Apply the rating-based Z-Score weighting. If data is missing or results in NaN, use 0.0.
2. **Final Vector Assembly**: Use these 13 newly calculated axes to overwrite the 0.0 placeholder values in the 'full_feature_vector'.

**[II. Archetype Scoring (Distance Model)]**
You must calculate the score for each of the 10 Archetypes using the following distance formula. 
The sum of weights ($W$) for each archetype is standardized to **40**.

**Formula:**
$$ D = \sum_{i=1}^{33} W_i \cdot |U_i - P_i| $$
$$ Score (\%) = 100 \times (1 - \frac{D}{80}) $$

* $U_i$: User's value for axis $i$ (-1.0 to 1.0)
* $P_i$: Archetype's prototype value for axis $i$ (-1.0 to 1.0)
* $W_i$: Importance weight of axis $i$ (0, 1, 2, 3)
* Max possible distance $D_{max} = 80$ (Since $\sum W = 40$ and max diff $|U-P|=2$).

**[III. Output: Rationale & Structure]**
1. **Rationale Generation**: Generate a detailed, user-friendly explanation in 'ai_explanation'.
    * **Rule 1**: Use ONLY the provided raw data (countries, cities, logs). **DO NOT hallucinate.**
    * **Rule 2**: Explain *why* the top type fits based on the user's traits/data.
    * **Rule 3**: **DO NOT mention any mathematical formulas or terms** (e.g., "Distance D", "Z-Score", "P value"). Keep it natural.
2. **Type Descriptions**: Do NOT generate `description_ko` or `description_en`.

Output STRICT JSON structure (MUST contain 'debug_info' field):

{
  "full_feature_vector": { ... },
  "summary": {
    "ai_explanation": "...", 
    "persona_scores": [
      {"id": "...", "label": "...", "score": 0.0}, // score is 0.0 to 1.0 (e.g., 0.87 for 87%)
      ...
    ],
    "debug_info": "Success"
  }
}
''';

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
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': jsonEncode(inputPayload)},
          ],
          // 시스템 프롬프트가 이미 "STRICT JSON"을 요구하므로 JSON 모드를 강제해서
          // 마크다운 코드펜스 없이 순수 JSON만 반환하도록 함
          'response_format': {'type': 'json_object'},
          'stream': false,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('DeepSeek API error: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final text = decoded['choices']?[0]?['message']?['content'] as String?;
      return text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
    } catch (e) {
      final debugResponse = {
        "full_feature_vector": fullFeatureVector,
        "summary": {
          "ai_explanation": "AI analysis failed due to communication error: ${e.toString()}",
          "persona_scores": [],
          "debug_info": "Communication Failure: ${e.toString()}"
        }
      };
      return jsonEncode(debugResponse);
    }
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