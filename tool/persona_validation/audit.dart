// Offline audit using the actual production scorer. No Flutter or API needed.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../lib/services/persona_scorer.dart';
import 'baseline_scorer.dart' as legacy;

void main(List<String> args) {
  final baseline = args.contains('--baseline');
  final dir = Directory('tool/persona_validation/out');
  final prototypes = jsonDecode(File(baseline ? 'tool/persona_validation/baseline_prototypes.json' : '${dir.path}/prototypes.json').readAsStringSync()) as List<dynamic>;
  final rows = File('${dir.path}/vectors.jsonl').readAsLinesSync()
      .map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  final oldResults = <String, dynamic>{};
  final old = File('${dir.path}/baseline_results.jsonl');
  if (!baseline && old.existsSync()) {
    for (final line in old.readAsLinesSync()) {
      final v = jsonDecode(line) as Map<String, dynamic>;
      oldResults[v['person_id'] as String] = v;
    }
  }
  final results = File('${dir.path}/${baseline ? 'baseline' : 'updated'}_results.jsonl').openSync(mode: FileMode.write);
  final metrics = <String, dynamic>{};
  final cohorts = <String, List<Map<String, dynamic>>>{};
  var elapsed = Stopwatch()..start();
  var changed = 0, compared = 0, dnaAgree = 0, dnaN = 0, travelAgree = 0, travelN = 0;
  var jitterRetained = 0, jitterTop2 = 0, jitterN = 0;
  final jitterGroups = <String, List<int>>{};
  var dropoutRetained = 0, dropoutN = 0;
  final ablations = <String, List<int>>{};
  final eligible = rows.where((r) => (r['dna'] as Map).isNotEmpty && (r['travel'] as Map).isNotEmpty).toList()
    ..shuffle(Random(42));
  final dropoutIds = eligible.take(100).map((r)=>r['person_id']).toSet();
  final ablationIds = eligible.take(40).map((r)=>r['person_id']).toSet();
  final rng = Random(20261016);
  Map<String, double> vector(dynamic v) => (v as Map<String, dynamic>).map((k,v) => MapEntry(k, (v as num).toDouble()));
  void add(String cohort, Map<String,dynamic> record) => cohorts.putIfAbsent(cohort, () => []).add(record);
  // Masks are grouped to share expensive calibration work, not to sample users.
  rows.sort((a,b) => (a['combined'] as Map).keys.join('|').compareTo((b['combined'] as Map).keys.join('|')));
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final u = vector(row[baseline ? 'legacy' : 'combined']);
    final dna = vector(row['dna']), travel = vector(row['travel']);
    final dynamic res = baseline ? legacy.PersonaScorer.score(prototypes, u) : PersonaScorer.score(prototypes, u);
    final total = res.scores.fold<double>(0.0, (double sum, dynamic s) => sum + (s.score as double));
    if (res.scores.any((s) => !s.score.isFinite || s.score < 0 || s.score > 1) || (total - 1).abs() > 1e-9) {
      throw StateError('Invalid distribution for ${row['person_id']}');
    }
    final informative = (row['combined'] as Map).isNotEmpty;
    final hasSignal = u.values.any((v) => v.abs() > 1e-9);
    final cohort = dna.isNotEmpty ? (travel.isNotEmpty ? 'dna_and_travel' : 'dna_only') : (travel.isNotEmpty ? 'travel_only' : 'no_data');
    final record = <String,dynamic>{'person_id':row['person_id'],'top':!baseline && !res.hasSignal ? 'unresolved' : res.scores.first.id,
      'top_share':res.scores.first.score,'gap':res.gap,'coverage':res.coverage,
      'close':res.isClose,'low_data':res.lowData,'observed_axes':(row['combined'] as Map).length,
      'cohort':cohort,'has_signal':hasSignal,
      'scores': {for (final s in res.scores) s.id:s.score}};
    add('all', record); add(cohort, record);
    if (informative) add('observed', record);
    if (!baseline && informative) {
      final previous = oldResults[row['person_id']];
      if (previous != null) {compared++; if (previous['top'] != record['top']) changed++;}
      if (dna.isNotEmpty && travel.isNotEmpty) {
        final d = PersonaScorer.score(prototypes,dna);
        dnaN++; if (d.scores.first.id == res.scores.first.id) dnaAgree++;
        final t = PersonaScorer.score(prototypes,travel);
        travelN++; if (t.scores.first.id == res.scores.first.id) travelAgree++;
      }
      // Small +/-0.05 axis noise, independent of any desired type label.
      for (var j=0; j<3; j++) {
        final noisy = u.map((k,v) => MapEntry(k,(v+(rng.nextDouble()*2-1)*.05).clamp(-1.0,1.0).toDouble()));
        final n = PersonaScorer.score(prototypes,noisy);
        final retained = n.scores.first.id == res.scores.first.id;
        jitterN++; if (retained) jitterRetained++;
        if (res.scores.take(2).any((s) => s.id == n.scores.first.id)) jitterTop2++;
        final g = jitterGroups.putIfAbsent(res.isClose ? 'close' : 'separated',()=>[0,0]);
        g[1]++; if (retained) g[0]++;
      }
      // Reproducible random sample, independent of observed masks and outcomes.
      if (dropoutIds.contains(row['person_id'])) {
        final dropped = Map<String,double>.from(u)..remove(u.keys.elementAt(dropoutN % u.length));
        final n = PersonaScorer.score(prototypes,dropped);
        dropoutN++; if(n.scores.first.id == res.scores.first.id) dropoutRetained++;
      }
      if (ablationIds.contains(row['person_id'])) {
        for (final axis in u.keys) {
          final dropped = Map<String,double>.from(u)..remove(axis);
          final n = PersonaScorer.score(prototypes,dropped);
          final a = ablations.putIfAbsent(axis,()=>[0,0]);
          a[1]++; if(n.scores.first.id != res.scores.first.id) a[0]++;
        }
      }
    }
    results.writeStringSync('${jsonEncode(record)}\n');
    if ((index+1)%1000==0) stdout.writeln('${index+1}/${rows.length}, ${elapsed.elapsedMilliseconds}ms');
  }
  results.closeSync();
  for (final e in cohorts.entries) {
    final rs=e.value;
    final wins = <String,int>{};
    for(final r in rs) { wins[r['top'] as String]=(wins[r['top']]??0)+1; }
    double mean(String k) => rs.map((r)=>(r[k] as num).toDouble()).reduce((a,b)=>a+b)/rs.length;
    metrics[e.key]={'n':rs.length,'top_counts':wins,'mean_top_share':mean('top_share'),'mean_gap':mean('gap'),
      'close_count':rs.where((r)=>r['close']==true).length,'low_data_count':rs.where((r)=>r['low_data']==true).length};
    metrics[e.key]['top_above_80pct_with_low_data'] = rs.where((r)=>r['low_data']==true && (r['top_share'] as num) > .8).length;
  }
  final report = {'mode':baseline?'baseline':'updated','cohorts':metrics,
    'changed_top':{'changed':changed,'compared':compared},
    'combined_vs_dna_top_agreement':{'same':dnaAgree,'n':dnaN},
    'combined_vs_travel_top_agreement':{'same':travelAgree,'n':travelN},
    'small_noise_top_retained':{'same':jitterRetained,'n':jitterN,'stays_in_original_top2':jitterTop2,'by_group':jitterGroups},
    'single_axis_dropout_random_100':{'same':dropoutRetained,'n':dropoutN},
    'axis_ablation_random_40_changed_and_total':ablations,
    'elapsed_ms':elapsed.elapsedMilliseconds,
    'limitations':['No independent labels: no accuracy estimate.','13 AI axes absent: deterministic fallback path only.',
       'Offline country aliases may differ from runtime normalizations.','Noise/dropout are diagnostic, not real user retest results.']};
  File('${dir.path}/${baseline?'baseline':'updated'}_audit.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(jsonEncode(report));
}
