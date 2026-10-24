import 'package:flutter/material.dart';

import '../../data/geo_data.dart';
import '../../models/social_profile.dart';
import '../../models/stats.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/charts.dart';
import '../../widgets/flag.dart';
import '../../widgets/world_map.dart';
import 'compare_screen.dart';

class FlightsTab extends StatelessWidget {
  const FlightsTab({super.key, required this.cmp});

  final Comparison cmp;

  @override
  Widget build(BuildContext context) {
    final geo = GeoData.I;
    final name = cmp.friend.displayName;
    final theme = Theme.of(context);
    final noData = cmp.me.flights.total == 0 && cmp.friend.flights.total == 0 && cmp.me.airports.isEmpty && cmp.friend.airports.isEmpty;
    if (noData) {
      return TabList(children: [
        EmptyHint(
          cmp.friend.privacy.flights
              ? 'No flight or airport records in Travelog yet.\nAdd your flights in the Flights tab.'
              : '$name keeps their flights private',
          emoji: '✈️',
        ),
      ]);
    }

    List<MapArc> arcs(SocialProfile p, Color color) => [
          for (final r in p.flights.routes.take(150))
            if (geo.airports[r.from] case final a?)
              if (geo.airports[r.to] case final b?)
                MapArc(a.lat, a.lng, b.lat, b.lng, color.withValues(alpha: 0.7), width: r.times > 1 ? 1.0 : 0.6),
        ];
    List<MapDot> airportDots(SocialProfile p, Color color) => [
          for (final iata in p.airports.keys)
            if (geo.airports[iata] case final a?) MapDot(a.lat, a.lng, color, radius: 1.6),
        ];

    return TabList(children: [
      SectionCard(
        emoji: '🛫',
        title: 'Flight map',
        tint: const Color(0xFF0EA5E9),
        subtitle: 'Up to 150 most-flown routes',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WorldMap(
            arcs: [...arcs(cmp.friend, AppColors.friend), ...arcs(cmp.me, AppColors.me)],
            dots: [...airportDots(cmp.friend, AppColors.friend), ...airportDots(cmp.me, AppColors.me)],
          ),
          const SizedBox(height: 10),
          VsLegend(friendName: name, showBoth: false),
        ]),
      ),
      SectionCard(
        emoji: '📏',
        title: 'Flight score',
        tint: const Color(0xFF0EA5E9),
        trailing: VsLegend(friendName: name, showBoth: false),
        child: Column(children: [
          VsBar(label: 'Flights', emoji: '✈️', mine: cmp.me.flights.total, theirs: cmp.friend.flights.total),
          VsBar(label: 'Distance', emoji: '📏', mine: cmp.mine.totalFlightKm.round(), theirs: cmp.theirs.totalFlightKm.round()),
          VsBar(label: 'Earth laps', emoji: '🌍', mine: cmp.mine.earthLaps, theirs: cmp.theirs.earthLaps, format: (v) => v.toStringAsFixed(2)),
          VsBar(label: 'Airports', emoji: '🛬', mine: cmp.me.airportCount, theirs: cmp.friend.airportCount),
          VsBar(label: 'Airlines', emoji: '🏷️', mine: cmp.me.flights.airlines.length, theirs: cmp.friend.flights.airlines.length),
          VsBar(label: 'Routes', emoji: '🧵', mine: cmp.me.flights.routes.length, theirs: cmp.friend.flights.routes.length),
        ]),
      ),
      SectionCard(
        emoji: '🥇',
        title: 'Records & favorites',
        tint: AppColors.gold,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _records(context, cmp.mine, AppColors.me, 'You')),
          const SizedBox(width: 10),
          Expanded(child: _records(context, cmp.theirs, AppColors.friend, name)),
        ]),
      ),
      SectionCard(
        emoji: '🏷️',
        title: 'Airlines flown',
        tint: const Color(0xFF0EA5E9),
        subtitle: '${cmp.airlines.both.length} airlines in common',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _airlineWrap(context, cmp.me.flights.airlines, 'You', AppColors.me),
          const SizedBox(height: 12),
          _airlineWrap(context, cmp.friend.flights.airlines, name, AppColors.friend),
        ]),
      ),
      if (cmp.airports.both.isNotEmpty)
        SectionCard(
          emoji: '🛬',
          title: 'Airports you both visited',
          tint: AppColors.both,
          subtitle: '${cmp.airports.both.length} airports',
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final iata in (cmp.airports.both.toList()
              ..sort((a, b) => ((cmp.me.airports[b] ?? 0) + (cmp.friend.airports[b] ?? 0))
                  .compareTo((cmp.me.airports[a] ?? 0) + (cmp.friend.airports[a] ?? 0)))).take(30))
              _airportChip(context, iata),
          ]),
        ),
      if (cmp.me.flights.seatClasses.isNotEmpty || cmp.friend.flights.seatClasses.isNotEmpty)
        SectionCard(
          emoji: '💺',
          title: 'Seat class',
          tint: AppColors.indigo,
          child: Column(children: [
            for (final cls in {...cmp.me.flights.seatClasses.keys, ...cmp.friend.flights.seatClasses.keys})
              VsBar(label: cls, mine: cmp.me.flights.seatClasses[cls] ?? 0, theirs: cmp.friend.flights.seatClasses[cls] ?? 0),
          ]),
        ),
      if (cmp.me.flights.aircraft.isNotEmpty || cmp.friend.flights.aircraft.isNotEmpty)
        SectionCard(
          emoji: '🛩️',
          title: 'Top aircraft',
          tint: AppColors.mint,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _topList(context, cmp.me.flights.aircraft, AppColors.me, 'You')),
            const SizedBox(width: 10),
            Expanded(child: _topList(context, cmp.friend.flights.aircraft, AppColors.friend, name)),
          ]),
        ),
      Text(
        'Distances are great-circle distances between airports.',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label),
      ),
    ]);
  }

  Widget _records(BuildContext context, ProfileStats s, Color color, String who) {
    final theme = Theme.of(context);
    final geo = GeoData.I;
    final longest = s.longestRoute;
    final airline = s.topAirline;
    final airport = s.topAirport;
    Widget item(String label, String value, String? sub) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(value,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (sub != null)
              Text(sub,
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(who,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        item('📏 Longest route', longest == null ? '-' : '${longest.from} → ${longest.to}',
            longest == null ? null : '${compactNumber(s.routeKm(longest).round())} km'),
        item('🏷️ Top airline', airline == null ? '-' : (geo.airlines[airline.key]?.name ?? airline.key),
            airline == null ? null : '${airline.value}×'),
        item('🛬 Top airport', airport == null ? '-' : airport.key,
            airport == null ? null : '${geo.airports[airport.key]?.city ?? ''} · ${airport.value}×'),
      ]),
    );
  }

  Widget _airlineWrap(BuildContext context, Map<String, int> airlines, String who, Color color) {
    final theme = Theme.of(context);
    final sorted = airlines.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(who,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      if (sorted.isEmpty)
        Text('No records', style: theme.textTheme.labelSmall)
      else
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in sorted.take(24))
            Builder(builder: (context) {
              final meta = GeoData.I.airlines[e.key];
              final brand = _hex(meta?.colorHex) ?? color;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(10)),
                child: Text('${meta?.name ?? e.key} ×${e.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: brand.computeLuminance() > 0.6 ? Colors.black87 : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              );
            }),
        ]),
    ]);
  }

  static Color? _hex(String? hex) {
    if (hex == null) return null;
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  Widget _airportChip(BuildContext context, String iata) {
    final meta = GeoData.I.airports[iata];
    return Chip(
      avatar: Flag(meta?.iso2, width: 20, radius: 2),
      label: Text('$iata ${meta?.city ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _topList(BuildContext context, Map<String, int> m, Color color, String who) {
    final theme = Theme.of(context);
    final sorted = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(who,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (sorted.isEmpty) Text('No records', style: theme.textTheme.labelSmall),
        for (final e in sorted.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: Text(e.key, style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${e.value}', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
    );
  }
}
