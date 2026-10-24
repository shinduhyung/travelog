import 'package:flutter/material.dart';

import '../../models/social_profile.dart';
import '../../models/stats.dart';
import '../../services/social_repository.dart';
import '../../services/social_store.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../common.dart';
import '../new_duel_sheet.dart';
import '../profile_screen.dart';
import 'cities_tab.dart';
import 'countries_tab.dart';
import 'dna_tab.dart';
import 'duels_tab.dart';
import 'flights_tab.dart';
import 'landmarks_tab.dart';
import 'overview_tab.dart';
import 'play_tab.dart';
import '../../widgets/avatar.dart';
import '../../social_hub.dart';

/// 나 vs 친구 — 8개 탭으로 모든 기록을 비교
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key, required this.friendUid, this.initialTab = 0});

  final String friendUid;
  final int initialTab;

  static const tabs = [
    ('Overview', '✨'),
    ('Countries', '🌍'),
    ('Cities', '🏙️'),
    ('Landmarks', '🗼'),
    ('Flights', '✈️'),
    ('Travel DNA', '🧬'),
    ('Quiz & Games', '🧠'),
    ('Duels', '⚔️'),
  ];

  Future<void> _unfriend(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unfriend $name?', maxLines: 2, overflow: TextOverflow.ellipsis),
        content: const Text("You won't be able to see each other's travel logs anymore."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unfriend')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SocialRepository.instance.removeFriend(friendUid);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showError(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final me = store.me;
    final friend = store.friend(friendUid);

    if (me == null || friend == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: store.friendLoaded(friendUid) || store.meLoaded
              ? const EmptyHint('Nothing to compare yet.\nTheir travel log shows up once they open the app.')
              : const CircularProgressIndicator(),
        ),
      );
    }
    final cmp = Comparison(me, friend);

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialTab,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, inner) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 230,
              foregroundColor: Colors.white,
              backgroundColor: AppColors.darkMint,
              surfaceTintColor: Colors.transparent,
              title: Text(
                'You vs ${friend.displayName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (_) => _unfriend(context, friend.displayName),
                  itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Unfriend'))],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _VsHero(cmp: cmp),
              ),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                dividerColor: Colors.transparent,
                tabs: [for (final (label, emoji) in tabs) Tab(text: '$emoji $label')],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              OverviewTab(cmp: cmp),
              CountriesTab(cmp: cmp),
              CitiesTab(cmp: cmp),
              LandmarksTab(cmp: cmp),
              FlightsTab(cmp: cmp),
              DnaTab(cmp: cmp),
              PlayTab(cmp: cmp),
              DuelsTab(cmp: cmp),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'duel-$friendUid',
          onPressed: () => startDuelFlow(context, friend),
          icon: const Text('⚔️', style: TextStyle(fontSize: 18)),
          label: const Text('Start a duel'),
        ),
      ),
    );
  }
}

class _VsHero extends StatelessWidget {
  const _VsHero({required this.cmp});

  final Comparison cmp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget side(SocialProfile p, Color color, int wins) => Expanded(
      // 좁은 높이에서도 넘치지 않도록 너비는 유지하고 필요하면 축소
      child: LayoutBuilder(
        builder: (context, c) => FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: c.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    socialRoute<void>((_) => ProfileScreen(uid: p.uid)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: UserAvatar(profile: p, radius: 24),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${p.countryCount} ${p.countryCount == 1 ? 'country' : 'countries'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.vsGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 56, 12, 50),
          child: Row(
            children: [
              side(cmp.me, AppColors.me, cmp.myWins),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${cmp.myWins} : ${cmp.theirWins}',
                        style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                      Text('Category score', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '💞 Travel match ${cmp.compatibility}%',
                          style: theme.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              side(cmp.friend, AppColors.friend, cmp.theirWins),
            ],
          ),
        ),
      ),
    );
  }
}

/// 범례·칩처럼 좁은 곳에 넣을 이름 (길면 말줄임)
String shortName(String name, [int max = 10]) => name.characters.length <= max ? name : '${name.characters.take(max - 1)}…';

/// 탭 공통 스크롤 영역
class TabList extends StatelessWidget {
  const TabList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) => children[i],
    );
  }
}
