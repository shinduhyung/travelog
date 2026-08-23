// lib/screens/which_is_farther_difficulty_screen.dart
import 'package:flutter/material.dart';
import 'package:jidoapp/data/which_is_farther_data.dart';
import 'package:jidoapp/screens/which_is_farther_lobby_screen.dart';
import 'package:jidoapp/widgets/which_is_farther_ui.dart';

/// Difficulty picker for Which Is Farther. All four tiers are open — the
/// difficulty controls how close the two candidate distances are (Easy:
/// 20-50% apart, Expert: 0.3-3% apart), not how many cities are in play.
class WhichIsFartherDifficultyScreen extends StatelessWidget {
  const WhichIsFartherDifficultyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Which Is Farther?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kInk),
        ),
        iconTheme: const IconThemeData(color: kInk),
      ),
      body: ScreenBackground(
        accent: accentFor(WhichIsFartherDifficulty.hard),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 32),
            children: [
              Text('CHOOSE A DIFFICULTY',
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: kMuted)),
              const SizedBox(height: 16),
              _DifficultyCard(
                difficulty: WhichIsFartherDifficulty.easy,
                subtitle: 'Big gaps · 12s',
                icon: Icons.sentiment_satisfied_alt_rounded,
                onTap: () => _openLobby(context, WhichIsFartherDifficulty.easy),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: WhichIsFartherDifficulty.medium,
                subtitle: 'Closer calls · gets faster',
                icon: Icons.sentiment_neutral_rounded,
                onTap: () => _openLobby(context, WhichIsFartherDifficulty.medium),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: WhichIsFartherDifficulty.hard,
                subtitle: 'Tight margins',
                icon: Icons.sentiment_very_dissatisfied_rounded,
                onTap: () => _openLobby(context, WhichIsFartherDifficulty.hard),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: WhichIsFartherDifficulty.expert,
                subtitle: 'Photo finishes',
                icon: Icons.local_fire_department_rounded,
                onTap: () => _openLobby(context, WhichIsFartherDifficulty.expert),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLobby(BuildContext context, WhichIsFartherDifficulty difficulty) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WhichIsFartherLobbyScreen(difficulty: difficulty)),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final WhichIsFartherDifficulty difficulty;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentFor(difficulty);
    return GestureDetector(
      onTap: onTap,
      child: SoftCard(
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
                  Text(labelFor(difficulty),
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: kInk)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12.5, color: kMuted, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 22, color: kFaint),
          ],
        ),
      ),
    );
  }
}
