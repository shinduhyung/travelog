// lib/games/which_is_farther.dart
//
// Self-contained "Which Is Farther?" mini-game.
//
// Everything the game needs -- the question-bank loader/model, local score
// persistence, a small shared UI kit, and all three screens (difficulty
// picker, lobby/leaderboard, and the game itself) -- lives in this single
// file. The actual questions are pre-generated offline (see
// tool/generate_which_is_farther_questions.py) and shipped as a bundled
// JSON asset -- register it in pubspec.yaml:
//
//   flutter:
//     assets:
//       - assets/data/which_is_farther_questions.json
//
// The ONLY public symbol is [WhichIsFartherDifficultyScreen]; everything
// else is private to this library (leading underscore) on purpose, so this
// file never collides with any other game file even if several are
// imported into the same place. To add this game somewhere, just:
//
//   import 'package:jidoapp/games/which_is_farther.dart';
//   ...
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => const WhichIsFartherDifficultyScreen(),
//   ));
//
// Dependencies: shared_preferences (see pubspec.yaml).

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jidoapp/services/game_ad_service.dart';
import 'package:jidoapp/services/game_insane_trial_service.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

// ============================================================================
// DATA
// ============================================================================

const String _kAssetPath = 'assets/data/which_is_farther_questions.json';

enum _WhichIsFartherDifficulty { easy, medium, hard, expert }

_WhichIsFartherDifficulty _difficultyFromJson(String s) {
  switch (s) {
    case 'easy':
      return _WhichIsFartherDifficulty.easy;
    case 'medium':
      return _WhichIsFartherDifficulty.medium;
    case 'hard':
      return _WhichIsFartherDifficulty.hard;
    case 'expert':
      return _WhichIsFartherDifficulty.expert;
    default:
      throw ArgumentError('Unknown difficulty: $s');
  }
}

/// A place shown in a question — either the origin (no distance attached)
/// or a destination (via [_WhichIsFartherQuestion.kmA] / [kmB]).
class _GeoPlace {
  final String name;
  final String countryCode;

  const _GeoPlace(this.name, this.countryCode);

  /// Flag emoji derived from the ISO 3166-1 alpha-2 country code via the
  /// Unicode Regional Indicator Symbol trick.
  String get emoji {
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🏳️';
    final first = 0x1F1E6 + (code.codeUnitAt(0) - 0x41);
    final second = 0x1F1E6 + (code.codeUnitAt(1) - 0x41);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  factory _GeoPlace.fromJson(Map<String, dynamic> json) =>
      _GeoPlace(json['name'] as String, json['cc'] as String);
}

class _WhichIsFartherQuestion {
  final String id;
  final _GeoPlace origin;
  final _GeoPlace a;
  final _GeoPlace b;
  final int kmA;
  final int kmB;
  final String answer; // 'a' or 'b'
  final _WhichIsFartherDifficulty difficulty;

  const _WhichIsFartherQuestion({
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

  factory _WhichIsFartherQuestion.fromJson(Map<String, dynamic> json) {
    return _WhichIsFartherQuestion(
      id: json['id'] as String,
      origin: _GeoPlace.fromJson(json['origin'] as Map<String, dynamic>),
      a: _GeoPlace.fromJson(json['a'] as Map<String, dynamic>),
      b: _GeoPlace.fromJson(json['b'] as Map<String, dynamic>),
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
class _WhichIsFartherQuestionBank {
  static Future<List<_WhichIsFartherQuestion>>? _cache;

  static Future<List<_WhichIsFartherQuestion>> load() {
    return _cache ??= _loadFromAsset();
  }

  /// Drops the cached future so the next [load] call re-reads the asset —
  /// useful for a "Retry" button after a load failure.
  static void resetCache() => _cache = null;

  static Future<List<_WhichIsFartherQuestion>> _loadFromAsset() async {
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

    final questions = <_WhichIsFartherQuestion>[];
    var skipped = 0;
    for (var i = 0; i < decoded.length; i++) {
      try {
        questions.add(_WhichIsFartherQuestion.fromJson(decoded[i] as Map<String, dynamic>));
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
  static Future<List<_WhichIsFartherQuestion>> forDifficulty(
      _WhichIsFartherDifficulty difficulty) async {
    final all = await load();
    final filtered = all.where((q) => q.difficulty == difficulty).toList();
    debugPrint('[WhichIsFarther] forDifficulty(${difficulty.name}): '
        '${filtered.length} of ${all.length} questions match');
    filtered.shuffle();
    return filtered;
  }
}

/// Right-pads a km value with thousands separators: 12345 -> "12,345".
String _formatKm(int km) {
  final s = km.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ============================================================================
// SCORE PERSISTENCE
// ============================================================================

class _WhichIsFartherScoreRecord {
  final double score;
  final int roundsCompleted;
  final int maxRounds;
  final int bestCombo;
  final DateTime playedAt;

  const _WhichIsFartherScoreRecord({
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

  factory _WhichIsFartherScoreRecord.fromJson(Map<String, dynamic> json) =>
      _WhichIsFartherScoreRecord(
        score: (json['score'] as num).toDouble(),
        roundsCompleted: json['roundsCompleted'] as int,
        maxRounds: json['maxRounds'] as int,
        bestCombo: json['bestCombo'] as int,
        playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class _WhichIsFartherScoreService {
  static const int maxStoredRecords = 20;

  String _keyFor(_WhichIsFartherDifficulty difficulty) =>
      'which_is_farther_scores_${difficulty.name}';

  Future<List<_WhichIsFartherScoreRecord>> loadRecords(
      _WhichIsFartherDifficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(difficulty));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final records = decoded
          .map((e) => _WhichIsFartherScoreRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      records.sort((a, b) => b.score.compareTo(a.score));
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecord(
      _WhichIsFartherDifficulty difficulty, _WhichIsFartherScoreRecord record) async {
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

// ============================================================================
// SHARED UI KIT
// ============================================================================

const Color _kInk = Color(0xFF1A1B23);
const Color _kMuted = Color(0xFF8E8E9B);
const Color _kFaint = Color(0xFFC7C7D1);
const Color _kSurface = Color(0xFFFAFAFC);

Color _accentFor(_WhichIsFartherDifficulty d) {
  switch (d) {
    case _WhichIsFartherDifficulty.easy:
      return const Color(0xFF2FBE73);
    case _WhichIsFartherDifficulty.medium:
      return const Color(0xFFFF9F1C);
    case _WhichIsFartherDifficulty.hard:
      return const Color(0xFFFF5A5F);
    case _WhichIsFartherDifficulty.expert:
      return const Color(0xFF3E63DD);
  }
}

String _labelFor(_WhichIsFartherDifficulty d) {
  switch (d) {
    case _WhichIsFartherDifficulty.easy:
      return 'Easy';
    case _WhichIsFartherDifficulty.medium:
      return 'Medium';
    case _WhichIsFartherDifficulty.hard:
      return 'Hard';
    case _WhichIsFartherDifficulty.expert:
      return 'Insane';
  }
}

/// A soft, elevated white card — the base building block for nearly every
/// piece of chrome in this feature.
class _SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  const _SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.4) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

/// A gradient, tactile primary button with a subtle press-scale animation.
class _GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;
  final bool outlined;

  const _GradientButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final fg = widget.outlined ? widget.color : Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            gradient: widget.outlined
                ? null
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.color, Color.lerp(widget.color, Colors.black, 0.18)!],
            ),
            color: widget.outlined ? Colors.white : null,
            border: widget.outlined ? Border.all(color: widget.color.withOpacity(0.35), width: 1.4) : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.outlined
                ? null
                : [
              BoxShadow(
                  color: widget.color.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: fg, size: 20),
                const SizedBox(width: 8),
              ],
              Text(tr(widget.label),
                  style: TextStyle(color: fg, fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tinted gradient wash behind a screen — subtle, accent-colored at the
/// top, fading to the base surface color.
class _ScreenBackground extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _ScreenBackground({super.key, required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withOpacity(0.14), _kSurface],
          stops: const [0.0, 0.4],
        ),
      ),
      child: child,
    );
  }
}

int _diffLevel(_WhichIsFartherDifficulty d) {
  switch (d) {
    case _WhichIsFartherDifficulty.easy:
      return 1;
    case _WhichIsFartherDifficulty.medium:
      return 2;
    case _WhichIsFartherDifficulty.hard:
      return 3;
    case _WhichIsFartherDifficulty.expert:
      return 4;
  }
}

// ============================================================================
// DIFFICULTY SCREEN (entry point — the only public symbol in this file)
// ============================================================================

/// Difficulty picker for Which Is Farther. All four tiers are open — the
/// difficulty controls how close the two candidate distances are (Easy:
/// 20-50% apart, Insane: 0.3-3% apart), not how many cities are in play.
class WhichIsFartherDifficultyScreen extends StatelessWidget {
  const WhichIsFartherDifficultyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        accent: _accentFor(_WhichIsFartherDifficulty.hard),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF5A5F), Color(0xFF3E63DD)]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                   Text(tr('CHOOSE A DIFFICULTY'),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: _kMuted)),
                ],
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                difficulty: _WhichIsFartherDifficulty.easy,
                icon: Icons.sentiment_satisfied_alt_rounded,
                onTap: () => _openLobby(context, _WhichIsFartherDifficulty.easy),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _WhichIsFartherDifficulty.medium,
                icon: Icons.sentiment_neutral_rounded,
                onTap: () => _openLobby(context, _WhichIsFartherDifficulty.medium),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _WhichIsFartherDifficulty.hard,
                icon: Icons.sentiment_very_dissatisfied_rounded,
                onTap: () => _openLobby(context, _WhichIsFartherDifficulty.hard),
              ),
              const SizedBox(height: 14),
              Consumer<SubscriptionService>(
                builder: (context, sub, _) {
                  final isPremium = sub.isPremium;
                  if (isPremium) {
                    return _DifficultyCard(
                      difficulty: _WhichIsFartherDifficulty.expert,
                      icon: Icons.local_fire_department_rounded,
                      onTap: () => _openLobby(context, _WhichIsFartherDifficulty.expert),
                    );
                  }
                  return FutureBuilder<bool>(
                    future: GameInsaneTrialService.instance.hasUsedTrial('which_is_farther'),
                    builder: (context, snapshot) {
                      final trialUsed = snapshot.data ?? false;
                      return _DifficultyCard(
                        difficulty: _WhichIsFartherDifficulty.expert,
                        icon: Icons.local_fire_department_rounded,
                        locked: trialUsed,
                        onTap: () async {
                          if (trialUsed) {
                            SubscriptionSheet.show(context, triggerContext: 'which_is_farther_insane');
                          } else {
                            await GameInsaneTrialService.instance.markTrialUsed('which_is_farther');
                            if (context.mounted) _openLobby(context, _WhichIsFartherDifficulty.expert);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF5A5F), Color(0xFF3E63DD)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF5A5F).withOpacity(0.32), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.public_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(tr('DISTANCE PUZZLE'),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: _kMuted)),
              const SizedBox(height: 4),
               Text(tr('Which Is Farther?'),
                  style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.6, height: 1.05)),
              const SizedBox(height: 8),
              Text(tr('Pick the more distant city before the clock runs out. Gaps get tighter as you climb.'),
                  style: TextStyle(
                      fontSize: 12.5, color: _kMuted.withOpacity(0.9), fontWeight: FontWeight.w600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  void _openLobby(BuildContext context, _WhichIsFartherDifficulty difficulty) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _WhichIsFartherLobbyScreen(difficulty: difficulty)),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final _WhichIsFartherDifficulty difficulty;
  final IconData icon;
  final bool locked;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.icon,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final color = _accentFor(difficulty);
    final level = _diffLevel(difficulty);
    return GestureDetector(
      onTap: onTap,
      child: _SoftCard(
        borderColor: locked ? color.withOpacity(0.3) : null,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.85), color],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(tr(_labelFor(difficulty)),
                          style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.2)),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_rounded, size: 15, color: color),
                      ],
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: List.generate(4, (i) {
                      final filled = i < level;
                      return Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Container(
                          width: 20,
                          height: 6,
                          decoration: BoxDecoration(
                            color: filled ? color : color.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOBBY SCREEN
// ============================================================================

class _WhichIsFartherLobbyScreen extends StatefulWidget {
  final _WhichIsFartherDifficulty difficulty;

  const _WhichIsFartherLobbyScreen({super.key, required this.difficulty});

  @override
  State<_WhichIsFartherLobbyScreen> createState() => _WhichIsFartherLobbyScreenState();
}

class _WhichIsFartherLobbyScreenState extends State<_WhichIsFartherLobbyScreen> {
  final _service = _WhichIsFartherScoreService();
  late Future<List<_WhichIsFartherScoreRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _recordsFuture = _service.loadRecords(widget.difficulty);
    });
  }

  Future<void> _startGame() async {
    await GameAdService.instance.requestStartGame();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _WhichIsFartherGameScreen(difficulty: widget.difficulty)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final accent = _accentFor(widget.difficulty);
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        accent: accent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                _buildLobbyHeader(accent),
                const SizedBox(height: 22),
                Expanded(child: _buildHistory(accent)),
                const SizedBox(height: 18),
                _GradientButton(
                  label: 'Start Game',
                  icon: Icons.play_arrow_rounded,
                  color: accent,
                  onPressed: _startGame,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyHeader(Color color) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.85), color],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: color.withOpacity(0.32), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.public_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text(tr('DIFFICULTY'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: _kMuted)),
              const SizedBox(height: 2),
              Text(tr('${_labelFor(widget.difficulty)} Mode'),
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(Color accent) {
    return FutureBuilder<List<_WhichIsFartherScoreRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!;
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_outlined, size: 46, color: _kFaint),
                const SizedBox(height: 12),
                 Text(tr('No runs yet'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
                const SizedBox(height: 4),
                Text(tr('Play a round to start your leaderboard'),
                    style: TextStyle(fontSize: 12.5, color: _kMuted)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('LEADERBOARD'),
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                Text(tr('${records.length} run${records.length == 1 ? '' : 's'}'),
                    style: TextStyle(fontSize: 12, color: _kFaint, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _RecordTile(rank: i + 1, record: records[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  final int rank;
  final _WhichIsFartherScoreRecord record;

  const _RecordTile({required this.rank, required this.record});

  static const _medalColors = {1: Color(0xFFFFC93C), 2: Color(0xFFB8C1CC), 3: Color(0xFFD08A5B)};

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final medal = _medalColors[rank];
    return _SoftCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: medal?.withOpacity(0.5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (medal ?? _kFaint).withOpacity(medal != null ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, size: 16, color: medal)
                : Text(tr('$rank'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _kMuted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(record.score.toStringAsFixed(1)),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _kInk)),
                const SizedBox(height: 2),
                Text(
                  tr('${record.roundsCompleted}/${record.maxRounds} rounds · combo ${record.bestCombo} · ${_formatDate(record.playedAt)}'),
                  style: const TextStyle(fontSize: 11.5, color: _kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GAME SCREEN
// ============================================================================

enum _RoundPhase { loading, error, prep, playing, revealed }

class _WhichIsFartherGameScreen extends StatefulWidget {
  final _WhichIsFartherDifficulty difficulty;

  const _WhichIsFartherGameScreen({super.key, required this.difficulty});

  @override
  State<_WhichIsFartherGameScreen> createState() => _WhichIsFartherGameScreenState();
}

class _WhichIsFartherGameScreenState extends State<_WhichIsFartherGameScreen> {
  static const int _maxRoundsCap = 30;
  static const double _maxScorePerRound = 10.0;
  static const Duration _correctRevealDuration = Duration(milliseconds: 1600);
  static const Duration _wrongRevealDuration = Duration(milliseconds: 2600);

  List<_WhichIsFartherQuestion> _rounds = [];
  int _maxRounds = 0;

  int _roundIndex = 0;
  double _totalScore = 0;
  double _bestRoundScore = 0;
  int _combo = 0;

  _RoundPhase _phase = _RoundPhase.loading;
  int _prepCountdown = 3;
  Timer? _prepTimer;

  double _timeLimit = 12;
  double _remaining = 12;
  Timer? _playTimer;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _revealTimer;

  String? _selected; // 'a' | 'b' | null (timeout)
  double? _lastRoundScore;

  bool _gameOver = false;
  String? _endReason; // 'wrong' | 'timeout' | 'complete'
  bool _recorded = false;
  String? _loadError;

  Color get _accent => _accentFor(widget.difficulty);
  _WhichIsFartherQuestion get _question => _rounds[_roundIndex];

  @override
  void initState() {
    super.initState();
    debugPrint('[WhichIsFarther] game screen initState — difficulty=${widget.difficulty.name}');
    _loadRounds();
  }

  Future<void> _loadRounds() async {
    debugPrint('[WhichIsFarther] _loadRounds start (${widget.difficulty.name})');
    setState(() {
      _phase = _RoundPhase.loading;
      _loadError = null;
    });
    try {
      final pool = await _WhichIsFartherQuestionBank.forDifficulty(widget.difficulty);
      debugPrint('[WhichIsFarther] _loadRounds got ${pool.length} candidates for ${widget.difficulty.name}');
      if (!mounted) {
        debugPrint('[WhichIsFarther] _loadRounds: widget unmounted before pool arrived, aborting');
        return;
      }
      if (pool.isEmpty) {
        debugPrint('[WhichIsFarther] _loadRounds: pool is EMPTY for ${widget.difficulty.name} — '
            'nothing to play. Check that which_is_farther_questions.json actually contains '
            'entries with difficulty "${widget.difficulty.name}".');
        setState(() {
          _phase = _RoundPhase.error;
          _loadError = 'No questions found for ${widget.difficulty.name} difficulty.';
        });
        return;
      }
      setState(() {
        _maxRounds = min(_maxRoundsCap, pool.length);
        _rounds = pool.take(_maxRounds).toList();
      });
      debugPrint('[WhichIsFarther] _loadRounds: starting game with $_maxRounds rounds');
      _beginPrep();
    } catch (e, st) {
      debugPrint('[WhichIsFarther] _loadRounds FAILED: $e');
      debugPrint('[WhichIsFarther] stack trace:\n$st');
      if (!mounted) return;
      setState(() {
        _phase = _RoundPhase.error;
        _loadError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _prepTimer?.cancel();
    _playTimer?.cancel();
    _revealTimer?.cancel();
    super.dispose();
  }

  /// Base time budget per difficulty, tightening slightly as rounds go on.
  double _timeLimitForRound(int index) {
    switch (widget.difficulty) {
      case _WhichIsFartherDifficulty.easy:
        return 12.0;
      case _WhichIsFartherDifficulty.medium:
        return max(5.0, 12.0 - index);
      case _WhichIsFartherDifficulty.hard:
        return max(4.0, 10.0 - index);
      case _WhichIsFartherDifficulty.expert:
        return max(3.0, 10.0 - index);
    }
  }

  // ── Round lifecycle ─────────────────────────────────────────────────────

  void _beginPrep() {
    debugPrint('[WhichIsFarther] _beginPrep round=${_roundIndex + 1}/$_maxRounds');
    setState(() {
      _phase = _RoundPhase.prep;
      _prepCountdown = 3;
    });
    _prepTimer?.cancel();
    _prepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _prepCountdown--);
      if (_prepCountdown <= 0) {
        t.cancel();
        _startRound();
      }
    });
  }

  void _startRound() {
    debugPrint('[WhichIsFarther] _startRound round=${_roundIndex + 1}: '
        '${_question.origin.name} -> ${_question.a.name} vs ${_question.b.name} '
        '(answer=${_question.answer}, ${_question.difficulty.name})');
    final limit = _timeLimitForRound(_roundIndex);
    setState(() {
      _selected = null;
      _lastRoundScore = null;
      _timeLimit = limit;
      _remaining = limit;
      _phase = _RoundPhase.playing;
    });

    _stopwatch
      ..reset()
      ..start();
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      final elapsed = _stopwatch.elapsedMilliseconds / 1000.0;
      final remaining = _timeLimit - elapsed;
      if (remaining <= 0) {
        t.cancel();
        _stopwatch.stop();
        setState(() => _remaining = 0);
        _enterReveal(correct: false);
        return;
      }
      setState(() => _remaining = remaining);
    });
  }

  void _onSelect(String side) {
    if (_phase != _RoundPhase.playing) return;
    _playTimer?.cancel();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds / 1000.0;
    final correct = side == _question.answer;

    double? score;
    if (correct) {
      final raw = (_maxScorePerRound - elapsed).clamp(0.0, _maxScorePerRound);
      score = double.parse(raw.toStringAsFixed(1));
    }

    setState(() {
      _selected = side;
      _lastRoundScore = score;
      if (correct) {
        _totalScore += score!;
        if (score > _bestRoundScore) _bestRoundScore = score;
        _combo++;
      }
    });

    HapticFeedback.selectionClick();
    _enterReveal(correct: correct);
  }

  void _enterReveal({required bool correct}) {
    setState(() => _phase = _RoundPhase.revealed);
    _revealTimer?.cancel();
    _revealTimer = Timer(correct ? _correctRevealDuration : _wrongRevealDuration, () {
      if (!mounted) return;
      if (!correct) {
        _finishGame(_selected == null ? 'timeout' : 'wrong');
        return;
      }
      if (_roundIndex + 1 >= _maxRounds) {
        _finishGame('complete');
      } else {
        setState(() => _roundIndex++);
        _beginPrep();
      }
    });
  }

  void _finishGame(String reason) {
    if (_gameOver) return;
    debugPrint('[WhichIsFarther] _finishGame reason=$reason score=$_totalScore rounds=$_roundIndex/$_maxRounds');
    _prepTimer?.cancel();
    _playTimer?.cancel();
    _revealTimer?.cancel();
    setState(() {
      _gameOver = true;
      _endReason = reason;
    });
    GameAdService.instance.notifyGameFinished();
    _saveRecord(reason);
  }

  Future<void> _saveRecord(String reason) async {
    if (_recorded) return;
    _recorded = true;
    try {
      await _WhichIsFartherScoreService().addRecord(
        widget.difficulty,
        _WhichIsFartherScoreRecord(
          score: double.parse(_totalScore.toStringAsFixed(1)),
          roundsCompleted: reason == 'complete' ? _maxRounds : _roundIndex,
          maxRounds: _maxRounds,
          bestCombo: _combo,
          playedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Local-storage hiccups shouldn't block showing the result screen.
    }
  }

  Future<void> _retry() async {
    setState(() {
      _phase = _RoundPhase.loading;
      _roundIndex = 0;
      _totalScore = 0;
      _bestRoundScore = 0;
      _combo = 0;
      _gameOver = false;
      _endReason = null;
      _recorded = false;
    });
    await _loadRounds();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(tr('${_labelFor(widget.difficulty)} Mode'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.2)),
          ],
        ),
        iconTheme: const IconThemeData(color: _kInk),
        actions: (_phase == _RoundPhase.loading || _phase == _RoundPhase.error)
            ? null
            : [_ScoreBadge(total: _totalScore, best: _bestRoundScore, accent: _accent)],
      ),
      body: _ScreenBackground(
        accent: _accent,
        child: SafeArea(
          child: _phase == _RoundPhase.loading
              ? const Center(child: CircularProgressIndicator())
              : _phase == _RoundPhase.error
              ? _buildError()
              : (_gameOver ? _buildGameOver() : _buildPlayArea()),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: _kFaint),
            const SizedBox(height: 16),
             Text(tr("Couldn't load questions"),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk)),
            const SizedBox(height: 8),
            if (_loadError != null)
              Text(tr(_loadError!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: _kMuted)),
            const SizedBox(height: 8),
            Text(tr('Check the debug console for [WhichIsFarther] logs — details are printed there.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: _kFaint)),
            const SizedBox(height: 24),
            _GradientButton(label: 'Retry', color: _accent, onPressed: _loadRounds),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 56, 0, 0),
      child: _phase == _RoundPhase.prep ? _buildPrep() : _buildRound(),
    );
  }

  Widget _buildPrep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr('ROUND ${_roundIndex + 1} OF $_maxRounds'),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            key: ValueKey(_prepCountdown),
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_accent.withOpacity(0.85), _accent],
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Text(
                tr(_prepCountdown > 0 ? '$_prepCountdown' : 'GO'),
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(tr('Get ready...'), style: TextStyle(fontSize: 14, color: _kMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRound() {
    final q = _question;
    final ratio = (_remaining / _timeLimit).clamp(0.0, 1.0);
    final barColor = Color.lerp(const Color(0xFFFF5A5F), const Color(0xFF2FBE73), ratio)!;
    final revealed = _phase == _RoundPhase.revealed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('ROUND ${_roundIndex + 1} / $_maxRounds'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _kMuted)),
              if (_combo > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A5F).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_fire_department_rounded, size: 15, color: Color(0xFFFF5A5F)),
                    const SizedBox(width: 3),
                    Text(tr('$_combo'),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFFF5A5F))),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!revealed)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 9,
                    backgroundColor: Colors.black.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(tr('${_remaining.toStringAsFixed(1)}s'),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: barColor)),
                ),
              ],
            )
          else
            _buildResultBanner(),
          const SizedBox(height: 20),
          _buildOriginHeader(q),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildDestinationCard(q, 'a', q.a, q.kmA)),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
                    ]),
                    child: Text(tr('VS'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _kMuted)),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(child: _buildDestinationCard(q, 'b', q.b, q.kmB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginHeader(_WhichIsFartherQuestion q) {
    return Column(
      children: [
        Text(tr('FROM'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _kMuted)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr(q.origin.emoji), style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(q.origin.name,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _kInk)),
          ],
        ),
        const SizedBox(height: 4),
        Text(tr('which is farther?'), style: TextStyle(fontSize: 13, color: _kMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDestinationCard(_WhichIsFartherQuestion q, String side, _GeoPlace place, int km) {
    final revealed = _phase == _RoundPhase.revealed;
    final isAnswer = side == q.answer;
    final isSelected = _selected == side;

    Color bg = Colors.white;
    Color fg = _kInk;
    Color sub = _kMuted;
    Color border = Colors.black.withOpacity(0.04);

    if (revealed) {
      if (isAnswer) {
        bg = const Color(0xFF2FBE73);
        border = const Color(0xFF2FBE73);
        fg = Colors.white;
        sub = Colors.white70;
      } else if (isSelected) {
        bg = const Color(0xFFFF5A5F);
        border = const Color(0xFFFF5A5F);
        fg = Colors.white;
        sub = Colors.white70;
      }
    }

    return GestureDetector(
      onTap: () => _onSelect(side),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Text(tr(place.emoji), style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: revealed
                        ? Padding(
                      key: const ValueKey('km'),
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(tr('${_formatKm(km)} km'),
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sub)),
                    )
                        : const SizedBox.shrink(key: ValueKey('hidden')),
                  ),
                ],
              ),
            ),
            if (revealed && isAnswer)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24)
            else if (revealed && isSelected)
              const Icon(Icons.cancel_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    final correct = _selected != null && _selected == _question.answer;
    final timedOut = _selected == null;
    final color = correct ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Icon(correct ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              tr(correct
                  ? 'Correct! +${_lastRoundScore!.toStringAsFixed(1)}'
                  : (timedOut ? "Time's up" : 'Wrong')),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOver() {
    final completed = _endReason == 'complete';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_accent.withOpacity(0.85), _accent]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Icon(completed ? Icons.emoji_events_rounded : Icons.public_off_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(tr(completed ? 'All Rounds Complete!' : 'Game Over'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
            const SizedBox(height: 26),
            _SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 26),
              child: Column(children: [
                Text(tr(_totalScore.toStringAsFixed(1)),
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: _accent)),
                 Text(tr('TOTAL SCORE'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StatChip(label: 'Rounds', value: '${completed ? _maxRounds : _roundIndex}/$_maxRounds'),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Best', value: _bestRoundScore.toStringAsFixed(1)),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Combo', value: '$_combo'),
                ]),
              ]),
            ),
            const SizedBox(height: 26),
            _GradientButton(label: 'Play Again', color: _accent, onPressed: _retry),
            const SizedBox(height: 10),
            _GradientButton(
              label: 'Back to Lobby',
              color: _accent,
              outlined: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double total;
  final double best;
  final Color accent;

  const _ScoreBadge({required this.total, required this.best, required this.accent});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr(total.toStringAsFixed(1)),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
            Text(tr('best ${best.toStringAsFixed(1)}'),
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _kMuted)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(tr(value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kInk)),
        const SizedBox(height: 2),
        Text(tr(label.toUpperCase()),
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: _kMuted)),
      ]),
    );
  }
}