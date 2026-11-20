import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/country_provider.dart';
import '../screens/countries_map_screen.dart';
import '../services/ad_service.dart';

/// Onboarding A/B 'direct_add' group: instead of the 6-step tutorial, the app
/// opens straight on My Trips and a two-step coach mark walks the user to
/// registering visited countries:
///   1. My Trips → the Countries "+" button
///   2. Countries map → the "+" button that opens the country picker
///
/// main.dart sets [pending] (and [onFinished]) when the user taps
/// "Get Started" on the welcome screen. MyTripsTabScreen tags the Countries
/// "+" button with [buttonKey] and calls [maybeShow] once it is on screen.
class DirectAddCoach {
  DirectAddCoach._();

  static final ValueNotifier<bool> pending = ValueNotifier(false);
  static final GlobalKey buttonKey = GlobalKey(debugLabel: 'direct_add_button');

  /// Marks onboarding as done (pref, paywall gate). Set by main.dart.
  static VoidCallback? onFinished;

  static bool _showing = false;

  static void log(int step, String name, String action, {int? selections}) {
    AdService.instance.logTutorialStep(
      step: step,
      stepName: name,
      action: action,
      selections: selections,
    );
  }

  /// Step 1, on My Trips.
  static Future<void> maybeShow(BuildContext context) async {
    if (!pending.value || _showing) return;
    if (buttonKey.currentContext == null) return;
    _showing = true;

    final tapped = await spotlight(
      context,
      targetKey: buttonKey,
      step: 1,
      totalSteps: 2,
      emoji: '🌍',
      title: tr('Start your travel map'),
      body: tr("Tap + to add the countries you've visited."),
    );
    if (tapped == null) {
      _showing = false;
      return; // could not be shown (screen gone); try again later
    }
    log(10, 'direct_coach', tapped ? 'complete' : 'skip');
    if (tapped && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const CountriesMapScreen(showAddCoach: true),
        ),
      );
      if (context.mounted) {
        final n = context.read<CountryProvider>().visitedCountries.length;
        log(11, 'direct_countries', 'complete', selections: n);
      }
    }
    pending.value = false;
    _showing = false;
    onFinished?.call();
  }

  /// Dims the screen, cuts a glowing hole over [targetKey] and shows a card.
  /// Returns true when the user taps the target, false on "Later", null when
  /// the target could not be found.
  static Future<bool?> spotlight(
    BuildContext context, {
    required GlobalKey targetKey,
    required int step,
    required int totalSteps,
    required String emoji,
    required String title,
    required String body,
  }) async {
    final keyContext = targetKey.currentContext;
    if (keyContext == null) return null;
    await Scrollable.ensureVisible(
      keyContext,
      alignment: 0.4,
      duration: const Duration(milliseconds: 250),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) return null;
    final box = targetKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (box == null || !box.attached || overlay == null) return null;
    final target = box.localToGlobal(Offset.zero) & box.size;

    final result = Completer<bool>();
    late OverlayEntry entry;
    void close(bool tapped) {
      if (result.isCompleted) return;
      entry.remove();
      result.complete(tapped);
    }

    entry = OverlayEntry(
      builder: (_) => _CoachOverlay(
        target: target,
        step: step,
        totalSteps: totalSteps,
        emoji: emoji,
        title: title,
        body: body,
        onTap: () => close(true),
        onLater: () => close(false),
      ),
    );
    overlay.insert(entry);
    return result.future;
  }
}

const _brand = Color(0xFF1ABFBC);
const _brandDeep = Color(0xFF0B7F86);

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({
    required this.target,
    required this.step,
    required this.totalSteps,
    required this.emoji,
    required this.title,
    required this.body,
    required this.onTap,
    required this.onLater,
  });

  final Rect target;
  final int step;
  final int totalSteps;
  final String emoji;
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onLater;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();

  @override
  void dispose() {
    _pulse.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final t = widget.target;
    final center = t.center;
    final radius = t.longestSide / 2 + 10;
    final cardAbove = center.dy > size.height * 0.5;
    const gap = 22.0;
    // Caret points at the button, kept inside the card's rounded corners.
    final caretLeft = (center.dx - 20 - 9).clamp(22.0, size.width - 40 - 18 - 22.0);

    final card = _CoachCard(
      step: widget.step,
      totalSteps: widget.totalSteps,
      emoji: widget.emoji,
      title: widget.title,
      body: widget.body,
      onLater: widget.onLater,
    );
    final caret = Padding(
      padding: EdgeInsets.only(left: caretLeft),
      child: CustomPaint(
        size: const Size(18, 10),
        painter: _CaretPainter(up: !cardAbove),
      ),
    );

    final fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);

    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: fade,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: _ScrimPainter(center: center, radius: radius),
              ),
            ),
          ),
        ),
        // Two expanding glow rings in the brand colour.
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Stack(
            children: [
              for (final phase in [0.0, 0.5])
                _ring(center, radius, (_pulse.value + phase) % 1.0),
            ],
          ),
        ),
        Positioned(
          left: center.dx - radius,
          top: center.dy - radius,
          width: radius * 2,
          height: radius * 2,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: cardAbove ? null : center.dy + radius + gap,
          bottom: cardAbove ? size.height - center.dy + radius + gap : null,
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, cardAbove ? 0.08 : -0.08),
                end: Offset.zero,
              ).animate(fade),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cardAbove ? [card, caret] : [caret, card],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ring(Offset center, double radius, double v) {
    final r = radius + 22 * v;
    return Positioned(
      left: center.dx - r,
      top: center.dy - r,
      width: r * 2,
      height: r * 2,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _brand.withOpacity((1 - v) * 0.9),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.step,
    required this.totalSteps,
    required this.emoji,
    required this.title,
    required this.body,
    required this.onLater,
  });

  final int step;
  final int totalSteps;
  final String emoji;
  final String title;
  final String body;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brand, _brandDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: _brandDeep.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
                const Spacer(),
                Row(
                  children: [
                    for (var i = 1; i <= totalSteps; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 5),
                        width: i == step ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(i == step ? 1 : 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onLater,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.75),
                ),
                child: Text(tr('Later')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter({required this.up});
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (up) {
      p
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = up ? _brand : _brandDeep);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => old.up != up;
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, Paint()..color = const Color(0xFF06262A).withOpacity(0.72));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.center != center || old.radius != radius;
}
