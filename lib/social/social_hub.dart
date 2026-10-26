// Travelog 앱 안에서 소셜 화면(프로필, 친구, 대결)을 여는 입구.
//
// Travelog Social 앱(travelog_social)의 화면을 그대로 옮겨 왔다. 그 앱에서는 MaterialApp 바로 아래에
// SocialScope를 두었지만, 여기서는 Travelog의 MaterialApp을 건드리지 않도록 소셜 화면을 열 때마다
// [socialRoute]가 SocialScope + 소셜 테마를 씌운다. 스토어는 처음 열 때 만들어서 계속 쓴다.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'data/geo_data.dart';
import 'screens/duel_game_screen.dart';
import 'screens/duels_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/profile_screen.dart';
import 'services/social_store.dart';
import 'theme.dart';
import 'widgets/world_map.dart';

class SocialHub {
  SocialHub._();

  static SocialStore? _store;
  static Future<void>? _data;
  static bool _dataReady = false;
  static final ThemeData _theme = buildTheme();

  /// 지도/도시/랜드마크 데이터 (처음 한 번만 읽는다)
  static Future<void> ensureData() => _data ??= GeoData.load().then((_) {
        warmUpWorldMap();
        _dataReady = true;
      });

  /// 위젯 테스트용: Firebase 없이 이 스토어를 쓴다
  @visibleForTesting
  static SocialStore? debugStore;

  /// 로그인한 사용자의 스토어. 계정이 바뀌면 새로 만든다.
  static SocialStore? get store {
    if (debugStore != null) return debugStore;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _store?.dispose();
      _store = null;
      return null;
    }
    if (_store?.uid != user.uid) {
      _store?.dispose();
      _store = SocialStore(user);
      SocialScope.fallback = () => _store!;
    }
    return _store;
  }

  /// 받은 대결 신청 수 (소셜을 한 번 연 뒤부터 실시간으로 알 수 있다)
  static int get pendingInvites {
    final s = _store;
    return s != null && s.uid == FirebaseAuth.instance.currentUser?.uid ? s.incomingInvites.length : 0;
  }

  static Future<void> openProfile(BuildContext context) =>
      _open(context, (store) => ProfileScreen(uid: store.uid));

  static Future<void> openFriends(BuildContext context) => _open(context, (_) => const FriendsScreen());

  static Future<void> openDuels(BuildContext context) => _open(context, (_) => const DuelsScreen());

  static Future<void> _open(BuildContext context, Widget Function(SocialStore store) page) async {
    final store = SocialHub.store;
    if (store == null) return;
    // 열 때마다 Travelog 기록을 다시 요약한다 (스토어는 계속 쓰므로 처음 동기화가 오래될 수 있다)
    unawaited(store.sync());
    if (!_dataReady) {
      final navigator = Navigator.of(context);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await ensureData();
      } catch (e) {
        _data = null; // 다음에 다시 시도
        debugPrint('Social data load failed: $e');
        return;
      } finally {
        navigator.pop();
      }
    }
    if (!context.mounted) return;
    await Navigator.push(context, socialRoute<void>((_) => page(store)));
  }

  static ThemeData get theme => _theme;
}

/// 소셜 화면용 라우트: 스토어와 소셜 테마(민트, Poppins)를 씌우고 대결 신청 팝업을 받는다.
/// Travelog의 상시 뒤로가기 버튼은 이 이름의 화면에서 숨는다 (소셜 화면은 앱바에 뒤로가기가 있다)
const socialRouteName = 'social';

Route<T> socialRoute<T>(WidgetBuilder builder) => MaterialPageRoute<T>(
      settings: const RouteSettings(name: socialRouteName),
      builder: (context) {
        final store = SocialHub.store;
        final page = Theme(data: SocialHub.theme, child: DuelInviteListener(child: Builder(builder: builder)));
        return store == null ? page : SocialScope(store: store, child: page);
      },
    );
