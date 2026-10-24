import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/geo_data.dart';
import '../models/social_profile.dart';
import '../models/stats.dart';
import '../theme.dart';
import 'charts.dart';
import 'flag.dart';
import 'avatar.dart';

/// 제목 + 내용 카드
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.emoji,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 20),
    this.tint,
  });

  final Color? tint;
  final String title;
  final String? emoji;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WhiteCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (emoji != null) ...[IconTile(emoji: emoji, size: 40, color: tint ?? AppColors.mint), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label)),
                  ],
                ),
              ),
              if (trailing != null)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: trailing),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// 칩을 한 줄로 늘어놓고 넘치면 가로로 스크롤 (여러 줄로 꺾이지 않게)
class ChipBar extends StatelessWidget {
  const ChipBar({super.key, required this.children, this.spacing = 6});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          children[i],
        ],
      ]),
    );
  }
}

/// 큰 숫자 하나
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.emoji, required this.value, required this.label, this.color, this.onTap});

  final String emoji;
  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? AppColors.mint;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(emoji: emoji, color: c, size: 36),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.ink)),
                ),
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 그리드로 StatTile 나열
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles, this.columns = 3});

  final List<Widget> tiles;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final w = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

/// 여권처럼 생긴 프로필 카드
class PassportCard extends StatelessWidget {
  const PassportCard({super.key, required this.profile, this.onTap, this.compact = false});

  final SocialProfile profile;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = ProfileStats(profile);
    final home = GeoData.I.countryByIso3(profile.homeCountryIso3);
    final rank = profile.badgeRank;
    final rankImage = rankAsset(rank);
    const white = Colors.white;

    Widget big(String v, String l) => Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(v, style: theme.textTheme.headlineSmall?.copyWith(color: white, fontWeight: FontWeight.w900)),
              ),
              Text(l,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x33A63D58), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(gradient: AppColors.tealGradient, borderRadius: BorderRadius.circular(24)),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Icon(Icons.public, size: 170, color: white.withValues(alpha: 0.08)),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: white, shape: BoxShape.circle),
                          child: UserAvatar(profile: profile, radius: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TRAVELOG PASSPORT',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: white.withValues(alpha: 0.75), letterSpacing: 2, fontWeight: FontWeight.w700)),
                              Text(profile.displayName,
                                  style: theme.textTheme.titleLarge?.copyWith(color: white, fontWeight: FontWeight.w900),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Row(
                                children: [
                                  if (home != null) ...[Flag(home.iso2, width: 18, radius: 2), const SizedBox(width: 6)],
                                  Flexible(
                                    child: Text(home?.longName ?? 'No home country',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelMedium?.copyWith(color: white.withValues(alpha: 0.9))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (rankImage != null)
                          Column(
                            children: [
                              Image.asset(rankImage, width: 46, height: 46),
                              Text(rankLabel[rank] ?? rank!,
                                  maxLines: 1,
                                  style: theme.textTheme.labelSmall?.copyWith(color: white, fontWeight: FontWeight.w700)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        big('${profile.countryCount}', 'Countries'),
                        big('${stats.continentCount}', 'Continents'),
                        big(compactNumber(profile.cityCount), 'Cities'),
                        big(compactNumber(profile.landmarkCount), 'Landmarks'),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: stats.worldPercent,
                          minHeight: 8,
                          backgroundColor: white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation(white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(stats.worldPercent * 100).toStringAsFixed(1)}% of the world · '
                        '${(stats.areaPercent * 100).toStringAsFixed(0)}% of land · '
                        '${(stats.populationPercent * 100).toStringAsFixed(0)}% of people',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(color: white.withValues(alpha: 0.95)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// 랜드마크 사진 (Travelog와 같은 Storage 경로). 없으면 그라데이션 + 이모지.
class LandmarkImage extends StatelessWidget {
  /// 테스트에서 네트워크 이미지를 끄는 스위치
  static bool offline = false;

  const LandmarkImage({super.key, required this.name, this.height = 120, this.radius = 16});

  final String name;
  final double height;
  final double radius;

  static String slug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r"['’`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');

  static const _base = 'https://firebasestorage.googleapis.com/v0/b/proboscis-2025.firebasestorage.app/o/';

  /// build_assets.py가 Storage 목록과 맞춰 둔 정확한 경로 하나만 쓴다.
  /// 사진이 없는 랜드마크는 네트워크 요청 없이 바로 대체 그림.
  static List<String> candidates(String name) {
    final path = GeoData.I.landmarks[name]?.imagePath;
    if (path == null) return const [];
    return ['$_base${Uri.encodeComponent(path)}?alt=media'];
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(height: height, width: double.infinity, child: _Fallback(urls: candidates(name), name: name)),
    );
  }
}

class _Fallback extends StatefulWidget {
  const _Fallback({required this.urls, required this.name});

  final List<String> urls;
  final String name;

  @override
  State<_Fallback> createState() => _FallbackState();
}

class _FallbackState extends State<_Fallback> {
  int _index = 0;

  Widget _placeholder(BuildContext context) {
    final meta = GeoData.I.landmarks[widget.name];
    final country = GeoData.I.countryByIso3(meta?.iso3);
    final hue = (widget.name.hashCode % 360).abs().toDouble();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor(), HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.4).toColor()],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: country?.iso2 != null ? Opacity(opacity: 0.85, child: Flag(country!.iso2, width: 44)) : const Text('🗺️', style: TextStyle(fontSize: 34)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (LandmarkImage.offline || _index >= widget.urls.length) return _placeholder(context);
    return CachedNetworkImage(
      key: ValueKey(widget.urls[_index]),
      imageUrl: widget.urls[_index],
      fit: BoxFit.cover,
      placeholder: (context, _) => _placeholder(context),
      errorWidget: (context, url, error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && url == widget.urls[_index]) setState(() => _index++);
        });
        return _placeholder(context);
      },
    );
  }
}

/// 사진 + 이름 카드 (가로 스크롤 목록용)
class LandmarkCard extends StatelessWidget {
  const LandmarkCard({super.key, required this.name, this.badgeColor, this.badge, this.width = 160});

  final String name;
  final Color? badgeColor;
  final String? badge;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = GeoData.I.landmarks[name];
    final country = GeoData.I.countryByIso3(meta?.iso3);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              LandmarkImage(name: name, height: width * 0.72),
              if (badge != null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: badgeColor ?? AppColors.both, borderRadius: BorderRadius.circular(8)),
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (meta != null && meta.rank > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Text('#${meta.rank}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          Row(
            children: [
              if (country != null) ...[Flag(country.iso2, width: 16, radius: 2), const SizedBox(width: 4)],
              Expanded(
                child: Text(
                  [meta?.city, country?.longName].whereType<String>().join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 가로 스크롤 카드 줄
class HorizontalCards extends StatelessWidget {
  const HorizontalCards({super.key, required this.children, this.height = 190});

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

/// 나 vs 친구 범례
class VsLegend extends StatelessWidget {
  const VsLegend({super.key, required this.friendName, this.showBoth = true});

  final String friendName;
  final bool showBoth;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String l) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
            ),
          ],
        );
    return Wrap(spacing: 14, runSpacing: 4, children: [
      dot(AppColors.me, 'You'),
      dot(AppColors.friend, friendName),
      if (showBoth) dot(AppColors.both, 'Both'),
    ]);
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.emoji = '🫥'});

  final String text;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.label)),
        ],
      ),
    );
  }
}

/// 재미있는 사실 한 줄
class FactTile extends StatelessWidget {
  const FactTile({super.key, required this.emoji, required this.text, this.color});

  final String emoji;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? AppColors.mint).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// 별점 표시
class Stars extends StatelessWidget {
  const Stars(this.rating, {super.key, this.size = 14, this.color = AppColors.gold});

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i ? Icons.star_rounded : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: color,
          ),
      ],
    );
  }
}

/// 국가 정보 바텀시트 (지도에서 탭)
Future<void> showCountrySheet(
  BuildContext context,
  CountryMeta c, {
  SocialProfile? me,
  SocialProfile? friend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      Widget who(SocialProfile p, Color color) {
        final visited = p.countries.contains(c.name);
        final info = p.countryInfo[c.name];
        final wish = p.countryWish.contains(c.name);
        final cities = ProfileStats(p).citiesByCountry[c.iso3] ?? 0;
        return Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(visited ? (info?.lived == true ? '🏠 Lived here' : '✅ Visited') : (wish ? '💭 On wishlist' : 'Not yet')),
                if (visited && (info?.visits ?? 0) > 1) Text('${info!.visits} visits', style: theme.textTheme.labelSmall),
                if (visited && info?.firstYear != null) Text('First in ${info!.firstYear}', style: theme.textTheme.labelSmall),
                if (cities > 0) Text(cities == 1 ? '1 city' : '$cities cities', style: theme.textTheme.labelSmall),
                if ((info?.rating ?? 0) > 0) Stars(info!.rating),
              ],
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flag(c.iso2, width: 48, radius: 6),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.longName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      Text('${continentEmoji[c.continent] ?? ''} ${continentLabel(c.continent)} · ${c.subregion ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.label)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (c.capital != null) Chip(avatar: const Text('🏛️'), label: Text(c.capital!)),
              if (c.population != null) Chip(avatar: const Text('👥'), label: Text(compactNumber(c.population!))),
              if (c.area != null) Chip(avatar: const Text('📐'), label: Text('${compactNumber(c.area!)} km²')),
            ]),
            if (me != null) ...[
              const SizedBox(height: 12),
              Row(children: [who(me, AppColors.me), if (friend != null) ...[const SizedBox(width: 10), who(friend, AppColors.friend)]]),
            ],
          ],
        ),
      );
    },
  );
}
