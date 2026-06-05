// lib/utils/premium_access_manager.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/services/subscription_service.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';

class PremiumAccessManager {
  /// 페이월(구독 시스템)이 공식적으로 도입된 날짜 (예: 2026년 5월 26일)
  static final DateTime paywallIntroDate = DateTime(2026, 5, 26);

  static bool hasAccess(BuildContext context) {
    // TODO: 테스트용 — 완료 후 아래 주석 제거하고 원래 로직 복원
    return SubscriptionService.instance.isPremium;

    // ↓↓↓ 원래 로직 (테스트 후 위 return 제거하고 아래 복원) ↓↓↓
    // if (SubscriptionService.instance.isPremium) {
    //   return true;
    // }
    // final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // final user = authProvider.user;
    // if (user != null && user.metadata.creationTime != null) {
    //   if (user.metadata.creationTime!.isBefore(paywallIntroDate)) {
    //     final expirationDate = paywallIntroDate.add(const Duration(days: 365));
    //     if (DateTime.now().isBefore(expirationDate)) {
    //       return true;
    //     }
    //   }
    // }
    // return false;
  }

  /// 권한 체크 후, 권한이 없으면 결제창을 띄우는 편의 메서드
  static void requirePremium(BuildContext context, VoidCallback onGranted) {
    if (hasAccess(context)) {
      onGranted();
    } else {
      SubscriptionSheet.show(context);
    }
  }
}