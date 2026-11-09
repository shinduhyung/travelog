import '../../lib/services/tourist_local_model.dart';

void check(bool value, String message) {if (!value) throw StateError(message);}
void main() {
  final reference = [1.0, 2.0, 4.0, 8.0, 16.0];
  final quiet = TouristLocalModel.score(reference, [const TouristCityVisit('Quiet', 1, 1)], 1)!;
  final busy = TouristLocalModel.score(reference, [const TouristCityVisit('Busy', 16, 1)], 1)!;
  check(quiet.tourist < busy.tourist, 'Tourism intensity polarity');
  check(quiet.tourist == 10 && busy.tourist == 90, 'Reference percentile');
  check(quiet.tourist + quiet.local == 100, 'Complement');
  check(TouristLocalModel.score(reference, [], 10) == null, 'Missing is not local');
  check(TouristLocalModel.score([1, 1], [const TouristCityVisit('Same', 1, 1)], 1) == null, 'No invented spread');
  final repeated = TouristLocalModel.score(reference,
    [const TouristCityVisit('Quiet', 1, 10000), const TouristCityVisit('Busy', 16, 1)], 10)!;
  check(repeated.covered.length == 2 && repeated.total == 10, 'Coverage');
  check(repeated.tourist > 30 && repeated.tourist < 40, 'Repeat weight capped');
  print('PASS: visit-only tourist/local polarity, missing data, coverage, capped revisits.');
}
