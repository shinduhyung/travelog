import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// 국가 방문 희귀도 점수 결과.
class RarityResult {
  const RarityResult({required this.score, required this.raw, required this.topPercent, this.rarestCountry, this.rarestRate});

  /// 최종 점수 (0~100, 평균 50)
  final double score;

  /// 방문한 국가들의 희귀도 평균 (원점수)
  final double raw;

  /// 전체 유저 중 상위 몇 %로 희귀한지
  final double topPercent;

  /// 가장 희귀한 방문 국가와 그 나라를 방문한 유저 비율(%)
  final String? rarestCountry;
  final double? rarestRate;

  String get label {
    if (score >= 90) return 'Legendary';
    if (score >= 75) return 'Very rare';
    if (score >= 60) return 'Rare';
    if (score >= 40) return 'Balanced';
    return 'Common';
  }
}

/// 국가별 희귀도 R_c = sqrt(min(500, N / V_c)), 사용자 원점수 S_u = 방문 국가 R_c의 평균.
/// 사용자 원점수 분포(고정)에서의 순위를 정규분포 점수 T = 50 + 15·Φ⁻¹(p)로 바꾸고 0~100으로 제한한다.
/// 기준 데이터(assets/country_rarity.json)는 고정이라 신규 사용자도 같은 기준으로 비교된다.
class CountryRarity {
  CountryRarity._(this._r, this._scores, this._n);

  final Map<String, double> _r;
  final List<double> _scores;
  final int _n;

  static Future<CountryRarity?>? _instance;

  static Future<CountryRarity?> load() => _instance ??= _read();

  static Future<CountryRarity?> _read() async {
    try {
      final d = json.decode(await rootBundle.loadString('assets/country_rarity.json')) as Map;
      return CountryRarity._(
        {for (final e in (d['r'] as Map).entries) e.key.toString(): (e.value as num).toDouble()},
        [for (final v in d['scores'] as List) (v as num).toDouble()],
        (d['n'] as num).toInt(),
      );
    } catch (_) {
      _instance = null;
      return null;
    }
  }

  RarityResult? score(Iterable<String> countries) {
    final known = [for (final c in countries) if (_r.containsKey(c)) c];
    if (known.isEmpty) return null;
    final raw = known.map((c) => _r[c]!).reduce((a, b) => a + b) / known.length;

    // 낮은 점수부터 센 평균 순위 (동점은 평균 순위)
    var less = 0, equal = 0;
    for (final s in _scores) {
      if (s < raw - 1e-9) {
        less++;
      } else if ((s - raw).abs() <= 1e-9) {
        equal++;
      }
    }
    final rank = less + (equal + 1) / 2;
    final p = ((rank - 0.5) / (_scores.length + 1)).clamp(0.0005, 0.9995);
    final t = (50 + 15 * _inverseNormal(p)).clamp(0.0, 100.0);

    var best = known.first;
    for (final c in known) {
      if (_r[c]! > _r[best]!) best = c;
    }
    final rate = 100 / math.pow(_r[best]!, 2);
    return RarityResult(
      score: t,
      raw: raw,
      topPercent: ((1 - p) * 100).clamp(0.1, 100),
      rarestCountry: best,
      rarestRate: rate > 100 ? 100 : rate,
    );
  }

  int get sampleSize => _n;
}

/// 표준정규분포 역누적분포함수 (Acklam 근사)
double _inverseNormal(double p) {
  const a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00];
  const b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01];
  const c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00];
  const d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00];
  const low = 0.02425;
  if (p < low) {
    final q = math.sqrt(-2 * math.log(p));
    return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  if (p > 1 - low) {
    final q = math.sqrt(-2 * math.log(1 - p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  final q = p - 0.5;
  final r = q * q;
  return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
}
