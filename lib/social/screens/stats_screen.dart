import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/providers/badge_provider.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/stat_lock_guard.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

import '../models/global_stats.dart';
import '../models/stats.dart' show rankAsset;
import '../models/social_profile.dart';
import '../services/badge_stats.dart';
import '../services/country_rarity.dart';
import '../services/global_stats_service.dart';
import '../services/my_stat_values.dart';
import '../data/geo_data.dart';
import '../services/social_store.dart';
import '../social_hub.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cards.dart';
import '../widgets/flag.dart';

/// 메인 화면 Social 메뉴의 Stats:
///  1) My Stats: 내 기록을 전체 유저와 비교 (상위 %, 평균, 중앙값, 희귀도 점수)
///  2) Rankings: 유저 기반/일반 통계 Top 10 카드
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Stats')),
          bottom: TabBar(tabs: [Tab(text: tr('My Stats')), Tab(text: tr('Friends')), Tab(text: tr('Rankings'))]),
        ),
        body: const TabBarView(children: [_MyStatsTab(), _FriendsTab(), _RankingsTab()]),
      ),
    );
  }
}

// ── My Stats ────────────────────────────────────────────────────────────

class _RarityPack {
  const _RarityPack({this.me, this.friends = const [], this.meBadge, this.friendBadges = const [], this.rankShares = const []});

  final RarityResult? me;
  final List<RarityResult?> friends;
  final BadgeResult? meBadge;
  final List<BadgeResult?> friendBadges;
  final List<(String, double)> rankShares;
}

class _MyStatsTab extends StatefulWidget {
  const _MyStatsTab({this.profile});

  /// null이면 내 통계, 아니면 그 친구의 통계
  final SocialProfile? profile;

  @override
  State<_MyStatsTab> createState() => _MyStatsTabState();
}

class _MyStatsTabState extends State<_MyStatsTab> with AutomaticKeepAliveClientMixin {
  final Future<GlobalStats?> _global = GlobalStatsService.instance.load();
  Future<MyStatValues>? _mine;
  String? _mineUid;
  DateTime? _mineUpdated;
  Future<List<MyStatValues>>? _friends;
  String? _friendsSig;
  Future<_RarityPack>? _rarity;
  String? _raritySig;
  Future<List<Object?>>? _combined;
  Future<MyStatValues>? _combinedMine;
  Future<GlobalStats?>? _combinedGlobal;
  Future<List<MyStatValues>>? _combinedFriends;
  Future<_RarityPack>? _combinedRarity;

  @override
  bool get wantKeepAlive => true;

  Future<MyStatValues> _valuesFor(SocialProfile p) {
    // 프로필이 갱신될 때만 다시 센다
    if (_mine == null || _mineUid != p.uid || _mineUpdated != p.updatedAt) {
      _mineUid = p.uid;
      _mineUpdated = p.updatedAt;
      _mine = MyStatValues.compute(p);
    }
    return _mine!;
  }

  Future<List<MyStatValues>> _friendValues(List<SocialProfile> friends) {
    final sig = friends.map((f) => '${f.uid}@${f.updatedAt?.millisecondsSinceEpoch}').join(',');
    if (_friends == null || _friendsSig != sig) {
      _friendsSig = sig;
      _friends = Future.wait([for (final f in friends) MyStatValues.compute(f)]);
    }
    return _friends!;
  }

  Future<_RarityPack> _rarityFor(SocialProfile me, List<SocialProfile> friends) {
    final sig = '${me.uid}@${me.updatedAt?.millisecondsSinceEpoch}|${friends.map((f) => '${f.uid}@${f.updatedAt?.millisecondsSinceEpoch}').join(',')}';
    if (_rarity == null || _raritySig != sig) {
      _raritySig = sig;
      // 배지 점수는 앱의 배지 목록(id -> 점수)으로 해제한 배지를 합산한다
      final points = {for (final a in context.read<BadgeProvider>().achievements) a.id: a.points};
      final premium = SubscriptionService.instance.isPremium;
      _rarity = Future.wait<Object?>([CountryRarity.load(), BadgeStats.load()]).then((r) {
        final rarity = r[0] as CountryRarity?;
        final badges = r[1] as BadgeStats?;
        int pointsOf(SocialProfile p) => p.badgeIds.fold(0, (sum, id) => sum + (points[id] ?? 0));
        return _RarityPack(
          me: rarity?.score(me.countries),
          friends: [for (final f in friends) rarity?.score(f.countries)],
          // 내 통계는 내 구독 여부에 맞는 분포, 친구는 프리미엄 포함 분포와 비교
          meBadge: badges?.score(pointsOf(me), premium: widget.profile == null ? premium : true),
          friendBadges: [for (final f in friends) badges?.score(pointsOf(f), premium: true)],
          rankShares: badges?.rankShares(premium: widget.profile == null ? premium : true) ?? const [],
        );
      });
    }
    return _rarity!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = SocialScope.of(context);
    final me = widget.profile ?? store.me;
    if (me == null) {
      return Center(child: store.meLoaded ? EmptyHint(tr('No travel record yet. Sync your trips first.')) : const CircularProgressIndicator());
    }
    final others = widget.profile == null ? store.friends : const <SocialProfile>[];
    final mineFuture = _valuesFor(me);
    final friendsFuture = _friendValues(others);
    final rarityFuture = _rarityFor(me, others);
    if (!identical(_combinedMine, mineFuture) ||
        !identical(_combinedGlobal, _global) ||
        !identical(_combinedFriends, friendsFuture) ||
        !identical(_combinedRarity, rarityFuture)) {
      _combinedMine = mineFuture;
      _combinedGlobal = _global;
      _combinedFriends = friendsFuture;
      _combinedRarity = rarityFuture;
      _combined = Future.wait<Object?>([mineFuture, _global, friendsFuture, rarityFuture]);
    }
    return FutureBuilder<List<Object?>>(
      future: _combined,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final mine = snap.data?[0] as MyStatValues?;
        final global = snap.data?[1] as GlobalStats?;
        final friends = (snap.data?[2] as List<MyStatValues>?) ?? const <MyStatValues>[];
        final rarity = (snap.data?[3] as _RarityPack?) ?? const _RarityPack();
        if (mine == null) return Center(child: EmptyHint(tr('Could not read your stats.')));
        final compare = global != null && global.hasDistributions;
        return ListenableBuilder(
          listenable: SubscriptionService.instance,
          builder: (context, _) {
        final ctx = _StatsContext(mine: mine, global: global, friends: friends, rarity: rarity, locked: !SubscriptionService.instance.isPremium);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (!compare)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Notice(global == null ? tr('Could not load community stats.') : tr('No community stats available yet.')),
              ),
            _CountriesHero(ctx: ctx),
            const SizedBox(height: 12),
            _TileRow(children: [
              _StatTile(ctx: ctx, metric: StatMetric.gawcCities, title: tr('Cities'), note: tr('of 189')),
              _StatTile(ctx: ctx, metric: StatMetric.top250Landmarks, title: tr('Landmarks'), note: tr('of 250')),
            ]),
            const SizedBox(height: 12),
            _TileRow(children: [
              _StatTile(ctx: ctx, metric: StatMetric.unesco, title: tr('UNESCO')),
              _BadgeTile(ctx: ctx),
            ]),
            _SectionLabel(tr('By continent')),
            _GroupCard(ctx: ctx, metrics: StatMetric.byContinent.values.toList(), titles: [for (final k in StatMetric.byContinent.keys) tr(k.replaceAll('North America', 'N. America').replaceAll('South America', 'S. America'))]),
            _SectionLabel(tr('Aviation')),
            _GroupCard(ctx: ctx, metrics: const [StatMetric.airports, StatMetric.airlines, StatMetric.flights], titles: [tr('Airports'), tr('Airlines'), tr('Flights')]),
          ],
        );
          },
        );
      },
    );
  }
}

/// 한 화면이 공유하는 값: 내 기록, 전체 유저 분포, 친구들 기록, 희귀도.
class _StatsContext {
  const _StatsContext({required this.mine, required this.global, required this.friends, required this.rarity, this.locked = false});

  /// 비구독자는 국가 외의 통계 수치를 ?로 가린다
  final bool locked;
  final MyStatValues mine;
  final GlobalStats? global;
  final List<MyStatValues> friends;
  final _RarityPack rarity;

  MetricDistribution? dist(StatMetric m) {
    final d = global?.of(m);
    return d == null || d.isEmpty ? null : d;
  }

  double? top(StatMetric m) => dist(m)?.topPercent(mine.valueOf(m));

  /// 친구들 사이 내 순위 (친구가 없으면 null)
  ({int rank, int of})? friendRank(StatMetric m) {
    if (friends.isEmpty) return null;
    final v = mine.valueOf(m);
    return (rank: 1 + friends.where((f) => f.valueOf(m) > v).length, of: friends.length + 1);
  }

  ({int rank, int of})? badgeFriendRank() {
    final me = rarity.meBadge;
    if (me == null || me.points <= 0 || rarity.friendBadges.isEmpty) return null;
    final others = rarity.friendBadges.whereType<BadgeResult>();
    return (rank: 1 + others.where((f) => f.points > me.points).length, of: rarity.friendBadges.length + 1);
  }

  ({int rank, int of})? rarityFriendRank() {
    final me = rarity.me;
    if (me == null || rarity.friends.isEmpty) return null;
    final others = rarity.friends.whereType<RarityResult>();
    return (rank: 1 + others.where((f) => f.score > me.score).length, of: rarity.friends.length + 1);
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.darkMint),
        const SizedBox(width: 8),
        Expanded(child: Text(tr(text), style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}

/// 두 카드를 같은 높이로 나란히
class _TileRow extends StatelessWidget {
  const _TileRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// 맨 위 큰 카드: 방문한 나라 기준 전 세계 상위 %
class _CountriesHero extends StatelessWidget {
  const _CountriesHero({required this.ctx});

  final _StatsContext ctx;

  @override
  Widget build(BuildContext context) {
    const m = StatMetric.countriesTotal;
    final value = ctx.mine.valueOf(m);
    final dist = ctx.dist(m);
    final top = ctx.top(m);
    final fr = ctx.friendRank(m);
    final rarity = ctx.rarity.me;
    final ahead = top == null ? null : (100 - top).clamp(0.0, 100.0).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFEEF2), Color(0xFFF1EDFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr('COUNTRIES'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: Color(0xFF6B7280))),
              ),
              if (fr != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.group_rounded, size: 14, color: fr.rank == 1 ? AppColors.gold : AppColors.friend),
                    const SizedBox(width: 4),
                    Text(fr.rank == 1 ? tr('Friends #1') : tr('Friends #${fr.rank}/${fr.of}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: top != null
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(tr('Top'), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('${_pct(top)}%', style: const TextStyle(fontSize: 68, height: 1.0, fontWeight: FontWeight.w900, color: AppColors.darkMint, letterSpacing: -2)),
                            ),
                          ),
                        ],
                      )
                    : Text('$value', style: const TextStyle(fontSize: 68, height: 1.0, fontWeight: FontWeight.w900, color: AppColors.darkMint, letterSpacing: -2)),
              ),
              if (rarity != null) ...[const SizedBox(width: 8), _RarityPill(result: rarity)],
            ],
          ),
          const SizedBox(height: 6),
          Text(ahead == null ? tr('countries visited') : tr('Ahead of ${_pct(ahead)}% of travelers'),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          if (ahead != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 8, color: Colors.white.withValues(alpha: 0.9)),
                  FractionallySizedBox(
                    widthFactor: (ahead / 100).clamp(0.0, 1.0),
                    child: Container(height: 8, decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.mint, Color(0xFFFDBA74)]))),
                  ),
                ],
              ),
            ),
          ],
          if (dist != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  _HeroFigure('YOU', '$value'),
                  _HeroDivider(),
                  _HeroFigure('AVG', _fmt(dist.mean)),
                  _HeroDivider(),
                  _HeroFigure('MEDIAN', _fmt(dist.median)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 18, height: 1.1, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(tr(label), maxLines: 1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.label)),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 24, color: Colors.black.withValues(alpha: 0.08));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(tr(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          const _Legend(),
        ],
      ),
    );
  }
}

/// 막대 눈금 범례: 내 값 / 전체 평균 / 중앙값
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(tr(t), style: const TextStyle(fontSize: 10, color: AppColors.label, fontWeight: FontWeight.w600)),
        ]);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      item(AppColors.mint, 'You'),
      const SizedBox(width: 8),
      item(AppColors.indigo, 'Avg'),
      const SizedBox(width: 8),
      item(AppColors.friend, 'Median'),
    ]);
  }
}

String _fmt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

String _pct(double v) => v < 10 ? v.toStringAsFixed(1) : v.round().toString();

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppColors.cardShadow,
    );

class _IconDot extends StatelessWidget {
  const _IconDot(this.emoji);

  final String emoji;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Text(emoji, style: const TextStyle(fontSize: 17)),
      );
}

/// 카드 하단의 친구 순위
class _Footer extends StatelessWidget {
  const _Footer({this.friend});

  final ({int rank, int of})? friend;

  @override
  Widget build(BuildContext context) {
    if (friend == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.group_rounded, size: 14, color: friend!.rank == 1 ? AppColors.gold : AppColors.friend),
        const SizedBox(width: 3),
        Flexible(
          child: Text(friend!.rank == 1 ? tr('Friends #1') : tr('Friends #${friend!.rank}/${friend!.of}'),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ),
      ]),
    );
  }
}

void _promptSubscribe(BuildContext context) => SubscriptionSheet.show(context, triggerContext: 'stats_locked');

/// "Top 2.9%" 큰 글씨 (값이 없으면 개수를 보여준다)
class _BigPercent extends StatelessWidget {
  const _BigPercent({required this.top, required this.fallback, this.locked = false});

  final double? top;
  final String fallback;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(tr('Top'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.label)),
          const SizedBox(width: 4),
          const Text('?%', style: TextStyle(fontSize: 32, height: 1.0, fontWeight: FontWeight.w900, color: AppColors.label)),
        ],
      );
    }
    if (top == null) {
      return Text(fallback, style: const TextStyle(fontSize: 32, height: 1.0, fontWeight: FontWeight.w900, color: AppColors.label));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(tr('Top'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.label)),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('${_pct(top!)}%', style: const TextStyle(fontSize: 32, height: 1.0, fontWeight: FontWeight.w900, color: AppColors.darkMint)),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.ctx, required this.metric, required this.title, this.note});

  final _StatsContext ctx;
  final StatMetric metric;
  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final value = ctx.mine.valueOf(metric);
    final dist = ctx.locked ? null : ctx.dist(metric);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ctx.locked ? () => _promptSubscribe(context) : null,
      child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconDot(metric.emoji),
              const SizedBox(width: 8),
              Expanded(child: Text(tr(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 12),
          _BigPercent(top: ctx.top(metric), fallback: '$value', locked: ctx.locked),
          const SizedBox(height: 3),
          if (ctx.locked)
            Row(children: [
              const Icon(Icons.lock_rounded, size: 13, color: AppColors.darkMint),
              const SizedBox(width: 4),
              Expanded(child: Text(tr('Premium'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.darkMint, fontWeight: FontWeight.w700))),
            ])
          else
            Text(note == null ? '$value' : '$value ${tr(note!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.label, fontWeight: FontWeight.w600)),
          if (dist != null) ...[
            const SizedBox(height: 12),
            _PositionBar(value: value, dist: dist),
            const SizedBox(height: 8),
            _AvgMedian(dist: dist),
          ],
          const Spacer(),
          if (!ctx.locked) _Footer(friend: value > 0 ? ctx.friendRank(metric) : null),
        ],
      ),
    ),
    );
  }
}

/// "Avg 12 · Median 8" 한 줄 (좁으면 글자가 줄어든다)
class _AvgMedian extends StatelessWidget {
  const _AvgMedian({required this.dist});

  final MetricDistribution dist;

  @override
  Widget build(BuildContext context) {
    Widget part(Color c, String label, String v) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('${tr(label)} ', style: const TextStyle(fontSize: 11, color: AppColors.label, fontWeight: FontWeight.w600)),
          Text(v, style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w800)),
        ]);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        part(AppColors.indigo, 'Avg', _fmt(dist.mean)),
        const SizedBox(width: 12),
        part(AppColors.friend, 'Median', _fmt(dist.median)),
      ]),
    );
  }
}

/// 맨 위 국가 카드 안에 작게 들어가는 희귀도 (누르면 설명)
class _RarityPill extends StatelessWidget {
  const _RarityPill({required this.result});

  final RarityResult result;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showRarityInfo(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💎', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('RARITY'), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.label)),
                Text(tr('Top ${_pct(result.topPercent)}%'), style: const TextStyle(fontSize: 13, height: 1.1, fontWeight: FontWeight.w900, color: AppColors.darkMint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showRarityInfo(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 36 + MediaQuery.of(sheetContext).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Rarity score'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          const _InfoLine('Rare country', 'Fewer travelers = higher value'),
          const _InfoLine('Your score', 'Avg rarity of visited countries'),
          const _InfoLine('Scale', '0–100, typical traveler = 50'),
          const _InfoLine('80+', 'Top 2% of travelers'),
        ],
      ),
    ),
  );
}

/// 레벨별 비율: 전체 활동 유저 중 각 레벨(Globetrotter 등)에 속한 % (인원 수는 노출하지 않는다).
void _showRankShares(BuildContext context, List<(String, double)> shares, String? myRank) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 36 + MediaQuery.of(sheetContext).viewPadding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Level distribution'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('% of users at each level'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.label)),
          const SizedBox(height: 14),
          if (shares.isEmpty) _Notice(tr('No community stats available yet.')),
          for (final (name, pct) in shares)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _RankImage(name, size: 30),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 94,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(tr(name), maxLines: 1, style: TextStyle(fontSize: 14, fontWeight: name == myRank ? FontWeight.w900 : FontWeight.w700, color: name == myRank ? AppColors.darkMint : null)),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: (pct / 100).clamp(0.0, 1.0), minHeight: 8, backgroundColor: Colors.grey.shade200, color: AppColors.darkMint),
                    ),
                  ),
                  SizedBox(width: 56, child: Text(_pctText(pct), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.darkMint))),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// 배지 통계 카드: 배지 점수로 본 전체 유저 중 상위 %
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.ctx});

  final _StatsContext ctx;

  @override
  Widget build(BuildContext context) {
    final b = ctx.rarity.meBadge;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ctx.locked ? () => _promptSubscribe(context) : null,
      child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconDot('🏅'),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('Badges'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              GestureDetector(
                onTap: () => ctx.locked ? _promptSubscribe(context) : _showRankShares(context, ctx.rarity.rankShares, ctx.rarity.meBadge?.rank),
                behavior: HitTestBehavior.opaque,
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.format_list_numbered_rounded, size: 20, color: AppColors.darkMint)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BigPercent(top: b?.topPercent, fallback: '${b?.points ?? 0}', locked: ctx.locked),
          const SizedBox(height: 3),
          if (ctx.locked)
            Row(children: [
              const Icon(Icons.lock_rounded, size: 13, color: AppColors.darkMint),
              const SizedBox(width: 4),
              Expanded(child: Text(tr('Premium'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.darkMint, fontWeight: FontWeight.w700))),
            ])
          else
          Row(
            children: [
              if (b != null) ...[_RankImage(b.rank, size: 28), const SizedBox(width: 6)],
              Expanded(
                child: Text(b == null ? '' : '${tr('${b.points} pts')} · ${tr(b.rank)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.label, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Spacer(),
          if (!ctx.locked) _Footer(friend: ctx.badgeFriendRank()),
        ],
      ),
    ),
    );
  }
}

/// 레벨(랭크) 이미지. 에셋이 없으면 자리만 비운다.
class _RankImage extends StatelessWidget {
  const _RankImage(this.rank, {required this.size});

  final String rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = rankAsset(rank);
    return SizedBox(width: size, height: size, child: asset == null ? null : Image.asset(asset, fit: BoxFit.contain));
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(tr(k), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkMint))),
            Expanded(child: Text(tr(v), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}

/// 항목 여러 개를 한 카드에 줄로 보여준다 (이모지 · 이름 · 분포 막대 · 값).
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.ctx, required this.metrics, this.titles});

  final _StatsContext ctx;
  final List<StatMetric> metrics;
  final List<String>? titles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            _MetricRow(ctx: ctx, metric: metrics[i], title: titles?[i] ?? metrics[i].label),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.ctx, required this.metric, required this.title});

  final _StatsContext ctx;
  final StatMetric metric;
  final String title;

  @override
  Widget build(BuildContext context) {
    final value = ctx.mine.valueOf(metric);
    final dist = ctx.locked ? null : ctx.dist(metric);
    final top = ctx.top(metric);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ctx.locked ? () => _promptSubscribe(context) : null,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(metric.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(tr(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              if (ctx.locked) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.lock_rounded, size: 14, color: AppColors.darkMint)) else Text('$value', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.label)),
              const SizedBox(width: 12),
              Text(ctx.locked ? tr('Top ?%') : (top == null ? '—' : tr('Top ${_pct(top)}%')),
                  style: TextStyle(fontSize: 18, height: 1.0, fontWeight: FontWeight.w900, color: ctx.locked || top == null ? AppColors.label : AppColors.darkMint)),
            ],
          ),
          if (dist != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _PositionBar(value: value, dist: dist)),
                const SizedBox(width: 12),
                SizedBox(width: 96, child: _AvgMedian(dist: dist)),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }
}

/// 전체 유저 분포에서 내 위치 (평균/중앙값 눈금 포함)
class _PositionBar extends StatelessWidget {
  const _PositionBar({required this.value, required this.dist});

  final int value;
  final MetricDistribution dist;

  @override
  Widget build(BuildContext context) {
    final maxKey = dist.hist.keys.fold<int>(1, (a, b) => b > a ? b : a);
    final scale = (value > maxKey ? value : maxKey).toDouble();
    double at(num v) => (v / scale).clamp(0.0, 1.0).toDouble();
    Widget tick(double f, Color color, double height) => Align(
          alignment: Alignment(f * 2 - 1, 0),
          child: Container(width: 2, height: height, color: color),
        );
    return SizedBox(
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(height: 6, color: AppColors.line),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: at(value).clamp(0.0, 1.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(height: 6, color: AppColors.mint),
              ),
            ),
          ),
          tick(at(dist.mean), AppColors.indigo, 12),
          tick(at(dist.median), AppColors.friend, 8),
        ],
      ),
    );
  }
}

// ── Friends ─────────────────────────────────────────────────────────────

class _FriendsTab extends StatefulWidget {
  const _FriendsTab();

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> with AutomaticKeepAliveClientMixin {
  final Future<GlobalStats?> _global = GlobalStatsService.instance.load();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = SocialScope.of(context);
    final me = store.me;
    if (me == null) {
      return Center(child: store.meLoaded ? EmptyHint(tr('No travel record yet. Sync your trips first.')) : const CircularProgressIndicator());
    }
    if (store.friends.isEmpty) {
      return Center(child: EmptyHint(tr('Add friends to compare stats.')));
    }
    return FutureBuilder<GlobalStats?>(
      future: _global,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final g = snap.data?.of(StatMetric.countriesTotal);
        final dist = g == null || g.isEmpty ? null : g;
        final people = [me, ...store.friends]..sort((a, b) => b.countryCount.compareTo(a.countryCount));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(tr('Countries · world rank'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.label)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.cardShadow),
              child: Column(
                children: [
                  for (var i = 0; i < people.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.line),
                    _FriendRankRow(
                      rank: i + 1,
                      profile: people[i],
                      isMe: people[i].uid == me.uid,
                      top: dist?.topPercent(people[i].countryCount),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FriendRankRow extends StatelessWidget {
  const _FriendRankRow({required this.rank, required this.profile, required this.isMe, required this.top});

  final int rank;
  final SocialProfile profile;
  final bool isMe;
  final double? top;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      3 => AppColors.bronze,
      _ => AppColors.label,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('$rank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: medal))),
          UserAvatar(profile: profile, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                if (isMe) Text(tr('YOU'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: AppColors.darkMint)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(top == null ? '—' : tr('Top ${_pct(top!)}%'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.darkMint)),
            ),
          ),
          const SizedBox(width: 10),
          // 내 줄에는 버튼 자리만 비워 둬서 퍼센트 열이 줄마다 가지런하다
          SizedBox(
            width: 64,
            child: isMe
                ? null
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(socialRoute<void>((_) => FriendStatsScreen(profile: profile))),
                    child: Container(
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(tr('Stats'), maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.darkMint)))),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.darkMint),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 친구 한 명의 통계 (My Stats와 같은 화면)
class FriendStatsScreen extends StatelessWidget {
  const FriendStatsScreen({super.key, required this.profile});

  final SocialProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(profile.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _MyStatsTab(profile: profile),
    );
  }
}

// ── Rankings ────────────────────────────────────────────────────────────

class _RankingsTab extends StatefulWidget {
  const _RankingsTab();

  @override
  State<_RankingsTab> createState() => _RankingsTabState();
}

class _RankingsTabState extends State<_RankingsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: const [_SiteCollections()],
    );
  }
}

// ── travelogapp.uk 통계 이미지 ──────────────────────────────────────────

/// travelogapp.uk/travel-statistics 의 순위 그림. 분류마다 앞의 몇 개만 바로 보여 주고,
/// 나머지는 구독자이거나 보상형 광고를 본 경우에만 열린다 (잠긴 항목은 이미지를 받지 않는다).
class _SiteItem {
  const _SiteItem(this.category, this.slug, this.title);

  final String category;
  final String slug;
  final String title;

  /// 목록용 제목을 앞부분(Most visited)과 지역/주제 부분으로 나눈다.
  (String, String) get titleParts {
    final parts = title.split(' — ');
    if (parts.length >= 2) {
      final head = parts.first.replaceAll(' destinations', '').replaceAll(RegExp(r'\s+'), ' ').trim();
      return (head, parts.sublist(1).join(' '));
    }
    final m = RegExp(r'^(Most visited|Least visited)\s+(.*)$', caseSensitive: false).firstMatch(title);
    if (m != null) return (m.group(1)!, m.group(2)!);
    return ('', title);
  }

  /// 목록용 짧은 제목: "Most visited destinations — Africa" -> "Most visited · Africa"
  String get shortTitle {
    final parts = title.split(' — ');
    if (parts.length < 2) return title;
    final head = parts.first.replaceAll(' destinations', '').replaceAll(' Most', 'Most');
    return '$head · ${parts.sublist(1).join(' ')}';
  }

  String get thumbUrl => 'https://travelogapp.uk/assets/statistics/$slug-thumb.webp';
  String get imageUrl => 'https://travelogapp.uk/assets/statistics/$slug.webp';
}

const _siteCategories = <(String, String)>[
  ('countries', 'Countries'),
  ('cities', 'Cities'),
  ('landmarks', 'Landmarks'),
  ('world-data', 'World data'),
];

/// 분류마다 가장 대표성 있는 통계를 앞에 둔다 (나머지는 원래 순서)
const _sitePinned = <String, List<String>>{
  'countries': ['most-visited-europe', 'most-visited-asia', 'most-visited-north-america', 'most-visited-africa', 'most-visited-latin-america', 'most-visited-oceania'],
  'cities': ['most-visited-world-cities', 'most-visited-world-capitals-cities', 'most-visited-europe-cities', 'most-visited-asia-cities', 'most-visited-north-america-cities'],
  'landmarks': ['most-visited-world-museums', 'most-visited-ancient-ruins', 'most-visited-world-beaches', 'most-visited-world-castles', 'most-visited-world-churches', 'palaces-worldwide'],
  'world-data': ['worlds-largest-economies', 'richest-countries-per-capita', 'biggest-military-spenders', 'worlds-biggest-exporters'],
};

/// 분류마다 처음 몇 개를 무료로 연다
const _siteFreeCount = 3;

class _SiteCollections extends StatefulWidget {
  const _SiteCollections();

  @override
  State<_SiteCollections> createState() => _SiteCollectionsState();
}

class _SiteCollectionsState extends State<_SiteCollections> {
  late final Future<List<_SiteItem>> _items = rootBundle.loadString('assets/site_rankings.json').then((s) => [
        for (final e in json.decode(s) as List) _SiteItem(e['c'] as String, e['s'] as String, e['t'] as String),
      ]);
  String _category = 'countries';
  int _shown = 12;

  /// 순위표 대륙 필터 (null = 전체). 분류를 바꿔도 유지된다.
  String? _continent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: SubscriptionService.instance,
      builder: (context, _) => FutureBuilder<List<_SiteItem>>(
      future: _items,
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const SizedBox.shrink();
        final pins = _sitePinned[_category] ?? const <String>[];
        int pinRank(_SiteItem i) {
          final k = pins.indexOf(i.slug);
          return k < 0 ? pins.length : k;
        }

        final items = [for (final i in all) if (i.category == _category) i]..sort((a, b) => pinRank(a).compareTo(pinRank(b)));
        final free = items.take(_siteFreeCount).toList();
        final rest = items.skip(_siteFreeCount).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(child: Text(tr('Travelog collections'), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  const SizedBox(width: 8),
                  Text('${all.length}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label)),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _siteCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final (id, label) = _siteCategories[i];
                  final on = id == _category;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _category = id;
                      _shown = 12;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? AppColors.mint : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: on ? null : AppColors.cardShadow,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (id != 'countries' && !SubscriptionService.instance.isPremium) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.lock_rounded, size: 12, color: on ? Colors.white : AppColors.darkMint)),
                        Text(tr(label), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? Colors.white : AppColors.ink)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_category != 'countries' && !SubscriptionService.instance.isPremium)
              _RankingLockedCard(label: tr(_siteCategories.firstWhere((c) => c.$1 == _category).$2))
            else ...[
            if (_boardKinds.contains(_category)) ...[
              _UserBoard(key: ValueKey(_category), kind: _category, continent: _continent, onContinent: (c) => setState(() => _continent = c)),
              const SizedBox(height: 16),
            ],
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: free.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _SitePoster(item: free[i]),
              ),
            ),
            const SizedBox(height: 12),
            for (final item in rest.take(_shown)) _SiteLockedRow(item: item),
            if (rest.length > _shown)
              Center(
                child: TextButton(onPressed: () => setState(() => _shown += 20), child: Text(tr('Show more (${rest.length - _shown})'))),
              ),
            ],
            const SizedBox(height: 14),
          ],
        );
      },
    ),
    );
  }
}

/// 비구독자에게 국가 외 랭킹 분류를 가리고 구독을 안내한다
class _RankingLockedCard extends StatelessWidget {
  const _RankingLockedCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.lock_rounded, size: 34, color: AppColors.darkMint),
          const SizedBox(height: 10),
          Text(tr('$label rankings are Premium'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(tr('Subscribe to Travelog Premium to see every ranking.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.label)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.mint, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => _promptSubscribe(context),
              child: Text(tr('Unlock with Premium')),
            ),
          ),
        ],
      ),
    );
  }
}

const _boardKinds = ['countries', 'cities', 'landmarks'];

class _BoardRow {
  const _BoardRow({required this.label, this.sub, this.continent, this.iso2, this.iso2b, required this.value, this.barColor = AppColors.label});

  final String label;
  final String? sub;
  final String? continent;
  final String? iso2;

  /// 두 나라에 걸친 곳이면 두 번째 나라 (국기를 대각선 반쪽씩 보여준다)
  final String? iso2b;
  final double value;
  final Color barColor;
}

/// Travelog 유저 방문율 순위표 (assets/user_rankings.json)
class _UserBoards {
  static Future<Map<String, List<_BoardRow>>>? _cache;

  static Future<Map<String, List<_BoardRow>>> load() => _cache ??= _read().catchError((Object e) {
        _cache = null;
        return <String, List<_BoardRow>>{};
      });

  static Future<Map<String, List<_BoardRow>>> _read() async {
    if (!GeoData.isLoaded) await GeoData.load();
    final geo = GeoData.I;
    final colorRows = json.decode(await rootBundle.loadString('assets/country_color.json')) as List;
    final countryColors = <String, Color>{};
    for (final entry in colorRows) {
      final hex = (entry['theme_color_hex'] as String?)?.replaceFirst('#', '');
      final value = hex == null || hex.length != 6 ? null : int.tryParse(hex, radix: 16);
      if (value != null) countryColors[entry['iso_a2'] as String] = Color(0xFF000000 | value);
    }
    Color countryColor(String? iso2) => countryColors[iso2] ?? AppColors.label;
    final raw = json.decode(await rootBundle.loadString('assets/user_rankings.json')) as Map;
    List<(String, double)> list(String k) => [for (final e in raw[k] as List) (e[0] as String, (e[1] as num).toDouble())];

    final countries = <_BoardRow>[];
    final seen = <String>{};
    for (final (name, v) in list('countries')) {
      final c = geo.countryByName(name);
      if (c == null) continue;
      seen.add(c.iso3);
      countries.add(_BoardRow(label: c.name, sub: c.continent, continent: c.continent, iso2: c.iso2, value: v, barColor: countryColor(c.iso2)));
    }
    final rest = [for (final c in geo.countries.values) if (!seen.contains(c.iso3)) c]..sort((a, b) => a.name.compareTo(b.name));
    for (final c in rest) {
      countries.add(_BoardRow(label: c.name, sub: c.continent, continent: c.continent, iso2: c.iso2, value: 0, barColor: countryColor(c.iso2)));
    }

    final cities = <_BoardRow>[];
    for (final (name, v) in list('cities')) {
      final meta = geo.cities[name];
      if (meta == null) continue;
      final c = geo.countryByIso2(meta.iso2);
      cities.add(_BoardRow(label: displayCityName(name), sub: c?.name, continent: _boardContinentOf(name, c?.continent), iso2: c?.iso2, value: v, barColor: countryColor(c?.iso2)));
    }

    final landmarks = <_BoardRow>[];
    for (final e in raw['landmarks'] as List) {
      final name = e[0] as String;
      final v = (e[1] as num).toDouble();
      // 세 번째 값: 국가 코드 (두 나라에 걸친 곳은 두 개)
      final countries = [
        for (final iso in (e.length > 2 ? e[2] as List : const [])) ?geo.countryByIso3('$iso'),
      ];
      final first = countries.isNotEmpty ? countries.first : geo.countryByIso3(geo.landmarks[name]?.iso3);
      if (first == null) continue;
      final two = countries.length > 1;
      landmarks.add(_BoardRow(
        label: name,
        sub: two ? countries.map((c) => c.name).join(' · ') : first.name,
        continent: _boardContinentOf(geo.landmarks[name]?.city, first.continent),
        iso2: first.iso2,
        iso2b: two ? countries[1].iso2 : null,
        value: v,
        barColor: countryColor(first.iso2),
      ));
    }
    return {'countries': countries, 'cities': cities, 'landmarks': landmarks};
  }
}

/// 순위표 드롭다운의 대륙 (null = 전체)
const _boardContinents = <String?>[null, 'Asia', 'Europe', 'Africa', 'North America', 'South America', 'Oceania'];

/// 대륙 필터 없이 볼 때의 최대 줄 수 (대륙별로 거른 목록은 원본 전체에서 고른다)
const _boardLimits = {'cities': 200, 'landmarks': 500};

/// 순위표 대륙 필터에서만 이스탄불(과 그 안의 랜드마크)을 유럽으로 본다
String? _boardContinentOf(String? city, String? continent) => city == 'Istanbul' ? 'Europe' : continent;

String _pctText(double v) => '${v.toStringAsFixed(v < 10 ? 1 : 0)}%';

/// 순위표: 처음에는 10줄만 보이고, 펼치면 전부 보인다. 도시와 랜드마크의 전체 목록은 구독자만 (아니면 보상형 광고/구독 화면).
class _UserBoard extends StatefulWidget {
  const _UserBoard({super.key, required this.kind, this.continent, required this.onContinent});

  final String kind;
  final String? continent;
  final ValueChanged<String?> onContinent;

  @override
  State<_UserBoard> createState() => _UserBoardState();
}

class _UserBoardState extends State<_UserBoard> {
  bool _open = false;

  String get _title => switch (widget.kind) {
        'countries' => tr('Most visited countries'),
        'cities' => tr('Most visited cities'),
        _ => tr('Most visited landmarks'),
      };

  bool get _premiumOnly => widget.kind != 'countries';

  void _showAll(List<_BoardRow> rows) {
    if (_premiumOnly && !SubscriptionService.instance.isPremium) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          body: StatLockGuard(
            statKey: 'board.${widget.kind}',
            locked: true,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + MediaQuery.of(context).viewPadding.bottom),
              children: [_BoardCard(title: _title, rows: rows, shown: rows.length)],
            ),
          ),
        ),
      ));
      return;
    }
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<_BoardRow>>>(
      future: _UserBoards.load(),
      builder: (context, snap) {
        final all = snap.data?[widget.kind];
        if (all == null || all.isEmpty) {
          return SizedBox(height: 120, child: Center(child: snap.connectionState == ConnectionState.done ? const SizedBox.shrink() : const CircularProgressIndicator(strokeWidth: 2)));
        }
        return ListenableBuilder(
          listenable: SubscriptionService.instance,
          builder: (context, _) {
            final locked = _premiumOnly && !SubscriptionService.instance.isPremium;
            final continent = widget.continent;
            final rows = continent == null ? all.take(_boardLimits[widget.kind] ?? all.length).toList() : [for (final r in all) if (r.continent == continent) r];
            return _BoardCard(
              title: _title,
              rows: rows,
              shown: _open ? rows.length : 10,
              action: _ContinentDropdown(value: continent, onChanged: widget.onContinent),
              footer: rows.length <= 10 ? null : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showAll(rows),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (locked && !_open) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.lock_rounded, size: 14, color: AppColors.darkMint)),
                      Flexible(child: Text(_open ? tr('Show less') : tr('Show all ${rows.length}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.darkMint))),
                      Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.darkMint),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.title, required this.rows, required this.shown, this.action, this.footer});

  final String title;
  final List<_BoardRow> rows;
  final int shown;
  final Widget? action;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final maxV = rows.isEmpty ? 1.0 : rows.first.value.clamp(1.0, 100.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    if (action != null) Text(tr('% of users'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.label)),
                  ],
                ),
              ),
              action ?? Text(tr('% of users'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.label)),
            ],
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text(tr('No data yet'), style: const TextStyle(fontSize: 13, color: AppColors.label)))),
          for (var i = 0; i < shown && i < rows.length; i++) _BoardLine(rank: i + 1, row: rows[i], maxValue: maxV),
          if (footer != null) footer! else const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// 순위표 머리의 대륙 선택 드롭다운
class _ContinentDropdown extends StatelessWidget {
  const _ContinentDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.darkMint),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.darkMint),
          items: [
            for (final c in _boardContinents)
              DropdownMenuItem<String?>(value: c, child: Text(c == null ? tr('All continents') : tr(continentLabel(c)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// 두 나라에 걸친 곳의 국기: 대각선으로 반쪽씩 (왼쪽 위 / 오른쪽 아래)
class _SplitFlag extends StatelessWidget {
  const _SplitFlag(this.a, this.b, {this.width = 26});

  final String? a;
  final String? b;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            Positioned.fill(child: ClipPath(clipper: const _DiagonalClipper(upper: true), child: Flag(a, width: width, radius: 0))),
            Positioned.fill(child: ClipPath(clipper: const _DiagonalClipper(upper: false), child: Flag(b, width: width, radius: 0))),
            const Positioned.fill(child: CustomPaint(painter: _DiagonalLine())),
          ],
        ),
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  const _DiagonalClipper({required this.upper});

  final bool upper;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (upper) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 두 국기 사이의 가는 흰 선
class _DiagonalLine extends CustomPainter {
  const _DiagonalLine();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), Paint()..color = Colors.white..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BoardLine extends StatelessWidget {
  const _BoardLine({required this.rank, required this.row, required this.maxValue});

  final int rank;
  final _BoardRow row;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      3 => AppColors.bronze,
      _ => AppColors.label,
    };
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('$rank', style: TextStyle(fontSize: rank <= 3 ? 16 : 14, fontWeight: FontWeight.w900, color: medal))),
          row.iso2b != null ? _SplitFlag(row.iso2, row.iso2b, width: 26) : Flag(row.iso2, width: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(row.label), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      Container(height: 4, color: AppColors.line),
                      FractionallySizedBox(widthFactor: (row.value / maxValue).clamp(0.0, 1.0).toDouble(), child: Container(height: 4, color: row.barColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 50, child: Text(_pctText(row.value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.darkMint))),
        ],
      ),
    );
  }
}

class _SitePoster extends StatelessWidget {
  const _SitePoster({required this.item});

  final _SiteItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSiteImage(context, item, false),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: AppColors.cardShadow, color: Colors.white),
          clipBehavior: Clip.antiAlias,
          child: CachedNetworkImage(
            imageUrl: item.thumbUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorWidget: (_, _, _) => Center(child: Padding(padding: const EdgeInsets.all(12), child: Text(tr(item.title), textAlign: TextAlign.center))),
          ),
        ),
      ),
    );
  }
}

/// "Most visited" 뒤의 지역 이름만 테마색으로 칠한다 (항목마다 조금씩 다른 색).
class _ColoredTitle extends StatelessWidget {
  const _ColoredTitle({required this.item});

  final _SiteItem item;

  static const _palette = [
    Color(0xFFC8566F),
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final (prefix, rest) = item.titleParts;
    final hash = item.slug.codeUnits.fold<int>(0, (a, b) => a + b);
    final color = prefix.isEmpty ? AppColors.ink : _palette[hash % _palette.length];
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
        children: [
          if (prefix.isNotEmpty) TextSpan(text: '${tr(prefix)} · '),
          TextSpan(text: tr(rest), style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _SiteLockedRow extends StatelessWidget {
  const _SiteLockedRow({required this.item});

  final _SiteItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openSiteImage(context, item, true),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: ListenableBuilder(
              listenable: SubscriptionService.instance,
              builder: (context, _) => Row(
                children: [
                  Icon(SubscriptionService.instance.isPremium ? Icons.bar_chart_rounded : Icons.lock_rounded, size: 18, color: AppColors.label),
                  const SizedBox(width: 10),
                  Expanded(child: _ColoredTitle(item: item)),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _openSiteImage(BuildContext context, _SiteItem item, bool locked) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _SiteImagePage(item: item, locked: locked)));
}

class _SiteImagePage extends StatelessWidget {
  const _SiteImagePage({required this.item, required this.locked});

  final _SiteItem item;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StatLockGuard(
        statKey: 'site.${item.slug}',
        locked: locked,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const CircularProgressIndicator(),
                    errorWidget: (_, _, _) => EmptyHint(tr('Could not load the image.')),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Builder(
                builder: (btnContext) => IconButton.filledTonal(
                  tooltip: tr('Share'),
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  onPressed: () => _shareSiteImage(btnContext, item),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _shareSiteImage(BuildContext context, _SiteItem item) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    final res = await http.get(Uri.parse(item.imageUrl));
    if (res.statusCode != 200) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/travelog_${item.slug}.webp');
    await file.writeAsBytes(res.bodyBytes);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin));
  } catch (_) {}
}

