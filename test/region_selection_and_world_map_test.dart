// Google Fonts test hook prevents network/font downloads in widget tests.
// ignore_for_file: implementation_imports
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/models/admin_region.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/screens/country_selection_screen.dart';
import 'package:jidoapp/screens/countries_map_screen.dart';
import 'package:jidoapp/services/ad_service.dart';
import 'package:jidoapp/services/admin_region_repository.dart';
import 'package:jidoapp/widgets/country_region_dropdown.dart';
import 'package:jidoapp/widgets/visited_world_map_layer.dart';
import 'package:latlong2/latlong.dart';

class _FontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
  ].map((w) => 'test-fonts/Poppins-$w.ttf').toList();
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

class _Country implements Country {
  @override
  final String name;
  @override
  final String isoA2;
  @override
  final String isoA3;
  @override
  final String continent = 'North America';
  @override
  final String subregion = 'Northern America';
  @override
  final List<List<List<LatLng>>> polygonsData = [
    [
      [
        const LatLng(25, -125),
        const LatLng(25, -66),
        const LatLng(49, -66),
        const LatLng(49, -125),
        const LatLng(25, -125),
      ],
    ],
  ];
  _Country(this.name, this.isoA2, this.isoA3);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Countries extends ChangeNotifier implements CountryProvider {
  @override
  final List<Country> allCountries;
  _Countries([this.allCountries = const []]);
  @override
  bool get isLoading => false;
  @override
  String? get homeCountryIsoA3 => null;
  @override
  Map<String, Color> get continentColors => {'North America': Colors.blue};
  @override
  Map<String, Color> get subregionColors => {'Northern America': Colors.green};
  @override
  final Set<String> visitedCountries = {};
  @override
  final Map<String, VisitDetails> visitDetails = {};
  @override
  void setVisitedStatus(String name, bool visited) {
    if (visited) {
      visitedCountries.add(name);
    } else {
      visitedCountries.remove(name);
    }
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Visits extends ChangeNotifier implements SubregionProvider {
  final Set<String> keys = {};
  int saves = 0;
  @override
  bool get isLoading => false;
  @override
  bool isRegionVisited(String iso, AdminRegion region) =>
      keys.contains('$iso:${region.stableKey}');
  @override
  void setRegionVisits(Map<String, Map<AdminRegion, bool>> changes) {
    saves++;
    for (final c in changes.entries) {
      for (final r in c.value.entries) {
        final key = '${c.key}:${r.key.stableKey}';
        if (r.value) {
          keys.add(key);
        } else {
          keys.remove(key);
        }
      }
    }
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settleData(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    // No timers, ads, Firebase initialization or real account writes.
    AdService.instance.setUiOverlayActive();
    fonts.assetManifest = _FontManifest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key.startsWith('test-fonts/')) return ByteData(0);
          return null;
        });
  });

  for (final apply in [true, false]) {
    testWidgets(
      'country region dropdown ${apply ? "applies" : "cancels"} only its draft',
      (tester) async {
        // Preload with the real bundle; font-only mock is temporarily removed.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
        await tester.runAsync(() => AdminRegionRepository.loadAll());
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (message) async {
              return ByteData(0);
            });
        final country = _Country('United States', 'US', 'USA');
        final countries = _Countries();
        final visits = _Visits();
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CountryProvider>.value(value: countries),
              ChangeNotifierProvider<SubregionProvider>.value(value: visits),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CountrySelectionScreen(
                          allCountries: [country],
                          scrollController: scroll,
                          groupBy: GroupBy.continent,
                        ),
                      ),
                    ),
                    child: const Text('Open selection'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open selection'));
        await _settleData(tester);
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.byIcon(Icons.favorite_border), findsNothing);
        await tester.tap(find.byKey(const ValueKey('regions-USA')));
        await _settleData(tester);
        expect(find.byType(CountryRegionDropdown), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byType(CountryRegionDropdown),
            matching: find.byType(TextField),
          ),
          'California',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        expect(visits.keys, isEmpty);
        expect(countries.visitedCountries, isEmpty);
        expect(find.text('1 / 51 regions selected'), findsOneWidget);
        await tester.tap(find.text(apply ? 'Apply Changes' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(visits.keys, apply ? contains('USA:US-CA') : isEmpty);
        expect(visits.saves, apply ? 1 : 0);
        expect(countries.visitedCountries, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'world map switches country fill to independently visited region fill',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      final regions = await tester.runAsync(
        () => AdminRegionRepository.regionsFor('US'),
      );
      final california = regions!.firstWhere((r) => r.iso31662 == 'US-CA');
      final visits = _Visits();
      var showRegions = false;
      late StateSetter change;
      final country = _Country('United States', 'US', 'USA');
      await tester.pumpWidget(
        ChangeNotifierProvider<SubregionProvider>.value(
          value: visits,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return Scaffold(
                  body: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(20, 0),
                      initialZoom: 0.3,
                      interactionOptions: InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      VisitedWorldMapLayer(
                        countries: [country],
                        visitedCountries: const {'United States'},
                        continentColors: const {'North America': Colors.blue},
                        showRegions: showRegions,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<PolygonLayer>(find.byType(PolygonLayer))
            .polygons
            .single
            .color,
        Colors.blue,
      );
      change(() => showRegions = true);
      await _settleData(tester);
      var polygons = tester
          .widget<PolygonLayer>(find.byType(PolygonLayer))
          .polygons;
      expect(polygons.first.color, isNot(Colors.blue));
      expect(polygons.skip(1).where((p) => p.color == Colors.blue), isEmpty);
      visits.setRegionVisits({
        'USA': {california: true},
      });
      await tester.pumpAndSettle();
      polygons = tester
          .widget<PolygonLayer>(find.byType(PolygonLayer))
          .polygons;
      expect(
        polygons.skip(1).where((p) => p.color == Colors.blue).length,
        california.polygonsData.length,
      );
      change(() => showRegions = false);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PolygonLayer>(find.byType(PolygonLayer))
            .polygons
            .single
            .color,
        Colors.blue,
      );
      expect(visits.keys, contains('USA:US-CA'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsupported territory dropdown has no misleading checkboxes', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    await tester.runAsync(() => AdminRegionRepository.regionsFor('VA'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountryRegionDropdown(
            countryIsoA2: 'VA',
            color: Colors.teal,
            isVisited: (_) => false,
            onChanged: (_, __) {},
          ),
        ),
      ),
    );
    await _settleData(tester);
    expect(
      find.textContaining('Subdivision boundaries are unavailable'),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsNothing);
  });
  testWidgets(
    'full world map toggles regions with switch immediately left of settings',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      final regions = await tester.runAsync(
        () => AdminRegionRepository.regionsFor('US'),
      );
      final california = regions!.firstWhere((r) => r.iso31662 == 'US-CA');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (_) async => ByteData(0));
      SharedPreferences.setMockInitialValues({'showCountriesLegend': false});
      final visits = _Visits()
        ..setRegionVisits({
          'USA': {california: true},
        });
      final countries = _Countries([_Country('United States', 'US', 'USA')]);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CountryProvider>.value(value: countries),
            ChangeNotifierProvider<SubregionProvider>.value(value: visits),
          ],
          child: const MaterialApp(home: CountriesMapScreen()),
        ),
      );
      await _settleData(tester);
      final change = find.byTooltip('Show visited regions');
      final settings = find.byTooltip('Settings');
      expect(
        tester.getCenter(change).dx,
        lessThan(tester.getCenter(settings).dx),
      );
      expect(
        tester
            .widget<PolygonLayer>(find.byType(PolygonLayer))
            .polygons
            .single
            .color,
        isNot(Colors.blue),
      );
      await tester.tap(change);
      await _settleData(tester);
      expect(find.byType(VisitedWorldMapLayer), findsOneWidget);
      expect(
        tester
            .widget<PolygonLayer>(find.byType(PolygonLayer))
            .polygons
            .where((p) => p.color == Colors.blue)
            .length,
        california.polygonsData.length,
      );
      expect(
        tester
                .widget<FlutterMap>(find.byType(FlutterMap))
                .options
                .interactionOptions
                .flags &
            InteractiveFlag.drag,
        isNot(0),
      );
      await tester.tap(find.byTooltip('Show visited countries'));
      await _settleData(tester);
      expect(find.byType(VisitedWorldMapLayer), findsNothing);
      expect(
        tester.widget<PolygonLayer>(find.byType(PolygonLayer)).polygons,
        hasLength(1),
      );
      expect(visits.keys, contains('USA:US-CA'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('world map can open directly in inherited regional mode', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    final regions = await tester.runAsync(
      () => AdminRegionRepository.regionsFor('US'),
    );
    final california = regions!.firstWhere((r) => r.iso31662 == 'US-CA');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (_) async => ByteData(0));
    SharedPreferences.setMockInitialValues({'showCountriesLegend': false});
    final visits = _Visits()
      ..setRegionVisits({
        'USA': {california: true},
      });
    final countries = _Countries([_Country('United States', 'US', 'USA')]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CountryProvider>.value(value: countries),
          ChangeNotifierProvider<SubregionProvider>.value(value: visits),
        ],
        child: const MaterialApp(
          home: CountriesMapScreen(initialShowRegions: true),
        ),
      ),
    );
    await _settleData(tester);
    expect(find.byType(VisitedWorldMapLayer), findsOneWidget);
    expect(find.byTooltip('Show visited countries'), findsOneWidget);
    expect(
      tester
          .widget<PolygonLayer>(find.byType(PolygonLayer))
          .polygons
          .where((p) => p.color == Colors.blue)
          .length,
      california.polygonsData.length,
    );
    expect(tester.takeException(), isNull);
  });
}
