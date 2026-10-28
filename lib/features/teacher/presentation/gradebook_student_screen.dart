import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/content_column.dart';
import '../../../shared/widgets/keyboard_reveal.dart';
import '../../../shared/widgets/pill_button.dart';
import '../domain/teacher_failure.dart';
import '../domain/teacher_gradebook_repository.dart';
import '../domain/teacher_submission.dart';
import 'gradebook_class_controller.dart';
import 'gradebook_class_screen.dart' show ProgramNotice;
import 'manual_attendance_screen.dart' show StudentInitialsAvatar;
import 'teacher_gradebook_strings.dart';
import 'widgets/gradebook_widgets.dart';
import 'widgets/program_widgets.dart';

/// A student in a class (Issues #233, #390), built against `Sign in - 35`,
/// `40`, `41` and `42`: the student's name in the header, the Хичээлийн ирц
/// and Шалгалтын дүн cards, the assignment selector, and the thread for the
/// selected assignment — the student's note, the teacher's reply, and the
/// "Тайлбар" composer.
///
/// **What is real.** The note is the submission's `description`; the reply
/// is its review `feedback` (`message`, `created_at`, `mentor`); Submit
/// sends `POST /teacher/submissions/{id}/review` and the reply shown is the
/// one the server answers with — never the typed text before it confirms. A
/// review is one reply, not a running thread: submitting again replaces it,
/// and the edit control puts the current reply back in the composer. When
/// the assignment has a `max_score` the review must carry a score, so a
/// score field appears — no frame draws it (PRODUCT DECISION).
///
/// **What is not.** Both summary figures stay "—" (BACKEND GAP / PRODUCT
/// DECISION, unchanged from #233), and the selector captions assignments by
/// their place in one simple list — not the frames' "Modules N" (PRODUCT
/// DECISION, Issue #394).
class GradebookStudentScreen extends StatefulWidget {
  const GradebookStudentScreen({
    required this.student,
    required this.classController,
    required this.repository,
    super.key,
    this.clock,
  });

  final CohortStudent student;

  /// The class list's controller: the assignments and this student's
  /// submissions come from it, and a saved review goes back to it.
  final GradebookClassController classController;

  final TeacherGradebookRepository repository;

  /// Decides what "Today" is in the timestamps. Injected in tests.
  final DateTime Function()? clock;

  @override
  State<GradebookStudentScreen> createState() => _GradebookStudentScreenState();
}

class _GradebookStudentScreenState extends State<GradebookStudentScreen> {
  final _reply = TextEditingController();
  final _score = TextEditingController();
  final _replyFocus = FocusNode();
  TeacherAssignment? _selected;
  bool _saving = false;
  String? _error;

  GradebookClassController get _class => widget.classController;
  int get _studentId => widget.student.id;

  @override
  void initState() {
    super.initState();
    _selected = _initialAssignment();
    _reply.addListener(_changed);
    _score.addListener(_changed);
    _class.addListener(_changed);
  }

  @override
  void dispose() {
    _class.removeListener(_changed);
    _reply.dispose();
    _score.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// The first assignment waiting for review, else the first submitted,
  /// else the class's first.
  TeacherAssignment? _initialAssignment() {
    final assignments = _class.assignments;
    if (assignments.isEmpty) return null;
    final submissions = _class.submissionsOf(_studentId);
    return assignments.firstWhere(
      (a) => submissions[a.id]?.isPending ?? false,
      orElse: () => assignments.firstWhere(
        (a) => submissions.containsKey(a.id),
        orElse: () => assignments.first,
      ),
    );
  }

  int _pendingFor(TeacherAssignment assignment) =>
      (_class.submissionsOf(_studentId)[assignment.id]?.isPending ?? false)
      ? 1
      : 0;

  Future<void> _pick() async {
    final selected = _selected;
    if (selected == null) return;
    final picked = await showAssignmentPicker(
      context,
      assignments: _class.assignments,
      selected: selected,
      pendingFor: _pendingFor,
    );
    if (picked != null && mounted && picked.id != selected.id) {
      setState(() {
        _selected = picked;
        _reply.clear();
        _score.clear();
        _error = null;
      });
    }
  }

  /// The edit control: the current reply (and score) back in the composer.
  void _edit(TeacherSubmission submission) {
    _reply.text = submission.feedback ?? '';
    final score = submission.score;
    _score.text = score == null
        ? ''
        : score == score.roundToDouble()
        ? '${score.toInt()}'
        : '$score';
    _replyFocus.requestFocus();
  }

  /// The score the composer holds, when the assignment needs one — null
  /// when it is missing, unreadable or out of range.
  num? _parsedScore(num max) {
    final value = num.tryParse(_score.text.trim().replaceAll(',', '.'));
    if (value == null || value < 0 || value > max) return null;
    return value;
  }

  bool _canSubmit(TeacherAssignment assignment) {
    if (_saving || _reply.text.trim().isEmpty) return false;
    final max = assignment.maxScore;
    return max == null || _parsedScore(max) != null;
  }

  Future<void> _submit(
    TeacherAssignment assignment,
    TeacherSubmission sub,
  ) async {
    if (!_canSubmit(assignment)) return;
    final max = assignment.maxScore;
    // The class list owns the controller and outlives this screen (Issue
    // #392): held here so a save confirmed after the teacher leaves still
    // reaches the roster.
    final classController = _class;
    final studentId = _studentId;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.reviewSubmission(
        submissionId: sub.id,
        feedback: _reply.text.trim(),
        score: max == null ? null : _parsedScore(max),
      );
      // The server confirmed it: record it whether or not this screen is
      // still up. Everything below is this screen's own.
      classController.replaceSubmission(studentId, saved);
      if (!mounted) return;
      _reply.clear();
      _score.clear();
      FocusScope.of(context).unfocus();
    } on TeacherFailure catch (failure) {
      if (mounted) _error = TeacherGradebookStrings.replyFailed(failure);
    } catch (_) {
      if (mounted) {
        _error = TeacherGradebookStrings.replyFailed(
          const TeacherFailure(TeacherFailureKind.unexpected),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = _selected;
    final submission = selected == null
        ? null
        : _class.submissionsOf(_studentId)[selected.id];
    final totalPending = _class.pendingOf(_studentId);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Its own style: the page below stops painting once covered,
      // and its style would stay (Issue #400).
      value: AppSystemUi.page(
        context,
        navigationBar: context.palette.surfaceSubtle,
      ),
      child: Scaffold(
        backgroundColor: palette.surfaceSubtle,
        body: SafeArea(
          bottom: false,
          child: ContentColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProgramPageHeader(title: widget.student.name),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    // No keyboard inset here: the `Scaffold` already shrinks
                    // the page by it, and this `context` — above the
                    // `Scaffold` — would add it a second time, a keyboard's
                    // height of blank space under Submit (Issue #463).
                    padding: EdgeInsets.only(
                      top: AppDimens.cardGap,
                      bottom:
                          AppDimens.pageBottom +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppDimens.screenPadding,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: GradebookStatCard(
                                title: TeacherGradebookStrings.attendance,
                                value: TeacherGradebookStrings.noFigure,
                              ),
                            ),
                            SizedBox(width: AppDimens.tileGap),
                            Expanded(
                              child: GradebookStatCard(
                                title: TeacherGradebookStrings.examScore,
                                value: TeacherGradebookStrings.noFigure,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.cardGap),
                      Container(
                        height: AppDimens.borderWidth,
                        color: palette.divider,
                      ),
                      const SizedBox(height: AppDimens.cardGap),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.screenPadding,
                        ),
                        child: selected == null
                            ? const ProgramNotice(
                                message: TeacherGradebookStrings.noAssignments,
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AssignmentSelector(
                                    number:
                                        _class.assignments.indexWhere(
                                          (a) => a.id == selected.id,
                                        ) +
                                        1,
                                    assignment: selected,
                                    pending: totalPending,
                                    onTap: _pick,
                                  ),
                                  const SizedBox(height: AppDimens.tileGap),
                                  _thread(context, selected, submission),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thread(
    BuildContext context,
    TeacherAssignment assignment,
    TeacherSubmission? submission,
  ) {
    final palette = context.palette;
    final now = (widget.clock ?? DateTime.now)();
    final card = BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
      border: Border.all(color: palette.outlineFaint),
    );
    if (submission == null) {
      return DecoratedBox(
        decoration: card,
        child: const ProgramNotice(
          message: TeacherGradebookStrings.notSubmitted,
        ),
      );
    }

    final note = submission.description?.trim();
    final link = submission.link?.trim();
    final max = assignment.maxScore;
    final scoreText = _score.text.trim();
    final scoreInvalid =
        max != null && scoreText.isNotEmpty && _parsedScore(max) == null;

    return DecoratedBox(
      decoration: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThreadEntry(
            avatarId: _studentId,
            name: widget.student.name,
            role: TeacherGradebookStrings.roleStudent,
            message: (note == null || note.isEmpty)
                ? TeacherGradebookStrings.noNote
                : note,
            muted: note == null || note.isEmpty,
            link: (link == null || link.isEmpty) ? null : link,
            at: submission.submittedAt,
            now: now,
          ),
          if (submission.feedback case final reply?) ...[
            Divider(height: 1, thickness: 1, color: palette.outlineFaint),
            ThreadEntry(
              avatarId: submission.mentor?.id ?? 0,
              name:
                  submission.mentor?.name ??
                  TeacherGradebookStrings.roleTeacher,
              role: TeacherGradebookStrings.roleTeacher,
              message: reply,
              at: submission.feedbackAt,
              now: now,
              onEdit: _saving ? null : () => _edit(submission),
            ),
          ],
          Divider(height: 1, thickness: 1, color: palette.outlineFaint),
          Padding(
            padding: const EdgeInsets.all(AppDimens.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The composer down to its Submit: a focused field and the
                // Submit land above the keyboard together (Issue #463). The
                // saving spinner stays below, outside it.
                KeyboardRevealArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KeyboardRevealField(
                        child: TextField(
                          controller: _reply,
                          focusNode: _replyFocus,
                          enabled: !_saving,
                          minLines: 4,
                          maxLines: 8,
                          maxLength: _maxFeedback,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppTypography.fieldText.copyWith(
                            color: palette.textPrimary,
                          ),
                          decoration: _outlined(
                            palette,
                            label: TeacherGradebookStrings.replyLabel,
                          ).copyWith(counterText: ''),
                        ),
                      ),
                      if (max != null) ...[
                        const SizedBox(height: 12),
                        KeyboardRevealField(
                          child: TextField(
                            controller: _score,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            style: AppTypography.fieldText.copyWith(
                              color: palette.textPrimary,
                            ),
                            decoration:
                                _outlined(
                                  palette,
                                  label: TeacherGradebookStrings.scoreLabel(
                                    max,
                                  ),
                                ).copyWith(
                                  errorText: scoreInvalid
                                      ? TeacherGradebookStrings.scoreInvalid(
                                          max,
                                        )
                                      : null,
                                  // Wraps rather than being cut short at
                                  // larger text (Issue #552); still the
                                  // field's error for assistive technology.
                                  errorMaxLines: _scoreErrorMaxLines,
                                ),
                          ),
                        ),
                      ],
                      if (_error case final error?) ...[
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            style: AppTypography.supporting.copyWith(
                              color: palette.errorInk,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      PillButton(
                        label: TeacherGradebookStrings.submit,
                        height: 44,
                        onPressed: _canSubmit(assignment)
                            ? () => _submit(assignment, submission)
                            : null,
                      ),
                    ],
                  ),
                ),
                if (_saving) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The review endpoint's limit (`MAX_FEEDBACK`).
const int _maxFeedback = 5000;

/// Lines the score's range error may take: room for the longest one whole
/// at 3.0× text on a 320pt phone (four lines), with a line to spare.
const int _scoreErrorMaxLines = 5;

InputDecoration _outlined(AppPalette palette, {required String label}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDimens.homeCardRadius),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: AppTypography.fieldLabel.copyWith(color: palette.textPrimary),
    contentPadding: const EdgeInsets.all(16),
    enabledBorder: border(palette.outline),
    focusedBorder: border(palette.borderFocused),
    disabledBorder: border(palette.outlineFaint),
    errorBorder: border(palette.errorOutline),
    focusedErrorBorder: border(palette.errorOutline),
    border: border(palette.outline),
  );
}

/// The selector card: the caption over the assignment title, the student's
/// awaiting-review badge, and a caret — `Sign in - 35`.
class AssignmentSelector extends StatelessWidget {
  const AssignmentSelector({
    required this.number,
    required this.assignment,
    required this.pending,
    required this.onTap,
    super.key,
  });

  final int number;
  final TeacherAssignment assignment;
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppDimens.homeCardRadius);
    return Semantics(
      button: true,
      label:
          '${TeacherGradebookStrings.assignmentCaption(number)}, '
          '${assignment.displayTitle}'
          '${pending > 0 ? ', ${TeacherGradebookStrings.pendingLabel(pending)}' : ''}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: palette.outlineFaint),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TeacherGradebookStrings.assignmentCaption(number),
                        style: AppTypography.supporting.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      Text(
                        assignment.displayTitle,
                        style: AppTypography.itemTitle.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pending > 0) ...[
                  const SizedBox(width: 8),
                  PendingBadge(count: pending),
                ],
                const SizedBox(width: 12),
                Icon(selectorCaret, size: 20, color: palette.textStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One message in the thread: the initials avatar, the name over the role
/// (and the edit control on the teacher's reply), the text, any link, and
/// the time.
class ThreadEntry extends StatelessWidget {
  const ThreadEntry({
    required this.avatarId,
    required this.name,
    required this.role,
    required this.message,
    required this.at,
    required this.now,
    super.key,
    this.link,
    this.muted = false,
    this.onEdit,
  });

  final int avatarId;
  final String name;
  final String role;
  final String message;
  final String? link;
  final DateTime? at;
  final DateTime now;

  /// The note is missing: drawn in the muted ink.
  final bool muted;

  /// Puts this reply back in the composer; null hides the control.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final when = at;
    return Padding(
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudentInitialsAvatar(name: name, studentId: avatarId),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.itemTitle.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      role,
                      style: AppTypography.supporting.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit case final edit?)
                IconButton(
                  onPressed: edit,
                  tooltip: TeacherGradebookStrings.editReply,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 24,
                    color: palette.textStrong,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.body.copyWith(
              color: muted ? palette.textMuted : palette.textSecondary,
            ),
          ),
          if (link case final link?) ...[
            const SizedBox(height: 8),
            SelectableText(
              link,
              style: AppTypography.supporting.copyWith(color: palette.linkInk),
            ),
          ],
          if (when != null) ...[
            const SizedBox(height: 12),
            Text(
              TeacherGradebookStrings.timestamp(when, now: now),
              style: AppTypography.caption.copyWith(color: palette.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
