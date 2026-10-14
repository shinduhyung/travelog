// lib/games/airport_code.dart
//
// Self-contained "Airport Code" mini-game: given a 3-letter IATA code,
// pick the city it serves from 4 options. Data comes from the data
// pipeline (see data_pipeline/01_airport_code/) — OurAirports ground
// truth for the code/city/country/difficulty tier, DeepSeek-generated
// distractor cities.
//
// The ONLY public symbol is [AirportCodeDifficultyScreen]; everything
// else is private to this library on purpose.
//
// SETUP REQUIRED: bundle the pipeline's output as an asset:
//   assets/data/airport_code.json
// and register it in pubspec.yaml:
//   flutter:
//     assets:
//       - assets/data/airport_code.json

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// DATA
// ============================================================================

/// Forces every keystroke to uppercase as the user types -- used by Insane
/// mode's code-entry field so "abc" becomes "ABC" live rather than only
/// being uppercased when compared against the answer.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

enum _AirportDifficulty { easy, medium, hard, insane }

_AirportDifficulty _difficultyFromTier(String tier) {
  switch (tier) {
    case 'easy':
      return _AirportDifficulty.easy;
    case 'medium':
      return _AirportDifficulty.medium;
    default:
      return _AirportDifficulty.hard;
  }
}

class _Airport {
  final String code;
  final String city;
  final String country;
  final String countryCode;
  final String name;
  final _AirportDifficulty tier;
  final List<String> distractors;

  const _Airport({
    required this.code,
    required this.city,
    required this.country,
    required this.countryCode,
    required this.name,
    required this.tier,
    required this.distractors,
  });

  String get flagEmoji {
    final c = countryCode.toUpperCase();
    if (c.length != 2) return '🏳️';
    final first = 0x1F1E6 + (c.codeUnitAt(0) - 0x41);
    final second = 0x1F1E6 + (c.codeUnitAt(1) - 0x41);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }

  factory _Airport.fromJson(Map<String, dynamic> json) => _Airport(
    code: json['code'] as String,
    city: json['city'] as String,
    country: json['country'] as String,
    countryCode: json['country_code'] as String,
    name: (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : json['city'] as String,
    tier: _difficultyFromTier(json['tier'] as String),
    distractors: (json['distractors'] as List).cast<String>(),
  );
}

class _AirportBank {
  static Future<List<_Airport>>? _cache;

  static Future<List<_Airport>> load() {
    return _cache ??= _loadFromAsset();
  }

  static Future<List<_Airport>> _loadFromAsset() async {
    final raw = await rootBundle.loadString('assets/data/airport_code.json');
    final decoded = json.decode(raw) as List;
    return decoded.map((e) => _Airport.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Difficulty is intentionally shifted one full notch easier than the raw
  /// OurAirports size tiers would suggest, while still keeping all 4 tiers
  /// meaningfully distinct from each other:
  ///   Easy   -> large_airport only (multiple choice)
  ///   Medium -> large_airport + medium_airport mixed, softened by blending
  ///             in recognizable big hubs (multiple choice)
  ///   Hard   -> medium_airport only -- this is what "Medium" used to be
  ///             (multiple choice)
  ///   Insane -> medium_airport only -- SAME pool as Hard, but you type the
  ///             code instead of picking it, which is what actually makes
  ///             it the hardest tier rather than needing an even harder pool
  /// small_airport (the old "Hard" pool) is no longer used by any mode --
  /// it was the source of the most obscure/unfair rounds.
  static Future<List<_Airport>> forDifficulty(_AirportDifficulty difficulty) async {
    final all = await load();
    List<_Airport> filtered;
    switch (difficulty) {
      case _AirportDifficulty.easy:
        filtered = all.where((a) => a.tier == _AirportDifficulty.easy).toList();
        break;
      case _AirportDifficulty.medium:
        filtered = all
            .where((a) => a.tier == _AirportDifficulty.easy || a.tier == _AirportDifficulty.medium)
            .toList();
        break;
      case _AirportDifficulty.hard:
      case _AirportDifficulty.insane:
        filtered = all.where((a) => a.tier == _AirportDifficulty.medium).toList();
        break;
    }
    filtered.shuffle();
    return filtered;
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
const Color _kAccent = Color(0xFF2563EB); // aviation blue

Color _tierColor(_AirportDifficulty d) {
  switch (d) {
    case _AirportDifficulty.easy:
      return const Color(0xFF2FBE73);
    case _AirportDifficulty.medium:
      return const Color(0xFFFF9F1C);
    case _AirportDifficulty.hard:
      return const Color(0xFFFF5A5F);
    case _AirportDifficulty.insane:
      return const Color(0xFF8B5CF6);
  }
}

String _tierLabel(_AirportDifficulty d) {
  switch (d) {
    case _AirportDifficulty.easy:
      return 'Easy';
    case _AirportDifficulty.medium:
      return 'Medium';
    case _AirportDifficulty.hard:
      return 'Hard';
    case _AirportDifficulty.insane:
      return 'Insane';
  }
}

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

class AirportCodeDifficultyScreen extends StatelessWidget {
  const AirportCodeDifficultyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Airport Code',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kInk)),
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        accent: _kAccent,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 32),
            children: [
              const Text('CHOOSE A DIFFICULTY',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: _kMuted)),
              const SizedBox(height: 16),
              for (final d in _AirportDifficulty.values) ...[
                _DifficultyCard(
                  difficulty: d,
                  subtitle: switch (d) {
                    _AirportDifficulty.easy => 'Major international hubs',
                    _AirportDifficulty.medium => 'Well-known regional airports',
                    _AirportDifficulty.hard => 'Smaller regional fields',
                    _AirportDifficulty.insane => 'Type the code yourself — no multiple choice',
                  },
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => _LobbyScreen(difficulty: d)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final _AirportDifficulty difficulty;
  final String subtitle;
  final VoidCallback onTap;

  const _DifficultyCard({required this.difficulty, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(difficulty);
    return GestureDetector(
      onTap: onTap,
      child: _SoftCard(
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
              child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tierLabel(difficulty),
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: _kInk)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: _kMuted, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 22, color: _kFaint),
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
  final _AirportDifficulty difficulty;

  const _LobbyScreen({required this.difficulty});

  @override
  State<_LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<_LobbyScreen> {
  final _service = _ScoreService();
  late Future<List<_ScoreRecord>> _recordsFuture;

  String get _storageKey => 'airport_code_scores_${widget.difficulty.name}';

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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _GameScreen(difficulty: widget.difficulty)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(widget.difficulty);
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${_tierLabel(widget.difficulty)} Mode',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk)),
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        accent: color,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 92, 20, 20),
            child: Column(
              children: [
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
  final _AirportDifficulty difficulty;

  const _GameScreen({required this.difficulty});

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  static const int _maxRoundsCap = 30;
  static const double _maxScorePerRound = 10.0;
  static const double _timeLimit = 10.0;

  List<_Airport> _rounds = [];
  int _maxRounds = 0;
  int _roundIndex = 0;
  int _totalScore = 0;
  int _bestRoundScore = 0;
  int _combo = 0;
  bool _recorded = false;

  _RoundPhase _phase = _RoundPhase.loading;
  String? _loadError;
  double _remaining = _timeLimit;
  DateTime? _roundStart;

  List<String> _choices = [];
  String? _selected;
  int? _lastRoundScore;

  // City name -> flag emoji, built once from the FULL dataset (not just
  // this difficulty's pool) so distractor city names -- which are plain
  // strings with no country attached in the data -- can still show a flag
  // by reverse-looking-up any airport elsewhere in the data that serves
  // that same city. Falls back to a blank flag if no match is found.
  Map<String, String> _cityFlags = {};

  // Insane mode only: type the code instead of picking from choices.
  final TextEditingController _codeController = TextEditingController();
  String? _submittedCode;

  bool get _isInsane => widget.difficulty == _AirportDifficulty.insane;
  Color get _accent => _tierColor(widget.difficulty);
  _Airport get _current => _rounds[_roundIndex];

  String _flagForCity(String city) => _cityFlags[city] ?? '🏳️';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _phase = _RoundPhase.loading;
      _loadError = null;
    });
    try {
      final all = await _AirportBank.load();
      if (!mounted) return;
      final flags = <String, String>{};
      for (final a in all) {
        flags.putIfAbsent(a.city, () => a.flagEmoji);
      }
      final pool = await _AirportBank.forDifficulty(widget.difficulty);
      if (!mounted) return;
      if (pool.isEmpty) {
        setState(() {
          _phase = _RoundPhase.error;
          _loadError = 'No airports found for ${_tierLabel(widget.difficulty)} difficulty.';
        });
        return;
      }
      setState(() {
        _cityFlags = flags;
        _maxRounds = pool.length < _maxRoundsCap ? pool.length : _maxRoundsCap;
        _rounds = pool.take(_maxRounds).toList();
      });
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
    final answer = _current;
    final choices = <String>[answer.city, ...answer.distractors]..shuffle();
    setState(() {
      _choices = choices;
      _selected = null;
      _submittedCode = null;
      _lastRoundScore = null;
      _remaining = _timeLimit;
      _phase = _RoundPhase.playing;
      _roundStart = DateTime.now();
    });
    _codeController.clear();
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

  void _onSelect(String choice) {
    if (_phase != _RoundPhase.playing) return;
    final elapsed = DateTime.now().difference(_roundStart!).inMilliseconds / 1000.0;
    final correct = choice == _current.city;

    int? score;
    if (correct) {
      final raw = (_maxScorePerRound - elapsed).clamp(0.0, _maxScorePerRound);
      score = raw.round();
    }

    setState(() {
      _selected = choice;
      _lastRoundScore = score;
      if (correct) {
        _totalScore += score!;
        if (score > _bestRoundScore) _bestRoundScore = score;
        _combo++;
      }
    });

    _reveal(correct: correct);
  }

  /// Insane mode: fires as soon as 3 letters have been typed -- no
  /// separate submit button needed.
  void _onCodeChanged(String value) {
    if (_phase != _RoundPhase.playing) return;
    if (value.length < 3) return;

    final elapsed = DateTime.now().difference(_roundStart!).inMilliseconds / 1000.0;
    final correct = value.toUpperCase() == _current.code.toUpperCase();

    int? score;
    if (correct) {
      final raw = (_maxScorePerRound - elapsed).clamp(0.0, _maxScorePerRound);
      score = raw.round();
    }

    setState(() {
      _submittedCode = value.toUpperCase();
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
    Future.delayed(Duration(milliseconds: correct ? 1200 : 2200), () {
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
    _save();
  }

  Future<void> _save() async {
    if (_recorded) return;
    _recorded = true;
    try {
      await _ScoreService().addRecord(
        'airport_code_scores_${widget.difficulty.name}',
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
      _rounds.shuffle();
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
        title: Text('${_tierLabel(widget.difficulty)} Mode',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk)),
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
            const Text("Couldn't load airports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk)),
            const SizedBox(height: 8),
            if (_loadError != null)
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: _kMuted)),
            const SizedBox(height: 24),
            _GradientButton(label: 'Retry', color: _accent, onPressed: _load),
          ],
        ),
      ),
    );
  }

  Widget _buildRound() {
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
          if (!revealed) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 9,
                backgroundColor: Colors.black.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ] else
            _buildResultBanner(),
          const SizedBox(height: 28),
          Expanded(
            child: Center(
              child: _SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 34),
                radius: 26,
                child: _isInsane
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_current.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
                    const SizedBox(height: 6),
                    Text('${_current.city}, ${_current.country}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kMuted)),
                    const SizedBox(height: 4),
                    const Text('AIRPORT NAME',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _kFaint)),
                  ],
                )
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_current.code,
                        style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    const Text('IATA CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _kFaint)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isInsane) _buildCodeInput() else _buildChoiceGrid(),
        ],
      ),
    );
  }

  Widget _buildCodeInput() {
    return TextField(
      controller: _codeController,
      enabled: _phase == _RoundPhase.playing,
      autofocus: true,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      maxLength: 3,
      onChanged: _onCodeChanged,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
        LengthLimitingTextInputFormatter(3),
        _UpperCaseTextFormatter(),
      ],
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 10, color: _kInk),
      decoration: InputDecoration(
        counterText: '',
        hintText: 'ABC',
        hintStyle: TextStyle(color: _kFaint, letterSpacing: 10),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _accent.withOpacity(0.25), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _accent, width: 2),
        ),
      ),
    );
  }

  Widget _buildChoiceGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: _choices.map(_buildChoiceButton).toList(),
    );
  }

  Widget _buildResultBanner() {
    final correct = _isInsane ? _submittedCode == _current.code.toUpperCase() : _selected == _current.city;
    final color = correct ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: Icon(correct ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correct
                        ? 'Correct! +${_lastRoundScore ?? 0}'
                        : (_isInsane ? 'Wrong — it was ${_current.code}' : 'Wrong'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  Text('${_current.flagEmoji} ${_current.city}, ${_current.country}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButton(String choice) {
    Color bg = Colors.white;
    Color fg = _kInk;
    Color border = Colors.black.withOpacity(0.04);

    if (_phase == _RoundPhase.revealed) {
      final isAnswer = choice == _current.city;
      final isSelected = _selected == choice;
      if (isAnswer) {
        bg = const Color(0xFF2FBE73);
        border = const Color(0xFF2FBE73);
        fg = Colors.white;
      } else if (isSelected) {
        bg = const Color(0xFFFF5A5F);
        border = const Color(0xFFFF5A5F);
        fg = Colors.white;
      }
    }

    return GestureDetector(
      onTap: () => _onSelect(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_flagForCity(choice), style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(choice,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
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
            const Text('Run Complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
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