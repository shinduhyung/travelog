import 'package:jidoapp/services/survey_ad_session.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:jidoapp/services/rewarded_unlock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/screens/discover_screen.dart';
import 'package:jidoapp/screens/discover_quiz_screen.dart';
import 'package:jidoapp/services/discover_quizzes.dart';

void main() {
  setUpAll(() async {
    final root = File(Platform.resolvedExecutable).parent.parent.parent.path;
    final fonts = FontLoader('Roboto');
    for (final name in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
      fonts.addFont(Future.value(ByteData.sublistView(File('$root/material_fonts/$name').readAsBytesSync())));
    }
    await fonts.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 384.0, 430.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('All seven Discover tiles have identical geometry at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!), home: const DiscoverScreen()));
        double? height, titleTop, descriptionTop;
        for (var i = 0; i < 7; i++) {
          final tile = find.byKey(ValueKey('discover-feature-$i'));
          await tester.scrollUntilVisible(tile, 160);
          await tester.pumpAndSettle();
          final size = tester.getSize(tile);
          height ??= size.height;
          expect(size.height, height, reason: 'Feature $i changed height');
          if (scale == 1.0 && width >= 384) {
            expect(size.height, lessThanOrEqualTo(84), reason: 'Normal-size tiles must stay compact');
          }
          final texts = tester.widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text))).toList();
          expect(texts.length, 2);
          for (final text in texts) { expect(text.maxLines, 2); }
          final origin = tester.getTopLeft(tile).dy;
          final titleOffset = tester.getTopLeft(find.descendant(of: tile, matching: find.text(texts.first.data!))).dy - origin;
          final descriptionOffset = tester.getTopLeft(find.descendant(of: tile, matching: find.text(texts.last.data!))).dy - origin;
          titleTop ??= titleOffset;
          descriptionTop ??= descriptionOffset;
          expect(titleOffset, closeTo(titleTop, .01));
          expect(descriptionOffset, closeTo(descriptionTop, .01));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('Discover and quiz fit a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget app(Widget child) => MaterialApp(
      builder: (context, body) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: body!,
      ),
      home: child,
    );
    await tester.pumpWidget(app(const DiscoverScreen()));
    await tester.scrollUntilVisible(find.text('Overpaying Test'), 250);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(const DiscoverQuizScreen(quizId: 'savvy')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discover lists all seven features and opens a test', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DiscoverScreen()));
    expect(find.text('Traveler Type AI'), findsOneWidget);
    expect(find.text('AI Recommendation'), findsOneWidget);
    expect(find.text('1. AI Recommendation'), findsNothing);
    final subtitle = tester.widget<Text>(
      find.text(
        'Find your next stop.',
      ),
    );
    expect(subtitle.maxLines, 2);
    expect(subtitle.overflow, TextOverflow.ellipsis);
    await tester.scrollUntilVisible(find.text('Overpaying Test'), 250);
    await tester.tap(find.text('Overpaying Test'));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoverQuizScreen), findsOneWidget);
    expect(find.text('1 / 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quiz completes, restores result and can be retaken', (
    tester,
  ) async {
    final screen = MaterialApp(home: DiscoverQuizScreen(quizId: 'survival', adSession: SurveyAdSession(pause: Object.new, resume: (_) {}, needsAd: () => false, watch: (_) async => RewardedUnlockResult.unlocked)));
    final quiz = discoveryQuizzes['survival']!;
    await tester.pumpWidget(screen);
    await tester.pumpAndSettle();
    for (var i = 0; i < quiz.questions.length; i++) {
      final option = quiz.questions[i].options.firstWhere((o) => o.points == 3);
      await tester.ensureVisible(find.text(option.text));
      await tester.tap(find.text(option.text));
      await tester.pump();
      final next = find.text(
        i == quiz.questions.length - 1 ? 'See result' : 'Next',
      );
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(find.text('100 / 100'), -300);
    expect(find.text('100 / 100'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(screen);
    await tester.pumpAndSettle();
    expect(find.text('100 / 100'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
