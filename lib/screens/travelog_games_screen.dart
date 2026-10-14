// lib/screens/travelog_games_screen.dart
import 'package:flutter/material.dart';
import 'package:jidoapp/games/flag_guess.dart';
import 'package:jidoapp/games/which_is_farther.dart';
import 'package:jidoapp/games/border_chain.dart';
import 'package:jidoapp/games/respawn.dart';
import 'package:jidoapp/games/timezone_impostor.dart';
import 'package:jidoapp/games/higher_or_lower.dart';

import 'package:jidoapp/services/game_ad_service.dart';

// ─────────────────────────────────────────────
// Flowing gradient background — same animated "color river" effect used
// on the Travelog Games entry card in My Trips, reused here for the hub
// header so both surfaces read as one continuous visual family.
// The color list is duplicated so the strip can scroll seamlessly with
// no visible seam between the last and first color.
// ─────────────────────────────────────────────
class _FlowingGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final Duration duration;

  const _FlowingGradientBackground({
    required this.colors,
    this.duration = const Duration(seconds: 6),
  });

  @override
  State<_FlowingGradientBackground> createState() => _FlowingGradientBackgroundState();
}

class _FlowingGradientBackgroundState extends State<_FlowingGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loopColors = [...widget.colors, ...widget.colors];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dx = -_controller.value * width;
              return Stack(
                children: [
                  Positioned(
                    left: dx,
                    top: 0,
                    bottom: 0,
                    width: width * 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: loopColors,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Hub screen for all Travelog mini-games — restyled to match the
/// flowing teal → cyan → blue → lavender palette used by the
/// "Travelog Games" entry card on the My Trips tab.
class TravelogGamesScreen extends StatefulWidget {
  const TravelogGamesScreen({super.key});

  @override
  State<TravelogGamesScreen> createState() => _TravelogGamesScreenState();
}

class _TravelogGamesScreenState extends State<TravelogGamesScreen> {
  static const Color pageBackground = Color(0xFFF6FBF9);

  // Same flowing color river as the My Trips entry card.
  static const List<Color> _gameFlow = [
    Color(0xFF087F6B),
    Color(0xFF12A594),
    Color(0xFF45B9A8),
    Color(0xFF3FA9C6),
    Color(0xFF6688C7),
    Color(0xFF18A58B),
  ];

  // Per-game accent colors sampled directly from the flow above, so every
  // list card ties back to the same palette as the header and the card.
  static const Color shade1 = Color(0xFF087F6B); // deep teal
  static const Color shade2 = Color(0xFF12A594); // teal
  static const Color shade3 = Color(0xFF45B9A8); // seafoam
  static const Color shade4 = Color(0xFF3FA9C6); // sky teal
  static const Color shade5 = Color(0xFF6688C7); // periwinkle
  static const Color shade6 = Color(0xFF18A58B); // emerald teal

  @override
  void initState() {
    super.initState();
    // Entering the games hub pauses the main app's touch/time ad triggers
    // (without resetting them) and switches to this screen's own ad world.
    GameAdService.instance.enterGamesArea();
  }

  @override
  void dispose() {
    // Fully leaving the games hub resumes the main app's ad triggers with
    // whatever had already accumulated.
    GameAdService.instance.exitGamesArea();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _GameListCard(
                    title: 'Flag Guess',
                    subtitle: 'Guess the country from its flag',
                    icon: Icons.flag_rounded,
                    color: shade1,
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
                    color: shade2,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WhichIsFartherDifficultyScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GameListCard(
                    title: 'Border Chain',
                    subtitle: 'Link neighboring countries',
                    icon: Icons.link_rounded,
                    color: shade3,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BorderChainDifficultyScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GameListCard(
                    title: 'Respawn',
                    subtitle: 'Get randomly reborn',
                    icon: Icons.casino_rounded,
                    color: shade4,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RespawnModeScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GameListCard(
                    title: 'Timezone Impostor',
                    subtitle: 'Spot the odd timezone out',
                    icon: Icons.schedule_rounded,
                    color: shade5,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TimezoneImpostorDifficultyScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GameListCard(
                    title: 'Higher or Lower',
                    subtitle: 'Pick the bigger one',
                    icon: Icons.swap_vert_rounded,
                    color: shade6,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HigherOrLowerModeScreen()),
                    ),
                  ),
                  // Add future games as additional _GameListCard entries here.
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        width: double.infinity,
        height: 168,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF168F86).withOpacity(0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // Animated color river — same as the My Trips entry card.
            _FlowingGradientBackground(colors: _gameFlow),

            // Soft mint glow, top-left.
            Positioned(
              left: -45,
              top: -65,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFBFF3E6).withOpacity(0.35),
                      const Color(0xFFBFF3E6).withOpacity(0.00),
                    ],
                  ),
                ),
              ),
            ),

            // Sky-blue glow, top-right.
            Positioned(
              right: 20,
              top: -70,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC8E9FF).withOpacity(0.34),
                      const Color(0xFFC8E9FF).withOpacity(0.00),
                    ],
                  ),
                ),
              ),
            ),

            // Lavender glow, bottom-right.
            Positioned(
              right: -55,
              bottom: -95,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFD8D5FF).withOpacity(0.30),
                      const Color(0xFFD8D5FF).withOpacity(0.00),
                    ],
                  ),
                ),
              ),
            ),

            // Faint cream accent, bottom-left.
            Positioned(
              left: 90,
              bottom: -55,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFF0CC).withOpacity(0.18),
                      const Color(0xFFFFF0CC).withOpacity(0.00),
                    ],
                  ),
                ),
              ),
            ),

            // Overall glass highlight, matching the card's sheen.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.10),
                      Colors.transparent,
                      const Color(0xFF2C4D72).withOpacity(0.08),
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),

            // Faint decorative icons scattered in the background.
            Positioned(
              top: -14,
              right: 6,
              child: Transform.rotate(
                angle: 0.35,
                child: Icon(Icons.public_rounded, size: 64, color: Colors.white.withOpacity(0.10)),
              ),
            ),
            Positioned(
              bottom: -18,
              right: 78,
              child: Transform.rotate(
                angle: -0.25,
                child: Icon(Icons.flag_rounded, size: 40, color: Colors.white.withOpacity(0.10)),
              ),
            ),
            Positioned(
              bottom: -10,
              right: -6,
              child: Transform.rotate(
                angle: 0.2,
                child: Icon(Icons.casino_rounded, size: 46, color: Colors.white.withOpacity(0.09)),
              ),
            ),

            // Content.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFD9F5EC),
                              Color(0xFFCFE7FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.50), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 9,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.sports_esports_rounded, color: Color(0xFF176C73), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDF4F0).withOpacity(0.20),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: const Color(0xFFDDF4F0).withOpacity(0.24),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'PLAY & EXPLORE',
                                style: TextStyle(
                                  color: Color(0xFFE2FFF8),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.1,
                                  height: 1.05,
                                ),
                                children: [
                                  TextSpan(text: 'Travelog ', style: TextStyle(color: Colors.white)),
                                  TextSpan(text: 'Games', style: TextStyle(color: Color(0xFFD1FAE5))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Test your travel smarts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.14), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(color, Colors.white, 0.82)!,
                    Color.lerp(color, Colors.white, 0.68)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [color, Color.lerp(color, Colors.black, 0.35)!],
                    ).createShader(bounds),
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}