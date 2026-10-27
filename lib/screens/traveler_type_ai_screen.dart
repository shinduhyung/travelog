// lib/screens/traveler_type_ai_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jidoapp/providers/personality_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/services/travel_persona_engine.dart';
import 'package:jidoapp/services/traveler_type_store.dart';

class TravelerTypeAiScreen extends StatefulWidget {
  const TravelerTypeAiScreen({super.key});

  @override
  State<TravelerTypeAiScreen> createState() => _TravelerTypeAiScreenState();
}

class _TravelerTypeAiScreenState extends State<TravelerTypeAiScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _parsed;
  String? _error;

  static const Color mint = Color(0xFF00CDB5);
  static const Color darkMint = Color(0xFF00A99D);
  static const Color purple = Color(0xFF8B5CF6);

  static const Map<String, String> _staticDescriptions = {
    'Identity Seeker': 'Travel focused on self-reflection, meaning, and personal growth. They often keep detailed journals or logs of their inner journey.',
    'Sensory Immersionist': 'Prefers slow, relaxed travel, focusing on atmosphere, local views, smells, and sounds. They seek sensory experience over packed schedules.',
    'Efficiency Maximizer': 'Driven to see and do as much as possible in limited time. Highly organized, planning routes, and utilizing checklists to maximize output.',
    'Cultural Decoder': 'Travels with a deep interest in history, context, and politics. They prioritize museums, ancient sites, and understanding local culture deeply.',
    'Joy Collector': 'Focused on fun, enjoyment, and memorable experiences. They enjoy socializing, nightlife, cafes, and collecting moments of pure delight.',
    'Inner Sanctuary Seeker': 'Seeks healing, quiet, and retreat. Prefers peaceful natural settings, beaches, or small towns for wellness and recharging.',
    'Wildlife & Earth Enthusiast': 'Primary motivation is experiencing nature, wildlife, landscapes, national parks, and ecological sites. They love hiking and outdoor exploration.',
    'Global Connector': 'Motivated by meeting new people, connecting with locals, and forming international friendships. They are flexible and prioritize social interactions.',
    'Freedom Drifter': 'Long-term, open-ended travel with maximum spontaneity. They avoid strict schedules and enjoy the simple, unpredictable nature of drifting.',
    'Achievement Hunter': 'Focuses on quantifiable goals like country counts, UNESCO sites visited, or completing specific challenges. They value stats and trophies over relaxation.',
  };

  @override
  void initState() {
    super.initState();
    _loadSavedAnalysis();
  }

  // Returns true only if the parsed result actually contains usable persona scores.
  bool _hasValidScores(Map<String, dynamic> parsed) {
    final scores = (parsed['summary']?['persona_scores'] as List?) ?? [];
    return scores.isNotEmpty;
  }

  Future<void> _loadSavedAnalysis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('ai_analysis_result');
      if (savedJson != null) {
        final parsed = jsonDecode(savedJson) as Map<String, dynamic>;

        if (_hasValidScores(parsed) && TravelerTypeStore.isValid(savedJson)) {
          if (mounted) {
            setState(() {
              _parsed = parsed;
            });
          }
        } else {
          // Stale/failed cache from a previous run — discard it so the user
          // sees the "not yet analyzed" placeholder instead of an error.
          await prefs.remove('ai_analysis_result');
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Error loading: $e'; });
    }
  }

  Future<void> _runAnalysis() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _parsed = null;
    });

    final personalityProvider = Provider.of<PersonalityProvider>(context, listen: false);
    final countryProvider = Provider.of<CountryProvider>(context, listen: false);
    final cityProvider = Provider.of<CityProvider>(context, listen: false);
    final airlineProvider = Provider.of<AirlineProvider>(context, listen: false);
    final airportProvider = Provider.of<AirportProvider>(context, listen: false);
    final tripLogProvider = Provider.of<TripLogProvider>(context, listen: false);

    try {
      final result = await TravelPersonaEngine().analyze(
        personalityProvider,
        countryProvider,
        cityProvider,
        airlineProvider,
        airportProvider,
        tripLogProvider,
      );

      final parsed = jsonDecode(result) as Map<String, dynamic>;

      // Only persist to cache when the analysis actually produced scores.
      // A failed/errored result must not overwrite a previously good cache
      // (or get treated as "successful" on the next app launch).
      if (mounted) {
        setState(() {
          _parsed = parsed;
          _isLoading = false;
        });
      }

      // 로컬 저장 + Firestore 저장. 서버 저장이 실패해도 로컬에는 남고,
      // 다음 앱 시작/로그인 때 TravelerTypeStore.sync가 다시 올린다.
      if (parsed['summary']?['has_signal'] == false) {
        await TravelerTypeStore.clearResult();
      } else if (_hasValidScores(parsed)) {
        await TravelerTypeStore.saveResult(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Analysis failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildDimensionsSection(Map<String, dynamic> data) {
    final featureVector =
    (data['full_feature_vector'] as Map<String, dynamic>? ?? {}).cast<String, double>();

    final List<String> dnaKeys = [
      'solo_social', 'nature_culture', 'relaxed_intensive',
      'planned_spontaneous', 'budget_luxury', 'transit_drive',
      'documenter_minimalist', 'morning_night'
    ];

    final Map<String, double> dimensions = {};
    for (var key in dnaKeys) {
      if (featureVector.containsKey(key)) {
        dimensions[key] = featureVector[key]!;
      }
    }

    final provider = Provider.of<PersonalityProvider>(context, listen: false);
    final sortedKeys = dimensions.keys.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Your 8 Personality Dimensions'),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          ...sortedKeys.map((key) {
            final value = dimensions[key] ?? 0.0;
            final percent = ((value + 1.0) / 2.0).clamp(0.0, 1.0);
            final leftLabel = provider.getLeftLabel(key);
            final rightLabel = provider.getRightLabel(key);
            final color = Color.lerp(purple, darkMint, percent);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr(leftLabel),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600),
                      ),
                      Text(
                        tr(rightLabel),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color!),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(tr(_error!), style: const TextStyle(color: Colors.red)),
          ));
    }

    if (_parsed != null) {
      final types = (_parsed!['summary']?['persona_scores'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>() ?? [];
      final summary = _parsed!['summary'] as Map<String, dynamic>?;
      if (summary?['has_signal'] == false) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text(tr('Add quiz answers or travel records to discover your traveler type.')),
        );
      }

      if (types.isEmpty) {
        final debugInfo = summary?['debug_info'] as String? ?? 'Unknown error in scoring process.';
        return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                tr('Analysis failed to generate scores.\nDebug Info: $debugInfo'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ));
      }

      final List<Map<String, dynamic>> sortedTypes = List<Map<String, dynamic>>.from(types)
        ..sort((a, b) {
          final scoreA = (a['score'] as num?)?.toDouble() ?? 0.0;
          final scoreB = (b['score'] as num?)?.toDouble() ?? 0.0;
          return scoreB.compareTo(scoreA);
        });

      final topType = sortedTypes.first;
      final aiExplanation = summary?['ai_explanation'] as String? ?? 'Analysis rationale not available.';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDimensionsSection(_parsed!),
          const SizedBox(height: 24),

          Text(
            tr('Traveler Type Scores'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade900),
          ),
          const SizedBox(height: 12),
          Text(tr('Relative scores across the 10 traveler types; not probabilities.')),
          if (summary?['low_data'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('This result is provisional. Add more quiz answers or travel records.')),
            ),
          if (summary?['is_close'] == true && sortedTypes.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${tr('Blended type')}: ${tr(sortedTypes[0]['label'] as String)} + ${tr(sortedTypes[1]['label'] as String)}'),
            ),
          const SizedBox(height: 12),

          ...sortedTypes.asMap().entries.map((entry) {
            final t = entry.value;
            final adjustedScore = (t['score'] as num).toDouble() * 100;

            final label = t['label'] ?? t['id'] ?? '';
            final isTopType = t['id'] == topType['id'];
            final desc = _staticDescriptions[label] ?? 'General description unavailable.';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isTopType ? mint.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isTopType ? darkMint : Colors.grey.shade200,
                      width: isTopType ? 1.5 : 1.0),
                  boxShadow: [
                    if (isTopType)
                      BoxShadow(
                          color: darkMint.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr(label),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isTopType ? darkMint : Colors.black87,
                          ),
                        ),
                        Text(
                          tr('${adjustedScore.toStringAsFixed(1)}%'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isTopType ? darkMint : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (isTopType) ...[
                      Text(
                        tr(desc),
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                      ),
                      const Divider(height: 24),
                       Text(
                        tr('Analysis based on your travel data:'),
                        style: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(aiExplanation),
                        style: TextStyle(fontSize: 15, height: 1.4, color: Colors.grey.shade800),
                      ),
                    ] else ...[
                      Text(
                        tr(desc),
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 40),
        ],
      );
    }

    return  Center(
      child: Text(
        tr('Press "Run AI Analysis" to calculate your Traveler Type.'),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    String buttonText = 'Run AI Analysis';
    if (_isLoading) {
      buttonText = 'Analyzing...';
    } else if (_parsed != null) {
      buttonText = 'Rerun AI Analysis';
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 24,
          left: 24,
          right: 24,
          bottom: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _runAnalysis,
              icon: Icon(Icons.psychology_alt,
                  color: _isLoading ? Colors.white70 : Colors.white),
              label: Text(
                tr(buttonText),
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
            const SizedBox(height: 24),
            _buildBody(),
          ],
        ),
      ),
    );
  }
}
