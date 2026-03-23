// lib/screens/flights_share.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:intl/intl.dart';

// Models
import 'package:jidoapp/models/airline_model.dart';
import 'package:jidoapp/models/airport_model.dart';

class FlightsShare {
  static Future<void> share({
    required BuildContext context,
    required Uint8List mapImage,
    required List<FlightLog> allLogs,
    required List<Airport> allAirports,
  }) async {
    final compositeController = ScreenshotController();

    try {
      final directory = await getTemporaryDirectory();
      final List<XFile> filesToShare = [];

      // 1. 통계 계산
      final stats = _calculateFlightStats(allLogs, allAirports);

      // 2. 이미지 생성 (지도 + 통계)
      final Uint8List shareImage = await compositeController.captureFromWidget(
        _buildStatsLayout(context, mapImage, stats),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.5,
      );

      final imagePath = await File('${directory.path}/flight_stats.png').create();
      await imagePath.writeAsBytes(shareImage);
      filesToShare.add(XFile(imagePath.path));

      // 3. 공유 실행
      await Share.shareXFiles(
        filesToShare,
        text: 'Check out my flight map! I have flown ${stats['distance']} via Travelog.',
      );
    } catch (e) {
      debugPrint("Flight Share Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate share image: $e')),
        );
      }
    }
  }

  // ⭐️ [Distance 전용] 숫자 3자리 이하 규칙 적용 포맷터
  // 예: 665100 -> 665k (0소수점), 6665100 -> 6.66m (2소수점)
  static String _formatDistance(double value) {
    if (value < 1000) {
      return NumberFormat("#,###").format(value.round());
    } else if (value < 1000000) {
      // k 단위
      double kValue = value / 1000;
      return '${_formatThreeDigits(kValue)}k';
    } else {
      // m 단위
      double mValue = value / 1000000;
      return '${_formatThreeDigits(mValue)}m';
    }
  }

  // 숫자의 크기에 따라 소수점 자릿수를 조절하여 "숫자 3개 이하"를 맞춤 (버림 처리)
  static String _formatThreeDigits(double value) {
    if (value >= 100) {
      // 100 이상 (예: 665.1) -> 소수점 버림 -> 665 (3자리)
      return value.floor().toString();
    } else if (value >= 10) {
      // 10 이상 100 미만 (예: 12.34) -> 소수점 1자리까지 버림 -> 12.3 (3자리)
      double truncated = (value * 10).floor() / 10;
      return truncated.toString().replaceAll(RegExp(r'\.0$'), '');
    } else {
      // 10 미만 (예: 6.6651) -> 소수점 2자리까지 버림 -> 6.66 (3자리)
      double truncated = (value * 100).floor() / 100;
      return truncated.toString().replaceAll(RegExp(r'\.0$'), '').replaceAll(RegExp(r'\.00$'), '');
    }
  }

  // ⭐️ [기타 통계용] 1000 이상일 때 k 붙이고 소수점 1자리까지 버림
  static String _formatGeneralStats(num value) {
    if (value >= 1000) {
      double kValue = value / 1000;
      // 소수점 첫째 자리까지만 남기고 버림 (예: 1.67 -> 1.6)
      double truncated = (kValue * 10).floor() / 10;
      return '${truncated == truncated.toInt() ? truncated.toInt() : truncated}k';
    }
    return NumberFormat("#,###").format(value);
  }

  // --- 통계 계산 로직 ---
  static Map<String, String> _calculateFlightStats(
      List<FlightLog> logs, List<Airport> airports) {

    double totalDistanceKm = 0;
    int totalMinutes = 0;
    int totalFlights = 0;
    Set<String> visitedAirports = {};
    Set<String> flownAirlines = {};

    // 공항 조회용 맵
    final airportMap = {for (var a in airports) a.iataCode: a};

    for (var log in logs) {
      if (log.times <= 0) continue;

      totalFlights += log.times;

      if (log.departureIata != null) visitedAirports.add(log.departureIata!);
      if (log.arrivalIata != null) visitedAirports.add(log.arrivalIata!);
      if (log.airlineName != null && log.airlineName != 'Unknown') {
        flownAirlines.add(log.airlineName!);
      }

      final dep = airportMap[log.departureIata];
      final arr = airportMap[log.arrivalIata];
      if (dep != null && arr != null) {
        final dist = _calculateDistance(dep.latitude, dep.longitude, arr.latitude, arr.longitude);
        totalDistanceKm += dist * log.times;
      }

      if (log.duration != null) {
        final minutes = _parseDurationToMinutes(log.duration!);
        totalMinutes += minutes * log.times;
      }
    }

    // ⭐️ [수정됨] Distance에만 전용 포맷터 적용
    final String distanceStr = "${_formatDistance(totalDistanceKm)} km";

    // 시간 포맷팅 (기타 통계 규칙 적용)
    final int hours = totalMinutes ~/ 60;
    final int mins = totalMinutes % 60;

    String durationStr;
    if (hours >= 1000) {
      durationStr = "${_formatGeneralStats(hours)} h";
    } else {
      durationStr = "${hours}h ${mins}m";
    }

    // 비행 횟수 (기타 통계 규칙 적용)
    final String flightsStr = _formatGeneralStats(totalFlights);

    return {
      'flights': flightsStr,
      'distance': distanceStr,
      'duration': durationStr,
      'airports': visitedAirports.length.toString(),
      'airlines': flownAirlines.length.toString(),
    };
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  static int _parseDurationToMinutes(String duration) {
    try {
      if (duration.contains('h') || duration.contains('m')) {
        int h = 0;
        int m = 0;
        final hMatch = RegExp(r'(\d+)\s*h').firstMatch(duration);
        final mMatch = RegExp(r'(\d+)\s*m').firstMatch(duration);
        if (hMatch != null) h = int.parse(hMatch.group(1)!);
        if (mMatch != null) m = int.parse(mMatch.group(1)!);
        return h * 60 + m;
      } else if (duration.contains(':')) {
        final parts = duration.split(':');
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    } catch (_) {}
    return 0;
  }

  // --- 레이아웃 빌더 ---
  static Widget _buildStatsLayout(
      BuildContext context,
      Uint8List mapImage,
      Map<String, String> stats,
      ) {
    const primaryColor = Colors.deepPurple;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      width: 600,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ========== 1. 헤더 (로고 + 타이틀 + 총 비행수) ==========
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/icons/app_logo_large.png',
                    width: 36,
                    height: 36,
                    errorBuilder: (_, __, ___) => const Icon(Icons.public, size: 36, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Travelog',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: -0.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              // 총 비행 수 배지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      stats['flights'] ?? '0',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                        decoration: TextDecoration.none,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Flights',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ========== 2. 지도 이미지 ==========
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.center,
                  heightFactor: 0.7,
                  child: Image.memory(mapImage, fit: BoxFit.cover),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ========== 3. 통계 (2단 구성) ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.straighten_rounded,
                      label: 'Total Distance',
                      value: stats['distance'] ?? '-',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      icon: Icons.schedule_rounded,
                      label: 'Total Duration',
                      value: stats['duration'] ?? '-',
                      color: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.connecting_airports_rounded,
                      label: 'Airports Visited',
                      value: stats['airports'] ?? '0',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      icon: Icons.airlines_rounded,
                      label: 'Airlines Flown',
                      value: stats['airlines'] ?? '0',
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      decoration: TextDecoration.none,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}