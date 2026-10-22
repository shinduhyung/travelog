import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'catalog_store.dart';

/// Display-only translation. Never use translated strings as database keys,
/// filter values, country identifiers, or persisted entity names.
T tr<T extends String?>(T value, {Iterable<String> entities = const []}) =>
    value == null
    ? value
    : AppLocale.instance.translateKeepingEntities(value, entities) as T;

/// Cabin labels share English words with economics; keep their display context
/// explicit while persisting the original cabin value.
String trSeatClass(String? value) {
  if (value == null) return tr('Unknown');
  if (AppLocale.instance.isEnglish) return value;
  return tr(value == 'Economy' ? 'Economy Class' : value);
}

/// A display language. English is the source language and needs no catalog;
/// every other language is listed in the manifest tool/l10n/build.py writes.
class AppLanguage {
  const AppLanguage(this.code, this.name, this.englishName, [this.entry = const {}]);
  final String code;
  final String name;
  final String englishName;

  /// The manifest entry: catalog file name, checksum, bundled flag.
  final Map<String, dynamic> entry;

  /// Codes follow BCP 47 subtags: `ko`, `zh-Hant`, `pt-BR`.
  Locale get locale {
    final parts = code.split('-');
    return Locale.fromSubtags(
      languageCode: parts.first,
      scriptCode: parts.length > 1 && parts[1].length == 4 ? parts[1] : null,
      countryCode: parts.length > 1 && parts[1].length == 2 ? parts[1] : null,
    );
  }
}

class AppLocale extends ChangeNotifier with WidgetsBindingObserver {
  AppLocale._();
  static final instance = AppLocale._();
  static final _latinLetters = RegExp('[A-Za-z]');
  static const preferenceKey = 'app_language';
  static const english = AppLanguage('en', 'English', 'English');
  static List<Locale> get supportedLocales =>
      [for (final language in instance._languages) language.locale];

  List<AppLanguage> _languages = const [english];
  List<AppLanguage> get languages => _languages;
  String? _language;
  String? get language => _language;
  String get code => _language ?? _deviceLanguage;
  bool get isEnglish => code == english.code;
  AppLanguage get current =>
      _languages.firstWhere((l) => l.code == code, orElse: () => english);
  Locale get locale => current.locale;
  String get _deviceLanguage {
    for (final device in WidgetsBinding.instance.platformDispatcher.locales) {
      for (final language in _languages) {
        final candidate = language.locale;
        if (candidate.languageCode != device.languageCode) continue;
        // zh-Hant must not be picked for a simplified-Chinese device.
        if (candidate.scriptCode != null &&
            device.scriptCode != null &&
            candidate.scriptCode != device.scriptCode) {
          continue;
        }
        return language.code;
      }
    }
    return english.code;
  }

  String? _catalogCode;
  Map<String, String> _messages = {};
  Map<String, String> _countries = {};
  Map<String, String> _caseFolded = {};
  final _templates = <(RegExp, String)>[];
  final _cache = <String, String>{};

  /// Replaceable in tests to serve catalogs without the network.
  static CatalogStore store = CatalogStore();
  Map<String, dynamic> _manifest = const {};
  final _downloads = <String, Future<void>>{};

  /// True while the selected language is still being downloaded; the UI
  /// shows English until then.
  bool get isDownloading => !isEnglish && _catalogCode != code;

  /// Completes once a pending download for the current language settles.
  Future<void> get ready => _downloads[code] ?? Future.value();

  Future<void> load() async {
    _catalogCode = null;
    _setManifest(await store.manifest());
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(preferenceKey);
    _language = _languages.any((l) => l.code == saved) ? saved : null;
    await initializeDateFormatting();
    await _loadCatalog();
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    // Picks up new languages and translation fixes without an app update.
    unawaited(_refreshManifest());
  }

  void _setManifest(Map<String, dynamic> manifest) {
    _manifest = manifest;
    _languages = [
      english,
      for (final entry
          in (manifest['languages'] as List).cast<Map<String, dynamic>>())
        AppLanguage(
          entry['code'] as String,
          entry['name'] as String,
          entry['english_name'] as String,
          entry,
        ),
    ];
  }

  Future<void> _refreshManifest() async {
    final newer = await store.refreshManifest(_manifest);
    if (newer == null) return;
    final before = current.entry['file'];
    _setManifest(newer);
    if (current.entry['file'] != before) _catalogCode = null;
    await _loadCatalog();
    notifyListeners();
  }

  /// Loads only the active language's catalog; the files are several MB each.
  /// Uses the saved or bundled copy if there is one, otherwise shows English
  /// and downloads in the background.
  Future<void> _loadCatalog() async {
    final target = code;
    Intl.defaultLocale = locale.languageCode;
    if (target == _catalogCode) return;
    if (target == english.code) {
      _applyCatalog(target, const {});
      return;
    }
    final language = current;
    final local = await store.local(language.entry);
    if (target != code) return; // The language changed while loading.
    if (local != null) {
      _applyCatalog(target, local);
      return;
    }
    _applyCatalog(null, const {});
    unawaited(_download(language));
  }

  Future<void> _download(AppLanguage language) =>
      _downloads[language.code] ??= () async {
        try {
          final catalog = await store.fetch(_manifest, language.entry);
          if (catalog == null || language.code != code) return;
          _applyCatalog(language.code, catalog);
          notifyListeners();
        } finally {
          _downloads.remove(language.code);
        }
      }();

  void _applyCatalog(String? target, Map<String, dynamic> catalog) {
    Map<String, String> strings(Object? map) =>
        map == null ? {} : Map<String, String>.from(map as Map);
    _messages = strings(catalog['messages']);
    _countries = strings(catalog['countries']);
    _catalogCode = target;
    _caseFolded = {
      for (final entry in _messages.entries)
        entry.key.toLowerCase(): entry.value,
      for (final entry in _countries.entries)
        entry.key.toLowerCase(): entry.value,
    };
    _templates.clear();
    _cache.clear();
    // Longest literal text first, so the most specific template wins. Only
    // template keys are sorted, and each length is computed once: sorting all
    // ~40k messages with a regex in the comparator took over ten seconds.
    final placeholder = RegExp(r'\{\d+\}');
    final entries = [
      for (final entry in _messages.entries)
        if (entry.key.contains('{0}'))
          (entry, entry.key.replaceAll(placeholder, '').length),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    for (final (entry, _) in entries) {
      final parts = entry.key.split(placeholder);
      // A literal anchor is required: a template must never translate arbitrary
      // entity names or user-written content.
      if (parts.join().trim().length < 3) continue;
      final pattern = parts.map(RegExp.escape).join('(.*?)');
      _templates.add((RegExp('^$pattern\$', dotAll: true), entry.value));
    }
  }

  Future<void> setLanguage(String? language) async {
    if (language != null && !_languages.any((l) => l.code == language)) {
      throw ArgumentError.value(
        language,
        'language',
        'Unsupported app language',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    if (language == null) {
      await prefs.remove(preferenceKey);
    } else {
      await prefs.setString(preferenceKey, language);
    }
    _language = language;
    await _loadCatalog();
    notifyListeners();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_language == null) _loadCatalog().then((_) => notifyListeners());
  }

  bool matchesCountry(String name, String query) {
    final search = query.trim().toLowerCase();
    // Extra search terms for localized names that people type differently.
    const aliases = {
      '대한민국': ['한국', '남한'],
      '조선민주주의인민공화국': ['북한', '북조선'],
      '북한': ['북조선', '조선민주주의인민공화국'],
      '미국': ['미합중국'],
      '중국': ['중화인민공화국'],
      '대만': ['타이완', '중화민국'],
    };
    final localized = _countries[name];
    return name.toLowerCase().contains(search) ||
        (localized?.toLowerCase().contains(search) ?? false) ||
        (aliases[localized]?.any((alias) => alias.contains(search)) ?? false);
  }

  String countryName(String name) =>
      isEnglish ? name : (_countries[name] ?? name);

  String translateKeepingEntities(String value, Iterable<String> entities) {
    if (entities.isEmpty) return translate(value);
    final names = entities.where((name) => name.isNotEmpty).toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (names.isEmpty) return translate(value);
    final pattern = RegExp(names.map(RegExp.escape).join('|'));
    final protected = <String>[];
    final masked = value.replaceAllMapped(pattern, (match) {
      protected.add(match[0]!);
      return '\uE000${protected.length - 1}\uE001';
    });
    return translate(masked).replaceAllMapped(
      RegExp('\uE000(\\d+)\uE001'),
      (match) => protected[int.parse(match[1]!)],
    );
  }

  String translate(String value) {
    if (_catalogCode != code ||
        isEnglish ||
        value.isEmpty ||
        !_latinLetters.hasMatch(value)) {
      return value;
    }
    return _cache[value] ?? _remember(value, _translateFromCatalog(value));
  }

  String _remember(String source, String translation) {
    if (_cache.length >= 4096) _cache.clear();
    _cache[source] = translation;
    return translation;
  }

  String _translateFromCatalog(String value) {
    final exact = _messages[value] ?? _countries[value];
    if (exact != null) return exact;
    final trimmed = value.trim();
    final normalized =
        _messages[trimmed] ??
        _countries[trimmed] ??
        _caseFolded[trimmed.toLowerCase()];
    if (normalized != null) return value.replaceFirst(trimmed, normalized);
    for (final (pattern, translation) in _templates) {
      final match = pattern.firstMatch(value);
      if (match == null) continue;
      return translation.replaceAllMapped(RegExp(r'\{(\d+)\}'), (placeholder) {
        final index = int.parse(placeholder[1]!) + 1;
        final argument = index <= match.groupCount
            ? match[index]!
            : placeholder[0]!;
        return argument.length < value.length ? translate(argument) : argument;
      });
    }
    // Match whole metadata segments, never substrings of proper names.
    for (final separator in [' • ', ' · ', ' | ', '\n', ', ']) {
      if (!value.contains(separator)) continue;
      final parts = value.split(separator);
      if (parts.any((part) => _countries.containsKey(part.trim()))) {
        return parts
            .map((part) => _countries[part.trim()] ?? part)
            .join(separator);
      }
    }
    final codeLabel = RegExp(r'^(.+)\s+\(([A-Z]{2,3})\)$').firstMatch(value);
    if (codeLabel != null && _countries.containsKey(codeLabel[1])) {
      return '${_countries[codeLabel[1]]} (${codeLabel[2]})';
    }
    return value;
  }
}
