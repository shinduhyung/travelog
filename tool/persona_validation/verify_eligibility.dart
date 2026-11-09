// Pure Dart verification: no Flutter asset build or API access required.
import 'dart:convert';
import 'dart:io';
import '../../lib/services/persona_runtime_model.dart';

void main() {
  final data = jsonDecode(File('assets/traveler_type/place_profiles.json').readAsStringSync()) as Map<String, dynamic>;
  final policy = jsonDecode(File('assets/traveler_type/landmark_eligibility.json').readAsStringSync()) as Map<String, dynamic>;
  data['eligibility_policy'] = policy;
  final catalog = PersonaPlaceCatalog(data);
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }
  for (final tag in (policy['excluded_attributes'] as List).cast<String>()) {
    check(!catalog.isEligibleLandmark('New attraction', [tag, 'Museum']), 'Mixed excluded tag: $tag');
  }
  check(catalog.isEligibleLandmark('Lake Bled', ['Lake']), 'Allowed lake');
  check(catalog.isEligibleLandmark('Alcatraz', ['Island']), 'Allowed island');
  check(!catalog.isEligibleLandmark('Lake Baikal', ['Lake']), 'Excluded lake');
  check(!catalog.isEligibleLandmark('Bali', ['Island']), 'Excluded island');
  check(!catalog.isEligibleLandmark('Bali', []), 'Name-only bypass');
  final names = (policy['excluded_catalog_names'] as List).cast<String>();
  final result = catalog.extract([], [for (final name in names) PersonaLandmarkEvidence(name)]);
  check(result.axes.isEmpty, 'Excluded catalog must provide no axes');
  check(result.evidence['landmark_matched'] == null, 'Excluded catalog matched');
  print('PASS: ${names.length} excluded names contribute no scoring axes; mixed tags and allowlists verified.');
}
