import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/providers/personality_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/services/travel_persona_engine.dart';
import 'package:jidoapp/services/traveler_type_store.dart';
import 'package:jidoapp/services/discover_recommendation_runtime.dart';
import 'package:jidoapp/services/discover_user_profile.dart';
import 'package:jidoapp/services/discover_copy.dart';
import 'package:jidoapp/widgets/discover_scaffold.dart';
import 'package:jidoapp/widgets/traveler_type_result.dart';

class TravelerTypeAiScreen extends StatefulWidget {
  const TravelerTypeAiScreen({super.key});
  @override
  State<TravelerTypeAiScreen> createState() => _TravelerTypeAiScreenState();
}

class _TravelerTypeAiScreenState extends State<TravelerTypeAiScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _parsed;
  String? _error;
  Future<DiscoverUserProfile>? _profile;

  @override
  void initState() {
    super.initState();
    _loadSavedAnalysis();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final countries = context.watch<CountryProvider>();
    final cities = context.watch<CityProvider>();
    final landmarks = context.watch<LandmarksProvider>();
    _profile = countries.isLoading || cities.isLoading || landmarks.isLoading
        ? null
        : DiscoverRecommendationRuntime.load().then(
            (model) => DiscoverUserProfile.capture(
              model,
              countries,
              cities,
              landmarks,
            ),
          );
  }

  Future<void> _loadSavedAnalysis() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        TravelerTypeStore.resultKey,
      );
      if (raw != null && TravelerTypeStore.isValid(raw) && mounted) {
        setState(() => _parsed = jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      /* A missing cache should never replace the empty state with a technical error. */
    }
  }

  Future<void> _runAnalysis() async {
    if (_isLoading || _profile == null) return;
    final profile = await _profile!;
    if (!mounted || _isLoading || profile.ratedCount < 5) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final raw = await TravelPersonaEngine().analyze(
        context.read<PersonalityProvider>(),
        context.read<CountryProvider>(),
        context.read<CityProvider>(),
        context.read<AirlineProvider>(),
        context.read<AirportProvider>(),
        context.read<TripLogProvider>(),
        landmarksProvider: context.read<LandmarksProvider>(),
        unescoProvider: context.read<UnescoProvider>(),
      );
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) setState(() => _parsed = parsed);
      if (parsed['summary']?['has_signal'] == false) {
        await TravelerTypeStore.clearResult();
      } else {
        await TravelerTypeStore.saveResult(raw);
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'We could not update your travel type. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DiscoverScaffold(
    appBar: AppBar(
      title: Text(tr('Traveler Type AI')),
      actions: [
        IconButton(
          onPressed: _isLoading ? null : _runAnalysis,
          tooltip: tr('Refresh my type'),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<DiscoverUserProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _empty(
            Icons.travel_explore_rounded,
            'Your travel story is waiting',
            'Please try again in a moment.',
            action: _runAnalysis,
          );
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.ratedCount < 5)
          return _empty(
            Icons.star_outline_rounded,
            'Let your travels tell your story',
            ratingPrompt('all', 0),
          );
        if (_parsed == null || _parsed!['summary']?['has_signal'] == false) {
          if (_isLoading)
            return const Center(child: CircularProgressIndicator());
          return _empty(
            Icons.fingerprint_rounded,
            'What kind of traveler are you?',
            _error ?? 'Discover the travel style that feels like you.',
            action: _runAnalysis,
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(tr(_error!)),
              ),
            TravelerTypeResult(analysis: _parsed!),
          ],
        );
      },
    ),
  );

  Widget _empty(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? action,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2EF),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, color: const Color(0xFF009688), size: 52),
          ),
          const SizedBox(height: 24),
          Text(
            tr(title),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(subtitle),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.5),
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: action,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(tr('Discover my type'), maxLines: 1),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
