import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jidoapp/screens/discover_quiz_screen.dart';
import 'package:jidoapp/services/discover_quizzes.dart';
import 'package:jidoapp/services/survey_ad_session.dart';
import 'package:jidoapp/services/rewarded_unlock_service.dart';

void main() {
  for (final id in ['survival', 'savvy', 'local']) {
    for (final width in [320.0, 430.0]) {
      testWidgets('$id keeps choices and footer fixed across 20 questions at $width', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = SurveyAdSession(pause: Object.new, resume: (_) {}, needsAd: () => true, watch: (_) async => RewardedUnlockResult.dismissed);
        await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.25)), child: child!), home: DiscoverQuizScreen(quizId: id, adSession: session)));
        await tester.pumpAndSettle();
        final quiz = discoveryQuizzes[id]!;
        Rect? footer;
        double? choiceCenter;
        for (var i = 0; i < quiz.questions.length; i++) {
          final next = find.widgetWithText(FilledButton, i == quiz.questions.length - 1 ? 'Watch ad & see result' : 'Next');
          final rect = tester.getRect(next);
          footer ??= rect;
          expect(rect, footer, reason: 'Footer moved on question ${i + 1}');
          final choice = find.text(quiz.questions[i].options.first.text);
          final center = tester.getCenter(choice).dy;
          choiceCenter ??= center;
          expect(center, closeTo(choiceCenter, .1), reason: 'Choice moved on question ${i + 1}');
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          await tester.tap(choice);
          await tester.pumpAndSettle();
          expect(tester.getRect(next), footer, reason: 'Selecting an answer moved the footer');
          if (i < quiz.questions.length - 1) {
            await tester.tap(next);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
