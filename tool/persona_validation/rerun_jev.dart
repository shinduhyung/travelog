// Shadow comparison for the frozen 500-person cohort. No API or app writes.
import 'dart:convert';
import 'dart:io';
// ignore: avoid_relative_lib_imports
import '../../lib/services/persona_scorer.dart';

Map<String, double> vector(dynamic value) =>
    (value as Map<String, dynamic>).map((k,v) => MapEntry(k,(v as num).toDouble()));

Map<String,dynamic> compare(List<dynamic> types, List<Map<String,dynamic>> rows,
    {IOSink? output}) {
  final beforeCounts = <String,int>{}, afterCounts = <String,int>{};
  var changed=0, added=0, blended=0, lowData=0;
  final ids=<String>{};
  for (final row in rows) {
    if (!ids.add(row['person_id'] as String)) throw StateError('Duplicate person');
    final before = PersonaScorer.score(types,vector(row['before']));
    final after = PersonaScorer.score(types,vector(row['after']));
    final b=before.hasSignal?before.scores.first.id:'unresolved';
    final a=after.hasSignal?after.scores.first.id:'unresolved';
    beforeCounts[b]=(beforeCounts[b]??0)+1;
    afterCounts[a]=(afterCounts[a]??0)+1;
    if(a!=b) changed++;
    if((row['added_axes'] as Map).isNotEmpty) added++;
    if(after.isClose) blended++;
    if(after.lowData) lowData++;
    final sum=after.scores.fold<double>(0,(s,e)=>s+e.score);
    if((sum-1).abs()>1e-9 || after.scores.any((s)=>!s.score.isFinite)) {
      throw StateError('Invalid output distribution');
    }
    output?.writeln(jsonEncode({'person_id':row['person_id'], 'before_top':b,'after_top':a,
      'is_close':after.isClose,'low_data':after.lowData,'coverage':after.coverage,
      'added_axes':row['added_axes'],'evidence':row['evidence'],
      'scores':{for(final s in after.scores)s.id:s.score}}));
  }
  return {'users':rows.length,'before_type_counts':beforeCounts,'after_type_counts':afterCounts,
    'changed_top':changed,'users_with_added_axes':added,'blended_users':blended,'low_data_users':lowData,
    'method':'Same cohort, same production scorer and prototypes; only supported Jev place axes added.',
    'limits':['No human type labels: type distribution changes are not accuracy.',
      'Generic categories omit crowd, price, tourist-audience and nightlife axes.',
      'Four landmark axes use the explicit catalog sign convention; the old online AI prompt had inverted descriptions.']};
}

Future<void> main(List<String> args) async {
  const folder='tool/persona_validation/out/jev';
  final source=File('lib/services/travel_persona_engine.dart').readAsStringSync();
  final match=RegExp(r"_archetypePrototypesJson = r'''(.*?)'''",dotAll:true).firstMatch(source)!;
  final types=jsonDecode(match.group(1)!) as List<dynamic>;
  if(args.contains('--self-test')) {
    // Deliberately synthetic fixtures, never written as actual Jev results.
    final rows=List.generate(500,(i)=><String,dynamic>{
      'person_id':'fixture-$i','before':<String,dynamic>{'solo_social':.4,'nature_culture':-.2},
      'after':<String,dynamic>{'solo_social':.4,'nature_culture':-.2,'cityType':.8},
      'added_axes':{'cityType':.8},'evidence':{'fixture':true}});
    final report=compare(types,rows);
    if(report['users']!=500 || report['users_with_added_axes']!=500) throw StateError('Fixture join failed');
    stdout.writeln('SELF_TEST_ONLY: 500 synthetic rows; finite normalized scores; unique cohort; no result files written.');
    return;
  }
  final input=File('$folder/vectors_500.jsonl');
  if(!input.existsSync()) {
    stderr.writeln('WAITING_FOR_JEV: run the API jobs and offline aggregate first. No result generated.');
    exitCode=2;
    return;
  }
  final rows=input.readAsLinesSync().map((s)=>jsonDecode(s) as Map<String,dynamic>).toList();
  final preparation=jsonDecode(File('$folder/preparation_summary.json').readAsStringSync());
  final aggregation=jsonDecode(File('$folder/aggregation_summary.json').readAsStringSync());
  if(aggregation['catalog_fingerprint']!=preparation['catalog_fingerprint'] ||
      aggregation['cohort_fingerprint']!=preparation['cohort_fingerprint']) {
    throw StateError('Prepared catalog/cohort changed; aggregate the current Jev cache again');
  }
  if(rows.length!=500) throw StateError('Expected the frozen 500-person cohort');
  final cohort=(jsonDecode(File('$folder/cohort.json').readAsStringSync()) as List)
      .map((r)=>r['person_id'] as String).toSet();
  final actual=rows.map((r)=>r['person_id'] as String).toSet();
  if(actual.length!=500 || !actual.containsAll(cohort) || cohort.length!=500) {
    throw StateError('Cohort identity changed');
  }
  final sink=File('$folder/results_500.jsonl').openWrite();
  final report=compare(types,rows,output:sink);
  await sink.close();
  report['place_score_fingerprint']=aggregation['score_fingerprint'];
  report['axis_user_coverage']=aggregation['axis_user_coverage'];
  report['jev_usage']=aggregation['jev_usage'];
  File('$folder/comparison_500.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(jsonEncode(report));
}
