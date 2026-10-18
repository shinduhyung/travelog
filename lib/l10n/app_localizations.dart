import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  if (AppLocale.instance.locale.languageCode != 'ko') return value;
  return tr(value == 'Economy' ? 'Economy Class' : value);
}

class AppLocale extends ChangeNotifier with WidgetsBindingObserver {
  AppLocale._();
  static final instance = AppLocale._();
  static final _latinLetters = RegExp('[A-Za-z]');
  static const preferenceKey = 'app_language';
  static const supportedLocales = [Locale('en'), Locale('ko')];
  String? _language;
  String? get language => _language;
  Locale get locale => Locale(_language ?? _deviceLanguage);
  String get _deviceLanguage {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    return locales.isNotEmpty && locales.first.languageCode == 'ko'
        ? 'ko'
        : 'en';
  }

  Map<String, String> _messages = {};
  Map<String, String> _countries = {};
  Map<String, String> _caseFolded = {};
  final _templates = <(RegExp, String)>[];
  final _cache = <String, String>{};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(preferenceKey);
    _language = saved == 'ko' || saved == 'en' ? saved : null;
    _messages = Map<String, String>.from(
      jsonDecode(await rootBundle.loadString('assets/l10n/ko.json')) as Map,
    );
    _countries = Map<String, String>.from(
      jsonDecode(await rootBundle.loadString('assets/l10n/countries_ko.json'))
          as Map,
    );
    _caseFolded = {
      for (final entry in _messages.entries)
        entry.key.toLowerCase(): entry.value,
      for (final entry in _countries.entries)
        entry.key.toLowerCase(): entry.value,
    };
    _templates.clear();
    _cache.clear();
    final entries = _messages.entries.toList()
      ..sort((a, b) {
        int literals(String key) =>
            key.replaceAll(RegExp(r'\{\d+\}'), '').length;
        return literals(b.key).compareTo(literals(a.key));
      });
    for (final entry in entries) {
      if (!entry.key.contains('{0}')) continue;
      final parts = entry.key.split(RegExp(r'\{\d+\}'));
      // A literal anchor is required: a template must never translate arbitrary
      // entity names or user-written content.
      if (parts.join().trim().length < 3) continue;
      final pattern = parts.map(RegExp.escape).join('(.*?)');
      _templates.add((RegExp('^$pattern\$', dotAll: true), entry.value));
    }
    await initializeDateFormatting('ko');
    Intl.defaultLocale = locale.languageCode;
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> setLanguage(String? language) async {
    if (language != null && language != 'ko' && language != 'en') {
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
    Intl.defaultLocale = locale.languageCode;
    notifyListeners();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_language == null) {
      Intl.defaultLocale = locale.languageCode;
      notifyListeners();
    }
  }

  bool matchesCountry(String name, String query) {
    final search = query.trim().toLowerCase();
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
      locale.languageCode == 'ko' ? (_countries[name] ?? name) : name;

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
    if (locale.languageCode != 'ko' || value.isEmpty || !_latinLetters.hasMatch(value)) {
      return value;
    }
    return _cache[value] ?? _remember(value, _translateKorean(value));
  }

  String _remember(String source, String translation) {
    if (_cache.length >= 4096) _cache.clear();
    _cache[source] = translation;
    return translation;
  }

  String _translateKorean(String value) {
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
