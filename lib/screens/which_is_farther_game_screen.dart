// lib/screens/which_is_farther_game_screen.dart
//
// Gameplay screen for "Which Is Farther?". Flow per round:
//   3s prep countdown -> origin + two destination cards with a per-round
//   timer -> pick one -> reveal (both real distances shown right on the
//   cards, correct one highlighted) -> next round (or game over).
//
// Questions come from the pre-generated bank (see which_is_farther_data.dart)
// filtered to this difficulty and shuffled — nothing is computed live except
// the score/timer bookkeeping below.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/data/which_is_farther_data.dart';
import 'package:jidoapp/services/which_is_farther_score_service.dart';
import 'package:jidoapp/widgets/which_is_farther_ui.dart';

enum _RoundPhase { loading, error, prep, playing, revealed }

class WhichIsFartherGameScreen extends StatefulWidget {
  final WhichIsFartherDifficulty difficulty;

  const WhichIsFartherGameScreen({super.key, required this.difficulty});

  @override
  State<WhichIsFartherGameScreen> createState() => _WhichIsFartherGameScreenState();
}

class _WhichIsFartherGameScreenState extends State<WhichIsFartherGameScreen> {
  static const int _maxRoundsCap = 30;
  static const double _maxScorePerRound = 10.0;
  static const Duration _correctRevealDuration = Duration(milliseconds: 1600);
  static const Duration _wrongRevealDuration = Duration(milliseconds: 2600);

  List<WhichIsFartherQuestion> _rounds = [];
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

  Color get _accent => accentFor(widget.difficulty);
  WhichIsFartherQuestion get _question => _rounds[_roundIndex];

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
      final pool = await WhichIsFartherQuestionBank.forDifficulty(widget.difficulty);
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
      case WhichIsFartherDifficulty.easy:
        return 12.0;
      case WhichIsFartherDifficulty.medium:
        return max(5.0, 12.0 - index);
      case WhichIsFartherDifficulty.hard:
        return max(4.0, 10.0 - index);
      case WhichIsFartherDifficulty.expert:
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
    _saveRecord(reason);
  }

  Future<void> _saveRecord(String reason) async {
    if (_recorded) return;
    _recorded = true;
    try {
      await WhichIsFartherScoreService().addRecord(
        widget.difficulty,
        WhichIsFartherScoreRecord(
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
    return Scaffold(
      backgroundColor: kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${labelFor(widget.difficulty)} Mode',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kInk)),
        iconTheme: const IconThemeData(color: kInk),
        actions: (_phase == _RoundPhase.loading || _phase == _RoundPhase.error)
            ? null
            : [_ScoreBadge(total: _totalScore, best: _bestRoundScore, accent: _accent)],
      ),
      body: ScreenBackground(
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
            Icon(Icons.cloud_off_rounded, size: 48, color: kFaint),
            const SizedBox(height: 16),
            const Text("Couldn't load questions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kInk)),
            const SizedBox(height: 8),
            if (_loadError != null)
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: kMuted)),
            const SizedBox(height: 8),
            Text('Check the debug console for [WhichIsFarther] logs — details are printed there.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: kFaint)),
            const SizedBox(height: 24),
            GradientButton(label: 'Retry', color: _accent, onPressed: _loadRounds),
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
          Text('ROUND ${_roundIndex + 1} OF $_maxRounds',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: kMuted)),
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
                _prepCountdown > 0 ? '$_prepCountdown' : 'GO',
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Get ready...', style: TextStyle(fontSize: 14, color: kMuted, fontWeight: FontWeight.w600)),
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
              Text('ROUND ${_roundIndex + 1} / $_maxRounds',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: kMuted)),
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
                    Text('$_combo',
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
                  child: Text('${_remaining.toStringAsFixed(1)}s',
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
                    child: Text('VS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kMuted)),
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

  Widget _buildOriginHeader(WhichIsFartherQuestion q) {
    return Column(
      children: [
        Text('FROM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: kMuted)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(q.origin.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(q.origin.name,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: kInk)),
          ],
        ),
        const SizedBox(height: 4),
        Text('which is farther?', style: TextStyle(fontSize: 13, color: kMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDestinationCard(WhichIsFartherQuestion q, String side, GeoPlace place, int km) {
    final revealed = _phase == _RoundPhase.revealed;
    final isAnswer = side == q.answer;
    final isSelected = _selected == side;

    Color bg = Colors.white;
    Color fg = kInk;
    Color sub = kMuted;
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
            Text(place.emoji, style: const TextStyle(fontSize: 34)),
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
                      child: Text('${formatKm(km)} km',
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
              correct
                  ? 'Correct! +${_lastRoundScore!.toStringAsFixed(1)}'
                  : (timedOut ? "Time's up" : 'Wrong'),
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
            Text(completed ? 'All Rounds Complete!' : 'Game Over',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kInk)),
            const SizedBox(height: 26),
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 26),
              child: Column(children: [
                Text(_totalScore.toStringAsFixed(1),
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: _accent)),
                const Text('TOTAL SCORE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: kMuted)),
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
            GradientButton(label: 'Play Again', color: _accent, onPressed: _retry),
            const SizedBox(height: 10),
            GradientButton(
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
            Text(total.toStringAsFixed(1),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
            Text('best ${best.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kMuted)),
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
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kInk)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: kMuted)),
      ]),
    );
  }
}