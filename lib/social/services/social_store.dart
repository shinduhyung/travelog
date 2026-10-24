import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../models/duel.dart';
import '../models/social_profile.dart';
import 'social_repository.dart';

/// 로그인한 동안 화면들이 함께 쓰는 실시간 상태:
/// 내 프로필, 친구 목록과 친구 프로필, 내 대결.
class SocialStore extends ChangeNotifier {
  SocialStore(User this.user) : uid = user.uid {
    _repo = SocialRepository.instance;
    _meSub = _repo.watchProfile(uid).listen((p) {
      me = p;
      meLoaded = true;
      notifyListeners();
    });
    _friendsSub = _repo.watchFriendUids(uid).listen(_onFriendUids, onError: (Object e) {
      friendsError = describeError(e);
      friendsLoaded = true;
      notifyListeners();
    });
    _duelsSub = _repo.watchMyDuels(uid).listen((d) {
      duels = d;
      duelsLoaded = true;
      notifyListeners();
    }, onError: (Object e) {
      duelsLoaded = true;
      notifyListeners();
    });
    sync();
  }

  /// 위젯 테스트용: Firebase 없이 고정된 데이터로 화면을 그린다
  @visibleForTesting
  SocialStore.test({
    required this.uid,
    this.me,
    List<SocialProfile> friends = const [],
    this.duels = const [],
  }) : user = null {
    meLoaded = true;
    friendsLoaded = true;
    duelsLoaded = true;
    friendUids = [for (final f in friends) f.uid];
    for (final f in friends) {
      _friendProfiles[f.uid] = f;
    }
  }

  /// 테스트용 스토어면 null
  final User? user;
  final String uid;
  late final SocialRepository _repo;
  StreamSubscription? _meSub;
  StreamSubscription? _friendsSub;
  StreamSubscription? _duelsSub;
  final _friendSubs = <String, StreamSubscription>{};

  SocialProfile? me;
  bool meLoaded = false;

  List<String> friendUids = const [];
  final Map<String, SocialProfile?> _friendProfiles = {};
  bool friendsLoaded = false;
  String? friendsError;

  List<Duel> duels = const [];
  bool duelsLoaded = false;

  bool syncing = false;
  String? syncError;

  /// 프로필이 올라온 친구만 (순서 = 친구 목록)
  List<SocialProfile> get friends => [for (final u in friendUids) ?_friendProfiles[u]];

  SocialProfile? friend(String uid) => _friendProfiles[uid];

  bool friendLoaded(String uid) => _friendProfiles.containsKey(uid);

  /// 나 + 친구 (랭킹용)
  List<SocialProfile> get everyone => [?me, ...friends];

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  /// 친구가 보낸, 아직 수락하지 않은 대결 신청
  List<Duel> get incomingInvites => duels.where((d) => d.createdBy != uid && d.inviteOpen(_now)).toList();

  /// 내가 보내고 기다리는 중
  List<Duel> get outgoingInvites => duels.where((d) => d.createdBy == uid && d.inviteOpen(_now)).toList();

  /// 지금 진행 중인 대결 (다시 들어갈 수 있음)
  List<Duel> get liveDuels => duels.where((d) => d.isPlaying && !d.isStale(_now)).toList();

  List<Duel> get finishedDuels => duels.where((d) => d.isFinished).toList();

  List<Duel> duelsWith(String friendUid) => duels.where((d) => d.players.contains(friendUid)).toList();

  void _onFriendUids(List<String> uids) {
    friendUids = uids;
    friendsLoaded = true;
    friendsError = null;
    for (final gone in _friendSubs.keys.where((u) => !uids.contains(u)).toList()) {
      _friendSubs.remove(gone)?.cancel();
      _friendProfiles.remove(gone);
    }
    for (final u in uids) {
      _friendSubs.putIfAbsent(
        u,
        () => _repo.watchProfile(u).listen((p) {
          _friendProfiles[u] = p;
          notifyListeners();
        }),
      );
    }
    notifyListeners();
  }

  Future<void> sync() async {
    final user = this.user;
    if (syncing || user == null) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      await _repo.syncMyProfile(user);
      // 등급 계산은 실패해도 동기화에는 영향 없음
      unawaited(_repo.refreshPlan().then((_) {}, onError: (Object e) => debugPrint('[plan] $e')));
    } catch (e, st) {
      syncError = describeError(e);
      debugPrint('[sync] failed: $e\n$st');
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> setPrivacy(PrivacySettings privacy) async {
    final user = this.user;
    if (user == null) return;
    syncing = true;
    notifyListeners();
    try {
      await _repo.updatePrivacy(user, privacy);
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _meSub?.cancel();
    _friendsSub?.cancel();
    _duelsSub?.cancel();
    for (final s in _friendSubs.values) {
      s.cancel();
    }
    super.dispose();
  }
}

class SocialScope extends InheritedNotifier<SocialStore> {
  const SocialScope({super.key, required SocialStore store, required super.child}) : super(notifier: store);

  /// Travelog 안에서는 소셜 화면마다 [socialRoute]가 SocialScope를 씌운다.
  /// 그 바깥(바텀시트, 다이얼로그)에서는 [fallback] 스토어를 쓴다.
  static SocialStore Function()? fallback;

  static SocialStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SocialScope>()?.notifier ?? fallback!();

  /// 다시 그리지 않고 값만 (콜백 안에서)
  static SocialStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SocialScope>()?.notifier ?? fallback!();
}
