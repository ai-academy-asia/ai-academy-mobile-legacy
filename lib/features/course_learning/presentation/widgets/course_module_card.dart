import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_module.dart';
import '../course_learning_strings.dart';

/// Measured off the reference frame at 1:1. The card box is 86 tall and its
/// icon tile 56 square, vertically centred in it — (86 - 56) / 2 lands the tile
/// exactly where the reference draws it. The locked state uses the *same* 56
/// tile, in flat grey, rather than a smaller one.
const double _cardHeight = 86;
const double _iconSlot = 56;
const double _checkSize = 20;

/// The completed badge, drawn at the 20 x 20 the reference measures — the
/// file's own native size. It carries its own colour and its own filled disc,
/// so it is neither tinted nor placed on a circle.
const String _checkAsset =
    'assets/images/course_learning/course_detail_completed_check.svg';

/// The design's padlock, at the 24 x 27 the reference measures — its own
/// native size. It carries its own colour, so it is not tinted.
///
/// The file as first supplied would not render: two of its right-hand corner
/// curves were damaged, and `flutter_svg` drops a path it cannot parse
/// silently, painting nothing. Both were repaired by mirroring the left edge
/// of the same path, which is geometrically identical — a missing `22.5304 9`
/// control point at the top-right, and a bottom-right control y of `26.7893`
/// (the top corner's value) where the mirror gives `26.0391`.
const String _lockAsset =
    'assets/images/course_learning/course_detail_lock.svg';
const double _lockWidth = 24;
const double _lockHeight = 27;

/// The tile's inset from the card's edge, and the gap from tile to text: the
/// reference's text column starts at 96, which is the card's own left edge
/// (16) + 12 + the 56 tile + 12.
const double _tileInset = 12;
const double _tileToText = 12;

/// The reference draws the card's depth as a *solid* band under it, not a
/// blur: four rows of flat [_border] below the bottom edge, then white. A
/// blurred shadow reads as a different material entirely.
const double _liftOffset = 4;

/// Sampled off the reference at 1:1. [_border] is the card outline, the band
/// beneath it and the connector; the app-wide [AppColors.border] (#E4E6EF) is
/// a different, warmer grey used by other screens.
const Color _border = AppColors.divider;
const Color _titleInk = AppColors.textTitle;
const Color _lockedTitleInk = AppColors.textLocked;
const Color _secondaryInk = AppColors.textSupporting;
const Color _lockedTile = Color(0xFFEFEFEF);

/// How strongly a module's own accent tints its icon tile. Solved from the
/// reference rather than guessed: module 2's #FFC640 over white at this alpha
/// gives #FFF1D1, which is the tile colour the frame draws, to the byte.
const double _tileTintOpacity = 0.24;

/// One module row on the Course Learning overview screen.
///
/// Two states, matching what the Figma sample actually shows — nothing in
/// between, see `CourseModule.locked`'s doc comment:
///
///  * **Completed/open** — [CourseModule.iconAsset] in a soft tint of its own
///    [CourseModule.accentColor] (the same "flat colour at low alpha behind an
///    icon" treatment `ProgramCard`'s pills already use), plus a green check
///    when [CourseModule.completed].
///  * **Locked** — the design's own padlock on the same 56 tile in flat grey,
///    and a dimmed title. One generic padlock for every locked module
///    regardless of topic, which is what the reference draws.
///
/// The card keeps the app's white surface and [AppDimens.homeCardRadius], but
/// its outline, ink and the band beneath it are this reference's own values
/// rather than the shared tokens — see the constants above.
class CourseModuleCard extends StatelessWidget {
  const CourseModuleCard({required this.module, super.key, this.onTap});

  final CourseModule module;

  /// Null when [CourseModule.locked] — a locked module has nothing to open.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = module.locked;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      // No `elevation`: Material's own elevation shadow is a blur, and the
      // reference's depth is a flat band — painted on the `Container` below.
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        child: Container(
          height: _cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: _tileInset),
          decoration: BoxDecoration(
            // The fill is repeated here, not left to the `Material` behind:
            // the band below is a zero-blur shadow, which paints the card's
            // whole silhouette shifted down, so without an opaque background
            // on this same decoration it would cover the card itself.
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
            border: Border.all(color: _border, width: AppDimens.borderWidth),
            boxShadow: const [
              BoxShadow(color: _border, offset: Offset(0, _liftOffset)),
            ],
          ),
          child: Row(
            children: [
              _ModuleIcon(module: module),
              const SizedBox(width: _tileToText),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${CourseLearningStrings.moduleCaption} ${module.order}',
                      style: AppTypography.catalogSectionLabel.copyWith(
                        fontSize: 12,
                        height: 16 / 12,
                        color: _secondaryInk,
                      ),
                    ),
                    // The caption's and title's line boxes sit flush in the
                    // reference — the space between their ink is the two
                    // boxes' own leading, not a gap.
                    Text(
                      module.title,
                      style: AppTypography.cardHeading.copyWith(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w700,
                        color: locked ? _lockedTitleInk : _titleInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      module.scheduleLabel,
                      style: AppTypography.cardSupporting.copyWith(
                        fontSize: 12,
                        height: 16 / 12,
                        color: _secondaryInk,
                      ),
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
      return Container(
        width: _iconSlot,
        height: _iconSlot,
        decoration: BoxDecoration(
          color: _lockedTile,
          borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        ),
        child: Center(
          child: SvgPicture.asset(
            _lockAsset,
            width: _lockWidth,
            height: _lockHeight,
          ),
        ),
      );
    }

    return Container(
      width: _iconSlot,
      height: _iconSlot,
      decoration: BoxDecoration(
        color: module.accentColor.withValues(alpha: _tileTintOpacity),
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      ),
      // No padding: each `module_*.svg` already carries its own margin inside
      // its viewBox, so the artwork still sits ~8 in from the tile's edge. At
      // the 8 this had, the drawing came out 28 wide against the reference's
      // 39 — the inset was being applied twice.
      child: SvgPicture.asset(module.iconAsset, fit: BoxFit.contain),
    );
  }
}

class _CompletedCheck extends StatelessWidget {
  const _CompletedCheck();

  @override
  Widget build(BuildContext context) {
    // The design's own glyph, and it is the whole badge: the filled green
    // disc is part of the artwork, so there is no circle behind it here.
    return SvgPicture.asset(_checkAsset, width: _checkSize, height: _checkSize);
  }
}
