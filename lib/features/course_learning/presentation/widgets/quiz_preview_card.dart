import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_quiz.dart';
import '../course_learning_strings.dart';
import '../course_quiz_screen.dart';
import 'exercise_submit_button.dart';
import 'exercise_text_field.dart' show exerciseBorderColor;

/// The Quiz preview/result card on Exercise Detail — a separate bordered
/// card below the Assignment/Course materials/Note tab card, not one more
/// tab inside it (see `CourseExerciseDetailScreen`'s own doc comment on why
/// Quiz moved out of the tab set). Shows "Start quiz" until the quiz has
/// been completed at least once, then the last score plus "Дахин quiz
/// өгөх" (retry).
///
/// [result] and [onResult] are owned by `CourseExerciseDetailScreen`, the
/// same lifting `_note` already needed: a result reached through
/// `CourseQuizScreen`/`CourseQuizResultScreen` (both pushed on top of this
/// screen) must still be showing here once the student pops back to it.
class QuizPreviewCard extends StatelessWidget {
  const QuizPreviewCard({
    required this.moduleCaption,
    required this.quiz,
    required this.result,
    required this.onResult,
    super.key,
  });

  final String moduleCaption;

  /// Null means this exercise has no quiz — the card renders nothing.
  final CourseQuiz? quiz;

  /// The last completed attempt's score, or null if the quiz has never been
  /// finished yet.
  final ({int correct, int total})? result;

  final ValueChanged<({int correct, int total})> onResult;

  Future<void> _start(BuildContext context, CourseQuiz quiz) async {
    final outcome = await Navigator.of(context).push<({int correct, int total})>(
      MaterialPageRoute(builder: (_) => CourseQuizScreen(quiz: quiz)),
    );
    if (outcome != null) onResult(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final quiz = this.quiz;
    if (quiz == null) return const SizedBox.shrink();

    final result = this.result;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: exerciseBorderColor,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(moduleCaption, style: AppTypography.catalogSectionLabel),
              Text(
                CourseLearningStrings.quizQuestionCount(quiz.questions.length),
                style: AppTypography.catalogSectionLabel,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quiz.title,
            style: AppTypography.cardHeading.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (result == null)
            Center(
              child: ExerciseSubmitButton(
                label: CourseLearningStrings.startQuiz,
                onPressed: () => _start(context, quiz),
              ),
            )
          else ...[
            Center(
              child: Column(
                children: [
                  Text(
                    CourseLearningStrings.yourScoreLabel,
                    style: AppTypography.cardSupporting,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(result.correct / result.total * 100).round()}%',
                    style: AppTypography.heading.copyWith(
                      fontSize: 28,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ExerciseSubmitButton(
                label: CourseLearningStrings.retakeQuiz,
                onPressed: () => _start(context, quiz),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
