// lib/screens/flag_guess_game_screen.dart
//
// Gameplay screen for "Flag Guess". Flow per round:
//   3s prep countdown -> flag shown with a per-round timer -> 4-choice
//   answer -> a brief "revealed" state (clear result banner, correct answer
//   named on a miss) -> next round (or game over).
//
// Scoring: max 10 pts/round = (10 - secondsTaken), floored at 0, to 1 decimal.
// A wrong answer or a timeout ends the run immediately; the run is saved via
// FlagGuessScoreService so the lobby screen's leaderboard picks it up.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/data/flag_guess_data.dart';
import 'package:jidoapp/services/flag_guess_score_service.dart';
import 'package:jidoapp/widgets/flag_guess_ui.dart';

enum _RoundPhase { prep, playing, revealed }

class FlagGuessGameScreen extends StatefulWidget {
  final FlagGuessDifficulty difficulty;

  const FlagGuessGameScreen({super.key, required this.difficulty});

  @override
  State<FlagGuessGameScreen> createState() => _FlagGuessGameScreenState();
}

class _FlagGuessGameScreenState extends State<FlagGuessGameScreen> {
  static const int _maxRoundsCap = 30;
  static const double _maxScorePerRound = 10.0;

  // How long the post-answer "revealed" state stays up before advancing.
  // Wrong answers get longer so the correct answer is actually readable.
  static const Duration _correctRevealDuration = Duration(milliseconds: 1400);
  static const Duration _wrongRevealDuration = Duration(milliseconds: 2200);

  late List<FlagCountry> _rounds;
  late final int _maxRounds;

  int _roundIndex = 0;
  double _totalScore = 0;
  double _bestRoundScore = 0;
  int _combo = 0;

  _RoundPhase _phase = _RoundPhase.prep;
  int _prepCountdown = 3;
  Timer? _prepTimer;

  double _timeLimit = 10;
  double _remaining = 10;
  Timer? _playTimer;
  final Stopwatch _stopwatch = Stopwatch();

  Timer? _revealTimer;

  FlagCountry? _answer;
  List<FlagCountry> _choices = [];
  FlagCountry? _selected;
  double? _lastRoundScore;

  bool _gameOver = false;
  String? _endReason; // 'wrong' | 'timeout' | 'complete'
  bool _recorded = false;

  Color get _accent => accentFor(widget.difficulty);

  @override
  void initState() {
    super.initState();
    final order = buildRoundOrder(widget.difficulty);
    _maxRounds = min(_maxRoundsCap, order.length);
    _rounds = order.take(_maxRounds).toList();
    _beginPrep();
    // Kick off every image-backed flag's download right away instead of
    // waiting for each round to need it — by the time a round actually
    // shows an image flag it's very likely already sitting in Flutter's
    // image cache, so it appears instantly instead of loading live.
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheRoundImages());
  }

  void _precacheRoundImages() {
    if (!mounted) return;
    for (final country in _rounds) {
      if (!country.hasImage) continue;
      precacheImage(NetworkImage(country.imageUrl!), context).catchError((_) {
        // A single bad/slow URL shouldn't block the others — the in-round
        // errorBuilder still covers a genuine failure at display time.
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

  /// 10s -> -1s per round, floored per difficulty. Easy stays fixed at 10s.
  double _timeLimitForRound(int index) {
    switch (widget.difficulty) {
      case FlagGuessDifficulty.easy:
        return 10.0;
      case FlagGuessDifficulty.medium:
        return max(2.0, 10.0 - index);
      case FlagGuessDifficulty.hard:
      case FlagGuessDifficulty.insane:
        return max(1.0, 10.0 - index);
    }
  }

  // ── Round lifecycle ─────────────────────────────────────────────────────

  void _beginPrep() {
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
    final answer = _rounds[_roundIndex];
    final choices = _buildChoices(answer);
    final limit = _timeLimitForRound(_roundIndex);

    setState(() {
      _answer = answer;
      _choices = choices;
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

  /// Correct answer + up to 3 wrong ones, biased toward lookalike traps
  /// where the data has them (Hard's country pairs).
  List<FlagCountry> _buildChoices(FlagCountry answer) {
    final chosen = <FlagCountry>[answer];

    final similar = kSimilarFlagGroups[answer.code] ?? const <String>[];
    for (final code in similar) {
      if (chosen.length >= 4) break;
      final c = kAllCountriesByCode[code];
      if (c != null && !chosen.any((x) => x.code == c.code)) chosen.add(c);
    }
    if (chosen.length < 4) {
      for (final entry in kSimilarFlagGroups.entries) {
        if (chosen.length >= 4) break;
        if (entry.value.contains(answer.code)) {
          final c = kAllCountriesByCode[entry.key];
          if (c != null && !chosen.any((x) => x.code == c.code)) chosen.add(c);
        }
      }
    }

    final rest = distractorPoolFor(widget.difficulty)
        .where((c) => !chosen.any((x) => x.code == c.code))
        .toList()
      ..shuffle();
    for (final c in rest) {
      if (chosen.length >= 4) break;
      chosen.add(c);
    }

    chosen.shuffle();
    return chosen;
  }

  void _onSelect(FlagCountry choice) {
    if (_phase != _RoundPhase.playing) return;
    _playTimer?.cancel();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds / 1000.0;
    final correct = choice.code == _answer!.code;

    double? score;
    if (correct) {
      final raw = (_maxScorePerRound - elapsed).clamp(0.0, _maxScorePerRound);
      score = double.parse(raw.toStringAsFixed(1));
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

    HapticFeedback.selectionClick();
    _enterReveal(correct: correct);
  }

  /// Holds the flag + result on screen for a fixed, clearly-visible duration,
  /// then advances to the next round (or ends the game on a miss).
  void _enterReveal({required bool correct}) {
    setState(() => _phase = _RoundPhase.revealed);
    _revealTimer?.cancel();
    _revealTimer = Timer(correct ? _correctRevealDuration : _wrongRevealDuration, () {
      if (!mounted) return;
      if (!correct) {
        _finishGame('wrong');
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
      await FlagGuessScoreService().addRecord(
        widget.difficulty,
        FlagGuessScoreRecord(
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

  void _retry() {
    setState(() {
      _roundIndex = 0;
      _totalScore = 0;
      _bestRoundScore = 0;
      _combo = 0;
      _gameOver = false;
      _endReason = null;
      _recorded = false;
      _rounds = buildRoundOrder(widget.difficulty).take(_maxRounds).toList();
    });
    _beginPrep();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheRoundImages());
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
        actions: [_ScoreBadge(total: _totalScore, best: _bestRoundScore, accent: _accent)],
      ),
      body: ScreenBackground(
        accent: _accent,
        child: SafeArea(
          child: _gameOver ? _buildGameOver() : _buildPlayArea(),
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: revealed
                ? _buildResultBanner(key: const ValueKey('result'))
                : _buildTimerBar(ratio, barColor, key: const ValueKey('timer')),
          ),
          const SizedBox(height: 18),
          Expanded(child: Center(child: _buildFlagVisual())),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: _choices.map((c) => _buildChoiceButton(c)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar(double ratio, Color barColor, {Key? key}) {
    return Column(
      key: key,
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
    );
  }

  /// Clear, high-contrast result banner shown while `_phase == revealed`.
  /// States the correct answer by name on a miss — no emoji clutter, the
  /// flag itself is already on screen.
  Widget _buildResultBanner({Key? key}) {
    final correct = _selected != null && _selected!.code == _answer!.code;
    final color = correct ? const Color(0xFF2FBE73) : const Color(0xFFFF5A5F);

    return TweenAnimationBuilder<double>(
      key: key,
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
                    correct ? 'Correct! +${_lastRoundScore!.toStringAsFixed(1)}' : 'Wrong',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  if (!correct) ...[
                    const SizedBox(height: 2),
                    Text('Answer: ${_answer!.name}',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagVisual() {
    final country = _answer!;
    final Widget visual;
    if (country.hasImage) {
      visual = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          country.imageUrl!,
          width: 220,
          height: 147,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: 220,
              height: 147,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            width: 220,
            height: 147,
            color: kSurface,
            alignment: Alignment.center,
            child: Icon(Icons.flag_outlined, size: 36, color: kFaint),
          ),
        ),
      );
    } else {
      visual = Text(country.emoji ?? '🏳️', style: const TextStyle(fontSize: 92));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(country.hasImage ? 18 : 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(country.hasImage ? 24 : 200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 28, offset: const Offset(0, 12)),
            ],
          ),
          child: visual,
        ),
        if (country.era != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: kInk.withOpacity(0.06), borderRadius: BorderRadius.circular(20)),
            child: Text(country.era!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          ),
        ],
      ],
    );
  }

  Widget _buildChoiceButton(FlagCountry choice) {
    Color bg = Colors.white;
    Color fg = kInk;
    Color border = Colors.black.withOpacity(0.04);

    if (_phase == _RoundPhase.revealed) {
      final isAnswer = choice.code == _answer!.code;
      final isSelected = _selected?.code == choice.code;
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Text(choice.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
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
              child: Icon(completed ? Icons.emoji_events_rounded : Icons.flag_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(completed ? 'All Rounds Complete!' : 'Game Over',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kInk)),
            const SizedBox(height: 6),
            if (!completed && _answer != null)
              Text('Answer: ${_answer!.name}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kMuted)),
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