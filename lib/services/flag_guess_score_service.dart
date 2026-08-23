// lib/services/flag_guess_score_service.dart
//
// Local (on-device) score history for Flag Guess, one leaderboard per
// difficulty. Backed by shared_preferences — add it to pubspec.yaml if it
// isn't already a dependency:
//
//   dependencies:
//     shared_preferences: ^2.2.0
//
// Records are stored as a JSON array under a per-difficulty key, capped at
// [FlagGuessScoreService.maxStoredRecords] entries (best scores kept).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/data/flag_guess_data.dart';

class FlagGuessScoreRecord {
  final double score;
  final int roundsCompleted;
  final int maxRounds;
  final int bestCombo;
  final DateTime playedAt;

  const FlagGuessScoreRecord({
    required this.score,
    required this.roundsCompleted,
    required this.maxRounds,
    required this.bestCombo,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
    'score': score,
    'roundsCompleted': roundsCompleted,
    'maxRounds': maxRounds,
    'bestCombo': bestCombo,
    'playedAt': playedAt.toIso8601String(),
  };

  factory FlagGuessScoreRecord.fromJson(Map<String, dynamic> json) => FlagGuessScoreRecord(
    score: (json['score'] as num).toDouble(),
    roundsCompleted: json['roundsCompleted'] as int,
    maxRounds: json['maxRounds'] as int,
    bestCombo: json['bestCombo'] as int,
    playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class FlagGuessScoreService {
  static const int maxStoredRecords = 20;

  String _keyFor(FlagGuessDifficulty difficulty) => 'flag_guess_scores_${difficulty.name}';

  /// Records for a difficulty, best score first.
  Future<List<FlagGuessScoreRecord>> loadRecords(FlagGuessDifficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(difficulty));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final records = decoded
          .map((e) => FlagGuessScoreRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      records.sort((a, b) => b.score.compareTo(a.score));
      return records;
    } catch (_) {
      // Corrupt or outdated local data shouldn't crash the lobby screen.
      return [];
    }
  }

  /// Appends a finished run and trims to [maxStoredRecords] (dropping the
  /// lowest scores first).
  Future<void> addRecord(FlagGuessDifficulty difficulty, FlagGuessScoreRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadRecords(difficulty);
    final updated = [...existing, record]..sort((a, b) => b.score.compareTo(a.score));
    final trimmed = updated.take(maxStoredRecords).toList();
    await prefs.setString(
      _keyFor(difficulty),
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }
}