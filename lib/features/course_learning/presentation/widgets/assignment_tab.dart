import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../../domain/file_size_label.dart';
import '../../domain/uploaded_file.dart';
import '../course_learning_strings.dart';
import 'assignment_attachment_card.dart';
import 'exercise_submit_button.dart';
import 'exercise_text_field.dart';
import 'mentor_feedback_card.dart';

/// The success card's green tile, measured off the reference at 1:1. The
/// fill is a flat sampled colour, not [AppColors.success] at an alpha —
/// solving for one gives a different figure per channel, so the frame's own
/// value is used.
const double _successTileWidth = 44;
const double _successTileHeight = 30;
const Color _successTileFill = AppColors.successFillStrong;

/// The pair of ticks spans the tile almost edge to edge in the reference, in
/// a deeper green than [AppColors.success].
const double _successCheckSize = 32;
const Color _successCheckInk = AppColors.successInk;

/// Negative, so the pair reaches the tile's edges: two centred glyphs pull
/// their ink *inward* as they grow, so a bigger size alone narrows the pair.
const double _successCheckInset = -4;

/// The outlined Resubmit pill, measured at 1:1.
const String _resubmitIconAsset =
    'assets/images/course_learning/exercise_resubmit.svg';
const double _resubmitIconBox = 24;
const double _resubmitLabelSize = 16;
const Color _resubmitBorder = AppColors.outline;

/// The submitted card's own rhythm, measured off the reference at 1:1:
/// divider -> tile 31, tile -> message 41, message -> button 34. The gaps
/// below are those less the leading each box already carries.
const double _successTopGap = 8;
const double _tileToMessage = 28;
const double _messageToResubmit = 32;

/// Between the description field and a failed submit's error line — the
/// same 8 `NoteTab` leaves.
const double _fieldToError = 8;

/// Which of the reference's two editable forms a backend assignment draws.
/// The frames show one or the other, never both.
enum AssignmentForm {
  /// A link field and a description — the frame with the link row.
  link,

  /// The file area and a description — the frames with the drop area.
  file,
}

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
/// canned entries. The certificate remains out of scope — see
/// `CourseExerciseDetailScreen`'s own doc comment.
///
/// **Disabled when [enabled] is false** — a backend lesson with no
/// assignment to submit to. The same fields and button are drawn, all of
/// them off, so nothing can look submitted.
///
/// **[submission] is the server's.** When a backend lesson's student has
/// already submitted, the tab opens on the success card — the state §2.6
/// maps any submission onto — with that submission's own [AssignmentSubmission
/// .feedback] in the Mentor Feedback card ("No feedback yet" until it is
/// reviewed). Resubmit is drawn but off while the tab is disabled.
///
/// **[onSubmit] makes the submit real** — a backend assignment. The same
/// three stages, but: Submit needs only the link, since §2.6 makes the
/// description optional; "pending review" lasts exactly as long as the
/// request; success shows the success card, whose feedback is then the new
/// [submission]'s; failure reopens the form with what was typed and
/// [errorMessage] under it, in the Login screen's own `fieldError`
/// treatment (the Figma pack has no error state here). Resubmit reopens the
/// form filled with the latest submission's link and description.
///
/// **[form] picks which real form is drawn**, as the reference does: the
/// link field *or* the file area, never both. In [AssignmentForm.file] the
/// area takes the link field's place, Submit needs an uploaded file, and no
/// link is sent. The file itself — picked, uploading, uploaded — is the
/// caller's state, drawn by `AssignmentFileUploadCard`; a failed pick or
/// upload shows [fileErrorMessage] under the area. A resubmission starts
/// with no file: the latest submission's is not read. Which form a given
/// assignment takes is the caller's to say — see
/// `CourseExerciseDetailScreen`.
class AssignmentTab extends StatefulWidget {
  const AssignmentTab({
    required this.feedbackSequence,
    this.attachment,
    this.submission,
    this.enabled = true,
    this.onSubmit,
    this.submitting = false,
    this.errorMessage,
    this.form = AssignmentForm.link,
    this.onPickFile,
    this.onCancelFileUpload,
    this.onRemoveFile,
    this.fileUploadSizeBytes,
    this.uploadedFile,
    this.fileErrorMessage,
    super.key,
  });

  /// False draws the tab with every control off. See the class doc.
  final bool enabled;

  /// `CourseExercise.assignmentFeedback` — the canned responses this tab
  /// walks through, one per submit/resubmit.
  final List<AssignmentMentorFeedback> feedbackSequence;

  /// `CourseExercise.assignmentAttachment` — a reference file the student
  /// must (simulate-)download before Submit is ready. Null skips that
  /// requirement entirely, same as an exercise with no attachment at all.
  final CourseExerciseMaterial? attachment;

  /// `CourseExercise.assignment?.submission` — the latest submission the
  /// backend holds. Null for the sample, and for a backend lesson with
  /// nothing submitted yet.
  final AssignmentSubmission? submission;

  /// Sends the trimmed link and description and answers whether the
  /// submission was accepted. Null keeps the sample's local simulation.
  final Future<bool> Function(String link, String description)? onSubmit;

  /// True while a submit is in flight — read when the tab is rebuilt
  /// mid-request (a tab switch), so it resumes in "pending review".
  final bool submitting;

  /// Why the last submit failed, or null.
  final String? errorMessage;

  /// Which form a real submit ([onSubmit]) draws. Ignored by the sample,
  /// which goes by [attachment].
  final AssignmentForm form;

  /// Opens the file picker and uploads what the student chooses — the
  /// [AssignmentForm.file] form's drop area. Null leaves the area inert.
  final VoidCallback? onPickFile;

  /// Abandons the upload in flight.
  final VoidCallback? onCancelFileUpload;

  /// Drops [uploadedFile].
  final VoidCallback? onRemoveFile;

  /// The size of the file being uploaded — non-null exactly while an upload
  /// is in flight.
  final int? fileUploadSizeBytes;

  /// The uploaded file the next submit will attach, or null.
  final UploadedFile? uploadedFile;

  /// Why the last pick or upload failed, or null.
  final String? fileErrorMessage;

  @override
  State<AssignmentTab> createState() => _AssignmentTabState();
}

class _AssignmentTabState extends State<AssignmentTab> {
  final _linkController = TextEditingController();
  final _descriptionController = TextEditingController();

  late _AssignmentStage _stage = widget.onSubmit != null && widget.submitting
      ? _AssignmentStage.pendingReview
      : widget.submission == null
      ? _AssignmentStage.notSubmitted
      : _AssignmentStage.submitted;

  /// True once a real submit from this tab has failed, until the next one —
  /// the same guard `NoteTab` uses so an error shows under its own attempt.
  bool _submitFailed = false;

  /// How many times [_submit] has resolved. Indexes into
  /// [AssignmentTab.feedbackSequence]: 1 submission → entry 0, 2 → entry 1,
  /// clamped to the last entry once the sequence runs out.
  int _resolvedSubmissions = 0;

  /// True once the fields Submit needs hold non-blank text — see
  /// [_onTextChanged].
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
  void didUpdateWidget(AssignmentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a tab rebuilt mid-request can still be pending when the request
    // ends: [_submit] settles its own attempt. Resolve it from the result.
    if (widget.onSubmit != null &&
        oldWidget.submitting &&
        !widget.submitting &&
        _stage == _AssignmentStage.pendingReview) {
      final accepted =
          widget.submission != null &&
          !identical(widget.submission, oldWidget.submission);
      _stage = accepted
          ? _AssignmentStage.submitted
          : _AssignmentStage.notSubmitted;
      _submitFailed = !accepted;
    }
  }

  @override
  void dispose() {
    _linkController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _linkController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// A real link submit needs only the link — §2.6's one required field
  /// when there is no file. The sample's simulation keeps its own rule: the
  /// description always counts; the link only when it is on screen — the
  /// file area replaces it, and a field the student cannot see must not be
  /// what holds Submit disabled.
  void _onTextChanged() {
    final hasLink = _linkController.text.trim().isNotEmpty;
    final hasContent = widget.onSubmit != null
        ? hasLink
        : _descriptionController.text.trim().isNotEmpty &&
              (widget.attachment != null || hasLink);
    if (hasContent != _hasContent) setState(() => _hasContent = hasContent);
  }

  /// True when a real submit draws the file form.
  bool get _fileForm =>
      widget.onSubmit != null && widget.form == AssignmentForm.file;

  bool get _readyToSubmit =>
      widget.enabled &&
      _stage == _AssignmentStage.notSubmitted &&
      // The file form has no link to type: its content is the uploaded
      // file — and one still uploading is not there to send yet.
      (_fileForm
          ? widget.uploadedFile != null && widget.fileUploadSizeBytes == null
          : _hasContent) &&
      _attachmentReady;

  AssignmentMentorFeedback? get _latestFeedback {
    // A server submission's feedback is the only one there is — never the
    // sample sequence.
    if (widget.submission case final submission?) return submission.feedback;
    final sequence = widget.feedbackSequence;
    if (sequence.isEmpty || _resolvedSubmissions == 0) return null;
    final index = (_resolvedSubmissions - 1).clamp(0, sequence.length - 1);
    return sequence[index];
  }

  /// Locks the fields, waits out a short cosmetic delay (standing in for a
  /// real mentor review nothing here has a backend for), then shows the
  /// success card.
  Future<void> _submit() async {
    final onSubmit = widget.onSubmit;
    if (onSubmit != null) return _submitToServer(onSubmit);

    setState(() => _stage = _AssignmentStage.pendingReview);

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _resolvedSubmissions += 1;
      _stage = _AssignmentStage.submitted;
    });
  }

  /// "Pending review" for exactly as long as the request, then the success
  /// card — or the form again, with what was typed, if it failed.
  Future<void> _submitToServer(
    Future<bool> Function(String link, String description) onSubmit,
  ) async {
    setState(() {
      _stage = _AssignmentStage.pendingReview;
      _submitFailed = false;
    });

    final accepted = await onSubmit(
      // The file form shows no link field, so it sends no link — not even
      // one a resubmission pre-filled out of sight.
      _fileForm ? '' : _linkController.text.trim(),
      _descriptionController.text.trim(),
    );
    if (!mounted) return;

    setState(() {
      _stage = accepted
          ? _AssignmentStage.submitted
          : _AssignmentStage.notSubmitted;
      _submitFailed = !accepted;
    });
  }

  void _resubmit() {
    // A real resubmission starts from what the server holds — the same
    // link and description, to change and send again.
    if (widget.onSubmit != null) {
      if (widget.submission case final submission?) {
        _linkController.text = submission.link ?? '';
        _descriptionController.text = submission.description ?? '';
      }
    }
    setState(() {
      _stage = _AssignmentStage.notSubmitted;
      _submitFailed = false;
    });
  }

  /// The real file area and its error line. The controls are handed over
  /// only while the form is open, so a submit in flight locks them with it.
  List<Widget> _fileArea() {
    final open = widget.enabled && _stage == _AssignmentStage.notSubmitted;
    final uploadSizeBytes = widget.fileUploadSizeBytes;
    final uploadedFile = widget.uploadedFile;
    return [
      AssignmentFileUploadCard(
        uploadSizeLabel: uploadSizeBytes == null
            ? null
            : fileSizeLabel(uploadSizeBytes),
        uploadedFileLabel: uploadedFile == null
            ? null
            : CourseLearningStrings.uploadedFileLabel(
                fileSizeLabel(uploadedFile.sizeBytes),
                uploadedFile.fileName,
              ),
        onPick: open ? widget.onPickFile : null,
        onCancel: open ? widget.onCancelFileUpload : null,
        onRemove: open ? widget.onRemoveFile : null,
      ),
      if (widget.fileErrorMessage case final message?) ...[
        const SizedBox(height: _fieldToError),
        SizedBox(
          width: double.infinity,
          child: Text(message, style: AppTypography.fieldError),
        ),
      ],
      const SizedBox(height: 18),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_stage == _AssignmentStage.submitted)
            _AssignmentSuccessCard(
              onResubmit: widget.enabled ? _resubmit : null,
            )
          else ...[
            // The reference draws the file area and the link field as
            // alternatives, never together: the frames with a drop area have
            // no link row, and the frame with the link row has no file area.
            if (widget.attachment case final attachment?) ...[
              AssignmentAttachmentCard(
                attachment: attachment,
                onDownloaded: () => setState(() => _attachmentReady = true),
                onRemoved: () => setState(() => _attachmentReady = false),
              ),
              const SizedBox(height: 18),
            ] else if (_fileForm)
              ..._fileArea()
            else ...[
              ExerciseTextField(
                controller: _linkController,
                placeholder: CourseLearningStrings.linkPlaceholder,
                height: 53,
                enabled:
                    widget.enabled && _stage == _AssignmentStage.notSubmitted,
              ),
              const SizedBox(height: 18),
            ],
            ExerciseTextField(
              controller: _descriptionController,
              placeholder: CourseLearningStrings.descriptionPlaceholder,
              floatingLabel: CourseLearningStrings.descriptionFloatingLabel,
              height: 104,
              multiline: true,
              enabled:
                  widget.enabled && _stage == _AssignmentStage.notSubmitted,
            ),
            if (_submitFailed && widget.errorMessage != null) ...[
              const SizedBox(height: _fieldToError),
              SizedBox(
                width: double.infinity,
                child: Text(
                  widget.errorMessage!,
                  style: AppTypography.fieldError,
                ),
              ),
            ],
            const SizedBox(height: 32),
            ExerciseSubmitButton(
              label: _stage == _AssignmentStage.pendingReview
                  ? CourseLearningStrings.submitted
                  : CourseLearningStrings.submit,
              onPressed: _readyToSubmit ? _submit : null,
            ),
          ],
          const SizedBox(height: 24),
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

  /// Null draws the pill unchanged but inert.
  final VoidCallback? onResubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The submitted state sits lower under the tabs than the editable
        // one does: the reference leaves 31 between the tab divider and the
        // tile, where the fields start after 17.
        const SizedBox(height: _successTopGap),
        // The reference sets the double check on a soft green tile rather
        // than on the card surface — 44 x 30, measured at 1:1.
        Container(
          width: _successTileWidth,
          height: _successTileHeight,
          decoration: BoxDecoration(
            color: _successTileFill,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: _successCheckInset,
                child: Icon(
                  AppIcons.check,
                  size: _successCheckSize,
                  color: _successCheckInk,
                ),
              ),
              Positioned(
                right: _successCheckInset,
                child: Icon(
                  AppIcons.check,
                  size: _successCheckSize,
                  color: _successCheckInk,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: _tileToMessage),
        Text(
          CourseLearningStrings.assignmentSubmittedSuccess,
          style: AppTypography.cardSupporting.copyWith(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: _messageToResubmit),
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

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
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
                color: _resubmitBorder,
                width: AppDimens.borderWidth,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The design's own retry glyph. Drawn at the asset's natural
                // 24 square: it is stroked (not filled), so the artwork runs
                // half a stroke past its path coordinates and lands on the
                // reference's ~19 x 18 without being scaled to it. The asset
                // carries its own ink (black at 90%, the same as
                // [AppColors.textPrimary]), so it is not tinted.
                SvgPicture.asset(
                  _resubmitIconAsset,
                  width: _resubmitIconBox,
                  height: _resubmitIconBox,
                ),
                const SizedBox(width: 8),
                Text(
                  CourseLearningStrings.resubmit,
                  style: AppTypography.buttonLabel.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: _resubmitLabelSize,
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
