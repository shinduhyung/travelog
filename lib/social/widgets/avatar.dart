import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../data/geo_data.dart';
import '../models/social_profile.dart';
import '../theme.dart';

/// 유료 등급별 테두리 색
class PlanStyle {
  const PlanStyle(this.label, this.colors, this.glow);

  final String label;
  final List<Color> colors;
  final Color? glow;

  static const _styles = {
    'lifetime': PlanStyle('Lifetime', [Color(0xFFA855F7), Color(0xFF7C3AED), Color(0xFFC084FC)], Color(0xFF8B5CF6)),
    'yearly': PlanStyle('Yearly', [Color(0xFFFCD34D), Color(0xFFF59E0B), Color(0xFFFDE68A)], Color(0xFFF5B301)),
    'monthly': PlanStyle('Monthly', [Color(0xFF5EEAD4), Color(0xFF00CDB5), Color(0xFF99F6E4)], Color(0xFF00CDB5)),
  };

  static const none = PlanStyle('Free', [Color(0xFFE5E7EB), Color(0xFFE5E7EB)], null);

  static PlanStyle of(String plan) => _styles[plan] ?? none;

  static Iterable<MapEntry<String, PlanStyle>> get paid => _styles.entries;
}

/// 프로필 사진 = 홈 국가 국기 (동그랗게). 유료 회원은 등급 색 테두리 + 은은한 빛.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.profile, this.radius = 22});

  final SocialProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = PlanStyle.of(profile.plan);
    final ring = (radius * 0.14).clamp(2.0, 5.0);
    final iso2 = GeoData.I.countryByIso3(profile.homeCountryIso3)?.iso2;
    final size = radius * 2;

    final Widget inner = iso2 != null && RegExp(r'^[A-Z]{2}$').hasMatch(iso2)
        ? CountryFlag.fromCountryCode(iso2, theme: ImageTheme(width: size, height: size, shape: const Circle()))
        : CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.mint.withValues(alpha: 0.18),
            child: Text(
              profile.displayName.isEmpty ? '?' : profile.displayName.characters.first.toUpperCase(),
              style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w800, color: AppColors.darkMint),
            ),
          );

    return Container(
      width: size + ring * 2 + 2,
      height: size + ring * 2 + 2,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [...style.colors, style.colors.first]),
        boxShadow: style.glow == null
            ? null
            : [BoxShadow(color: style.glow!.withValues(alpha: 0.55), blurRadius: radius * 0.7, spreadRadius: 1)],
      ),
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: ClipOval(child: SizedBox(width: size, height: size, child: inner)),
      ),
    );
  }
}

/// 등급 작은 배지 (이름 옆)
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key, required this.plan});

  final String plan;

  @override
  Widget build(BuildContext context) {
    if (plan == 'none') return const SizedBox.shrink();
    final style = PlanStyle.of(plan);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: style.colors.take(2).toList()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        style.label.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6),
      ),
    );
  }
}
