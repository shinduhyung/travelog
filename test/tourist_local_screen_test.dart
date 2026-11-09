import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/services/survey_ad_session.dart';
import 'package:jidoapp/services/rewarded_unlock_service.dart';
import 'package:jidoapp/services/discover_quizzes.dart';
import 'package:jidoapp/services/tourist_local_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/city_model.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/screens/tourist_local_screen.dart';

class _Cities extends ChangeNotifier implements CityProvider {
  @override
  bool get isLoading => false;
  @override
  String? get homeCityName => 'Home';
  @override
  List<City> get allCities => [
    for (var i = 0; i < 5; i++) City(name: ['Quiet', 'Home', 'Middle', 'Busy', 'Unknown'][i],
      country: 'Test', countryIsoA2: 'FR', continent: 'Europe', population: 100,
      latitude: i.toDouble(), longitude: 0, cityTouristRatio: [1.0, 2.0, 4.0, 8.0, 0.0][i]),
  ];
  @override
  Map<String, CityVisitDetail> get visitDetails => {
    for (final name in ['Quiet', 'Home', 'Unknown']) name: CityVisitDetail.fromJson({
      'name': name, 'rating': 0, 'visitDateRanges': [<String, dynamic>{}],
    }),
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Ten answers blend with cities and result hides city lists', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final ads = SurveyAdSession(pause: Object.new, resume: (_) {}, needsAd: () => false, watch: (_) async => RewardedUnlockResult.unlocked);
    await tester.pumpWidget(ChangeNotifierProvider<CityProvider>(
      create: (_) => _Cities(), child: MaterialApp(home: TouristLocalScreen(adSession: ads))));
    await tester.pumpAndSettle();
    final quiz = discoveryQuizzes['local']!;
    expect(quiz.questions.length, 10);
    expect(find.text('1 / 10'), findsOneWidget);
    for (var i = 0; i < quiz.questions.length; i++) {
      final option = quiz.questions[i].options.firstWhere((o) => o.points == 3);
      await tester.ensureVisible(find.text(option.text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option.text));
      await tester.pump();
      await tester.tap(find.text(i == 9 ? 'See result' : 'Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('YOUR TRAVEL STYLE'), findsOneWidget);
    expect(find.text('Your cities'), findsNothing);
    expect(find.text('99.1%'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  test('City evidence shifts quiz result and absent cities use answers alone', () {
    expect(TouristLocalModel.combine(null, 80).local, 80);
    final cities = TouristLocalResult(100, List.generate(5, (i) => TouristCityVisit('$i', 1, 1)), 5);
    expect(TouristLocalModel.combine(cities, 100).local, 65);
    expect(TouristLocalModel.combine(cities, 0).tourist, 100);
  });
}
