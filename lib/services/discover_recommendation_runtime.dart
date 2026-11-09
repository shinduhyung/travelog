import 'dart:convert';
import 'package:flutter/services.dart';
import 'discover_recommender.dart';

class DiscoverRecommendationRuntime {
  static Future<DiscoverRecommender>? _pending;
  static Future<DiscoverRecommender> load() => _pending ??= _load();
  static Future<DiscoverRecommender> _load() async {
    try {
      return DiscoverRecommender(
        jsonDecode(
              await rootBundle.loadString(
                'assets/traveler_type/discover_profiles.json',
              ),
            )
            as Map<String, dynamic>,
      );
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }
}
