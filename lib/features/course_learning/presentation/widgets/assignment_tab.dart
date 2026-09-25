import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'assignment_attachment_card.dart';
import 'exercise_submit_button.dart';
import 'exercise_text_field.dart';
import 'mentor_feedback_card.dart';

/// The three states this tab cycles through, all driven by sample data — see
/// the class doc below for what each one shows.
enum _AssignmentStage {
  /// Editable fields, nothing submitted yet — or the student tapped
  /// "Resubmit" on the success card to submit again.
  notSubmitted,

  /// Just submitted; fields locked while sample "review" plays out. A brief,
  /// purely cosmetic delay (see `_AssignmentTabState._submit`) — no network
  /// call, no backend.
  pendingReview,

  /// "Assignment submitted successfully" — the reference shows this same
  /// card regardless of what the mentor's own feedback says (see
  /// `AssignmentMentorFeedback`, rendered separately below by
  /// `MentorFeedbackCard`); "Resubmit" here always reopens the fields for
  /// another attempt, it is not conditional on the feedback asking for one.
  submitted,
}

/// The Assignment tab: an optional attached reference file, a link field, a
/// description textarea and a submit button while editable, or — once
/// submitted — a success card with a "Resubmit" action, followed in both
/// cases by a Mentor Feedback footer.
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
/// only ever advances this widget's own [_AssignmentStage], and the Mentor
/// Feedback card below is sourced from `CourseExercise.assignmentFeedback`'s
/// canned entries. A real file *upload* and the certificate remain out of
/// scope — see `CourseExerciseDetailScreen`'s own doc comment.
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

  bool get _readyToSubmit =>
      _stage == _AssignmentStage.notSubmitted && _hasContent && _attachmentReady;

  AssignmentMentorFeedback? get _latestFeedback {
    final sequence = widget.feedbackSequence;
    if (sequence.isEmpty || _resolvedSubmissions == 0) return null;
    final index = (_resolvedSubmissions - 1).clamp(0, sequence.length - 1);
    return sequence[index];
  }

  /// Locks the fields, waits out a short cosmetic delay (standing in for a
  /// real mentor review nothing here has a backend for), then shows the
  /// success card.
  Future<void> _submit() async {
    setState(() => _stage = _AssignmentStage.pendingReview);

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _resolvedSubmissions += 1;
      _stage = _AssignmentStage.submitted;
    });
  }

  void _resubmit() => setState(() => _stage = _AssignmentStage.notSubmitted);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_stage == _AssignmentStage.submitted)
            _AssignmentSuccessCard(onResubmit: _resubmit)
          else ...[
            if (widget.attachment case final attachment?) ...[
              AssignmentAttachmentCard(
                attachment: attachment,
                onDownloaded: () => setState(() => _attachmentReady = true),
                onRemoved: () => setState(() => _attachmentReady = false),
              ),
              const SizedBox(height: 12),
            ],
            ExerciseTextField(
              controller: _linkController,
              placeholder: CourseLearningStrings.linkPlaceholder,
              height: 53,
              enabled: _stage == _AssignmentStage.notSubmitted,
            ),
            const SizedBox(height: 12),
            ExerciseTextField(
              controller: _descriptionController,
              placeholder: CourseLearningStrings.descriptionPlaceholder,
              floatingLabel: CourseLearningStrings.descriptionFloatingLabel,
              height: 104,
              multiline: true,
              enabled: _stage == _AssignmentStage.notSubmitted,
            ),
            const SizedBox(height: 16),
            ExerciseSubmitButton(
              label: _stage == _AssignmentStage.pendingReview
                  ? CourseLearningStrings.submitted
                  : CourseLearningStrings.submit,
              onPressed: _readyToSubmit ? _submit : null,
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          MentorFeedbackCard(feedback: _latestFeedback),
        ],
      ),
    );
  }
}

/// "Assignment submitted successfully" — a double-check icon, the message,
/// and an outlined (not primary-blue) "Resubmit" pill that always reopens
/// the fields, regardless of what the mentor's own feedback says.
class _AssignmentSuccessCard extends StatelessWidget {
  const _AssignmentSuccessCard({required this.onResubmit});

  final VoidCallback onResubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 2,
                child: Icon(AppIcons.check, size: 26, color: AppColors.success),
              ),
              Positioned(
                right: 2,
                child: Icon(AppIcons.check, size: 26, color: AppColors.success),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          CourseLearningStrings.assignmentSubmittedSuccess,
          style: AppTypography.cardSupporting,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _ResubmitButton(onTap: onResubmit),
      ],
    );
  }
}

/// The outlined "Resubmit" pill — same 329 x 44 footprint as
/// `ExerciseSubmitButton`, but white/bordered rather than filled blue, which
/// is why this is its own widget rather than a new variant of that one.
class _ResubmitButton extends StatelessWidget {
  const _ResubmitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: CourseLearningStrings.resubmit,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 329,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.border,
                width: AppDimens.borderWidth,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh, size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  CourseLearningStrings.resubmit,
                  style: AppTypography.buttonLabel.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
