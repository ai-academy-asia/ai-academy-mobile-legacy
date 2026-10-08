import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';

/// The Assignment tab's footer: "Mentor Feedback" / "No feedback yet" when
/// [feedback] is null (unchanged from the tab's original, only-ever-empty
/// state), or the mentor's own comment once a submission has been reviewed.
///
/// The populated state reuses `NoteTab`'s `_ExistingNoteCard` visual
/// language (bordered card, avatar-with-initials, message, timestamp) rather
/// than inventing a new one — same tab family, same kind of "someone left a
/// message" content.
/// Solved from the reference frame's ink widths at 1:1; local because
/// `cardHeading`/`cardSupporting` are shared with other screens.
const double _headingSize = 18;

/// The feedback card's own outline and its avatar, measured at 1:1 — the
/// outline is lighter than the field outlines (`exerciseBorderColor`) and the
/// avatar is 40 across, not 36.
const Color _cardBorder = AppColors.outlineSubtle;
const double _avatarRadius = 20;

/// The feedback card's own inner rhythm, measured off `Exercise - 14` at 1:1:
/// 20 of padding on every side, 23 of clear space under the avatar before the
/// message, and 25 between the message and the timestamp. The gaps below are
/// those less the leading each text box already carries.
const double _cardPadding = 20;
const double _avatarToMessage = 18;
const double _messageToTimestamp = 18;

/// The reference leaves 16 between the section divider and the heading's
/// bounding box, which renders as 24 of clear space above its ink — the line
/// box carries 8 of leading over the cap. Both states use this; they have
/// drifted apart twice, so it lives in one place.
const double _dividerToHeading = 16;

/// One style for both states. The reference draws this heading dark in every
/// frame that shows real feedback and in three of the four empty ones, so the
/// empty state is not a lighter variant — it used to be, which is why the two
/// branches had drifted apart.
final TextStyle _heading = AppTypography.cardHeading.copyWith(
  fontSize: _headingSize,
  height: 26 / _headingSize,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);
const double _bodySize = 14;

class MentorFeedbackCard extends StatelessWidget {
  const MentorFeedbackCard({super.key, this.feedback});

  /// Null for the empty state. The Assignment tab passes the latest entry
  /// from `CourseExercise.assignmentFeedback` once one exists.
  final AssignmentMentorFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    if (feedback == null) {
      // Content-sized rather than a fixed 87: the reference's own gaps put
      // the two lines exactly where it draws them, and a fixed height cannot
      // also hold them there once their sizes are the reference's.
      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: _dividerToHeading),
            Text(CourseLearningStrings.mentorFeedbackTitle, style: _heading),
            const SizedBox(height: 9),
            Text(
              CourseLearningStrings.noFeedbackYet,
              style: AppTypography.cardSupporting.copyWith(
                fontSize: _bodySize,
                height: 20 / _bodySize,
              ),
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
        const SizedBox(height: _dividerToHeading),
        Text(CourseLearningStrings.mentorFeedbackTitle, style: _heading),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _cardBorder,
              width: AppDimens.borderWidth,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: _avatarRadius,
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
                        Text(
                          feedback.mentorName,
                          style: AppTypography.cardHeading,
                        ),
                        Text(
                          feedback.mentorRole,
                          style: AppTypography.cardSupporting,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _avatarToMessage),
              Text(
                feedback.message,
                style: AppTypography.settingsRowLabel.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: _messageToTimestamp),
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
