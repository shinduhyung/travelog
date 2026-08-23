// lib/data/which_is_farther_data.dart
//
// Data layer for the "Which Is Farther?" mini-game. Questions are NOT
// generated at runtime — they're pre-computed offline (200 cities, every
// valid origin/destination-pair combination, Haversine great-circle
// distance, filtered by how close the two distances are) and shipped as a
// bundled JSON asset. See tool/generate_which_is_farther_questions.py for
// the generator; re-run it any time you want to regenerate the set (add
// cities, change difficulty bands, etc).
//
// Add the asset to pubspec.yaml:
//   flutter:
//     assets:
//       - assets/data/which_is_farther_questions.json

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

const String _kAssetPath = 'assets/data/which_is_farther_questions.json';

enum WhichIsFartherDifficulty { easy, medium, hard, expert }

WhichIsFartherDifficulty _difficultyFromJson(String s) {
  switch (s) {
    case 'easy':
      return WhichIsFartherDifficulty.easy;
    case 'medium':
      return WhichIsFartherDifficulty.medium;
    case 'hard':
      return WhichIsFartherDifficulty.hard;
    case 'expert':
      return WhichIsFartherDifficulty.expert;
    default:
      throw ArgumentError('Unknown difficulty: $s');
  }
}

/// A place shown in a question — either the origin (no distance attached)
/// or a destination (via [WhichIsFartherQuestion.kmA] / [kmB]).
class GeoPlace {
  final String name;
  final String countryCode;

  const GeoPlace(this.name, this.countryCode);

  /// Flag emoji derived from the ISO 3166-1 alpha-2 country code via the
  /// Unicode Regional Indicator Symbol trick.
  String get emoji {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🏳️';
    final first = 0x1F1E6 + (code.codeUnitAt(0) - 0x41);
    final second = 0x1F1E6 + (code.codeUnitAt(1) - 0x41);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  factory GeoPlace.fromJson(Map<String, dynamic> json) =>
      GeoPlace(json['name'] as String, json['cc'] as String);
}

class WhichIsFartherQuestion {
  final String id;
  final GeoPlace origin;
  final GeoPlace a;
  final GeoPlace b;
  final int kmA;
  final int kmB;
  final String answer; // 'a' or 'b'
  final WhichIsFartherDifficulty difficulty;

  const WhichIsFartherQuestion({
    required this.id,
    required this.origin,
    required this.a,
    required this.b,
    required this.kmA,
    required this.kmB,
    required this.answer,
    required this.difficulty,
  });

  bool get aIsFarther => answer == 'a';

  factory WhichIsFartherQuestion.fromJson(Map<String, dynamic> json) {
    return WhichIsFartherQuestion(
      id: json['id'] as String,
      origin: GeoPlace.fromJson(json['origin'] as Map<String, dynamic>),
      a: GeoPlace.fromJson(json['a'] as Map<String, dynamic>),
      b: GeoPlace.fromJson(json['b'] as Map<String, dynamic>),
      kmA: (json['a'] as Map<String, dynamic>)['km'] as int,
      kmB: (json['b'] as Map<String, dynamic>)['km'] as int,
      answer: json['answer'] as String,
      difficulty: _difficultyFromJson(json['difficulty'] as String),
    );
  }
}

/// Loads and caches the full pre-generated question bank for the lifetime
/// of the app — parsing ~9,600 small JSON objects is quick, but there's no
/// reason to redo it on every game start.
class WhichIsFartherQuestionBank {
  static Future<List<WhichIsFartherQuestion>>? _cache;

  static Future<List<WhichIsFartherQuestion>> load() {
    return _cache ??= _loadFromAsset();
  }

  /// Drops the cached future so the next [load] call re-reads the asset —
  /// useful for a "Retry" button after a load failure.
  static void resetCache() => _cache = null;

  static Future<List<WhichIsFartherQuestion>> _loadFromAsset() async {
    debugPrint('[WhichIsFarther] loading asset: $_kAssetPath');
    final stopwatch = Stopwatch()..start();

    late final String raw;
    try {
      raw = await rootBundle.loadString(_kAssetPath);
    } catch (e, st) {
      debugPrint('[WhichIsFarther] FAILED to load asset "$_kAssetPath": $e');
      debugPrint('[WhichIsFarther] This almost always means the file is missing from '
          'the project or not registered in pubspec.yaml under flutter/assets. '
          'Expected path: $_kAssetPath');
      debugPrint('[WhichIsFarther] stack trace:\n$st');
      rethrow;
    }
    debugPrint('[WhichIsFarther] asset loaded: ${raw.length} chars in ${stopwatch.elapsedMilliseconds}ms');

    late final List decoded;
    try {
      decoded = json.decode(raw) as List;
    } catch (e, st) {
      debugPrint('[WhichIsFarther] FAILED to parse JSON: $e');
      debugPrint('[WhichIsFarther] first 200 chars of asset content: '
          '"${raw.substring(0, raw.length < 200 ? raw.length : 200)}"');
      debugPrint('[WhichIsFarther] stack trace:\n$st');
      rethrow;
    }
    debugPrint('[WhichIsFarther] JSON decoded: ${decoded.length} raw entries');

    final questions = <WhichIsFartherQuestion>[];
    var skipped = 0;
    for (var i = 0; i < decoded.length; i++) {
      try {
        questions.add(WhichIsFartherQuestion.fromJson(decoded[i] as Map<String, dynamic>));
      } catch (e) {
        skipped++;
        if (skipped <= 5) {
          debugPrint('[WhichIsFarther] skipped malformed entry at index $i: $e');
        }
      }
    }
    if (skipped > 0) {
      debugPrint('[WhichIsFarther] skipped $skipped malformed entr${skipped == 1 ? 'y' : 'ies'} total');
    }

    final byDifficulty = <String, int>{};
    for (final q in questions) {
      byDifficulty[q.difficulty.name] = (byDifficulty[q.difficulty.name] ?? 0) + 1;
    }
    debugPrint('[WhichIsFarther] ready: ${questions.length} questions total, by difficulty: $byDifficulty '
        '(took ${stopwatch.elapsedMilliseconds}ms)');

    if (questions.isEmpty) {
      debugPrint('[WhichIsFarther] WARNING: question bank is empty after parsing — '
          'the game will have nothing to show for any difficulty.');
    }

    return questions;
  }

  /// All questions for a single difficulty, freshly shuffled.
  static Future<List<WhichIsFartherQuestion>> forDifficulty(
      WhichIsFartherDifficulty difficulty) async {
    final all = await load();
    final filtered = all.where((q) => q.difficulty == difficulty).toList();
    debugPrint('[WhichIsFarther] forDifficulty(${difficulty.name}): '
        '${filtered.length} of ${all.length} questions match');
    filtered.shuffle();
    return filtered;
  }
}

/// Right-pads a km value with thousands separators: 12345 -> "12,345".
String formatKm(int km) {
  final s = km.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}