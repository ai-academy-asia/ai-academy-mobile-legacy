import 'package:flutter/material.dart';

import '../course_learning_strings.dart';
import 'exercise_submit_button.dart';
import 'exercise_text_field.dart';
import 'mentor_feedback_card.dart';

/// The Assignment tab's initial state: a link field, a description textarea,
/// a disabled submit, and the empty Mentor Feedback footer.
///
/// Typing is real (the fields own working `TextEditingController`s), but
/// submitting is not: upload/download progress, an uploaded-file state,
/// submit success, resubmission and the assignment state machine that would
/// connect them are reserved for a separate future issue — see
/// `CourseExerciseDetailScreen`'s own doc comment. Submit stays permanently
/// disabled here rather than toggling on non-empty input, so this state
/// matches exactly what the Figma reference shows for it — no other state
/// exists yet to toggle into.
class AssignmentTab extends StatefulWidget {
  const AssignmentTab({super.key});

  @override
  State<AssignmentTab> createState() => _AssignmentTabState();
}

class _AssignmentTabState extends State<AssignmentTab> {
  final _linkController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _linkController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExerciseTextField(
            controller: _linkController,
            placeholder: CourseLearningStrings.linkPlaceholder,
            height: 53,
          ),
          const SizedBox(height: 12),
          ExerciseTextField(
            controller: _descriptionController,
            placeholder: CourseLearningStrings.descriptionPlaceholder,
            floatingLabel: CourseLearningStrings.descriptionFloatingLabel,
            height: 104,
            multiline: true,
          ),
          const SizedBox(height: 16),
          const ExerciseSubmitButton(),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const MentorFeedbackCard(),
        ],
      ),
    );
  }
}
