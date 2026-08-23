// lib/screens/flag_guess_difficulty_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/data/flag_guess_data.dart';
import 'package:jidoapp/screens/flag_guess_lobby_screen.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';
import 'package:jidoapp/widgets/flag_guess_ui.dart';

/// Difficulty picker for Flag Guess. Easy / Medium / Hard are always
/// playable; Insane is gated behind Premium and opens the paywall sheet
/// when tapped by a non-subscriber.
class FlagGuessDifficultyScreen extends StatelessWidget {
  const FlagGuessDifficultyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Flag Guess',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kInk),
        ),
        iconTheme: const IconThemeData(color: kInk),
      ),
      body: ScreenBackground(
        accent: accentFor(FlagGuessDifficulty.hard),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 32),
            children: [
              Text('CHOOSE A DIFFICULTY',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: kMuted)),
              const SizedBox(height: 16),
              _DifficultyCard(
                difficulty: FlagGuessDifficulty.easy,
                subtitle: '50 flags · 10s',
                icon: Icons.sentiment_satisfied_alt_rounded,
                onTap: () => _openLobby(context, FlagGuessDifficulty.easy),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: FlagGuessDifficulty.medium,
                subtitle: 'All flags · gets faster',
                icon: Icons.sentiment_neutral_rounded,
                onTap: () => _openLobby(context, FlagGuessDifficulty.medium),
              ),
              const SizedBox(height: 14),
              _DifficultyCard(
                difficulty: FlagGuessDifficulty.hard,
                subtitle: 'All flags · trap-heavy',
                icon: Icons.sentiment_very_dissatisfied_rounded,
                onTap: () => _openLobby(context, FlagGuessDifficulty.hard),
              ),
              const SizedBox(height: 14),
              Consumer<SubscriptionService>(
                builder: (context, sub, _) {
                  final unlocked = sub.isPremium;
                  return _DifficultyCard(
                    difficulty: FlagGuessDifficulty.insane,
                    subtitle: unlocked ? 'History & regions' : 'History & regions · Premium',
                    icon: Icons.local_fire_department_rounded,
                    locked: !unlocked,
                    onTap: () {
                      if (unlocked) {
                        _openLobby(context, FlagGuessDifficulty.insane);
                      } else {
                        SubscriptionSheet.show(context, triggerContext: 'flag_guess_insane');
                      }
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

  void _openLobby(BuildContext context, FlagGuessDifficulty difficulty) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FlagGuessLobbyScreen(difficulty: difficulty)),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final FlagGuessDifficulty difficulty;
  final String subtitle;
  final IconData icon;
  final bool locked;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentFor(difficulty);
    return GestureDetector(
      onTap: onTap,
      child: SoftCard(
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
                      Text(labelFor(difficulty),
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: kInk)),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_rounded, size: 15, color: color),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12.5, color: kMuted, fontWeight: FontWeight.w500, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 22, color: kFaint),
          ],
        ),
      ),
    );
  }
}