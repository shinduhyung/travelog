import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/geo_data.dart';
import '../models/social_profile.dart';
import '../models/stats.dart';
import '../theme.dart';
import 'cards.dart';
import 'world_map.dart';

enum ProfileMapMode { countries, cities, landmarks }

/// 프로필 화면의 지도: 나라 / 도시 / 랜드마크 모드 + "횟수로 음영" 스위치
class ProfileMaps extends StatefulWidget {
  const ProfileMaps({super.key, required this.profile, this.viewerMe});

  /// 지도에 그릴 사람
  final SocialProfile profile;

  /// 지금 보고 있는 사람(나). 나라 시트에서 비교용으로 쓴다.
  final SocialProfile? viewerMe;

  static const _lightMint = Color(0xFFCCF5F0);
  static const _lightPurple = Color(0xFFE9DDFE);

  /// 1..max 를 연한색 → 진한색으로
  static Color shade(int count, int max, {Color from = _lightMint, Color to = AppColors.darkMint}) {
    if (max <= 1) return to;
    final t = ((count.clamp(1, max) - 1) / (max - 1)).toDouble();
    return Color.lerp(from, to, t)!;
  }

  @override
  State<ProfileMaps> createState() => _ProfileMapsState();
}

class _ProfileMapsState extends State<ProfileMaps> {
  ProfileMapMode _mode = ProfileMapMode.countries;
  bool _shade = false;

  static const _landmarkColor = AppColors.friend;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final s = ProfileStats(p);
    final theme = Theme.of(context);
    final isFriend = widget.viewerMe == null || widget.viewerMe!.uid != p.uid;

    Color? Function(CountryMeta) colorFor;
    List<MapDot> dots = const [];
    Widget legend;

    switch (_mode) {
      case ProfileMapMode.countries:
        final visited = p.countries.toSet();
        final lived = p.livedCountries.toSet();
        if (_shade) {
          const max = 5;
          colorFor = (c) {
            if (!visited.contains(c.name)) return null;
            final v = math.max(1, p.countryInfo[c.name]?.visits ?? 1);
            return ProfileMaps.shade(v, max);
          };
          legend = _GradientLegend(max: max, unit: 'visits');
        } else {
          colorFor = (c) => lived.contains(c.name)
              ? AppColors.darkMint
              : visited.contains(c.name)
                  ? AppColors.mint
                  : null;
          legend = MapLegend(items: [
            (AppColors.mint, 'Visited ${p.countryCount}'),
            (AppColors.darkMint, 'Lived ${lived.length}'),
          ]);
        }
      case ProfileMapMode.cities:
        final by = s.citiesByCountry;
        final max = by.values.fold(0, math.max).clamp(1, 10);
        dots = [for (final c in s.cityMetas) MapDot(c.lat, c.lng, _shade ? AppColors.indigo : AppColors.mint, radius: 2.2)];
        if (_shade) {
          colorFor = (c) {
            final n = by[c.iso3] ?? 0;
            return n == 0 ? null : ProfileMaps.shade(n, max);
          };
          legend = _GradientLegend(max: max, unit: 'cities');
        } else {
          colorFor = (_) => null;
          legend = MapLegend(items: [(AppColors.mint, 'Cities ${p.cityCount}')]);
        }
      case ProfileMapMode.landmarks:
        final by = <String, int>{};
        for (final l in s.landmarkMetas) {
          final iso3 = l.iso3;
          if (iso3 != null) by[iso3] = (by[iso3] ?? 0) + 1;
        }
        final max = by.values.fold(0, math.max).clamp(1, 10);
        dots = [for (final l in s.landmarkMetas) MapDot(l.lat, l.lng, _landmarkColor, radius: 2.4)];
        if (_shade) {
          colorFor = (c) {
            final n = by[c.iso3] ?? 0;
            return n == 0 ? null : ProfileMaps.shade(n, max, from: ProfileMaps._lightPurple, to: const Color(0xFF6D28D9));
          };
          legend = _GradientLegend(
            max: max,
            unit: 'landmarks',
            from: ProfileMaps._lightPurple,
            to: const Color(0xFF6D28D9),
          );
        } else {
          colorFor = (_) => null;
          legend = MapLegend(items: [(_landmarkColor, 'Landmarks ${p.landmarkCount}')]);
        }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ProfileMapMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ProfileMapMode.countries, label: _SegLabel('Countries')),
              ButtonSegment(value: ProfileMapMode.cities, label: _SegLabel('Cities')),
              ButtonSegment(value: ProfileMapMode.landmarks, label: _SegLabel('Landmarks')),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
        ),
        const SizedBox(height: 12),
        WorldMap(
          colorFor: colorFor,
          dots: dots,
          onTapCountry: (c) => showCountrySheet(
            context,
            c,
            me: widget.viewerMe ?? p,
            friend: isFriend && widget.viewerMe != null ? p : null,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: legend),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Shade by count',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _shade = !_shade),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'By count',
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 40,
                      height: 24,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Switch(
                          value: _shade,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => setState(() => _shade = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SegLabel extends StatelessWidget {
  const _SegLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, softWrap: false));
}

/// "1 ▬▬▬ N+" 그라데이션 범례
class _GradientLegend extends StatelessWidget {
  const _GradientLegend({
    required this.max,
    required this.unit,
    this.from = ProfileMaps._lightMint,
    this.to = AppColors.darkMint,
  });

  final int max;
  final String unit;
  final Color from;
  final Color to;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.label, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('1', style: style),
            const SizedBox(width: 6),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: LinearGradient(colors: [from, to]),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(max > 1 ? '$max+' : '$max', style: style),
          ],
        ),
        Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ],
    );
  }
}
