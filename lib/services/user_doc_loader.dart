import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// Loads users/{uid} for the providers' initial load, always from the server.
//
// Why: right after sign-in, AuthProvider writes a few profile fields to this
// same doc. If Firestore briefly considers itself offline at that moment, a
// default get() resolves from the local cache, which then holds only that
// pending partial write — the doc "exists" with no visit data and no error.
// That is how a fresh install / tutorial login showed every stat as 0 until
// the app was reopened. Source.server either returns the real doc or throws,
// and the callers already fall back to local data on error.
//
// All providers rebuilt by the login remount read the same doc within a few
// seconds, so one in-flight request is shared instead of ~20 separate reads.
class UserDocLoader {
  UserDocLoader._();
  static final UserDocLoader instance = UserDocLoader._();

  static const Duration _shareWindow = Duration(seconds: 20);
  static const Duration _attemptTimeout = Duration(seconds: 6);
  static const int _maxAttempts = 3;

  String? _uid;
  DateTime? _startedAt;
  Future<DocumentSnapshot<Map<String, dynamic>>>? _inFlight;

  Future<DocumentSnapshot<Map<String, dynamic>>> load(String uid) {
    final shared = _inFlight;
    if (shared != null &&
        _uid == uid &&
        DateTime.now().difference(_startedAt!) < _shareWindow) {
      return shared;
    }
    _uid = uid;
    _startedAt = DateTime.now();
    final future = _fetch(uid);
    _inFlight = future;
    // A failed load must not be handed to later callers.
    future.then((_) {}, onError: (Object _) {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetch(String uid) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        // A documentId query instead of ref.get(): a doc-level listen can resume
        // from a saved token and hand back a stale partial cached copy as
        // "from server"; a fresh query target always returns the full server doc
        // (and rewrites the cached copy, healing devices already stuck).
        DocumentSnapshot<Map<String, dynamic>>? doc;
        var via = 'query';
        try {
          final query = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, isEqualTo: uid)
              .limit(1)
              .get(const GetOptions(source: Source.server))
              .timeout(_attemptTimeout);
          if (query.docs.isNotEmpty) doc = query.docs.first;
        } on FirebaseException catch (e) {
          // If security rules reject the query form, the plain doc read still works.
          if (e.code != 'permission-denied') rethrow;
          debugPrint('⚠️ [UserDocLoader] query denied, falling back to doc read');
        }
        if (doc == null) {
          via = 'doc';
          doc = await ref.get(const GetOptions(source: Source.server)).timeout(_attemptTimeout);
        }
        debugPrint('📥 [UserDocLoader] users/$uid loaded from server via $via '
            '(attempt $attempt, exists=${doc.exists}, keys=${doc.data()?.length ?? 0})');
        return doc;
      } catch (e) {
        lastError = e;
        debugPrint('⚠️ [UserDocLoader] attempt $attempt failed: $e');
        if (attempt < _maxAttempts) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
        }
      }
    }
    throw lastError!;
  }
}
