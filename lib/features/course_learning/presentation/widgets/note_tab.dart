import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/course_exercise.dart';
import '../course_learning_strings.dart';
import 'exercise_submit_button.dart';
import 'exercise_text_field.dart';

/// The Note tab: an editable textarea when there is no saved note yet, or
/// when the student is editing one, or the saved note once one exists and
/// isn't being edited.
///
/// **Saving is the caller's.** [onSave] is handed the trimmed text and
/// answers whether it was saved; the note then shown is whatever
/// `CourseExerciseDetailScreen` passes back down as [note] — the
/// repository's answer, with its own author and timestamp, never one built
/// here. While [saving], Submit is off; if the save fails, the textarea
/// stays open with what was typed, and [errorMessage] is shown under it in
/// the Login screen's own `fieldError` treatment — the Figma pack has no
/// saving or error state for this tab to follow instead.
///
/// **Read-only when [onSave] is null.** The layout is the same; only the
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
const double _fieldToError = 8;

class NoteTab extends StatefulWidget {
  const NoteTab({
    required this.note,
    this.onSave,
    this.saving = false,
    this.errorMessage,
    super.key,
  });

  final CourseExerciseNote? note;

  /// Called with the text to save — a first submission or a saved edit, both
  /// go through this — and answers whether it was saved. Null makes the tab
  /// read-only.
  final Future<bool> Function(String content)? onSave;

  /// True while a save is in flight: Submit is drawn disabled.
  final bool saving;

  /// Why the last save failed, or null.
  final String? errorMessage;

  @override
  State<NoteTab> createState() => _NoteTabState();
}

class _NoteTabState extends State<NoteTab> {
  final _controller = TextEditingController();

  /// True while the textarea is showing — either there is no note yet, or
  /// the student tapped "Засах" to change the one that exists.
  late bool _editing = widget.note == null;

  bool _hasContent = false;

  /// True once a submit from this tab has failed, until the next one — so
  /// [NoteTab.errorMessage] is shown under the attempt it belongs to, not
  /// carried into a later edit.
  bool _submitFailed = false;

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
    setState(() {
      _editing = true;
      _submitFailed = false;
    });
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    final onSave = widget.onSave;
    if (onSave == null) return;

    setState(() => _submitFailed = false);
    final saved = await onSave(content);
    if (!mounted) return;
    setState(() {
      // A failed save keeps the textarea open with what was typed.
      if (saved) _editing = false;
      _submitFailed = !saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final readOnly = widget.onSave == null;
    final errorMessage = _submitFailed ? widget.errorMessage : null;

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
                if (errorMessage != null) ...[
                  const SizedBox(height: _fieldToError),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(errorMessage, style: AppTypography.fieldError),
                  ),
                ],
                const SizedBox(height: 16),
                ExerciseSubmitButton(
                  onPressed: !readOnly && _hasContent && !widget.saving
                      ? _submit
                      : null,
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
