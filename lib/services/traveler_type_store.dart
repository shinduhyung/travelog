// lib/services/traveler_type_store.dart
//
// 여행자 타입 AI 분석 결과(ai_analysis_result)의 저장/동기화 담당.
//
// - 결과 JSON 안에 engine_version / generated_at 을 넣어 두고, 현재 엔진 버전이
//   아닌 결과(예전 계산식)는 로컬/서버 모두에서 무효로 보고 지운다.
// - 분석 직후 바로 Firestore에 저장한다. 실패하면 로컬에는 남고, 다음 앱 시작 /
//   로그인 때 sync()가 generated_at 이 더 최신인 쪽을 기준으로 다시 맞춘다.
//   (예전에는 앱 재시작 시 서버의 옛 값이 새 결과를 덮어썼다.)

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelerTypeStore {
  TravelerTypeStore._();

  /// 점수 계산식을 바꿀 때마다 올린다. 이전 버전 결과는 자동으로 폐기된다.
  static const int currentVersion = 2;

  static const String resultKey = 'ai_analysis_result';
  static const String updatedAtField = 'ai_analysis_updated_at';
  static const String _legacyTypeKey = 'traveler_type';
  static const Duration _serverTimeout = Duration(seconds: 15);

  static Map<String, dynamic>? _parse(String? json) {
    if (json == null) return null;
    try {
      final parsed = jsonDecode(json);
      return parsed is Map<String, dynamic> ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  /// 현재 엔진 버전으로 만든, 점수가 들어 있는 결과인가.
  static bool isValid(String? json) {
    final parsed = _parse(json);
    if (parsed == null) return false;
    if (parsed['engine_version'] != currentVersion) return false;
    final scores = parsed['summary']?['persona_scores'];
    return scores is List && scores.isNotEmpty;
  }

  static int _stamp(String? json) {
    final v = _parse(json)?['generated_at'];
    return v is num ? v.toInt() : 0;
  }

  /// 로컬에 남아 있는 예전 버전 결과 삭제.
  static Future<void> purgeStaleLocal(SharedPreferences prefs) async {
    final raw = prefs.getString(resultKey);
    if (raw != null && !isValid(raw)) {
      await prefs.remove(resultKey);
      await prefs.remove(_legacyTypeKey);
    }
  }

  /// 분석 결과 저장: 로컬 먼저, 이어서 서버. 서버 저장 성공 여부를 반환.
  static Future<bool> saveResult(String json) async {
    if (!isValid(json)) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(resultKey, json);
    return _push(json);
  }

  static Future<bool> _push(String json) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false; // 로그인 후 sync()/uploadLocal이 올린다
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        resultKey: json,
        updatedAtField: _stamp(json),
      }, SetOptions(merge: true)).timeout(_serverTimeout);
      return true;
    } catch (e) {
      debugPrint('⚠️ [TravelerTypeStore] server save failed (will retry on next sync): $e');
      return false;
    }
  }

  static Future<void> _deleteServer(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        resultKey: FieldValue.delete(),
        updatedAtField: FieldValue.delete(),
      }).timeout(_serverTimeout);
    } catch (e) {
      debugPrint('⚠️ [TravelerTypeStore] stale server result delete failed: $e');
    }
  }

  /// 서버 문서([serverData])와 로컬을 맞춘다. generated_at 이 더 최신인 쪽이 이긴다.
  /// 서버의 옛 버전 결과는 서버에서도 삭제.
  static Future<void> sync(
      SharedPreferences prefs, Map<String, dynamic> serverData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final localRaw = prefs.getString(resultKey);
    final serverRaw = serverData[resultKey] as String?;
    final localOk = isValid(localRaw);
    final serverOk = isValid(serverRaw);

    if (serverRaw != null && !serverOk) {
      await _deleteServer(user.uid); // 옛 계산식 결과 폐기
    }

    final localStamp = localOk ? _stamp(localRaw) : -1;
    final serverStamp = serverOk ? _stamp(serverRaw) : -1;

    if (serverOk && serverStamp > localStamp) {
      await prefs.setString(resultKey, serverRaw!);
    } else if (localOk && localStamp > serverStamp) {
      await _push(localRaw!);
    }
  }

  /// "서버 기준으로 복원" 용: 서버 결과가 유효하면 로컬을 덮어쓴다.
  static Future<void> adoptServer(
      SharedPreferences prefs, Map<String, dynamic> serverData) async {
    final serverRaw = serverData[resultKey] as String?;
    if (isValid(serverRaw)) {
      await prefs.setString(resultKey, serverRaw!);
    }
  }
}
