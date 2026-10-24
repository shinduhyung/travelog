import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/duel.dart';
import '../models/social_profile.dart';

class InvitePreview {
  const InvitePreview({
    required this.ownerUid,
    required this.ownerName,
    required this.isSelf,
    required this.alreadyFriends,
  });

  final String ownerUid;
  final String ownerName;
  final bool isSelf;
  final bool alreadyFriends;
}

/// Firestore 읽기/쓰기와 social* Cloud Functions 호출을 한곳에 모은다.
class SocialRepository {
  SocialRepository._();
  static final instance = SocialRepository._();

  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) =>
      _db.collection('profiles').doc(uid);

  // ── 내 프로필 요약 동기화 ──────────────────────────────────────────────

  /// 내 Travelog 원본 데이터를 읽어 profiles/{uid}에 요약을 쓴다.
  /// displayName은 처음 만들 때만 로그인 이름으로 채우고, 이후엔 사용자가 정한 값을 유지.
  Future<void> syncMyProfile(User user) async {
    final uid = user.uid;
    final userRef = _db.collection('users').doc(uid);

    final results = await Future.wait([
      userRef.get(),
      userRef.collection('badges').doc('unlocked').get(),
      _db.collection('game_scores').doc(uid).get(),
      userRef.collection('quiz_history').get(),
      userRef.collection('quiz_history_expert').get(),
      _profileRef(uid).get(),
    ]);
    final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final badgesDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
    final gamesDoc = results[2] as DocumentSnapshot<Map<String, dynamic>>;
    final quizNormal = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final quizExpert = results[4] as QuerySnapshot<Map<String, dynamic>>;
    final existing = results[5] as DocumentSnapshot<Map<String, dynamic>>;

    final summary = ProfileSummaryBuilder.build(
      uid: uid,
      displayName: '',
      user: userDoc.data(),
      badges: badgesDoc.data(),
      gameScores: gamesDoc.data(),
      quizNormal: quizNormal.docs.map((d) => MapEntry(d.id, d.data())),
      quizExpert: quizExpert.docs.map((d) => MapEntry(d.id, d.data())),
    );
    final privacy = PrivacySettings.fromMap(existing.data()?['privacy']);

    // 진단용: 값은 남기지 않고 어떤 필드가 어떤 형태로 있는지와 결과 개수만
    if (kDebugMode) {
      final raw = userDoc.data() ?? const {};
      String shape(String k) {
        final v = raw[k];
        if (v == null) return 'missing';
        if (v is String) return 'String(${v.length})';
        if (v is List) return 'List(${v.length})';
        if (v is Map) return 'Map(${v.length})';
        return v.runtimeType.toString();
      }
      debugPrint('[sync] userDoc exists=${userDoc.exists} fields=${raw.length} '
          'countries=${shape('country_visits_v2')} cities=${shape('city_visit_details_v3')} '
          'landmarks=${shape('visited_landmarks')} unesco=${shape('unesco_visited_sites')} '
          'airlines=${shape('saved_airlines_data')} airports=${shape('airport_visit_history')}');
      debugPrint('[sync] result countries=${summary.countryCount} cities=${summary.cityCount} '
          'landmarks=${summary.landmarkCount} unesco=${summary.unescoCount} flights=${summary.flights.total}');
    }

    await _profileRef(uid).set({
      ...summary.toSummaryFields(privacy),
      if (!existing.exists || existing.data()?['displayName'] == null)
        'displayName': _defaultName(user),
      if (user.photoURL != null) 'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _defaultName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Traveler';
  }

  Future<void> updateDisplayName(String uid, String name) =>
      _profileRef(uid).set({'displayName': name.trim()}, SetOptions(merge: true));

  /// 공개 범위를 바꾸고 바로 다시 동기화해서 꺼진 항목을 지운다.
  Future<void> updatePrivacy(User user, PrivacySettings privacy) async {
    await _profileRef(user.uid).set({'privacy': privacy.toMap()}, SetOptions(merge: true));
    await syncMyProfile(user);
  }

  /// 여러 명의 프로필을 한 번에 (랭킹, 홈 화면). 순서는 [uids]와 같고 없는 사람은 빠진다.
  Stream<List<SocialProfile>> watchProfiles(List<String> uids) {
    if (uids.isEmpty) return Stream.value(const []);
    final latest = <String, SocialProfile?>{};
    final controller = StreamController<List<SocialProfile>>();
    final subs = <StreamSubscription>[];
    void emit() {
      if (latest.length < uids.length) return;
      controller.add([for (final u in uids) ?latest[u]]);
    }

    controller.onListen = () {
      for (final u in uids) {
        subs.add(watchProfile(u).listen((p) {
          latest[u] = p;
          emit();
        }));
      }
    };
    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };
    return controller.stream;
  }

  /// 친구가 아니게 되면 permission-denied가 나므로 null로 바꿔서 흘려보낸다.
  Stream<SocialProfile?> watchProfile(String uid) => _profileRef(uid)
      .snapshots()
      .map<SocialProfile?>((doc) => doc.exists ? SocialProfile.fromDoc(doc) : null)
      .transform(StreamTransformer.fromHandlers(handleError: (error, stack, sink) {
        if (error is FirebaseException) {
          sink.add(null);
        } else {
          sink.addError(error, stack);
        }
      }));

  // ── 친구 ────────────────────────────────────────────────────────────

  Stream<List<String>> watchFriendUids(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('friends')
      .snapshots()
      .map((s) => s.docs.map((d) => d.id).toList());

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    final result = await _functions.httpsCallable(name).call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  }

  /// 결제 기록으로 유료 등급을 다시 계산 (서버가 profiles/{uid}.plan에 씀)
  Future<String> refreshPlan() async => (await _call('socialRefreshPlan'))['plan'] as String? ?? 'none';

  Future<String> createInvite() async => (await _call('socialCreateInvite'))['code'] as String;

  Future<InvitePreview> previewInvite(String code) async {
    final d = await _call('socialPreviewInvite', {'code': code});
    return InvitePreview(
      ownerUid: d['ownerUid'] as String,
      ownerName: d['ownerName'] as String,
      isSelf: d['isSelf'] == true,
      alreadyFriends: d['alreadyFriends'] == true,
    );
  }

  Future<void> acceptInvite(String code) => _call('socialAcceptInvite', {'code': code});

  Future<void> removeFriend(String friendUid) =>
      _call('socialRemoveFriend', {'friendUid': friendUid});

  // ── 1:1 대결 ─────────────────────────────────────────────────────────

  /// [mode]: flag | capital | population | area | landmark | city | mixed
  Future<String> createDuel(String friendUid, {String mode = 'mixed', String difficulty = 'medium', String scoring = 'speed'}) async =>
      (await _call('socialCreateDuel', {'friendUid': friendUid, 'mode': mode, 'difficulty': difficulty, 'scoring': scoring}))['matchId']
          as String;

  Future<void> joinDuel(String matchId) => _call('socialJoinDuel', {'matchId': matchId});

  /// 반환: {ok, pts, late, now}
  Future<Map<String, dynamic>> answerDuel(String matchId, int round, int choice, int elapsedMs) =>
      _call('socialAnswerDuel', {'matchId': matchId, 'round': round, 'choice': choice, 'elapsedMs': elapsedMs});

  /// 시간이 지난 라운드를 닫는다. 서버 시각(now)을 돌려줘서 시계 맞추기에도 쓴다.
  Future<int> tickDuel(String matchId) async => ((await _call('socialTickDuel', {'matchId': matchId}))['now'] as num).toInt();

  Future<void> leaveDuel(String matchId) => _call('socialLeaveDuel', {'matchId': matchId});

  /// 정렬은 클라이언트에서 한다 (array-contains + orderBy는 복합 색인이 필요해서).
  Stream<List<Duel>> watchMyDuels(String uid) => _db
      .collection('matches')
      .where('players', arrayContains: uid)
      .limit(100)
      .snapshots()
      .map((s) {
        final duels = s.docs.map(Duel.fromDoc).toList()
          ..sort((a, b) => (b.createdMs ?? 1 << 52).compareTo(a.createdMs ?? 1 << 52));
        return duels;
      });

  Stream<Duel> watchDuel(String matchId) =>
      _db.collection('matches').doc(matchId).snapshots().map(Duel.fromDoc);
}

/// Cloud Functions 오류 → 화면에 보여줄 문장
String describeError(Object e) {
  if (e is FirebaseFunctionsException) return e.message ?? e.code;
  if (e is FirebaseException) return e.message ?? e.code;
  return e.toString();
}
