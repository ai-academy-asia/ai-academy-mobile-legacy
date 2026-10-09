import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';

/// Sizes below are solved from the reference frame's own ink widths at 1:1
/// (a 393pt frame exported at 3x), not estimated: each string's rendered
/// advance was matched against the width the frame draws it at. They are
/// screen-local because the shared tokens they override — `cardHeading`,
/// `cardSupporting`, `catalogSectionLabel` — are sampled from other frames
/// and used by other screens.
const double _captionSize = 12;
const double _titleSize = 18;
const double _bodySize = 14;
const double _readMoreSize = 14;

/// Coloured at use (`textSecondary`), so the theme decides the ink.
const TextStyle _bodyStyle = TextStyle(
  fontFamily: AppTypography.fontFamily,
  fontSize: _bodySize,
  height: 20 / _bodySize,
  fontWeight: FontWeight.w400,
);

/// Modules caption, title, the collapsible description, and — once expanded —
/// whatever [CourseExercise.extraSections] the exercise has.
///
/// Content height is intentionally unconstrained: the reference's own
/// "approximately 393 x 584" expanded measurement is a description of how
/// tall the content happens to be, not a box to fit it into — a fixed height
/// would either clip a longer exercise's text or leave a shorter one
/// floating in empty space.
class ExerciseInfoSection extends StatelessWidget {
  const ExerciseInfoSection({
    required this.exercise,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final CourseExercise exercise;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bodyStyle = _bodyStyle.copyWith(color: palette.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.moduleCaption,
          style: AppTypography.catalogSectionLabel.copyWith(
            fontSize: _captionSize,
            height: 16 / _captionSize,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          exercise.title,
          style: AppTypography.heading.copyWith(
            fontSize: _titleSize,
            height: 26 / _titleSize,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          exercise.summary,
          style: bodyStyle,
          maxLines: expanded ? null : 3,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (expanded)
          for (final section in exercise.extraSections) ...[
            const SizedBox(height: 16),
            Text(
              section.title,
              style: AppTypography.cardHeading.copyWith(
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(section.body, style: bodyStyle),
            for (final bullet in section.bullets) ...[
              const SizedBox(height: 12),
              Text('•  $bullet', style: bodyStyle),
            ],
          ],
        _ReadMoreRow(expanded: expanded, onTap: onToggle),
      ],
    );
  }
}

class _ReadMoreRow extends StatelessWidget {
  const _ReadMoreRow({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = expanded
        ? CourseLearningStrings.readLess
        : CourseLearningStrings.readMore;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.cardHeading.copyWith(
                  fontSize: _readMoreSize,
                  decoration: TextDecoration.underline,
                  color: context.palette.textPrimary,
                ),
              ),
              Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20,
                color: context.palette.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
