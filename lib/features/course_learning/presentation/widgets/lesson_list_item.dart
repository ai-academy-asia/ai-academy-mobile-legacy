import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/lesson.dart';

/// Measured off the Figma level-detail reference at 1:1 (Issue #215): a
/// 361-wide card, 72 tall with its 1pt outline, radius 12, the number 16 in
/// from the outline and the title at 61 — the number's own slot is 28 wide.
const double _minHeight = 72;
const double _radius = 12;
const double _inset = 16;
const double _numberSlot = 28;
const double _checkSize = 20;

/// The lesson title's type, calibrated against the reference (Issue #217):
/// its four lesson titles' ink widths match Manrope 14 ExtraBold to within
/// 0.7pt, where 16 Bold runs 11–20pt wide. The line box is
/// `CourseModuleCard`'s 14pt title's 20. The module title above (18) stays
/// the larger heading.
const double _titleSize = 14;
const double _titleLineHeight = 20;
const FontWeight _titleWeight = FontWeight.w800;

/// The reference's card outline and the flat band under it, the same
/// `#EAEDF0` and 4pt `CourseModuleCard` measures off the Course Detail
/// reference. Kept as this file's own copy rather than extracted: those
/// constants are private to Course Detail's card, and this change leaves
/// that screen untouched.
const Color _border = AppColors.divider;
const double _liftOffset = 4;

/// Sampled off the reference: the number's grey and the title's ink. The
/// duration and the locked ink are `CourseModuleCard`'s own, since the
/// reference draws neither on a lesson card.
const Color _numberInk = AppColors.textMuted;
const Color _titleInk = AppColors.textStrong;
const Color _secondaryInk = AppColors.textSupporting;
const Color _lockedInk = AppColors.textLocked;

/// Course Detail's own completed badge and padlock — the same assets
/// `CourseModuleCard` draws, at their native sizes.
const String _checkAsset =
    'assets/images/course_learning/course_detail_completed_check.svg';
const String _lockAsset =
    'assets/images/course_learning/course_detail_lock.svg';
const double _lockWidth = 24;
const double _lockHeight = 27;

/// One lesson card on the Lesson List screen, drawn to the Figma
/// level-detail reference: the two-digit lesson number, the bold title and
/// the green completed check on a white, outlined card with a flat band
/// under it.
///
/// The reference's card carries no duration and no locked state; this one
/// keeps both, because they are real lesson data: the duration as a
/// secondary line under the title, and a locked lesson in
/// `CourseModuleCard`'s dimmed ink with Course Detail's padlock where the
/// check would be. The reference's blue "current lesson" treatment is not
/// drawn — §2.2 sends no current-lesson marker (Issue #215).
class LessonListItem extends StatelessWidget {
  const LessonListItem({required this.lesson, super.key, this.onTap});

  /// The trailing status column — the padlock's width, the wider of the two
  /// badges — reserved on every card, with or without a badge, so a title
  /// wraps inside its own area and never reaches the check or padlock. The
  /// badge sits at its right edge, which puts the check where the reference
  /// draws it: 16 in from the card's outline.
  static const double statusColumnWidth = _lockWidth;

  /// The space between the title area and [statusColumnWidth]'s column —
  /// the card's own 16 inset.
  static const double titleToStatusGap = _inset;

  final Lesson lesson;

  /// Null when [Lesson.locked] — a locked lesson has nothing to open.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = lesson.locked;
    final lineStyle = TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: 16,
      height: 22 / 16,
      leadingDistribution: TextLeadingDistribution.even,
      color: locked ? _lockedInk : _titleInk,
    );

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: _minHeight),
          padding: const EdgeInsets.symmetric(horizontal: _inset, vertical: 12),
          decoration: BoxDecoration(
            // Repeated here, as on `CourseModuleCard`: the band is a
            // zero-blur shadow of the whole card, so the card needs its own
            // opaque fill on top of it.
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(color: _border, offset: Offset(0, _liftOffset)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  // The number and the title sit on one baseline, as the
                  // reference draws them, though their sizes differ; the
                  // duration sits under the title only.
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: _numberSlot),
                      child: Text(
                        lesson.order.toString().padLeft(2, '0'),
                        style: lineStyle.copyWith(
                          fontWeight: FontWeight.w400,
                          color: locked ? _lockedInk : _numberInk,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lesson.title,
                            style: lineStyle.copyWith(
                              fontSize: _titleSize,
                              height: _titleLineHeight / _titleSize,
                              fontWeight: _titleWeight,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lesson.durationLabel,
                            style: AppTypography.cardSupporting.copyWith(
                              fontSize: 12,
                              height: 16 / 12,
                              color: _secondaryInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: titleToStatusGap),
              SizedBox(
                width: statusColumnWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: lesson.completed
                      ? SvgPicture.asset(
                          _checkAsset,
                          width: _checkSize,
                          height: _checkSize,
                        )
                      : locked
                      ? SvgPicture.asset(
                          _lockAsset,
                          width: _lockWidth,
                          height: _lockHeight,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
