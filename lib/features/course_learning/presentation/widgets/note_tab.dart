import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'exercise_submit_button.dart';
import 'exercise_text_field.dart';

/// The Note tab: an editable textarea when the student has not left a note
/// yet ([CourseExerciseNote] is null), or the existing note — with the
/// mentor's reply already alongside it — once they have.
///
/// Which of the two shows is driven entirely by the sample data
/// (`CourseExercise.note`), the same way `CourseModule.completed`/`.locked`
/// pick a module's state: there is no in-app action here that moves a note
/// from one state to the other yet (leaving a note for real, and the mentor
/// replying, are the same future "progression" work this screen otherwise
/// defers — see `CourseExerciseDetailScreen`'s own doc comment).
class NoteTab extends StatefulWidget {
  const NoteTab({required this.note, super.key});

  final CourseExerciseNote? note;

  @override
  State<NoteTab> createState() => _NoteTabState();
}

class _NoteTabState extends State<NoteTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: note == null
          ? Column(
              children: [
                ExerciseTextField(
                  controller: _controller,
                  placeholder: CourseLearningStrings.descriptionPlaceholder,
                  floatingLabel: CourseLearningStrings.descriptionFloatingLabel,
                  height: 118,
                  multiline: true,
                ),
                const SizedBox(height: 16),
                const ExerciseSubmitButton(),
              ],
            )
          : _ExistingNoteCard(note: note),
    );
  }
}

class _ExistingNoteCard extends StatelessWidget {
  const _ExistingNoteCard({required this.note});

  final CourseExerciseNote note;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  note.authorInitials,
                  style: AppTypography.buttonLabel.copyWith(
                    color: AppColors.onPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(note.authorName, style: AppTypography.cardHeading),
                  Text(note.authorLabel, style: AppTypography.cardSupporting),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note.message,
            style: AppTypography.settingsRowLabel.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(note.timestampLabel, style: AppTypography.cardSupporting),
          const SizedBox(height: 16),
          const ExerciseSubmitButton(label: CourseLearningStrings.editNote),
        ],
      ),
    );
  }
}
