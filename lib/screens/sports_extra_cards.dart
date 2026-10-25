// lib/screens/sports_extra_cards.dart
// Sports statistics cards backed by the sports_* datasets (tool/sports_stats).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/country_model.dart';
import 'package:jidoapp/models/statistics_dataset.dart';
import 'package:jidoapp/screens/sports_stats_screen.dart'
    show flagEmoji, navigateToCountryDetail;
import 'package:jidoapp/services/statistics_repository.dart';

class SportsRankRow {
  final String label;
  final String? subtitle;
  final String? isoA3;
  final num value;
  final String valueText;
  final int? rank;

  const SportsRankRow({
    required this.label,
    required this.isoA3,
    required this.value,
    required this.valueText,
    this.subtitle,
    this.rank,
  });
}

class SportsRankTab {
  final String label;
  final List<SportsRankRow> Function(
    StatisticsDataset? data,
    Map<String, Country> byIso,
  )
  build;

  const SportsRankTab(this.label, this.build);
}

Map<String, Country> _byIso(List<Country> countries) => {
  for (final c in countries) c.isoA3: c,
};

String _fmt(num v) {
  if (v is int || v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(v.abs() < 10 ? 2 : 1);
}

/// Ranking list with optional tabs, backed by one dataset (or none for derived data).
class SportsRankingCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? assetPath;
  final List<SportsRankTab> tabs;
  final String? footnote;
  final List<Country> countries;
  final Set<String> visitedCountryNames;

  const SportsRankingCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.tabs,
    required this.countries,
    required this.visitedCountryNames,
    this.assetPath,
    this.footnote,
  });

  @override
  State<SportsRankingCard> createState() => _SportsRankingCardState();
}

class _SportsRankingCardState extends State<SportsRankingCard> {
  int _tab = 0;
  bool _visitedOnly = false;
  late final Future<StatisticsDataset?> _data = widget.assetPath == null
      ? Future.value(null)
      : StatisticsRepository.instance.load(widget.assetPath!);

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SportsCardHeader(
            title: widget.title,
            icon: widget.icon,
            color: widget.color,
            children: [
              Row(
                children: [
                  if (widget.tabs.length > 1)
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          borderRadius: BorderRadius.circular(16),
                          value: _tab,
                          isExpanded: true,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: widget.color,
                          ),
                          items: [
                            for (var i = 0; i < widget.tabs.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  tr(widget.tabs[i].label),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _tab = v ?? 0),
                        ),
                      ),
                    ),
                  if (widget.tabs.length > 1) const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<bool>(
                        borderRadius: BorderRadius.circular(16),
                        value: _visitedOnly,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: widget.color),
                        items: [
                          DropdownMenuItem(
                            value: false,
                            child: Text(tr('All Countries')),
                          ),
                          DropdownMenuItem(
                            value: true,
                            child: Text(tr('Visited Only')),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _visitedOnly = v ?? false),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<StatisticsDataset?>(
              future: _data,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text(tr('No data to display.')));
                }
                final byIso = _byIso(widget.countries);
                var rows = widget.tabs[_tab].build(snap.data, byIso);
                if (_visitedOnly) {
                  rows = rows.where((r) {
                    final c = byIso[r.isoA3];
                    return c != null &&
                        widget.visitedCountryNames.contains(c.name);
                  }).toList();
                }
                if (rows.isEmpty) {
                  return Center(child: Text(tr('No data to display.')));
                }
                final maxValue = rows.map((r) => r.value).reduce(math.max);
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: rows.length + (widget.footnote == null ? 0 : 1),
                  itemBuilder: (context, i) {
                    if (i == rows.length) {
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          tr(widget.footnote!),
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    }
                    final r = rows[i];
                    final country = byIso[r.isoA3];
                    final visited =
                        country != null &&
                        widget.visitedCountryNames.contains(country.name);
                    return _RankTile(
                      row: r,
                      rank: r.rank ?? i + 1,
                      color: widget.color,
                      visited: visited,
                      progress: maxValue <= 0 ? 0 : r.value / maxValue,
                      flag: country == null ? '' : flagEmoji(country.isoA2),
                      onTap: country == null
                          ? null
                          : () => navigateToCountryDetail(context, country),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SportsCardHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SportsCardHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: color.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(title),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final SportsRankRow row;
  final int rank;
  final Color color;
  final bool visited;
  final double progress;
  final String flag;
  final VoidCallback? onTap;

  const _RankTile({
    required this.row,
    required this.rank,
    required this.color,
    required this.visited,
    required this.progress,
    required this.flag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: visited ? color.withOpacity(0.12) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Text(flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(row.label),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        if (row.subtitle != null)
                          Text(
                            row.subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    row.valueText,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                borderRadius: BorderRadius.circular(5),
                minHeight: 5,
                backgroundColor: Colors.grey.shade200,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row builders
// ---------------------------------------------------------------------------

/// Rows labelled with the country name; dataset rows without a loaded country are dropped.
List<SportsRankRow> _countryRows(
  StatisticsDataset? data,
  Map<String, Country> byIso,
  String metric, {
  String table = 'main',
  String Function(num)? text,
}) {
  final rows = <SportsRankRow>[];
  for (final r in data!.table(table).records) {
    final iso = r.dimensions['iso_a3'] as String?;
    final c = byIso[iso];
    final v = r.number(metric);
    if (c == null || v == null) continue;
    rows.add(
      SportsRankRow(
        label: c.name,
        isoA3: iso,
        value: v,
        valueText: text?.call(v) ?? _fmt(v),
      ),
    );
  }
  rows.sort((a, b) => b.value.compareTo(a.value));
  return rows;
}

List<SportsRankRow> _fifaRows(
  StatisticsDataset? data,
  Map<String, Country> byIso,
  String table,
) {
  final rows = <SportsRankRow>[];
  for (final r in data!.table(table).records) {
    final rank = r.number('rank')?.toInt();
    final points = r.number('points');
    if (rank == null || points == null) continue;
    rows.add(
      SportsRankRow(
        label: (r.dimensions['name'] ?? '') as String,
        isoA3: r.dimensions['iso_a3'] as String?,
        value: points,
        valueText: points.toStringAsFixed(1),
        rank: rank,
      ),
    );
  }
  return rows;
}

List<SportsRankRow> _ucl(
  StatisticsDataset? data,
  Map<String, Country> byIso,
  bool city,
) {
  final rows = <SportsRankRow>[];
  for (final r in data!.table(city ? 'city' : 'country').records) {
    final iso = r.dimensions['iso_a3'] as String?;
    final titles = r.number('titles');
    if (titles == null) continue;
    final label = city
        ? (r.dimensions['city'] ?? '') as String
        : (byIso[iso]?.name);
    if (label == null) continue;
    rows.add(
      SportsRankRow(
        label: label,
        isoA3: iso,
        value: titles,
        valueText: _fmt(titles),
        subtitle: city ? r.values['clubs'] as String? : null,
      ),
    );
  }
  rows.sort((a, b) => b.value.compareTo(a.value));
  return rows;
}

/// Olympic medals relative to population, derived from the loaded country data.
List<SportsRankRow> _olympicPerCapita(
  Map<String, Country> byIso, {
  required bool gold,
}) {
  final rows = <SportsRankRow>[];
  for (final c in byIso.values) {
    final medals = gold
        ? (c.summerGold ?? 0) + (c.winterGold ?? 0)
        : (c.summerTotal ?? 0) + (c.winterTotal ?? 0);
    final millions = c.populationEst / 1e6;
    if (medals <= 0 || millions < 1) continue;
    final v = medals / millions;
    rows.add(
      SportsRankRow(
        label: c.name,
        isoA3: c.isoA3,
        value: v,
        valueText: v.toStringAsFixed(1),
        subtitle: '${_fmt(medals)} / ${millions.toStringAsFixed(1)}M',
      ),
    );
  }
  rows.sort((a, b) => b.value.compareTo(a.value));
  return rows;
}

// ---------------------------------------------------------------------------
// Public cards
// ---------------------------------------------------------------------------

class SportsExtraCards extends StatelessWidget {
  final List<Country> countries;
  final Set<String> visitedCountryNames;

  const SportsExtraCards({
    super.key,
    required this.countries,
    required this.visitedCountryNames,
  });

  Widget _boxed(Widget child, {double height = 600}) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: SizedBox(height: height, child: child),
  );

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Column(
      children: [
        _boxed(
          SportsRankingCard(
            title: 'Olympic Medals per Capita',
            icon: Icons.groups,
            color: Colors.teal,
            countries: countries,
            visitedCountryNames: visitedCountryNames,
            footnote:
                'Medals per million people, all-time Summer + Winter. Countries under 1 million people are excluded.',
            tabs: [
              SportsRankTab(
                'Total Medals',
                (_, byIso) => _olympicPerCapita(byIso, gold: false),
              ),
              SportsRankTab(
                'Gold Medals',
                (_, byIso) => _olympicPerCapita(byIso, gold: true),
              ),
            ],
          ),
        ),
        _boxed(
          SportsRankingCard(
            title: 'FIFA World Ranking',
            icon: Icons.sports_soccer,
            color: Colors.green.shade700,
            assetPath: 'assets/sports_fifa_ranking.json',
            countries: countries,
            visitedCountryNames: visitedCountryNames,
            footnote:
                'FIFA/Coca-Cola ranking points. Men: 7 Oct 2026. Women: 15 Jun 2026.',
            tabs: [
              SportsRankTab('Men', (d, i) => _fifaRows(d, i, 'men')),
              SportsRankTab('Women', (d, i) => _fifaRows(d, i, 'women')),
            ],
          ),
        ),
        _boxed(
          SportsRankingCard(
            title: 'UEFA Champions League Titles',
            icon: Icons.emoji_events,
            color: Colors.indigo,
            assetPath: 'assets/sports_ucl_titles.json',
            countries: countries,
            visitedCountryNames: visitedCountryNames,
            footnote:
                'European Cup and Champions League titles through 2026. England and Scotland are counted as the United Kingdom.',
            tabs: [
              SportsRankTab('By Country', (d, i) => _ucl(d, i, false)),
              SportsRankTab('By City', (d, i) => _ucl(d, i, true)),
            ],
          ),
        ),
        _boxed(
          SportsRankingCard(
            title: 'Grand Slam Singles Titles (Men)',
            icon: Icons.sports_tennis,
            color: Colors.lime.shade800,
            assetPath: 'assets/sports_tennis_slam_men.json',
            countries: countries,
            visitedCountryNames: visitedCountryNames,
            footnote:
                'All-time titles by player nationality, through the 2026 US Open.',
            tabs: [
              SportsRankTab(
                'Titles',
                (d, i) => _countryRows(d, i, 'titles'),
              ),
            ],
          ),
        ),
        _boxed(
          SportsRankingCard(
            title: 'Chess Grandmasters',
            icon: Icons.grid_on,
            color: Colors.blueGrey.shade700,
            assetPath: 'assets/sports_fide_grandmasters.json',
            countries: countries,
            visitedCountryNames: visitedCountryNames,
            footnote:
                'Grandmasters by FIDE federation. England, Scotland and Wales are counted as the United Kingdom.',
            tabs: [
              SportsRankTab(
                'Grandmasters',
                (d, i) => _countryRows(d, i, 'grandmasters'),
              ),
            ],
          ),
        ),
        _boxed(
          SportsRankingCard(
            title: 'MLB Players Born Abroad',
            icon: Icons.sports_baseball,
            color: Colors.red.shade700,
            assetPath: 'assets/sports_mlb_international_players.json',
            countries: countries,
            visitedCountryNames: visitedCountryNames,
            footnote:
                '2026 Opening Day rosters and inactive lists. Players born in the United States are not shown.',
            tabs: [
              SportsRankTab('Players', (d, i) => _countryRows(d, i, 'players')),
            ],
          ),
        ),
        _boxed(
          WorldCupResultsCard(
            countries: countries,
            visitedCountryNames: visitedCountryNames,
          ),
          height: 640,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Classification: best World Cup result per country
// ---------------------------------------------------------------------------

const _wcCategories = <String>[
  'Champions',
  'Runners-up',
  'Third place',
  'Fourth place',
  'Quarter-finals',
  'Round of 16',
  'Round of 32',
  'Group stage',
];

class WorldCupResultsCard extends StatefulWidget {
  final List<Country> countries;
  final Set<String> visitedCountryNames;

  const WorldCupResultsCard({
    super.key,
    required this.countries,
    required this.visitedCountryNames,
  });

  @override
  State<WorldCupResultsCard> createState() => _WorldCupResultsCardState();
}

class _WorldCupResultsCardState extends State<WorldCupResultsCard> {
  static const _color = Color(0xFFB8860B);
  late final Future<StatisticsDataset> _data = StatisticsRepository.instance
      .load('assets/sports_world_cup_results.json');
  bool _visitedOnly = false;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final textTheme = Theme.of(context).textTheme;
    final byIso = _byIso(widget.countries);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SportsCardHeader(
            title: 'Best World Cup Result',
            icon: Icons.public,
            color: _color,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<bool>(
                  borderRadius: BorderRadius.circular(16),
                  value: _visitedOnly,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: _color),
                  items: [
                    DropdownMenuItem(
                      value: false,
                      child: Text(tr('All Countries')),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text(tr('Visited Only')),
                    ),
                  ],
                  onChanged: (v) => setState(() => _visitedOnly = v ?? false),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<StatisticsDataset>(
              future: _data,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError || snap.data == null) {
                  return Center(child: Text(tr('No data to display.')));
                }
                final groups = {for (final c in _wcCategories) c: <Country>[]};
                var qualified = 0;
                for (final r in snap.data!.table().records) {
                  final c = byIso[r.dimensions['iso_a3']];
                  final cat = r.values['best_result'];
                  if (c == null || !groups.containsKey(cat)) continue;
                  qualified++;
                  if (_visitedOnly &&
                      !widget.visitedCountryNames.contains(c.name)) {
                    continue;
                  }
                  groups[cat]!.add(c);
                }
                final neverCount = widget.countries
                    .where((c) => !c.isTerritory)
                    .length - qualified;
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final cat in _wcCategories)
                      if (groups[cat]!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            '${tr(cat)} (${groups[cat]!.length})',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _color,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in groups[cat]!)
                              ActionChip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor:
                                    widget.visitedCountryNames.contains(c.name)
                                    ? _color.withOpacity(0.2)
                                    : null,
                                label: Text('${flagEmoji(c.isoA2)} ${tr(c.name)}'),
                                onPressed: () =>
                                    navigateToCountryDetail(context, c),
                              ),
                          ],
                        ),
                      ],
                    if (!_visitedOnly && neverCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          '${tr('Never qualified')}: $neverCount',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        tr(
                          'Through the 2026 FIFA World Cup. Germany includes West Germany, Russia includes the Soviet Union, and the United Kingdom is shown by its best team.',
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
