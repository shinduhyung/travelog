import 'package:flutter/material.dart';

import '../models/social_profile.dart';

const _gameNames = {
  'which_is_farther_scores_': 'Which Is Farther',
  'border_chain_scores_': 'Border Chain',
  'flag_guess_scores_': 'Flag Guess',
  'timezone_impostor_scores_': 'Timezone Impostor',
  'higher_or_lower_scores_': 'Higher or Lower',
};

/// flag_guess_scores_hard -> "국기 맞히기 · hard"
String gameLabel(String key) {
  for (final e in _gameNames.entries) {
    if (key.startsWith(e.key)) {
      final variant = key.substring(e.key.length).replaceAll('_', ' ');
      return variant.isEmpty ? e.value : '${e.value} · $variant';
    }
  }
  return key;
}

String formatScore(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

String formatElapsed(int? ms) {
  if (ms == null) return '-';
  final seconds = ms / 1000;
  return seconds < 60
      ? '${seconds.toStringAsFixed(1)}s'
      : '${seconds.round() ~/ 60}m ${(seconds.round() % 60).toString().padLeft(2, '0')}s';
}

String formatPercent(QuizStats q) =>
    q.solved == 0 ? '-' : '${(q.accuracy * 100).round()}% (${q.correct}/${q.solved})';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.photoUrl, this.radius = 20});

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
      child: Text(initial),
    );
  }
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
