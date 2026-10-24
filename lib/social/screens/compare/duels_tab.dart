import 'package:flutter/material.dart';

import '../../models/duel.dart';
import '../../models/stats.dart';
import '../../services/social_store.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import '../duels_screen.dart';
import '../new_duel_sheet.dart';
import 'compare_screen.dart';

class DuelsTab extends StatelessWidget {
  const DuelsTab({super.key, required this.cmp});

  final Comparison cmp;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final theme = Theme.of(context);
    final friendUid = cmp.friend.uid;
    final name = cmp.friend.displayName;
    final duels = store.duelsWith(friendUid);
    final finished = duels.where((d) => d.isFinished).toList();
    final wins = finished.where((d) => d.winner == store.uid).length;
    final losses = finished.where((d) => d.winner == friendUid).length;
    final draws = finished.length - wins - losses;

    // 유형별 전적
    final byMode = <String, (int, int)>{};
    for (final d in finished) {
      final (w, l) = byMode[d.mode] ?? (0, 0);
      byMode[d.mode] = (w + (d.winner == store.uid ? 1 : 0), l + (d.winner == friendUid ? 1 : 0));
    }
    final total = finished.length;

    return TabList(children: [
      SectionCard(
        emoji: '⚔️',
        title: 'Head-to-head',
        tint: AppColors.indigo,
        child: Column(children: [
          Row(children: [
            Expanded(child: _score(context, '$wins', 'Wins', AppColors.me)),
            Expanded(child: _score(context, '$draws', 'Draws', AppColors.label)),
            Expanded(child: _score(context, '$losses', 'Losses', AppColors.friend)),
          ]),
          if (total > 0) ...[
            const SizedBox(height: 12),
            OverlapBar(onlyMine: wins, both: draws, onlyTheirs: losses, height: 18),
            const SizedBox(height: 6),
            Text('Win rate ${(wins / total * 100).round()}%', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => startDuelFlow(context, cmp.friend),
            icon: const Text('🎯'),
            label: Text('Challenge $name', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
      if (byMode.isNotEmpty)
        SectionCard(
          emoji: '🗂️',
          title: 'Record by mode',
          tint: AppColors.friend,
          child: Column(children: [
            for (final e in byMode.entries)
              VsBar(
                label: duelModeOf(e.key).title,
                mine: e.value.$1,
                theirs: e.value.$2,
              ),
          ]),
        ),
      SectionCard(
        emoji: '📜',
        title: 'History',
        tint: AppColors.gold,
        subtitle: '${duels.length} ${duels.length == 1 ? 'duel' : 'duels'}',
        child: duels.isEmpty
            ? const EmptyHint('No duels yet', emoji: '🎲')
            : Column(children: [for (final d in duels) DuelTile(duel: d)]),
      ),
    ]);
  }

  Widget _score(BuildContext context, String v, String label, Color color) => Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(v,
              maxLines: 1,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: color)),
        ),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
      ]);
}
