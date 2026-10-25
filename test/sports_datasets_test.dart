import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/models/statistics_dataset.dart';

StatisticsDataset _load(String id) => StatisticsDataset.fromJson(
  jsonDecode(File('assets/$id.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  test('every sports dataset is bundled in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final files = Directory('assets')
        .listSync()
        .map((e) => e.path.replaceAll(r'\', '/').split('/').last)
        .where((n) => n.startsWith('sports_') && n.endsWith('.json'));
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(pubspec, contains('- assets/$f'), reason: '$f is not registered');
    }
  });

  test('sports datasets match the statistics schema and expected shape', () {
    final fifa = _load('sports_fifa_ranking');
    expect(fifa.table('men').records.first.dimensions['iso_a3'], 'ESP');
    expect(fifa.table('men').records.length, greaterThan(200));
    expect(fifa.table('women').records.first.number('rank'), 1);

    final ucl = _load('sports_ucl_titles');
    final spain = ucl
        .table('country')
        .records
        .firstWhere((r) => r.dimensions['iso_a3'] == 'ESP');
    expect(spain.number('titles'), 20);
    final titles = ucl.table('city').records.fold<num>(
      0,
      (s, r) => s + r.number('titles')!,
    );
    expect(
      titles,
      ucl.table('country').records.fold<num>(0, (s, r) => s + r.number('titles')!),
    );

    final wc = _load('sports_world_cup_results').table();
    final champions = wc.records
        .where((r) => r.values['best_result'] == 'Champions')
        .map((r) => r.dimensions['iso_a3'])
        .toSet();
    expect(champions, {'GBR', 'BRA', 'DEU', 'ARG', 'ITA', 'ESP', 'FRA', 'URY'});

    expect(_load('sports_tennis_slam_men').table().records.first.number('titles'), 147);
    expect(_load('sports_fide_grandmasters').table().records.first.dimensions['iso_a3'], 'RUS');
    expect(_load('sports_mlb_international_players').table().records.first.number('players'), 93);
  });

  test('olympics uses ISO3 codes only', () {
    final isos = _load('olympics')
        .table()
        .records
        .map((r) => r.dimensions['iso_a3'] as String)
        .toList();
    expect(isos.toSet().length, isos.length);
    expect(isos, containsAll(['DEU', 'CHE', 'FRA', 'USA']));
    expect(isos, isNot(contains('GER')));
    expect(isos, isNot(contains('SUI')));
  });
}
