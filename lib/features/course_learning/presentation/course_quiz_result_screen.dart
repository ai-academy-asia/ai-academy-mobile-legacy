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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  32,
                  AppDimens.screenPadding,
                  16,
                ),
                child: Column(
                  children: [
                    Text(
                      quiz.resultTitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.heading.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      CourseLearningStrings.yourScoreLabel,
                      textAlign: TextAlign.center,
                      style: AppTypography.cardSupporting.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$percent%',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading.copyWith(
                        fontSize: 32,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      CourseLearningStrings.quizResultSummary(total, correct),
                      textAlign: TextAlign.center,
                      style: AppTypography.settingsRowLabel.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                              const Divider(height: 1, color: AppColors.border),
                            QuizResultQuestionRow(
                              number: i + 1,
                              correct:
                                  answers[i] == quiz.questions[i].correctOptionIndex,
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
