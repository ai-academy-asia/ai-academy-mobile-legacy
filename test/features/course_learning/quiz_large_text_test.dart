import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/data/sample_course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_quiz.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_result_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_submit_button.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/quiz_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// The quiz card's header and the Exercise/Quiz action pill at larger
/// system text sizes (Issue #541). The header row gave its two texts no
/// width, so from 2.0× on a 320pt phone it overflowed; the pill was a fixed
/// 44 tall, so a one-line label needing 48 was cropped. Both now grow with
/// their text and are exactly as before at the default size.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0, 3.0];

  /// Exercise Detail's tab inset either side: the screen's 16 gutter, the
  /// tab card's 1 edge and the tab's own 16 padding.
  const sideInset = 16.0 + 1 + 16;

  /// Pumps [child] at the Exercise Detail tab's width and returns every
  /// error it raised.
  Future<List<String>> pump(
    WidgetTester tester,
    Widget child, {
    required double width,
    required double scale,
    double inset = sideInset,
  }) async {
    useLogicalViewport(tester, Size(width, 1600), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Center(child: child),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  /// [value] is drawn once, whole: not cut short and at its full height.
  void expectWhole(WidgetTester tester, String value) {
    final label = find.text(value);
    expect(label, findsOneWidget, reason: value);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: label, matching: find.byType(RichText)).first,
    );
    expect(paragraph.didExceedMaxLines, isFalse, reason: value);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
      ),
      reason: value,
    );
  }

  group('the action pill (Issue #541)', () {
    // Every label the pill draws today, in either language, plus the
    // English L16 (#539) brings.
    const labels = [
      'Үргэлжлүүлэх',
      'Continue',
      'Дуусгах',
      'Finish',
      'Submit',
      'Засах',
      'Edit',
      'Start quiz',
      'Дахин quiz өгөх',
      'Retake quiz',
    ];
    for (final label in labels) {
      for (final width in widths) {
        for (final scale in scales) {
          testWidgets('"$label", ${width.toInt()} wide, text ×$scale: the '
              'label whole, inside the pill', (tester) async {
            final errors = await pump(
              tester,
              ExerciseSubmitButton(label: label, onPressed: () {}),
              width: width,
              scale: scale,
            );
            expect(errors, isEmpty);
            expectWhole(tester, label);
            final pill = tester.getRect(find.byType(ExerciseSubmitButton));
            final text = tester.getRect(find.text(label));
            expect(text.top, greaterThanOrEqualTo(pill.top - 0.01));
            expect(text.bottom, lessThanOrEqualTo(pill.bottom + 0.01));
            expect(text.left, greaterThanOrEqualTo(pill.left - 0.01));
            expect(text.right, lessThanOrEqualTo(pill.right + 0.01));
            if (scale == 1.0) {
              expect(pill.height, 44, reason: 'the frame\'s 44 at 1.0×');
            } else {
              expect(pill.height, greaterThanOrEqualTo(44));
            }
          });
        }
      }
    }
  });

  group('the quiz card\'s header (Issue #541)', () {
    final quiz = sampleQuiz(questionCount: 12);
    for (final caption in ['Modules 2', 'Modules 12']) {
      for (final width in widths) {
        for (final scale in scales) {
          testWidgets('"$caption", ${width.toInt()} wide, text ×$scale: no '
              'overflow, both lines whole', (tester) async {
            final errors = await pump(
              tester,
              QuizPreviewCard(
                moduleCaption: caption,
                quiz: quiz,
                onStart: () {},
              ),
              width: width,
              scale: scale,
            );
            expect(errors, isEmpty);
            expectWhole(tester, caption);
            expectWhole(tester, CourseLearningStrings.quizQuestionCount(12));
            final card = tester.getRect(find.byType(QuizPreviewCard));
            for (final value in [
              caption,
              CourseLearningStrings.quizQuestionCount(12),
            ]) {
              final text = tester.getRect(find.text(value));
              expect(text.left, greaterThanOrEqualTo(card.left), reason: value);
              expect(text.right, lessThanOrEqualTo(card.right), reason: value);
            }
          });
        }
      }
    }
  });

  group('the quiz screens at 2.0× on a 320pt phone', () {
    late CourseQuiz flow;
    setUpAll(() async {
      flow = (await SampleCourseLearningRepository().getExercise(2)).quiz!;
    });

    Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
      useLogicalViewport(tester, const Size(320, 2400), padding: iPhonePadding);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
      await tester.pumpAndSettle();
    }

    testWidgets('a question answered: its Continue whole', (tester) async {
      await pumpScreen(
        tester,
        CourseQuizScreen(
          quiz: flow,
          repository: SampleCourseLearningRepository(),
        ),
      );
      await tester.tap(find.text('Хиймэл оюун'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expectWhole(tester, CourseLearningStrings.quizContinue);
    });

    testWidgets('the result: its Finish whole', (tester) async {
      await pumpScreen(
        tester,
        CourseQuizResultScreen(
          title: flow.resultTitle,
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
      );

      expect(tester.takeException(), isNull);
      expectWhole(tester, CourseLearningStrings.quizFinish);
    });
  });
}
