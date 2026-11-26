import 'dart:convert';

import 'package:jidoapp/models/visit_date_model.dart';

/// Retired duplicate names. Keep these mappings for existing saved user data.
const landmarkAliases = <String, String>{
  'Luncheon of theLuncheon of thee': 'Lady with an Ermine',
  'Arch of Hadrian (Thessaloniki)': 'Arch of Galerius',
  "John's Incredible Pizza Company (Roseville - Southern California)":
      "John's Incredible Pizza Company (Roseville)",
  'Medersa Ben Youssef': 'Ben Youssef Madrasa',
  'SpeedZone Los Angeles': 'SpeedZone (City of Industry)',
  'Parc Festyland': 'Festyland',
  'Night Safari': 'Mandai Night Safari',
  'Kīlauea Volcano': 'Kilauea',
  'MASP (Sao Paulo Museum of Art)': 'São Paulo Museum of Art',
  'Sé Cathedral': 'Sao Paulo Cathedral',
  'Mercado Municipal': 'Mercado Municipal de Sao Paulo',
  'Stone Forest': 'Shilin Stone Forest',
  // 2026-11-24 landmark audit: merged duplicates and fixed names.
  'Nijmeh Square ': 'Nijmeh Square',
  'Plaza Mayor, Salamance': 'Plaza Mayor, Salamanca',
  'Wieskyrche': 'Wieskirche',
  'Parliament Haus': 'National Parliament House',
  'Sogne River': 'Sognefjord',
  'Simien Lava Desert': 'Danakil Depression',
  'Lujan Basilica': 'Basilica de Lujan',
  'Jefferson Memorial': 'Thomas Jefferson Memorial',
  'Great Market Hall': 'Central Market Hall',
  'Old Arbat Street': 'Arbat Street',
  'Muzeul Național al Satului': 'Village Museum',
  'Ixchel Museum of Indigenous Textiles': 'Museo Ixchel del Traje Indígena',
  'Archiginnasio of Bologna': "Palazzo dell'Archiginnasio anatomical theatre",
  'Golden Hall': 'Golden Roof',
  'Drum and Bell Towers': 'Drum Tower',
  'Binondo': 'Binondo Chinatown',
  'Eureka Tower': 'Melbourne Skydeck',
};

String canonicalLandmarkName(String name) => landmarkAliases[name] ?? name;

String canonicalLandmarkSubLocationKey(String key) {
  for (final entry in landmarkAliases.entries) {
    if (key.startsWith('${entry.key}_')) {
      return '${entry.value}${key.substring(entry.key.length)}';
    }
  }
  return key;
}

Map<String, double> mergeLandmarkRatings(Map<String, double> ratings) {
  final result = <String, double>{};
  // Prefer a positive rating saved under the retained name when both exist.
  for (final entry in ratings.entries) {
    final name = canonicalLandmarkName(entry.key);
    if (entry.value > 0 && (!result.containsKey(name) || entry.key == name)) {
      result[name] = entry.value;
    }
  }
  return result;
}

Map<String, List<VisitDate>> mergeLandmarkVisitHistory(
  Map<String, List<dynamic>> history,
) {
  final result = <String, List<VisitDate>>{};
  final fingerprints = <String, Set<String>>{};
  final entries = history.entries.toList()
    ..sort(
      (a, b) => (landmarkAliases.containsKey(a.key) ? 1 : 0).compareTo(
        landmarkAliases.containsKey(b.key) ? 1 : 0,
      ),
    );
  for (final entry in entries) {
    final name = canonicalLandmarkName(entry.key);
    final visits = result.putIfAbsent(name, () => []);
    final seen = fingerprints.putIfAbsent(name, () => <String>{});
    // Only remove copies across different names, never repeated entries within
    // one name: those may be intentional visits without dates or notes.
    final previousNames = Set<String>.of(seen);
    for (final raw in entry.value) {
      final visit = VisitDate.fromJson(Map<String, dynamic>.from(raw as Map));
      final fingerprint = jsonEncode(visit.toJson());
      if (!previousNames.contains(fingerprint)) visits.add(visit);
      seen.add(fingerprint);
    }
  }
  return result;
}
