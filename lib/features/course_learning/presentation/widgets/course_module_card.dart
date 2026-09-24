import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_module.dart';
import '../course_learning_strings.dart';

/// Figma measurement: the card is 361 x 86, its icon container 56 x 56, its
/// completed check 24 x 24, and — a separate, smaller element for the locked
/// state, not a resized version of the same one — its locked icon container
/// 32 x 32.
const double _iconSlot = 56;
const double _lockedIconSize = 32;
const double _checkSize = 24;

/// One module row on the Course Learning overview screen.
///
/// Two states, matching what the Figma sample actually shows — nothing in
/// between, see `CourseModule.locked`'s doc comment:
///
///  * **Completed/open** — [CourseModule.iconAsset] in a soft tint of its own
///    [CourseModule.accentColor] (the same "flat colour at low alpha behind an
///    icon" treatment `ProgramCard`'s pills already use), plus a green check
///    when [CourseModule.completed].
///  * **Locked** — a plain lock glyph in a small grey tile instead of the
///    module's own icon. `Icons.lock_outline` rather than a bundled Phosphor
///    glyph or a grey copy of the module SVG: the Figma reference draws the
///    same generic padlock for every locked module regardless of topic, and
///    nothing in `AppIcons` has a confirmed lock codepoint to reuse.
///
/// The card style — white surface, [AppColors.border] outline,
/// [AppDimens.homeCardRadius] — matches every other card in the app, but adds
/// a soft shadow, which no other screen's cards do. That shadow is new for
/// this screen: the Figma reference draws one on every card here, and there
/// is no existing "flat, bordered, no shadow" pattern to defer to instead.
class CourseModuleCard extends StatelessWidget {
  const CourseModuleCard({required this.module, super.key, this.onTap});

  final CourseModule module;

  /// Null when [CourseModule.locked] — a locked module has nothing to open.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = module.locked;
    final titleColor = locked ? AppColors.textSecondary : AppColors.textPrimary;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      // No `elevation`: Material's own elevation shadow reads as a hard drop
      // shadow at any non-zero value, but the Figma reference's is soft and
      // diffuse — painted explicitly on the `Container` below instead.
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
            border: Border.all(
              color: AppColors.border,
              width: AppDimens.borderWidth,
            ),
            boxShadow: [
              // Tighter blur than a diffuse drop shadow, so the depth reads
              // mostly along the bottom edge rather than as an even glow all
              // the way around — a "lifted" card, not a dropped-shadow one.
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ModuleIcon(module: module),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${CourseLearningStrings.moduleCaption} ${module.order}',
                      style: AppTypography.catalogSectionLabel,
                    ),
                    const SizedBox(height: 2),
                    // `cardHeading` alone (15/600) reads too light for the
                    // reference's title — bumped a size and a weight, the
                    // same kind of local `copyWith` `CohortCard`'s own
                    // `_titleStyle` already does off the same base style.
                    Text(
                      module.title,
                      style: AppTypography.cardHeading.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // A step below the `Modules N` caption, matching the
                    // reference's own smaller, quieter metadata line.
                    Text(
                      module.scheduleLabel,
                      style: AppTypography.cardSupporting,
                    ),
                  ],
                ),
              ),
              if (module.completed) ...[
                const SizedBox(width: 8),
                const _CompletedCheck(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({required this.module});

  final CourseModule module;

  @override
  Widget build(BuildContext context) {
    if (module.locked) {
      return SizedBox(
        width: _iconSlot,
        height: _iconSlot,
        child: Center(
          child: Container(
            width: _lockedIconSize,
            height: _lockedIconSize,
            decoration: BoxDecoration(
              // `surfaceMuted` (near-white) barely registered against the
              // card's own white fill — `border`'s cool grey is the closest
              // existing token with enough contrast to actually read as a
              // tile, matching the reference's clearly visible container.
              color: AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      width: _iconSlot,
      height: _iconSlot,
      decoration: BoxDecoration(
        color: module.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
      ),
      padding: const EdgeInsets.all(12),
      child: SvgPicture.asset(module.iconAsset, fit: BoxFit.contain),
    );
  }
}

class _CompletedCheck extends StatelessWidget {
  const _CompletedCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _checkSize,
      height: _checkSize,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
      child: const Icon(AppIcons.check, size: 14, color: AppColors.onPrimary),
    );
  }
}
