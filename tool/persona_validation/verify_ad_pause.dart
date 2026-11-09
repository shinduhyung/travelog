import '../../lib/services/preserved_ad_pause.dart';

void check(bool value, String message) {if (!value) throw StateError(message);}
void main() {
  final start = DateTime.utc(2026, 10, 31);
  final clock = PreservedAdPause();
  final survey = Object(), game = Object();
  final anchor = start.subtract(const Duration(seconds: 40));
  clock.begin(survey, start);
  clock.begin(survey, start.add(const Duration(seconds: 10)));
  clock.begin(game, start.add(const Duration(seconds: 20)));
  var result = clock.end(survey, start.add(const Duration(seconds: 60)), anchor);
  check(clock.isPaused && result == anchor, 'Nested pause must not resume early');
  final end = start.add(const Duration(seconds: 100));
  result = clock.end(game, end, result);
  check(!clock.isPaused && end.difference(result!).inSeconds == 40,
    'Elapsed time must resume at exactly the original 40 seconds');
  check(clock.end(game, end, result) == result, 'Duplicate resume must not change time');
  clock.begin(survey, start);
  result = clock.end(survey, end, start.add(const Duration(seconds: 50)));
  check(result == end, 'An anchor created mid-pause must not move into the future');
  clock.begin(survey, start);
  check(clock.end(survey, end, null) == null, 'Missing anchor must remain missing');
  print('PASS: exact elapsed preservation, overlapping screens, repeated pause/resume, late and missing anchors.');
}
