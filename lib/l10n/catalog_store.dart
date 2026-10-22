import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Where translation catalogs come from: a copy saved on the device, the app
/// bundle (languages built with `"bundled": true`), or Firebase Storage.
///
/// Files are published by tool/l10n/publish.py under content-hashed names, so
/// a saved copy is valid for as long as the manifest still names it.
class CatalogStore {
  CatalogStore({http.Client? client, this.directory})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Overrides the cache directory (tests). Defaults to app support storage.
  final Future<Directory> Function()? directory;

  static const bundledManifest = 'assets/l10n/languages.json';

  /// The newer of the bundled manifest and the last one downloaded.
  Future<Map<String, dynamic>> manifest() async {
    final bundled = _decode(
      utf8.encode(await rootBundle.loadString(bundledManifest)),
    )!;
    final saved = await _read('languages.json');
    final cached = saved == null ? null : _decode(saved);
    return cached != null && _version(cached) > _version(bundled)
        ? cached
        : bundled;
  }

  /// Fetches the published manifest and returns it only if it is newer.
  Future<Map<String, dynamic>?> refreshManifest(
    Map<String, dynamic> current,
  ) async {
    final bytes = await _download(current, 'languages.json');
    if (bytes == null) return null;
    final remote = _decode(bytes);
    if (remote == null || _version(remote) <= _version(current)) return null;
    await _write('languages.json', bytes);
    return remote;
  }

  /// A saved or bundled catalog, without touching the network.
  Future<Map<String, dynamic>?> local(Map<String, dynamic> entry) async {
    final saved = await _read(entry['file'] as String);
    if (saved != null && _matches(saved, entry)) return _decode(saved);
    if (entry['bundled'] == true) {
      return _decode(
        utf8.encode(
          await rootBundle.loadString('assets/l10n/${entry['code']}.json'),
        ),
      );
    }
    return null;
  }

  /// Downloads, verifies and saves a catalog. Null when offline or corrupt.
  Future<Map<String, dynamic>?> fetch(
    Map<String, dynamic> manifest,
    Map<String, dynamic> entry,
  ) async {
    final file = entry['file'] as String;
    final bytes = await _download(manifest, file);
    if (bytes == null) return null;
    if (!_matches(bytes, entry)) {
      debugPrint('[l10n] checksum mismatch for $file');
      return null;
    }
    await _write(file, bytes);
    await _prune(entry['code'] as String, file);
    return _decode(bytes);
  }

  bool _matches(List<int> bytes, Map<String, dynamic> entry) =>
      sha256.convert(bytes).toString() == entry['sha256'];

  static int _version(Map<String, dynamic>? manifest) =>
      (manifest?['version'] as num?)?.toInt() ?? 0;

  static Map<String, dynamic>? _decode(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _download(Map<String, dynamic> manifest, String name) async {
    final path = Uri.encodeComponent('${manifest['prefix']}$name');
    final url = Uri.parse('${manifest['base_url']}$path?alt=media');
    try {
      // Objects are stored gzip-encoded; the HTTP client inflates them.
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) return response.bodyBytes;
      debugPrint('[l10n] $name: HTTP ${response.statusCode}');
    } catch (error) {
      debugPrint('[l10n] $name: $error');
    }
    return null;
  }

  Future<Directory?> _cacheDirectory() async {
    if (kIsWeb) return null;
    try {
      final base = await (directory?.call() ?? getApplicationSupportDirectory());
      return Directory('${base.path}/l10n').create(recursive: true);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _read(String name) async {
    final dir = await _cacheDirectory();
    final file = dir == null ? null : File('${dir.path}/$name');
    return file != null && await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> _write(String name, List<int> bytes) async {
    final dir = await _cacheDirectory();
    if (dir == null) return;
    // Write then rename, so a crash never leaves a half-written catalog.
    final temp = File('${dir.path}/$name.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename('${dir.path}/$name');
  }

  /// Drops older versions of a language once a newer one is saved.
  Future<void> _prune(String code, String keep) async {
    final dir = await _cacheDirectory();
    if (dir == null) return;
    // Exact match on the code, so pruning `pt` never touches `pt-BR` files.
    final versionOf = RegExp('^${RegExp.escape(code)}-[0-9a-f]{16}\\.json\$');
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (name != keep && versionOf.hasMatch(name)) await entity.delete();
    }
  }
}
