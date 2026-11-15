import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Apple Search Ads attribution via the AdServices framework.
///
/// Once per install (iOS only): get the AdServices token from the native
/// channel, exchange it at Apple's attribution API and store the result in
/// Firestore `adservices_attribution/{uid or install id}`. No ATT needed.
///
/// Apple returns 404 until the attribution record is ready, so each launch
/// tries [_attemptsPerLaunch] times and the whole thing is retried on the next
/// launch, up to [_maxLaunches] launches.
class AdServicesAttribution {
  AdServicesAttribution._();

  static const MethodChannel _channel = MethodChannel('travelog/adservices');
  static final Uri _endpoint = Uri.parse(
    'https://api-adservices.apple.com/api/v1/',
  );

  static const String _prefDone = 'adservices_attribution_done';
  static const String _prefLaunches = 'adservices_attribution_launches';
  static const String _prefInstallId = 'adservices_install_id';
  // Same key AdService uses, so attribution docs join with ad/app-open events.
  static const String _prefAdDeviceId = 'ad_experiment_device_id';

  static const int _maxLaunches = 3;
  static const int _attemptsPerLaunch = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  static const List<String> _fields = [
    'attribution',
    'orgId',
    'campaignId',
    'adGroupId',
    'keywordId',
    'countryOrRegion',
    'conversionType',
    'clickDate',
    'adId',
    'claimType',
  ];

  static bool _started = false;

  /// Fire-and-forget. Never throws, never blocks startup.
  static Future<void> runOnce() async {
    if (_started || kIsWeb) return;
    _started = true;
    try {
      if (!Platform.isIOS || Firebase.apps.isEmpty) return;
      await _run();
    } catch (e) {
      if (kDebugMode) debugPrint('[ASA] attribution failed: $e');
    }
  }

  static Future<void> _run() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefDone) ?? false) return;

    final launches = (prefs.getInt(_prefLaunches) ?? 0) + 1;
    if (launches > _maxLaunches) return;
    await prefs.setInt(_prefLaunches, launches);

    final token = await _channel.invokeMethod<String>('getAttributionToken');
    if (token == null || token.isEmpty) {
      // iOS < 14.3 or token unavailable (e.g. simulator) — nothing to retry.
      if (kDebugMode) debugPrint('[ASA] no attribution token');
      await prefs.setBool(_prefDone, true);
      return;
    }

    Map<String, dynamic>? data;
    for (var attempt = 1; attempt <= _attemptsPerLaunch; attempt++) {
      if (attempt > 1) await Future<void>.delayed(_retryDelay);
      final res = await http
          .post(
            _endpoint,
            headers: const {'Content-Type': 'text/plain'},
            body: token,
          )
          .timeout(const Duration(seconds: 15));
      if (kDebugMode) {
        debugPrint('[ASA] attempt $attempt → HTTP ${res.statusCode}');
      }
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) data = decoded;
        break;
      }
      // 404 = not ready yet; 400 = bad/expired token (a fresh token is
      // fetched next launch); 5xx = transient. All retried within limits.
    }
    if (data == null) return;

    final installId = await _installId(prefs);
    final uid = await _currentUid();
    final appVersion = await _appVersion();

    final doc = <String, dynamic>{
      for (final f in _fields)
        if (data.containsKey(f)) f: data[f],
      'platform': 'ios',
      'appVersion': appVersion,
      'uid': uid,
      'deviceId': installId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('adservices_attribution')
        .doc(uid ?? installId)
        .set(doc);
    await prefs.setBool(_prefDone, true);

    if (data['attribution'] == true) {
      await FirebaseAnalytics.instance.logEvent(
        name: 'asa_attribution',
        parameters: {
          for (final f in const ['campaignId', 'adGroupId', 'keywordId'])
            if (data[f] != null) f: data[f].toString(),
        },
      );
    }
  }

  static Future<String> _installId(SharedPreferences prefs) async {
    final adDeviceId = prefs.getString(_prefAdDeviceId);
    if (adDeviceId != null && adDeviceId.isNotEmpty) return adDeviceId;
    var id = prefs.getString(_prefInstallId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_prefInstallId, id);
    }
    return id;
  }

  /// Signed-in uid if Firebase Auth restores one shortly; guests → null.
  static Future<String?> _currentUid() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser!.uid;
    try {
      final user = await auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 3));
      return user?.uid;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _appVersion() async {
    try {
      return await _channel.invokeMethod<String>('getAppVersion');
    } catch (_) {
      return null;
    }
  }
}
