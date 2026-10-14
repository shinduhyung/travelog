// lib/games/timezone_impostor.dart
//
// Self-contained "Timezone Impostor" mini-game: 4 cities shown, 3 share
// the same real UTC offset, 1 doesn't -- find the odd one out. Data comes
// from the data pipeline (see data_pipeline/04_timezone_impostor/) --
// GeoNames cities joined with their exact UTC offset computed via Python's
// real IANA tzdata at a fixed reference instant (printed at the top of
// the exported JSON). NO rounds are pre-baked: this game builds a fresh
// one every time via rejection sampling, exactly like border_chain.dart's
// _RoundPuzzle.generate().
//
// Difficulty is how CLOSE the impostor's offset is to the majority's
// (in minutes) -- easy is an obviously different offset, insane is
// something like +5:30 vs +5:45.
//
// The ONLY public symbol is [TimezoneImpostorDifficultyScreen]; everything
// else is private to this library on purpose.
//
// SETUP REQUIRED: bundle the pipeline's output as an asset:
//   assets/data/timezone_impostor_cities.json
// and register it in pubspec.yaml:
//   flutter:
//     assets:
//       - assets/data/timezone_impostor_cities.json

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jidoapp/services/game_ad_service.dart';
import 'package:jidoapp/services/game_insane_trial_service.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

// ============================================================================
// DATA
// ============================================================================

class _TzCity {
  final String name;
  final String country;
  final String countryCode;
  final int offsetMinutes;
  final String offsetLabel;

  const _TzCity({
    required this.name,
    required this.country,
    required this.countryCode,
    required this.offsetMinutes,
    required this.offsetLabel,
  });

  String get flagEmoji {
    final c = countryCode.toUpperCase();
    if (c.length != 2) return '🏳️';
    final first = 0x1F1E6 + (c.codeUnitAt(0) - 0x41);
    final second = 0x1F1E6 + (c.codeUnitAt(1) - 0x41);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  factory _TzCity.fromJson(Map<String, dynamic> json) => _TzCity(
    name: json['name'] as String,
    country: json['country'] as String,
    countryCode: json['country_code'] as String,
    offsetMinutes: json['utc_offset_minutes'] as int,
    offsetLabel: json['utc_offset_label'] as String,
  );
}

class _TzBank {
  static Future<List<_TzCity>>? _cache;
  static String? _referenceDatetime;

  static Future<List<_TzCity>> load() {
    return _cache ??= _loadFromAsset();
  }

  static Future<List<_TzCity>> _loadFromAsset() async {
    final raw = await rootBundle.loadString('assets/data/timezone_impostor_cities.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    _referenceDatetime = decoded['reference_datetime'] as String?;
    final cities = decoded['cities'] as List;
    return cities.map((e) => _TzCity.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String get referenceDatetime => _referenceDatetime ?? '';
}

// ============================================================================
// DIFFICULTY
// ============================================================================

enum _TzDifficulty { easy, medium, hard, insane }

/// (minMinutes, maxMinutes) gap between the impostor's offset and the
/// majority's offset, exclusive of maxMinutes except for easy's open top end.
(int, int) _bandRange(_TzDifficulty d) {
  switch (d) {
    case _TzDifficulty.easy:
      return (300, 1 << 30);
    case _TzDifficulty.medium:
      return (120, 300);
    case _TzDifficulty.hard:
      return (30, 120);
    case _TzDifficulty.insane:
      return (1, 30);
  }
}

Color _diffColor(_TzDifficulty d) {
  switch (d) {
    case _TzDifficulty.easy:
      return const Color(0xFF2FBE73);
    case _TzDifficulty.medium:
      return const Color(0xFFFF9F1C);
    case _TzDifficulty.hard:
      return const Color(0xFFFF5A5F);
    case _TzDifficulty.insane:
      return const Color(0xFF9B5DE5);
  }
}

String _diffLabel(_TzDifficulty d) {
  switch (d) {
    case _TzDifficulty.easy:
      return 'Easy';
    case _TzDifficulty.medium:
      return 'Medium';
    case _TzDifficulty.hard:
      return 'Hard';
    case _TzDifficulty.insane:
      return 'Insane';
  }
}

IconData _diffIcon(_TzDifficulty d) {
  switch (d) {
    case _TzDifficulty.easy:
      return Icons.sentiment_satisfied_alt_rounded;
    case _TzDifficulty.medium:
      return Icons.sentiment_neutral_rounded;
    case _TzDifficulty.hard:
      return Icons.sentiment_very_dissatisfied_rounded;
    case _TzDifficulty.insane:
      return Icons.local_fire_department_rounded;
  }
}

int _diffLevel(_TzDifficulty d) {
  switch (d) {
    case _TzDifficulty.easy:
      return 1;
    case _TzDifficulty.medium:
      return 2;
    case _TzDifficulty.hard:
      return 3;
    case _TzDifficulty.insane:
      return 4;
  }
}

// ============================================================================
// ROUND GENERATION (runtime, rejection-sampled — no pre-baked rounds)
// ============================================================================

class _TzRound {
  final List<_TzCity> cities; // 4 cities, shuffled
  final _TzCity impostor;

  const _TzRound({required this.cities, required this.impostor});

  static _TzRound? generate(List<_TzCity> pool, _TzDifficulty difficulty, Random rng) {
    final (minGap, maxGap) = _bandRange(difficulty);

    final byOffset = <int, List<_TzCity>>{};
    for (final c in pool) {
      byOffset.putIfAbsent(c.offsetMinutes, () => []).add(c);
    }
    final majorityCandidates = byOffset.entries.where((e) => e.value.length >= 3).toList();
    if (majorityCandidates.isEmpty) return null;

    for (var attempt = 0; attempt < 60; attempt++) {
      final majorityEntry = majorityCandidates[rng.nextInt(majorityCandidates.length)];
      final majorityOffset = majorityEntry.key;
      final majorityCities = List<_TzCity>.from(majorityEntry.value)..shuffle(rng);
      final threeCities = majorityCities.take(3).toList();

      final impostorCandidates = pool.where((c) {
        final gap = (c.offsetMinutes - majorityOffset).abs();
        return gap >= minGap && gap < maxGap && c.offsetMinutes != majorityOffset;
      }).toList();
      if (impostorCandidates.isEmpty) continue;

      final impostor = impostorCandidates[rng.nextInt(impostorCandidates.length)];
      final cities = [...threeCities, impostor]..shuffle(rng);
      return _TzRound(cities: cities, impostor: impostor);
    }
    return null; // caller should treat as "couldn't build a round in this band"
  }
}

// ============================================================================
// SCORE PERSISTENCE
// ============================================================================

class _ScoreRecord {
  final int score;
  final int roundsCompleted;
  final int maxRounds;
  final int bestCombo;
  final DateTime playedAt;

  const _ScoreRecord({
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

  factory _ScoreRecord.fromJson(Map<String, dynamic> json) => _ScoreRecord(
    score: json['score'] as int,
    roundsCompleted: json['roundsCompleted'] as int,
    maxRounds: json['maxRounds'] as int,
    bestCombo: json['bestCombo'] as int,
    playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class _ScoreService {
  static const int maxStoredRecords = 20;

  Future<List<_ScoreRecord>> loadRecords(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final records = decoded.map((e) => _ScoreRecord.fromJson(e as Map<String, dynamic>)).toList();
      records.sort((a, b) => b.score.compareTo(a.score));
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecord(String key, _ScoreRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadRecords(key);
    final updated = [...existing, record]..sort((a, b) => b.score.compareTo(a.score));
    final trimmed = updated.take(maxStoredRecords).toList();
    await prefs.setString(key, jsonEncode(trimmed.map((r) => r.toJson()).toList()));
  }
}

// ============================================================================
// SHARED UI KIT
// ============================================================================

const Color _kInk = Color(0xFF1A1B23);
const Color _kMuted = Color(0xFF8E8E9B);
const Color _kFaint = Color(0xFFC7C7D1);
const Color _kSurface = Color(0xFFFAFAFC);

class _SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
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

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;
  final bool outlined;

  const _GradientButton({
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
              BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: fg, size: 20),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: TextStyle(color: fg, fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenBackground extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _ScreenBackground({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
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

// ============================================================================
// DIFFICULTY SCREEN (entry point — the only public symbol in this file)
// ============================================================================

class TimezoneImpostorDifficultyScreen extends StatelessWidget {
  const TimezoneImpostorDifficultyScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        accent: _diffColor(_TzDifficulty.hard),
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
                      gradient: const LinearGradient(colors: [Color(0xFFFF5A5F), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('CHOOSE A DIFFICULTY',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: _kMuted)),
                ],
              ),
              const SizedBox(height: 16),
              _DifficultyCard(
                difficulty: _TzDifficulty.easy,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _LobbyScreen(difficulty: _TzDifficulty.easy)),
                ),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _TzDifficulty.medium,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _LobbyScreen(difficulty: _TzDifficulty.medium)),
                ),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: _TzDifficulty.hard,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _LobbyScreen(difficulty: _TzDifficulty.hard)),
                ),
              ),
              const SizedBox(height: 14),
              Consumer<SubscriptionService>(
                builder: (context, sub, _) {
                  final isPremium = sub.isPremium;
                  if (isPremium) {
                    return _DifficultyCard(
                      difficulty: _TzDifficulty.insane,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _LobbyScreen(difficulty: _TzDifficulty.insane)),
                      ),
                    );
                  }
                  return FutureBuilder<bool>(
                    future: GameInsaneTrialService.instance.hasUsedTrial('timezone_impostor'),
                    builder: (context, snapshot) {
                      final trialUsed = snapshot.data ?? false;
                      return _DifficultyCard(
                        difficulty: _TzDifficulty.insane,
                        locked: trialUsed,
                        onTap: () async {
                          if (trialUsed) {
                            SubscriptionSheet.show(context, triggerContext: 'timezone_impostor_insane');
                          } else {
                            await GameInsaneTrialService.instance.markTrialUsed('timezone_impostor');
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => _LobbyScreen(difficulty: _TzDifficulty.insane)),
                              );
                            }
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
              colors: [Color(0xFFFF5A5F), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF5A5F).withOpacity(0.32), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TIMEZONE PUZZLE',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: _kMuted)),
              const SizedBox(height: 4),
              const Text('Timezone Impostor',
                  style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.6, height: 1.05)),
              const SizedBox(height: 8),
              Text('Four cities, one clock that doesn\'t match. Spot the impostor before time runs out.',
                  style: TextStyle(
                      fontSize: 12.5, color: _kMuted.withOpacity(0.9), fontWeight: FontWeight.w600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final _TzDifficulty difficulty;
  final bool locked;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _diffColor(difficulty);
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
                boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: Icon(_diffIcon(difficulty), color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_diffLabel(difficulty),
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

class _LobbyScreen extends StatefulWidget {
  final _TzDifficulty difficulty;

  const _LobbyScreen({required this.difficulty});

  @override
  State<_LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<_LobbyScreen> {
  final _service = _ScoreService();
  late Future<List<_ScoreRecord>> _recordsFuture;

  String get _storageKey => 'timezone_impostor_scores_${widget.difficulty.name}';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _recordsFuture = _service.loadRecords(_storageKey);
    });
  }

  Future<void> _startGame() async {
    await GameAdService.instance.requestStartGame();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _GameScreen(difficulty: widget.difficulty)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final color = _diffColor(widget.difficulty);
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
        accent: color,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                _buildLobbyHeader(color),
                const SizedBox(height: 22),
                Expanded(child: _buildHistory(color)),
                const SizedBox(height: 18),
                _GradientButton(label: 'Start Game', icon: Icons.play_arrow_rounded, color: color, onPressed: _startGame),
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
          child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DIFFICULTY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: _kMuted)),
              const SizedBox(height: 2),
              Text('${_diffLabel(widget.difficulty)} Mode',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(Color color) {
    return FutureBuilder<List<_ScoreRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final records = snapshot.data!;
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_outlined, size: 46, color: _kFaint),
                const SizedBox(height: 12),
                const Text('No runs yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LEADERBOARD',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
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
  final _ScoreRecord record;

  const _RecordTile({required this.rank, required this.record});

  static const _medalColors = {1: Color(0xFFFFC93C), 2: Color(0xFFB8C1CC), 3: Color(0xFFD08A5B)};

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(color: (medal ?? _kFaint).withOpacity(medal != null ? 0.18 : 0.12), shape: BoxShape.circle),
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, size: 16, color: medal)
                : Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _kMuted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${record.score}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _kInk)),
                Text('${record.roundsCompleted}/${record.maxRounds} rounds · combo ${record.bestCombo}',
                    style: const TextStyle(fontSize: 11.5, color: _kMuted)),
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

enum _RoundPhase { loading, error, playing, revealed, complete }

class _GameScreen extends StatefulWidget {
  final _TzDifficulty difficulty;

  const _GameScreen({required this.difficulty});

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  static const int _maxRounds = 20;
  static const double _maxScorePerRound = 10.0;
  static const double _timeLimit = 12.0;

  final _rng = Random();
  List<_TzCity> _pool = [];
  int _roundIndex = 0;
  int _totalScore = 0;
  int _bestRoundScore = 0;
  int _combo = 0;
  bool _recorded = false;

  _RoundPhase _phase = _RoundPhase.loading;
  String? _loadError;
  double _remaining = _timeLimit;
  DateTime? _roundStart;

  _TzRound? _round;
  _TzCity? _selected;
  int? _lastRoundScore;

  Color get _accent => _diffColor(widget.difficulty);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _phase = _RoundPhase.loading;
      _loadError = null;
    });
    try {
      final all = await _TzBank.load();
      if (!mounted) return;
      if (all.length < 4) {
        setState(() {
          _phase = _RoundPhase.error;
          _loadError = 'Not enough cities in the data set (need at least 4, have ${all.length}).';
        });
        return;
      }
      setState(() => _pool = all);
      _startRound();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _RoundPhase.error;
        _loadError = e.toString();
      });
    }
  }

  void _startRound() {
    final round = _TzRound.generate(_pool, widget.difficulty, _rng);
    if (round == null) {
      setState(() {
        _phase = _RoundPhase.error;
        _loadError =
        "Couldn't find a ${_diffLabel(widget.difficulty)}-difficulty combination in the current data set. "
            "Try a lower difficulty, or add more cities to the pipeline's data.";
      });
      return;
    }
    setState(() {
      _round = round;
      _selected = null;
      _lastRoundScore = null;
      _remaining = _timeLimit;
      _phase = _RoundPhase.playing;
      _roundStart = DateTime.now();
    });
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _phase != _RoundPhase.playing) return;
      final elapsed = DateTime.now().difference(_roundStart!).inMilliseconds / 1000.0;
      final remaining = _timeLimit - elapsed;
      if (remaining <= 0) {
        setState(() => _remaining = 0);
        _reveal(correct: false);
        return;
      }
      setState(() => _remaining = remaining);
      _tick();
    });
  }

  void _onSelect(_TzCity city) {
    if (_phase != _RoundPhase.playing) return;
    final elapsed = DateTime.now().difference(_roundStart!).inMilliseconds / 1000.0;
    final correct = city.name == _round!.impostor.name;

    int? score;
    if (correct) {
      final raw = (_maxScorePerRound - elapsed).clamp(0.0, _maxScorePerRound);
      score = raw.round();
    }

    setState(() {
      _selected = city;
      _lastRoundScore = score;
      if (correct) {
        _totalScore += score!;
        if (score > _bestRoundScore) _bestRoundScore = score;
        _combo++;
      }
    });

    _reveal(correct: correct);
  }

  void _reveal({required bool correct}) {
    setState(() => _phase = _RoundPhase.revealed);
    Future.delayed(Duration(milliseconds: correct ? 1400 : 2400), () {
      if (!mounted) return;
      if (!correct) {
        _finish();
        return;
      }
      if (_roundIndex + 1 >= _maxRounds) {
        _finish();
      } else {
        setState(() => _roundIndex++);
        _startRound();
      }
    });
  }

  void _finish() {
    setState(() => _phase = _RoundPhase.complete);
    GameAdService.instance.notifyGameFinished();
    _save();
  }

  Future<void> _save() async {
    if (_recorded) return;
    _recorded = true;
    try {
      await _ScoreService().addRecord(
        'timezone_impostor_scores_${widget.difficulty.name}',
        _ScoreRecord(
          score: _totalScore,
          roundsCompleted: _combo,
          maxRounds: _maxRounds,
          bestCombo: _combo,
          playedAt: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  void _retry() {
    setState(() {
      _roundIndex = 0;
      _totalScore = 0;
      _bestRoundScore = 0;
      _combo = 0;
      _recorded = false;
    });
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
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
            Text('${_diffLabel(widget.difficulty)} Mode',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.2)),
          ],
        ),
        iconTheme: const IconThemeData(color: _kInk),
        actions: (_phase == _RoundPhase.loading || _phase == _RoundPhase.error || _phase == _RoundPhase.complete)
            ? null
            : [_ScoreBadge(score: _totalScore, best: _bestRoundScore, accent: _accent)],
      ),
      body: _ScreenBackground(
        accent: _accent,
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _RoundPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case _RoundPhase.error:
        return _buildError();
      case _RoundPhase.complete:
        return _buildComplete();
      case _RoundPhase.playing:
      case _RoundPhase.revealed:
        return _buildRound();
    }
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
            const Text("Couldn't build a round", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk)),
            const SizedBox(height: 8),
            if (_loadError != null)
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: _kMuted)),
            const SizedBox(height: 24),
            _GradientButton(label: 'Retry', color: _accent, onPressed: _init),
          ],
        ),
      ),
    );
  }

  Widget _buildRound() {
    final round = _round!;
    final revealed = _phase == _RoundPhase.revealed;
    final ratio = (_remaining / _timeLimit).clamp(0.0, 1.0);
    final barColor = Color.lerp(const Color(0xFFFF5A5F), const Color(0xFF2FBE73), ratio)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ROUND ${_roundIndex + 1} / $_maxRounds',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _kMuted)),
              if (_combo > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFFF5A5F).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_fire_department_rounded, size: 15, color: Color(0xFFFF5A5F)),
                    const SizedBox(width: 3),
                    Text('$_combo', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFFF5A5F))),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!revealed)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 9,
                backgroundColor: Colors.black.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            )
          else
            _buildResultBanner(),
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(Icons.travel_explore_rounded, size: 18, color: _accent),
              const SizedBox(width: 6),
              const Text('FIND THE IMPOSTOR',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: _kInk)),
            ],
          ),
          const SizedBox(height: 5),
          const Text('Three of these cities share a timezone. One doesn\'t.',
              style: TextStyle(fontSize: 12, color: _kFaint, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              // Was 1.25 -- too short once the reveal-phase offset label
              // (e.g. "UTC+9:00") appears below the country name, which
              // needs room that wasn't reserved for it, causing a bottom
              // overflow on all 4 cards every time a round resolved.
              childAspectRatio: 0.95,
              children: round.cities.map(_buildCityCard).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    final correct = _selected != null && _selected!.name == _round!.impostor.name;
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
              correct ? 'Correct! +${_lastRoundScore ?? 0}' : (timedOut ? "Time's up" : 'Wrong'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityCard(_TzCity city) {
    final revealed = _phase == _RoundPhase.revealed;
    final isImpostor = city.name == _round!.impostor.name;
    final isSelected = _selected?.name == city.name;

    Color bg = Colors.white;
    Color fg = _kInk;
    Color sub = _kMuted;
    Color border = Colors.black.withOpacity(0.04);

    if (revealed) {
      if (isImpostor) {
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
      onTap: () => _onSelect(city),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1.4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(city.flagEmoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(city.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 4),
            Text(city.country,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sub)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: revealed
                  ? Padding(
                key: const ValueKey('offset'),
                padding: const EdgeInsets.only(top: 6),
                child: Text(city.offsetLabel,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: sub)),
              )
                  : const SizedBox.shrink(key: ValueKey('hidden')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete() {
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
              child: const Icon(Icons.emoji_events_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text('RUN COMPLETE',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: _kMuted)),
            const SizedBox(height: 6),
            const Text('Nice work!',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.5)),
            const SizedBox(height: 26),
            _SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 26),
              child: Column(children: [
                Text('$_totalScore', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: _accent)),
                const Text('TOTAL SCORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StatChip(label: 'Rounds', value: '$_combo/$_maxRounds'),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Best', value: '$_bestRoundScore'),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Combo', value: '$_combo'),
                ]),
              ]),
            ),
            const SizedBox(height: 26),
            _GradientButton(label: 'Play Again', color: _accent, onPressed: _retry),
            const SizedBox(height: 10),
            _GradientButton(label: 'Back to Lobby', color: _accent, outlined: true, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  final int best;
  final Color accent;

  const _ScoreBadge({required this.score, required this.best, required this.accent});

  @override
  Widget build(BuildContext context) {
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
            Text('$score', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
            Text('best $best', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _kMuted)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kInk)),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: _kMuted)),
      ]),
    );
  }
}