import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';

import '../../data/geo_data.dart';
import '../../models/stats.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import 'compare_screen.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.cmp});

  final Comparison cmp;

  String get _verdict {
    final s = cmp.compatibility;
    if (s >= 80) return tr('Soulmate travelers 🫶');
    if (s >= 60) return tr('Great travel buddies ✈️');
    if (s >= 40) return tr('Lots to learn from each other 📚');
    if (s >= 20) return tr('Totally different styles 🔀');
    return tr('Barely any overlap yet 🌱');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = cmp.friend.displayName;
    return TabList(children: [
      SectionCard(
        emoji: '💞',
        tint: AppColors.both,
        title: tr('Travel match'),
        subtitle: tr('Shared places & travel style'),
        child: Column(
          children: [
            Gauge(value: cmp.compatibility, size: 210),
            const SizedBox(height: 6),
            Text(
              _verdict,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (label, value) in [
                  ('Countries', '${cmp.countries.both.length}'),
                  ('Cities', '${cmp.cities.both.length}'),
                  ('Landmarks', '${cmp.landmarks.both.length}'),
                  if (cmp.dnaSimilarity != null) ('DNA', '${(cmp.dnaSimilarity! * 100).round()}%'),
                ]) ...[
                  Expanded(child: _pill(context, tr(label), value, AppColors.both)),
                  const SizedBox(width: 6),
                ],
              ]..removeLast(),
            ),
            const SizedBox(height: 4),
            Text(tr('in common'), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label)),
          ],
        ),
      ),
      SectionCard(
        emoji: '🕸️',
        tint: AppColors.indigo,
        title: tr('Travel radar'),
        subtitle: tr('Leader = 100%'),
        trailing: VsLegend(friendName: shortName(name), showBoth: false),
        child: RadarVs(axes: cmp.radar, size: 260),
      ),
      SectionCard(
        emoji: '🏁',
        tint: AppColors.gold,
        title: tr('Category score ${cmp.myWins} : ${cmp.theirWins}'),
        subtitle: cmp.myWins == cmp.theirWins
            ? tr('Neck and neck!')
            : cmp.myWins > cmp.theirWins
                ? tr("You're in the lead")
                : tr('$name is in the lead'),
        child: Column(
          children: [
            for (final c in cmp.categories) VsBar(label: tr(c.label), emoji: c.emoji, mine: c.mine, theirs: c.theirs),
          ],
        ),
      ),
      SectionCard(
        emoji: '💡',
        tint: AppColors.mint,
        title: tr('Did you know?'),
        child: Column(children: _facts(context)),
      ),
    ]);
  }

  Widget _pill(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  List<Widget> _facts(BuildContext context) {
    final name = cmp.friend.displayName;
    final geo = GeoData.I;
    String cn(String n) => geo.countryByName(n)?.longName ?? n;
    String countries(int n) => n == 1 ? tr('1 country') : tr('$n countries');
    final facts = <Widget>[];

    if (cmp.countries.both.isNotEmpty) {
      final byContinent = <String, int>{};
      for (final c in cmp.countries.both) {
        final ct = geo.countryByName(c)?.continent;
        if (ct != null) byContinent[ct] = (byContinent[ct] ?? 0) + 1;
      }
      final top = byContinent.entries.isEmpty ? null : byContinent.entries.reduce((a, b) => a.value >= b.value ? a : b);
      facts.add(FactTile(
        emoji: '🤝',
        color: AppColors.both,
        text: tr("You've both been to ${countries(cmp.countries.both.length)}") +
            (top == null ? '' : ' · ${tr('Most overlap: ${continentLabel(top.key)} (${top.value})')}'),
      ));
    } else {
      facts.add(FactTile(emoji: '🌱', text: tr('No countries in common yet. Time to plan your first shared trip!')));
    }

    final sameYear = cmp.sameYearTrips;
    if (sameYear.isNotEmpty) {
      final (c, y) = sameYear.first;
      facts.add(FactTile(
        emoji: '📅',
        color: AppColors.both,
        text: tr('You were both in ${cn(c)} in $y!') +
            (sameYear.length > 1 ? ' ${tr('(${sameYear.length} same-country, same-year trips)')}' : ''),
      ));
    }

    final gaps = cmp.ratingGaps.where((g) => (g.$2 - g.$3).abs() >= 1).toList();
    if (gaps.isNotEmpty) {
      final (c, a, b) = gaps.first;
      facts.add(FactTile(
        emoji: a > b ? '😍' : '🤔',
        text: tr('Biggest rating gap: ${cn(c)} — You ★${a.toStringAsFixed(1)}, $name ★${b.toStringAsFixed(1)}'),
      ));
    }

    if (cmp.wishOverlap.isNotEmpty) {
      facts.add(FactTile(
        emoji: '💭',
        color: AppColors.gold,
        text: '${tr('On both your wishlists:')} ${cmp.wishOverlap.take(4).map(cn).join(', ')}'
            '${cmp.wishOverlap.length > 4 ? ' ${tr('+${cmp.wishOverlap.length - 4} more')}' : ''}. ${tr('Go together?')}',
      ));
    }

    final rec = cmp.recommendForMe;
    if (rec.isNotEmpty) {
      facts.add(FactTile(
        emoji: '🧭',
        color: AppColors.friend,
        text: '${tr("$name has been, you haven't yet:")} ${rec.take(3).map(cn).join(', ')}',
      ));
    }

    final km1 = cmp.mine.totalFlightKm, km2 = cmp.theirs.totalFlightKm;
    if (km1 > 0 || km2 > 0) {
      final more = km1 >= km2 ? tr('You') : name;
      facts.add(FactTile(
        emoji: '✈️',
        text: '${tr('$more flew farther')} — ${compactNumber(km1.round())} km vs ${compactNumber(km2.round())} km '
            '(${tr('${(km1 > km2 ? cmp.mine.earthLaps : cmp.theirs.earthLaps).toStringAsFixed(1)} laps around Earth')})',
      ));
    }

    final a1 = cmp.mine.areaPercent, a2 = cmp.theirs.areaPercent;
    facts.add(FactTile(
      emoji: '🌐',
      text: tr("Share of Earth's land visited: You ${(a1 * 100).toStringAsFixed(1)}%, $name ${(a2 * 100).toStringAsFixed(1)}%"),
    ));

    final b1 = cmp.mine.biggestCity, b2 = cmp.theirs.biggestCity;
    if (b1 != null && b2 != null) {
      facts.add(FactTile(
        emoji: '🏙️',
        text: tr('Biggest city: You — ${b1.displayName} (pop. ${compactNumber(b1.population)}), '
            '$name — ${b2.displayName} (pop. ${compactNumber(b2.population)})'),
      ));
    }

    if (cmp.dnaSimilarity != null) {
      facts.add(FactTile(
        emoji: '🧬',
        color: AppColors.both,
        text: tr('Your travel styles are ${(cmp.dnaSimilarity! * 100).round()}% alike. See the Travel DNA tab for more!'),
      ));
    }
    return facts;
  }
}
