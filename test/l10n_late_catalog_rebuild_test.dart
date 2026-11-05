// A catalog that arrives after the first frame (first launch, or the first
// launch after a new catalog was published) must update screens that were
// already built, including `const` tabs kept alive in an IndexedStack.
//   python tool/l10n/build.py --check
//   flutter test test/l10n_late_catalog_rebuild_test.dart
// Requires AppLocale.englishOnly == false while it runs.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/l10n/catalog_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same pattern as the real tabs: depends on the locale, never on AppLocale.
class _Tab extends StatefulWidget {
  const _Tab();
  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Text(tr('Settings'), textDirection: TextDirection.ltr);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('already-built const tab shows Korean once the catalog lands',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app_language': 'ko'});
    final cache = Directory.systemTemp.createTempSync('l10n_late');
    addTearDown(() => cache.deleteSync(recursive: true));
    AppLocale.store = CatalogStore(
      client: MockClient((request) async {
        final name = Uri.decodeComponent(request.url.pathSegments.last)
            .split('/')
            .last;
        final file = File('build/l10n/$name');
        if (!file.existsSync()) return http.Response('missing', 404);
        return http.Response.bytes(file.readAsBytesSync(), 200);
      }),
      directory: () async => cache,
    );

    await tester.runAsync(() => AppLocale.instance.load());
    // Korean is selected but its catalog is not here yet: English first.
    expect(AppLocale.instance.isDownloading, isTrue);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: AppLocale.instance,
        builder: (context, _) => MaterialApp(
          locale: AppLocale.instance.locale,
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(body: _Tab()),
        ),
      ),
    );
    expect(find.text('Settings'), findsOneWidget);

    await tester.runAsync(() => AppLocale.instance.ready);
    await tester.pumpAndSettle();

    expect(AppLocale.instance.isDownloading, isFalse);
    expect(find.text('설정'), findsOneWidget);
  });
}
