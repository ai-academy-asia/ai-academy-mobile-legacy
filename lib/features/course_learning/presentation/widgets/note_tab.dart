import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'exercise_submit_button.dart';
import 'exercise_text_field.dart';

/// The Figma sample's own student identity — the same "БП" / "Болд Батаа"
/// `SampleCourseLearningRepository` already gives the one pre-existing note,
/// and `ProfileStrings.name`'s own sample student. A newly-left note is
/// authored by that same student, not a different, invented one.
const String _studentInitials = 'БП';
const String _studentName = 'Болд Батаа';

/// The Note tab: an editable textarea when there is no saved note yet, or
/// when the student is editing one, or the saved note — with the mentor's
/// reply already alongside it — once one exists and isn't being edited.
///
/// **Sample/local state only.** [note] is the tab's own idea of "the current
/// note", not the fixed sample value `CourseExercise.note` — [onSave] hands
/// a new one back up to `CourseExerciseDetailScreen`, which is what makes
/// "submit, then switch tabs and back" still show what was just saved.
/// `PUT /me/lessons/{id}/note` is not integrated, so nothing here survives
/// leaving this screen instance.
///
/// **Read-only when [onSave] is null** — a note loaded from the backend,
/// which nothing here can save back. The layout is the same; only the
/// controls are off: an existing note keeps its card with the edit action
/// drawn disabled, and with no note the textarea and submit are drawn
/// disabled.
/// Measured off `Exercise - 26` at 1:1. The note card is the same 329 x 213
/// box the Assignment tab's feedback card is, with the same 20 of padding and
/// 40 avatar; the edit action sits 17 below it, outside the card's outline.
const double _cardPadding = 20;
const double _avatarRadius = 20;
const double _avatarToMessage = 18;
const double _messageToTimestamp = 18;
const double _cardToEdit = 17;
const Color _cardBorder = Color(0xFFE5E7EB);

class NoteTab extends StatefulWidget {
  const NoteTab({required this.note, this.onSave, super.key});

  final CourseExerciseNote? note;

  /// Called with the note to hold from now on — a first submission or a
  /// saved edit, both go through this. Null makes the tab read-only.
  final ValueChanged<CourseExerciseNote>? onSave;

  @override
  State<NoteTab> createState() => _NoteTabState();
}

class _NoteTabState extends State<NoteTab> {
  final _controller = TextEditingController();

  /// True while the textarea is showing — either there is no note yet, or
  /// the student tapped "Засах" to change the one that exists.
  late bool _editing = widget.note == null;

  bool _hasContent = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasContent = _controller.text.trim().isNotEmpty;
    if (hasContent != _hasContent) setState(() => _hasContent = hasContent);
  }

  void _startEditing() {
    _controller.text = widget.note?.message ?? '';
    setState(() => _editing = true);
  }

  void _submit() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    final onSave = widget.onSave;
    if (onSave == null) return;

    final existing = widget.note;
    onSave(
      CourseExerciseNote(
        authorInitials: existing?.authorInitials ?? _studentInitials,
        authorName: existing?.authorName ?? _studentName,
        authorLabel:
            existing?.authorLabel ?? CourseLearningStrings.noteAuthorMe,
        message: message,
        // No real clock reading behind this — "Just now" is honest about
        // what actually happened (this session, this instant) rather than
        // fabricating a formatted date/time nothing here can confirm.
        timestampLabel: CourseLearningStrings.noteJustNow,
      ),
    );
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final readOnly = widget.onSave == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: _editing
          ? Column(
              children: [
                ExerciseTextField(
                  controller: _controller,
                  placeholder: CourseLearningStrings.descriptionPlaceholder,
                  floatingLabel: CourseLearningStrings.descriptionFloatingLabel,
                  height: 118,
                  multiline: true,
                  enabled: !readOnly,
                ),
                const SizedBox(height: 16),
                ExerciseSubmitButton(
                  onPressed: !readOnly && _hasContent ? _submit : null,
                ),
              ],
            )
          // The reference ends the note card at the timestamp and sets the
          // edit action below it, inside the tab rather than inside the card.
          : Column(
              children: [
                _ExistingNoteCard(note: note!),
                const SizedBox(height: _cardToEdit),
                ExerciseSubmitButton(
                  label: CourseLearningStrings.editNote,
                  onPressed: readOnly ? null : _startEditing,
                  muted: true,
                ),
              ],
            ),
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
      padding: const EdgeInsets.all(_cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder, width: AppDimens.borderWidth),
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
          const SizedBox(height: _avatarToMessage),
          Text(
            note.message,
            style: AppTypography.settingsRowLabel.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: _messageToTimestamp),
          Text(note.timestampLabel, style: AppTypography.cardSupporting),
        ],
      ),
    );
  }
}
