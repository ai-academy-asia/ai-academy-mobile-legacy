import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';
import 'exercise_text_field.dart' show exerciseBorderColor;

/// Shown under the answer list once the student has picked one: a green
/// "correct" title, or a red "wrong" title with the correct letter spelled
/// out, either way followed by the question's own explanation.
class QuizFeedbackCard extends StatelessWidget {
  const QuizFeedbackCard({
    required this.correct,
    required this.correctLetter,
    required this.explanation,
    super.key,
  });

  final bool correct;

  /// e.g. "A" — only shown when [correct] is false.
  final String correctLetter;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.success : AppColors.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
          Text(
            correct
                ? CourseLearningStrings.quizCorrectTitle
                : CourseLearningStrings.quizWrongTitle,
            style: AppTypography.heading.copyWith(fontSize: 20, color: color),
          ),
          if (!correct) ...[
            const SizedBox(height: 4),
            Text(
              CourseLearningStrings.quizCorrectAnswerIs(correctLetter),
              style: AppTypography.settingsRowLabel.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            explanation,
            style: AppTypography.settingsRowLabel.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
