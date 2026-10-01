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
/// fake's two-question stub cannot reproduce them. The sample answers each
/// pick the way §2.7's server does, so the screen runs its real flow.
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
        home: CourseQuizScreen(
          quiz: quiz,
          repository: SampleCourseLearningRepository(),
        ),
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
    // Option A of the frame's first question — the right one.
    await tester.tap(find.text('Хиймэл оюун'));
    await tester.pumpAndSettle();
    await shot(tester, '2_correct');
  });

  testWidgets('q3 wrong answer picked', (tester) async {
    await pumpQuiz(tester);
    // Option B — a wrong one.
    await tester.tap(find.text('Тоглоом'));
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
          title: quiz.resultTitle,
          // Two of four right, as the reference frame shows.
          result: const QuizAttemptResult(
            attemptId: 1,
            correct: 2,
            total: 4,
            percent: 50,
            passed: false,
            questions: [
              QuizQuestionResult(questionId: 1, order: 1, correct: true),
              QuizQuestionResult(questionId: 2, order: 2, correct: false),
              QuizQuestionResult(questionId: 3, order: 3, correct: true),
              QuizQuestionResult(questionId: 4, order: 4, correct: false),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await shot(tester, '4_result');
  });
}
