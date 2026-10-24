import 'package:flutter/material.dart';

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
import '../widgets/profile_maps.dart';
import '../widgets/top_landmarks.dart';
import 'badges_screen.dart';
import 'category_list_screen.dart';
import 'common.dart';
import 'compare/compare_screen.dart';
import 'new_duel_sheet.dart';
import '../social_hub.dart';

/// 나든 친구든 같은 프로필 화면. 나일 때만 이름 변경/동기화/로그아웃/공개 범위.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.uid});

  final String uid;

  Future<void> _editName(BuildContext context, String uid, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name shown to friends'),
        content: TextField(controller: controller, autofocus: true, maxLength: 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await SocialRepository.instance.updateDisplayName(uid, name);
    } catch (e) {
      if (context.mounted) showError(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final isSelf = uid == store.uid;
    final p = isSelf ? store.me : store.friend(uid);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelf ? 'My profile' : (p?.displayName ?? 'Profile'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isSelf) ...[
            IconButton(
              tooltip: 'Change name',
              onPressed: p == null ? null : () => _editName(context, store.uid, p.displayName),
              icon: const Icon(Icons.edit_outlined),
            ),
            if (store.syncing)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              IconButton(tooltip: 'Sync from Travelog', onPressed: store.sync, icon: const Icon(Icons.sync)),
          ],
        ],
      ),
      body: p == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: store.syncing || (!isSelf && !store.friendLoaded(uid))
                    ? const CircularProgressIndicator()
                    : isSelf
                        ? FilledButton(onPressed: store.sync, child: const Text('Import Travelog records'))
                        : const EmptyHint('This profile is not available yet.', emoji: '🫥'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              children: [
                _Header(profile: p, isSelf: isSelf),
                const SizedBox(height: 16),
                _Stats(profile: p),
                const SizedBox(height: 16),
                WhiteCard(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: ProfileMaps(profile: p, viewerMe: store.me),
                ),
                const SizedBox(height: 16),
                TopLandmarksPreview(uids: [p.uid]),
                const SizedBox(height: 16),
                BadgesSection(profile: p),
                const SizedBox(height: 16),
                _Timeline(p: p, isSelf: isSelf),
                if (isSelf) ...[
                  const SizedBox(height: 16),
                  _Privacy(p: p),
                  if (store.syncError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Sync failed: ${store.syncError}',
                          maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (p.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Last synced: ${p.updatedAt!.toLocal().toString().substring(0, 16)}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label)),
                    ),
                ],
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.isSelf});

  final SocialProfile profile;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final theme = Theme.of(context);
    final stats = ProfileStats(p);
    final home = GeoData.I.countryByIso3(p.homeCountryIso3);
    final rank = p.badgeRank;
    final rankImage = rankAsset(rank);

    return WhiteCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(profile: p, radius: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (p.isPremium) ...[
                      const SizedBox(height: 2),
                      PlanBadge(plan: p.plan),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (home != null) ...[Flag(home.iso2, width: 20, radius: 2), const SizedBox(width: 6)],
                        Expanded(
                          child: Text(
                            home?.longName ?? 'No home country',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (rank != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (rankImage != null) ...[Image.asset(rankImage, width: 26, height: 26), const SizedBox(width: 6)],
                          Expanded(
                            child: Text(
                              rankLabel[rank] ?? rank,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.darkMint),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.worldPercent.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation(AppColors.mint),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(stats.worldPercent * 100).toStringAsFixed(1)}% of the world · '
            '${stats.continentCount} continents',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600),
          ),
          if (!isSelf) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    socialRoute<void>((_) => CompareScreen(friendUid: p.uid)),
                  ),
                  icon: const Icon(Icons.compare_arrows, size: 18),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Compare')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.indigo),
                  onPressed: () => startDuelFlow(context, p),
                  icon: const Icon(Icons.sports_esports, size: 18),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Duel')),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.profile});

  final SocialProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final s = ProfileStats(p);
    final theme = Theme.of(context);

    VoidCallback open(ListCategory c) => () => Navigator.push(
          context,
          socialRoute<void>((_) => CategoryListScreen(uid: p.uid, category: c)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatGrid(tiles: [
          StatTile(emoji: '🌍', value: '${p.countryCount}', label: 'Countries', onTap: open(ListCategory.countries)),
          StatTile(emoji: '🏙️', value: compactNumber(p.cityCount), label: 'Cities', onTap: open(ListCategory.cities)),
          StatTile(emoji: '🗼', value: compactNumber(p.landmarkCount), label: 'Landmarks', onTap: open(ListCategory.landmarks)),
          StatTile(
              emoji: '🏛️', value: '${p.unescoCount}', label: 'UNESCO', color: const Color(0xFF8B5CF6), onTap: open(ListCategory.unesco)),
          StatTile(
              emoji: '✈️',
              value: compactNumber(p.flights.total),
              label: 'Flights',
              color: const Color(0xFF0EA5E9),
              onTap: open(ListCategory.flights)),
          StatTile(
              emoji: '🛬',
              value: '${p.airportCount}',
              label: 'Airports',
              color: const Color(0xFF0EA5E9),
              onTap: open(ListCategory.airports)),
          StatTile(
              emoji: '⭐',
              value: '${s.capitalCount}',
              label: 'Capitals',
              color: const Color(0xFFF97316),
              onTap: open(ListCategory.capitals)),
          StatTile(
              emoji: '📏', value: '${compactNumber(s.totalFlightKm.round())} km', label: 'Distance', color: const Color(0xFF0EA5E9)),
          StatTile(
              emoji: '🎖️',
              value: '${p.badgeCount}',
              label: 'Badges',
              color: AppColors.gold,
              onTap: () => Navigator.push(context, socialRoute<void>((_) => BadgesScreen(uid: p.uid)))),
        ]),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app_outlined, size: 14, color: AppColors.label),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Tap a number to see the list',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.p, required this.isSelf});

  final SocialProfile p;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final s = ProfileStats(p);
    final byYear = <int, List<String>>{};
    for (final e in p.countryInfo.entries) {
      final y = e.value.firstYear;
      if (y != null) byYear.putIfAbsent(y, () => []).add(e.key);
    }
    if (byYear.isEmpty) return const SizedBox.shrink();
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final theme = Theme.of(context);
    return SectionCard(
      emoji: '📅',
      title: 'Travel timeline',
      subtitle: 'By year of first visit',
      child: Column(children: [
        TimelineChart(mine: s.cumulativeCountries(), theirs: const {}, height: 170),
        const SizedBox(height: 12),
        for (final y in years.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 54,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('$y', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: AppColors.me)),
                ),
              ),
              Expanded(
                child: Wrap(spacing: 4, runSpacing: 4, children: [
                  for (final c in byYear[y]!)
                    Tooltip(message: GeoData.I.countryByName(c)?.longName ?? c, child: Flag.ofCountry(c, width: 26, radius: 3)),
                ]),
              ),
              const SizedBox(width: 6),
              Text('+${byYear[y]!.length}', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.label)),
            ]),
          ),
      ]),
    );
  }
}

class _Privacy extends StatelessWidget {
  const _Privacy({required this.p});

  final SocialProfile p;

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final pr = p.privacy;
    Future<void> set(PrivacySettings next) async {
      try {
        await store.setPrivacy(next);
      } catch (e) {
        if (context.mounted) showError(context, describeError(e));
      }
    }

    Widget sw(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
          value: value,
          onChanged: store.syncing ? null : onChanged,
        );

    return SectionCard(
      emoji: '🔒',
      title: 'Privacy',
      subtitle: 'Countries & landmarks are always shared',
      child: Column(children: [
        sw('🏙️ City records', 'Visited cities, city ratings, home city', pr.cities, (v) => set(pr.copyWith(cities: v))),
        sw('✈️ Flight records', 'Flight count, routes, airlines, airports', pr.flights, (v) => set(pr.copyWith(flights: v))),
        sw('🧬 Travel DNA', 'Scores for 8 travel traits', pr.dna, (v) => set(pr.copyWith(dna: v))),
        sw('💭 Wishlist', 'Countries, cities, and landmarks you want to visit', pr.wishlist,
            (v) => set(pr.copyWith(wishlist: v))),
      ]),
    );
  }
}
