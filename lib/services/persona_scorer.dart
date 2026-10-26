// lib/services/persona_scorer.dart
//
// 여행자 타입 점수 계산 (순수 Dart, 결정적).
// 예전에는 LLM이 거리 공식을 직접 계산했지만 가중치 합이 타입마다 달라 쏠림이 있었고
// (36~41), 중립 사용자도 75%를 받는 점수 부풀림이 있었다. 여기서는
//   1) 타입별 가중치 합으로 정규화 (0~1 유사도)
//   2) 값이 없는 축은 0으로 두지 않고 계산에서 제외
//   3) 기준 집단(평균 0 근처) 대비 z-점수로 타입별 편향 제거
//   4) softmax로 10개 타입의 상대 비율로 변환
// 순서로 계산한다.

import 'dart:math';

class PersonaScore {
  final String id;
  final String label;
  final double score; // 0.0 ~ 1.0, 10개 타입 합 = 1.0
  const PersonaScore(this.id, this.label, this.score);
}

class PersonaScoreResult {
  final List<PersonaScore> scores; // 내림차순
  final double gap; // 1위와 2위의 점수 차 (0~1)
  final double coverage; // 계산에 쓰인 가중치 비율 (0~1)

  const PersonaScoreResult(this.scores, this.gap, this.coverage);

  /// 1·2위가 사실상 접전이면 true (혼합형으로 표시)
  bool get isClose => gap < 0.08;

  /// 데이터가 부족해 결과가 불안정하면 true
  bool get lowData => coverage < 0.6;
}

class PersonaScorer {
  PersonaScorer._();

  static const double temperature = 0.5;
  static const int _calibrationSamples = 1500;
  static const double _calibrationSigma = 0.4;

  /// [prototypes]: archetype_prototypes JSON (id, label, data{axis:{P,W}})
  /// [user]: 축 이름 -> -1..1. 없는 키는 "데이터 없음"으로 취급해 제외한다.
  static PersonaScoreResult score(
      List<dynamic> prototypes, Map<String, double> user) {
    final types = prototypes.cast<Map<String, dynamic>>();
    final axes = user.keys.toSet();

    final raw = [for (final t in types) _similarity(t, user)];

    // 기준 집단에서 타입별 평균/표준편차를 구해 편향 제거.
    // 사용자와 같은 축 집합으로 계산해야 마스크가 달라도 공정하다.
    final rng = Random(12345);
    final samples = List.generate(types.length, (_) => <double>[]);
    for (var n = 0; n < _calibrationSamples; n++) {
      final u = <String, double>{
        for (final k in axes)
          k: (_gauss(rng) * _calibrationSigma).clamp(-1.0, 1.0).toDouble(),
      };
      for (var i = 0; i < types.length; i++) {
        samples[i].add(_similarity(types[i], u));
      }
    }

    final z = <double>[];
    for (var i = 0; i < types.length; i++) {
      final mean = samples[i].reduce((a, b) => a + b) / samples[i].length;
      final variance = samples[i]
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          samples[i].length;
      final sd = max(sqrt(variance), 1e-6);
      z.add((raw[i] - mean) / sd);
    }

    final maxZ = z.reduce(max);
    final exps = [for (final v in z) exp((v - maxZ) / temperature)];
    final total = exps.reduce((a, b) => a + b);

    final out = <PersonaScore>[
      for (var i = 0; i < types.length; i++)
        PersonaScore(types[i]['id'] as String, types[i]['label'] as String,
            exps[i] / total),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final gap = out.length > 1 ? out[0].score - out[1].score : out[0].score;

    var usedW = 0.0, allW = 0.0;
    for (final t in types) {
      final data = t['data'] as Map<String, dynamic>;
      for (final e in data.entries) {
        final w = (e.value['W'] as num).toDouble();
        allW += w;
        if (axes.contains(e.key)) usedW += w;
      }
    }
    return PersonaScoreResult(out, gap, allW == 0 ? 0 : usedW / allW);
  }

  /// 1 - D / (2 * sumW): 값이 있는 축만, 가중치 합으로 정규화한 0~1 유사도.
  static double _similarity(
      Map<String, dynamic> type, Map<String, double> user) {
    final data = type['data'] as Map<String, dynamic>;
    var d = 0.0, sumW = 0.0;
    for (final e in data.entries) {
      final u = user[e.key];
      final w = (e.value['W'] as num).toDouble();
      if (u == null || w <= 0) continue;
      d += w * (u - (e.value['P'] as num).toDouble()).abs();
      sumW += w;
    }
    return sumW == 0 ? 0.5 : 1 - d / (2 * sumW);
  }

  static double _gauss(Random r) {
    final u1 = 1 - r.nextDouble();
    final u2 = r.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}
