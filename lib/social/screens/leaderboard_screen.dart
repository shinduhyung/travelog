import 'package:flutter/material.dart';

import '../models/social_profile.dart';
import '../models/stats.dart';
import '../services/social_store.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import 'compare/compare_screen.dart';
import '../widgets/avatar.dart';
import '../social_hub.dart';

class _Metric {
  const _Metric(this.emoji, this.label, this.value, {this.format});

  final String emoji;
  final String label;
  final num Function(SocialProfile p, ProfileStats s) value;
  final String Function(num v)? format;
}

final _metrics = <_Metric>[
  _Metric('🌍', 'Countries', (p, s) => p.countryCount),
  _Metric('🧭', 'Continents', (p, s) => s.continentCount),
  _Metric('🏙️', 'Cities', (p, s) => p.cityCount),
  _Metric('🗼', 'Landmarks', (p, s) => p.landmarkCount),
  _Metric('🏛️', 'UNESCO', (p, s) => p.unescoCount),
  _Metric('📐', 'Area covered', (p, s) => s.areaPercent * 100, format: (v) => '${v.toStringAsFixed(1)}%'),
  _Metric('✈️', 'Flights', (p, s) => p.flights.total),
  _Metric('📏', 'Distance flown', (p, s) => s.totalFlightKm, format: (v) => '${compactNumber(v.round())} km'),
  _Metric('🛬', 'Airports', (p, s) => p.airportCount),
  _Metric('🎖️', 'Badges', (p, s) => p.badgeCount),
  _Metric('🧠', 'Quiz correct', (p, s) => p.quizNormal.correct + p.quizExpert.correct),
  _Metric('🔥', 'Quiz streak', (p, s) => p.quizNormal.streak(DateTime.now()), format: (v) => v.toInt() == 1 ? '1 day' : '${v.toInt()} days'),
];

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _metric = 0;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final theme = Theme.of(context);
    final m = _metrics[_metric];
    final rows = [
      for (final p in store.everyone) (p, m.value(p, ProfileStats(p))),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final fmt = m.format ?? compactNumber;

    return Scaffold(
      appBar: AppBar(title: const Text('Friend Ranking')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (var i = 0; i < _metrics.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${_metrics[i].emoji} ${_metrics[i].label}'),
                      selected: _metric == i,
                      onSelected: (_) => setState(() => _metric = i),
                    ),
                  ),
              ],
            ),
          ),
          if (rows.length >= 2) _Podium(rows: rows.take(3).toList(), fmt: fmt, myUid: store.uid),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final (p, v) = rows[i];
                final isMe = p.uid == store.uid;
                final top = rows.first.$2 == 0 ? 1 : rows.first.$2;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isMe ? Color.alphaBlend(AppColors.me.withValues(alpha: 0.12), Colors.white) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                    leading: SizedBox(
                      width: 72,
                      child: Row(children: [
                        SizedBox(
                          width: 24,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('${i + 1}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          ),
                        ),
                        UserAvatar(profile: p, radius: 18),
                      ]),
                    ),
                    title: Text(isMe ? '${p.displayName} (You)' : p.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: v / top,
                          minHeight: 6,
                          color: isMe ? AppColors.me : AppColors.friend,
                          backgroundColor: AppColors.background,
                        ),
                      ),
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(fmt(v),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: AppColors.darkMint)),
                    ),
                    onTap: isMe
                        ? null
                        : () => Navigator.push(
                            context, socialRoute<void>((_) => CompareScreen(friendUid: p.uid))),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.rows, required this.fmt, required this.myUid});

  final List<(SocialProfile, num)> rows;
  final String Function(num) fmt;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget place(int i, double height, Color color, String medal) {
      if (i >= rows.length) return const Expanded(child: SizedBox.shrink());
      final (p, v) = rows[i];
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 110,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(medal, style: const TextStyle(fontSize: 26)),
            UserAvatar(profile: p, radius: i == 0 ? 28 : 22),
            const SizedBox(height: 4),
            Text(p.uid == myUid ? 'You' : p.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(fmt(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.label)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 230,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            place(1, 60, AppColors.silver, '🥈'),
            place(0, 90, AppColors.gold, '🥇'),
            place(2, 40, AppColors.bronze, '🥉'),
          ],
        ),
      ),
    );
  }
}
