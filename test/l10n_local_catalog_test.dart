// Checks the catalogs built by tool/l10n/build.py (build/l10n) without
// touching Firebase: the download is served from the local build output.
//   python tool/l10n/build.py --check
//   flutter test test/l10n_local_catalog_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/l10n/catalog_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _hangul = RegExp(r'[가-힣]');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Korean built catalog translates new UI text through tr()', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = Directory.systemTemp.createTempSync('l10n_local');
    addTearDown(() => cache.deleteSync(recursive: true));
    AppLocale.store = CatalogStore(
      client: MockClient((request) async {
        final name = Uri.decodeComponent(request.url.pathSegments.last)
            .split('/')
            .last;
        final file = File('build/l10n/$name');
        if (!file.existsSync()) return http.Response('missing $name', 404);
        return http.Response.bytes(file.readAsBytesSync(), 200);
      }),
      directory: () async => cache,
    );
    await AppLocale.instance.load();
    await AppLocale.instance.setLanguage('ko');
    await AppLocale.instance.ready;
    expect(AppLocale.instance.isDownloading, isFalse);

    const samples = [
      'Settings',
      'No email app found. Address copied.',
      'Travel Soulmate',
      'Poll results',
      'Friend invite code',
      'Rarity score',
      'Which country is this flag?',
      'What makes a city memorable to you?',
      'Add friend',
      'Unlock with Premium',
    ];
    final untranslated = <String>[];
    for (final text in samples) {
      final out = tr(text);
      // ignore: avoid_print
      print('$text  ->  $out');
      if (out == text || !_hangul.hasMatch(out)) untranslated.add(text);
    }
    expect(untranslated, isEmpty);

    // Interpolated text is filled from the {n} template.
    final template = tr('Add Alice as a friend?');
    // ignore: avoid_print
    print('Add Alice as a friend?  ->  $template');
    expect(template, contains('Alice'));
    expect(template, matches(_hangul));

    // Every string collected from data structures resolves to Korean unless
    // it is deliberately kept in Latin script (brands, acronyms).
    final extra = (jsonDecode(
      File('tool/l10n/extra_sources.json').readAsStringSync(),
    ) as List).cast<String>();
    final latin = <String>[];
    for (final text in extra) {
      final probe = text.replaceAll(RegExp(r'\{\d+\}'), '1');
      final out = tr(probe);
      if (!_hangul.hasMatch(out)) latin.add(text);
    }
    // ignore: avoid_print
    print('extra_sources: ${extra.length}, without Hangul: ${latin.length}');
    for (final text in latin.take(40)) {
      // ignore: avoid_print
      print('  kept: $text');
    }
    expect(latin.length, lessThan(extra.length ~/ 10));
  });
}
