import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/geo_data.dart';
import '../../models/stats.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import '../../widgets/flag.dart';
import '../../widgets/world_map.dart';
import 'compare_screen.dart';

class CitiesTab extends StatefulWidget {
  const CitiesTab({super.key, required this.cmp});

  final Comparison cmp;

  @override
  State<CitiesTab> createState() => _CitiesTabState();
}

class _CitiesTabState extends State<CitiesTab> with AutomaticKeepAliveClientMixin {
  int _list = 0; // 0 둘 다, 1 나만, 2 친구만

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cmp = widget.cmp;
    final geo = GeoData.I;
    final theme = Theme.of(context);
    final name = cmp.friend.displayName;
    final short = shortName(name);
    final c = cmp.cities;

    if (!cmp.friend.privacy.cities && cmp.friend.cities.isEmpty) {
      return const TabList(children: [EmptyHint('Your friend keeps their cities private', emoji: '🔒')]);
    }

    // 지도 점: 너무 많으면 큰 도시 위주로
    List<MapDot> dots(Iterable<String> keys, Color color, double r) {
      final metas = keys.map((k) => geo.cities[k]).whereType<CityMeta>().toList()
        ..sort((a, b) => b.population.compareTo(a.population));
      return [for (final m in metas.take(600)) MapDot(m.lat, m.lng, color, radius: r)];
    }

    final allDots = [
      ...dots(c.onlyTheirs, AppColors.friend, 2.6),
      ...dots(c.onlyMine, AppColors.me, 2.6),
      ...dots(c.both, AppColors.both, 3.4),
    ];

    final keys = switch (_list) { 0 => c.both, 1 => c.onlyMine, _ => c.onlyTheirs };
    final listed = keys.map((k) => geo.cities[k] ?? CityMeta(key: k, lat: 0, lng: 0)).toList()
      ..sort((a, b) => b.population.compareTo(a.population));

    final myCountries = cmp.mine.citiesByCountry;
    final theirCountries = cmp.theirs.citiesByCountry;
    final topCountries = {...myCountries.keys, ...theirCountries.keys}.toList()
      ..sort((a, b) => math.max(theirCountries[b] ?? 0, myCountries[b] ?? 0)
          .compareTo(math.max(theirCountries[a] ?? 0, myCountries[a] ?? 0)));

    Widget segLabel(String text) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

    return TabList(children: [
      SectionCard(
        emoji: '📍',
        tint: AppColors.mint,
        title: 'City map',
        subtitle: 'Pinch to zoom in',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorldMap(dots: allDots),
            const SizedBox(height: 10),
            MapLegend(items: [
              (AppColors.both, 'Both ${c.both.length}'),
              (AppColors.me, 'Only you ${c.onlyMine.length}'),
              (AppColors.friend, '$short only ${c.onlyTheirs.length}'),
            ]),
            const SizedBox(height: 10),
            OverlapBar(onlyMine: c.onlyMine.length, both: c.both.length, onlyTheirs: c.onlyTheirs.length),
          ],
        ),
      ),
      SectionCard(
        emoji: '🏙️',
        tint: AppColors.indigo,
        title: 'City score',
        trailing: VsLegend(friendName: short, showBoth: false),
        child: Column(children: [
          VsBar(label: 'Cities', emoji: '🏙️', mine: cmp.me.cityCount, theirs: cmp.friend.cityCount),
          VsBar(label: 'Capitals', emoji: '🏛️', mine: cmp.mine.capitalCount, theirs: cmp.theirs.capitalCount),
          VsBar(label: 'Lived', emoji: '🏠',
              mine: cmp.me.cityInfo.values.where((i) => i.lived).length,
              theirs: cmp.friend.cityInfo.values.where((i) => i.lived).length),
          VsBar(label: 'Wishlist', emoji: '💭', mine: cmp.me.cityWish.length, theirs: cmp.friend.cityWish.length),
          VsBar(label: 'Per country', emoji: '📊',
              mine: cmp.me.countryCount == 0 ? 0 : cmp.me.cityCount / cmp.me.countryCount,
              theirs: cmp.friend.countryCount == 0 ? 0 : cmp.friend.cityCount / cmp.friend.countryCount,
              format: (v) => v.toStringAsFixed(1)),
        ]),
      ),
      SectionCard(
        emoji: '🏡',
        tint: AppColors.gold,
        title: 'Home & biggest city',
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _homeCard(context, cmp.me.homeCity, cmp.mine.biggestCity, AppColors.me, 'You')),
          const SizedBox(width: 10),
          Expanded(child: _homeCard(context, cmp.friend.homeCity, cmp.theirs.biggestCity, AppColors.friend, name)),
        ]),
      ),
      if (topCountries.isNotEmpty)
        SectionCard(
          emoji: '🗂️',
          tint: AppColors.friend,
          title: 'Most cities by country',
          child: Column(children: [
            for (final iso3 in topCountries.take(8))
              Builder(builder: (context) {
                final m = geo.countryByIso3(iso3);
                return Row(children: [
                  Flag(m?.iso2, width: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: VsBar(label: m?.longName ?? iso3, mine: myCountries[iso3] ?? 0, theirs: theirCountries[iso3] ?? 0),
                  ),
                ]);
              }),
          ]),
        ),
      SectionCard(
        emoji: '🧾',
        tint: AppColors.both,
        title: 'City list',
        subtitle: 'By population · ${listed.length} ${listed.length == 1 ? 'city' : 'cities'}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: segLabel('Both ${c.both.length}')),
                  ButtonSegment(value: 1, label: segLabel('You ${c.onlyMine.length}')),
                  ButtonSegment(value: 2, label: segLabel('Friend ${c.onlyTheirs.length}')),
                ],
                selected: {_list},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _list = s.first),
              ),
            ),
            const SizedBox(height: 10),
            if (listed.isEmpty)
              const EmptyHint('No matching cities')
            else
              for (final m in listed.take(40))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Flag(m.iso2, width: 24, radius: 3),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(m.displayName + (m.isCapital ? ' 🏛️' : ''),
                          style: theme.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (m.population > 0) ...[
                      const SizedBox(width: 6),
                      Text(compactNumber(m.population),
                          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label)),
                    ],
                    _ratingFor(m.key),
                  ]),
                ),
            if (listed.length > 40)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('+${listed.length - 40} more',
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label)),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _ratingFor(String key) {
    final cmp = widget.cmp;
    final a = cmp.me.cityInfo[key]?.rating ?? 0;
    final b = cmp.friend.cityInfo[key]?.rating ?? 0;
    if (a == 0 && b == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (a > 0) Text('★${a.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.me, fontWeight: FontWeight.w800, fontSize: 12)),
        if (a > 0 && b > 0) const SizedBox(width: 4),
        if (b > 0) Text('★${b.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.friend, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }

  Widget _homeCard(BuildContext context, String? home, CityMeta? biggest, Color color, String who) {
    final theme = Theme.of(context);
    final geo = GeoData.I;
    final homeMeta = home == null ? null : geo.cities[home];
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600);
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
          const SizedBox(height: 8),
          Text('🏡 Home', style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(children: [
            if (homeMeta != null) ...[Flag(homeMeta.iso2, width: 18, radius: 2), const SizedBox(width: 4)],
            Expanded(
              child: Text(home == null ? 'Not set' : displayCityName(home),
                  style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 8),
          Text('🌆 Biggest city', style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(children: [
            if (biggest != null) ...[Flag(biggest.iso2, width: 18, radius: 2), const SizedBox(width: 4)],
            Expanded(
              child: Text(biggest?.displayName ?? '-',
                  style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
          if (biggest != null)
            Text('Pop. ${compactNumber(biggest.population)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label)),
        ],
      ),
    );
  }
}
