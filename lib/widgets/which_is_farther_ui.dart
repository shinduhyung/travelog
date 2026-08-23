// lib/widgets/which_is_farther_ui.dart
//
// Shared visual language for Which Is Farther — palette, a soft-card
// wrapper, a tactile gradient button, and a tinted screen background.
// Deliberately self-contained (not shared with the Flag Guess feature)
// so the two mini-games stay independent of each other, even though the
// tokens are near-identical by design for a consistent app-wide feel.

import 'package:flutter/material.dart';
import 'package:jidoapp/data/which_is_farther_data.dart';

const Color kInk = Color(0xFF1A1B23);
const Color kMuted = Color(0xFF8E8E9B);
const Color kFaint = Color(0xFFC7C7D1);
const Color kSurface = Color(0xFFFAFAFC);

Color accentFor(WhichIsFartherDifficulty d) {
  switch (d) {
    case WhichIsFartherDifficulty.easy:
      return const Color(0xFF2FBE73);
    case WhichIsFartherDifficulty.medium:
      return const Color(0xFFFF9F1C);
    case WhichIsFartherDifficulty.hard:
      return const Color(0xFFFF5A5F);
    case WhichIsFartherDifficulty.expert:
      return const Color(0xFF3E63DD);
  }
}

String labelFor(WhichIsFartherDifficulty d) {
  switch (d) {
    case WhichIsFartherDifficulty.easy:
      return 'Easy';
    case WhichIsFartherDifficulty.medium:
      return 'Medium';
    case WhichIsFartherDifficulty.hard:
      return 'Hard';
    case WhichIsFartherDifficulty.expert:
      return 'Expert';
  }
}

/// A soft, elevated white card — the base building block for nearly every
/// piece of chrome in this feature.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  const SoftCard({
    super.key,
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

/// A gradient, tactile primary button with a subtle press-scale animation.
class GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;
  final bool outlined;

  const GradientButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
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
              Text(widget.label,
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
class ScreenBackground extends StatelessWidget {
  final Color accent;
  final Widget child;

  const ScreenBackground({super.key, required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withOpacity(0.14), kSurface],
          stops: const [0.0, 0.4],
        ),
      ),
      child: child,
    );
  }
}
