// lib/services/game_insane_trial_service.dart
//
// Tracks, per game, whether a non-premium player has already used their
// one free look at that game's Insane difficulty. Applies to every game
// EXCEPT Respawn (which has no difficulty tiers).
//
// Rule: Insane is otherwise Premium-only, but every non-subscriber gets to
// play it exactly once for free, per game. The moment that one free run
// is used, Insane locks (shows a lock icon) for that game, and tapping it
// again opens the subscription sheet instead of starting the game.
// Premium users are never affected by any of this -- always unlocked.

import 'package:shared_preferences/shared_preferences.dart';

class GameInsaneTrialService {
  GameInsaneTrialService._();

  static final GameInsaneTrialService instance = GameInsaneTrialService._();

  String _keyFor(String gameKey) => 'insane_trial_used_$gameKey';

  /// Whether the free Insane trial has already been used for [gameKey].
  Future<bool> hasUsedTrial(String gameKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFor(gameKey)) ?? false;
  }

  /// Marks the free Insane trial as used for [gameKey]. Call this the
  /// moment a non-premium player actually starts their one free Insane
  /// run -- not just from viewing the difficulty screen.
  Future<void> markTrialUsed(String gameKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(gameKey), true);
  }
}