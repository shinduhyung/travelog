import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/services/travel_persona_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final places=jsonDecode(File('assets/traveler_type/place_profiles.json').readAsStringSync()) as Map<String,dynamic>;
  final balance=jsonDecode(File('assets/traveler_type/distribution_balance.json').readAsStringSync()) as Map<String,dynamic>;
  final model=PersonaRuntimeModel(places,balance);
  final source=File('lib/services/travel_persona_engine.dart').readAsStringSync();
  final prototypes=jsonDecode(RegExp(r"_archetypePrototypesJson = r'''(.*?)'''",dotAll:true).firstMatch(source)!.group(1)!) as List<dynamic>;
  const dna=['solo_social','nature_culture','relaxed_intensive','planned_spontaneous',
    'budget_luxury','transit_drive','documenter_minimalist','morning_night'];

  test('bundled runtime loads without an API key', () async {
    final loaded=await TravelPersonaRuntime.load();
    expect(identical(loaded,await TravelPersonaRuntime.load()),isTrue);
    expect(loaded.places.data['city_count'],271);
    expect(loaded.places.data['category_count'],28);
  });
  test('empty evidence does not become a balanced leading type', () {
    final result=model.score(prototypes,{},[],[]);
    expect(result.balanceApplied,isFalse);
    expect(result.result.hasSignal,isFalse);
    expect(result.result.scores.every((s)=>(s.score-.1).abs()<1e-9),isTrue);
  });
  test('quiz-only and travel-only users stay outside the fitted reference', () {
    expect(model.score(prototypes,{for(final k in dna)k:.2},[],[]).balanceApplied,isFalse);
    expect(model.score(prototypes,{'cityDistribution':1},[],[]).balanceApplied,isFalse);
  });
  test('recorded cities plus answers use both cached axes and balancing', () {
    final result=model.score(prototypes,{for(final k in dna)k:.2},
        [const PersonaCityEvidence('Paris',visits:2)],[]);
    expect(result.features,contains('cityType'));
    expect(result.balanceApplied,isTrue);
    expect(result.result.scores.fold<double>(0,(s,v)=>s+v.score),closeTo(1,1e-9));
  });
  test('home, lived and unvisited cities are excluded', () {
    final result=model.places.extract([
      const PersonaCityEvidence('Paris',visits:2,isHome:true),
      const PersonaCityEvidence('Tokyo',visits:2,hasLived:true),
      const PersonaCityEvidence('New York',visits:0),
    ],[]);
    expect(result.axes,isEmpty);
  });
  test('food and lodging never add landmark axes, even through fallback', () {
    final result=model.places.extract([], [
      const PersonaLandmarkEvidence('A fixture restaurant',attributes:['Restaurant','Museum']),
      const PersonaLandmarkEvidence('A fixture hotel',attributes:['Hotel']),
    ]);
    expect(result.axes,isEmpty);
    expect(result.evidence['landmark_excluded'],2);
  });
  test('normalization handles accents and city aliases without collapsing Unicode', () {
    expect(model.places.normalize('São Paulo'),'sao paulo');
    expect(model.places.normalize('New York City'),'new york');
    expect(model.places.normalize('서울'),isNot(model.places.normalize('부산')));
  });
  test('new venues reuse a category and repeated venues do not dominate', () {
    final temple=const PersonaLandmarkEvidence('Fixture temple',attributes:['Buddhist']);
    final one=model.places.extract([], [
      const PersonaLandmarkEvidence('Fixture park 0',attributes:['Amusement Park']),temple]);
    final many=model.places.extract([], [
      for(var i=0;i<10;i++) PersonaLandmarkEvidence('Fixture park $i',attributes:const ['Amusement Park']),temple]);
    expect(one.axes,many.axes);
    expect(one.axes,contains('landmark_spiritual_secular'));
  });
  test('high original lead and uniform scores are preserved', () {
    final types=(balance['types'] as List).cast<String>();
    final strong = {for (final k in types) k: k == types.first ? .9 : .1 / 9};
    final neutral={for(final k in types)k:.1};
    expect(model.balance.apply(strong),strong);
    expect(model.balance.apply(neutral),neutral);
  });
  test('profile output is independent of key order and batch counts', () {
    final types=(balance['types'] as List).cast<String>();
    final raw={for(var i=0;i<types.length;i++)types[i]:(i+1)/55.0};
    final expected=model.balance.apply(raw);
    for(var i=0;i<10;i++) {model.balance.apply({for(final k in types)k:.1});}
    expect(model.balance.apply(Map.fromEntries(raw.entries.toList().reversed)),expected);
    expect(expected.values.fold<double>(0,(a,b)=>a+b),closeTo(1,1e-9));
  });
  test('bundles contain no account identifiers or credentials', () {
    const forbidden={'person_id','uid','email','training_person_ids','holdout_person_ids',
      'dna_responses','TYPESAFE_API_KEY','JEV_API_KEY'};
    void check(dynamic value) {
      if(value is Map) {
        expect(value.keys.toSet().intersection(forbidden),isEmpty);
        for(final item in value.values) {check(item);}
      } else if(value is List) {for(final item in value) {check(item);}}
    }
    check(places);check(balance);
  });
}
