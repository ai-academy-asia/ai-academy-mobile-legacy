import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/course_quiz.dart';
import 'course_learning_strings.dart';
import 'widgets/exercise_submit_button.dart';
import 'widgets/quiz_result_question_row.dart';

/// The Quiz Result screen — its own full screen, reached by
/// `CourseQuizScreen.pushReplacement`-ing itself in once the last question is
/// answered. Shows the dynamically-computed score, a plain-language summary,
/// and a per-question correct/incorrect list; "Дуусгах" pops back to
/// Exercise Detail, whose `QuizPreviewCard` then switches to its own result
/// state — see `CourseQuizScreen`'s own doc comment on how that score
/// reaches it.
/// Sampled off the Quiz result frame at 1:1. The title fits one line there;
/// at the 22 this used it wrapped to two and pulled the whole column up.
const Color _page = Color(0xFFF9FAFB);
const Color _titleInk = Color(0xFF191919);
const Color _scoreInk = Color(0xFFDD940E);
const double _titleSize = 18;

/// The reference opens the column well below the safe area — there is no
/// header on this screen, so the title carries the whole top inset.
const double _topPadding = 80;
const double _titleToScoreLabel = 13;
const double _scoreLabelToScore = 4;
const double _scoreToSummary = 20;
const double _summaryToList = 12;

/// Sampled off the Quiz result frame at 1:1: the CTA runs the full content
/// column, and the row dividers are lighter than [AppColors.border].
const double _ctaWidth = 361;
const Color _rowDivider = Color(0xFFEAEDF0);

class CourseQuizResultScreen extends StatelessWidget {
  const CourseQuizResultScreen({
    required this.quiz,
    required this.answers,
    super.key,
  });

  final CourseQuiz quiz;
  final Map<int, int> answers;

  @override
  Widget build(BuildContext context) {
    final total = quiz.questions.length;
    final correct = quizScore(quiz, answers);
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();

    return Scaffold(
      backgroundColor: _page,
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
                      quiz.resultTitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.heading.copyWith(
                        fontSize: _titleSize,
                        color: _titleInk,
                      ),
                    ),
                    const SizedBox(height: _titleToScoreLabel),
                    Text(
                      CourseLearningStrings.yourScoreLabel,
                      textAlign: TextAlign.center,
                      style: AppTypography.cardSupporting.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: _scoreLabelToScore),
                    Text(
                      '$percent%',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading.copyWith(
                        fontSize: 32,
                        color: _scoreInk,
                      ),
                    ),
                    const SizedBox(height: _scoreToSummary),
                    // Left-aligned, unlike the three centred lines above it —
                    // the reference sets it against the content column's edge.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CourseLearningStrings.quizResultSummary(total, correct),
                        style: AppTypography.settingsRowLabel.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: _summaryToList),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border,
                          width: AppDimens.borderWidth,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < total; i++) ...[
                            if (i != 0)
                              const Divider(height: 1, color: _rowDivider),
                            QuizResultQuestionRow(
                              number: i + 1,
                              correct:
                                  answers[i] ==
                                  quiz.questions[i].correctOptionIndex,
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
    );
  }
}
