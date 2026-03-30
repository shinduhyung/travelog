// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/providers/badge_provider.dart';
import 'package:jidoapp/providers/calendar_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/flight_map_settings_provider.dart';
import 'package:jidoapp/providers/itinerary_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/passport_provider.dart';
import 'package:jidoapp/providers/personality_provider.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/providers/visa_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/services/storage_service.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _useWhiteBorders = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode') ?? 'system';
    _useWhiteBorders = prefs.getBool('useWhiteBorders') ?? false;

    if (mounted) {
      setState(() {
        _themeMode = ThemeMode.values.firstWhere(
              (e) => e.toString().split('.').last == themeString,
          orElse: () => ThemeMode.system,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _setThemeMode(ThemeMode? themeMode) async {
    if (themeMode == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', themeMode.toString().split('.').last);
    if (mounted) {
      setState(() {
        _themeMode = themeMode;
      });
    }
  }

  Future<void> _setUseWhiteBorders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useWhiteBorders', value);
    if (mounted) {
      setState(() {
        _useWhiteBorders = value;
      });
    }
  }

  Future<void> _resetAllData(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Reset'),
          content: const Text(
              'Are you sure you want to reset all data? This will clear all your visited countries, cities, landmarks, trip logs, and other records. This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. SharedPreferences 초기화 (튜토리얼 버전은 유지)
      final prefs = await SharedPreferences.getInstance();
      final tutorialVersion = prefs.getString('onboarding_tutorial_version');
      await prefs.clear();
      if (tutorialVersion != null) {
        await prefs.setString('onboarding_tutorial_version', tutorialVersion);
      }

      // 2. SQLite(TripLog) 초기화
      await StorageService.instance.clearLocalDatabase();

      // 3. Firestore 유저 데이터 초기화 (로그인 상태인 경우)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final firestore = FirebaseFirestore.instance;
        final userDoc = firestore.collection('users').doc(user.uid);

        // 여행 데이터 필드 일괄 삭제
        await userDoc.update({
          'country_visits_v2': FieldValue.delete(),
          'city_visit_details_v3': FieldValue.delete(),
          'saved_custom_cities': FieldValue.delete(),
          'homeCityName': FieldValue.delete(),
          'homeCountryIsoA3': FieldValue.delete(),
          'useDefaultCityRankingBarColor': FieldValue.delete(),
          'useDefaultRankingBarColor': FieldValue.delete(),
          'includeTerritories': FieldValue.delete(),
          'airport_visit_history': FieldValue.delete(),
          'airport_ratings': FieldValue.delete(),
          'airport_hubs': FieldValue.delete(),
          'airport_favorites': FieldValue.delete(),
          'airport_memos': FieldValue.delete(),
          'airport_photos': FieldValue.delete(),
          'saved_airlines_data': FieldValue.delete(),
          'saved_itineraries_data': FieldValue.delete(),
          'saved_flight_connections': FieldValue.delete(),
          'visited_landmarks': FieldValue.delete(),
          'visited_landmark_sublocations': FieldValue.delete(),
          'wishlisted_landmarks': FieldValue.delete(),
          'landmark_ratings': FieldValue.delete(),
          'landmark_visit_history': FieldValue.delete(),
          'unesco_visited_sites': FieldValue.delete(),
          'unesco_wishlisted_sites': FieldValue.delete(),
          'unesco_sub_locations': FieldValue.delete(),
          'unesco_ratings': FieldValue.delete(),
          'unesco_history': FieldValue.delete(),
          'visited_subregions': FieldValue.delete(),
          'calendarMemos': FieldValue.delete(),
          'saved_itineraries': FieldValue.delete(),
          'route_thickness_by_freq': FieldValue.delete(),
          'route_show_hubs': FieldValue.delete(),
          'route_color_1': FieldValue.delete(),
          'route_color_2': FieldValue.delete(),
          'hidden_log_ids': FieldValue.delete(),
          'dna_responses': FieldValue.delete(),
          'dna_final_scores': FieldValue.delete(),
          'dna_is_calculated': FieldValue.delete(),
          'selectedPassportIso': FieldValue.delete(),
          'user_visas': FieldValue.delete(),
        });

        // badges subcollection 초기화
        await userDoc.collection('badges').doc('unlocked').delete();

        // trip_logs subcollection 초기화
        final tripLogs = await userDoc.collection('trip_logs').get();
        for (final doc in tripLogs.docs) {
          await doc.reference.delete();
        }
      }

      // 4. Provider 메모리 초기화 (각 Provider reloadFromServer 호출)
      if (context.mounted) {
        await Future.wait([
          context.read<CountryProvider>().reloadFromServer(),
          context.read<CityProvider>().reloadFromServer(),
          context.read<AirportProvider>().reloadFromServer(),
          context.read<AirlineProvider>().reloadFromServer(),
          context.read<LandmarksProvider>().reloadFromServer(),
          context.read<UnescoProvider>().reloadFromServer(),
          context.read<SubregionProvider>().reloadFromServer(),
          context.read<CalendarProvider>().reloadFromServer(),
          context.read<ItineraryProvider>().reloadFromServer(),
          context.read<FlightMapSettingsProvider>().reloadFromServer(),
          context.read<PersonalityProvider>().reloadFromServer(),
          context.read<PassportProvider>().reloadFromServer(),
          context.read<VisaProvider>().reloadFromServer(),
          context.read<TripLogProvider>().reloadFromServer(),
          context.read<BadgeProvider>().reloadFromServer(),
        ]);
      }
    } catch (e) {
      debugPrint('❌ Reset error: \$e');
    }

    // 로딩 닫기
    if (context.mounted) Navigator.of(context).pop();

    // 완료 안내
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Reset Complete'),
          content: const Text('All data has been reset.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access Providers
    final countryProvider = Provider.of<CountryProvider>(context);
    final cityProvider = Provider.of<CityProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Title replacement for AppBar
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            // Theme Settings
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme'),
              trailing: DropdownButton<ThemeMode>(
                value: _themeMode,
                onChanged: _setThemeMode,
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System Default'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Include Territories Switch
            SwitchListTile(
              secondary: const Icon(Icons.public_off_outlined),
              title: const Text('Include Territories'),
              subtitle: const Text('Include territories in all statistics'),
              value: countryProvider.includeTerritories,
              onChanged: (bool value) {
                countryProvider.toggleIncludeTerritories();
              },
            ),
            const Divider(),

            // Border Color Settings
            SwitchListTile(
              secondary: const Icon(Icons.border_color_outlined),
              title: const Text('Use White Borders'),
              subtitle: const Text(
                  'Use white borders instead of dark borders for country boundaries'),
              value: _useWhiteBorders,
              onChanged: _setUseWhiteBorders,
            ),
            const Divider(),

            // Country Ranking Bar Color Settings
            SwitchListTile(
              secondary: const Icon(Icons.color_lens_outlined),
              title: const Text('Use Default Country Ranking Bar Color'),
              subtitle: const Text(
                  'Use a single primary color for all country ranking bars instead of continent-specific colors.'),
              value: countryProvider.useDefaultRankingBarColor,
              onChanged: (bool value) {
                countryProvider.setUseDefaultRankingBarColor(value);
              },
            ),
            const Divider(),

            // City Ranking Bar Color Settings
            SwitchListTile(
              secondary: const Icon(Icons.location_city_outlined),
              title: const Text('Use Default City Ranking Bar Color'),
              subtitle: const Text(
                  'Use a single primary color for all city ranking bars instead of continent-specific colors.'),
              value: cityProvider.useDefaultCityRankingBarColor,
              onChanged: (bool value) {
                cityProvider.setUseDefaultCityRankingBarColor(value);
              },
            ),
            const Divider(),

            // Reset All Data
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded,
                  color: Colors.red),
              title: const Text('Reset All Data'),
              subtitle: const Text(
                  'Deletes all visited records, logs, and settings.'),
              onTap: () => _resetAllData(context),
            ),
          ],
        ),
      ),
    );
  }
}