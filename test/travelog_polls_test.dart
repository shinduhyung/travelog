import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jidoapp/screens/travelog_polls_screen.dart';
import 'package:jidoapp/services/travelog_poll_service.dart';

class Polls implements TravelogPollGateway {
  String? choice;
  bool next = false;
  int writes = 0;
  Map<String, dynamic> food() => {
    'id': 'food',
    'question': 'Which country has the best food?',
    'releaseAt': '2026-11-09T00:00:00Z',
    'accent': 'coral',
    'choice': choice,
    'options': [
      for (final c in [
        ('FR', 'France'),
        ('IT', 'Italy'),
        ('TH', 'Thailand'),
        ('MX', 'Mexico'),
        ('JP', 'Japan'),
      ])
        {'code': c.$1, 'label': c.$2, 'detail': 'Food & culture'},
    ],
  };
  @override
  Future<Map<String, dynamic>> load() async => {
    'serverNow': next ? '2026-11-09T00:00:00Z' : '2026-11-08T23:59:59Z',
    'active': next
        ? {
            'id': 'east',
            'question': 'Which is the best East Asian country?',
            'releaseAt': '2026-11-16T00:00:00Z',
            'options': [
              for (final c in [
                ('CN', 'China'),
                ('JP', 'Japan'),
                ('KR', 'South Korea'),
                ('TW', 'Taiwan'),
                ('MN', 'Mongolia'),
              ])
                {'code': c.$1, 'label': c.$2, 'detail': 'Food & culture'},
            ],
          }
        : food(),
    'previous': next
        ? [
            {
              ...food(),
              'released': true,
              'counts': {'FR': 1, 'IT': 0, 'TH': 0, 'MX': 0, 'JP': 0},
            },
          ]
        : [],
  };
  @override
  Future<void> vote(String pollId, String country) async {
    choice = country;
    writes++;
  }
}

void main() {
  setUpAll(() async {
    final root = File(Platform.resolvedExecutable).parent.parent.parent.path;
    final loader = FontLoader('Roboto');
    for (final f in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ])
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('$root/material_fonts/$f').readAsBytesSync(),
          ),
        ),
      );
    await loader.load();
  });

  testWidgets('Vote has five flags and hides every result before reveal', (
    tester,
  ) async {
    final api = Polls();
    await tester.pumpWidget(
      MaterialApp(home: TravelogPollsScreen(gateway: api)),
    );
    await tester.pumpAndSettle();
    expect(find.text('France'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Japan'), 200);
    expect(find.text('Japan'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('France'), -200);
    expect(find.textContaining('votes'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    await tester.tap(find.text('France'));
    await tester.pump();
    await tester.tap(find.text('Cast my vote'));
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    expect(find.text('Vote saved'), findsOneWidget);
    expect(find.textContaining('votes'), findsNothing);
    api.next = true;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Which is the best East Asian country?'), findsOneWidget);
    expect(find.text('China'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past poll results'));
    await tester.pumpAndSettle();
    expect(find.textContaining('%'), findsNothing);
    await tester.tap(find.text('Which country has the best food?'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Poll fits narrow screen and larger text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(
            c,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: w!,
        ),
        home: TravelogPollsScreen(gateway: Polls()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Japan'), 250);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final size in [const Size(320, 720), const Size(384, 832)]) {
    testWidgets('All five choices fit without scrolling at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: TravelogPollsScreen(gateway: Polls())),
      );
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scroll.position.maxScrollExtent, 0);
      expect(
        tester.getRect(find.text('Japan')).bottom,
        lessThan(tester.getRect(find.text('Cast my vote')).top),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
