import 'package:flutter/material.dart';
import 'package:jidoapp/services/ad_service.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';
import 'package:jidoapp/widgets/premium_theme.dart';
import 'package:jidoapp/screens/countries_share.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSharing = false;
  final ScreenshotController _mapScreenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    AdService.instance.setUiOverlayActive();
  }

  @override
  void dispose() {
    AdService.instance.clearUiOverlayActive();
    super.dispose();
  }

  Future<void> _handleShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final provider = context.read<CountryProvider>();
      final visitedCountries = provider.allCountries
          .where((c) => provider.visitedCountries.contains(c.name))
          .toList();

      // 화면에 렌더링된 invisible map을 .capture()로 찍기
      // (captureFromWidget은 Impeller/Vulkan에서 동작 안 함)
      final Uint8List? mapImage = await _mapScreenshotController.capture();

      if (!mounted) return;
      await CountriesShare.share(
        context: context,
        mapImage: mapImage ?? Uint8List(0),
        visitedCountries: visitedCountries,
      );
    } catch (e) {
      debugPrint('Profile share error: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("Not Logged In"))
          : Consumer<CountryProvider>(
        builder: (context, countryProvider, _) {
          return Stack(
            children: [
              // invisible map: 화면 밖(-9999)에 렌더링해두고 캡처
              Positioned(
                left: -9999,
                top: 0,
                width: 600,
                height: 300,
                child: Screenshot(
                  controller: _mapScreenshotController,
                  child: IgnorePointer(
                    child: FlutterMap(
                      options: const MapOptions(
                        initialCenter: LatLng(20, 0),
                        initialZoom: 0.3,
                        interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(urlTemplate: '', backgroundColor: Colors.white),
                        PolygonLayer(
                          polygons: countryProvider.allCountries.expand((country) {
                            final isVisited = countryProvider.visitedCountries.contains(country.name);
                            final color = isVisited
                                ? (countryProvider.continentColors[country.continent] ?? Colors.grey)
                                : Colors.grey.withOpacity(0.15);
                            return country.polygonsData.map((polygonData) => Polygon(
                              points: polygonData.first,
                              holePointsList: polygonData.length > 1 ? polygonData.sublist(1) : null,
                              color: color,
                              borderColor: Colors.white,
                              borderStrokeWidth: 0.5,
                              isFilled: true,
                            ));
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 실제 profile 콘텐츠
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: user.photoURL != null
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: user.photoURL == null
                              ? const Icon(Icons.person,
                              size: 50, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        user.displayName ?? 'Traveler',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── Unlock All Features / Premium button ───────────────────
                      Consumer<SubscriptionService>(
                        builder: (context, sub, _) {
                          final kind = sub.activePlanKind;
                          // 비구독자한테는 추천 플랜(yearly) 톤으로 초대장을 보여줌.
                          final colors = sub.isPremium
                              ? PremiumTheme.colorsFor(kind)
                              : PremiumTheme.yearly;
                          final bool vivid = sub.isPremium && PremiumTheme.isVivid(kind);

                          final Widget content = Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.workspace_premium_rounded,
                                    color: Colors.white, size: 26),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sub.isPremium
                                            ? (kind == PremiumPlanKind.lifetime
                                            ? 'Lifetime Premium'
                                            : 'Premium Active')
                                            : 'Unlock All Features & Ad-Free',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        sub.isPremium
                                            ? 'You are subscribed. Thank you!'
                                            : (sub.productDetailsFor(sub.yearlyProductIdToOffer) != null
                                            ? 'Go ad-free for ${sub.productDetailsFor(sub.yearlyProductIdToOffer)!.price} / year'
                                            : 'Go ad-free'),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  sub.isPremium
                                      ? Icons.check_circle_rounded
                                      : Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: sub.isPremium ? 22 : 14,
                                ),
                              ],
                            ),
                          );

                          final Widget banner = vivid
                              ? PremiumGradientBorder(
                            colors: colors,
                            animated: true,
                            borderWidth: 2.5,
                            borderRadius: 18,
                            child: content,
                          )
                              : content;

                          return GestureDetector(
                            onTap: () => SubscriptionSheet.show(context, triggerContext: 'profile'),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(vivid ? 18 : 16),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors[0].withOpacity(vivid ? 0.4 : 0.3),
                                    blurRadius: vivid ? 20 : 12,
                                    offset: const Offset(0, 4),
                                  ),
                                  if (vivid)
                                    BoxShadow(
                                      color: colors.last.withOpacity(0.3),
                                      blurRadius: 26,
                                      offset: const Offset(0, 8),
                                    ),
                                ],
                              ),
                              child: banner,
                            ),
                          );
                        },
                      ),

                      // ── Benefits card ─────────────────────────────────
                      Consumer<SubscriptionService>(
                        builder: (context, sub, _) {
                          final colors = sub.isPremium
                              ? PremiumTheme.colorsFor(sub.activePlanKind)
                              : null;
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: sub.isPremium
                                  ? colors![0].withOpacity(0.06)
                                  : const Color(0xFFF8F9FC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: sub.isPremium
                                    ? colors![0].withOpacity(0.3)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      sub.isPremium
                                          ? Icons.check_circle_rounded
                                          : Icons.workspace_premium_rounded,
                                      size: 14,
                                      color: sub.isPremium
                                          ? colors![0]
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      sub.isPremium ? 'YOUR PREMIUM BENEFITS' : 'ALL FEATURES & AD-FREE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: sub.isPremium
                                            ? colors![0]
                                            : Colors.grey,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _ProfileBenefitRow(
                                  icon: Icons.block_rounded,
                                  label: 'No interstitial & banner ads',
                                  active: sub.isPremium,
                                  activeColor: colors?[0],
                                ),
                                const SizedBox(height: 10),
                                _ProfileBenefitRow(
                                  icon: Icons.bar_chart_rounded,
                                  label: 'Detailed stats for countries & cities',
                                  active: sub.isPremium,
                                  activeColor: colors?[0],
                                ),
                                const SizedBox(height: 10),
                                _ProfileBenefitRow(
                                  icon: Icons.explore_rounded,
                                  label: 'UNESCO map, landmark stats & more',
                                  active: sub.isPremium,
                                  activeColor: colors?[0],
                                ),
                                const SizedBox(height: 10),
                                _ProfileBenefitRow(
                                  icon: Icons.analytics_outlined,
                                  label: 'Airport & airline statistics',
                                  active: sub.isPremium,
                                  activeColor: colors?[0],
                                ),
                                const SizedBox(height: 10),
                                _ProfileBenefitRow(
                                  icon: Icons.favorite_rounded,
                                  label: 'Supporting the developer directly',
                                  active: sub.isPremium,
                                  activeColor: colors?[0],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // ── Lifetime upgrade upsell (subscriber, not yet lifetime) ─
                      Consumer<SubscriptionService>(
                        builder: (context, sub, _) {
                          if (!sub.isPremium || sub.isLifetime) {
                            return const SizedBox.shrink();
                          }
                          final lifetime = sub.productDetailsFor(SubscriptionService.kLifetimeId);
                          final colors = PremiumTheme.lifetime;
                          return GestureDetector(
                            onTap: () => SubscriptionSheet.show(context, triggerContext: 'profile_lifetime_upsell'),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors[0].withOpacity(0.45),
                                    blurRadius: 22,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 6),
                                  ),
                                  BoxShadow(
                                    color: colors.last.withOpacity(0.35),
                                    blurRadius: 28,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: PremiumGradientBorder(
                                colors: colors,
                                animated: true,
                                borderWidth: 2.5,
                                borderRadius: 18,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: colors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Go Lifetime',
                                              style: TextStyle(
                                                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              lifetime != null
                                                  ? 'Pay ${lifetime.price} once — never renew again'
                                                  : 'Pay once — never renew again',
                                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.arrow_forward_rounded, size: 18, color: colors[0]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // ── Log Out button ────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () async {
                            await authProvider.signOut();
                            if (context.mounted) {
                              Navigator.popUntil(context, (route) => route.isFirst);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),  // SingleChildScrollView
            ],  // Stack children
          );  // Stack
        },  // Consumer builder
      ),  // Consumer
    );
  }
}

class _ProfileBenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? activeColor;

  const _ProfileBenefitRow({
    required this.icon,
    required this.label,
    required this.active,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = activeColor ?? const Color(0xFF3DDAD7);
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active
                ? color.withOpacity(0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 14,
            color: active ? color : Colors.grey.shade400,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? const Color(0xFF2C3E50) : Colors.grey.shade400,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
        if (active) ...[
          const SizedBox(width: 6),
          Icon(Icons.check_rounded, size: 13, color: color),
        ],
      ],
    );
  }
}