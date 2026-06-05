import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:jidoapp/models/badge_model.dart';

class BadgeShare {
  static Future<void> share({
    required BuildContext context,
    required Achievement achievement,
    required double progress,
    required String progressDetailText,
  }) async {
    final controller = ScreenshotController();

    try {
      // 보이지 않는 상태에서 위젯을 렌더링하여 캡처 (비율을 높여 고화질로 캡처)
      final Uint8List imageBytes = await controller.captureFromWidget(
        _buildShareWidget(achievement, progress, progressDetailText),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3.0,
        context: context,
      );

      // 임시 폴더에 이미지 파일 생성
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/badge_${achievement.id}.png').create();
      await imagePath.writeAsBytes(imageBytes);

      // 공유 실행
      final String shareText = achievement.isUnlocked
          ? 'I just unlocked the "${achievement.name}" badge on Travelog! 🏆✈️\n\n#Travelog #TravelTracker'
          : 'Working on the "${achievement.name}" badge on Travelog! 🏃‍♂️✈️\n\n#Travelog #TravelTracker';

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: shareText,
      );
    } catch (e) {
      debugPrint("Badge Share Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate share image: $e')),
        );
      }
    }
  }

  // 캡처 전용 UI (화면에는 안 보이고 이미지만 생성됨)
  static Widget _buildShareWidget(
      Achievement achievement,
      double progress,
      String progressDetailText,
      ) {
    Color categoryColor;
    switch (achievement.category) {
      case AchievementCategory.Country:
        categoryColor = const Color(0xFF3B82F6);
        break;
      case AchievementCategory.City:
        categoryColor = const Color(0xFFFBBF24);
        break;
      case AchievementCategory.Landmarks:
        categoryColor = const Color(0xFF66BB6A);
        break;
      case AchievementCategory.Flight:
        categoryColor = const Color(0xFFAB47BC);
        break;
      default:
        categoryColor = Colors.grey;
    }

    final isUnlocked = achievement.isUnlocked;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 500, // 인스타 스토리에 올리기 좋은 고정 너비
        color: const Color(0xFFF8FAFC), // 앱 배경색과 동일
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 뱃지 카드 디자인
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey[100],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              isUnlocked ? Colors.transparent : Colors.grey,
                              isUnlocked ? BlendMode.dst : BlendMode.saturation,
                            ),
                            child: Image.asset(
                              achievement.imagePath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              achievement.name,
                              style: const TextStyle(
                                fontSize: 26, // 크기 약간 확대
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${achievement.points} points',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: categoryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    achievement.description,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                          Text(
                            progressDetailText,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          color: categoryColor,
                          minHeight: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% Complete',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // 하단 Travelog 앱 워터마크
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/app_logo_large.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => const Icon(Icons.public, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Text(
                  'Travelog App',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}