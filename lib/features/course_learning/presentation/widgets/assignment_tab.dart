import 'package:flutter/material.dart';

import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'assignment_attachment_card.dart';
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

/// The Assignment tab: an optional attached reference file, a link field, a
/// description textarea, a submit button, and a Mentor Feedback footer,
/// cycling through [_AssignmentStage.notSubmitted] → `pendingReview` →
/// `needsResubmission` or `accepted` as [CourseExercise.assignmentFeedback]
/// scripts it.
///
/// **Submit is enabled once the "required sample content" is ready**: both
/// fields hold non-blank text, and — when [attachment] is not null — the
/// attachment has finished (simulated-)downloading. There is no confirmed
/// backend rule for what "ready" means for a real assignment, so this is a
/// frontend-only judgement call, the same kind `CourseModuleListScreen`'s own
/// `_continueLearningTarget` documents itself as being.
///
/// **Sample data only, entirely local state.** There is no Assignment or
/// Submission backend contract to call — `course_learning_api_
/// requirements_v1.md` lists both as requiring backend confirmation. Typing
/// is real (the fields own working `TextEditingController`s); "submitting"
/// only ever advances this widget's own [_AssignmentStage], sourced from
/// `CourseExercise.assignmentFeedback`'s canned entries. A real file
/// *upload* and the certificate remain out of scope — see
/// `CourseExerciseDetailScreen`'s own doc comment.
class AssignmentTab extends StatefulWidget {
  const AssignmentTab({
    required this.feedbackSequence,
    this.attachment,
    super.key,
  });

  /// `CourseExercise.assignmentFeedback` — the canned responses this tab
  /// walks through, one per submit/resubmit.
  final List<AssignmentMentorFeedback> feedbackSequence;

  /// `CourseExercise.assignmentAttachment` — a reference file the student
  /// must (simulate-)download before Submit is ready. Null skips that
  /// requirement entirely, same as an exercise with no attachment at all.
  final CourseExerciseMaterial? attachment;

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

  /// True once both fields hold non-blank text.
  bool _hasContent = false;

  /// True once [AssignmentTab.attachment] has finished downloading, or there
  /// was none to begin with.
  late bool _attachmentReady = widget.attachment == null;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _linkController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _linkController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasContent =
        _linkController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty;
    if (hasContent != _hasContent) setState(() => _hasContent = hasContent);
  }

  bool get _fieldsEditable =>
      _stage == _AssignmentStage.notSubmitted ||
      _stage == _AssignmentStage.needsResubmission;

  bool get _readyToSubmit => _fieldsEditable && _hasContent && _attachmentReady;

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
    final attachment = widget.attachment;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (attachment != null) ...[
            AssignmentAttachmentCard(
              attachment: attachment,
              onDownloaded: () => setState(() => _attachmentReady = true),
            ),
            const SizedBox(height: 12),
          ],
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
            onPressed: _readyToSubmit ? _submit : null,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          MentorFeedbackCard(feedback: _latestFeedback),
        ],
      ),
    );
  }
}
