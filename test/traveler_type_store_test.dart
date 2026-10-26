import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/services/traveler_type_store.dart';

String _result({int? version, bool scores = true}) => jsonEncode({
      if (version != null) 'engine_version': version,
      'summary': {
        'persona_scores': scores ? [{'id': 'a', 'label': 'A', 'score': 1.0}] : [],
      },
    });

void main() {
  test('old-engine results (no version) are invalid and get discarded', () {
    expect(TravelerTypeStore.isValid(_result()), isFalse);
    expect(TravelerTypeStore.isValid(_result(version: 1)), isFalse);
  });

  test('current-engine result with scores is valid', () {
    expect(TravelerTypeStore.isValid(_result(version: TravelerTypeStore.currentVersion)), isTrue);
  });

  test('empty scores / garbage / null are invalid', () {
    expect(TravelerTypeStore.isValid(_result(version: TravelerTypeStore.currentVersion, scores: false)), isFalse);
    expect(TravelerTypeStore.isValid('not json'), isFalse);
    expect(TravelerTypeStore.isValid(null), isFalse);
  });
}
