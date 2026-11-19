import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/country_provider.dart';
import '../screens/countries_map_screen.dart';
import '../services/ad_service.dart';

/// Onboarding A/B 'direct_add' group: instead of the 6-step tutorial, the app
/// opens straight on My Trips and a coach mark points at the Countries "+"
/// button so the user registers visited countries right away.
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

  static void _log(int step, String name, String action, {int? selections}) {
    AdService.instance.logTutorialStep(
      step: step,
      stepName: name,
      action: action,
      selections: selections,
    );
  }

  static Future<void> maybeShow(BuildContext context) async {
    if (!pending.value || _showing) return;
    final keyContext = buttonKey.currentContext;
    if (keyContext == null) return;
    _showing = true;

    // Bring the Countries row into view before measuring it.
    await Scrollable.ensureVisible(
      keyContext,
      alignment: 0.4,
      duration: const Duration(milliseconds: 250),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) {
      _showing = false;
      return;
    }
    final box = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (box == null || !box.attached || overlay == null) {
      _showing = false;
      return;
    }
    final target = box.localToGlobal(Offset.zero) & box.size;

    late OverlayEntry entry;
    var done = false;
    Future<void> close({required bool add}) async {
      if (done) return;
      done = true;
      entry.remove();
      _log(10, 'direct_coach', add ? 'complete' : 'skip');
      if (add && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CountriesMapScreen()),
        );
        if (context.mounted) {
          final n = context.read<CountryProvider>().visitedCountries.length;
          _log(11, 'direct_countries', 'complete', selections: n);
        }
      }
      pending.value = false;
      _showing = false;
      onFinished?.call();
    }

    entry = OverlayEntry(
      builder: (_) => _CoachOverlay(
        target: target,
        onAdd: () => close(add: true),
        onLater: () => close(add: false),
      ),
    );
    overlay.insert(entry);
    _log(10, 'direct_coach', 'view');
  }
}

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({
    required this.target,
    required this.onAdd,
    required this.onLater,
  });

  final Rect target;
  final VoidCallback onAdd;
  final VoidCallback onLater;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final t = widget.target;
    final center = t.center;
    final radius = t.longestSide / 2 + 10;
    // Card goes above the button when the button sits in the lower half.
    final cardAbove = center.dy > size.height * 0.5;

    final card = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Start your travel map'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              tr("Tap + to add the countries you've visited."),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onLater,
                child: Text(tr('Later')),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        // Scrim with a hole over the button. Taps on the scrim are absorbed.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(
              painter: _ScrimPainter(center: center, radius: radius),
            ),
          ),
        ),
        // Pulsing ring around the button.
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final r = radius + 14 * _pulse.value;
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
                      color: Colors.white.withOpacity(1 - _pulse.value),
                      width: 3,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // The hole itself is the tap target.
        Positioned(
          left: center.dx - radius,
          top: center.dy - radius,
          width: radius * 2,
          height: radius * 2,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onAdd,
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: cardAbove ? null : center.dy + radius + 18,
          bottom: cardAbove ? size.height - center.dy + radius + 18 : null,
          child: card,
        ),
      ],
    );
  }
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
    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.62));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.center != center || old.radius != radius;
}
