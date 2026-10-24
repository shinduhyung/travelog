import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../data/geo_data.dart';
import '../theme.dart';

/// 국기. country_flags SVG를 쓰고, 모르는 코드면 이모지/빈 칸.
class Flag extends StatelessWidget {
  const Flag(this.iso2, {super.key, this.width = 28, this.radius = 4});

  /// 나라 이름(Travelog 키)으로 국기
  factory Flag.ofCountry(String name, {Key? key, double width = 28, double radius = 4}) =>
      Flag(GeoData.I.countryByName(name)?.iso2, key: key, width: width, radius: radius);

  final String? iso2;
  final double width;
  final double radius;

  static final _valid = RegExp(r'^[A-Z]{2}$');

  @override
  Widget build(BuildContext context) {
    final height = width * 0.7;
    final code = iso2?.toUpperCase();
    if (code == null || !_valid.hasMatch(code)) {
      return SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(child: Text('🏳️', style: TextStyle(fontSize: height * 0.6))),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: CountryFlag.fromCountryCode(
        code,
        theme: ImageTheme(width: width, height: height, shape: RoundedRectangle(radius)),
      ),
    );
  }
}

/// 국기 + 나라 이름 칩
class CountryChip extends StatelessWidget {
  const CountryChip(this.name, {super.key, this.color, this.trailing, this.onTap});

  final String name; // Travelog 키
  final Color? color;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = GeoData.I.countryByName(name);
    final theme = Theme.of(context);
    final bg = color?.withValues(alpha: 0.12) ?? AppColors.background;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flag(meta?.iso2, width: 22, radius: 3),
              const SizedBox(width: 6),
              Flexible(
                child: Text(meta?.longName ?? name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                Text(trailing!, maxLines: 1, style: theme.textTheme.labelSmall?.copyWith(color: AppColors.label)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 국기를 촘촘히 깐 그리드 (국기 컬렉션)
class FlagWall extends StatelessWidget {
  const FlagWall({super.key, required this.names, this.size = 34, this.highlight});

  final List<String> names;
  final double size;
  final Color? Function(String name)? highlight;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final n in names)
          Tooltip(
            message: GeoData.I.countryByName(n)?.longName ?? n,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: highlight?.call(n) ?? Colors.transparent, width: 2),
              ),
              child: Flag.ofCountry(n, width: size),
            ),
          ),
      ],
    );
  }
}
