import 'package:jidoapp/services/discover_copy.dart';
import 'package:jidoapp/widgets/discover_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:country_flags/country_flags.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/personality_provider.dart';
import 'package:jidoapp/services/discover_recommender.dart';
import 'package:jidoapp/services/discover_recommendation_runtime.dart';
import 'package:jidoapp/services/discover_user_profile.dart';
import 'package:jidoapp/widgets/city_tour_navigation.dart';
import 'country_detail_screen.dart';

class DiscoverMatchScreen extends StatefulWidget {
  final String kind;
  const DiscoverMatchScreen({super.key, required this.kind});
  @override
  State<DiscoverMatchScreen> createState() => _DiscoverMatchScreenState();
}

class _DiscoverMatchScreenState extends State<DiscoverMatchScreen> {
  Future<DiscoverResult>? _future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final countries = context.watch<CountryProvider>();
    final cities = context.watch<CityProvider>();
    final landmarks = context.watch<LandmarksProvider>();
    final responses = Map<int, int>.from(
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
      return profile.recommend(
        model,
        widget.kind,
        responses,
        includeVisited: true,
        applyPopularity: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final title = widget.kind == 'country'
        ? 'Your Country Twin'
        : 'Your Soul City';
    return DiscoverScaffold(
      appBar: AppBar(title: Text(tr(title))),
      body: FutureBuilder<DiscoverResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Text(
                tr('Unable to load recommendations. Please try again.'),
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final result = snapshot.data!;
          if (!result.hasEnoughRatings)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  ratingPrompt(widget.kind, result.ratedCount),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          if (result.matches.isEmpty)
            return Center(child: Text(tr('No matches yet.')));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (var i = 0; i < result.matches.length; i++)
                _matchCard(context, result.matches[i], result.preferences, i),
            ],
          );
        },
      ),
    );
  }

  Widget _tag(String text, bool hero) => Chip(
    color: WidgetStatePropertyAll(
      hero ? const Color(0xFF5B21B6) : Colors.white,
    ),
    side: BorderSide.none,
    label: Text(
      tr(text),
      style: TextStyle(
        color: hero ? Colors.white : const Color(0xFF6D28D9),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _matchCard(
    BuildContext context,
    DiscoverMatch match,
    Map<String, double> preferences,
    int index,
  ) {
    final color = widget.kind == 'country'
        ? const Color(0xFF009688)
        : const Color(0xFF8B5CF6);
    final hero = index == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(hero ? 28 : 22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hero
              ? const [Color(0xFF4C1D95), Color(0xFF8B5CF6)]
              : const [Color(0xFFF5F0FF), Color(0xFFEDE9FE)],
        ),
        boxShadow: hero
            ? [
                BoxShadow(
                  color: color.withValues(alpha: .2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(hero ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hero) ...[
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFDDD6FE),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('YOUR SOUL CITY'),
                      style: const TextStyle(
                        color: Color(0xFFDDD6FE),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.location_city_rounded,
                    color: Color(0xFFC4B5FD),
                    size: 40,
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
            Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 26,
                  child: CountryFlag.fromCountryCode(match.place.country),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    match.place.name,
                    style: TextStyle(
                      fontSize: hero ? 30 : 22,
                      fontWeight: FontWeight.w900,
                      color: hero ? Colors.white : const Color(0xFF4C1D95),
                    ),
                  ),
                ),
                Text(
                  '${(match.rankScore * 100).toStringAsFixed(1)}',
                  style: TextStyle(
                    color: hero ? const Color(0xFFE9D5FF) : color,
                    fontSize: hero ? 26 : 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Theme(
              data: Theme.of(context).copyWith(
                chipTheme: ChipThemeData(
                  backgroundColor: hero
                      ? Colors.white.withValues(alpha: .14)
                      : Colors.white,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: hero ? Colors.white : const Color(0xFF6D28D9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if ((match.place.scores['nature_culture'] ?? 0) < -.25)
                    _tag('Nature escapes', hero),
                  if ((match.place.scores['nature_culture'] ?? 0) > .25)
                    _tag('Culture & stories', hero),
                  if ((match.place.scores['activity'] ?? 0) > .25)
                    _tag('Active days', hero),
                  if ((match.place.scores['cost'] ?? 0) < -.25)
                    _tag('Budget friendly', hero),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: hero ? Colors.white : color,
                foregroundColor: hero ? const Color(0xFF6D28D9) : Colors.white,
                minimumSize: Size(hero ? double.infinity : 120, 48),
              ),
              icon: Icon(
                widget.kind == 'city'
                    ? Icons.travel_explore_rounded
                    : Icons.public,
              ),
              label: Text(
                tr(widget.kind == 'city' ? 'Tour' : 'Explore country'),
              ),
              onPressed: () {
                if (widget.kind == 'city') {
                  openCityTour(
                    context,
                    match.place.name,
                    countryCode: match.place.country,
                    latitude: (match.place.data['latitude'] as num).toDouble(),
                    longitude: (match.place.data['longitude'] as num)
                        .toDouble(),
                  );
                } else {
                  final countries = context
                      .read<CountryProvider>()
                      .allCountries
                      .where((c) => c.isoA2 == match.place.country);
                  if (countries.isNotEmpty)
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CountryDetailScreen(country: countries.first),
                      ),
                    );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
