import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android Play 설치 리퍼러를 기기당 1번 install_referrers/{deviceId}에 남긴다.
/// orders 문서에도 deviceId가 있어서, 광고 플랫폼 숫자와 별개로
/// "어느 캠페인으로 설치된 기기가 결제했는지"를 우리 데이터로 직접 볼 수 있다.
class InstallReferrerService {
  static const _channel = MethodChannel('com.ahnlee.jidoapp/install_referrer');
  static const _prefKeyDone = 'install_referrer_recorded_v1';

  static Future<void> recordOnce(String? deviceId) async {
    if (!Platform.isAndroid || deviceId == null || deviceId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKeyDone) == true) return;

      final raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getInstallReferrer')
          .timeout(const Duration(seconds: 10));
      if (raw == null) return;

      final referrer = raw['referrer'] as String?;
      final data = <String, dynamic>{
        'deviceId': deviceId,
        'platform': 'android',
        'recordedAt': FieldValue.serverTimestamp(),
        if (referrer != null)
          'referrer': referrer.length > 1900
              ? referrer.substring(0, 1900)
              : referrer,
        if (raw['clickTs'] is num) 'clickTs': raw['clickTs'],
        if (raw['installTs'] is num) 'installTs': raw['installTs'],
        if (raw['instantExperience'] is bool)
          'instantExperience': raw['instantExperience'],
        if (raw['error'] is String) 'error': raw['error'],
      };

      try {
        await FirebaseFirestore.instance
            .collection('install_referrers')
            .doc(deviceId)
            .set(data);
      } on FirebaseException catch (e) {
        // 이미 기록된 기기면 규칙상 덮어쓰기가 거부된다 → 완료로 본다.
        if (e.code != 'permission-denied') rethrow;
      }
      // 서비스 일시 끊김이면 다음 실행 때 다시 시도
      if (raw['error'] == 'disconnected') return;
      await prefs.setBool(_prefKeyDone, true);
      debugPrint('[InstallReferrer] recorded: $referrer');
    } catch (e) {
      debugPrint('[InstallReferrer] error: $e');
    }
  }
}
