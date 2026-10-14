// lib/services/game_scores_sync_service.dart
//
// Syncs every mini-game's local SharedPreferences data (leaderboards, the
// Respawn "My Country" setting, and each game's one-free-Insane-trial flag)
// to/from Firestore, keyed by the signed-in user's uid.
//
// This is intentionally NOT a per-game solution. Every game's score service
// already writes its own well-known SharedPreferences key(s):
//
//   which_is_farther_scores_<difficulty>
//   border_chain_scores_<difficulty>
//   flag_guess_scores_<difficulty>
//   timezone_impostor_scores_<difficulty>
//   higher_or_lower_scores_<metric>_<difficulty>
//   respawn_home_country_code
//   insane_trial_used_<gameKey>
//
// Rather than hardcoding every difficulty/metric combination (which breaks
// the moment a new difficulty or metric is added), this service scans
// SharedPreferences for anything matching a known PREFIX and syncs whatever
// it finds. New difficulties/metrics are picked up automatically.
//
// Wired into the same "upload on login" / "reload on login" pipeline the
// other providers use (see main.dart's _handlePendingLoginAction) -- this
// service isn't a ChangeNotifier/Provider, just a plain singleton, so it's
// called directly rather than via context.read<...>().

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameScoresSyncService {
  GameScoresSyncService._();

  static final GameScoresSyncService instance = GameScoresSyncService._();

  static const String _collection = 'game_scores';

  /// Any SharedPreferences key starting with one of these belongs to a
  /// mini-game and should be synced.
  static const List<String> _keyPrefixes = [
    'which_is_farther_scores_',
    'border_chain_scores_',
    'flag_guess_scores_',
    'timezone_impostor_scores_',
    'higher_or_lower_scores_',
    'insane_trial_used_',
  ];

  /// Exact (non-prefixed) keys that also belong to a mini-game.
  static const List<String> _exactKeys = [
    'respawn_home_country_code',
  ];

  bool _keyBelongsToGames(String key) {
    if (_exactKeys.contains(key)) return true;
    return _keyPrefixes.any((prefix) => key.startsWith(prefix));
  }

  /// Pushes every local game-related SharedPreferences entry up to
  /// Firestore, merged into the signed-in user's document. Safe to call
  /// even if nothing has been played yet (just writes an empty diff).
  Future<void> uploadLocalToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};

      for (final key in prefs.getKeys()) {
        if (!_keyBelongsToGames(key)) continue;
        final value = prefs.get(key);
        // Score leaderboards are stored as JSON-encoded strings; the
        // Insane-trial flags are bools; the Respawn home country is a
        // plain string. All three round-trip cleanly through Firestore
        // as-is, so no re-encoding is needed here.
        if (value is String || value is bool) {
          data[key] = value;
        }
      }

      if (data.isEmpty) return;

      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(uid)
          .set(data, SetOptions(merge: true));

      debugPrint('[GameScoresSyncService] uploaded ${data.length} game key(s)');
    } catch (e) {
      debugPrint('[GameScoresSyncService] upload error: $e');
    }
  }

  /// Pulls the signed-in user's game data back down from Firestore into
  /// local SharedPreferences, overwriting whatever's on this device.
  /// Called after login (or re-login on a new device) so leaderboards,
  /// the Respawn home country, and Insane-trial-used flags all follow
  /// the account rather than staying stuck on one device.
  Future<void> reloadFromServer() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection(_collection).doc(uid).get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null || data.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      var applied = 0;

      for (final entry in data.entries) {
        if (!_keyBelongsToGames(entry.key)) continue;
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
          applied++;
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
          applied++;
        }
      }

      debugPrint('[GameScoresSyncService] reloaded $applied game key(s)');
    } catch (e) {
      debugPrint('[GameScoresSyncService] reload error: $e');
    }
  }
}