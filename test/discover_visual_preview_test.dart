import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/widgets/discover_scaffold.dart';
import 'package:jidoapp/widgets/country_twin_result.dart';
import 'package:jidoapp/widgets/traveler_type_result.dart';
import 'package:jidoapp/widgets/tourist_footprint_result.dart';
import 'package:jidoapp/services/tourist_local_model.dart';

void main() {
  setUpAll(() async {
    final artifactRoot = File(Platform.resolvedExecutable).parent.parent.parent.path;
    final fonts = FontLoader('Roboto');
    for (final name in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']) {
      final bytes = File('$artifactRoot/material_fonts/$name').readAsBytesSync();
      fonts.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(Future.value(ByteData.sublistView(File('build/app/intermediates/flutter/debug/flutter_assets/fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
    await icons.load();
  });
  final sample = <String, dynamic>{
    'summary': {'persona_scores': [
      {'id': 'inner_sanctuary_seeker', 'label': 'Inner Sanctuary Seeker', 'score': .498},
      {'id': 'cultural_decoder', 'label': 'Cultural Decoder', 'score': .15},
      {'id': 'sensory_immersionist', 'label': 'Sensory Immersionist', 'score': .10},
      {'id': 'wildlife_earth_enthusiast', 'label': 'Wildlife & Earth Enthusiast', 'score': .08},
      {'id': 'freedom_drifter', 'label': 'Freedom Drifter', 'score': .05},
      {'id': 'identity_seeker', 'label': 'Identity Seeker', 'score': .04},
      {'id': 'joy_collector', 'label': 'Joy Collector', 'score': .03},
      {'id': 'global_connector', 'label': 'Global Connector', 'score': .02},
      {'id': 'achievement_hunter', 'label': 'Achievement Hunter', 'score': .02},
      {'id': 'efficiency_maximizer', 'label': 'Efficiency Maximizer', 'score': .012},
    ]},
    'full_feature_vector': {'solo_social': .8, 'nature_culture': .7, 'relaxed_intensive': .9,
      'planned_spontaneous': .6, 'budget_luxury': .2},
  };
  final footprint = TouristLocalResult(58.6, const [
    TouristCityVisit('Venice', 10, 1, country: 'IT'),
    TouristCityVisit('Paris', 7, 2, country: 'FR'),
    TouristCityVisit('Kyoto', 5, 1, country: 'JP'),
    TouristCityVisit('Seoul', 2, 3, country: 'KR'),
  ], 6, percentiles: {'Venice': .9, 'Paris': .75, 'Kyoto': .55, 'Seoul': .25});

  for (final width in [360.0, 430.0]) {
    testWidgets('Inspect traveler and footprint at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final entry in <String, Widget>{
        'twin': CountryTwinResult(match: {'similarity': .879, 'shared': 12, 'countries': ['FR','IT','JP','KR','GB','DE','US','CA'], 'cities': ['Paris', 'Kyoto', 'Seoul'], 'landmarks': ['Eiffel Tower', 'An unusually long landmark name to verify wrapping'], 'unesco': ['Historic Centre of Rome'], 'badgeScore': 213, 'badgeCount': 103}, names: const {'FR':'France','IT':'Italy','JP':'Japan','KR':'South Korea'}, mine: const ['FR','IT','JP','KR','GB','DE','US','CA']),
        'traveler': TravelerTypeResult(analysis: sample),
        'footprint': TouristFootprintResult(result: footprint),
      }.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true, colorSchemeSeed: const Color(0xFF3DDAD7)),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24, bottom: 32),
            viewPadding: const EdgeInsets.only(top: 24, bottom: 32)), child: child!),
          home: RepaintBoundary(key: key, child: DiscoverScaffold(
            appBar: AppBar(title: Text(entry.key == 'traveler' ? 'Traveler Type AI' : entry.key == 'twin' ? 'Your Country Twin' : 'Tourist vs Local')),
            body: entry.key == 'twin' ? entry.value : ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [entry.value]),
          )),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('tool/persona_validation/out/${entry.key}_preview_${width.toInt()}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
