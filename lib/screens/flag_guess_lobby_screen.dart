// lib/screens/flag_guess_lobby_screen.dart
//
// Shown after picking a difficulty, before the game itself: past-run
// history/leaderboard for that difficulty on top, "Start Game" pinned at
// the bottom. Reloads the list whenever a game finishes and this screen is
// returned to.

import 'package:flutter/material.dart';
import 'package:jidoapp/data/flag_guess_data.dart';
import 'package:jidoapp/screens/flag_guess_game_screen.dart';
import 'package:jidoapp/services/flag_guess_score_service.dart';
import 'package:jidoapp/widgets/flag_guess_ui.dart';

class FlagGuessLobbyScreen extends StatefulWidget {
  final FlagGuessDifficulty difficulty;

  const FlagGuessLobbyScreen({super.key, required this.difficulty});

  @override
  State<FlagGuessLobbyScreen> createState() => _FlagGuessLobbyScreenState();
}

class _FlagGuessLobbyScreenState extends State<FlagGuessLobbyScreen> {
  final _service = FlagGuessScoreService();
  late Future<List<FlagGuessScoreRecord>> _recordsFuture;

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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FlagGuessGameScreen(difficulty: widget.difficulty)),
    );
    // The game screen saves its record on game-over before popping back
    // here, so a fresh load will include the just-finished run.
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentFor(widget.difficulty);
    return Scaffold(
      backgroundColor: kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${labelFor(widget.difficulty)} Mode',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kInk)),
        iconTheme: const IconThemeData(color: kInk),
      ),
      body: ScreenBackground(
        accent: accent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 92, 20, 20),
            child: Column(
              children: [
                Expanded(child: _buildHistory(accent)),
                const SizedBox(height: 18),
                GradientButton(
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

  Widget _buildHistory(Color accent) {
    return FutureBuilder<List<FlagGuessScoreRecord>>(
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
                Icon(Icons.emoji_events_outlined, size: 46, color: kFaint),
                const SizedBox(height: 12),
                const Text('No runs yet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kInk)),
                const SizedBox(height: 4),
                Text('Play a round to start your leaderboard',
                    style: TextStyle(fontSize: 12.5, color: kMuted)),
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
                Text('LEADERBOARD',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: kMuted)),
                Text('${records.length} run${records.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: kFaint, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _RecordTile(
                  rank: i + 1,
                  record: records[i],
                  accent: accent,
                ),
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
  final FlagGuessScoreRecord record;
  final Color accent;

  const _RecordTile({required this.rank, required this.record, required this.accent});

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
    final medal = _medalColors[rank];
    return SoftCard(
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
              color: (medal ?? kFaint).withOpacity(medal != null ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, size: 16, color: medal)
                : Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kMuted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.score.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kInk)),
                const SizedBox(height: 2),
                Text(
                  '${record.roundsCompleted}/${record.maxRounds} rounds · combo ${record.bestCombo} · ${_formatDate(record.playedAt)}',
                  style: const TextStyle(fontSize: 11.5, color: kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}