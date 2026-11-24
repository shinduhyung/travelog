import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/services/admin_region_repository.dart';
import 'package:jidoapp/models/admin_region.dart';
import 'package:jidoapp/providers/subregion_provider.dart';
import 'package:jidoapp/utils/point_in_polygon.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every country exposed by the app has a region map or explicit outline',
    () async {
      final all = await AdminRegionRepository.loadAll();
      final countries = jsonDecode(
        File('assets/custom.geo.json').readAsStringSync(),
      );
      const excluded = {
        'Indian Ocean Ter.',
        'Siachen Glacier',
        'Antarctica',
        'N. Cyprus',
        'Northern Cyprus',
        'Ashmore and Cartier Is.',
      };
      for (final feature in countries['features']) {
        final p = feature['properties'];
        if (excluded.contains(p['name'])) continue;
        expect(
          all[p['iso_a2']],
          isNotEmpty,
          reason: '${p['name']} (${p['iso_a2']})',
        );
      }
      expect(all.length, 238);
      expect(all['US']!.length, 51);
      expect(all['KI']!.length, 3);
      expect(all['TV']!.length, 8);
      expect(all['NU']!.length, 14);
      expect(all.values.where((r) => r.every((v) => v.isWholeArea)).length, 25);
      expect(
        all.values.expand((r) => r).where((r) => !r.isWholeArea).length,
        4501, // Malta 68 councils -> 6 districts (2026-11)
      );
    },
  );

  // Crimea (UA-43) and Sevastopol (UA-40) moved from RU to UA on 2026-11-24;
  // every other original key is unchanged.
  test('original 30-country names and visit keys remain identical', () async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/admin1_regions.geojson'),
    );
    const legacy = {
      'AE',
      'AR',
      'AT',
      'AU',
      'BR',
      'CA',
      'CH',
      'CN',
      'DE',
      'EG',
      'ES',
      'FR',
      'GB',
      'GR',
      'ID',
      'IN',
      'IT',
      'JP',
      'KR',
      'MX',
      'MY',
      'NL',
      'PH',
      'PT',
      'RU',
      'TH',
      'TR',
      'US',
      'VN',
      'ZA',
    };
    final rows = <List<String>>[];
    for (final f in data['features']) {
      final p = f['properties'];
      if (!legacy.contains(p['iso_a2']) || p['name'] == null || p['name'] == '') {
        continue;
      }
      expect(p['storage_key'], isNull);
      rows.add([
        p['iso_a2'] as String,
        p['name'] as String,
        p['iso_3166_2'] as String? ?? '',
      ]);
    }
    rows.sort((a, b) {
      for (var i = 0; i < 3; i++) {
        final result = a[i].compareTo(b[i]);
        if (result != 0) return result;
      }
      return 0;
    });
    expect(
      sha256.convert(utf8.encode(jsonEncode(rows))).toString(),
      'b7dc78914d70396e43db925bd2aebdc538f3f79eb30064d819649e0f1a365368',
    );
  });

  test(
    'new countries have independent keys even when source ISO codes collide',
    () async {
      final all = await AdminRegionRepository.loadAll();
      for (final iso in ['MG', 'BA', 'IE', 'LV', 'KZ', 'AF']) {
        final regions = all[iso]!;
        expect(
          regions.map((r) => r.stableKey).toSet().length,
          regions.length,
          reason: iso,
        );
      }
      final kazakhstan = all['KZ']!
          .where((r) => r.iso31662 == 'KZ-ALA')
          .toList();
      expect(kazakhstan.length, 2);
      expect(kazakhstan[0].stableKey, isNot(kazakhstan[1].stableKey));
    },
  );

  test('all parsed region polygons and camera bounds are usable', () async {
    final all = await AdminRegionRepository.loadAll();
    for (final entry in all.entries) {
      expect(
        AdminRegionRepository.fitBoundsFor(entry.key, entry.value),
        isNotNull,
      );
      for (final region in entry.value) {
        expect(region.polygonsData, isNotEmpty, reason: region.name);
        for (final polygon in region.polygonsData) {
          expect(polygon, isNotEmpty);
          for (final ring in polygon) {
            expect(ring.length, greaterThanOrEqualTo(4), reason: region.name);
            expect(ring.first, ring.last);
          }
        }
      }
    }
    for (final iso in ['NZ', 'FJ', 'KI']) {
      final bounds = AdminRegionRepository.fitBoundsFor(iso, all[iso]!)!;
      expect(bounds.east - bounds.west, lessThan(30), reason: iso);
    }
  });

  test('supplementary maps identify a real village on tap', () async {
    final niue = await AdminRegionRepository.regionsFor('NU');
    final alofi = niue.where(
      (r) => isPointInRegion(const LatLng(-19.055, -169.917), r.polygonsData),
    );
    expect(alofi, hasLength(1));
    expect(alofi.single.name, contains('Alofi'));
  });

  test('whole-area outlines are explicitly marked in the model', () {
    final feature = jsonDecode(
      File('assets/admin1_regions.geojson').readAsStringSync(),
    )['features'].firstWhere((f) => f['properties']['iso_a2'] == 'VA');
    final region = AdminRegion.fromFeature(Map<String, dynamic>.from(feature));
    expect(region.isWholeArea, isTrue);
    expect(region.typeLabel, 'Whole area');
  });
  test('Malta uses the 6 statistical districts', () async {
    final malta = await AdminRegionRepository.regionsFor('MT');
    expect(malta.map((r) => r.name).toSet(), {
      'Southern Harbour',
      'Northern Harbour',
      'South Eastern',
      'Western',
      'Northern',
      'Gozo and Comino',
    });
    final valletta = malta.where(
      (r) => isPointInRegion(const LatLng(35.8989, 14.5146), r.polygonsData),
    );
    expect(valletta.single.name, 'Southern Harbour');
    final victoria = malta.where(
      (r) => isPointInRegion(const LatLng(36.0444, 14.2397), r.polygonsData),
    );
    expect(victoria.single.name, 'Gozo and Comino');
  });

  test('Crimea and Sevastopol are Ukrainian regions', () async {
    final all = await AdminRegionRepository.loadAll();
    final ua = all['UA']!.map((r) => r.stableKey).toSet();
    final ru = all['RU']!.map((r) => r.stableKey).toSet();
    expect(ua, containsAll(['UA-43', 'UA-40']));
    expect(ru.intersection({'UA-43', 'UA-40'}), isEmpty);
    expect(all['UA']!.length, 27);
    expect(all['RU']!.length, 83);

    final countries = jsonDecode(File('assets/custom.geo.json').readAsStringSync());
    String? countryAt(LatLng point) {
      for (final f in countries['features']) {
        final g = f['geometry'];
        final polys = g['type'] == 'Polygon' ? [g['coordinates']] : g['coordinates'];
        final parts = <List<List<LatLng>>>[
          for (final poly in polys)
            [
              for (final ring in poly)
                [for (final p in ring) LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())],
            ],
        ];
        if (isPointInRegion(point, parts)) return f['properties']['iso_a2'] as String;
      }
      return null;
    }

    expect(countryAt(const LatLng(45.0, 34.1)), 'UA'); // central Crimea
    expect(countryAt(const LatLng(55.75, 37.62)), 'RU'); // Moscow
  });

  test('saved region keys migrate to the new regions once', () {
    final table = jsonDecode(
      File('assets/admin1_key_migration.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final visited = <String, Set<String>>{
      'MLT': {'MT-60', 'MT-56', 'MT-45'}, // Valletta, Sliema, Victoria
      'RUS': {'RU-MOW', 'UA-43'},
      'KOR': {'KR-11'},
    };
    expect(SubregionProvider.migrateVisitedRegionKeys(visited, table), isTrue);
    expect(visited['MLT'], {
      'MT::Southern Harbour',
      'MT::Northern Harbour',
      'MT::Gozo and Comino',
    });
    expect(visited['RUS'], {'RU-MOW'});
    expect(visited['UKR'], {'UA-43'});
    expect(visited['KOR'], {'KR-11'});
    expect(SubregionProvider.migrateVisitedRegionKeys(visited, table), isFalse);
  });
}
