import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:country_flags/country_flags.dart';
import 'package:jidoapp/models/country_model.dart';

class CountriesShare {
  static Future<void> share({
    required BuildContext context,
    required Uint8List mapImage,
    required List<Country> visitedCountries,
  }) async {
    final compositeController = ScreenshotController();

    try {
      final directory = await getTemporaryDirectory();
      final List<XFile> filesToShare = [];

      // 대륙별 통계 계산
      final continentStats = _calculateContinentStats(visitedCountries);
      final continentTotals = _calculateContinentTotals(visitedCountries);

      // 1페이지: 지도 + 통계
      final Uint8List statsImage = await compositeController.captureFromWidget(
        _buildStatsLayout(context, mapImage, visitedCountries, continentStats, continentTotals),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.5,
      );

      final statsImagePath = await File('${directory.path}/travel_stats.png').create();
      await statsImagePath.writeAsBytes(statsImage);
      filesToShare.add(XFile(statsImagePath.path));

      // 2페이지: 국기들 (최대 1페이지만, 초과분은 무시)
      if (visitedCountries.isNotEmpty) {
        final int maxFlags = 120; // 가로 10개 x 세로 12줄 정도
        final flagsToShow = visitedCountries.take(maxFlags).toList();

        final Uint8List flagsImage = await compositeController.captureFromWidget(
          _buildFlagsLayout(context, flagsToShow),
          delay: const Duration(milliseconds: 100),
          pixelRatio: 2.5,
        );

        final flagsImagePath = await File('${directory.path}/travel_flags.png').create();
        await flagsImagePath.writeAsBytes(flagsImage);
        filesToShare.add(XFile(flagsImagePath.path));
      }

      await Share.shareXFiles(
        filesToShare,
        text: 'Check out my travel map! I have visited ${visitedCountries.length} countries via Travelog.',
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

  // 대륙별 통계 계산
  static Map<String, int> _calculateContinentStats(List<Country> countries) {
    final stats = <String, int>{};
    for (var country in countries) {
      final continent = country.continent;
      if (continent != null && continent.isNotEmpty) {
        stats[continent] = (stats[continent] ?? 0) + 1;
      }
    }
    return stats;
  }

  // 대륙별 전체 국가 수 (대략적인 값)
  static Map<String, int> _calculateContinentTotals(List<Country> countries) {
    return {
      'Asia': 51,
      'Europe': 51,
      'Africa': 56,
      'North America': 38,
      'South America': 13,
      'Oceania': 24,
    };
  }

  // 대륙별 색상
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

  // 1페이지: 지도 + 통계
  static Widget _buildStatsLayout(
      BuildContext context,
      Uint8List mapImage,
      List<Country> visitedCountries,
      Map<String, int> continentStats,
      Map<String, int> continentTotals,
      ) {
    final primaryColor = Theme.of(context).primaryColor;
    final totalCountries = visitedCountries.length;

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
                      '$totalCountries',
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
                        'Countries',
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
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 0.75,
                  child: Image.memory(mapImage, fit: BoxFit.cover),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ========== 대륙별 통계 (Grid 형태) ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                // 첫 번째 행
                Row(
                  children: [
                    _buildContinentCard('Asia', continentStats['Asia'] ?? 0, continentTotals['Asia'] ?? 1),
                    const SizedBox(width: 6),
                    _buildContinentCard('Europe', continentStats['Europe'] ?? 0, continentTotals['Europe'] ?? 1),
                    const SizedBox(width: 6),
                    _buildContinentCard('Africa', continentStats['Africa'] ?? 0, continentTotals['Africa'] ?? 1),
                  ],
                ),
                const SizedBox(height: 6),
                // 두 번째 행
                Row(
                  children: [
                    _buildContinentCard('North America', continentStats['North America'] ?? 0, continentTotals['North America'] ?? 1),
                    const SizedBox(width: 6),
                    _buildContinentCard('South America', continentStats['South America'] ?? 0, continentTotals['South America'] ?? 1),
                    const SizedBox(width: 6),
                    _buildContinentCard('Oceania', continentStats['Oceania'] ?? 0, continentTotals['Oceania'] ?? 1),
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
  static Widget _buildContinentCard(String continent, int count, int total) {
    final color = _getContinentColor(continent);
    final asset = _getContinentAsset(continent);
    final displayName = continent == 'North America'
        ? 'N. America'
        : (continent == 'South America' ? 'S. America' : continent);
    final ratio = total > 0 ? count / total : 0.0;

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
                Text(
                  count > 0 ? '$count/$total' : '-',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: count > 0 ? color : Colors.grey.shade400,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
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

  // 2페이지: 국기 목록
  static Widget _buildFlagsLayout(
      BuildContext context,
      List<Country> countries,
      ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ========== 국기 그리드만 ==========
          Wrap(
            spacing: 1,
            runSpacing: 2,
            alignment: WrapAlignment.center,
            children: countries.map((country) {
              final String countryCode = country.isoA2;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: ClipOval(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: (countryCode.isNotEmpty && countryCode != 'N/A')
                            ? CountryFlag.fromCountryCode(countryCode)
                            : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.flag, size: 11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  SizedBox(
                    width: 44,
                    child: Text(
                      country.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 6,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}