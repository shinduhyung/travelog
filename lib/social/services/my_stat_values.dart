import 'package:jidoapp/services/statistics_repository.dart';

import '../data/geo_data.dart';
import '../models/global_stats.dart';
import '../models/social_profile.dart';
import '../models/stats.dart';

/// 내 프로필에서 [StatMetric] 값들을 뽑는다. 전체 유저 분포와 같은 기준으로 센다.
class MyStatValues {
  MyStatValues._(this.values);

  final Map<StatMetric, int> values;

  int valueOf(StatMetric m) => values[m] ?? 0;

  /// GaWC 189개 도시 (이름|ISO2). 앱 번들에서 한 번만 읽는다.
  static Future<Set<String>>? _gawc;

  static Future<Set<String>> gawcKeys() => _gawc ??= StatisticsRepository.instance
          .load('assets/gawc.json')
          .then((d) => {
                for (final r in d.table().records) '${r.dimensions['name']}|${r.dimensions['country_iso']}',
              })
          .catchError((Object e) {
        _gawc = null;
        return <String>{};
      });

  static Future<MyStatValues> compute(SocialProfile p) async {
    final gawc = await gawcKeys();
    return computeWith(p, gawc);
  }

  static MyStatValues computeWith(SocialProfile p, Set<String> gawc) {
    final geo = GeoData.I;
    final stats = ProfileStats(p);
    final out = <StatMetric, int>{
      StatMetric.countriesTotal: p.countryCount,
      for (final e in StatMetric.byContinent.entries) e.value: stats.continents[e.key] ?? 0,
      StatMetric.unesco: p.unescoCount,
      StatMetric.airports: p.airportCount,
      StatMetric.airlines: p.flights.airlines.length,
      StatMetric.flights: p.flights.total,
    };

    var gawcVisited = 0;
    final seen = <String>{};
    for (final key in p.cities) {
      final iso2 = geo.cities[key]?.iso2;
      final id = '${displayCityName(key)}|$iso2';
      if (gawc.contains(id) && seen.add(id)) gawcVisited++;
    }
    out[StatMetric.gawcCities] = gawcVisited;

    out[StatMetric.top250Landmarks] = stats.landmarkMetas.where((l) => l.rank > 0 && l.rank <= 250).length;
    return MyStatValues._(out);
  }
}
