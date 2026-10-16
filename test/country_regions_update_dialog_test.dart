import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/models/admin_region.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/visit_details_model.dart';
import 'package:jidoapp/providers/auth_provider.dart' as app;
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/screens/countries_menu_screen.dart';
import 'package:jidoapp/screens/countrydex_screen.dart';
import 'package:jidoapp/services/ad_service.dart';
import 'package:jidoapp/services/admin_region_repository.dart';
import 'package:jidoapp/services/country_regions_notice_service.dart';
import 'package:jidoapp/widgets/country_regions_update_dialog.dart';
import 'package:jidoapp/widgets/visited_world_map_layer.dart';

class _User implements User {
  @override
  final String uid = 'existing-account';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements app.AuthProvider {
  @override
  User? get user => _User();
  @override
  bool get isAuthReady => true;
  @override
  bool get isSigningIn => false;
  @override
  bool get isHandlingLoginAction => false;
  @override
  bool get isNewAccountForRegionsUpdate => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Countries extends ChangeNotifier implements CountryProvider {
  @override
  bool get isLoading => false;
  @override
  List<Country> get allCountries => [];
  @override
  List<Country> get filteredCountries => [];
  @override
  Set<String> get visitedCountries => {};
  @override
  Set<String> get wishlistedCountries => {};
  @override
  Map<String, Color> get continentColors => {};
  @override
  Map<String, VisitDetails> get visitDetails => {};
  @override
  String? get homeCountryIsoA3 => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Visits extends ChangeNotifier implements SubregionProvider {
  @override
  bool isRegionVisited(String iso, AdminRegion region) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store implements CountryRegionsNoticeStore {
  int claims = 0;
  bool seen = false;
  @override
  Future<bool> isPending(String uid) async => !seen;
  @override
  Future<bool> claim(String uid, String token, bool Function() canShow) async {
    claims++;
    if (seen || !canShow()) return false;
    seen = true;
    return true;
  }

  @override
  Future<void> release(String uid, String token) async => seen = false;
}

Future<void> _pumpAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final first in ['map', 'countrydex']) {
    testWidgets(
      '$first tap introduces feature then runs original action; both NEW badges disappear',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        AdService.instance.setTutorialActive();
        await tester.runAsync(() => AdminRegionRepository.loadAll());
        final store = _Store();
        var active = false;
        late StateSetter setActive;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<app.AuthProvider>.value(value: _Auth()),
              ChangeNotifierProvider<CountryProvider>.value(
                value: _Countries(),
              ),
              ChangeNotifierProvider<SubregionProvider>.value(value: _Visits()),
            ],
            child: MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  setActive = setState;
                  return CountriesMenuScreen(
                    isActive: active,
                    regionsNoticeService: CountryRegionsNoticeService(
                      store: store,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await _pumpAsync(tester);
        expect(store.claims, 0);
        expect(find.byType(CountryRegionsUpdateDialog), findsNothing);
        setActive(() => active = true);
        await _pumpAsync(tester);
        expect(
          store.claims,
          0,
        ); // Entering Countries is passive, never a claim/show.
        expect(find.byType(CountryRegionsUpdateDialog), findsNothing);
        expect(find.byKey(const ValueKey('regions-new-map')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('regions-new-countrydex')),
          findsOneWidget,
        );
        if (first == 'countrydex') {
          await tester.tap(find.byKey(const ValueKey('stat-category-1')));
          await tester.pump();
          expect(find.text('General'), findsOneWidget);
        }
        await tester.tap(
          find.byKey(
            ValueKey(first == 'map' ? 'change-map-mode' : 'stat-category-0'),
          ),
        );
        await _pumpAsync(tester);
        expect(store.claims, 1);
        expect(find.byType(CountryRegionsUpdateDialog), findsOneWidget);
        expect(
          tester
              .widget<VisitedWorldMapLayer>(find.byType(VisitedWorldMapLayer))
              .showRegions,
          isFalse,
        );
        if (first == 'countrydex') expect(find.text('General'), findsOneWidget);
        await tester.tap(find.text('Got it'));
        await _pumpAsync(tester);
        expect(find.byType(CountryRegionsUpdateDialog), findsNothing);
        expect(find.byKey(const ValueKey('regions-new-map')), findsNothing);
        expect(
          find.byKey(const ValueKey('regions-new-countrydex')),
          findsNothing,
        );
        if (first == 'map') {
          expect(
            tester
                .widget<VisitedWorldMapLayer>(find.byType(VisitedWorldMapLayer))
                .showRegions,
            isTrue,
          );
          await tester.tap(find.byKey(const ValueKey('stat-category-0')));
          await _pumpAsync(tester);
        } else {
          expect(find.text('CountryDex'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('change-map-mode')));
          await _pumpAsync(tester);
          expect(
            tester
                .widget<VisitedWorldMapLayer>(find.byType(VisitedWorldMapLayer))
                .showRegions,
            isTrue,
          );
        }
        expect(
          store.claims,
          1,
        ); // The other feature consumes the same acknowledgment.
        expect(find.byType(CountryRegionsUpdateDialog), findsNothing);
        await tester.tap(find.byKey(const ValueKey('open-detailed-stats')));
        await _pumpAsync(tester);
        expect(find.byType(CountryDexScreen), findsOneWidget);
        expect(find.byType(CountryRegionsUpdateDialog), findsNothing);
        expect(store.claims, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
