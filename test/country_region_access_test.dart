import 'dart:async';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/services/country_region_access.dart';
import 'package:jidoapp/services/admin_region_repository.dart';
import 'package:jidoapp/widgets/country_region_access_gate.dart';
import 'package:jidoapp/widgets/country_region_dropdown.dart';

class _UnavailableStore extends InAppPurchasePlatform {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override
  Future<bool> isAvailable() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'free countries exactly match the original 30-country data manifest',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('assets/admin1_coverage.json'))
              as Map<String, dynamic>;
      expect(CountryRegionAccess.freeCountryCodes, hasLength(30));
      expect(
        CountryRegionAccess.freeCountryCodes,
        unorderedEquals(manifest['legacy_countries'] as List),
      );
      for (final iso in CountryRegionAccess.freeCountryCodes) {
        expect(CountryRegionAccess.canAccess(iso, isPremium: false), isTrue);
      }
      expect(CountryRegionAccess.canAccess('us', isPremium: false), isTrue);
      expect(CountryRegionAccess.canAccess('NP', isPremium: false), isFalse);
      for (final iso in (manifest['countries'] as Map).keys.cast<String>()) {
        expect(CountryRegionAccess.canAccess(iso, isPremium: true), isTrue);
      }
    },
  );
  testWidgets(
    'locked gate does not build region content and explains upgrade',
    (tester) async {
      var built = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountryRegionAccessGate(
              countryIsoA2: 'NP',
              builder: (_) {
                built = true;
                return const Text('Private regions');
              },
            ),
          ),
        ),
      );
      expect(built, isFalse);
      expect(find.text('Private regions'), findsNothing);
      await tester.tap(find.text('Get Premium'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock more regions'), findsOneWidget);
      expect(find.textContaining('original 30 countries'), findsNWidgets(2));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(built, isFalse);
    },
  );
  testWidgets('original country content stays free', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountryRegionAccessGate(
            countryIsoA2: 'KR',
            builder: (_) => const Text('Free regions'),
          ),
        ),
      ),
    );
    expect(find.text('Free regions'), findsOneWidget);
    expect(find.text('Get Premium'), findsNothing);
  });
  testWidgets(
    'premium country dropdown exposes no search or visit checkboxes',
    (tester) async {
      await tester.runAsync(() => AdminRegionRepository.regionsFor('NP'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountryRegionDropdown(
              countryIsoA2: 'NP',
              color: Colors.teal,
              isVisited: (_) => false,
              onChanged: (_, __) => fail('Locked region was changed'),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Premium regions'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets('premium restore unlocks content and expiry locks it again', (
    tester,
  ) async {
    // A fake unavailable store prevents all real store calls and purchases.
    final sub = SubscriptionService.instance;
    final originalStore = InAppPurchasePlatform.instance;
    InAppPurchasePlatform.instance = _UnavailableStore();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountryRegionAccessGate(
              countryIsoA2: 'NP',
              builder: (_) => const Text('Unlocked Nepal'),
            ),
          ),
        ),
      );
      expect(find.text('Unlocked Nepal'), findsNothing);
      SharedPreferences.setMockInitialValues({
        'is_premium': true,
        'active_product_id': 'travelog_premium_monthly',
      });
      await sub.initialize();
      await tester.pumpAndSettle();
      expect(find.text('Unlocked Nepal'), findsOneWidget);
      expect(find.text('Get Premium'), findsNothing);
      SharedPreferences.setMockInitialValues({'is_premium': false});
      await sub.initialize();
      await tester.pumpAndSettle();
      expect(find.text('Unlocked Nepal'), findsNothing);
      expect(find.text('Premium regions'), findsOneWidget);
    } finally {
      SharedPreferences.setMockInitialValues({'is_premium': false});
      await sub.initialize();
      InAppPurchasePlatform.instance = originalStore;
    }
  });
}
