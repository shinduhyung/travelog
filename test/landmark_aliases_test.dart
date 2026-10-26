import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/utils/landmark_aliases.dart';

void main() {
  test(
    'retired names resolve to one existing landmark and rank references survive',
    () {
      final records =
          jsonDecode(File('assets/all_landmarks.json').readAsStringSync())
              as List;
      final names = records.map((e) => e['name'] as String).toList();
      for (final alias in landmarkAliases.entries) {
        expect(names, isNot(contains(alias.key)));
        expect(names.where((name) => name == alias.value), hasLength(1));
      }
      final ranks = File('assets/city_rank.json').readAsStringSync();
      for (final alias in landmarkAliases.keys) {
        expect(ranks, isNot(contains(jsonEncode(alias))));
      }
      expect(names, containsAll(['Park Alisa', 'Park Yulya']));
      final alisa = records.singleWhere((e) => e['name'] == 'Park Alisa');
      final yulya = records.singleWhere((e) => e['name'] == 'Park Yulya');
      expect(alisa['latitude'], isNot(yulya['latitude']));
    },
  );

  test('visited, wishlist and sublocation keys collapse aliases only', () {
    expect(
      [
        'Stone Forest',
        'Shilin Stone Forest',
        'Park Alisa',
        'Park Yulya',
      ].map(canonicalLandmarkName).toSet(),
      {'Shilin Stone Forest', 'Park Alisa', 'Park Yulya'},
    );
    expect(
      canonicalLandmarkSubLocationKey('Stone Forest_Ashima'),
      'Shilin Stone Forest_Ashima',
    );
    expect(
      canonicalLandmarkSubLocationKey('Stone Forest Other_Ashima'),
      'Stone Forest Other_Ashima',
    );
  });

  test('canonical positive rating wins independent of saved map order', () {
    for (final ratings in [
      {'Stone Forest': 5.0, 'Shilin Stone Forest': 4.0},
      {'Shilin Stone Forest': 4.0, 'Stone Forest': 5.0},
    ]) {
      expect(mergeLandmarkRatings(ratings), {'Shilin Stone Forest': 4.0});
    }
    expect(
      mergeLandmarkRatings({'Stone Forest': 5.0, 'Shilin Stone Forest': 0.0}),
      {'Shilin Stone Forest': 5.0},
    );
  });

  test(
    'visit merge keeps notes and photos without duplicating alias copies',
    () {
      final first = {
        'year': 2024,
        'memo': 'first trip',
        'photos': ['first.jpg'],
      };
      final second = {
        'year': 2025,
        'memo': 'return trip',
        'photos': ['second.jpg'],
      };
      final history = mergeLandmarkVisitHistory({
        'Stone Forest': [first, second],
        'Shilin Stone Forest': [first],
      });
      final visits = history['Shilin Stone Forest']!;
      expect(visits, hasLength(2));
      expect(visits.map((v) => v.memo), ['first trip', 'return trip']);
      expect(visits.last.photos, ['second.jpg']);
      final saved = {
        for (final e in history.entries)
          e.key: e.value.map((v) => v.toJson()).toList(),
      };
      expect(
        mergeLandmarkVisitHistory(saved)['Shilin Stone Forest'],
        hasLength(2),
      );
    },
  );

  test('intentional repeated undated visits within one name survive', () {
    final history = mergeLandmarkVisitHistory({
      'Stone Forest': [{}, {}],
    });
    expect(history['Shilin Stone Forest'], hasLength(2));
  });
}
