// lib/screens/activity_stats_screen.dart

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:jidoapp/models/landmarks_model.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'package:provider/provider.dart';

// ✅ [추가] 랭킹에 사용할 활동별 통계 데이터 클래스 (Landmarks Stats와 동일한 구조를 사용한다고 가정)
class ActivityStatData {
  final String name;
  final int visitedCount;
  final int totalCount;
  final double percentage;

  ActivityStatData({
    required this.name,
    required this.visitedCount,
    required this.totalCount,
  }) : percentage = (totalCount > 0) ? (visitedCount / totalCount * 100) : 0.0;
}

class ActivityStatsScreen extends StatelessWidget {
  const ActivityStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        top: false, // 🔥 상태바 영역까지 꽉 채우기
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                   Text(
                    tr('Activity Statistics'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 🔥 나머지 내용은 Expanded 안으로
              Expanded(
                child: Consumer<LandmarksProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // TODO: 랜드마크 데이터 대신 Activities 관련 속성 통계를 계산하는 로직으로 변경 필요
                    // 현재는 임시로 텍스트만 표시합니다.
                    return Center(
                      child: Text(
                        tr('Activities 통계 화면입니다. (데이터 로직 추가 필요)\n예: 방문한 Cuisines 통계, Zoo/Aquarium 방문률'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
