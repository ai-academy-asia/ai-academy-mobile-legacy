import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_icons.dart';

/// The app's back control: a 40 x 40 circle (a `surface` disc in an `outline`
/// ring, a soft lift) that pops the current route.
///
/// First drawn for the Course Learning screens — a revision of the earlier
/// decision to keep `CourseDetailScreen`'s bare icon-in-an-`InkWell` pattern:
/// their Figma reference draws this distinct circular control, and that is
/// what this implements. Moved here unchanged from
/// `course_learning/presentation/widgets/course_learning_back_button.dart`
/// (Issue #327), since screens across the app use it — the attendance,
/// contract, certificate, notification, payment, password and teacher
/// screens as well as Course Learning — and a shared widget should not live
/// inside one feature. It holds its own [label] for the same reason, so
/// `shared/` depends on no feature.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.icon = AppIcons.arrowLeft});

  /// What assistive technology announces. The text it has always had;
  /// `CourseLearningStrings.back` is this.
  static const String label = 'Back';

  static const double _size = AppDimens.backButtonSize;

  /// The glyph in the circle: the arrow, on every page (Issue #368 — the
  /// Course Learning frames' caret was the one exception, now aligned).
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // Colours by role (Dark Mode Phase 3, Issue #258): a `surface` disc in an
    // `outline` ring — the reference's own cooler grey, not the field
    // `border` — with a soft black lift and a `textPrimary` glyph.
    final palette = context.palette;
    return Padding(
      // [AppDimens.backButtonTop] above, not the screen's 16: the reference
      // puts this control's top edge 12 below the safe-area inset.
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        AppDimens.backButtonTop,
        AppDimens.screenPadding,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: palette.surface,
            shape: CircleBorder(side: BorderSide(color: palette.outline)),
            // Black @ 8 %, exactly as before: `shadowSubtle`'s hue at the
            // reference's own 0.08 (the role's 0x14 is 0.0784 and moves a
            // pixel).
            shadowColor: palette.shadowSubtle.withValues(alpha: 0.08),
            elevation: 2,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: _size,
                height: _size,
                child: Icon(icon, size: 20, color: palette.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
