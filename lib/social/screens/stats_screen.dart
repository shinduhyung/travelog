import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jidoapp/widgets/stat_lock_guard.dart';

import '../models/global_stats.dart';
import '../models/social_profile.dart';
import '../services/global_stats_service.dart';
import '../services/local_rankings.dart';
import '../services/my_stat_values.dart';
import '../services/user_rankings.dart';
import '../services/social_store.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/ranking_card.dart';

/// 메인 화면 Social 메뉴의 Stats:
///  1) My Stats: 내 기록을 전체 유저와 비교 (상위 %, 평균, 중앙값)
///  2) Rankings: 유저 기반/일반 통계 Top 10 카드
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stats'),
          bottom: const TabBar(tabs: [Tab(text: 'My Stats'), Tab(text: 'Rankings')]),
        ),
        body: const TabBarView(children: [_MyStatsTab(), _RankingsTab()]),
      ),
    );
  }
}

// ── My Stats ────────────────────────────────────────────────────────────

class _MyStatsTab extends StatefulWidget {
  const _MyStatsTab();

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
  Future<List<Object?>>? _combined;
  Future<MyStatValues>? _combinedMine;
  Future<GlobalStats?>? _combinedGlobal;
  Future<List<MyStatValues>>? _combinedFriends;

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final store = SocialScope.of(context);
    final me = store.me;
    if (me == null) {
      return Center(child: store.meLoaded ? const EmptyHint('No travel record yet. Sync your trips first.') : const CircularProgressIndicator());
    }
    final mineFuture = _valuesFor(me);
    final friendsFuture = _friendValues(store.friends);
    if (!identical(_combinedMine, mineFuture) || !identical(_combinedGlobal, _global) || !identical(_combinedFriends, friendsFuture)) {
      _combinedMine = mineFuture;
      _combinedGlobal = _global;
      _combinedFriends = friendsFuture;
      _combined = Future.wait<Object?>([mineFuture, _global, friendsFuture]);
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
        if (mine == null) return const Center(child: EmptyHint('Could not read your stats.'));
        final compare = global != null && global.hasDistributions;
        final ctx = _StatsContext(mine: mine, global: global, friends: friends);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            if (!compare)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _Notice(global == null ? 'Could not load community stats.' : 'No community stats available yet.'),
              ),
            if (compare) _Hero(ctx: ctx),
            const _SectionLabel('🌍', 'Countries', 'Visited countries vs. all Travelog users'),
            _Tiles(ctx: ctx, metrics: StatMetric.values.sublist(0, 7), featured: StatMetric.countriesTotal),
            const _SectionLabel('🏙️', 'Cities, landmarks & heritage', null),
            _Tiles(
              ctx: ctx,
              metrics: const [StatMetric.gawcCities, StatMetric.top250Landmarks, StatMetric.unesco],
              notes: const {StatMetric.gawcCities: 'of 189', StatMetric.top250Landmarks: 'of 250'},
            ),
            const _SectionLabel('✈️', 'Aviation', null),
            _Tiles(ctx: ctx, metrics: const [StatMetric.airports, StatMetric.airlines, StatMetric.flights]),
          ],
        );
      },
    );
  }
}

/// 한 화면이 공유하는 값: 내 기록, 전체 유저 분포, 친구들 기록.
class _StatsContext {
  const _StatsContext({required this.mine, required this.global, required this.friends});

  final MyStatValues mine;
  final GlobalStats? global;
  final List<MyStatValues> friends;

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
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}

/// 맨 위 요약: 가장 상위인 항목과 그다음 항목들.
class _Hero extends StatelessWidget {
  const _Hero({required this.ctx});

  final _StatsContext ctx;

  @override
  Widget build(BuildContext context) {
    final ranked = <(StatMetric, double)>[
      for (final m in StatMetric.values)
        if (ctx.top(m) != null && ctx.mine.valueOf(m) > 0) (m, ctx.top(m)!),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    if (ranked.isEmpty) return const SizedBox.shrink();
    final best = ranked.first;
    final dist = ctx.dist(best.$1)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: AppColors.vsGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x33C8566F), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR TRAVEL STANDING',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: Color(0xCCFFFFFF))),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Top ${_pct(best.$2)}%',
                  style: const TextStyle(fontSize: 44, height: 1.0, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('in ${best.$1.label}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('You ${ctx.mine.valueOf(best.$1)}  ·  average ${_fmt(dist.mean)}',
              style: const TextStyle(fontSize: 13, color: Color(0xDDFFFFFF))),
          if (ranked.length > 1) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in ranked.skip(1).take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text('${r.$1.emoji} ${r.$1.label} · Top ${_pct(r.$2)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.emoji, this.title, this.subtitle);

  final String emoji;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$emoji  $title', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 항목 카드를 2열로 늘어놓는다. [featured]는 가로 전체를 쓴다.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.ctx, required this.metrics, this.featured, this.notes = const {}});

  final _StatsContext ctx;
  final List<StatMetric> metrics;
  final StatMetric? featured;
  final Map<StatMetric, String> notes;

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++)
            Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows[r].length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: _StatTile(ctx: ctx, metric: rows[r][i], wide: rows[r][i] == featured, note: notes[rows[r][i]])),
                    ],
                    if (rows[r].length == 1 && rows[r].first != featured) ...[const SizedBox(width: 10), const Expanded(child: SizedBox())],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// [featured]는 혼자 한 줄, 나머지는 두 개씩
  List<List<StatMetric>> _rows() {
    final rest = [for (final m in metrics) if (m != featured) m];
    return [
      if (featured != null) [featured!],
      for (var i = 0; i < rest.length; i += 2) rest.sublist(i, i + 2 > rest.length ? rest.length : i + 2),
    ];
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.ctx, required this.metric, required this.wide, this.note});

  final _StatsContext ctx;
  final StatMetric metric;
  final bool wide;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = ctx.mine.valueOf(metric);
    final dist = ctx.dist(metric);
    final top = ctx.top(metric);
    final fr = ctx.friendRank(metric);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.mint.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Text(metric.emoji, style: const TextStyle(fontSize: 16)),
              ),
              const Spacer(),
              if (top != null) _TopChip(percent: top),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$value', style: TextStyle(fontSize: wide ? 38 : 30, height: 1.0, fontWeight: FontWeight.w900, color: AppColors.darkMint)),
              if (note != null) ...[
                const SizedBox(width: 5),
                Text(note!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (dist != null) ...[
            const SizedBox(height: 10),
            _PositionBar(value: value, dist: dist),
            const SizedBox(height: 6),
            Text('Avg ${_fmt(dist.mean)} · Median ${_fmt(dist.median)}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label, fontSize: 11)),
          ],
          if (fr != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.group_rounded, size: 14, color: fr.rank == 1 ? AppColors.gold : AppColors.friend),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(fr.rank == 1 ? 'Best among friends' : '#${fr.rank} of ${fr.of} with friends',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.ink)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _fmt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

String _pct(double v) => v < 10 ? v.toStringAsFixed(1) : v.round().toString();

class _TopChip extends StatelessWidget {
  const _TopChip({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final strong = percent <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: strong ? AppColors.tealGradient : null,
        color: strong ? null : AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('Top ${_pct(percent)}%',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: strong ? Colors.white : AppColors.ink)),
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

// ── Rankings ────────────────────────────────────────────────────────────

class _RankingsTab extends StatefulWidget {
  const _RankingsTab();

  @override
  State<_RankingsTab> createState() => _RankingsTabState();
}

class _RankingsTabState extends State<_RankingsTab> with AutomaticKeepAliveClientMixin {
  late final Future<List<(String, RankingData)>> _user = GlobalStatsService.instance.load().then(UserRankings.build);
  late final List<Future<RankingData?>> _local = [for (final s in localRankingSpecs) LocalRankings.build(s)];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<(String, RankingData)>>(
      future: _user,
      builder: (context, snap) {
        final userRankings = snap.data ?? const <(String, RankingData)>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const _SiteCollections(),
            if (userRankings.isNotEmpty) ...[
              const _Heading('Most visited by Travelog users'),
              for (final (id, data) in userRankings) _Ranked(id: id, future: Future.value(data)),
              const SizedBox(height: 8),
            ],
            const _Heading('World rankings'),
            for (var i = 0; i < localRankingSpecs.length; i++) _Ranked(id: localRankingSpecs[i].id, future: _local[i]),
          ],
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _Ranked extends StatelessWidget {
  const _Ranked({required this.id, required this.future});

  final String id;
  final Future<RankingData?> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RankingData?>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const AspectRatio(aspectRatio: RankingCard.designWidth / RankingCard.designHeight, child: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppColors.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                RankingCard(data: data),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Builder(
                    builder: (btnContext) => IconButton.filledTonal(
                      tooltip: 'Share',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      onPressed: () => shareRankingCard(btnContext, data, id: id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  String get thumbUrl => 'https://travelogapp.uk/assets/statistics/$slug-thumb.webp';
  String get imageUrl => 'https://travelogapp.uk/assets/statistics/$slug.webp';
}

const _siteCategories = <(String, String)>[
  ('countries', 'Countries'),
  ('cities', 'Cities'),
  ('landmarks', 'Landmarks'),
  ('world-data', 'World data'),
];

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<_SiteItem>>(
      future: _items,
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const SizedBox.shrink();
        final items = [for (final i in all) if (i.category == _category) i];
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
                  Text('Travelog collections', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
                      child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? Colors.white : AppColors.ink)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
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
                child: TextButton(onPressed: () => setState(() => _shown += 20), child: Text('Show more (${rest.length - _shown})')),
              ),
            const SizedBox(height: 14),
          ],
        );
      },
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
            errorWidget: (_, _, _) => Center(child: Padding(padding: const EdgeInsets.all(12), child: Text(item.title, textAlign: TextAlign.center))),
          ),
        ),
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
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 18, color: AppColors.label),
                const SizedBox(width: 10),
                Expanded(child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                const Icon(Icons.chevron_right_rounded, color: AppColors.label),
              ],
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
      appBar: AppBar(title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: StatLockGuard(
        statKey: 'site.${item.slug}',
        locked: locked,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, _) => const CircularProgressIndicator(),
              errorWidget: (_, _, _) => const EmptyHint('Could not load the image.'),
            ),
          ),
        ),
      ),
    );
  }
}
