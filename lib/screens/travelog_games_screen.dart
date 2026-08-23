// lib/screens/travelog_games_screen.dart
import 'package:flutter/material.dart';
import 'package:jidoapp/screens/flag_guess_difficulty_screen.dart';
import 'package:jidoapp/screens/which_is_farther_difficulty_screen.dart';

/// Hub screen for all Travelog mini-games.
class TravelogGamesScreen extends StatelessWidget {
  const TravelogGamesScreen({super.key});

  static const Color darkMint = Color(0xFF009688);
  static const Color skyBlue = Color(0xFF3E63DD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Travelog Games',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _GameListCard(
            title: 'Flag Guess',
            subtitle: 'Guess the country from its flag',
            icon: Icons.flag_rounded,
            color: darkMint,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const FlagGuessDifficultyScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _GameListCard(
            title: 'Which Is Farther?',
            subtitle: 'Pick the more distant city',
            icon: Icons.public_rounded,
            color: skyBlue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const WhichIsFartherDifficultyScreen()),
            ),
          ),
          // Add future games as additional _GameListCard entries here.
        ],
      ),
    );
  }
}

class _GameListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GameListCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}