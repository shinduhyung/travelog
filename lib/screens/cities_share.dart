import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:jidoapp/models/city_model.dart';

class CitiesShare {
  static Future<void> share({
    required BuildContext context,
    required Uint8List mapImage,
    required List<City> visitedCities,
  }) async {
    final compositeController = ScreenshotController();

    try {
      final directory = await getTemporaryDirectory();

      // 대륙별 통계 계산
      final continentStats = calculateContinentStats(visitedCities);

      // 단일 페이지: 통계 레이아웃
      final Uint8List statsImage = await compositeController.captureFromWidget(
        buildStatsLayout(context, mapImage, visitedCities, continentStats),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.5,
      );

      final statsImagePath = await File('${directory.path}/cities_map_share.png').create();
      await statsImagePath.writeAsBytes(statsImage);

      await Share.shareXFiles(
        [XFile(statsImagePath.path)],
        text: 'Check out my city travels! I have visited ${visitedCities.length} cities via Travelog.',
      );
    } catch (e) {
      debugPrint("Share Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate share image: $e')),
        );
      }
    }
  }

  // 대륙별 방문 도시 수 계산
  static Map<String, int> calculateContinentStats(List<City> cities) {
    final stats = <String, int>{};
    for (var city in cities) {
      final continent = city.continent;
      if (continent.isNotEmpty && continent != 'Unknown') {
        stats[continent] = (stats[continent] ?? 0) + 1;
      }
    }
    return stats;
  }

  // 대륙별 색상 (country share와 동일)
  static Color _getContinentColor(String continent) {
    switch (continent) {
      case 'Asia':
        return Colors.pink.shade300;
      case 'Europe':
        return Colors.yellow.shade700;
      case 'Africa':
        return Colors.brown.shade400;
      case 'North America':
        return Colors.blue.shade400;
      case 'South America':
        return Colors.green.shade400;
      case 'Oceania':
        return Colors.purple.shade400;
      default:
        return Colors.grey;
    }
  }

  // 대륙 아이콘 경로
  static String _getContinentAsset(String continent) {
    switch (continent) {
      case 'Asia':
        return 'assets/icons/asia.png';
      case 'Europe':
        return 'assets/icons/europe.png';
      case 'Africa':
        return 'assets/icons/africa.png';
      case 'North America':
        return 'assets/icons/n_america.png';
      case 'South America':
        return 'assets/icons/s_america.png';
      case 'Oceania':
        return 'assets/icons/oceania.png';
      default:
        return '';
    }
  }

  // 통계 레이아웃
  static Widget buildStatsLayout(
      BuildContext context,
      Uint8List mapImage,
      List<City> visitedCities,
      Map<String, int> continentStats,
      ) {
    final primaryColor = Theme.of(context).primaryColor;
    final totalCities = visitedCities.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ========== 헤더 ==========
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/icons/app_logo_large.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) => const Icon(Icons.public, size: 32),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Travelog',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: -0.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalCities',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        decoration: TextDecoration.none,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'Cities',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ========== 지도 이미지 ==========
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRect(
                  child: Align(
                    alignment: const Alignment(0.0, 0.3),  // 0.0이 중앙, 숫자 높이면 아래로
                    heightFactor: 0.75,
                    child: Image.memory(mapImage, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ========== 대륙별 도시 통계 (Grid 형태) ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                // 첫 번째 행
                Row(
                  children: [
                    _buildContinentCard('Asia', continentStats['Asia'] ?? 0, totalCities),
                    const SizedBox(width: 6),
                    _buildContinentCard('Europe', continentStats['Europe'] ?? 0, totalCities),
                    const SizedBox(width: 6),
                    _buildContinentCard('Africa', continentStats['Africa'] ?? 0, totalCities),
                  ],
                ),
                const SizedBox(height: 6),
                // 두 번째 행
                Row(
                  children: [
                    _buildContinentCard('North America', continentStats['North America'] ?? 0, totalCities),
                    const SizedBox(width: 6),
                    _buildContinentCard('South America', continentStats['South America'] ?? 0, totalCities),
                    const SizedBox(width: 6),
                    _buildContinentCard('Oceania', continentStats['Oceania'] ?? 0, totalCities),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // 대륙 카드 생성 헬퍼
  static Widget _buildContinentCard(String continent, int count, int totalCities) {
    final color = _getContinentColor(continent);
    final asset = _getContinentAsset(continent);
    final displayName = continent == 'North America'
        ? 'N. America'
        : (continent == 'South America' ? 'S. America' : continent);
    final ratio = totalCities > 0 ? count / totalCities : 0.0;
    final percentage = (ratio * 100).toStringAsFixed(1);

    return Expanded(
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: count > 0 ? color.withOpacity(0.3) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    asset,
                    width: 12,
                    height: 12,
                    color: color,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.public,
                      size: 12,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      decoration: TextDecoration.none,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: count > 0 ? color : Colors.grey.shade400,
                        decoration: TextDecoration.none,
                        height: 1,
                      ),
                    ),
                    if (count > 0)
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      // 배경 바
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 진행률 바
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: count > 0 ? color : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}