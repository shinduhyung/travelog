import 'dart:math';
import '../../lib/services/discover_quizzes.dart';
import '../../lib/services/persona_scorer.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  var cases = 0;
  for (final quiz in discoveryQuizzes.values) {
    var minimum = 100, maximum = 0;
    void visit(List<int> answers) {
      if (answers.length == quiz.questions.length) {
        final score = quiz.score(answers);
        check(score >= 0 && score <= 100, 'Score out of range');
        check(quiz.score(List.from(answers)) == score, 'Replay changed score');
        if (score < minimum) minimum = score;
        if (score > maximum) maximum = score;
        cases++;
        return;
      }
      for (var i = 0; i < quiz.questions[answers.length].options.length; i++) {
        visit([...answers, i]);
      }
    }
    if (quiz.questions.length <= 8) {
      visit([]);
    } else {
      final random = Random(42);
      for (var i = 0; i < 1000; i++) {
        visit([for (final q in quiz.questions) random.nextInt(q.options.length)]);
      }
      for (final target in [0, 3]) {
        visit([for (final q in quiz.questions) q.options.indexWhere((o) => o.points == target)]);
      }
    }
    check(minimum == 0 && maximum == 100, 'Incomplete score range: ${quiz.id}');
    for (final invalid in [<int>[], List.filled(quiz.questions.length, -1),
      List.filled(quiz.questions.length, 99)]) {
      var rejected = false;
      try { quiz.score(invalid); } on ArgumentError { rejected = true; }
      check(rejected, 'Invalid saved answers accepted');
    }
  }
  final reasons = PersonaScorer.matchingAxes({'data': {
    'missing': {'P': 1, 'W': 3}, 'opposite': {'P': -1, 'W': 3},
    'neutral': {'P': 0, 'W': 3}, 'known': {'P': 1, 'W': 2},
    'disabled': {'P': 1, 'W': 0},
  }}, {'opposite': 1, 'neutral': 0, 'known': .8, 'disabled': 1});
  check(reasons.length == 1 && reasons.single == 'known', 'Unsupported rationale');
  print('PASS: $cases complete quiz answer sets, saved-answer validation, grounded type explanations.');
}
