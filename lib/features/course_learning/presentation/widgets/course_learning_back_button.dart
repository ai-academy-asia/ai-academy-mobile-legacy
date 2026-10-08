import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../course_learning_strings.dart';

/// Back navigation for the Course Learning screens.
///
/// A revision of the earlier decision to keep `CourseDetailScreen`'s bare
/// icon-in-an-`InkWell` pattern here: this screen's own Figma reference
/// draws a distinct 40 x 40 circular control (white fill, [_borderColor]
/// outline, a soft shadow), and that is now what this implements, on
/// direction to match it rather than defer to the plainer app-wide pattern.
class CourseLearningBackButton extends StatelessWidget {
  const CourseLearningBackButton({super.key, this.icon = AppIcons.caretLeft});

  static const double _size = 40;

  /// The glyph in the circle: the caret every Course Learning frame draws by
  /// default; the Adult attendance frame draws [AppIcons.arrowLeft].
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // Colours by role (Dark Mode Phase 3, Issue #258): a `surface` disc in an
    // `outline` ring — the reference's own cooler grey, not the field
    // `border` — with a soft black lift and a `textPrimary` glyph.
    final palette = context.palette;
    return Padding(
      // 12 above, not the screen's 16: the reference puts this control's top
      // edge 12 below the safe-area inset.
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        12,
        AppDimens.screenPadding,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          label: CourseLearningStrings.back,
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
