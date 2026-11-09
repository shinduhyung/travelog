import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app_localizations.dart';

/// Debug-only hook for tool/l10n/overflow_audit: switches the app language in
/// place, so one visit to a screen can be checked in every language.
///
/// The driver writes a language code to `<app support>/l10n_audit_cmd` (via
/// `adb shell run-as`). The app applies it, reassembles so every RenderFlex
/// reports its overflow again, and logs `[AUDIT] ready <code>`.
class L10nAudit {
  static Timer? _timer;

  static Future<void> start() async {
    if (!kDebugMode || kIsWeb || _timer != null) return;
    AppLocale.keepCatalogs = true;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/l10n_audit_cmd');
    var busy = false;
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      if (busy || !file.existsSync()) return;
      busy = true;
      try {
        final code = file.readAsStringSync().trim();
        file.deleteSync();
        // "max" = the longest translation of each string across all languages
        // (tool/l10n/overflow_audit/make_max.py), pushed as l10n_audit_max.json.
        if (code == 'max') {
          final max = File('${dir.path}/l10n_audit_max.json').readAsStringSync();
          await AppLocale.instance.debugShowCatalog(
            'de',
            jsonDecode(max) as Map<String, dynamic>,
          );
        } else {
          AppLocale.instance.debugForgetCatalog();
          await AppLocale.instance.setLanguage(code);
        }
        await WidgetsBinding.instance.reassembleApplication();
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await WidgetsBinding.instance.endOfFrame;
        debugPrint('[AUDIT] ready $code');
      } catch (error) {
        debugPrint('[AUDIT] error $error');
      } finally {
        busy = false;
      }
    });
  }
}
