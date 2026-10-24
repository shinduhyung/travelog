import 'package:flutter/material.dart';

import '../../data/geo_data.dart';
import '../../models/stats.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import '../../widgets/flag.dart';
import '../../widgets/top_landmarks.dart';
import '../../widgets/world_map.dart';
import 'compare_screen.dart';

class LandmarksTab extends StatelessWidget {
  const LandmarksTab({super.key, required this.cmp});

  final Comparison cmp;

  @override
  Widget build(BuildContext context) {
    final geo = GeoData.I;
    final theme = Theme.of(context);
    final name = cmp.friend.displayName;
    final l = cmp.landmarks;

    List<String> byRank(Iterable<String> names) => names.toList()
      ..sort((a, b) {
        final ra = geo.landmarks[a]?.rank ?? 0, rb = geo.landmarks[b]?.rank ?? 0;
        if (ra == 0 && rb == 0) return a.compareTo(b);
        if (ra == 0) return 1;
        if (rb == 0) return -1;
        return ra.compareTo(rb);
      });

    final dots = <MapDot>[
      for (final n in l.onlyTheirs)
        if (geo.landmarks[n] case final m?) MapDot(m.lat, m.lng, AppColors.friend, radius: 2.6),
      for (final n in l.onlyMine)
        if (geo.landmarks[n] case final m?) MapDot(m.lat, m.lng, AppColors.me, radius: 2.6),
      for (final n in l.both)
        if (geo.landmarks[n] case final m?) MapDot(m.lat, m.lng, AppColors.both, radius: 3.6),
    ];

    final top = {for (final m in top250) m.name};
    final topMine = cmp.me.landmarks.where(top.contains).toSet().length;
    final topTheirs = cmp.friend.landmarks.where(top.contains).toSet().length;

    return TabList(children: [
      SectionCard(
        emoji: '🏆',
        title: 'Landmark score',
        tint: AppColors.gold,
        trailing: VsLegend(friendName: name, showBoth: false),
        child: Column(children: [
          VsBar(label: 'Landmarks', emoji: '🗼', mine: cmp.me.landmarkCount, theirs: cmp.friend.landmarkCount),
          VsBar(label: 'Top 250', emoji: '🌟', mine: topMine, theirs: topTheirs),
          VsBar(label: 'UNESCO', emoji: '🏛️', mine: cmp.me.unescoCount, theirs: cmp.friend.unescoCount),
          VsBar(label: 'Wishlist', emoji: '💭', mine: cmp.me.landmarkWish.length, theirs: cmp.friend.landmarkWish.length),
        ]),
      ),
      if (l.both.isNotEmpty)
        SectionCard(
          emoji: '📸',
          title: 'Landmarks you both visited',
          tint: AppColors.both,
          subtitle: '${l.both.length} places',
          child: HorizontalCards(
            height: 200,
            children: [for (final n in byRank(l.both).take(20)) LandmarkCard(name: n, badge: 'Both', badgeColor: AppColors.both)],
          ),
        ),
      TopLandmarksPreview(uids: [cmp.me.uid, cmp.friend.uid]),
      if (dots.isNotEmpty)
        SectionCard(
          emoji: '🗺️',
          title: 'Landmark map',
          tint: AppColors.mint,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            WorldMap(dots: dots),
            const SizedBox(height: 10),
            MapLegend(items: [
              (AppColors.both, 'Both ${l.both.length}'),
              (AppColors.me, 'Only you ${l.onlyMine.length}'),
              (AppColors.friend, '$name only ${l.onlyTheirs.length}'),
            ]),
          ]),
        ),
      if (cmp.mine.landmarkCategories.isNotEmpty || cmp.theirs.landmarkCategories.isNotEmpty)
        SectionCard(
          emoji: '🧩',
          title: 'What you each love',
          tint: AppColors.indigo,
          subtitle: 'Landmark types',
          child: Column(children: [
            _label(context, 'You', AppColors.me),
            const SizedBox(height: 6),
            cmp.mine.landmarkCategories.isEmpty
                ? const EmptyHint('No records')
                : Donut(data: cmp.mine.landmarkCategories, center: Text('${cmp.me.landmarkCount}', style: theme.textTheme.titleMedium)),
            const Divider(height: 24),
            _label(context, name, AppColors.friend),
            const SizedBox(height: 6),
            cmp.theirs.landmarkCategories.isEmpty
                ? const EmptyHint('No records')
                : Donut(data: cmp.theirs.landmarkCategories, center: Text('${cmp.friend.landmarkCount}', style: theme.textTheme.titleMedium)),
          ]),
        ),
      SectionCard(
        emoji: '🏛️',
        title: 'UNESCO World Heritage',
        tint: AppColors.indigo,
        subtitle: 'Both ${cmp.unesco.both.length} · You ${cmp.unesco.onlyMine.length} · ${shortName(name)} ${cmp.unesco.onlyTheirs.length}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _unescoTypes(context, cmp.mine.unescoTypes, AppColors.me, 'You')),
              const SizedBox(width: 10),
              Expanded(child: _unescoTypes(context, cmp.theirs.unescoTypes, AppColors.friend, name)),
            ]),
            if (cmp.unesco.both.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Sites you both visited', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final n in cmp.unesco.both.take(12)) _unescoRow(context, n),
            ],
          ],
        ),
      ),
      if (l.onlyTheirs.isNotEmpty)
        SectionCard(
          emoji: '🧭',
          title: 'Places $name has been',
          tint: AppColors.friend,
          child: HorizontalCards(
            height: 200,
            children: [
              for (final n in byRank(l.onlyTheirs).take(15))
                LandmarkCard(
                  name: n,
                  badge: cmp.me.landmarkWish.contains(n) ? '💭 Wishlist' : null,
                  badgeColor: AppColors.gold,
                ),
            ],
          ),
        ),
    ]);
  }

  Widget _label(BuildContext context, String text, Color color) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
      ]);

  Widget _unescoTypes(BuildContext context, Map<String, int> types, Color color, String who) {
    final theme = Theme.of(context);
    const labels = {'Cultural': ('🏺', 'Cultural'), 'Natural': ('🌿', 'Natural'), 'Mixed': ('🌄', 'Mixed')};
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(who,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final e in labels.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(
                  child: Text('${e.value.$1} ${e.value.$2}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
                ),
                const SizedBox(width: 4),
                Text('${types[e.key] ?? 0}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _unescoRow(BuildContext context, String n) {
    final meta = GeoData.I.unesco[n];
    final country = GeoData.I.countryByIso3(meta?.iso3);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Flag(country?.iso2, width: 22, radius: 3),
        const SizedBox(width: 8),
        Expanded(child: Text(n, style: theme.textTheme.labelMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
        if (meta?.year != null) Text('${meta!.year}', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label)),
      ]),
    );
  }
}
