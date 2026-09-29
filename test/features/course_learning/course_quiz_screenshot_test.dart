import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_result_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:aia_mobile/features/course_learning/data/sample_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_quiz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// Deterministic captures of the Quiz flow at the reference frames' own
/// 393 x 852, one per state in the Figma Quiz pack.
///
/// Driven by the *production* sample rather than the test fake: the frames
/// show the four-question, four-option quiz transcribed from Figma, and the
/// fake's two-question stub cannot reproduce them.
late CourseQuiz quiz;

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final exercise = await SampleCourseLearningRepository().getExercise(2);
    quiz = exercise.quiz!;
  });

  Future<void> pumpQuiz(WidgetTester tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: CourseQuizScreen(quiz: quiz),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/quiz_$name.png'),
  );

  testWidgets('q1 unanswered', (tester) async {
    await pumpQuiz(tester);
    await shot(tester, '1_unanswered');
  });

  testWidgets('q2 correct answer picked', (tester) async {
    await pumpQuiz(tester);
    await tester.tap(find.text(quiz.questions.first.options[0]));
    await tester.pumpAndSettle();
    await shot(tester, '2_correct');
  });

  testWidgets('q3 wrong answer picked', (tester) async {
    await pumpQuiz(tester);
    await tester.tap(find.text(quiz.questions.first.options[1]));
    await tester.pumpAndSettle();
    await shot(tester, '3_incorrect');
  });

  testWidgets('q4 result', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: CourseQuizResultScreen(
          quiz: quiz,
          // Two of four right, as the reference frame shows.
          answers: {
            0: quiz.questions[0].correctOptionIndex,
            1: (quiz.questions[1].correctOptionIndex + 1) % 4,
            2: quiz.questions[2].correctOptionIndex,
            3: (quiz.questions[3].correctOptionIndex + 1) % 4,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await shot(tester, '4_result');
  });
}
