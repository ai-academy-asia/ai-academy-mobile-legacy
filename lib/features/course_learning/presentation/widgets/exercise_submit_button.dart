import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// The pill submit button under the Assignment link/description fields and
/// under the Note textarea — 329 x 44, disabled.
///
/// Unconditionally disabled: submitting, and everything that follows it
/// (upload progress, resubmission, mentor feedback progressing past "No
/// feedback yet"), is reserved for a separate future issue — see
/// `CourseExerciseDetailScreen`'s own doc comment. Not `AppButton`: that
/// widget has no disabled-with-shadow treatment (its disabled state is flat),
/// and is fixed to `AppDimens.buttonHeight` (44) at *full width*, whereas the
/// reference measures this at 329, inset from the 361pt card — reusing it
/// here would mean widening its contract for a state and a width it has never
/// needed elsewhere.
class ExerciseSubmitButton extends StatelessWidget {
  const ExerciseSubmitButton({
    super.key,
    this.label = CourseLearningStrings.submit,
  });

  /// Defaults to "Submit"; the existing-note card's disabled "Засах" (edit)
  /// button is the same pill with a different label, not a separate widget.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      child: Container(
        width: 329,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
