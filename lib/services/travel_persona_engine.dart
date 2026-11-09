// lib/services/travel_persona_engine.dart

import 'dart:convert';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/services/travel_persona_runtime.dart';
import 'package:jidoapp/services/persona_scorer.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/services/traveler_type_store.dart';
import 'package:jidoapp/services/travel_quantifier.dart';

import 'package:jidoapp/providers/personality_provider.dart';

class TravelPersonaEngine {
  TravelPersonaEngine._internal();

  static final TravelPersonaEngine _instance = TravelPersonaEngine._internal();

  factory TravelPersonaEngine() => _instance;

  // DNA signs follow PersonalityProvider: +planned, +documenter, +relaxed.
  static const String _archetypePrototypesJson = r'''
[
  {
    "id": "identity_seeker",
    "label": "Identity Seeker",
    "data": {
      "solo_social": {"P": 1.0, "W": 3}, "nature_culture": {"P": 0.2, "W": 2}, "relaxed_intensive": {"P": -0.6, "W": 2}, "planned_spontaneous": {"P": -0.4, "W": 1}, "budget_luxury": {"P": 0.3, "W": 1}, "transit_drive": {"P": 0.4, "W": 1}, "documenter_minimalist": {"P": 0.5, "W": 2}, "morning_night": {"P": 0.6, "W": 1},
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
      "solo_social": {"P": 0.7, "W": 2}, "nature_culture": {"P": 1.0, "W": 3}, "relaxed_intensive": {"P": 0.4, "W": 1}, "planned_spontaneous": {"P": -0.2, "W": 2}, "budget_luxury": {"P": 0.5, "W": 2}, "transit_drive": {"P": -0.8, "W": 2}, "documenter_minimalist": {"P": -0.2, "W": 1}, "morning_night": {"P": 0.9, "W": 2},
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
      "solo_social": {"P": -0.2, "W": 2}, "nature_culture": {"P": -1.0, "W": 3}, "relaxed_intensive": {"P": -0.3, "W": 1}, "planned_spontaneous": {"P": 0.4, "W": 1}, "budget_luxury": {"P": -0.6, "W": 2}, "transit_drive": {"P": 0.8, "W": 2}, "documenter_minimalist": {"P": 0.8, "W": 2}, "morning_night": {"P": -0.3, "W": 2},
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
      "solo_social": {"P": -0.9, "W": 3}, "nature_culture": {"P": 0.0, "W": 1}, "relaxed_intensive": {"P": 0.6, "W": 2}, "planned_spontaneous": {"P": -0.9, "W": 3}, "budget_luxury": {"P": 1.0, "W": 3}, "transit_drive": {"P": 0.9, "W": 2}, "documenter_minimalist": {"P": 0.4, "W": 1}, "morning_night": {"P": -0.8, "W": 2},
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
      "solo_social": {"P": -0.5, "W": 2}, "nature_culture": {"P": -0.3, "W": 2}, "relaxed_intensive": {"P": -1.0, "W": 3}, "planned_spontaneous": {"P": 0.6, "W": 2}, "budget_luxury": {"P": -1.0, "W": 3}, "transit_drive": {"P": -0.5, "W": 2}, "documenter_minimalist": {"P": -0.6, "W": 1}, "morning_night": {"P": 0.0, "W": 0},
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
      "solo_social": {"P": 0.5, "W": 3}, "nature_culture": {"P": 0.0, "W": 2}, "relaxed_intensive": {"P": -1.0, "W": 3}, "planned_spontaneous": {"P": 0.8, "W": 3}, "budget_luxury": {"P": 0.0, "W": 2}, "transit_drive": {"P": 0.6, "W": 2}, "documenter_minimalist": {"P": 1.0, "W": 2}, "morning_night": {"P": 0.7, "W": 1},
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
      "solo_social": {"P": -1.0, "W": 3}, "nature_culture": {"P": -0.5, "W": 1}, "relaxed_intensive": {"P": -1.0, "W": 3}, "planned_spontaneous": {"P": 1.0, "W": 3}, "budget_luxury": {"P": -0.4, "W": 2}, "transit_drive": {"P": -0.7, "W": 2}, "documenter_minimalist": {"P": 0.2, "W": 1}, "morning_night": {"P": 0.5, "W": 1},
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
      "solo_social": {"P": 0.0, "W": 2}, "nature_culture": {"P": 0.8, "W": 2}, "relaxed_intensive": {"P": 0.9, "W": 3}, "planned_spontaneous": {"P": -0.5, "W": 3}, "budget_luxury": {"P": 0.2, "W": 2}, "transit_drive": {"P": -0.3, "W": 2}, "documenter_minimalist": {"P": -0.8, "W": 2}, "morning_night": {"P": 0.4, "W": 1},
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
      "solo_social": {"P": -0.4, "W": 2}, "nature_culture": {"P": -0.2, "W": 2}, "relaxed_intensive": {"P": 0.9, "W": 3}, "planned_spontaneous": {"P": -0.7, "W": 2}, "budget_luxury": {"P": 0.4, "W": 1}, "transit_drive": {"P": 0.5, "W": 1}, "documenter_minimalist": {"P": -0.9, "W": 2}, "morning_night": {"P": 0.0, "W": 2},
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
      "solo_social": {"P": 0.8, "W": 2}, "nature_culture": {"P": -0.6, "W": 2}, "relaxed_intensive": {"P": -0.5, "W": 2}, "planned_spontaneous": {"P": -1.0, "W": 3}, "budget_luxury": {"P": 0.4, "W": 2}, "transit_drive": {"P": 0.7, "W": 2}, "documenter_minimalist": {"P": -0.5, "W": 2}, "morning_night": {"P": -0.4, "W": 2},
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
      TripLogProvider tripLogProvider, {
        required LandmarksProvider landmarksProvider,
        required UnescoProvider unescoProvider,
      }) async {
    if (countryProvider.isLoading || cityProvider.isLoading || airlineProvider.isLoading ||
        airportProvider.isLoading || landmarksProvider.isLoading || unescoProvider.isLoading) {
      throw StateError('Your travel records are still loading. Please try again shortly.');
    }

    // Only consume a completed, unlocked quiz. Analysis must never unlock
    // the survey result as a side effect or bypass its rewarded-video flow.
    final dnaScores = personalityProvider.isCalculated && personalityProvider.responses.isNotEmpty
        ? personalityProvider.finalScores : <String, double>{};

    Map<String, double> dnaNormalized = {};
    for (final entry in dnaScores.entries) {
      final v = entry.value;
      if (!v.isFinite) continue;
      dnaNormalized[entry.key] = ((v - 50.0) / 50.0).clamp(-1.0, 1.0);
    }

    final quantifier = TravelQuantifier(
      countryProvider: countryProvider,
      cityProvider: cityProvider,
      airlineProvider: airlineProvider,
      airportProvider: airportProvider,
    );

    final calculatedFeatures = quantifier.quantify();
    final observedTravelAxes = quantifier.observedAxes;

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
    fullFeatureVector.removeWhere((key, value) =>
        !dnaNormalized.containsKey(key) && !observedTravelAxes.contains(key));

    final runtime = await TravelPersonaRuntime.load();
    final landmarkRatings = {for (final place in landmarksProvider.allLandmarks) place.name: place};
    final heritageRatings = {for (final place in unescoProvider.allSites) place.name: place};
    final cities = [
      for (final entry in cityProvider.visitDetails.entries)
        PersonaCityEvidence(entry.key, visits: entry.value.visitDateRanges.length,
          rating: entry.value.rating, hasLived: entry.value.hasLived,
          isHome: entry.key == cityProvider.homeCityName),
    ];
    final landmarks = [
      for (final name in landmarksProvider.visitedLandmarks)
        PersonaLandmarkEvidence(name, rating: landmarkRatings[name]?.rating ?? 0,
          attributes: landmarkRatings[name]?.attributes ?? const []),
      for (final name in unescoProvider.visitedSites)
        PersonaLandmarkEvidence(name, source: 'unesco', rating: heritageRatings[name]?.rating ?? 0,
          heritageType: heritageRatings[name]?.type),
    ];
    final prototypes = jsonDecode(_archetypePrototypesJson) as List<dynamic>;
    final scored = runtime.score(prototypes,
        fullFeatureVector, cities, landmarks);
    final result = scored.result;
    final cityCount = scored.places.evidence['cities_used'] ?? 0;
    final landmarkCount = scored.places.evidence['landmark_matched'] ?? 0;
    final explanation = result.hasSignal
        ? 'Your quiz preferences and recorded travel are compared across all ten traveler types. '
          '$cityCount recorded cities and $landmarkCount recorded attractions were matched to place profiles. '
          'Your leading match is ${result.scores.first.label}.'
        : 'Add quiz answers or travel records to discover your traveler type.';
    return jsonEncode({
      'engine_version': TravelerTypeStore.currentVersion,
      'generated_at': DateTime.now().millisecondsSinceEpoch,
      'scoring_method': 'cached_jev_places_balanced_v1',
      'full_feature_vector': scored.features,
      'summary': {
        'top_type_matches': result.hasSignal
            ? PersonaScorer.matchingAxes(
                prototypes.firstWhere((p) => p['id'] == result.scores.first.id)
                    as Map<String, dynamic>, dnaNormalized)
            : <String>[],
        'ai_explanation': explanation,
        'persona_scores': [for (final s in result.scores) {'id': s.id, 'label': s.label, 'score': s.score}],
        'raw_persona_scores': [for (final s in scored.raw.scores) {'id': s.id, 'label': s.label, 'score': s.score}],
        'distribution_balanced': scored.balanceApplied,
        'is_close': result.isClose,
        'low_data': result.lowData,
        'has_signal': result.hasSignal,
        'score_gap': result.gap,
        'data_coverage': result.coverage,
        'place_evidence': scored.places.evidence,
        'debug_info': 'Local place profiles and fixed distribution reference',
      },
    });
  }
}
