import 'package:jidoapp/services/statistics_repository.dart';

import '../data/geo_data.dart';
import '../models/global_stats.dart';

/// 앱에 들어 있는 나라별 통계(assets/*.json)에서 Top 10 순위표를 만든다.
/// 이미지를 따로 싣는 대신 같은 모양의 카드를 위젯으로 그린다 (용량 0, 데이터가 바뀌면 자동 반영).
class LocalRankingSpec {
  const LocalRankingSpec({
    required this.id,
    required this.titleTop,
    required this.titleBottom,
    required this.subtitle,
    required this.asset,
    required this.metric,
    required this.format,
    this.continent,
    this.ascending = false,
  });

  final String id;
  final String titleTop;
  final String titleBottom;
  final String subtitle;
  final String asset;
  final String metric;
  final String Function(num v) format;

  /// economy_data처럼 continent 값이 있는 표에서 한 대륙만 고를 때
  final String? continent;
  final bool ascending;
}

String _compact(num v, {int digits = 2}) {
  final a = v.abs();
  if (a >= 1e12) return '${(v / 1e12).toStringAsFixed(digits)}T';
  if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(digits)}B';
  if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(digits)}M';
  if (a >= 1e4) return '${(v / 1e3).toStringAsFixed(1)}K';
  return v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(digits);
}

String _int(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

final localRankingSpecs = <LocalRankingSpec>[
  LocalRankingSpec(
    id: 'armies',
    titleTop: 'Biggest Armies',
    titleBottom: 'Active Troops',
    subtitle: 'Active military personnel',
    asset: 'assets/armed_forces.json',
    metric: 'armed_forces_personnel_total',
    format: (v) => v >= 1e6 ? _compact(v) : _int(v),
  ),
  LocalRankingSpec(
    id: 'economies',
    titleTop: "World's Largest",
    titleBottom: 'Economies',
    subtitle: 'Nominal GDP, USD',
    asset: 'assets/economy_data.json',
    metric: 'gdp_nominal',
    // 원본 단위는 10억 달러
    format: (v) => '\$${_compact(v * 1e9)}',
  ),
  LocalRankingSpec(
    id: 'asia_economies',
    titleTop: "Asia's Largest",
    titleBottom: 'Economies',
    subtitle: 'Nominal GDP, USD',
    asset: 'assets/economy_data.json',
    metric: 'gdp_nominal',
    continent: 'Asia',
    format: (v) => '\$${_compact(v * 1e9)}',
  ),
  LocalRankingSpec(
    id: 'europe_economies',
    titleTop: "Europe's Largest",
    titleBottom: 'Economies',
    subtitle: 'Nominal GDP, USD',
    asset: 'assets/economy_data.json',
    metric: 'gdp_nominal',
    continent: 'Europe',
    format: (v) => '\$${_compact(v * 1e9)}',
  ),
  LocalRankingSpec(
    id: 'population',
    titleTop: 'Most Populous',
    titleBottom: 'Countries',
    subtitle: 'Population',
    asset: 'assets/economy_data.json',
    metric: 'population',
    // 원본 단위는 백만 명
    format: (v) => _compact(v * 1e6),
  ),
  LocalRankingSpec(
    id: 'area',
    titleTop: 'Largest Countries',
    titleBottom: 'By Area',
    subtitle: 'Total area, km²',
    asset: 'assets/area_data.json',
    metric: 'area',
    format: (v) => '${_compact(v, digits: 1)} km²',
  ),
  LocalRankingSpec(
    id: 'hdi',
    titleTop: 'Highest Human',
    titleBottom: 'Development',
    subtitle: 'Human Development Index',
    asset: 'assets/hdi_data.json',
    metric: 'hdi',
    format: (v) => v.toStringAsFixed(3),
  ),
  LocalRankingSpec(
    id: 'fertility',
    titleTop: 'Highest Fertility',
    titleBottom: 'Rates',
    subtitle: 'Births per woman',
    asset: 'assets/fertility_rate.json',
    metric: 'fertility_rate',
    format: (v) => v.toStringAsFixed(2),
  ),
  LocalRankingSpec(
    id: 'gold',
    titleTop: 'Biggest Gold',
    titleBottom: 'Reserves',
    subtitle: 'Central bank gold, tonnes',
    asset: 'assets/gold.json',
    metric: 'gold',
    format: (v) => '${_int(v)} t',
  ),
];

class LocalRankings {
  LocalRankings._();

  /// 표 하나를 읽어 Top 10으로. 데이터를 못 읽으면 null.
  static Future<RankingData?> build(LocalRankingSpec spec) async {
    try {
      final table = (await StatisticsRepository.instance.load(spec.asset)).table();
      final geo = GeoData.I;
      final rows = <RankRow>[];
      for (final r in table.records) {
        if (spec.continent != null && r.values['continent'] != spec.continent) continue;
        final v = r.number(spec.metric);
        if (v == null) continue;
        final country = geo.countryByIso3(r.dimensions['iso_a3']?.toString());
        // 지도에 없는 영토는 국기를 그릴 수 없어 순위에서 뺀다
        if (country == null || country.iso2 == null) continue;
        rows.add(RankRow(
          label: country.longName == country.name || country.longName.length > 22 ? country.name : country.longName,
          iso2: country.iso2,
          value: v.toDouble(),
          valueText: spec.format(v),
        ));
      }
      if (rows.length < 3) return null;
      rows.sort((a, b) => spec.ascending ? a.value.compareTo(b.value) : b.value.compareTo(a.value));
      return RankingData(
        titleTop: spec.titleTop,
        titleBottom: spec.titleBottom,
        subtitle: spec.subtitle,
        rows: rows.take(10).toList(),
      );
    } catch (_) {
      return null;
    }
  }
}
