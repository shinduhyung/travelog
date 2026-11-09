// Verify the actual app model against all 500 frozen experiment results.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
// ignore: avoid_relative_lib_imports
import '../../lib/services/persona_runtime_model.dart';

Map<String,dynamic> read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String,dynamic>;
Map<String,double> vector(dynamic value) => (value as Map<String,dynamic>)
    .map((k,v)=>MapEntry(k,(v as num).toDouble()));

void main() {
  const folder='tool/persona_validation/out/jev';
  final runtime=PersonaRuntimeModel(read('assets/traveler_type/place_profiles.json'),
      read('assets/traveler_type/distribution_balance.json'));
  final rows=File('$folder/vectors_500.jsonl').readAsLinesSync()
      .map((s)=>jsonDecode(s) as Map<String,dynamic>).toList();
  final expected={for(final line in File('$folder/distribution_strong_results_500.jsonl').readAsLinesSync())
    (jsonDecode(line) as Map<String,dynamic>)['person_id'] as String:jsonDecode(line) as Map<String,dynamic>};
  final wanted=rows.map((r)=>r['person_id'] as String).toSet();
  final stableExpected={for(final line in File('$folder/app_expected_500.jsonl').readAsLinesSync())
    (jsonDecode(line) as Map<String,dynamic>)['person_id'] as String:jsonDecode(line) as Map<String,dynamic>};
  final people=<String,Map<String,dynamic>>{};
  for(final line in File('tool/persona_validation/out/users_reduced.jsonl').readAsLinesSync()) {
    final p=jsonDecode(line) as Map<String,dynamic>;
    if(wanted.contains(p['person_id'])) people[p['person_id'] as String]=p;
  }
  final engine=File('lib/services/travel_persona_engine.dart').readAsStringSync();
  final prototypes=jsonDecode(RegExp(r"_archetypePrototypesJson = r'''(.*?)'''",dotAll:true)
      .firstMatch(engine)!.group(1)!) as List<dynamic>;
  var maxAxisError=0.0,maxScoreError=0.0,protected=0;
  final counts=<String,int>{};
  for(final row in rows) {
    final person=people[row['person_id']]!;
    final cities=[for(final e in (person['cities'] as Map<String,dynamic>).entries)
      PersonaCityEvidence(e.key,visits:e.value['recorded_visits'] as int,
          rating:(e.value['rating'] as num? ?? 0).toDouble(),hasLived:e.value['hasLived']==true,
          isHome:e.key==person['homeCityName'])];
    final landmarks=[
      for(final name in person['landmark_visited'] as List)
        PersonaLandmarkEvidence(name.toString(),rating:((person['landmark_ratings'] as Map)[name] as num? ?? 0).toDouble()),
      for(final name in person['unesco_visited'] as List)
        PersonaLandmarkEvidence(name.toString(),source:'unesco',rating:((person['unesco_ratings'] as Map)[name] as num? ?? 0).toDouble()),
    ];
    final scored=runtime.score(prototypes,vector(row['before']),cities,landmarks);
    final expectedAxes=vector(row['added_axes']);
    if(scored.places.axes.length!=expectedAxes.length || !scored.places.axes.keys.toSet().containsAll(expectedAxes.keys)) {
      throw StateError('Place feature mask differs for ${row['person_id']}');
    }
    for(final e in expectedAxes.entries) {
      maxAxisError=max(maxAxisError,(e.value-scored.places.axes[e.key]!).abs());
    }
    final golden=expected[row['person_id']]!;
    final expectedScores=vector(stableExpected[row['person_id']]!['scores']);
    for(final s in scored.result.scores) {
      maxScoreError=max(maxScoreError,(s.score-expectedScores[s.id]!).abs());
    }
    if(scored.result.scores.first.id!=golden['strong_top']) throw StateError('Top type differs');
    if(!scored.balanceApplied) throw StateError('Expected reference cohort to qualify for balancing');
    if(scored.raw.scores.first.score>=.8) {
      protected++;
      if(scored.raw.scores.first.id!=scored.result.scores.first.id) throw StateError('Strong lead changed');
    }
    final top=scored.result.scores.first.id;
    counts[top]=(counts[top]??0)+1;
  }
  if(rows.length!=500 || people.length!=500 || maxAxisError>1e-10 || maxScoreError>1e-9 || protected!=95) {
    throw StateError('Parity tolerance or cohort count failed: $maxAxisError / $maxScoreError');
  }
  final report={'users':rows.length,'all_top_types_match':true,'max_axis_error':maxAxisError,
    'max_score_error':maxScoreError,'protected_leads':protected,'type_counts':counts,
    'runtime':'Actual shared app model and bundled Jev/category/balance assets','no_api_calls':true};
  File('$folder/app_integration_verification.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(jsonEncode(report));
}
