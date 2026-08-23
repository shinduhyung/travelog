// lib/services/which_is_farther_score_service.dart
//
// Local (on-device) score history for Which Is Farther, one leaderboard per
// difficulty. Backed by shared_preferences (same dependency the Flag Guess
// feature already needs — no new package required if that's set up).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/data/which_is_farther_data.dart';

class WhichIsFartherScoreRecord {
  final double score;
  final int roundsCompleted;
  final int maxRounds;
  final int bestCombo;
  final DateTime playedAt;

  const WhichIsFartherScoreRecord({
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

  factory WhichIsFartherScoreRecord.fromJson(Map<String, dynamic> json) =>
      WhichIsFartherScoreRecord(
        score: (json['score'] as num).toDouble(),
        roundsCompleted: json['roundsCompleted'] as int,
        maxRounds: json['maxRounds'] as int,
        bestCombo: json['bestCombo'] as int,
        playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class WhichIsFartherScoreService {
  static const int maxStoredRecords = 20;

  String _keyFor(WhichIsFartherDifficulty difficulty) =>
      'which_is_farther_scores_${difficulty.name}';

  Future<List<WhichIsFartherScoreRecord>> loadRecords(
      WhichIsFartherDifficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(difficulty));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final records = decoded
          .map((e) => WhichIsFartherScoreRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      records.sort((a, b) => b.score.compareTo(a.score));
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecord(
      WhichIsFartherDifficulty difficulty, WhichIsFartherScoreRecord record) async {
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
