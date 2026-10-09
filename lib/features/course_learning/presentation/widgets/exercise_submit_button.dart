import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
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
/// the screen's blue instead — the same primary-pill treatment
/// `CourseModuleListScreen`'s "Continue learning" button already uses, not a
/// new one invented for this. Not `AppButton`: that widget has no
/// disabled-with-shadow treatment (its disabled state is flat), and is fixed
/// to `AppDimens.buttonHeight` (44) at *full width*, whereas the reference
/// measures this at 329, inset from the 361pt card — reusing it here would
/// mean widening its contract for a state and a width it has never needed
/// elsewhere.
/// Sampled off the reference frames at 1:1. Every primary CTA measures
/// 329 x 44: an `AppPalette.accent` fill and `onPrimary` label on a 4pt
/// `primaryDepth` band. The disabled pill is the same shape in the muted
/// set Phase 5 fixed for `HomePillButton` — `surfaceSubtle` fill, `divider`
/// outline, `disabledInk` label, `neutralDepth` band.
const double _depthOffset = 4;
const double _defaultWidth = 329;

class ExerciseSubmitButton extends StatelessWidget {
  const ExerciseSubmitButton({
    super.key,
    this.label = CourseLearningStrings.submit,
    this.onPressed,
    this.muted = false,
    this.width = _defaultWidth,
  });

  /// Defaults to "Submit"; the existing-note card's disabled "Засах" (edit)
  /// button is the same pill with a different label, not a separate widget.
  final String label;

  /// Null renders the original disabled look. Non-null renders the enabled,
  /// blue-filled look and makes the pill tappable.
  final VoidCallback? onPressed;

  /// Draws the muted (grey) palette even with a live [onPressed].
  ///
  /// The existing-note card's "Засах" needs this: the reference frame draws
  /// that button grey, but the two frames after it are the note being edited,
  /// which is reached by tapping it — so it is the reference's secondary
  /// treatment, not a disabled control, and rendering it from `onPressed ==
  /// null` would make those two states unreachable.
  final bool muted;

  /// The Exercise frames draw this pill at 329 inside their 361 card; the
  /// Quiz frames run it the full 361 of the page's content column. Same
  /// button, two widths.
  final double width;

  bool get _enabled => onPressed != null;

  bool get _filled => _enabled && !muted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
            width: width,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _filled ? palette.accent : palette.surfaceSubtle,
              borderRadius: BorderRadius.circular(22),
              // The disabled pill is outlined in the frames; the filled one
              // is not.
              border: _filled
                  ? null
                  : Border.all(color: palette.divider, width: 1),
              // A flat band, not a glow: beside the button's edge the
              // reference is plain page, and below it is four rows of one
              // colour. Same treatment `CourseModuleCard` and the module
              // list's "Continue learning" already use.
              boxShadow: [
                BoxShadow(
                  color: _filled ? palette.primaryDepth : palette.neutralDepth,
                  offset: const Offset(0, _depthOffset),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _filled ? palette.onPrimary : palette.disabledInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
