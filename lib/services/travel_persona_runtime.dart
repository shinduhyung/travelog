import 'dart:convert';
import 'package:flutter/services.dart';
import 'persona_runtime_model.dart';
export 'persona_runtime_model.dart';

/// Only public place profiles and fitted numeric parameters are bundled.
/// No Jev key or HTTP client is needed to analyze a user's recorded travel.
class TravelPersonaRuntime {
  TravelPersonaRuntime._();
  static Future<PersonaRuntimeModel>? _pending;

  static Future<PersonaRuntimeModel> load() => _pending ??= _load();

  static Future<PersonaRuntimeModel> _load() async {
    try {
      final texts = await Future.wait([
        rootBundle.loadString('assets/traveler_type/place_profiles.json'),
        rootBundle.loadString('assets/traveler_type/distribution_balance.json'),
        rootBundle.loadString('assets/traveler_type/landmark_eligibility.json'),
      ]);
      final places = jsonDecode(texts[0]) as Map<String,dynamic>;
      places['eligibility_policy'] = jsonDecode(texts[2]);
      return PersonaRuntimeModel(places,
          jsonDecode(texts[1]) as Map<String,dynamic>);
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }
}
