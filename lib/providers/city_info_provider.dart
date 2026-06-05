// lib/providers/city_info_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/models/city_info_model.dart';

class CityInfoProvider with ChangeNotifier {
  Map<String, CityInfo> _cityInfoMap = {};
  bool _isLoading = true;

  Map<String, CityInfo> get cityInfoMap => _cityInfoMap;
  bool get isLoading => _isLoading;

  CityInfoProvider() {
    _loadCityInfo();
  }

  Future<void> _loadCityInfo() async {
    try {
      final String jsonString =
      await rootBundle.loadString('assets/city_info.json');
      final Map<String, dynamic> decoded = json.decode(jsonString);
      _cityInfoMap = decoded.map(
            (key, value) =>
            MapEntry(key, CityInfo.fromJson(value as Map<String, dynamic>)),
      );
    } catch (e) {
      debugPrint('Error loading city_info.json: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Look up by city name — converts to snake_case key automatically.
  /// e.g. "New York" → "new_york", "São Paulo" → "so_paulo"
  CityInfo? getByName(String cityName) {
    final key = _toKey(cityName);
    return _cityInfoMap[key];
  }

  String _toKey(String name) => name.toLowerCase().trim();
}