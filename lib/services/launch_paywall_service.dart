import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show navigatorKey, isOnboardingActive;
import '../widgets/subscription_sheet.dart';
import 'subscription_service.dart';

/// Shows the paywall once on the first day the user reaches the main screen
/// (right after onboarding/login), then at most once per calendar day on the
/// first app open. Always dismissible (the sheet has a close button / swipe).
class LaunchPaywallService {
  LaunchPaywallService._();
  static final LaunchPaywallService instance = LaunchPaywallService._();

  static const _prefLastDay = 'launch_paywall_last_day';
  static const _delay = Duration(milliseconds: 1800);

  bool _checkedThisProcess = false;

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Call when the main screen is first shown. Safe to call repeatedly —
  /// only the first call per app process does anything.
  Future<void> maybeShow() async {
    if (_checkedThisProcess) return;
    _checkedThisProcess = true;

    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final last = prefs.getString(_prefLastDay);
    if (last == today) return;

    // Let the home screen settle (and any restore update the premium flag).
    await Future.delayed(_delay);

    if (SubscriptionService.instance.isPremium) return;
    if (isOnboardingActive) {
      _checkedThisProcess = false; // try again once onboarding ends
      return;
    }
    final nav = navigatorKey.currentState;
    final ctx = navigatorKey.currentContext;
    if (nav == null || ctx == null || !ctx.mounted) return;
    // Don't stack on top of another screen, dialog or sheet.
    if (nav.canPop()) return;

    await prefs.setString(_prefLastDay, today);
    if (!ctx.mounted) return;
    await SubscriptionSheet.show(
      ctx,
      triggerContext: last == null ? 'launch_first' : 'launch_daily',
    );
  }
}
