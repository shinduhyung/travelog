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
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/services/storage_service.dart';

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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final tutorialVersion = prefs.getString('onboarding_tutorial_version');
      await prefs.clear();
      if (tutorialVersion != null) {
        await prefs.setString('onboarding_tutorial_version', tutorialVersion);
      }

      await StorageService.instance.clearLocalDatabase();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final firestore = FirebaseFirestore.instance;
        final userDoc = firestore.collection('users').doc(user.uid);

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

        await userDoc.collection('badges').doc('unlocked').delete();

        final tripLogs = await userDoc.collection('trip_logs').get();
        for (final doc in tripLogs.docs) {
          await doc.reference.delete();
        }
      }

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
      debugPrint('Reset error: $e');
    }

    if (context.mounted) Navigator.of(context).pop();

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
    final countryProvider = Provider.of<CountryProvider>(context);
    final cityProvider = Provider.of<CityProvider>(context);

    // Settings is always accessible regardless of login state
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
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

            // ── Premium / Remove Ads ──────────────────────────
            Consumer<SubscriptionService>(
              builder: (context, sub, _) => GestureDetector(
                onTap: () => SubscriptionSheet.show(context),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3DDAD7), Color(0xFF00A39F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3DDAD7).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub.isPremium
                                  ? 'Premium Active'
                                  : 'Remove Ads',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              sub.isPremium
                                  ? 'You are subscribed. Thank you!'
                                  : sub.productDetails != null
                                  ? 'Go ad-free for ${sub.productDetails!.price} / year'
                                  : 'Go ad-free',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        sub.isPremium
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: sub.isPremium ? 22 : 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Theme ─────────────────────────────────────────
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

            SwitchListTile(
              secondary: const Icon(Icons.public_off_outlined),
              title: const Text('Include Territories'),
              subtitle:
              const Text('Include territories in all statistics'),
              value: countryProvider.includeTerritories,
              onChanged: (bool value) {
                countryProvider.toggleIncludeTerritories();
              },
            ),
            const Divider(),

            SwitchListTile(
              secondary: const Icon(Icons.border_color_outlined),
              title: const Text('Use White Borders'),
              subtitle: const Text(
                  'Use white borders instead of dark borders for country boundaries'),
              value: _useWhiteBorders,
              onChanged: _setUseWhiteBorders,
            ),
            const Divider(),

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