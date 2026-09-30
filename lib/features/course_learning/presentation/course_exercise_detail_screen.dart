import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/http_course_learning_repository.dart';
import '../domain/course_exercise.dart';
import '../domain/course_learning_repository.dart';
import 'course_exercise_detail_controller.dart';
import 'course_learning_strings.dart';
import 'widgets/assignment_tab.dart';
import 'widgets/course_learning_back_button.dart';
import 'widgets/course_materials_tab.dart';
import 'widgets/exercise_info_section.dart';
import 'widgets/exercise_tabs.dart';
import 'widgets/exercise_video_header.dart';
import 'widgets/note_tab.dart';
import 'widgets/quiz_preview_card.dart';

/// Sampled off the reference frames at 1:1. The page is a shade lighter than
/// the app-wide [AppColors.background], and the tab card's outline is lighter
/// than the field outlines inside it (`exerciseBorderColor`).
const Color _page = Color(0xFFF9FAFB);
const Color _cardBorder = Color(0xFFEAEDF0);

/// The Exercise Detail screen — one lesson's content, keyed by [lessonId]
/// and loaded from `GET /me/lessons/{lesson_id}`.
///
/// Reached from `CourseModuleListScreen`'s "Continue learning" buttons, with
/// the server's `continue.lesson_id`, and from `LessonListScreen`'s rows.
/// The module cards still open the sample exercise — see
/// `CourseModuleListScreen`'s own doc comment.
///
/// **Backend lessons are read-only here.** The content is real; the writes
/// are not integrated, so for a lesson whose
/// [CourseExercise.simulatesWrites] is false the Note tab shows the note
/// without letting it be edited, the Assignment tab is disabled, and the
/// quiz card does not draw (the lesson detail carries a quiz summary, not
/// questions). The layout is unchanged either way. The sample exercise keeps
/// the local simulations described below, which the Figma states and the
/// goldens were built against.
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
/// to keep showing that result. None of this reaches a backend: the
/// Assignment, Note, Materials-download and Quiz endpoints the contract
/// documents are not integrated yet.
/// Still out of scope, reserved for a separate future issue: a real file
/// *upload* (as opposed to the download this issue adds) against an actual
/// file, and the certificate. Every widget that would eventually carry that
/// behaviour (the play button) is already in place and wired to nothing, the
/// same `_noDestinationYet`-style placeholder `CourseModuleListScreen` uses
/// for its own not-yet-built destinations, so this structure does not need
/// to be rewritten to add that behaviour later.
class CourseExerciseDetailScreen extends StatefulWidget {
  const CourseExerciseDetailScreen({
    required this.lessonId,
    super.key,
    this.repository,
  });

  /// `Lesson.id` — which lesson to load.
  final int lessonId;

  /// Defaults to `HttpCourseLearningRepository` —
  /// `GET /me/lessons/{lesson_id}` against the signed-in student's token.
  /// Injected in tests, and by the callers that still show sample content.
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
      repository: widget.repository ?? HttpCourseLearningRepository(),
      lessonId: widget.lessonId,
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
      // Dark status-bar glyphs: the reference keeps the bar on the page's own
      // light background and starts the video below it, rather than running
      // the navy up behind it.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _page,
      ),
      child: Scaffold(
        backgroundColor: _page,
        // The reference's video header starts below the status bar, not
        // under it — so the whole body is inset at the top. `bottom: false`
        // keeps the scroll running to the screen's edge.
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.errorMessage case final message?) {
      return _ErrorView(message: message, onRetry: () => _controller.load());
    }

    final exercise = _controller.exercise;
    if (exercise == null) {
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
    _note ??= exercise.note;

    return _ExerciseDetailBody(
      exercise: exercise,
      descriptionExpanded: _descriptionExpanded,
      onToggleDescription: () =>
          setState(() => _descriptionExpanded = !_descriptionExpanded),
      selectedTab: _selectedTab,
      onSelectTab: (tab) => setState(() => _selectedTab = tab),
      note: _note,
      // Only the sample's note save is simulated; a backend note is shown
      // read-only rather than edited into something that is never saved.
      onSaveNote: exercise.simulatesWrites
          ? (note) => setState(() => _note = note)
          : null,
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
  final ValueChanged<CourseExerciseNote>? onSaveNote;
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
                hasVideo: exercise.hasVideo,
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
                    // The reference leaves this much air between the
                    // description's Read more control and the tab card.
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _cardBorder,
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
  final ValueChanged<CourseExerciseNote>? onSaveNote;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      ExerciseTab.assignment => AssignmentTab(
        feedbackSequence: exercise.assignmentFeedback,
        attachment: exercise.assignmentAttachment,
        // The submission API is not integrated: a backend lesson's tab is
        // drawn, but nothing in it can be submitted.
        enabled: exercise.simulatesWrites,
      ),
      ExerciseTab.materials => CourseMaterialsTab(
        materials: exercise.materials,
      ),
      ExerciseTab.note => NoteTab(note: note, onSave: onSaveNote),
    };
  }
}

/// Shown when the lesson could not be loaded.
///
/// The Figma pack has no error state for this screen, so this is
/// `CourseModuleListScreen._ErrorView` reproduced — the same centred message
/// in `cardSupporting`, the same 16 of air, the same outlined `AppButton`
/// retry — with the shared back button above it, since the video header
/// that normally carries this screen's back control is not drawn.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CourseLearningBackButton(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.screenPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: AppTypography.cardSupporting,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: CourseLearningStrings.retry,
                    variant: AppButtonVariant.outlined,
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
