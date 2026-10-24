// My Trips의 My Hub 바로가기와 Contact 시트를 휴대폰 폭과 큰 글씨로 그려서 넘침이 없는지 확인한다.
//   flutter test test/my_hub_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/widgets/my_hub_board.dart';

void main() {
  const screens = [320.0, 360.0, 412.0];
  const scales = [1.0, 1.3, 1.6];

  Future<void> pump(WidgetTester tester, double width, double scale) async {
    tester.view.physicalSize = Size(width, 780) * 3;
    tester.view.devicePixelRatio = 3;
    await tester.pumpWidget(MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: MyHubBoard(),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final w in screens) {
    for (final scale in scales) {
      testWidgets('board + contact sheet ${w.toInt()}w x$scale', (tester) async {
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());

        await pump(tester, w, scale);
        expect(find.text('My Hub'), findsOneWidget);
        expect(find.text('See all'), findsNothing);
        for (final item in myHubItems) {
          expect(find.text(item.title), findsOneWidget);
        }

        await tester.tap(find.text('Contact'));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Contact us'), findsOneWidget);
        expect(find.text(contactEmail), findsOneWidget);
        expect(find.text('Send email'), findsOneWidget);

        FlutterError.onError = old;
        expect(errors, isEmpty, reason: errors.join('\n---\n'));
        tester.view.reset();
      });
    }
  }
}
