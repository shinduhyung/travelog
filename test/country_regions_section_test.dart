import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/models/admin_region.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/services/admin_region_repository.dart';
import 'package:jidoapp/widgets/country_regions_section.dart';

// These UI tests do not initialize Firebase or touch actual account records.
class _Visits extends ChangeNotifier implements SubregionProvider {
  @override
  bool isRegionVisited(String countryIsoA3, AdminRegion region) => false;
  @override
  int visitedRegionCount(String countryIsoA3, Iterable<AdminRegion> regions) =>
      0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Country implements Country {
  @override
  final String name;
  @override
  final String isoA2;
  @override
  final String isoA3;
  _Country(this.name, this.isoA2, this.isoA3);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _screen(Country country, _Visits visits) {
  return ChangeNotifierProvider<SubregionProvider>.value(
    value: visits,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CountryRegionsSection(
            country: country,
            themeColor: Colors.teal,
            header: const Text('Regions'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'new country requires premium and hides its region map and controls',
    (tester) async {
      final regions = await tester.runAsync(
        () => AdminRegionRepository.regionsFor('NP'),
      );
      expect(regions, isNotEmpty);
      final visits = _Visits();
      await tester.pumpWidget(_screen(_Country('Nepal', 'NP', 'NPL'), visits));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Premium regions'), findsOneWidget);
      expect(find.textContaining('regions visited'), findsNothing);
      expect(find.byTooltip('Region list'), findsNothing);
      expect(find.byTooltip('Full screen'), findsNothing);
      await tester.tap(find.text('Get Premium'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock more regions'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Map data sources'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'whole-area fallback explains missing boundaries without visit counts',
    (tester) async {
      final regions = await tester.runAsync(
        () => AdminRegionRepository.regionsFor('VA'),
      );
      expect(regions, isNotEmpty);
      final visits = _Visits();
      await tester.pumpWidget(
        _screen(_Country('Vatican', 'VA', 'VAT'), visits),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Subdivision boundaries are unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('regions visited'), findsNothing);
      expect(find.byTooltip('Region list'), findsNothing);
      expect(find.byTooltip('Full screen'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
