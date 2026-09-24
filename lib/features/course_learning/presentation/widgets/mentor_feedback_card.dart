import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../course_learning_strings.dart';

/// "Mentor Feedback" / "No feedback yet" — the Assignment tab's static footer.
///
/// Only this empty state exists in this issue: the mentor actually leaving
/// feedback, and the student seeing it here, is reserved for a later
/// increment alongside the rest of the assignment progression — see
/// `CourseExerciseDetailScreen`'s own doc comment.
class MentorFeedbackCard extends StatelessWidget {
  const MentorFeedbackCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 87,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            CourseLearningStrings.mentorFeedbackTitle,
            style: AppTypography.cardHeading.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CourseLearningStrings.noFeedbackYet,
            style: AppTypography.cardSupporting,
          ),
        ],
      ),
    );
  }
}
