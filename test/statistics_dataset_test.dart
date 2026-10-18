import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/models/statistics_dataset.dart';
import 'package:jidoapp/services/statistics_assets.dart';
import 'package:jidoapp/services/statistics_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every migrated asset preserves all legacy values, types and row order',
    () async {
      final baseline =
          jsonDecode(
                File(
                  'test/fixtures/statistics_legacy_fingerprints.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(statisticsAssetPaths, baseline.keys.toSet());
      final repository = StatisticsRepository(bundle: _FileBundle());
      var recordCount = 0;
      for (final path in statisticsAssetPaths) {
        final dataset = await repository.load(path);
        expect(
          _fingerprint(dataset.toLegacyJson()),
          baseline[path],
          reason: path,
        );
        expect(
          _fingerprint(jsonDecode(await repository.loadLegacyString(path))),
          baseline[path],
          reason: 'Compatibility adapter: $path',
        );
        recordCount += dataset.tables.fold<int>(
          0,
          (sum, t) => sum + t.records.length,
        );
      }
      expect(recordCount, 7982);
    },
  );

  test('shares concurrent reads, reuses adapters and clears caches', () async {
    final bundle = _FileBundle();
    final repository = StatisticsRepository(bundle: bundle);
    const path = 'assets/economy_data.json';
    final datasets = await Future.wait([
      repository.load(path),
      repository.load(path),
    ]);
    expect(identical(datasets.first, datasets.last), isTrue);
    await repository.loadLegacyString(path);
    await repository.loadLegacyString(path);
    expect(bundle.reads, 1);
    repository.clearCache();
    await repository.load(path);
    expect(bundle.reads, 2);
  });

  test('failed reads and adapters can be retried', () async {
    final bundle = _FileBundle()..failNext = true;
    final repository = StatisticsRepository(bundle: bundle);
    const path = 'assets/health.json';
    await expectLater(repository.loadLegacyString(path), throwsStateError);
    expect(jsonDecode(await repository.loadLegacyString(path)), isA<Map>());
    expect(bundle.reads, 2);
  });

  test(
    'zero, missing, null and strings remain distinct; cached records are immutable',
    () {
      final data = _sample();
      final records = data['tables'][0]['records'] as List;
      records.add({
        'dimensions': {'iso_a3': 'USA'},
        'values': {
          'amount': null,
          'label': ['test'],
        },
      });
      final dataset = StatisticsDataset.fromJson(data);
      expect(dataset.metadata.sourceUrl, isNull);
      expect(dataset.table().records.first.number('amount'), 0);
      expect(dataset.table().records.first.number('missing'), isNull);
      expect(dataset.table().records.last.number('amount'), isNull);
      expect(dataset.table().records.first.number('label'), isNull);
      expect(
        () => dataset.table().records.first.values['amount'] = 2,
        throwsUnsupportedError,
      );
      expect(
        () => (dataset.table().records.last.values['label'] as List).add('bad'),
        throwsUnsupportedError,
      );
      final legacy = dataset.toLegacyJson() as List;
      (legacy.last['label'] as List).add('changed');
      expect(dataset.table().records.last.values['label'], ['test']);
      expect(dataset.toLegacyJson().first['label'], '0');
    },
  );

  test(
    'rejects unsupported schemas, duplicate tables and undeclared metrics',
    () {
      expect(
        () => StatisticsDataset.fromJson(_sample()..['schema_version'] = 2),
        throwsFormatException,
      );
      final duplicate = _sample()..['legacy_layout'] = 'sections';
      duplicate['tables'].add(duplicate['tables'].first);
      expect(
        () => StatisticsDataset.fromJson(duplicate),
        throwsFormatException,
      );
      final extra = _sample();
      extra['tables'][0]['records'][0]['values']['undeclared'] = 1;
      expect(() => StatisticsDataset.fromJson(extra), throwsFormatException);
      final metadata = _sample()..['metadata'] = {'source_url': null};
      expect(() => StatisticsDataset.fromJson(metadata), throwsFormatException);
    },
  );

  test(
    'rejects dataset identity mismatches and malformed registered assets',
    () async {
      final wrong = _sample()..['dataset_id'] = 'wrong';
      final repository = StatisticsRepository(
        bundle: _TextBundle(jsonEncode(wrong)),
      );
      await expectLater(
        repository.load('assets/sample.json'),
        throwsFormatException,
      );
      final legacy = StatisticsRepository(bundle: _TextBundle('[]'));
      await expectLater(
        legacy.loadLegacyString('assets/health.json'),
        throwsFormatException,
      );
    },
  );

  test(
    'passes non-statistical assets through without treating them as statistics',
    () async {
      final repository = StatisticsRepository(
        bundle: _TextBundle('{"catalogue":true}'),
      );
      expect(
        await repository.loadLegacyString('assets/catalogue.json'),
        '{"catalogue":true}',
      );
    },
  );
}

Map<String, dynamic> _sample() {
  final metadata = {
    'source_url': null,
    'reference_period': null,
    'updated_at': null,
  };
  return {
    'schema_version': 1,
    'dataset_id': 'sample',
    'legacy_layout': 'list',
    'metadata': {...metadata},
    'tables': <dynamic>[
      {
        'id': 'main',
        'metadata': {...metadata},
        'dimensions': ['iso_a3'],
        'metrics': [
          {'id': 'amount', 'unit': null, ...metadata},
          {'id': 'label', 'unit': null, ...metadata},
        ],
        'records': <dynamic>[
          {
            'dimensions': {'iso_a3': 'KOR'},
            'values': {'amount': 0, 'label': '0'},
          },
        ],
      },
    ],
  };
}

class _FileBundle extends CachingAssetBundle {
  var reads = 0;
  var failNext = false;
  @override
  Future<ByteData> load(String key) async {
    reads++;
    if (failNext) {
      failNext = false;
      throw StateError('Temporary read failure');
    }
    return ByteData.sublistView(await File(key).readAsBytes());
  }
}

class _TextBundle extends CachingAssetBundle {
  final String value;
  _TextBundle(this.value);
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
}

/// Same structural fingerprint as tool/verify_statistics_migration.py.
String _fingerprint(dynamic value) {
  final bytes = BytesBuilder();
  void text(String s) => bytes.add(utf8.encode(s));
  void emit(dynamic v) {
    if (v == null) {
      text('n');
    } else if (v is bool) {
      text(v ? 't' : 'f');
    } else if (v is int) {
      text('i$v;');
    } else if (v is double) {
      text('d');
      bytes.add(
        (ByteData(8)..setFloat64(0, v, Endian.big)).buffer.asUint8List(),
      );
    } else if (v is String) {
      final encoded = utf8.encode(v);
      text('s${encoded.length}:');
      bytes.add(encoded);
    } else if (v is List) {
      text('[');
      for (final item in v) {
        emit(item);
      }
      text(']');
    } else if (v is Map<String, dynamic>) {
      text('{');
      final keys = v.keys.toList()..sort();
      for (final key in keys) {
        emit(key);
        emit(v[key]);
      }
      text('}');
    } else {
      throw StateError('Unexpected JSON value $v');
    }
  }

  emit(value);
  return sha256.convert(bytes.takeBytes()).toString();
}
