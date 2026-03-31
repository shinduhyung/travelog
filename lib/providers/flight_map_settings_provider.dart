// lib/providers/flight_map_settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FlightMapSettingsProvider with ChangeNotifier {
  // --- Firebase Instances ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // --------------------------

  // Default settings
  bool _useThicknessByFrequency = true;
  bool _showHubs = true;
  Color _routeColor1 = Colors.pink[300]!;
  Color _routeColor2 = Colors.purple[200]!;

  // Hidden individual flight log IDs
  Set<String> _hiddenLogIds = {};

  // Getters
  bool get useThicknessByFrequency => _useThicknessByFrequency;
  bool get showHubs => _showHubs;
  Color get routeColor1 => _routeColor1;
  Color get routeColor2 => _routeColor2;
  Set<String> get hiddenLogIds => _hiddenLogIds;

  FlightMapSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. Load from local SharedPreferences first (as a base/default)
    _useThicknessByFrequency = prefs.getBool('route_thickness_by_freq') ?? true;
    _showHubs = prefs.getBool('route_show_hubs') ?? true;

    final int? color1Val = prefs.getInt('route_color_1');
    if (color1Val != null) _routeColor1 = Color(color1Val);

    final int? color2Val = prefs.getInt('route_color_2');
    if (color2Val != null) _routeColor2 = Color(color2Val);

    final List<String>? hiddenList = prefs.getStringList('hidden_log_ids');
    if (hiddenList != null) {
      _hiddenLogIds = hiddenList.toSet();
    }

    // 2. Check server data if logged in (overwrite with server data if available)
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (data.containsKey('route_thickness_by_freq')) {
              _useThicknessByFrequency = data['route_thickness_by_freq'];
              await prefs.setBool('route_thickness_by_freq', _useThicknessByFrequency);
            }
            if (data.containsKey('route_show_hubs')) {
              _showHubs = data['route_show_hubs'];
              await prefs.setBool('route_show_hubs', _showHubs);
            }
            if (data.containsKey('route_color_1')) {
              _routeColor1 = Color(data['route_color_1']);
              await prefs.setInt('route_color_1', _routeColor1.value);
            }
            if (data.containsKey('route_color_2')) {
              _routeColor2 = Color(data['route_color_2']);
              await prefs.setInt('route_color_2', _routeColor2.value);
            }
            if (data.containsKey('hidden_log_ids')) {
              // Ensure data['hidden_log_ids'] is treated as a List<dynamic> and then converted
              _hiddenLogIds = Set<String>.from(data['hidden_log_ids'] as Iterable<dynamic>);
              await prefs.setStringList('hidden_log_ids', _hiddenLogIds.toList());
            }
          }
        } else {

        }
      } catch (e) {
        debugPrint("Failed to load map settings from server: $e");
      }
    }
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. Local save
    await prefs.setBool('route_thickness_by_freq', _useThicknessByFrequency);
    await prefs.setBool('route_show_hubs', _showHubs);
    await prefs.setInt('route_color_1', _routeColor1.value);
    await prefs.setInt('route_color_2', _routeColor2.value);
    await prefs.setStringList('hidden_log_ids', _hiddenLogIds.toList());

    // 2. Server save (if logged in)
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'route_thickness_by_freq': _useThicknessByFrequency,
          'route_show_hubs': _showHubs,
          'route_color_1': _routeColor1.value,
          'route_color_2': _routeColor2.value,
          'hidden_log_ids': _hiddenLogIds.toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Failed to save map settings to server: $e");
      }
    }
    notifyListeners();
  }

  // Setters
  void setThicknessByFrequency(bool value) {
    _useThicknessByFrequency = value;
    _saveSettings();
  }

  void setShowHubs(bool value) {
    _showHubs = value;
    _saveSettings();
  }

  void setRouteColor1(Color color) {
    _routeColor1 = color;
    _saveSettings();
  }

  void setRouteColor2(Color color) {
    _routeColor2 = color;
    _saveSettings();
  }

  // Toggle individual log visibility
  void toggleLogVisibility(String logId, bool isVisible) {
    if (isVisible) {
      _hiddenLogIds.remove(logId);
    } else {
      _hiddenLogIds.add(logId);
    }
    _saveSettings();
  }

  // Check if a specific log is hidden (required method)
  bool isLogHidden(String logId) {
    return _hiddenLogIds.contains(logId);
  }

  Future<void> resetSettings() async {
    _useThicknessByFrequency = true;
    _showHubs = true;
    _routeColor1 = Colors.pink[300]!;
    _routeColor2 = Colors.purple[200]!;
    _hiddenLogIds.clear();
    await _saveSettings();
  }
  // ─── 케이스 2: Firestore 데이터로 로컬 덮어씌우기 ──────────────────────
  // 로컬 데이터를 먼저 기본값으로 초기화 후 Firestore에서 새로 로드
  Future<void> reloadFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _auth.currentUser;

    // 1. 메모리 + 로컬 초기화 (기본값으로)
    _useThicknessByFrequency = true;
    _showHubs = true;
    _routeColor1 = Colors.pink[300]!;
    _routeColor2 = Colors.purple[200]!;
    _hiddenLogIds = {};
    await prefs.remove('route_thickness_by_freq');
    await prefs.remove('route_show_hubs');
    await prefs.remove('route_color_1');
    await prefs.remove('route_color_2');
    await prefs.remove('hidden_log_ids');

    // 2. Firestore에서 새로 로드
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data.containsKey('route_thickness_by_freq')) {
            _useThicknessByFrequency = data['route_thickness_by_freq'];
            await prefs.setBool('route_thickness_by_freq', _useThicknessByFrequency);
          }
          if (data.containsKey('route_show_hubs')) {
            _showHubs = data['route_show_hubs'];
            await prefs.setBool('route_show_hubs', _showHubs);
          }
          if (data.containsKey('route_color_1')) {
            _routeColor1 = Color(data['route_color_1']);
            await prefs.setInt('route_color_1', _routeColor1.value);
          }
          if (data.containsKey('route_color_2')) {
            _routeColor2 = Color(data['route_color_2']);
            await prefs.setInt('route_color_2', _routeColor2.value);
          }
          if (data.containsKey('hidden_log_ids')) {
            _hiddenLogIds = Set<String>.from(data['hidden_log_ids'] as Iterable<dynamic>);
            await prefs.setStringList('hidden_log_ids', _hiddenLogIds.toList());
          }
        }
      } catch (e) {
        debugPrint("Failed to reload map settings from server: $e");
      }
    }
    notifyListeners();
  }

  // ─── 케이스 1: 로컬 데이터를 Firestore로 업로드 ─────────────────────────
  Future<void> uploadLocalToFirestore() async {
    await _saveSettings();
  }

}