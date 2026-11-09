import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

import '../../models/stats.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import 'compare_screen.dart';

class DnaTab extends StatelessWidget {
  const DnaTab({super.key, required this.cmp});

  final Comparison cmp;

  @override
  Widget build(BuildContext context) {
    final name = cmp.friend.displayName;
    final mine = cmp.me.dna;
    final theirs = cmp.friend.dna;
    if (mine.isEmpty && theirs.isEmpty) {
      return TabList(children: [
        EmptyHint(tr('Neither of you has taken the Travel DNA test yet.\nTry the travel personality test in Travelog!'), emoji: '🧬'),
      ]);
    }

    final shared = dnaAxes.keys.where((k) => mine.containsKey(k) && theirs.containsKey(k)).toList()
      ..sort((a, b) => (mine[b]! - theirs[b]!).abs().compareTo((mine[a]! - theirs[a]!).abs()));

    String side(String axis, double v) {
      final (left, right, _, _) = dnaAxes[axis]!;
      if (v >= 60) return right;
      if (v <= 40) return left;
      return tr('balanced');
    }

    return TabList(children: [
      if (cmp.dnaSimilarity != null)
        SectionCard(
          emoji: '🧬',
          title: tr('Travel DNA match'),
          tint: AppColors.indigo,
          child: Column(children: [
            Gauge(value: (cmp.dnaSimilarity! * 100).round(), size: 200),
            const SizedBox(height: 8),
            if (shared.isNotEmpty) ...[
              FactTile(
                emoji: '⚡',
                color: AppColors.friend,
                text: '${tr('Biggest difference')}: ${tr(dnaAxes[shared.first]!.$1)} ↔ ${tr(dnaAxes[shared.first]!.$2)} '
                    '(${tr('you')}: ${side(shared.first, mine[shared.first]!)}, $name: ${side(shared.first, theirs[shared.first]!)})',
              ),
              FactTile(
                emoji: '🤝',
                color: AppColors.both,
                text: '${tr('Most alike')}: ${tr(dnaAxes[shared.last]!.$1)} ↔ ${tr(dnaAxes[shared.last]!.$2)} '
                    '(${tr('both')}: ${side(shared.last, (mine[shared.last]! + theirs[shared.last]!) / 2)})',
              ),
            ],
          ]),
        )
      else
        EmptyHint(mine.isEmpty ? tr("You haven't taken the Travel DNA test yet") : tr("$name's Travel DNA is missing or private"), emoji: '🧪'),
      SectionCard(
        emoji: '🎚️',
        title: tr('8 travel traits'),
        tint: AppColors.friend,
        trailing: VsLegend(friendName: name, showBoth: false),
        child: Column(children: [
          for (final e in dnaAxes.entries)
            DnaAxisRow(
              left: tr(e.value.$1),
              right: tr(e.value.$2),
              leftEmoji: e.value.$3,
              rightEmoji: e.value.$4,
              mine: mine[e.key],
              theirs: theirs[e.key],
            ),
        ]),
      ),
      if (shared.isNotEmpty)
        SectionCard(
          emoji: '🧳',
          title: tr('If you travel together'),
          tint: AppColors.mint,
          child: Column(children: [for (final tip in _tips(shared, mine, theirs, name)) FactTile(emoji: tip.$1, text: tip.$2)]),
        ),
    ]);
  }

  List<(String, String)> _tips(List<String> axes, Map<String, double> a, Map<String, double> b, String name) {
    final tips = <(String, String)>[];
    for (final k in axes) {
      final diff = (a[k]! - b[k]!).abs();
      final avg = (a[k]! + b[k]!) / 2;
      switch (k) {
        case 'budget_luxury' when diff > 25:
          tips.add(('💸', tr('Agree on a hotel budget early: one of you loves a bargain, the other loves luxury.')));
        case 'planned_spontaneous' when diff > 25:
          tips.add(('📋', tr("Plan the big stuff and leave a day open for spontaneity. You'll both be happy.")));
        case 'morning_night' when diff > 25:
          tips.add(('🌙', tr('Early bird meets night owl! Let one lead the mornings and the other the night tours.')));
        case 'nature_culture' when diff > 25:
          tips.add(('🏞️', tr('Mix nature and culture: a day at a national park, then a day at museums.')));
        case 'relaxed_intensive' when diff > 25:
          tips.add(('🏖️', tr('Be sure to add rest days between the busy ones.')));
        case 'solo_social' when diff > 25:
          tips.add(('🧍', tr('Try taking a day of solo free time each.')));
        case 'transit_drive' when diff > 25:
          tips.add(('🚗', tr('You get around differently. Try transit in cities and a rental car for day trips.')));
        case 'nature_culture' when diff <= 15:
          tips.add((avg > 55 ? '🏛️' : '🌲', avg > 55 ? tr('Both culture lovers! A city trip full of museums and historic sites is perfect.') : tr('Both nature lovers! Try a trip of hikes and national parks.')));
        case 'budget_luxury' when diff <= 15 && avg > 60:
          tips.add(('💎', tr('You both love luxury. How about a hotel getaway?')));
        default:
          break;
      }
    }
    if (tips.isEmpty) tips.add(('✨', tr('Your travel styles match well. Anywhere with $name will be fun!')));
    return tips;
  }
}
