import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// `CourseQuizScreen`'s own header: a 40 x 40 close button, a progress bar
/// tracking how many of the quiz's questions have been reached, and the
/// "current/total" counter.
// Sampled off the Quiz frames at 1:1: an `AppPalette.accent` bar on the
// light `divider` track, the counter in `textTitle`.

class QuizProgressHeader extends StatelessWidget {
  const QuizProgressHeader({
    required this.current,
    required this.total,
    required this.onClose,
    super.key,
  });

  /// 1-based — the question currently showing.
  final int current;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _CloseButton(onTap: onClose),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : current / total,
                  minHeight: 8,
                  color: context.palette.accent,
                  backgroundColor: context.palette.divider,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CourseLearningStrings.quizProgressCounter(current, total),
              style: AppTypography.cardHeading.copyWith(
                fontSize: 13,
                color: context.palette.textTitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // `CourseLearningBackButton`'s page control: a `surface` disc in an
    // `outline` ring, its glyph `textPrimary`.
    return Semantics(
      button: true,
      label: 'Close',
      child: Material(
        color: palette.surface,
        shape: CircleBorder(side: BorderSide(color: palette.outline)),
        // Black @ 10 %, exactly as before: `shadowSubtle`'s hue at this
        // control's own strength, as `CourseLearningBackButton` does.
        shadowColor: palette.shadowSubtle.withValues(alpha: 0.1),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.close, size: 20, color: palette.textPrimary),
          ),
        ),
      ),
    );
  }
}
