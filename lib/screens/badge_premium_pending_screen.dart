// lib/screens/badge_premium_pending_screen.dart
//
// "조건은 다 채웠지만 프리미엄 미구독이라 실제로는 못 받은" 순간 전용 팝업.
// BadgeCollectedScreen(정상 해금 축하)과 짝을 이루는 화면 — 여기서는 축하 대신
// "이미 다 했는데 구독만 하면 바로 받는다"는 손실회피 심리를 자극해서 전환시킨다.
// main.dart(또는 뱃지 체크가 끝나는 지점)에서 badgeProvider.newlyPendingPremiumClaim이
// 비어있지 않으면 이 화면을 띄우고, dismiss될 때 markPremiumClaimPromptSeen을 호출한다.

import 'package:flutter/material.dart';
import 'package:jidoapp/models/badge_model.dart';
import 'package:jidoapp/widgets/subscription_sheet.dart';
import 'package:jidoapp/widgets/premium_badge_shimmer.dart';
import 'package:jidoapp/widgets/firebase_badge_image.dart';

class BadgePremiumPendingScreen extends StatelessWidget {
  final Achievement achievement;

  const BadgePremiumPendingScreen({
    Key? key,
    required this.achievement,
  }) : super(key: key);

  Color _categoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.Country:
        return Colors.teal;
      case AchievementCategory.City:
        return Colors.orange;
      case AchievementCategory.Flight:
        return Colors.blue;
      case AchievementCategory.Landmarks:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(achievement.category);
    const goldColor = Color(0xFFFFC107);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.only(left: 20, top: 40, right: 20, bottom: 20),
            margin: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, offset: Offset(0, 10), blurRadius: 10),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    "BADGE COMPLETE!",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: goldColor,
                      letterSpacing: 1.5,
                      shadows: const [
                        Shadow(color: Colors.black12, offset: Offset(1, 1), blurRadius: 2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "You've met every requirement — subscribe to claim it.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  // 뱃지 이미지 — 컬러↔흑백 반짝임
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                      border: Border.all(color: goldColor, width: 3),
                    ),
                    child: ClipOval(
                      child: PremiumBadgeShimmer(
                        child: FirebaseBadgeImage(
                          imagePath: achievement.imagePath,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    achievement.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    achievement.description,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        SubscriptionSheet.show(context, triggerContext: 'badge_moment_claim');
                      },
                      icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goldColor,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      label: const Text(
                        "Subscribe to Claim",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      "Not now",
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 30,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}