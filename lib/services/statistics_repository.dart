import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:jidoapp/models/statistics_dataset.dart';
import 'statistics_assets.dart';

/// Shared, injectable loader. Concurrent consumers share one validated dataset.
class StatisticsRepository {
  final AssetBundle _bundle;
  final Map<String, Future<StatisticsDataset>> _datasets = {};
  final Map<String, Future<String>> _legacyStrings = {};

  static final instance = StatisticsRepository();

  StatisticsRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  Future<StatisticsDataset> load(String path) {
    final cached = _datasets[path];
    if (cached != null) return cached;
    late final Future<StatisticsDataset> pending;
    pending = Future<StatisticsDataset>(() async {
      try {
        final raw = jsonDecode(await _bundle.loadString(path, cache: false));
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Expected statistics dataset object');
        }
        final dataset = StatisticsDataset.fromJson(raw);
        final expectedId = path
            .split('/')
            .last
            .replaceFirst(RegExp(r'\.json$'), '');
        if (dataset.id != expectedId) {
          throw FormatException(
            'Statistics id mismatch: $path / ${dataset.id}',
          );
        }
        return dataset;
      } catch (_) {
        // A transient read failure must not poison future loads.
        if (identical(_datasets[path], pending)) {
          _datasets.remove(path);
        }
        rethrow;
      }
    });
    _datasets[path] = pending;
    return pending;
  }

  /// Compatibility adapter while existing screen/domain models are retained.
  /// Non-statistical assets (GeoJSON, airport catalogues, etc.) pass through.
  Future<String> loadLegacyString(String path) {
    if (!statisticsAssetPaths.contains(path)) return _bundle.loadString(path);
    final cached = _legacyStrings[path];
    if (cached != null) return cached;
    late final Future<String> pending;
    pending = Future<String>(() async {
      try {
        return jsonEncode((await load(path)).toLegacyJson());
      } catch (_) {
        if (identical(_legacyStrings[path], pending)) {
          _legacyStrings.remove(path);
        }
        rethrow;
      }
    });
    _legacyStrings[path] = pending;
    return pending;
  }

  void clearCache() {
    _datasets.clear();
    _legacyStrings.clear();
  }
}
