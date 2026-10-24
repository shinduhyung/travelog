import 'package:flutter/material.dart';

import '../data/geo_data.dart';
import '../models/social_profile.dart';
import '../models/stats.dart';
import '../services/social_store.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../social_hub.dart';

const badgeCategories = ['Country', 'City', 'Landmarks', 'Flight'];

const _categoryEmoji = {'Country': '🌍', 'City': '🏙️', 'Landmarks': '🗼', 'Flight': '✈️'};

/// Badge meta for an id; ids missing from the catalog become a generic badge.
BadgeMeta badgeMetaFor(String id) =>
    GeoData.I.badges[id] ??
    BadgeMeta(
      id: id,
      name: id.replaceAll(RegExp(r'[_-]+'), ' ').trim().isEmpty ? 'Badge' : id.replaceAll(RegExp(r'[_-]+'), ' ').trim(),
      description: 'A Travelog badge that is not in this app\'s catalog yet.',
    );

/// Unlocked badges, highest points first, then most recent (later in the list) first.
List<BadgeMeta> topUnlockedBadges(SocialProfile p) {
  final indexed = [for (var i = 0; i < p.badgeIds.length; i++) (i, badgeMetaFor(p.badgeIds[i]))];
  indexed.sort((a, b) {
    final c = b.$2.points.compareTo(a.$2.points);
    return c != 0 ? c : b.$1.compareTo(a.$1);
  });
  return [for (final e in indexed) e.$2];
}

int badgePoints(SocialProfile p) => p.badgeIds.toSet().fold(0, (sum, id) => sum + (GeoData.I.badges[id]?.points ?? 0));

/// Total = catalog + ids this profile has that the catalog lacks
int badgeTotal(SocialProfile p) =>
    GeoData.I.badges.length + p.badgeIds.toSet().where((id) => !GeoData.I.badges.containsKey(id)).length;

const _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Round badge image (bundled asset) or 🎖️ fallback. Locked = greyscale + 40% opacity.
class BadgeIcon extends StatelessWidget {
  const BadgeIcon({super.key, required this.meta, this.size = 44, this.locked = false});

  final BadgeMeta meta;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final fallback = IconTile(emoji: _categoryEmoji[meta.category] ?? '🎖️', size: size, color: AppColors.gold);
    Widget img = meta.image == null
        ? fallback
        : ClipOval(
            child: Image.asset(
              meta.image!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
          );
    img = SizedBox(width: size, height: size, child: img);
    if (!locked) return img;
    return Opacity(opacity: 0.4, child: ColorFiltered(colorFilter: _greyscale, child: img));
  }
}

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key, required this.uid});

  final String uid;

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  String? _category; // null = All

  @override
  Widget build(BuildContext context) {
    final store = SocialScope.of(context);
    final isSelf = widget.uid == store.uid;
    final p = isSelf ? store.me : store.friend(widget.uid);
    final theme = Theme.of(context);

    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Badges')),
        body: const Center(child: EmptyHint('This profile is not available yet.')),
      );
    }

    final unlocked = p.badgeIds.toSet();
    final mine = isSelf ? const <String>{} : (store.me?.badgeIds.toSet() ?? const <String>{});
    final unknown = [for (final id in unlocked) if (!GeoData.I.badges.containsKey(id)) badgeMetaFor(id)];
    final all = [...GeoData.I.badges.values, ...unknown];
    // unlocked first, catalog order otherwise
    final sorted = [
      ...all.where((b) => unlocked.contains(b.id)),
      ...all.where((b) => !unlocked.contains(b.id)),
    ];
    final shown = _category == null ? sorted : sorted.where((b) => b.category == _category).toList();
    final total = all.length;
    final rank = p.badgeRank;
    final rankImage = rankAsset(rank);

    String chipLabel(String? cat) {
      final inCat = cat == null ? all : all.where((b) => b.category == cat);
      final have = inCat.where((b) => unlocked.contains(b.id)).length;
      return '${cat == null ? 'All' : '${_categoryEmoji[cat]} $cat'} $have/${inCat.length}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelf ? 'My badges' : '${p.displayName}\'s badges', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WhiteCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          if (rankImage != null)
                            Image.asset(rankImage, width: 52, height: 52, errorBuilder: (_, _, _) => const IconTile(emoji: '🎖️', size: 52))
                          else
                            const IconTile(emoji: '🎖️', size: 52, color: AppColors.gold),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${unlocked.length} / $total unlocked',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                              Text(
                                [if (rank != null) rankLabel[rank] ?? rank, '${badgePoints(p)} points'].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(color: AppColors.darkMint, fontWeight: FontWeight.w800),
                              ),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : (unlocked.length / total).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: AppColors.line,
                            valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                          ),
                        ),
                        if (!isSelf) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            const _MineCheck(),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('= you have it too',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(color: AppColors.label)),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ChipBar(children: [
                    for (final cat in <String?>[null, ...badgeCategories])
                      ChoiceChip(
                        selected: _category == cat,
                        onSelected: (_) => setState(() => _category = cat),
                        label: Text(chipLabel(cat), maxLines: 1),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          if (shown.isEmpty)
            const SliverToBoxAdapter(child: EmptyHint('No badges here')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 96,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.74,
              ),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final b = shown[i];
                final have = unlocked.contains(b.id);
                return _BadgeCell(
                  meta: b,
                  unlocked: have,
                  mineToo: mine.contains(b.id),
                  onTap: () => showBadgeSheet(context, b, unlocked: have, ownerName: isSelf ? null : p.displayName, mineToo: mine.contains(b.id)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MineCheck extends StatelessWidget {
  const _MineCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: AppColors.mint,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(Icons.check, size: 11, color: Colors.white),
    );
  }
}

class _BadgeCell extends StatelessWidget {
  const _BadgeCell({required this.meta, required this.unlocked, required this.mineToo, required this.onTap});

  final BadgeMeta meta;
  final bool unlocked;
  final bool mineToo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
          child: Column(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(clipBehavior: Clip.none, children: [
                BadgeIcon(meta: meta, size: 56, locked: !unlocked),
                if (mineToo) const Positioned(right: -2, bottom: -2, child: _MineCheck()),
              ]),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                meta.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: unlocked ? FontWeight.w700 : FontWeight.w500,
                  color: unlocked ? AppColors.ink : AppColors.label,
                  height: 1.15,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

Future<void> showBadgeSheet(BuildContext context, BadgeMeta b, {required bool unlocked, String? ownerName, bool mineToo = false}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final status = unlocked ? '✅ Unlocked${ownerName != null ? ' by $ownerName' : ''}' : '🔒 Locked';
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BadgeIcon(meta: b, size: 120, locked: !unlocked),
              const SizedBox(height: 14),
              Text(b.name,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                if (b.level != null) Chip(avatar: const Text('🏅'), label: Text(b.level!)),
                if (b.category != null) Chip(avatar: Text(_categoryEmoji[b.category] ?? '🎖️'), label: Text(b.category!)),
                Chip(avatar: const Text('⭐'), label: Text('${b.points} pts')),
              ]),
              const SizedBox(height: 12),
              if (b.description.isNotEmpty)
                Text(b.description, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(status,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800, color: unlocked ? AppColors.darkMint : AppColors.label)),
              if (ownerName != null && mineToo)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('You have it too',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.mint, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Profile section: "87 of 645", rank, top unlocked badges, See all
class BadgesSection extends StatelessWidget {
  const BadgesSection({super.key, required this.profile});

  final SocialProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final theme = Theme.of(context);
    final rank = p.badgeRank;
    final rankImage = rankAsset(rank);
    final top = topUnlockedBadges(p);
    void open() => Navigator.push(context, socialRoute<void>((_) => BadgesScreen(uid: p.uid)));

    return SectionCard(
      emoji: '🎖️',
      title: 'Badges',
      tint: AppColors.gold,
      subtitle: '${p.badgeIds.toSet().length} of ${badgeTotal(p)} unlocked',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rank != null)
            Row(children: [
              if (rankImage != null) ...[
                Image.asset(rankImage, width: 30, height: 30, errorBuilder: (_, _, _) => const SizedBox(width: 30)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  '${rankLabel[rank] ?? rank} · ${badgePoints(p)} points',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.darkMint),
                ),
              ),
            ]),
          const SizedBox(height: 12),
          if (top.isEmpty)
            const EmptyHint('No badges yet', emoji: '🎖️')
          else
            LayoutBuilder(builder: (context, c) {
              const size = 44.0, gap = 8.0;
              final fit = ((c.maxWidth + gap) / (size + gap)).floor().clamp(1, 8);
              final shown = top.take(fit).toList();
              return Row(children: [
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                    child: GestureDetector(
                      onTap: () => showBadgeSheet(context, shown[i], unlocked: true),
                      child: Tooltip(message: shown[i].name, child: BadgeIcon(meta: shown[i], size: size)),
                    ),
                  ),
              ]);
            }),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: open,
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: const Text('See all'),
            ),
          ),
        ],
      ),
    );
  }
}
