import 'package:flutter/material.dart';

import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'exercise_submit_button.dart';
import 'exercise_text_field.dart';
import 'mentor_feedback_card.dart';

/// The four Assignment states this tab demonstrates, all driven by sample
/// data — see the class doc below for what each one shows.
enum _AssignmentStage {
  /// Editable fields, nothing submitted yet. The tab's original, only state.
  notSubmitted,

  /// Just submitted; fields locked while sample "review" plays out. A brief,
  /// purely cosmetic delay (see `_AssignmentTabState._submit`) — no network
  /// call, no backend.
  pendingReview,

  /// The latest canned mentor response asked for changes — fields reopen for
  /// editing, the button relabels "Resubmit".
  needsResubmission,

  /// The latest canned mentor response accepted the submission — terminal,
  /// nothing left to do.
  accepted,
}

/// The Assignment tab: a link field, a description textarea, a submit
/// button, and a Mentor Feedback footer, cycling through
/// [_AssignmentStage.notSubmitted] → `pendingReview` → `needsResubmission`
/// or `accepted` as [CourseExercise.assignmentFeedback] scripts it.
///
/// **Sample data only, entirely local state.** There is no Assignment or
/// Submission backend contract to call — `course_learning_api_
/// requirements_v1.md` lists both as requiring backend confirmation. Typing
/// is real (the fields own working `TextEditingController`s); "submitting"
/// only ever advances this widget's own [_AssignmentStage], sourced from
/// `CourseExercise.assignmentFeedback`'s canned entries. Real file upload,
/// the quiz and the certificate remain out of scope — see
/// `CourseExerciseDetailScreen`'s own doc comment.
class AssignmentTab extends StatefulWidget {
  const AssignmentTab({required this.feedbackSequence, super.key});

  /// `CourseExercise.assignmentFeedback` — the canned responses this tab
  /// walks through, one per submit/resubmit.
  final List<AssignmentMentorFeedback> feedbackSequence;

  @override
  State<AssignmentTab> createState() => _AssignmentTabState();
}

class _AssignmentTabState extends State<AssignmentTab> {
  final _linkController = TextEditingController();
  final _descriptionController = TextEditingController();

  _AssignmentStage _stage = _AssignmentStage.notSubmitted;

  /// How many times [_submit] has resolved. Indexes into
  /// [AssignmentTab.feedbackSequence]: 1 submission → entry 0, 2 → entry 1,
  /// clamped to the last entry once the sequence runs out.
  int _resolvedSubmissions = 0;

  @override
  void dispose() {
    _linkController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _fieldsEditable =>
      _stage == _AssignmentStage.notSubmitted ||
      _stage == _AssignmentStage.needsResubmission;

  AssignmentMentorFeedback? get _latestFeedback {
    final sequence = widget.feedbackSequence;
    if (sequence.isEmpty || _resolvedSubmissions == 0) return null;
    final index = (_resolvedSubmissions - 1).clamp(0, sequence.length - 1);
    return sequence[index];
  }

  String get _buttonLabel => switch (_stage) {
    _AssignmentStage.notSubmitted => CourseLearningStrings.submit,
    _AssignmentStage.pendingReview => CourseLearningStrings.submitted,
    _AssignmentStage.needsResubmission => CourseLearningStrings.resubmit,
    _AssignmentStage.accepted => CourseLearningStrings.submitted,
  };

  /// Locks the fields, waits out a short cosmetic delay (standing in for a
  /// real mentor review nothing here has a backend for), then resolves to
  /// whichever canned entry comes next.
  Future<void> _submit() async {
    setState(() => _stage = _AssignmentStage.pendingReview);

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final nextCount = _resolvedSubmissions + 1;
    final sequence = widget.feedbackSequence;
    final feedback = sequence.isEmpty
        ? null
        : sequence[(nextCount - 1).clamp(0, sequence.length - 1)];

    setState(() {
      _resolvedSubmissions = nextCount;
      _stage = (feedback != null && feedback.requiresResubmission)
          ? _AssignmentStage.needsResubmission
          : _AssignmentStage.accepted;
    });
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
            enabled: _fieldsEditable,
          ),
          const SizedBox(height: 12),
          ExerciseTextField(
            controller: _descriptionController,
            placeholder: CourseLearningStrings.descriptionPlaceholder,
            floatingLabel: CourseLearningStrings.descriptionFloatingLabel,
            height: 104,
            multiline: true,
            enabled: _fieldsEditable,
          ),
          const SizedBox(height: 16),
          ExerciseSubmitButton(
            label: _buttonLabel,
            onPressed: _fieldsEditable ? _submit : null,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          MentorFeedbackCard(feedback: _latestFeedback),
        ],
      ),
    );
  }
}
