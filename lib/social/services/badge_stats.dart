import 'dart:convert';

import 'package:flutter/services.dart';

/// 배지 점수 결과: 점수, 랭크, 전체 유저 중 상위 몇 %인지.
class BadgeResult {
  const BadgeResult({required this.points, required this.rank, this.topPercent});

  final int points;
  final String rank;

  /// 나와 같거나 더 높은 점수를 가진 유저의 비율 (점수가 0이면 null)
  final double? topPercent;
}

/// 배지 점수 분포 (assets/badge_scores.json). 인원 수는 담지 않고 점수별 상위 %와 랭크별 비율만 둔다.
/// 구독자는 프리미엄 포함 분포, 비구독자는 무료 배지 분포와 비교한다.
class BadgeStats {
  BadgeStats._(this._free, this._all);

  final _Dist _free;
  final _Dist _all;

  static Future<BadgeStats?>? _instance;

  static Future<BadgeStats?> load() => _instance ??= _read();

  static Future<BadgeStats?> _read() async {
    try {
      final d = json.decode(await rootBundle.loadString('assets/badge_scores.json')) as Map;
      return BadgeStats._(_Dist.from(d['free'] as Map), _Dist.from(d['all'] as Map));
    } catch (_) {
      _instance = null;
      return null;
    }
  }

  /// 앱의 랭크 기준 (홈 화면의 레벨과 같다)
  static const _ranks = [
    (600, 'Legend'),
    (400, 'Worldmaster'),
    (200, 'Globetrotter'),
    (100, 'Adventurer'),
    (50, 'Nomad'),
    (10, 'Explorer'),
    (0, 'Rookie'),
  ];

  static String rankOf(int points) {
    for (final (min, name) in _ranks) {
      if (points >= min) return name;
    }
    return 'Rookie';
  }

  BadgeResult score(int points, {required bool premium}) {
    final top = points > 0 ? (premium ? _all : _free).topPercent(points) : null;
    return BadgeResult(points: points, rank: rankOf(points), topPercent: top);
  }

  /// 랭크별 유저 비율(%), 높은 랭크부터.
  List<(String, double)> rankShares({required bool premium}) {
    final t = (premium ? _all : _free).tiers;
    return [for (final (_, name) in _ranks) (name, t[name] ?? 0)];
  }
}

class _Dist {
  _Dist(this._points, this._top, this.tiers);

  final List<int> _points;
  final List<double> _top;
  final Map<String, double> tiers;

  factory _Dist.from(Map m) {
    final rows = m['top'] as List;
    return _Dist(
      [for (final r in rows) ((r as List)[0] as num).toInt()],
      [for (final r in rows) (r as List)[1].toDouble() as double],
      {for (final e in (m['tiers'] as Map).entries) '${e.key}': (e.value as num).toDouble()},
    );
  }

  /// points 이상인 유저의 비율(%). 표에 없으면 바로 위 점수의 값.
  double topPercent(int points) {
    var lo = 0, hi = _points.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_points[mid] < points) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo >= _top.length) return 0.1;
    return _top[lo].clamp(0.1, 100.0);
  }
}
