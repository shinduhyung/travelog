import 'package:flutter/material.dart';

import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/services/rewarded_unlock_service.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

/// Shows [child] unless this statistic is locked for the current user.
/// A locked statistic renders [StatLockedPromo] in its place instead.
///
/// [locked] is the static rule ("not the first metric of this card");
/// premium subscribers and rewarded-video unlocks are resolved here.
class StatLockGuard extends StatelessWidget {
  final String statKey;
  final bool locked;
  final Widget child;

  const StatLockGuard({
    super.key,
    required this.statKey,
    required this.locked,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return ListenableBuilder(
      listenable: Listenable.merge([
        SubscriptionService.instance,
        RewardedUnlockService.instance,
      ]),
      builder: (context, _) {
        if (RewardedUnlockService.instance.isUnlocked(statKey)) return child;
        return StatLockedPromo(statKey: statKey);
      },
    );
  }
}

/// Subscription pitch with a rewarded-video option right below it.
class StatLockedPromo extends StatefulWidget {
  final String statKey;

  const StatLockedPromo({super.key, required this.statKey});

  @override
  State<StatLockedPromo> createState() => _StatLockedPromoState();
}

class _StatLockedPromoState extends State<StatLockedPromo> {
  static const Color _brand = Color(0xFF1ABFBC);
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    RewardedUnlockService.instance.preload();
  }

  Future<void> _watch() async {
    if (_showing) return;
    setState(() => _showing = true);
    final result = await RewardedUnlockService.instance.watchToUnlock(
      widget.statKey,
    );
    if (!mounted) return;
    setState(() => _showing = false);
    if (result == RewardedUnlockResult.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('The video is not ready yet. Please try again in a moment.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _brand.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock_rounded, color: _brand, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    tr('Premium statistic'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('Subscribe to Travelog Premium to see every ranking.'),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => SubscriptionSheet.show(
                        context,
                        triggerContext: 'stat_lock',
                      ),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: Text(tr('Go Premium')),
                    ),
                  ),
                ],
              ),
            ),
            if (RewardedUnlockService.isSupported) ...[
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: RewardedUnlockService.instance,
                builder: (context, _) {
                  final ready = RewardedUnlockService.instance.isReady;
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brand,
                        side: const BorderSide(color: _brand, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: (ready && !_showing) ? _watch : null,
                      icon: (_showing || !ready)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_circle_fill_rounded),
                      label: Text(
                        tr('Watch a video to unlock this for now'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
