// Live check against Firebase Storage. Not part of the regular suite:
//   flutter test test/l10n_live_firebase_test.dart --tags live --run-skipped
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/l10n/catalog_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Korean downloads from Firebase Storage and is cached', () async {
    // flutter_test blocks real HTTP by default.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    final cache = Directory.systemTemp.createTempSync('l10n_live');
    addTearDown(() => cache.deleteSync(recursive: true));
    final client = HttpClient();
    AppLocale.store = CatalogStore(
      client: IOClient(client),
      directory: () async => cache,
    );
    await AppLocale.instance.load();

    final watch = Stopwatch()..start();
    await AppLocale.instance.setLanguage('ko');
    expect(AppLocale.instance.isDownloading, isTrue);
    expect(tr('Settings'), 'Settings'); // English until the download lands
    await AppLocale.instance.ready;
    // ignore: avoid_print
    print('download took ${watch.elapsedMilliseconds} ms');

    expect(AppLocale.instance.isDownloading, isFalse);
    expect(tr('Settings'), '설정');
    expect(tr('Top Cities'), '인기 도시');
    expect(AppLocale.instance.countryName('United States'), '미국');
    final saved = File(
      '${cache.path}/l10n/${AppLocale.instance.current.entry['file']}',
    );
    expect(saved.existsSync(), isTrue);

    // A restart uses the saved copy: no catalog download, works offline.
    AppLocale.store = CatalogStore(
      client: IOClient(HttpClient()..connectionTimeout = Duration.zero),
      directory: () async => cache,
    );
    await AppLocale.instance.load();
    expect(AppLocale.instance.isDownloading, isFalse);
    expect(tr('Settings'), '설정');
  });
}
