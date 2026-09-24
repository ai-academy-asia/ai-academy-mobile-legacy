import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/lesson.dart';
import '../course_learning_strings.dart';

/// Figma has no dedicated Lesson List screenshot yet — this row deliberately
/// reuses `CourseModuleCard`'s own measurements and treatment (56pt icon
/// slot, [AppDimens.homeCardRadius], the same border/shadow pair) rather than
/// inventing a new visual language for a screen that has none confirmed, so
/// the two lists read as the same product.
const double _iconSlot = 56;
const double _lockedIconSize = 32;
const double _checkSize = 24;

/// One lesson row on the Lesson List screen.
///
/// Same two states as `CourseModuleCard`: open (a play glyph, tinted with
/// [AppColors.blue] since a lesson has no [Lesson.moduleId]-specific accent
/// colour of its own the way `CourseModule.accentColor` does) or locked (the
/// identical plain lock tile `CourseModuleCard` draws).
class LessonListItem extends StatelessWidget {
  const LessonListItem({required this.lesson, super.key, this.onTap});

  final Lesson lesson;

  /// Null when [Lesson.locked] — a locked lesson has nothing to open.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = lesson.locked;
    final titleColor = locked ? AppColors.textSecondary : AppColors.textPrimary;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
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
              _LessonIcon(lesson: lesson),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${CourseLearningStrings.lessonCaption} ${lesson.order}',
                      style: AppTypography.catalogSectionLabel,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson.title,
                      style: AppTypography.cardHeading.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.durationLabel,
                      style: AppTypography.cardSupporting,
                    ),
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

class _LessonIcon extends StatelessWidget {
  const _LessonIcon({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    if (lesson.locked) {
      return SizedBox(
        width: _iconSlot,
        height: _iconSlot,
        child: Center(
          child: Container(
            width: _lockedIconSize,
            height: _lockedIconSize,
            decoration: BoxDecoration(
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

    // `Icons.play_arrow_rounded`, not a bundled Phosphor glyph: same
    // reasoning `ExerciseInfoSection`'s own read-more chevrons document —
    // there is no confirmed Phosphor "play" codepoint to reuse, and this
    // tile only needs to read as "opens a video", not match one exactly.
    return Container(
      width: _iconSlot,
      height: _iconSlot,
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.fieldRadius),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: AppColors.blue,
        size: 28,
      ),
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
