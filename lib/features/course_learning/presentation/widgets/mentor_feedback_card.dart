import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'exercise_text_field.dart';

/// The Assignment tab's footer: "Mentor Feedback" / "No feedback yet" when
/// [feedback] is null (unchanged from the tab's original, only-ever-empty
/// state), or the mentor's own comment once a submission has been reviewed.
///
/// The populated state reuses `NoteTab`'s `_ExistingNoteCard` visual
/// language (bordered card, avatar-with-initials, message, timestamp) rather
/// than inventing a new one — same tab family, same kind of "someone left a
/// message" content.
class MentorFeedbackCard extends StatelessWidget {
  const MentorFeedbackCard({super.key, this.feedback});

  /// Null for the empty state. The Assignment tab passes the latest entry
  /// from `CourseExercise.assignmentFeedback` once one exists.
  final AssignmentMentorFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    if (feedback == null) {
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

    return _PopulatedMentorFeedback(feedback: feedback);
  }
}

class _PopulatedMentorFeedback extends StatelessWidget {
  const _PopulatedMentorFeedback({required this.feedback});

  final AssignmentMentorFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          CourseLearningStrings.mentorFeedbackTitle,
          style: AppTypography.cardHeading.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: exerciseBorderColor,
              width: AppDimens.borderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.blue,
                    child: Text(
                      feedback.mentorInitials,
                      style: AppTypography.buttonLabel.copyWith(
                        color: AppColors.onPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(feedback.mentorName, style: AppTypography.cardHeading),
                        Text(
                          feedback.mentorRole,
                          style: AppTypography.cardSupporting,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                feedback.message,
                style: AppTypography.settingsRowLabel.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                feedback.timestampLabel,
                style: AppTypography.cardSupporting,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
