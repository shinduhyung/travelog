import 'package:jidoapp/providers/country_provider.dart';
import 'package:jidoapp/providers/city_provider.dart';
import 'package:jidoapp/providers/landmarks_provider.dart';
import 'discover_recommender.dart';

class DiscoverUserProfile {
  final Map<String, List<DiscoverVisit>> evidence;
  final Map<String, Set<String>> excluded;
  const DiscoverUserProfile(this.evidence, this.excluded);

  List<DiscoverVisit> get combined => {
    for (final group in evidence.entries)
      for (final visit in group.value)
        '${group.key}|${visit.key}': DiscoverVisit(
          '${group.key}|${visit.key}',
          visit.scores,
          visit.rating,
        ),
  }.values.toList();

  int get ratedCount => combined
      .where((v) => v.rating.isFinite && v.rating >= 1 && v.rating <= 5)
      .length;

  DiscoverResult recommend(
    DiscoverRecommender model,
    String kind,
    Map<int, int> answers, {
    bool includeVisited = false,
    bool applyPopularity = true,
    int limit = 3,
  }) => model.recommend(
    kind,
    evidence[kind]!,
    answers,
    preferenceEvidence: combined,
    excludedIds: includeVisited ? const {} : excluded[kind]!,
    includeVisited: includeVisited,
    applyPopularity: applyPopularity,
    limit: limit,
  );

  /// Same score as the AI Recommendation list, for one place. Null when the
  /// user has too few ratings or the place lacks enough scored axes.
  double? scoreFor(
    DiscoverRecommender model,
    DiscoverPlace place,
    Map<int, int> answers,
  ) {
    final r = model.recommend(
      place.kind,
      evidence[place.kind]!,
      answers,
      preferenceEvidence: combined,
      includeVisited: true,
      only: place,
    );
    return r.matches.isEmpty ? null : r.matches.first.rankScore;
  }

  static DiscoverUserProfile capture(
    DiscoverRecommender model,
    CountryProvider countries,
    CityProvider cities,
    LandmarksProvider landmarks,
  ) {
    final countryVisits = <DiscoverVisit>[];
    final cityVisits = <DiscoverVisit>[];
    final landmarkVisits = <DiscoverVisit>[];
    final excluded = <String, Set<String>>{
      'country': {},
      'city': {},
      'landmark': {},
    };
    final countryByA3 = {
      for (final c in countries.allCountries) c.isoA3: c.isoA2,
    };
    for (final c in countries.allCountries) {
      final detail = countries.visitDetails[c.name];
      if (detail == null || (!detail.isVisited && !detail.hasLived)) continue;
      final place = model.resolve('country', c.name, country: c.isoA2);
      if (place != null) excluded['country']!.add(place.id);
      if (detail.hasLived || !detail.isVisited) continue;
      countryVisits.add(
        DiscoverVisit(
          place?.id ?? 'country:${c.isoA2}',
          place?.scores ?? {},
          detail.rating,
        ),
      );
    }
    for (final entry in cities.visitDetails.entries) {
      final detail = entry.value;
      if (detail.visitCount <= 0 && !detail.isHome && !detail.hasLived)
        continue;
      // Saved city records contain a name only. Never guess among namesakes.
      final options = cities.allCities
          .where((c) => c.name == entry.key)
          .toList();
      final uniqueIdentity = options
          .map((c) => '${c.countryIsoA2}|${c.latitude}|${c.longitude}')
          .toSet();
      final place = uniqueIdentity.length == 1
          ? model.resolve(
              'city',
              entry.key,
              country: options.first.countryIsoA2,
              latitude: options.first.latitude,
              longitude: options.first.longitude,
            )
          : null;
      for (final p in model.places.where(
        (p) =>
            p.kind == 'city' && (p.data['aliases'] as List).contains(entry.key),
      )) {
        // Ambiguous recorded names are conservatively omitted from candidates too.
        excluded['city']!.add(p.id);
      }
      if (detail.isHome || entry.key == cities.homeCityName || detail.hasLived)
        continue;
      cityVisits.add(
        DiscoverVisit(
          place?.id ?? 'city:${entry.key}',
          place?.scores ?? {},
          detail.rating,
        ),
      );
    }
    final landmarkIdentities = <String, Set<String>>{};
    for (final l in landmarks.allLandmarks) {
      landmarkIdentities
          .putIfAbsent(l.name, () => {})
          .add('${l.countriesIsoA3.join(',')}|${l.latitude}|${l.longitude}');
    }
    for (final l in landmarks.allLandmarks) {
      if (!landmarks.visitedLandmarks.contains(l.name)) continue;
      if (landmarkIdentities[l.name]!.length != 1) continue;
      final place = model.resolve(
        'landmark',
        l.name,
        country: l.countriesIsoA3.isEmpty
            ? null
            : countryByA3[l.countriesIsoA3.first],
        latitude: l.latitude,
        longitude: l.longitude,
      );
      if (place != null) excluded['landmark']!.add(place.id);
      if (!model.isEligibleLandmark(l.name, l.attributes)) continue;
      landmarkVisits.add(
        DiscoverVisit(
          place?.id ?? 'landmark:${l.name}|${l.latitude}|${l.longitude}',
          place?.scores ?? {},
          l.rating ?? 0,
        ),
      );
    }

    return DiscoverUserProfile({
      'country': countryVisits,
      'city': cityVisits,
      'landmark': landmarkVisits,
    }, excluded);
  }
}
