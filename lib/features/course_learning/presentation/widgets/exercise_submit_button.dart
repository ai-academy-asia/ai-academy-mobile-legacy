import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// The pill submit button under the Assignment link/description fields and
/// under the Note textarea — 329 x 44.
///
/// Disabled (grey fill, no tap) when [onPressed] is null — the Note tab's
/// two uses stay exactly this way, since leaving a note/editing it is still
/// reserved for a future issue (see `CourseExerciseDetailScreen`'s own doc
/// comment). The Assignment tab now passes a real [onPressed] for its
/// "Submit"/"Resubmit" states, which fills the pill with
/// [AppColors.blue] instead — the same primary-pill treatment
/// `CourseModuleListScreen`'s "Continue learning" button already uses, not a
/// new one invented for this. Not `AppButton`: that widget has no
/// disabled-with-shadow treatment (its disabled state is flat), and is fixed
/// to `AppDimens.buttonHeight` (44) at *full width*, whereas the reference
/// measures this at 329, inset from the 361pt card — reusing it here would
/// mean widening its contract for a state and a width it has never needed
/// elsewhere.
class ExerciseSubmitButton extends StatelessWidget {
  const ExerciseSubmitButton({
    super.key,
    this.label = CourseLearningStrings.submit,
    this.onPressed,
  });

  /// Defaults to "Submit"; the existing-note card's disabled "Засах" (edit)
  /// button is the same pill with a different label, not a separate widget.
  final String label;

  /// Null renders the original disabled look. Non-null renders the enabled,
  /// blue-filled look and makes the pill tappable.
  final VoidCallback? onPressed;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 329,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _enabled ? AppColors.blue : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _enabled
                      ? AppColors.blue.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: _enabled ? 10 : 6,
                  offset: Offset(0, _enabled ? 4 : 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _enabled ? AppColors.onPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
