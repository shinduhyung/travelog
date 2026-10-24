// My Trips의 Travelog Social 메뉴를 실제 폭(작은 폰 360px, 큰 폰 412px에서 카드 안쪽 폭)과
// 큰 글씨로 그려서 넘침이 없는지 확인한다.
//   flutter test test/social_menu_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/social/social_menu.dart';

void main() {
  // 화면 폭 - 바깥 여백 48 - 프로필 카드 안쪽 여백 48
  const widths = [320.0 - 96, 360.0 - 96, 412.0 - 96];
  const scales = [1.0, 1.3, 1.6];
  const counts = <int?>[null, 1, 12, 1234];

  for (final w in widths) {
    for (final scale in scales) {
      for (final count in counts) {
        testWidgets('social menu ${w.toInt()}w x$scale invites=$count', (tester) async {
          final errors = <String>[];
          final old = FlutterError.onError;
          FlutterError.onError = (d) => errors.add(d.exceptionAsString());
          tester.view.physicalSize = const Size(412, 900) * 3;
          tester.view.devicePixelRatio = 3;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: const Size(412, 900), textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: w,
                      child: SocialMenu(
                        duelInvites: count == null ? 0 : 3,
                        onOpen: () {},
                        onProfile: () {},
                        onFriends: () {},
                        onDuels: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          FlutterError.onError = old;
          expect(errors, isEmpty, reason: errors.join('\n---\n'));
          expect(find.text('Profile'), findsOneWidget);
          expect(find.textContaining('friend'), findsNothing);
          await tester.pumpWidget(const SizedBox());
          tester.view.reset();
        });
      }
    }
  }
}
