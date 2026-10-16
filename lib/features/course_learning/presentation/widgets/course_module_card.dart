import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_lesson.dart';
import '../../domain/course_module.dart';
import '../course_learning_strings.dart';

/// Measured off the reference frame at 1:1. The card box is 86 tall and its
/// icon tile 56 square, vertically centred in it — (86 - 56) / 2 lands the tile
/// exactly where the reference draws it. The locked state uses the *same* 56
/// tile, in flat grey, rather than a smaller one.
///
/// 86 is the card's *minimum* (Issue #349): at a larger system text size the
/// card grows to hold its three lines rather than clipping the date line. At
/// the default size the text column is exactly the 60 left inside the 1pt
/// edge and the [_tileInset] above and below it, so the card is exactly 86.
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
/// blur: four rows of flat `AppPalette.cardDepth` below the bottom edge, then
/// white. A blurred shadow reads as a different material entirely.
///
/// Sampled off the reference at 1:1, the card's edge (`outlineFaint`), the
/// band and the connector between cards (`divider`) are one grey in light
/// mode, but three roles: an edge, a band and a rule. The app-wide
/// `AppPalette.border` (#E4E6EF) is a different, warmer grey.
const double _liftOffset = 4;

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
/// its outline, ink and the band beneath it are this reference's own roles
/// (`outlineFaint`, `cardDepth`, the opaque text greys) — see above. The
/// tile's tint is the module's authored accent, not a theme colour.
class CourseModuleCard extends StatelessWidget {
  const CourseModuleCard({required this.module, super.key, this.onTap});

  final CourseModule module;

  /// Null when [CourseModule.locked] — a locked module has nothing to open.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = module.locked;
    final palette = context.palette;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      // No `elevation`: Material's own elevation shadow is a blur, and the
      // reference's depth is a flat band — painted on the `Container` below.
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: _cardHeight),
          // The tile's own inset above and below too, so a card that has
          // grown keeps the reference's breathing room around its text.
          padding: const EdgeInsets.all(_tileInset),
          decoration: BoxDecoration(
            // The fill is repeated here, not left to the `Material` behind:
            // the band below is a zero-blur shadow, which paints the card's
            // whole silhouette shifted down, so without an opaque background
            // on this same decoration it would cover the card itself.
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
            border: Border.all(
              color: palette.outlineFaint,
              width: AppDimens.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.cardDepth,
                offset: const Offset(0, _liftOffset),
              ),
            ],
          ),
          child: Row(
            children: [
              _ModuleIcon(
                iconAsset: module.iconAsset,
                accentColor: module.accentColor,
                locked: locked,
              ),
              const SizedBox(width: _tileToText),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${CourseLearningStrings.moduleCaption} ${module.order}',
                      style: AppTypography.caption.copyWith(
                        color: palette.textSupporting,
                      ),
                    ),
                    // The caption's and title's line boxes sit flush in the
                    // reference — the space between their ink is the two
                    // boxes' own leading, not a gap.
                    Text(
                      module.title,
                      style: AppTypography.itemTitle.copyWith(
                        color: locked ? palette.textLocked : palette.textTitle,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      module.scheduleLabel,
                      style: AppTypography.supporting.copyWith(
                        color: palette.textSupporting,
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

/// The card's 56 tile: the module's artwork in a tint of its accent, or the
/// padlock in flat grey when [locked]. Shared by [CourseModuleCard] and
/// [CourseLessonCard], so a lesson wears its module's tile.
class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({
    required this.iconAsset,
    required this.accentColor,
    required this.locked,
  });

  final String iconAsset;
  final Color accentColor;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return Container(
        width: _iconSlot,
        height: _iconSlot,
        decoration: BoxDecoration(
          color: context.palette.surfaceLocked,
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
        color: accentColor.withValues(alpha: _tileTintOpacity),
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      ),
      // No padding: each `module_*.svg` already carries its own margin inside
      // its viewBox, so the artwork still sits ~8 in from the tile's edge. At
      // the 8 this had, the drawing came out 28 wide against the reference's
      // 39 — the inset was being applied twice.
      child: SvgPicture.asset(iconAsset, fit: BoxFit.contain),
    );
  }
}

/// The current lesson's outline: the card's own edge, in the accent and
/// twice as heavy, so the lesson to continue with reads at a glance.
const double _currentBorderWidth = AppDimens.borderWidth * 2;

/// The current lesson's label pill.
const double _currentLabelGap = 6;
const EdgeInsets _currentLabelPadding = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 2,
);

/// One lesson on Course Detail's lesson list (Issue #437), on the module
/// card's own design — the same white card, outline, flat band and 56 tile,
/// with the lesson's details where the module's were:
///
///  * the tile is the lesson's module's artwork and accent, or the padlock
///    when the lesson cannot be opened ([available] false: the lesson or its
///    module is locked, or the student has not reached it yet);
///  * the caption is the lesson's number across the whole course, `01`–`N`;
///  * then its title, and its duration when the server sent one;
///  * the green check when it is completed.
///
/// [current] marks the lesson to continue with: the outline, number and title
/// in the accent, and the "Эндээс үргэлжлүүлнэ" pill under the title — the
/// level-detail reference's blue current-lesson treatment, on this card.
class CourseLessonCard extends StatelessWidget {
  const CourseLessonCard({
    required this.entry,
    super.key,
    this.current = false,
    this.available = true,
    this.onTap,
  });

  final CourseLesson entry;

  /// Whether this is the lesson to continue with.
  final bool current;

  /// Whether the lesson may be opened (`lessonOpens`). One that may not —
  /// locked by the server, or not yet reached — is drawn disabled: the
  /// padlock tile and the dimmed title, as Junior Home draws a lesson waiting
  /// its turn (Issue #439).
  final bool available;

  /// Null when the lesson may not be opened (`lessonOpens`).
  final VoidCallback? onTap;

  /// [CourseLesson.number] as the caption draws it: at least two digits.
  static String numberLabel(int number) => number.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final lesson = entry.lesson;
    final locked = entry.locked || !available;
    final palette = context.palette;
    final titleInk = locked
        ? palette.textLocked
        : current
        ? palette.primary
        : palette.textTitle;

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: _cardHeight),
          padding: const EdgeInsets.all(_tileInset),
          decoration: BoxDecoration(
            // Opaque for the reason `CourseModuleCard` gives.
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
            border: Border.all(
              color: current ? palette.primary : palette.outlineFaint,
              width: current ? _currentBorderWidth : AppDimens.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.cardDepth,
                offset: const Offset(0, _liftOffset),
              ),
            ],
          ),
          child: Row(
            children: [
              _ModuleIcon(
                iconAsset: entry.module.iconAsset,
                accentColor: entry.module.accentColor,
                locked: locked,
              ),
              const SizedBox(width: _tileToText),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      numberLabel(entry.number),
                      style: AppTypography.caption.copyWith(
                        color: current && !locked
                            ? palette.primary
                            : palette.textSupporting,
                      ),
                    ),
                    Text(
                      lesson.title,
                      style: AppTypography.itemTitle.copyWith(color: titleInk),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lesson.durationLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        lesson.durationLabel,
                        style: AppTypography.supporting.copyWith(
                          color: palette.textSupporting,
                        ),
                      ),
                    ],
                    if (current) ...[
                      const SizedBox(height: _currentLabelGap),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(
                            AppDimens.homeCardRadius,
                          ),
                        ),
                        child: Padding(
                          padding: _currentLabelPadding,
                          child: Text(
                            CourseLearningStrings.continueHere,
                            style: AppTypography.caption.copyWith(
                              color: palette.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (lesson.completed) ...[
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

class _CompletedCheck extends StatelessWidget {
  const _CompletedCheck();

  @override
  Widget build(BuildContext context) {
    // The design's own glyph, and it is the whole badge: the filled green
    // disc is part of the artwork, so there is no circle behind it here.
    return SvgPicture.asset(_checkAsset, width: _checkSize, height: _checkSize);
  }
}
