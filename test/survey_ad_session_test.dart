import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:jidoapp/services/survey_ad_session.dart';
import 'package:jidoapp/services/rewarded_unlock_service.dart';
import 'package:jidoapp/screens/discover_quiz_screen.dart';
import 'package:jidoapp/services/discover_quizzes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('a survey keeps one pause token and one rewarded request at a time', () async {
    var pauses = 0, resumes = 0, requests = 0;
    var premium = false;
    final pending = Completer<RewardedUnlockResult>();
    final session = SurveyAdSession(pause: () {pauses++; return Object();},
      resume: (_) => resumes++, needsAd: () => !premium,
      watch: (_) {requests++; return pending.future;});
    session.enter(); session.enter();
    expect(pauses, 1);
    final result = session.unlock('test');
    expect(await session.unlock('test'), RewardedUnlockResult.dismissed);
    expect(requests, 1);
    pending.complete(RewardedUnlockResult.unlocked);
    expect(await result, RewardedUnlockResult.unlocked);
    expect(resumes, 0);
    session.leave(); session.leave();
    expect(resumes, 1);
    premium = true;
    expect(await session.unlock('test'), RewardedUnlockResult.unlocked);
    expect(requests, 1);
  });

  for (final id in ['survival', 'savvy']) {
    testWidgets('$id keeps all 20 answers until the reward is earned', (tester) async {
      var resumed = 0;
      var earned = false;
      final session = SurveyAdSession(pause: Object.new, resume: (_) => resumed++,
        needsAd: () => true, watch: (_) async => earned ? RewardedUnlockResult.unlocked : RewardedUnlockResult.dismissed);
      final quiz = discoveryQuizzes[id]!;
      expect(quiz.questions.length, 20);
      await tester.pumpWidget(MaterialApp(home: DiscoverQuizScreen(quizId: id, adSession: session)));
      await tester.pumpAndSettle();
      for (var i = 0; i < quiz.questions.length; i++) {
        final option = quiz.questions[i].options.firstWhere((o) => o.points == 3);
        final chosen = find.text(option.text);
        await tester.ensureVisible(chosen);
        await tester.pumpAndSettle();
        await tester.tap(chosen);
        await tester.pump();
        final button = find.text(i == 19 ? 'Watch ad & see result' : 'Next');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(find.text('20 / 20'), -250);
      expect(find.text('20 / 20'), findsOneWidget);
      expect(resumed, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('discover_quiz_${id}_v2'), isNull);
      expect(prefs.getString('discover_quiz_${id}_v2_draft'), isNotNull);
      earned = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Watch ad & see result'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watch ad & see result'));
      await tester.pumpAndSettle();
      expect(find.text('100 / 100'), findsOneWidget);
      expect(resumed, 1);
      expect(prefs.getString('discover_quiz_${id}_v2'), isNotNull);
      expect(prefs.getString('discover_quiz_${id}_v2_draft'), isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
