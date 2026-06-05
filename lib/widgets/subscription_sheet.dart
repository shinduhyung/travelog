import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/screens/countries_share.dart';
import 'package:screenshot/screenshot.dart';

class SubscriptionSheet extends StatefulWidget {
  final VoidCallback? onShareTap;

  const SubscriptionSheet({super.key, this.onShareTap});

  static Future<void> show(BuildContext context, {VoidCallback? onShareTap}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriptionSheet(onShareTap: onShareTap),
    );
  }

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
  bool _isSharing = false;

  Future<void> _handleShareTap() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    widget.onShareTap?.call();
    // 짧은 딜레이 후 로딩 해제 (실제 완료는 caller가 처리)
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isSharing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionService>(
      builder: (context, sub, _) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // App logo
                Image.asset(
                  'assets/icons/app_logo_large.png',
                  height: 64,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.workspace_premium_rounded,
                    size: 64,
                    color: Color(0xFF3DDAD7),
                  ),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Travelog Premium',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  sub.isPremium
                      ? 'You are subscribed to Premium ✓'
                      : 'Enjoy Travelog without any ads',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Benefits
                const _BenefitRow(icon: Icons.block_rounded, label: 'Remove all interstitial & banner ads'),
                const SizedBox(height: 10),
                const _BenefitRow(icon: Icons.bar_chart_rounded, label: 'Detailed stats for countries & cities'),
                const SizedBox(height: 10),
                const _BenefitRow(icon: Icons.explore_rounded, label: 'UNESCO map, landmark stats & more'),
                const SizedBox(height: 10),
                const _BenefitRow(icon: Icons.analytics_outlined, label: 'Airport & airline statistics'),
                const SizedBox(height: 10),
                const _BenefitRow(icon: Icons.favorite_rounded, label: 'Directly support the developer'),
                const SizedBox(height: 22),

                // Price
                if (!sub.isPremium)
                  Text(
                    sub.productDetails != null ? '${sub.productDetails!.price} / year' : '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
                  ),
                const SizedBox(height: 14),

                // Subscribe / Active button
                if (sub.isPremium)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3DDAD7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF3DDAD7)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF3DDAD7), size: 20),
                        SizedBox(width: 8),
                        Text('Premium Active', style: TextStyle(color: Color(0xFF3DDAD7), fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: sub.isLoading
                          ? null
                          : () async {
                        final success = await sub.buySubscription();
                        if (success && context.mounted) Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3DDAD7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: sub.isLoading
                          ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                          : const Text('Subscribe Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                // Promo: Instagram / Facebook (비구독자만)
                if (!sub.isPremium) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFFB347).withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🎁', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(fontSize: 13, color: Color(0xFF444444), height: 1.5),
                                  children: [
                                    TextSpan(text: 'Try 30 days for FREE!\n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1A2E))),
                                    TextSpan(text: 'Post your map on '),
                                    TextSpan(text: 'Instagram', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE1306C))),
                                    TextSpan(text: ' or '),
                                    TextSpan(text: 'Facebook', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1877F2))),
                                    TextSpan(text: ' and send a screenshot to '),
                                    TextSpan(text: 'leeahn137@gmail.com', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3DDAD7))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.onShareTap != null) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _handleShareTap,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFB347), width: 1.2),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFFFFB347).withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _isSharing
                                      ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB347))),
                                  )
                                      : const Icon(Icons.share_rounded, size: 18, color: Color(0xFFFFB347)),
                                  const SizedBox(width: 8),
                                  const Text('Share My Map', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFFB347))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF3DDAD7).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF3DDAD7)),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF444444))),
      ],
    );
  }
}