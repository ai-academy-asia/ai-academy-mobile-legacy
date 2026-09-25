import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import 'exercise_text_field.dart' show exerciseBorderColor;

enum QuizAnswerState { normal, selectedCorrect, selectedWrong }

/// One 361 x 56 option row on `CourseQuizScreen`: a letter (A/B/C/D), the
/// option's own text, and — once the student has answered — a state icon on
/// the trailing edge. The option that was *not* picked stays in
/// [QuizAnswerState.normal] even when the pick was wrong, matching the
/// reference (it does not also highlight the correct answer).
class QuizAnswerCard extends StatelessWidget {
  const QuizAnswerCard({
    required this.letter,
    required this.label,
    required this.state,
    required this.onTap,
    super.key,
  });

  final String letter;
  final String label;
  final QuizAnswerState state;

  /// Null once an answer has been locked in for this question — the row no
  /// longer responds to taps.
  final VoidCallback? onTap;

  Color get _color => switch (state) {
    QuizAnswerState.normal => exerciseBorderColor,
    QuizAnswerState.selectedCorrect => AppColors.success,
    QuizAnswerState.selectedWrong => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: state != QuizAnswerState.normal,
      label: label,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _color, width: AppDimens.borderWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  letter,
                  style: AppTypography.cardHeading.copyWith(
                    color: state == QuizAnswerState.normal
                        ? AppColors.textSecondary
                        : _color,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.settingsRowLabel.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (state == QuizAnswerState.selectedCorrect)
                  const Icon(AppIcons.check, size: 24, color: AppColors.success)
                else if (state == QuizAnswerState.selectedWrong)
                  const Icon(AppIcons.xCircle, size: 24, color: AppColors.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
