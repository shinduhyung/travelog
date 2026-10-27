import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/models/global_stats.dart';

void main() {
  test('distribution mean, median, top percent (>= definition)', () {
    // 값 1이 2명, 3이 1명, 10이 1명 -> 1,1,3,10
    final d = MetricDistribution(hist: {1: 2, 3: 1, 10: 1});
    expect(d.n, 4.0);
    expect(d.mean, 3.75);
    expect(d.median, 1);
    expect(d.topPercent(10), 25.0);
    expect(d.topPercent(3), 50.0);
    expect(d.topPercent(1), 100.0);
    expect(d.topPercent(0), isNull);
  });

  test('top percent matches the exported CSV (countries, 2533 users)', () {
    // countries 1 -> 100.0, 2 -> 95.1 (1개 방문자 124명)
    final d = MetricDistribution(hist: {1: 124, 2: 111, 3: 2298});
    expect(d.topPercent(1), 100.0);
    expect(d.topPercent(2), closeTo(95.1, 0.1));
  });

  test('bundled json parses', () {
    final g = GlobalStats.fromMap({
      'updatedAt': '2026-10-27',
      'metrics': {
        'flights': {'mean': 12.5, 'median': 7, 'hist': {'5': 1, '9': 1}}
      },
      'cities': [['Paris', 46.25]],
      'landmarks': [['Eiffel Tower', 37.28], ['bad']],
    });
    final d = g.of(StatMetric.flights)!;
    expect(d.mean, 12.5);
    expect(d.median, 7);
    expect(g.cities.single.name, 'Paris');
    expect(g.landmarks.length, 1);
    expect(g.hasDistributions, isTrue);
  });
}
