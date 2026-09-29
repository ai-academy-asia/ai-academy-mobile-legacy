import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';
import 'exercise_text_field.dart' show exerciseBorderColor;

/// `CourseQuizScreen`'s own header: a 40 x 40 close button, a progress bar
/// tracking how many of the quiz's questions have been reached, and the
/// "current/total" counter.
/// Sampled off the Quiz frames at 1:1.
const Color _progressFill = Color(0xFF2970FF);
const Color _progressTrack = Color(0xFFEAEDF0);
const Color _counterInk = Color(0xFF191919);

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
                  color: _progressFill,
                  backgroundColor: _progressTrack,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CourseLearningStrings.quizProgressCounter(current, total),
              style: AppTypography.cardHeading.copyWith(
                fontSize: 13,
                color: _counterInk,
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
    return Semantics(
      button: true,
      label: 'Close',
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: exerciseBorderColor)),
        shadowColor: Colors.black.withValues(alpha: 0.1),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.close, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
