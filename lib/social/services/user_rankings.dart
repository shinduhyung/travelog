import '../data/geo_data.dart';
import '../models/global_stats.dart';

/// Travelog 유저들의 방문율(번들 통계)로 만드는 Top 10 순위표: 인기 도시, 인기 랜드마크, 대륙별 랜드마크.
class UserRankings {
  UserRankings._();

  static const _continents = ['Europe', 'Asia', 'Africa', 'North America', 'South America', 'Oceania'];

  /// (카드 id, 내용). 통계가 없으면 빈 목록.
  static List<(String, RankingData)> build(GlobalStats? stats) {
    if (stats == null || !GeoData.isLoaded) return const [];
    final geo = GeoData.I;
    final out = <(String, RankingData)>[];

    String pct(double v) => '${v.toStringAsFixed(v < 10 ? 1 : 0)}%';

    RankRow cityRow(VisitRate r) {
      final meta = geo.cities[r.name];
      final country = geo.countryByIso2(meta?.iso2);
      return RankRow(label: r.name, sub: country?.name, iso2: country?.iso2, value: r.percent, valueText: pct(r.percent));
    }

    final cities = [for (final r in stats.cities) if (geo.cities.containsKey(r.name)) r];
    if (cities.length >= 10) {
      out.add(('user_cities', RankingData(
        titleTop: 'Most Visited',
        titleBottom: 'Cities',
        subtitle: 'Share of Travelog users who have visited each city',
        rows: cities.take(10).map(cityRow).toList(),
      )));
    }

    ({RankRow row, CountryMeta? country})? landmarkRow(VisitRate r) {
      final meta = geo.landmarks[r.name];
      if (meta == null) return null;
      final country = geo.countryByIso3(meta.iso3);
      return (
        row: RankRow(label: r.name, sub: country?.name, iso2: country?.iso2, value: r.percent, valueText: pct(r.percent)),
        country: country,
      );
    }

    final landmarks = [for (final r in stats.landmarks) ?landmarkRow(r)];
    if (landmarks.length >= 10) {
      out.add(('user_landmarks', RankingData(
        titleTop: 'Most Visited',
        titleBottom: 'Landmarks',
        subtitle: 'Share of Travelog users who have visited each landmark',
        rows: landmarks.take(10).map((e) => e.row).toList(),
      )));
    }
    for (final continent in _continents) {
      final rows = [for (final l in landmarks) if (l.country?.continent == continent) l.row];
      if (rows.length < 10) continue;
      out.add(('user_landmarks_${continent.toLowerCase().replaceAll(' ', '_')}', RankingData(
        titleTop: 'Landmarks',
        titleBottom: continent,
        subtitle: 'Share of Travelog users who have visited each landmark',
        rows: rows.take(10).toList(),
      )));
    }
    return out;
  }
}
