import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          : Padding(
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

            // ── Remove Ads / Premium button ───────────────────
            Consumer<SubscriptionService>(
              builder: (context, sub, _) => GestureDetector(
                onTap: () => SubscriptionSheet.show(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3DDAD7), Color(0xFF00A39F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3DDAD7).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                                  ? 'Premium Active'
                                  : 'Remove Ads',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              sub.isPremium
                                  ? 'You are subscribed. Thank you!'
                                  : 'Go ad-free for \$9.99 / year',
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
                ),
              ),
            ),



            // ── Benefits card ─────────────────────────────────
            Consumer<SubscriptionService>(
              builder: (context, sub, _) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: sub.isPremium
                      ? const Color(0xFF3DDAD7).withOpacity(0.06)
                      : const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sub.isPremium
                        ? const Color(0xFF3DDAD7).withOpacity(0.3)
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
                              ? const Color(0xFF3DDAD7)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sub.isPremium ? 'YOUR PREMIUM BENEFITS' : 'PREMIUM BENEFITS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sub.isPremium
                                ? const Color(0xFF3DDAD7)
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
                    ),
                    const SizedBox(height: 10),
                    _ProfileBenefitRow(
                      icon: Icons.bar_chart_rounded,
                      label: 'Detailed stats for countries & cities',
                      active: sub.isPremium,
                    ),
                    const SizedBox(height: 10),
                    _ProfileBenefitRow(
                      icon: Icons.explore_rounded,
                      label: 'UNESCO map, landmark stats & more',
                      active: sub.isPremium,
                    ),
                    const SizedBox(height: 10),
                    _ProfileBenefitRow(
                      icon: Icons.analytics_outlined,
                      label: 'Airport & airline statistics',
                      active: sub.isPremium,
                    ),
                    const SizedBox(height: 10),
                    _ProfileBenefitRow(
                      icon: Icons.favorite_rounded,
                      label: 'Supporting the developer directly',
                      active: sub.isPremium,
                    ),
                  ],
                ),
              ),
            ),

            // ── Gift code card (premium only) ─────────────────
            Consumer<SubscriptionService>(
              builder: (context, sub, _) => sub.isPremium
                  ? Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFB347), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB347).withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.55),
                          children: [
                            TextSpan(
                              text: 'Get 2 free 90-day gift codes!\n',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1A1A2E)),
                            ),
                            TextSpan(text: 'Send your subscribed email + purchase screenshot to '),
                            TextSpan(
                              text: 'leeahn137@gmail.com',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3DDAD7)),
                            ),
                            TextSpan(text: ' to receive '),
                            TextSpan(
                              text: '2 free 90-day gift codes',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
                            ),
                            TextSpan(text: ' to share with friends!'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  : const SizedBox.shrink(),
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
    );
  }
}

class _ProfileBenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _ProfileBenefitRow({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF3DDAD7).withOpacity(0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 14,
            color: active ? const Color(0xFF3DDAD7) : Colors.grey.shade400,
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
          const Icon(Icons.check_rounded, size: 13, color: Color(0xFF3DDAD7)),
        ],
      ],
    );
  }
}