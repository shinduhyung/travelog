// lib/screens/explore_menu_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jidoapp/providers/unesco_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';

// Screens
import 'package:jidoapp/screens/unesco_sites_screen.dart';
import 'package:jidoapp/screens/unesco_map_screen.dart';
import 'package:jidoapp/screens/unesco_stats_screen.dart';

import 'package:jidoapp/screens/landmarks_menu_screen.dart';
import 'package:jidoapp/screens/natural_menu_screen.dart';
import 'package:jidoapp/screens/top_picks_menu_screen.dart';
import 'package:jidoapp/screens/landmark_stats_screen.dart';
import 'package:jidoapp/screens/landmark_visit_log_screen.dart';

import 'package:jidoapp/screens/activities_menu_screen.dart';
import 'package:jidoapp/screens/top_activities_menu_screen.dart';
import 'package:jidoapp/providers/auth_provider.dart';
import 'package:jidoapp/screens/login_prompt_screen.dart';

class ExploreMenuScreen extends StatelessWidget {
  const ExploreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'assets/icons/app_wallpaper.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                // Header (심플하고 여백을 살린 스타일)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready for an adventure?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                            letterSpacing: 1.2,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Explore',
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -1.2,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // UNESCO Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Consumer<UnescoProvider>(
                      builder: (context, unescoProvider, child) {
                        final total = unescoProvider.allSites.length;
                        final visited = unescoProvider.visitedSites.length;
                        final progress = total > 0 ? visited / total : 0.0;

                        void gated(VoidCallback action) {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          if (auth.user == null) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const LoginPromptScreen(),
                            );
                            return;
                          }
                          action();
                        }
                        return _buildUnescoSection(
                          context,
                          visited: visited,
                          total: total,
                          progress: progress,
                          onMainTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnescoSitesScreen())),
                          onMapTap: () => gated(() {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => UnescoMapScreen(
                                title: 'UNESCO Map',
                                allItems: unescoProvider.allSites,
                                visitedItems: unescoProvider.visitedSites,
                                onToggleVisited: unescoProvider.toggleVisitedStatus,
                              ),
                            ));
                          }),
                          onStatsTap: () => gated(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnescoStatsScreen()))),
                        );
                      },
                    ),
                  ),
                ),

                // Landmarks Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _buildLandmarksSection(context),
                  ),
                ),

                // Activities Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 50),
                    child: _buildActivitiesSection(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UNESCO Section
  Widget _buildUnescoSection(
      BuildContext context, {
        required int visited,
        required int total,
        required double progress,
        required VoidCallback onMainTap,
        required VoidCallback onMapTap,
        required VoidCallback onStatsTap,
      }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onMainTap,
          child: Container(
            height: 220, // 사진이 조금 더 잘 보이도록 높이 증가
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFF8C42), // 주황색 테두리
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8C42).withOpacity(0.35), // 넓게 퍼지는 주황색 글로우 효과
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // 전체 배경 사진 (검은색 그라데이션 제거)
                  Positioned.fill(
                    child: Image.asset(
                      'assets/explore_icons/unesco.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),

                  // 하단 글래스모피즘(반투명 블러) 영역
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85), // 밝은 톤의 반투명 배경
                            border: Border(
                              top: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$visited',
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFFF8C42), // 밝은 배경에 맞는 주황색 숫자
                                            height: 1,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 3),
                                          child: Text(
                                            '/ $total',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[600], // 진한 회색 텍스트
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        height: 8,
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8C42)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF8C42).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFF8C42).withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFF8C42),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildIconButton(
                icon: Icons.explore_outlined,
                label: 'Map',
                color: const Color(0xFF667EEA),
                onTap: onMapTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIconButton(
                icon: Icons.analytics_outlined,
                label: 'Stats',
                color: const Color(0xFFEC4899),
                onTap: onStatsTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandmarksSection(BuildContext context) {
    void _gatedPush(BuildContext context, Widget screen) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const LoginPromptScreen(),
        );
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Landmarks',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildLandmarkCard(
                context,
                title: 'Cultural',
                imagePath: 'assets/explore_icons/landmarks_top.png',
                onTap: () => _gatedPush(context, const LandmarksMenuScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLandmarkCard(
                context,
                title: 'Natural',
                imagePath: 'assets/explore_icons/mountains.png',
                onTap: () => _gatedPush(context, const NaturalMenuScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSmallOutlineButton(
                context,
                title: 'Top Picks',
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopPicksMenuScreen())),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSmallOutlineButton(
                context,
                title: 'Stats',
                icon: Icons.analytics_outlined,
                color: const Color(0xFF3B82F6),
                onTap: () => _gatedPush(context, const LandmarkStatsScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSmallOutlineButton(
                context,
                title: 'Logs',
                icon: Icons.history_edu_rounded,
                color: const Color(0xFF10B981),
                onTap: () => _gatedPush(context, const LandmarkVisitLogScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLandmarkCard(
      BuildContext context, {
        required String title,
        required String imagePath,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallOutlineButton(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Activities Section
  Widget _buildActivitiesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activities',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivitiesMenuScreen())),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/explore_icons/activities_top.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                'Browse Activities',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Paintings, Foods, Amusement Parks & More',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}