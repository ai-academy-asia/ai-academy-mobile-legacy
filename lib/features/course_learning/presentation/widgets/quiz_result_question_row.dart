import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// One 56pt-tall row in `CourseQuizResultScreen`'s question list: the
/// question's 1-based number, the reference's own generic "Асуулт" label
/// (not each question's own prompt — the reference shows this same label for
/// every row), and a correct/incorrect state icon.
class QuizResultQuestionRow extends StatelessWidget {
  const QuizResultQuestionRow({
    required this.number,
    required this.correct,
    super.key,
  });

  final int number;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text('$number', style: AppTypography.cardSupporting),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                CourseLearningStrings.quizResultQuestionLabel,
                style: AppTypography.settingsRowLabel,
              ),
            ),
            Icon(
              correct ? AppIcons.checkCircle : AppIcons.xCircle,
              size: 24,
              color: correct ? AppColors.success : AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}
