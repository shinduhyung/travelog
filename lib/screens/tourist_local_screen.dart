import 'package:jidoapp/screens/discover_quiz_screen.dart';
import 'package:jidoapp/services/discover_quizzes.dart';
import 'package:jidoapp/services/survey_ad_session.dart';
import 'package:jidoapp/widgets/tourist_footprint_result.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/services/tourist_local_model.dart';

class TouristLocalScreen extends StatelessWidget {
  final SurveyAdSession? adSession;
  const TouristLocalScreen({super.key, this.adSession});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CityProvider>();
    final reference = provider.allCities
        .map((c) => c.cityTouristRatio)
        .toList();
    final byName = <String, List<City>>{};
    for (final city in provider.allCities) {
      byName.putIfAbsent(city.name, () => []).add(city);
    }
    final visits = <TouristCityVisit>[];
    var total = 0;
    for (final entry in provider.visitDetails.entries) {
      final detail = entry.value;
      if (detail.visitCount <= 0 ||
          detail.isHome ||
          detail.hasLived ||
          entry.key == provider.homeCityName)
        continue;
      total++;
      final candidates = byName[entry.key] ?? [];
      if (candidates.length != 1) continue;
      final city = candidates.single;
      visits.add(
        TouristCityVisit(
          city.name,
          city.cityTouristRatio,
          detail.visitCount,
          country: city.countryIsoA2,
        ),
      );
    }
    final result = TouristLocalModel.score(reference, visits, total);
    if (provider.isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return DiscoverQuizScreen(
      quizId: 'local',
      adSession: adSession,
      resultDataBuilder: (answers) {
        final value = TouristLocalModel.combine(
          result,
          discoveryQuizzes['local']!.score(answers).toDouble(),
        );
        return {
          'local': value.local,
          'tourist': value.tourist,
          'coveredCities': value.covered.length,
        };
      },
      resultBuilder: (answers) {
        final surveyLocal = discoveryQuizzes['local']!
            .score(answers)
            .toDouble();
        return TouristFootprintResult(
          result: TouristLocalModel.combine(result, surveyLocal),
          showDetails: false,
        );
      },
    );
  }
}
