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
/// "submit, then switch tabs and back" still show what was just saved. There
/// is no backend note endpoint — `course_learning_api_requirements_v1.md`
/// lists create/get/update as all requiring backend confirmation — so
/// nothing here survives leaving this screen instance.
class NoteTab extends StatefulWidget {
  const NoteTab({required this.note, required this.onSave, super.key});

  final CourseExerciseNote? note;

  /// Called with the note to hold from now on — a first submission or a
  /// saved edit, both go through this.
  final ValueChanged<CourseExerciseNote> onSave;

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

    final existing = widget.note;
    widget.onSave(
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
                ),
                const SizedBox(height: 16),
                ExerciseSubmitButton(onPressed: _hasContent ? _submit : null),
              ],
            )
          : _ExistingNoteCard(note: note!, onEdit: _startEditing),
    );
  }
}

class _ExistingNoteCard extends StatelessWidget {
  const _ExistingNoteCard({required this.note, required this.onEdit});

  final CourseExerciseNote note;
  final VoidCallback onEdit;

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
          ExerciseSubmitButton(
            label: CourseLearningStrings.editNote,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}
