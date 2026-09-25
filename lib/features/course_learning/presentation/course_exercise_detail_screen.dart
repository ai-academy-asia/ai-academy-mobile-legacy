import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../data/sample_course_learning_repository.dart';
import '../domain/course_exercise.dart';
import '../domain/course_learning_repository.dart';
import 'course_exercise_detail_controller.dart';
import 'widgets/assignment_tab.dart';
import 'widgets/course_materials_tab.dart';
import 'widgets/exercise_info_section.dart';
import 'widgets/exercise_tabs.dart';
import 'widgets/exercise_text_field.dart';
import 'widgets/exercise_video_header.dart';
import 'widgets/note_tab.dart';
import 'widgets/quiz_preview_card.dart';

/// The Exercise Detail screen — reached directly from an unlocked module
/// card on `CourseModuleListScreen`, or from either of its "Continue
/// learning" buttons. The Figma flow has no Lesson List step between them;
/// `LessonListScreen` still exists (with its own tests) for a real
/// per-lesson backend contract, but is not part of this screen's normal
/// navigation today — see `CourseModuleListScreen`'s own doc comment.
///
/// **Scope.** The description's expanded/collapsed toggle is UI-only, same
/// as before. The Assignment tab cycles through submit → pending review →
/// "submitted successfully", entirely as local widget state, gated on an
/// attached reference file being (simulated-)downloaded when the exercise
/// has one; see `AssignmentTab`'s own doc comment. The Note tab similarly
/// cycles between empty, editing and saved, held in this screen's own state
/// (see `_note`) so it survives a tab switch; see `NoteTab`'s own doc
/// comment. The Course materials tab's download button flips to a checked
/// "downloaded" state on tap, also local only — see `CourseMaterialCard`'s
/// own doc comment.
///
/// **The Quiz is not one of this card's tabs.** It is a separate
/// `QuizPreviewCard` below the tab card, and starting it pushes two more
/// full screens (`CourseQuizScreen`, `CourseQuizResultScreen`) on top of
/// this one — matching the reference, which draws the quiz as its own
/// preview card and its own screens, not a fourth tab. Its score is held
/// here (see `_quizResult`) for the same reason `_note` is: the student
/// pops back to this screen after finishing it, and the preview card needs
/// to keep showing that result. None of this reaches a backend: there is no
/// Assignment, Note, Materials-download or Quiz endpoint to call yet.
/// Still out of scope, reserved for a separate future issue: a real file
/// *upload* (as opposed to the download this issue adds) against an actual
/// file, and the certificate. Every widget that would eventually carry that
/// behaviour (the play button) is already in place and wired to nothing, the
/// same `_noDestinationYet`-style placeholder `CourseModuleListScreen` uses
/// for its own not-yet-built destinations, so this structure does not need
/// to be rewritten to add that behaviour later.
class CourseExerciseDetailScreen extends StatefulWidget {
  const CourseExerciseDetailScreen({
    required this.moduleId,
    super.key,
    this.repository,
  });

  /// `CourseModule.id` — which module's exercise to load.
  final int moduleId;

  /// Defaults to the sample data. Injected in tests.
  final CourseLearningRepository? repository;

  @override
  State<CourseExerciseDetailScreen> createState() =>
      _CourseExerciseDetailScreenState();
}

class _CourseExerciseDetailScreenState
    extends State<CourseExerciseDetailScreen> {
  late final CourseExerciseDetailController _controller;

  bool _descriptionExpanded = false;
  ExerciseTab _selectedTab = ExerciseTab.assignment;

  /// The Note tab's current note — seeded once from the loaded sample
  /// exercise (see [_buildBody]), then replaced whenever `NoteTab` saves a
  /// new one. Held here, not inside `NoteTab` itself, so a note survives
  /// switching to another tab and back — the same reason [_selectedTab]
  /// and [_descriptionExpanded] live here rather than in a child.
  CourseExerciseNote? _note;

  /// The Quiz's last completed attempt — null until the student finishes it
  /// at least once. Held here, not inside `QuizPreviewCard`, for the same
  /// reason [_note] is: `CourseQuizScreen`/`CourseQuizResultScreen` are
  /// pushed on top of this screen, so their result has to survive popping
  /// back to it.
  ({int correct, int total})? _quizResult;

  @override
  void initState() {
    super.initState();
    _controller = CourseExerciseDetailController(
      repository: widget.repository ?? SampleCourseLearningRepository(),
      moduleId: widget.moduleId,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final exercise = _controller.exercise;
    if (_controller.loading && exercise == null) {
      return const SafeArea(
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.blue,
            ),
          ),
        ),
      );
    }

    // Seeded exactly once, the first time the exercise loads — `_note`
    // then holds whatever `NoteTab` last saved, not the original sample.
    _note ??= exercise!.note;

    return _ExerciseDetailBody(
      exercise: exercise!,
      descriptionExpanded: _descriptionExpanded,
      onToggleDescription: () =>
          setState(() => _descriptionExpanded = !_descriptionExpanded),
      selectedTab: _selectedTab,
      onSelectTab: (tab) => setState(() => _selectedTab = tab),
      note: _note,
      onSaveNote: (note) => setState(() => _note = note),
      quizResult: _quizResult,
      onQuizResult: (result) => setState(() => _quizResult = result),
    );
  }
}

class _ExerciseDetailBody extends StatelessWidget {
  const _ExerciseDetailBody({
    required this.exercise,
    required this.descriptionExpanded,
    required this.onToggleDescription,
    required this.selectedTab,
    required this.onSelectTab,
    required this.note,
    required this.onSaveNote,
    required this.quizResult,
    required this.onQuizResult,
  });

  final CourseExercise exercise;
  final bool descriptionExpanded;
  final VoidCallback onToggleDescription;
  final ExerciseTab selectedTab;
  final ValueChanged<ExerciseTab> onSelectTab;
  final CourseExerciseNote? note;
  final ValueChanged<CourseExerciseNote> onSaveNote;
  final ({int correct, int total})? quizResult;
  final ValueChanged<({int correct, int total})> onQuizResult;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Full-bleed within the content column, unlike everything
              // below it — the reference runs the video edge to edge, with
              // no `screenPadding` gutter either side.
              ExerciseVideoHeader(
                durationLabel: exercise.durationLabel,
                recordingBadgeLabel: exercise.recordingBadgeLabel,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  16,
                  AppDimens.screenPadding,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExerciseInfoSection(
                      exercise: exercise,
                      expanded: descriptionExpanded,
                      onToggle: onToggleDescription,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: exerciseBorderColor,
                          width: AppDimens.borderWidth,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ExerciseTabs(
                            selected: selectedTab,
                            onSelected: onSelectTab,
                          ),
                          _TabContent(
                            tab: selectedTab,
                            exercise: exercise,
                            note: note,
                            onSaveNote: onSaveNote,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    QuizPreviewCard(
                      moduleCaption: exercise.moduleCaption,
                      quiz: exercise.quiz,
                      result: quizResult,
                      onResult: onQuizResult,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tab,
    required this.exercise,
    required this.note,
    required this.onSaveNote,
  });

  final ExerciseTab tab;
  final CourseExercise exercise;
  final CourseExerciseNote? note;
  final ValueChanged<CourseExerciseNote> onSaveNote;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      ExerciseTab.assignment => AssignmentTab(
        feedbackSequence: exercise.assignmentFeedback,
        attachment: exercise.assignmentAttachment,
      ),
      ExerciseTab.materials => CourseMaterialsTab(
        materials: exercise.materials,
      ),
      ExerciseTab.note => NoteTab(note: note, onSave: onSaveNote),
    };
  }
}
