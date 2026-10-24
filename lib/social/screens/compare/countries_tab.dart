import 'package:flutter/material.dart';

import '../../data/geo_data.dart';
import '../../models/stats.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import '../../widgets/flag.dart';
import '../../widgets/world_map.dart';
import 'compare_screen.dart';

class CountriesTab extends StatefulWidget {
  const CountriesTab({super.key, required this.cmp});

  final Comparison cmp;

  @override
  State<CountriesTab> createState() => _CountriesTabState();
}

enum _Filter { both, mine, theirs, all }

/// VsBar의 좁은 라벨 칸용 대륙 이름
const _shortContinent = {
  'Asia': 'Asia',
  'Europe': 'Europe',
  'Africa': 'Africa',
  'North America': 'N. America',
  'South America': 'S. America',
  'Oceania': 'Oceania',
};

class _CountriesTabState extends State<CountriesTab> with AutomaticKeepAliveClientMixin {
  _Filter _filter = _Filter.both;
  String? _continent;

  @override
  bool get wantKeepAlive => true;

  Comparison get cmp => widget.cmp;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final name = cmp.friend.displayName;
    final short = shortName(name);
    final geo = GeoData.I;
    final c = cmp.countries;

    Color? colorFor(CountryMeta m) {
      if (c.both.contains(m.name)) return AppColors.both;
      if (c.onlyMine.contains(m.name)) return AppColors.me;
      if (c.onlyTheirs.contains(m.name)) return AppColors.friend;
      return null;
    }

    final selected = switch (_filter) {
      _Filter.both => c.both,
      _Filter.mine => c.onlyMine,
      _Filter.theirs => c.onlyTheirs,
      _Filter.all => c.union,
    };
    final shown = selected
        .where((n) => _continent == null || geo.countryByName(n)?.continent == _continent)
        .toList()
      ..sort((a, b) => (geo.countryByName(a)?.longName ?? a).compareTo(geo.countryByName(b)?.longName ?? b));

    const continents = ['Asia', 'Europe', 'Africa', 'North America', 'South America', 'Oceania'];

    return TabList(children: [
      SectionCard(
        emoji: '🗺️',
        tint: AppColors.mint,
        title: 'Shared world map',
        subtitle: 'Tap a country for details',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorldMap(
              colorFor: colorFor,
              onTapCountry: (m) => showCountrySheet(context, m, me: cmp.me, friend: cmp.friend),
            ),
            const SizedBox(height: 10),
            MapLegend(items: [
              (AppColors.both, 'Both ${c.both.length}'),
              (AppColors.me, 'Only you ${c.onlyMine.length}'),
              (AppColors.friend, '$short only ${c.onlyTheirs.length}'),
            ]),
            const SizedBox(height: 12),
            OverlapBar(onlyMine: c.onlyMine.length, both: c.both.length, onlyTheirs: c.onlyTheirs.length),
          ],
        ),
      ),
      SectionCard(
        emoji: '🏁',
        tint: AppColors.both,
        title: 'Flag collection',
        subtitle: shown.length == 1 ? '1 country' : '${shown.length} countries',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChipBar(children: [
              _chip('Both', _Filter.both, AppColors.both),
              _chip('You', _Filter.mine, AppColors.me),
              _chip(short, _Filter.theirs, AppColors.friend),
              _chip('All', _Filter.all, theme.colorScheme.primary),
            ]),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('All continents'),
                    selected: _continent == null,
                    onSelected: (_) => setState(() => _continent = null),
                  ),
                ),
                for (final ct in continents)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${continentEmoji[ct]} ${continentLabel(ct)}'),
                      selected: _continent == ct,
                      onSelected: (_) => setState(() => _continent = ct),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              const EmptyHint('No matching countries')
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n in shown)
                    CountryChip(
                      n,
                      color: colorFor(geo.countryByName(n) ?? CountryMeta(iso3: '', name: n)),
                      onTap: geo.countryByName(n) == null
                          ? null
                          : () => showCountrySheet(context, geo.countryByName(n)!, me: cmp.me, friend: cmp.friend),
                    ),
                ],
              ),
          ],
        ),
      ),
      SectionCard(
        emoji: '🧭',
        tint: AppColors.indigo,
        title: 'By continent',
        trailing: VsLegend(friendName: short, showBoth: false),
        child: Column(children: [
          for (final ct in continents)
            VsBar(
              label: '${_shortContinent[ct] ?? continentLabel(ct)}\n/${geo.continentTotals[ct] ?? 0}',
              emoji: continentEmoji[ct],
              mine: cmp.mine.continents[ct] ?? 0,
              theirs: cmp.theirs.continents[ct] ?? 0,
            ),
        ]),
      ),
      SectionCard(
        emoji: '📈',
        tint: AppColors.friend,
        title: 'Travel timeline',
        subtitle: 'Countries by first visit',
        trailing: VsLegend(friendName: short, showBoth: false),
        child: Column(
          children: [
            TimelineChart(mine: cmp.mine.cumulativeCountries(), theirs: cmp.theirs.cumulativeCountries()),
            if (cmp.mine.activeCountriesByYear.isNotEmpty || cmp.theirs.activeCountriesByYear.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Countries visited per year (last 10 years)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              YearBars(mine: cmp.mine.activeCountriesByYear, theirs: cmp.theirs.activeCountriesByYear),
            ],
          ],
        ),
      ),
      SectionCard(
        emoji: '📊',
        tint: AppColors.gold,
        title: 'World coverage',
        child: Column(children: [
          VsBar(label: 'Countries', emoji: '🌍', mine: cmp.mine.worldPercent * 100, theirs: cmp.theirs.worldPercent * 100, format: _pct),
          VsBar(label: 'Land area', emoji: '📐', mine: cmp.mine.areaPercent * 100, theirs: cmp.theirs.areaPercent * 100, format: _pct),
          VsBar(label: 'Population', emoji: '👥', mine: cmp.mine.populationPercent * 100, theirs: cmp.theirs.populationPercent * 100, format: _pct),
          VsBar(label: 'Lived', emoji: '🏠', mine: cmp.me.livedCountries.length, theirs: cmp.friend.livedCountries.length),
          VsBar(label: 'Wishlist', emoji: '💭', mine: cmp.me.countryWish.length, theirs: cmp.friend.countryWish.length),
          VsBar(label: 'Regions', emoji: '📍', mine: cmp.me.subregionCount, theirs: cmp.friend.subregionCount),
        ]),
      ),
      if (cmp.ratingGaps.isNotEmpty)
        SectionCard(
          emoji: '⭐',
          tint: AppColors.gold,
          title: 'Same country, different ratings',
          subtitle: 'Countries you both rated',
          child: Column(children: [
            for (final (n, a, b) in cmp.ratingGaps.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Flag.ofCountry(n, width: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      geo.countryByName(n)?.longName ?? n,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  _starPill(a, AppColors.me),
                  const SizedBox(width: 6),
                  _starPill(b, AppColors.friend),
                ]),
              ),
          ]),
        ),
      _MostVisited(cmp: cmp),
      if (cmp.recommendForMe.isNotEmpty)
        SectionCard(
          emoji: '🧳',
          tint: AppColors.friend,
          title: "$name's picks for you",
          subtitle: "$name has been, you haven't",
          child: Column(children: [
            for (final n in cmp.recommendForMe.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Flag.ofCountry(n, width: 36),
                title: Text(geo.countryByName(n)?.longName ?? n, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    if (cmp.me.countryWish.contains(n)) '💭 On your wishlist',
                    if ((cmp.friend.countryInfo[n]?.visits ?? 0) > 1) '${cmp.friend.countryInfo[n]!.visits} visits',
                    if (cmp.friend.countryInfo[n]?.firstYear != null) '${cmp.friend.countryInfo[n]!.firstYear}',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label),
                ),
                trailing: (cmp.friend.countryInfo[n]?.rating ?? 0) > 0 ? Stars(cmp.friend.countryInfo[n]!.rating) : null,
                onTap: geo.countryByName(n) == null
                    ? null
                    : () => showCountrySheet(context, geo.countryByName(n)!, me: cmp.me, friend: cmp.friend),
              ),
          ]),
        ),
      if (cmp.wishOverlap.isNotEmpty)
        SectionCard(
          emoji: '💭',
          tint: AppColors.gold,
          title: 'Shared wishlist',
          subtitle: 'Plan a trip together?',
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final n in cmp.wishOverlap) CountryChip(n, color: AppColors.gold),
          ]),
        ),
    ]);
  }

  static String _pct(num v) => '${v.toStringAsFixed(1)}%';

  Widget _chip(String label, _Filter f, Color color) => ChoiceChip(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: _filter == f,
        selectedColor: color.withValues(alpha: 0.25),
        onSelected: (_) => setState(() => _filter = f),
      );

  Widget _starPill(double r, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
        child: Text('★${r.toStringAsFixed(1)}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

class _MostVisited extends StatelessWidget {
  const _MostVisited({required this.cmp});

  final Comparison cmp;

  @override
  Widget build(BuildContext context) {
    final mine = cmp.mine.mostVisitedCountries.take(5).toList();
    final theirs = cmp.theirs.mostVisitedCountries.take(5).toList();
    final mineTop = cmp.mine.topRatedCountries.take(5).toList();
    final theirsTop = cmp.theirs.topRatedCountries.take(5).toList();
    if (mine.isEmpty && theirs.isEmpty && mineTop.isEmpty && theirsTop.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final name = cmp.friend.displayName;

    Widget column(String title, List<Widget> rows, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (rows.isEmpty)
                  Text('Nothing yet', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label))
                else
                  ...rows,
              ],
            ),
          ),
        );

    Widget row(String n, String trailing) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Flag.ofCountry(n, width: 20, radius: 2),
            const SizedBox(width: 6),
            Expanded(
              child: Text(GeoData.I.countryByName(n)?.longName ?? n,
                  style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            Text(trailing, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );

    return SectionCard(
      emoji: '❤️',
      tint: AppColors.both,
      title: 'Favorite countries',
      child: Column(children: [
        if (mineTop.isNotEmpty || theirsTop.isNotEmpty)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            column('Your top rated', [for (final e in mineTop) row(e.key, '★${e.value.rating.toStringAsFixed(1)}')], AppColors.me),
            const SizedBox(width: 10),
            column("$name's top rated",
                [for (final e in theirsTop) row(e.key, '★${e.value.rating.toStringAsFixed(1)}')], AppColors.friend),
          ]),
        if (mine.isNotEmpty || theirs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            column('Your most visited', [for (final e in mine) row(e.key, '${e.value.visits}x')], AppColors.me),
            const SizedBox(width: 10),
            column("$name's most visited", [for (final e in theirs) row(e.key, '${e.value.visits}x')], AppColors.friend),
          ]),
        ],
      ]),
    );
  }
}
