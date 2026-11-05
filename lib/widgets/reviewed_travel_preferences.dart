import 'package:jidoapp/services/discover_copy.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/personality_provider.dart';
import 'package:jidoapp/services/discover_recommendation_runtime.dart';
import 'package:jidoapp/services/discover_recommender.dart';
import 'package:jidoapp/services/discover_user_profile.dart';

/// Live reviewed-place insights, separate from the calibrated ten-type score.
class ReviewedTravelPreferences extends StatefulWidget {
  const ReviewedTravelPreferences({super.key});
  @override
  State<ReviewedTravelPreferences> createState() =>
      _ReviewedTravelPreferencesState();
}

class _ReviewedTravelPreferencesState extends State<ReviewedTravelPreferences> {
  Future<Map<String, DiscoverResult>>? _future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final countries = context.watch<CountryProvider>();
    final cities = context.watch<CityProvider>();
    final landmarks = context.watch<LandmarksProvider>();
    final answers = Map<int, int>.from(
      context.watch<PersonalityProvider>().responses,
    );
    if (countries.isLoading || cities.isLoading || landmarks.isLoading) {
      _future = null;
      return;
    }
    _future = DiscoverRecommendationRuntime.load().then((model) {
      final profile = DiscoverUserProfile.capture(
        model,
        countries,
        cities,
        landmarks,
      );
      return {
        for (final kind in ['country', 'city', 'landmark'])
          kind: model.recommend(
            kind,
            profile.evidence[kind]!,
            answers,
            limit: 0,
          ),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    const domains = {
      'country': 'Countries',
      'city': 'Cities',
      'landmark': 'Landmarks',
    };
    const axes = {
      'nature_culture': 'Nature ↔ Culture',
      'natural_built': 'Nature ↔ Human-made',
      'historic_modern': 'Historic ↔ Modern',
      'activity': 'Viewing ↔ Participation',
      'cost': 'Lower cost ↔ Higher cost',
      'difficulty': 'Easy logistics ↔ More planning',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: FutureBuilder<Map<String, DiscoverResult>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                tr('Unable to load place preferences. Please try again.'),
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Your preferences from reviewed places'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Survey answers and visits contribute; ratings have more influence. Below 3 stars counts against a preference, above 3 supports it.',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'These live insights explain destination matching separately from your ten-type scores.',
                  ),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                for (final entry in snapshot.data!.entries) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${tr(domains[entry.key]!)} · ${entry.value.ratedCount}/5 ${tr('ratings')}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (!entry.value.hasEnoughRatings)
                    Text(
                      ratingPrompt(entry.key, entry.value.ratedCount),
                    )
                  else if (entry.value.preferences.isEmpty)
                    Text(tr('Not enough evaluated place information.'))
                  else
                    for (final axis in entry.value.preferences.entries)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(axes[axis.key] ?? axis.key),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: (axis.value + 1) / 2,
                              color: const Color(0xFF009688),
                              backgroundColor: const Color(0xFFE2E8F0),
                            ),
                          ],
                        ),
                      ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
