import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/screens/travelog_polls_screen.dart';
import 'package:jidoapp/services/travelog_poll_preview.dart';

void main() {
  setUpAll(() async {
    final root = File(Platform.resolvedExecutable).parent.parent.parent.path;
    final loader = FontLoader('Roboto');
    for (final font in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('$root/material_fonts/$font').readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
  });
  test(
    'Preview week has previous food result and current East Asia choices',
    () async {
      final gateway = TravelogPollWeekPreview();
      final data = await gateway.load();
      expect((data['active']['options'] as List).map((o) => o['code']), [
        'CN',
        'JP',
        'KR',
        'TW',
        'MN',
      ]);
      expect(data['previous'][0]['counts'], {
        'JP': 34,
        'IT': 27,
        'TH': 14,
        'FR': 13,
        'MX': 12,
      });
      expect(
        DateTime.parse(
          data['previous'][0]['releaseAt'],
        ).isBefore(DateTime.parse(data['serverNow'])),
        isTrue,
      );
      await gateway.vote('preview_east_asia', 'TW');
      expect((await gateway.load())['active']['choice'], 'TW');
      expect(() => gateway.vote('real_poll', 'TW'), throwsArgumentError);
    },
  );

  for (final size in [const Size(320, 720), const Size(384, 832)]) {
    testWidgets('Week preview fits all choices and history at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TravelogPollsScreen(gateway: TravelogPollWeekPreview()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('China'), findsOneWidget);
      expect(find.text('Mongolia'), findsOneWidget);
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scroll.position.maxScrollExtent, 0);
      expect(
        tester.getRect(find.text('Past poll results')).bottom,
        lessThan(tester.getRect(find.text('Cast my vote')).top),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
