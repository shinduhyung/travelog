import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/city_visit_detail_model.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/models/unesco_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/providers/airline_provider.dart';
import 'package:jidoapp/providers/airport_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:jidoapp/providers/personality_provider.dart';
import 'package:jidoapp/providers/trip_log_provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/services/travel_persona_engine.dart';
import 'package:jidoapp/services/traveler_type_store.dart';

class _Countries implements CountryProvider {
  @override bool get isLoading=>false;
  @override String? get homeCountryIsoA3=>null;
  @override Map<String,VisitDetails> get visitDetails=>{};
  @override Map<String,String> get countryNameToIsoMap=>{};
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class _Cities implements CityProvider {
  @override bool get isLoading=>false;
  @override String? get homeCityName=>null;
  @override final Map<String,CityVisitDetail> visitDetails={};
  @override bool isVisited(String name)=>visitDetails[name]?.visitDateRanges.isNotEmpty??false;
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class _Flights implements AirlineProvider {
  @override bool get isLoading=>false;
  @override List<FlightLog> get allFlightLogs=>[];
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class _Airports implements AirportProvider {
  @override bool get isLoading=>false;
  @override Set<String> get visitedAirports=>{};
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class _Answers implements PersonalityProvider {
  @override bool get isCalculated=>true;
  @override final Map<int,int> responses={1:5};
  @override Map<String,double> get finalScores=>{
    'solo_social':60,'nature_culture':60,'relaxed_intensive':60,'planned_spontaneous':60,
    'budget_luxury':60,'transit_drive':60,'documenter_minimalist':60,'morning_night':60};
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class _Landmarks implements LandmarksProvider {
  @override bool isLoading=false;
  @override List<Landmark> get allLandmarks=>[];
  @override final Set<String> visitedLandmarks={};
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class _Unesco implements UnescoProvider {
  @override bool get isLoading=>false;
  @override List<UnescoSite> get allSites=>[];
  @override Set<String> get visitedSites=>{};
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class _Logs implements TripLogProvider {
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Cities cities;
  late _Answers answers;
  late _Landmarks landmarks;
  setUp(() {
    cities=_Cities()..visitDetails['Paris']=CityVisitDetail(name:'Paris',rating:4,visitDateRanges:[DateRange()]);
    answers=_Answers();
    landmarks=_Landmarks()..visitedLandmarks.add('Notre-Dame de Paris');
  });
  Future<Map<String,dynamic>> analyze() async=>jsonDecode(await TravelPersonaEngine().analyze(
      answers,_Countries(),cities,_Flights(),_Airports(),_Logs(),
      landmarksProvider:landmarks,unescoProvider:_Unesco())) as Map<String,dynamic>;

  test('app entry point uses quiz, real city and landmark providers without keys', () async {
    final result=await analyze();
    expect(result['engine_version'],TravelerTypeStore.currentVersion);
    expect(result['scoring_method'],'cached_jev_places_balanced_v1');
    expect(result['full_feature_vector'],contains('cityWealth'));
    expect(result['full_feature_vector'],contains('landmark_spiritual_secular'));
    expect(result['summary']['distribution_balanced'],isTrue);
    final scores=result['summary']['persona_scores'] as List;
    expect(scores.length,10);
    expect(scores.fold<double>(0,(s,v)=>s+(v['score'] as num).toDouble()),closeTo(1,1e-9));
    expect(TravelerTypeStore.isValid(jsonEncode(result)),isTrue);
  });
  test('empty answer map does not synthesize quiz evidence', () async {
    answers.responses.clear();
    final result=await analyze();
    expect((result['full_feature_vector'] as Map).containsKey('solo_social'),isFalse);
    expect(result['summary']['distribution_balanced'],isFalse);
  });
  test('no travel or answer evidence cannot be cached as a leading type', () async {
    answers.responses.clear();cities.visitDetails.clear();landmarks.visitedLandmarks.clear();
    final result=await analyze();
    expect(result['summary']['has_signal'],isFalse);
    expect(TravelerTypeStore.isValid(jsonEncode(result)),isFalse);
  });
  test('loading records are not analyzed as missing observations', () async {
    landmarks.isLoading=true;
    await expectLater(analyze(),throwsStateError);
  });
}
