import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped cache; Firestore persists drafts and completed results.
class DiscoverSurveyStore {
  final String? uid;
  int _revision = 0;
  DiscoverSurveyStore()
    : uid = Firebase.apps.isEmpty
          ? null
          : FirebaseAuth.instance.currentUser?.uid;
  String cacheKey(String key) => uid == null ? key : '${key}_${uid!}';
  DocumentReference<Map<String, dynamic>>? ref(String key) => uid == null
      ? null
      : FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('discover_surveys')
            .doc(key);
  Future<Map<String, dynamic>?> load(String key) async {
    final prefs = await SharedPreferences.getInstance(), cache = cacheKey(key);
    Map<String, dynamic>? local;
    try {
      final raw = prefs.getString('${cache}_cloud');
      if (raw != null)
        local = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
    final doc = ref(key);
    if (doc == null) return local;
    if (prefs.getBool('${cache}_pending') == true && local != null) {
      await save(key, local);
      return local;
    }
    try {
      final remote = await doc.get().timeout(const Duration(seconds: 6));
      if (remote.exists) {
        final data = remote.data()!;
        data.remove('updatedAt');
        data.remove('completedAt');
        await prefs.setString('${cache}_cloud', jsonEncode(data));
        return data;
      }
      if (local != null) await save(key, local);
    } catch (e) {
      debugPrint('Survey restore pending: ${e.runtimeType}');
    }
    return local;
  }

  Future<void> save(String key, Map<String, dynamic> data) async {
    final revision = ++_revision;
    final prefs = await SharedPreferences.getInstance(), cache = cacheKey(key);
    if (revision != _revision) return;
    await prefs.setString('${cache}_cloud', jsonEncode(data));
    await prefs.setBool('${cache}_pending', true);
    final doc = ref(key);
    if (doc == null) return;
    try {
      if (revision != _revision) return;
      final batch = FirebaseFirestore.instance.batch();
      batch.set(doc, {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (data['status'] == 'complete')
        batch.set(
          doc.collection('attempts').doc('${data['completedAtMillis']}'),
          {...data, 'completedAt': FieldValue.serverTimestamp()},
        );
      await batch.commit().timeout(const Duration(seconds: 6));
      if (revision == _revision) await prefs.setBool('${cache}_pending', false);
    } catch (e) {
      debugPrint('Survey sync pending: ${e.runtimeType}');
    }
  }

  Future<void> complete(
    String key,
    List<int> answers,
    int score,
    Map<String, dynamic> result,
  ) async {
    final data = <String, dynamic>{
      'status': 'complete',
      'answers': answers,
      'score': score,
      'result': result,
      'schema': 1,
      'step': answers.length,
      'completedAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
    await save(key, data);
  }
}
