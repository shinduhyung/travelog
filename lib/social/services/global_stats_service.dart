import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/global_stats.dart';

/// 전체 유저 통계 (분포, 평균/중앙값, 도시/랜드마크 방문율).
/// 앱에 번들된 assets/user_stats.json을 읽는다. 갱신은 tool/user_stats/build_user_stats.py로 에셋을 다시 만든다.
class GlobalStatsService {
  GlobalStatsService._();

  static final instance = GlobalStatsService._();

  /// 위젯 테스트용
  @visibleForTesting
  Future<GlobalStats?> Function()? debugLoader;

  Future<GlobalStats?>? _cached;

  Future<GlobalStats?> load() {
    if (debugLoader != null) return debugLoader!();
    return _cached ??= _read();
  }

  Future<GlobalStats?> _read() async {
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/user_stats.json'));
      return GlobalStats.fromMap(raw as Map);
    } catch (e) {
      debugPrint('User stats load failed: $e');
      _cached = null;
      return null;
    }
  }
}
