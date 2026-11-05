import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

class PollCountdown extends StatefulWidget {
  final DateTime serverNow, revealAt;
  const PollCountdown({
    super.key,
    required this.serverNow,
    required this.revealAt,
  });
  @override
  State<PollCountdown> createState() => _PollCountdownState();
}

class _PollCountdownState extends State<PollCountdown> {
  final _clock = Stopwatch();
  Timer? _tick;
  @override
  void initState() {
    super.initState();
    _clock.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(PollCountdown old) {
    super.didUpdateWidget(old);
    if (old.serverNow != widget.serverNow)
      _clock
        ..reset()
        ..start();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.revealAt.difference(
      widget.serverNow.add(_clock.elapsed),
    );
    String two(int v) => v.toString().padLeft(2, '0');
    final text = left.isNegative
        ? tr('Revealing...')
        : '${left.inDays}d ${two(left.inHours.remainder(24))}:${two(left.inMinutes.remainder(60))}:${two(left.inSeconds.remainder(60))}';
    return Text(
      text,
      key: const ValueKey('poll-countdown'),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        height: 1.1,
        fontWeight: FontWeight.w800,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
