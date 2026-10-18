/// One contract for bundled statistics, independent of the screen consuming it.
/// Null metadata means unknown, never the date of the schema migration.
class StatisticsMetadata {
  final String? sourceUrl;
  final String? referencePeriod;
  final String? updatedAt;

  const StatisticsMetadata({
    this.sourceUrl,
    this.referencePeriod,
    this.updatedAt,
  });

  factory StatisticsMetadata.fromJson(Map<String, dynamic> json) {
    for (final key in ['source_url', 'reference_period', 'updated_at']) {
      if (!json.containsKey(key) ||
          (json[key] != null && json[key] is! String)) {
        throw FormatException('Invalid statistics metadata: $key');
      }
    }
    return StatisticsMetadata(
      sourceUrl: json['source_url'] as String?,
      referencePeriod: json['reference_period'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class StatisticsMetric {
  final String id;
  final String? unit;
  final StatisticsMetadata metadata;

  StatisticsMetric._(this.id, this.unit, this.metadata);

  factory StatisticsMetric.fromJson(Map<String, dynamic> json) {
    final id = _id(json['id']);
    if (!json.containsKey('unit') ||
        (json['unit'] != null && json['unit'] is! String)) {
      throw FormatException('Invalid unit for metric $id');
    }
    return StatisticsMetric._(
      id,
      json['unit'] as String?,
      StatisticsMetadata.fromJson(json),
    );
  }
}

class StatisticsRecord {
  final Map<String, dynamic> dimensions;
  final Map<String, dynamic> values;

  StatisticsRecord._(this.dimensions, this.values);

  /// Missing/null and zero remain distinct; strings are never coerced to numbers.
  num? number(String metricId) =>
      values[metricId] is num ? values[metricId] as num : null;

  Map<String, dynamic> toLegacyJson() =>
      _copy({...dimensions, ...values}) as Map<String, dynamic>;
}

class StatisticsTable {
  final String id;
  final StatisticsMetadata metadata;
  final List<String> dimensions;
  final List<StatisticsMetric> metrics;
  final List<StatisticsRecord> records;

  StatisticsTable._(
    this.id,
    this.metadata,
    this.dimensions,
    this.metrics,
    this.records,
  );

  factory StatisticsTable.fromJson(Map<String, dynamic> json) {
    final id = _id(json['id']);
    final dimensions = _list(json['dimensions']).map(_id).toList();
    final metrics = _list(
      json['metrics'],
    ).map((v) => StatisticsMetric.fromJson(_map(v))).toList();
    final metricIds = metrics.map((m) => m.id).toSet();
    if (dimensions.toSet().length != dimensions.length ||
        metricIds.length != metrics.length ||
        dimensions.any(metricIds.contains)) {
      throw FormatException('Duplicate dimensions or metrics in $id');
    }
    final records = <StatisticsRecord>[];
    for (final value in _list(json['records'])) {
      final row = _map(value);
      final keys = _map(row['dimensions']);
      final values = _map(row['values']);
      if (keys.keys.any((k) => !dimensions.contains(k)) ||
          values.keys.any((k) => !metricIds.contains(k))) {
        throw FormatException('Undeclared field in table $id');
      }
      records.add(
        StatisticsRecord._(
          _freeze(keys) as Map<String, dynamic>,
          _freeze(values) as Map<String, dynamic>,
        ),
      );
    }
    return StatisticsTable._(
      id,
      StatisticsMetadata.fromJson(_map(json['metadata'])),
      List.unmodifiable(dimensions),
      List.unmodifiable(metrics),
      List.unmodifiable(records),
    );
  }
}

class StatisticsDataset {
  static const schemaVersion = 1;
  final String id;
  final StatisticsMetadata metadata;
  final List<StatisticsTable> tables;
  final String _legacyLayout;

  StatisticsDataset._(this.id, this.metadata, this.tables, this._legacyLayout);

  factory StatisticsDataset.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] is! int ||
        json['schema_version'] != schemaVersion) {
      throw FormatException(
        'Unsupported statistics schema: ${json['schema_version']}',
      );
    }
    final id = _id(json['dataset_id']);
    final tables = _list(
      json['tables'],
    ).map((v) => StatisticsTable.fromJson(_map(v))).toList();
    final layout = json['legacy_layout'];
    if (tables.map((t) => t.id).toSet().length != tables.length ||
        (layout != 'list' && layout != 'sections') ||
        (layout == 'list' &&
            (tables.length != 1 || tables.single.id != 'main'))) {
      throw FormatException('Invalid table layout in $id');
    }
    return StatisticsDataset._(
      id,
      StatisticsMetadata.fromJson(_map(json['metadata'])),
      List.unmodifiable(tables),
      layout as String,
    );
  }

  StatisticsTable table([String id = 'main']) =>
      tables.firstWhere((table) => table.id == id);

  /// Temporary boundary for existing domain models and background isolates.
  /// New consumers should read tables/records directly.
  dynamic toLegacyJson() {
    final data = {
      for (final table in tables)
        table.id: table.records.map((r) => r.toLegacyJson()).toList(),
    };
    return _legacyLayout == 'list' ? data['main']! : data;
  }
}

String _id(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException(
      'Statistics identifier must be a nonempty string',
    );
  }
  return value;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected statistics object');
  }
  return value;
}

List<dynamic> _list(dynamic value) {
  if (value is! List) {
    throw const FormatException('Expected statistics list');
  }
  return value;
}

dynamic _freeze(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
      value.map((k, v) => MapEntry(k, _freeze(v))),
    );
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

dynamic _copy(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map((k, v) => MapEntry(k, _copy(v)));
  }
  if (value is List) return value.map(_copy).toList();
  return value;
}
