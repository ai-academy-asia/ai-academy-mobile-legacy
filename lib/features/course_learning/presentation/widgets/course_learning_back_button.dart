import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../course_learning_strings.dart';

/// The Figma reference's own border colour for this control — a cooler,
/// lighter grey than [AppColors.border]. Nothing in the shared palette
/// matches it, so it stays a local constant here rather than in
/// `AppColors`, which is sampled from the Login/Home/Catalog references,
/// not this one.
const Color _borderColor = AppColors.outline;

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
            color: AppColors.surface,
            shape: const CircleBorder(side: BorderSide(color: _borderColor)),
            shadowColor: Colors.black.withValues(alpha: 0.08),
            elevation: 2,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: _size,
                height: _size,
                child: Icon(icon, size: 20, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
