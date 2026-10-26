import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_quiz.dart';
import '../course_learning_strings.dart';
import 'exercise_submit_button.dart';

/// The Quiz preview/result card on Exercise Detail — a separate bordered
/// card below the Assignment/Course materials/Note tab card, not one more
/// tab inside it (see `CourseExerciseDetailScreen`'s own doc comment on why
/// Quiz moved out of the tab set). Everything it shows is the server's §2.7
/// summary: "Start quiz" until an attempt has finished, then `last_result`'s
/// own percentage plus "Дахин quiz өгөх" (retry) — hidden once
/// `attempts_left` reaches 0 (§2.7 Q23).
///
/// Starting is [onStart]'s: `CourseExerciseDetailScreen` pushes
/// `CourseQuizScreen` and re-reads the summary when it returns.
class QuizPreviewCard extends StatelessWidget {
  const QuizPreviewCard({
    required this.moduleCaption,
    required this.quiz,
    required this.onStart,
    super.key,
  });

  final String moduleCaption;

  /// Null means this exercise has no quiz — the card renders nothing.
  final CourseQuiz? quiz;

  /// "Start quiz" / "Дахин quiz өгөх" — both start (or resume) an attempt.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final quiz = this.quiz;
    if (quiz == null) return const SizedBox.shrink();

    final result = quiz.lastResult;
    final palette = context.palette;

    // The same bordered-card language as Exercise Detail's material and
    // attachment cards: `surface` on an `outline` edge.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.outline,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Each side flexes, so larger text wraps them rather than the row
          // overflowing (Issue #541); at the default size both fit as before.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  moduleCaption,
                  style: AppTypography.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  CourseLearningStrings.quizQuestionCount(quiz.questionCount),
                  style: AppTypography.caption.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quiz.title,
            style: AppTypography.itemTitle.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 16),
          if (result == null)
            Center(
              child: ExerciseSubmitButton(
                label: CourseLearningStrings.startQuiz,
                onPressed: onStart,
              ),
            )
          else ...[
            Center(
              child: Column(
                children: [
                  Text(
                    CourseLearningStrings.yourScoreLabel,
                    style: AppTypography.supporting.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.percent}%',
                    // `warning`, as this score always was — the result
                    // screen's darker score is `warningInk`.
                    style: AppTypography.display.copyWith(
                      color: palette.warning,
                    ),
                  ),
                ],
              ),
            ),
            if (quiz.canRetake) ...[
              const SizedBox(height: 16),
              Center(
                child: ExerciseSubmitButton(
                  label: CourseLearningStrings.retakeQuiz,
                  onPressed: onStart,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
