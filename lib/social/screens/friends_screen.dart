import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/geo_data.dart';
import '../models/social_profile.dart';
import '../models/stats.dart';
import '../services/social_repository.dart';
import '../services/social_store.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/cards.dart';
import '../widgets/charts.dart';
import '../widgets/flag.dart';
import 'common.dart';
import 'compare/compare_screen.dart';
import 'leaderboard_screen.dart';
import 'new_duel_sheet.dart';
import 'profile_screen.dart';
import '../social_hub.dart';

void _openProfile(BuildContext context, String uid) =>
    Navigator.push(context, socialRoute<void>((_) => ProfileScreen(uid: uid)));

/// 첫 화면: 위쪽 친구 추가, 아래쪽 나라 수 기준 친구 순위 (누르면 펼쳐짐)
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _expanded = <String>{};

  SocialRepository get _repo => SocialRepository.instance;

  Future<void> _createInvite(BuildContext context) async {
    try {
      final code = await _repo.createInvite();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Friend invite code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: SelectableText(
                  code,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        letterSpacing: 6,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkMint,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Valid for 7 days. Once your friend enters it under "Enter code", you\'ll be friends right away.',
                style: TextStyle(color: AppColors.label),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => SharePlus.instance.share(ShareParams(
                text: "Let's compare our travels on Travelog Social! Invite code: $code",
              )),
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showError(context, describeError(e));
    }
  }

  Future<void> _enterCode(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter invite code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. K7Q2MX'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;

    try {
      final preview = await _repo.previewInvite(code.trim());
      if (!context.mounted) return;
      if (preview.isSelf) return showError(context, 'This is your own invite code.');
      if (preview.alreadyFriends) {
        return showError(context, "You're already friends with ${preview.ownerName}.");
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Add ${preview.ownerName} as a friend?'),
          content: const Text("Friends can see each other's travel maps, stats, and quiz & game records."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add friend')),
          ],
        ),
      );
      if (ok != true) return;
      await _repo.acceptInvite(code.trim());
      if (context.mounted) showError(context, 'You and ${preview.ownerName} are now friends!');
    } catch (e) {
      if (context.mounted) showError(context, describeError(e));
    }
  }

  Future<void> _showAddFriendSheet(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add friend',
                  style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('Compare maps, see your travel match and duel 1:1',
                  style: Theme.of(sheet).textTheme.bodySmall?.copyWith(color: AppColors.label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              _SheetOption(
                icon: Icons.person_add_alt_1,
                color: AppColors.mint,
                title: 'Invite',
                subtitle: 'Create a code to send to a friend',
                onTap: () => Navigator.pop(sheet, 'invite'),
              ),
              const SizedBox(height: 10),
              _SheetOption(
                icon: Icons.keyboard,
                color: AppColors.indigo,
                title: 'Enter code',
                subtitle: "Type a friend's invite code",
                onTap: () => Navigator.pop(sheet, 'enter'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'invite') {
      await _createInvite(context);
    } else if (choice == 'enter') {
      await _enterCode(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final me = store.me;
    final theme = Theme.of(context);
    final ranked = [...store.everyone]..sort((a, b) {
        final c = b.countryCount.compareTo(a.countryCount);
        return c != 0 ? c : b.cityCount.compareTo(a.cityCount);
      });
    final pending = store.friendUids.where((u) => store.friend(u) == null).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          if (store.syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(tooltip: 'Refresh from Travelog', onPressed: store.sync, icon: const Icon(Icons.sync)),
          if (store.friends.isNotEmpty)
            IconButton(
              tooltip: 'More rankings',
              icon: const Icon(Icons.leaderboard_outlined),
              onPressed: () => Navigator.push(context, socialRoute<void>((_) => const LeaderboardScreen())),
            ),
          if (me != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: Tooltip(
                message: 'My profile',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openProfile(context, store.uid),
                  child: UserAvatar(profile: me, radius: 15),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.sync,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            if (store.syncError != null) ...[
              const SizedBox(height: 8),
              Material(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  leading: const Icon(Icons.sync_problem),
                  title: const Text("Couldn't refresh your Travelog records"),
                  subtitle: Text(store.syncError!, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: TextButton(onPressed: store.sync, child: const Text('Retry')),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _AddFriendButton(onTap: () => _showAddFriendSheet(context)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: Text('Ranking',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text('by countries', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.label)),
            ]),
            const SizedBox(height: 4),
            const _PlanLegend(),
            const SizedBox(height: 12),
            if (store.friendsError != null)
              Text("Couldn't load your friends.\n${store.friendsError}")
            else if (!store.friendsLoaded || (me == null && !store.meLoaded))
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else ...[
              for (var i = 0; i < ranked.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RankRow(
                    rank: i + 1,
                    profile: ranked[i],
                    me: me,
                    isMe: ranked[i].uid == store.uid,
                    expanded: _expanded.contains(ranked[i].uid),
                    onToggle: () => setState(() {
                      final uid = ranked[i].uid;
                      _expanded.contains(uid) ? _expanded.remove(uid) : _expanded.add(uid);
                    }),
                  ),
                ),
              for (final uid in pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: WhiteCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const IconTile(icon: Icons.hourglass_empty, color: AppColors.label),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabelValue(
                          label: store.friendLoaded(uid) ? 'Profile not ready yet' : 'Loading…',
                          value: 'Waiting for their first sync',
                        ),
                      ),
                    ]),
                  ),
                ),
              if (store.friendUids.isEmpty)
                const EmptyHint('No friends yet.\nCreate an invite code and send it to a friend.', emoji: '🌱'),
            ],
          ],
        ),
      ),
    );
  }
}

/// 순위 위 한 줄짜리 친구 추가 버튼 (누르면 초대 / 코드 입력 시트)
class _AddFriendButton extends StatelessWidget {
  const _AddFriendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.tealGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.darkMint.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('Add friend',
                        style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 친구 추가 시트의 큰 선택지
class _SheetOption extends StatelessWidget {
  const _SheetOption({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            IconTile(icon: icon, color: color, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.label),
          ]),
        ),
      ),
    );
  }
}

/// 테두리 색 = 유료 등급
class _PlanLegend extends StatelessWidget {
  const _PlanLegend();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(spacing: 12, runSpacing: 4, children: [
      for (final e in PlanStyle.paid)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: e.value.colors.take(2).toList())),
          ),
          const SizedBox(width: 4),
          Text(e.value.label, style: t.labelSmall?.copyWith(color: AppColors.label)),
        ]),
    ]);
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.profile,
    required this.me,
    required this.isMe,
    required this.expanded,
    required this.onToggle,
  });

  final int rank;
  final SocialProfile profile;
  final SocialProfile? me;
  final bool isMe;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = profile;
    final stats = ProfileStats(p);
    final cmp = (!isMe && me != null) ? Comparison(me!, p) : null;
    const medals = {1: '🥇', 2: '🥈', 3: '🥉'};

    return Container(
      decoration: BoxDecoration(
        color: isMe ? Color.alphaBlend(AppColors.mint.withValues(alpha: 0.07), Colors.white) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isMe ? Border.all(color: AppColors.mint.withValues(alpha: 0.5), width: 1.5) : null,
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  SizedBox(
                    width: 30,
                    child: medals[rank] != null
                        ? Text(medals[rank]!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22))
                        : Text('$rank',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: AppColors.label)),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _openProfile(context, p.uid),
                    child: UserAvatar(profile: p, radius: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () => _openProfile(context, p.uid),
                            child: Text(isMe ? '${p.displayName} (you)' : p.displayName,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        if (p.isPremium) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            flex: 2,
                            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: PlanBadge(plan: p.plan)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        cmp != null ? '${cmp.compatibility}% match' : '${stats.continentCount} continents',
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 64),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${p.countryCount}',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.darkMint)),
                        Text('countries', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label)),
                      ]),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, color: AppColors.label),
                  ),
                ]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: expanded ? _Details(profile: p, stats: stats, cmp: cmp, isMe: isMe) : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.profile, required this.stats, required this.cmp, required this.isMe});

  final SocialProfile profile;
  final ProfileStats stats;
  final Comparison? cmp;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final cmp = this.cmp;

    void openProfile() => _openProfile(context, p.uid);
    String n(int v) => compactNumber(v);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 12),
          _StatGrid(onTap: openProfile, items: [
            ('🏙️', n(p.cityCount), 'cities'),
            ('🗼', n(p.landmarkCount), 'landmarks'),
            ('🏛️', n(p.unescoCount), 'UNESCO'),
            ('✈️', n(p.flights.total), 'flights'),
            ('🎖️', n(p.badgeCount), 'badges'),
            ('🌐', '${(stats.worldPercent * 100).toStringAsFixed(0)}%', 'of world'),
          ]),
          if (cmp != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openProfile,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                OverlapBar(
                  onlyMine: cmp.countries.onlyMine.length,
                  both: cmp.countries.both.length,
                  onlyTheirs: cmp.countries.onlyTheirs.length,
                  height: 20,
                ),
                const SizedBox(height: 12),
                FlagRow(label: 'Both', color: AppColors.both, names: cmp.countries.both),
                FlagRow(label: 'Only you', color: AppColors.me, names: cmp.countries.onlyMine),
                FlagRow(label: 'Only ${shortName(p.displayName)}', color: AppColors.friend, names: cmp.countries.onlyTheirs),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14)),
                  onPressed: () => _openProfile(context, p.uid),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Profile')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14)),
                  onPressed: () => Navigator.push(
                    context,
                    socialRoute<void>((_) => CompareScreen(friendUid: p.uid)),
                  ),
                  icon: const Icon(Icons.compare_arrows, size: 18),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Compare')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  ),
                  onPressed: () => startDuelFlow(context, p),
                  icon: const Icon(Icons.sports_esports, size: 18),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Duel')),
                ),
              ),
            ]),
          ] else if (isMe) ...[
            const SizedBox(height: 14),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openProfile,
              child: FlagRow(label: 'Visited', color: AppColors.me, names: p.countries.toSet()),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _openProfile(context, p.uid),
              icon: const Icon(Icons.person_outline, size: 18),
              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('My profile')),
            ),
          ],
        ],
      ),
    );
  }
}

/// 펼친 순위 줄의 작은 통계 칸: 너비 고정, 숫자는 줄어들 뿐 칸을 키우지 않는다
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items, required this.onTap});

  final List<(String, String, String)> items;
  final VoidCallback onTap;

  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, c) {
      final perRow = (c.maxWidth - _gap * 5) / 6 >= 58 ? 6 : 3;
      final w = ((c.maxWidth - _gap * (perRow - 1)) / perRow).floorToDouble();
      return Wrap(spacing: _gap, runSpacing: _gap, children: [
        for (final (emoji, value, label) in items)
          SizedBox(
            width: w,
            child: Material(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(emoji, style: const TextStyle(fontSize: 12, height: 1.2), maxLines: 1),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value,
                          maxLines: 1,
                          style: theme.textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w900, height: 1.2)),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: AppColors.label, height: 1.2)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

/// 한 줄 국기 목록 (라벨 + 개수 + 가로 스크롤)
class FlagRow extends StatelessWidget {
  const FlagRow({super.key, required this.label, required this.color, required this.names});

  final String label;
  final Color color;
  final Set<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final geo = GeoData.I;
    final sorted = names.toList()
      ..sort((a, b) => (geo.countryByName(a)?.longName ?? a).compareTo(geo.countryByName(b)?.longName ?? b));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          Text('${names.length}', style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 26,
          child: sorted.isEmpty
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text('None', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label)),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 5),
                  itemBuilder: (_, i) => Tooltip(
                    message: geo.countryByName(sorted[i])?.longName ?? sorted[i],
                    child: Flag.ofCountry(sorted[i], width: 34, radius: 3),
                  ),
                ),
        ),
      ]),
    );
  }
}
