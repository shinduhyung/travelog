import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/services/persona_scorer.dart';

double _gauss(Random r) =>
    sqrt(-2 * log(1 - r.nextDouble())) * cos(2 * pi * r.nextDouble());
double _clip(double v) => v.clamp(-1.0, 1.0).toDouble();

void main() {
  final src = File('lib/services/travel_persona_engine.dart').readAsStringSync();
  final m = RegExp(r"_archetypePrototypesJson = r'''(.*?)'''", dotAll: true).firstMatch(src)!;
  final protos = jsonDecode(m.group(1)!) as List<dynamic>;
  final axes = (protos.first['data'] as Map<String, dynamic>).keys.toList();

  Map<String, double> around(Map<String, dynamic> t, Random r, double sd) => {
        for (final e in (t['data'] as Map<String, dynamic>).entries)
          e.key: _clip((e.value['P'] as num).toDouble() + _gauss(r) * sd),
      };

  test('30 simulated travelers: own type is top', () {
    final r = Random(7);
    var hit = 0;
    final tops = <double>[];
    for (final t in protos) {
      for (var i = 0; i < 3; i++) {
        final res = PersonaScorer.score(protos, around(t, r, 0.4));
        if (res.scores.first.id == t['id']) hit++;
        tops.add(res.scores.first.score);
      }
    }
    print('accuracy $hit/30, avg top share ${(tops.reduce((a, b) => a + b) / 30).toStringAsFixed(2)}');
    expect(hit, greaterThanOrEqualTo(27));
  });

  test('ordinary users: no type dominates, scores sum to 1', () {
    for (final sd in [0.3, 0.5]) {
      final r = Random(3);
      final wins = <String, int>{};
      var close = 0;
      const n = 600;
      for (var i = 0; i < n; i++) {
        final u = {for (final a in axes) a: _clip(_gauss(r) * sd)};
        final res = PersonaScorer.score(protos, u);
        wins[res.scores.first.id] = (wins[res.scores.first.id] ?? 0) + 1;
        if (res.isClose) close++;
        expect(res.scores.fold<double>(0, (s, e) => s + e.score), closeTo(1.0, 1e-9));
      }
      print('sd=$sd wins: ${wins.map((k, v) => MapEntry(k.substring(0, 8), '${(v * 100 / n).round()}%'))} close=${(close * 100 / n).round()}%');
      expect(wins.values.reduce(max) / n, lessThan(0.2));
      expect(wins.length, 10);
    }
  });

  test('neutral user is flagged as close, not a confident 75%', () {
    final res = PersonaScorer.score(protos, {for (final a in axes) a: 0.0});
    print('neutral top ${res.scores.first.label} ${(res.scores.first.score * 100).toStringAsFixed(0)}% gap ${(res.gap * 100).toStringAsFixed(1)}');
    expect(res.scores.first.score, lessThan(0.5));
    expect(res.hasSignal, isFalse);
    expect(res.isClose, isTrue);
    expect(res.lowData, isTrue);
    expect(res.scores.every((s) => (s.score - 0.1).abs() < 1e-9), isTrue);
  });

  test('empty, invalid and unknown evidence cannot produce a leading type', () {
    for (final u in <Map<String, double>>[
      {}, {'unknown_axis': 1}, {'solo_social': double.nan},
      {'morning_night': double.infinity},
    ]) {
      final result = PersonaScorer.score(protos, u);
      expect(result.hasSignal, isFalse);
      expect(result.coverage, 0);
      expect(result.scores.every((s) => s.score.isFinite), isTrue);
    }
  });

  test('same evidence in another map order gives identical scores', () {
    final u = {for (var i = 0; i < axes.length; i++) axes[i]: (i % 7 - 3) / 3.0};
    final reversed = Map<String, double>.fromEntries(u.entries.toList().reversed);
    final a = PersonaScorer.score(protos, u);
    final b = PersonaScorer.score(protos, reversed);
    expect(a.scores.map((s) => s.id), b.scores.map((s) => s.id));
    expect(a.scores.map((s) => s.score), b.scores.map((s) => s.score));
  });

  test('missing axes have less coverage than explicitly observed neutral axes', () {
    final sparse = PersonaScorer.score(protos, {'solo_social': 0.8});
    final withNeutral = PersonaScorer.score(protos, {'solo_social': 0.8, 'morning_night': 0});
    expect(sparse.coverage, lessThan(withNeutral.coverage));
    expect(sparse.lowData, isTrue);
    expect(sparse.scores.first.score, lessThan(0.3));
  });

  test('prototype directions agree with quiz semantics and type descriptions', () {
    Map<String, dynamic> type(String id) => protos.firstWhere((t) => t['id'] == id) as Map<String, dynamic>;
    double p(String id, String axis) => (type(id)['data'][axis]['P'] as num).toDouble();
    expect(p('efficiency_maximizer', 'planned_spontaneous'), greaterThan(0));
    expect(p('freedom_drifter', 'planned_spontaneous'), lessThan(0));
    expect(p('identity_seeker', 'documenter_minimalist'), greaterThan(0));
    expect(p('efficiency_maximizer', 'relaxed_intensive'), lessThan(0));
    expect(p('achievement_hunter', 'relaxed_intensive'), lessThan(0));
    expect(p('sensory_immersionist', 'relaxed_intensive'), greaterThan(0));
  });

  test('missing axes are excluded, DNA-only still recovers type', () {
    const dna = ['solo_social','nature_culture','relaxed_intensive','planned_spontaneous','budget_luxury','transit_drive','documenter_minimalist','morning_night'];
    var hit = 0;
    for (final t in protos) {
      final d = t['data'] as Map<String, dynamic>;
      final u = {for (final k in dna) k: (d[k]['P'] as num).toDouble()};
      final res = PersonaScorer.score(protos, u);
      if (res.scores.first.id == t['id']) hit++;
    }
    print('DNA-only recovery $hit/10');
    expect(hit, greaterThanOrEqualTo(8));
  });
}
