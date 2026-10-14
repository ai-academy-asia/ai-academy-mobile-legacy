import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/course_quiz.dart';
import 'course_learning_strings.dart';
import 'widgets/exercise_submit_button.dart';
import 'widgets/quiz_result_question_row.dart';

/// The Quiz Result screen — its own full screen, reached by
/// `CourseQuizScreen.pushReplacement`-ing itself in once the attempt is
/// finished. Shows the server-graded [result] as sent — its percentage, a
/// plain-language summary from its counts, and its per-question
/// correct/incorrect list — never a score worked out here. "Дуусгах" pops
/// back to Exercise Detail, whose `QuizPreviewCard` then shows the quiz's
/// refreshed `last_result`.
/// Sampled off the Quiz result frame at 1:1. The page is
/// `AppPalette.surfaceSubtle`, the title `textTitle` and the score amber ink
/// (`warningInk`).

/// The reference opens the column well below the safe area — there is no
/// header on this screen, so the title carries the whole top inset.
const double _topPadding = 80;
const double _titleToScoreLabel = 13;
const double _scoreLabelToScore = 4;
const double _scoreToSummary = 20;
const double _summaryToList = 12;

/// Sampled off the Quiz result frame at 1:1: the CTA runs the full content
/// column. The list card's edge is `AppPalette.border`, and the rules
/// between its rows the lighter `divider`.
const double _ctaWidth = 361;

class CourseQuizResultScreen extends StatelessWidget {
  const CourseQuizResultScreen({
    required this.title,
    required this.result,
    super.key,
  });

  /// `CourseQuiz.resultTitle`.
  final String title;

  /// §2.7's finish answer.
  final QuizAttemptResult result;

  @override
  Widget build(BuildContext context) {
    final questions = result.questions;
    final palette = context.palette;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Its own style: the page below stops painting once covered,
      // and its style would stay (Issue #400).
      value: AppSystemUi.page(context, navigationBar: palette.surfaceSubtle),
      child: Scaffold(
        backgroundColor: palette.surfaceSubtle,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.screenPadding,
                    _topPadding,
                    AppDimens.screenPadding,
                    16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTypography.sectionTitle.copyWith(
                          color: palette.textTitle,
                        ),
                      ),
                      const SizedBox(height: _titleToScoreLabel),
                      Text(
                        CourseLearningStrings.yourScoreLabel,
                        textAlign: TextAlign.center,
                        style: AppTypography.supporting.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: _scoreLabelToScore),
                      Text(
                        '${result.percent}%',
                        textAlign: TextAlign.center,
                        style: AppTypography.display.copyWith(
                          color: palette.warningInk,
                        ),
                      ),
                      const SizedBox(height: _scoreToSummary),
                      // Left-aligned, unlike the three centred lines above it —
                      // the reference sets it against the content column's edge.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CourseLearningStrings.quizResultSummary(
                            result.total,
                            result.correct,
                          ),
                          style: AppTypography.body.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: _summaryToList),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: palette.border,
                            width: AppDimens.borderWidth,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (i, question) in questions.indexed) ...[
                              if (i != 0)
                                Divider(height: 1, color: palette.divider),
                              QuizResultQuestionRow(
                                number: i + 1,
                                correct: question.correct,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Center(
                  child: ExerciseSubmitButton(
                    width: _ctaWidth,
                    label: CourseLearningStrings.quizFinish,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
