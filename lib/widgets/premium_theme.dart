import 'package:flutter/material.dart';
import 'package:jidoapp/services/subscription_service.dart';

/// Shared color palette for the three premium tiers, kept in sync with
/// subscription_sheet.dart's paywall: Monthly = green, Yearly = mint/teal
/// (brand color), Lifetime = purple→violet→pink.
class PremiumTheme {
  PremiumTheme._();

  static const List<Color> monthly = [Color(0xFF34D399), Color(0xFF10B981)];
  static const List<Color> yearly = [Color(0xFF3DDAD7), Color(0xFF00A39F)];
  static const List<Color> lifetime = [
    Color(0xFF6D28D9),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
  ];

  /// Colors for [kind]. Falls back to [yearly] for [PremiumPlanKind.none]
  /// so call sites don't need a null-check just to pick a default tone.
  static List<Color> colorsFor(PremiumPlanKind kind) {
    switch (kind) {
      case PremiumPlanKind.monthly:
        return monthly;
      case PremiumPlanKind.yearly:
        return yearly;
      case PremiumPlanKind.lifetime:
        return lifetime;
      case PremiumPlanKind.none:
        return yearly;
    }
  }

  /// Only Lifetime gets the rotating-border / vivid-fill treatment.
  static bool isVivid(PremiumPlanKind kind) => kind == PremiumPlanKind.lifetime;
}

/// Wraps [child] in a border of constant [borderWidth], colored with
/// [colors]. When [animated] is false it's a static gradient (or a flat
/// color, if [colors] has a single distinct entry repeated) — when true,
/// the gradient visibly spins around the shape using a rotating
/// [SweepGradient], giving a "light chasing around the edge" effect.
///
/// Works for circular avatars too: pass a square [child]/size and set
/// [borderRadius] to half the side length.
class PremiumGradientBorder extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final bool animated;
  final double borderWidth;
  final double borderRadius;

  const PremiumGradientBorder({
    super.key,
    required this.child,
    required this.colors,
    required this.animated,
    this.borderWidth = 2.5,
    this.borderRadius = 18,
  });

  @override
  State<PremiumGradientBorder> createState() => _PremiumGradientBorderState();
}

class _PremiumGradientBorderState extends State<PremiumGradientBorder>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget inner = ClipRRect(
      borderRadius:
      BorderRadius.circular(widget.borderRadius - widget.borderWidth),
      child: widget.child,
    );

    if (!widget.animated) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            colors: widget.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(widget.borderWidth),
        child: inner,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              // 3색을 두 바퀴 반복 배치 -> 색 전체가 고르게 도는 느낌.
              gradient: SweepGradient(
                colors: [...widget.colors, ...widget.colors, widget.colors.first],
                transform: GradientRotation(_controller!.value * 6.283185307179586),
              ),
            ),
            padding: EdgeInsets.all(widget.borderWidth),
            child: inner,
          );
        },
      ),
    );
  }
}