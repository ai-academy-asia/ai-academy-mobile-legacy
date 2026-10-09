import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/domain/course_quiz.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_result_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/quiz_answer_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/quiz_feedback_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/quiz_preview_card.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/quiz_progress_header.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/quiz_result_question_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// Dark Mode Phase 6c (Issue #270): the Quiz draws its colours from the
/// active theme's `AppPalette`, each by its meaning.
///
/// Pumped under a palette whose roles are unmistakable sentinels — not a
/// dark palette, which is not approved. The pairs that share a light value
/// or a near one get distinct sentinels, so each must be read where it
/// belongs: an unanswered option's `outlineFaint` edge against its
/// `cardDepth` band and the `divider` rule; the state inks against their
/// outlines; the two quiz scores (`warning`, `warningInk`); the answer
/// letter against `textMuted`; and the close button's page roles against
/// the video's media roles. Light mode is held by the goldens.
void main() {
  setUpAll(loadAppFonts);

  const surface = Color(0xFF010101);
  const surfaceSubtle = Color(0xFF020202);
  const outline = Color(0xFF030303);
  const outlineFaint = Color(0xFF040404);
  const cardDepth = Color(0xFF050505);
  const divider = Color(0xFF060606);
  const border = Color(0xFF070707);
  const successOutline = Color(0xFF080808);
  const successInk = Color(0xFF090909);
  const errorOutline = Color(0xFF0A0A0A);
  const errorInk = Color(0xFF0B0B0B);
  const warning = Color(0xFF0C0C0C);
  const warningInk = Color(0xFF0D0D0D);
  const textAnswerLetter = Color(0xFF0E0E0E);
  const textMuted = Color(0xFF0F0F0F);
  const textStrong = Color(0xFF101010);
  const textTitle = Color(0xFF111111);
  const textPrimary = Color(0xFF121212);
  const textSecondary = Color(0xFF131313);
  const accent = Color(0xFF141414);
  const progressTrack = Color(0xFF151515);
  const primary = Color(0xFF161616);
  const mediaControl = Color(0xFF171717);
  const mediaControlOutline = Color(0xFF181818);
  const onMediaControl = Color(0xFF191919);

  final sentinel = AppPalette.light.copyWith(
    surface: surface,
    surfaceSubtle: surfaceSubtle,
    outline: outline,
    outlineFaint: outlineFaint,
    cardDepth: cardDepth,
    divider: divider,
    border: border,
    successOutline: successOutline,
    successInk: successInk,
    errorOutline: errorOutline,
    errorInk: errorInk,
    warning: warning,
    warningInk: warningInk,
    textAnswerLetter: textAnswerLetter,
    textMuted: textMuted,
    textStrong: textStrong,
    textTitle: textTitle,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    accent: accent,
    progressTrack: progressTrack,
    primary: primary,
    mediaControl: mediaControl,
    mediaControlOutline: mediaControlOutline,
    onMediaControl: onMediaControl,
  );

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(extensions: [sentinel]),
        home: home,
      ),
    );
    await tester.pump();
  }

  Widget body(Widget child) => Scaffold(
    body: Center(child: SingleChildScrollView(child: child)),
  );

  Color? textColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  /// Every distinct [BoxDecoration] under [of] — a `Container` builds a
  /// `DecoratedBox` with its own decoration, so each is counted once.
  Iterable<BoxDecoration> decorations(WidgetTester tester, Finder of) => {
    for (final b in tester.widgetList<DecoratedBox>(
      find.descendant(of: of, matching: find.byType(DecoratedBox)),
    ))
      if (b.decoration case final BoxDecoration d) d,
  };

  Color? edge(BoxDecoration d) => (d.border as Border?)?.top.color;

  group('QuizAnswerCard', () {
    BoxDecoration card(WidgetTester tester) => decorations(
      tester,
      find.byType(QuizAnswerCard),
    ).singleWhere((d) => d.border != null);

    Future<void> pumpCard(WidgetTester tester, QuizAnswerState state) => pump(
      tester,
      body(
        QuizAnswerCard(letter: 'A', label: 'Answer', state: state, onTap: null),
      ),
    );

    testWidgets('unanswered: outlineFaint edge on a cardDepth band — not the '
        'divider; textAnswerLetter letter, textStrong label', (tester) async {
      await pumpCard(tester, QuizAnswerState.normal);
      expect(card(tester).color, surface);
      expect(edge(card(tester)), outlineFaint);
      expect(card(tester).boxShadow!.single.color, cardDepth);
      expect(textColor(tester, 'A'), textAnswerLetter);
      expect(textColor(tester, 'Answer'), textStrong);
    });

    testWidgets('correct: successOutline edge, no band', (tester) async {
      await pumpCard(tester, QuizAnswerState.selectedCorrect);
      expect(edge(card(tester)), successOutline);
      expect(card(tester).boxShadow, isNull);
      expect(textColor(tester, 'A'), textAnswerLetter);
    });

    testWidgets('wrong: errorOutline edge, no band', (tester) async {
      await pumpCard(tester, QuizAnswerState.selectedWrong);
      expect(edge(card(tester)), errorOutline);
      expect(card(tester).boxShadow, isNull);
    });
  });

  group('QuizFeedbackCard', () {
    testWidgets('correct: successInk title (not the outline), textMuted '
        'explanation, outlineFaint edge', (tester) async {
      await pump(
        tester,
        body(
          const QuizFeedbackCard(
            correct: true,
            correctLetter: 'A',
            explanation: 'Because',
          ),
        ),
      );
      expect(
        textColor(tester, CourseLearningStrings.quizCorrectTitle),
        successInk,
      );
      expect(textColor(tester, 'Because'), textMuted);
      final card = decorations(tester, find.byType(QuizFeedbackCard)).single;
      expect(card.color, surface);
      expect(edge(card), outlineFaint);
    });

    testWidgets('wrong: errorInk title, textStrong correct answer', (
      tester,
    ) async {
      await pump(
        tester,
        body(
          const QuizFeedbackCard(
            correct: false,
            correctLetter: 'B',
            explanation: 'Because',
          ),
        ),
      );
      expect(textColor(tester, CourseLearningStrings.quizWrongTitle), errorInk);
      expect(
        textColor(tester, CourseLearningStrings.quizCorrectAnswerIs('B')),
        textStrong,
      );
    });
  });

  testWidgets('QuizProgressHeader: accent on the divider track; a page close '
      'button — surface, outline, textPrimary, not the media roles', (
    tester,
  ) async {
    await pump(
      tester,
      body(QuizProgressHeader(current: 1, total: 2, onClose: () {})),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.color, accent);
    expect(bar.backgroundColor, divider);
    expect(
      textColor(tester, CourseLearningStrings.quizProgressCounter(1, 2)),
      textTitle,
    );

    final disc = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(QuizProgressHeader),
            matching: find.byType(Material),
          ),
        )
        .singleWhere((m) => m.shape is CircleBorder);
    expect(disc.color, surface);
    expect((disc.shape! as CircleBorder).side.color, outline);
    expect(tester.widget<Icon>(find.byIcon(Icons.close)).color, textPrimary);
  });

  group('QuizPreviewCard', () {
    testWidgets('outline card; a finished attempt\'s score is warning — not '
        'the result screen\'s warningInk', (tester) async {
      await pump(
        tester,
        body(
          QuizPreviewCard(
            moduleCaption: 'Module 1',
            quiz: sampleQuiz(lastResult: sampleLastResult(percent: 80)),
            onStart: () {},
          ),
        ),
      );
      final card = decorations(
        tester,
        find.byType(QuizPreviewCard),
      ).firstWhere((d) => d.color == surface);
      expect(edge(card), outline);
      expect(textColor(tester, '80%'), warning);
      expect(textColor(tester, 'Module 1'), textSecondary);
      expect(
        textColor(tester, CourseLearningStrings.yourScoreLabel),
        textSecondary,
      );
      expect(textColor(tester, 'Sample quiz'), textPrimary);
    });
  });

  testWidgets('result screen: warningInk score (not warning); a border-edged '
      'list with divider rules; palette text', (tester) async {
    await pump(
      tester,
      const CourseQuizResultScreen(
        title: 'Result',
        result: QuizAttemptResult(
          attemptId: 1,
          correct: 1,
          total: 3,
          percent: 33,
          passed: false,
          questions: [
            QuizQuestionResult(questionId: 1, order: 1, correct: true),
            QuizQuestionResult(questionId: 2, order: 2, correct: false),
            QuizQuestionResult(questionId: 3, order: 3, correct: false),
          ],
        ),
      ),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      surfaceSubtle,
    );
    expect(textColor(tester, 'Result'), textTitle);
    expect(textColor(tester, '33%'), warningInk);
    expect(
      textColor(tester, CourseLearningStrings.yourScoreLabel),
      textSecondary,
    );

    // The list card: the bordered, filled one (a `Divider` is a bordered
    // box too, with no fill).
    final list = decorations(
      tester,
      find.byType(CourseQuizResultScreen),
    ).singleWhere((d) => d.border != null && d.color != null);
    expect(list.color, surface);
    expect(edge(list), border);
    expect(
      tester.widgetList<Divider>(find.byType(Divider)).map((d) => d.color),
      [divider, divider],
    );

    final row = find.byType(QuizResultQuestionRow).first;
    Color? rowText(String text) => tester
        .widget<Text>(find.descendant(of: row, matching: find.text(text)))
        .style
        ?.color;
    expect(rowText('1'), textSecondary);
    expect(rowText(CourseLearningStrings.quizResultQuestionLabel), textPrimary);
  });

  group('CourseQuizScreen', () {
    testWidgets('surfaceSubtle page, textTitle question', (tester) async {
      await pump(
        tester,
        CourseQuizScreen(
          quiz: sampleQuiz(),
          repository: FakeCourseLearningRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        surfaceSubtle,
      );
      expect(
        textColor(tester, 'Pick the right answer (first question)'),
        textTitle,
      );
    });

    testWidgets('starting: primary spinner', (tester) async {
      final repository = FakeCourseLearningRepository(holdStartQuiz: true);
      await pump(
        tester,
        CourseQuizScreen(quiz: sampleQuiz(), repository: repository),
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        primary,
      );
      repository.releaseStartQuiz();
      await tester.pumpAndSettle();
    });
  });
}
