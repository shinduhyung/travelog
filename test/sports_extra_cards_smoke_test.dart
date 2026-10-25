import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/screens/sports_extra_cards.dart';

void main() {
  testWidgets('sports extra cards render real data', (tester) async {
    final geo = jsonDecode(File('assets/custom.geo.json').readAsStringSync());
    final oly = {
      for (final r in jsonDecode(File('assets/olympics.json').readAsStringSync())['tables'][0]['records'])
        r['dimensions']['iso_a3']: r['values'],
    };
    final countries = <Country>[];
    for (final f in geo['features']) {
      final iso = f['properties']['iso_a3_eh'] ?? f['properties']['iso_a3'];
      if (iso == '-99') continue;
      final o = oly[iso];
      final c = Country.fromJson(
        f as Map<String, dynamic>,
        area: 0, avgTemp: 0, avgPrecipitation: 0, islandCount: 0, coastlineLength: 0,
        lakeCount: 0, elevationHighest: 0, elevationAverage: 0, centroidLat: 0,
        northLat: 0, southLat: 0, capitalLat: 0, countryPopularity: 0,
        summerGold: o?['summer_gold'], summerTotal: o?['summer_total'],
        winterGold: o?['winter_gold'], winterTotal: o?['winter_total'],
      );
      c.populationEst = ((f['properties']['pop_est'] as num?) ?? 0).toInt();
      countries.add(c);
    }
    tester.view.physicalSize = const Size(900, 8000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SportsExtraCards(
            countries: countries,
            visitedCountryNames: {'Spain', 'Japan'},
          ),
        ),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    for (final t in ['FIFA World Ranking', 'Spain', 'Madrid', 'Chess Grandmasters', 'Russia', 'MLB Players Born Abroad', 'Best World Cup Result']) {
      print('$t: ${find.text(t).evaluate().length}');
    }
    expect(find.text('FIFA World Ranking'), findsOneWidget);
    expect(find.text('Formula 1 2026 Calendar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
