import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/pick_local_file.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/http_course_learning_repository.dart';
import '../domain/course_exercise.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_quiz.dart';
import '../domain/uploaded_file.dart';
import 'course_exercise_detail_controller.dart';
import 'course_learning_strings.dart';
import 'course_quiz_screen.dart';
import 'widgets/assignment_tab.dart';
import 'widgets/course_learning_back_button.dart';
import 'widgets/course_materials_tab.dart';
import 'widgets/exercise_info_section.dart';
import 'widgets/exercise_tabs.dart';
import 'widgets/exercise_video_header.dart';
import 'widgets/note_tab.dart';
import 'widgets/quiz_preview_card.dart';

// Sampled off the reference frames at 1:1. The page (`surfaceSubtle`) is a
// shade lighter than the app-wide `pageBackground`, and the tab card's edge
// (`outlineFaint`) is lighter than the field outlines inside it (`outline`).

/// The Exercise Detail screen — one lesson's content, keyed by [lessonId]
/// and loaded from `GET /me/lessons/{lesson_id}`.
///
/// Reached from `CourseModuleListScreen`'s "Continue learning" buttons, with
/// the server's `continue.lesson_id`, and from `LessonListScreen`'s rows.
///
/// **What reaches the backend.** Every lesson's Note tab saves through
/// `CourseLearningRepository.saveNote` — `PUT /me/lessons/{id}/note` for a
/// backend lesson, a local simulation for the sample. For a lesson whose
/// [CourseExercise.simulatesWrites] is false, a material's download button
/// fetches a fresh link (`GET /me/materials/{id}/download`) and opens it
/// outside the app, and — when the lesson has an assignment — the Assignment
/// tab submits a link through `POST /me/assignments/{id}/submissions`. The
/// file form (pick a file, upload it through `POST /me/files`, submit its
/// id) is built behind the same tab but no backend lesson draws it yet — see
/// [_formFor]. With no assignment its tab is disabled. A lesson with a quiz
/// draws its preview card from the lesson's own §2.7 summary, and the quiz
/// itself runs against the quiz endpoints — see below. The layout is
/// unchanged either way. The sample exercise keeps the local simulations
/// described below, which the Figma states and the goldens were built
/// against.
///
/// **Scope.** The description's expanded/collapsed toggle is UI-only, same
/// as before. On the sample, the Assignment tab cycles through submit →
/// pending review → "submitted successfully", entirely as local widget
/// state, gated on an
/// attached reference file being (simulated-)downloaded when the exercise
/// has one; see `AssignmentTab`'s own doc comment. The Note tab cycles
/// between empty, editing and saved; the saved note is held on the
/// controller's exercise, so it survives a tab switch; see `NoteTab`'s own
/// doc comment. On the sample, the Course materials tab's download button
/// flips to a checked "downloaded" state on tap, local only — see
/// `CourseMaterialCard`'s own doc comment.
///
/// **The Quiz is not one of this card's tabs.** It is a separate
/// `QuizPreviewCard` below the tab card, and starting it pushes two more
/// full screens (`CourseQuizScreen`, `CourseQuizResultScreen`) on top of
/// this one — matching the reference, which draws the quiz as its own
/// preview card and its own screens, not a fourth tab. The attempt runs
/// against §2.7 (`CourseQuizScreen`), and when the student comes back the
/// lesson is re-read for its quiz summary (see `_openQuiz`), so the card
/// shows the server's own `last_result` and `attempts_left`.
/// Still out of scope, reserved for a separate future issue: the
/// certificate. Every widget that would eventually carry a not-yet-built
/// behaviour (the play button) is already in place and wired to nothing, the
/// same `_noDestinationYet`-style placeholder `CourseModuleListScreen` uses
/// for its own not-yet-built destinations, so this structure does not need
/// to be rewritten to add that behaviour later.
/// Which of the reference's two assignment forms [assignment] draws.
///
/// **BACKEND GAP — always the link form.** The reference draws a link field
/// *or* a file area, never both, and nothing confirmed says which one a
/// given assignment takes: §2.6's `assignment` as this client knows it
/// (`id`, `title`, `instructions`, `due_date`, `max_score`, `attachment`,
/// `submission`) has no such field, and a submission accepts either. So
/// every backend assignment keeps the link form it already had, rather than
/// a rule invented here. When the backend says which, this is the one place
/// that reads it; the file form behind it is already wired.
AssignmentForm _formFor(CourseAssignment assignment) => AssignmentForm.link;

class CourseExerciseDetailScreen extends StatefulWidget {
  const CourseExerciseDetailScreen({
    required this.lessonId,
    super.key,
    this.repository,
    this.openUrl,
    this.pickFile,
    @visibleForTesting this.assignmentForm,
  });

  /// `Lesson.id` — which lesson to load.
  final int lessonId;

  /// Defaults to `HttpCourseLearningRepository` —
  /// `GET /me/lessons/{lesson_id}` against the signed-in student's token.
  /// Injected in tests, and by the callers that still show sample content.
  final CourseLearningRepository? repository;

  /// Opens a material's download link outside the app. Defaults to
  /// `openExternalUrl`; injected in tests, which must not reach the
  /// platform.
  final Future<bool> Function(Uri url)? openUrl;

  /// Asks the student for the file an assignment submission uploads.
  /// Defaults to `pickLocalFile`; injected in tests, for the same reason.
  final Future<PickedFile?> Function()? pickFile;

  /// Overrides [_formFor]. Tests only: it is how the file form is exercised
  /// end to end while no backend assignment selects it.
  final AssignmentForm? assignmentForm;

  @override
  State<CourseExerciseDetailScreen> createState() =>
      _CourseExerciseDetailScreenState();
}

class _CourseExerciseDetailScreenState
    extends State<CourseExerciseDetailScreen> {
  late final CourseExerciseDetailController _controller;

  bool _descriptionExpanded = false;

  /// The first tab, Note: where the learning workflow starts (Issue #219).
  ExerciseTab _selectedTab = ExerciseTab.note;

  /// The one repository this screen's controller and its quiz share.
  late final CourseLearningRepository _repository =
      widget.repository ?? HttpCourseLearningRepository();

  @override
  void initState() {
    super.initState();
    _controller = CourseExerciseDetailController(
      repository: _repository,
      lessonId: widget.lessonId,
      openUrl: widget.openUrl,
      pickFile: widget.pickFile,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens the quiz's own screens, then re-reads the summary however the
  /// student left them — finished, or closed part-way with an attempt still
  /// open — since either changes what the server reports.
  Future<void> _openQuiz(CourseQuiz quiz) async {
    await Navigator.of(context).push<QuizAttemptResult>(
      MaterialPageRoute(
        builder: (_) => CourseQuizScreen(quiz: quiz, repository: _repository),
      ),
    );
    await _controller.refreshQuiz();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status-bar glyphs: the reference keeps the bar on the page's own
      // light background and starts the video below it, rather than running
      // the navy up behind it.
      value: AppSystemUi.page(
        context,
        navigationBar: context.palette.surfaceSubtle,
      ),
      child: Scaffold(
        backgroundColor: context.palette.surfaceSubtle,
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
      return SafeArea(
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: context.palette.primary,
            ),
          ),
        ),
      );
    }

    return _ExerciseDetailBody(
      exercise: exercise,
      descriptionExpanded: _descriptionExpanded,
      onToggleDescription: () =>
          setState(() => _descriptionExpanded = !_descriptionExpanded),
      selectedTab: _selectedTab,
      onSelectTab: (tab) => setState(() => _selectedTab = tab),
      // Held on the controller's exercise, not in `NoteTab`, so a saved
      // note survives switching to another tab and back.
      note: exercise.note,
      onSaveNote: _controller.saveNote,
      onSubmitAssignment: _controller.submitAssignment,
      submittingAssignment: _controller.submittingAssignment,
      assignmentSubmitErrorMessage: _controller.assignmentSubmitErrorMessage,
      onPickAssignmentFile: _controller.pickAndUploadAssignmentFile,
      onCancelAssignmentFileUpload: _controller.cancelAssignmentFileUpload,
      onRemoveAssignmentFile: _controller.removeAssignmentFile,
      assignmentFileUploadSizeBytes: _controller.assignmentFileUploadSizeBytes,
      assignmentFile: _controller.assignmentFile,
      assignmentFileErrorMessage: _controller.assignmentFileErrorMessage,
      assignmentForm: widget.assignmentForm,
      savingNote: _controller.savingNote,
      noteSaveErrorMessage: _controller.noteSaveErrorMessage,
      // The sample's materials have no stored file: its button keeps the
      // local toggle rather than asking for a link that does not exist.
      onDownloadMaterial: exercise.simulatesWrites
          ? null
          : _controller.downloadMaterial,
      isDownloadingMaterial: _controller.isDownloadingMaterial,
      isMaterialOpened: _controller.isMaterialOpened,
      materialDownloadErrorMessage: _controller.materialDownloadErrorMessage,
      onStartQuiz: _openQuiz,
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
    required this.onSubmitAssignment,
    required this.submittingAssignment,
    required this.assignmentSubmitErrorMessage,
    required this.onPickAssignmentFile,
    required this.onCancelAssignmentFileUpload,
    required this.onRemoveAssignmentFile,
    required this.assignmentFileUploadSizeBytes,
    required this.assignmentFile,
    required this.assignmentFileErrorMessage,
    required this.assignmentForm,
    required this.savingNote,
    required this.noteSaveErrorMessage,
    required this.onDownloadMaterial,
    required this.isDownloadingMaterial,
    required this.isMaterialOpened,
    required this.materialDownloadErrorMessage,
    required this.onStartQuiz,
  });

  final CourseExercise exercise;
  final bool descriptionExpanded;
  final VoidCallback onToggleDescription;

  final ExerciseTab selectedTab;
  final ValueChanged<ExerciseTab> onSelectTab;
  final CourseExerciseNote? note;
  final Future<bool> Function(String content) onSaveNote;
  final Future<bool> Function({String? link, String? description})
  onSubmitAssignment;
  final bool submittingAssignment;
  final String? assignmentSubmitErrorMessage;
  final VoidCallback onPickAssignmentFile;
  final VoidCallback onCancelAssignmentFileUpload;
  final VoidCallback onRemoveAssignmentFile;
  final int? assignmentFileUploadSizeBytes;
  final UploadedFile? assignmentFile;
  final String? assignmentFileErrorMessage;
  final AssignmentForm? assignmentForm;
  final bool savingNote;
  final String? noteSaveErrorMessage;
  final ValueChanged<int>? onDownloadMaterial;
  final bool Function(int materialId) isDownloadingMaterial;
  final bool Function(int materialId) isMaterialOpened;
  final String? Function(int materialId) materialDownloadErrorMessage;
  final ValueChanged<CourseQuiz> onStartQuiz;

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
                        color: context.palette.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.palette.outlineFaint,
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
                            onSubmitAssignment: onSubmitAssignment,
                            submittingAssignment: submittingAssignment,
                            assignmentSubmitErrorMessage:
                                assignmentSubmitErrorMessage,
                            onPickAssignmentFile: onPickAssignmentFile,
                            onCancelAssignmentFileUpload:
                                onCancelAssignmentFileUpload,
                            onRemoveAssignmentFile: onRemoveAssignmentFile,
                            assignmentFileUploadSizeBytes:
                                assignmentFileUploadSizeBytes,
                            assignmentFile: assignmentFile,
                            assignmentFileErrorMessage:
                                assignmentFileErrorMessage,
                            assignmentForm: assignmentForm,
                            savingNote: savingNote,
                            noteSaveErrorMessage: noteSaveErrorMessage,
                            onDownloadMaterial: onDownloadMaterial,
                            isDownloadingMaterial: isDownloadingMaterial,
                            isMaterialOpened: isMaterialOpened,
                            materialDownloadErrorMessage:
                                materialDownloadErrorMessage,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    QuizPreviewCard(
                      moduleCaption: exercise.moduleCaption,
                      quiz: exercise.quiz,
                      onStart: () {
                        if (exercise.quiz case final quiz?) onStartQuiz(quiz);
                      },
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
    required this.onSubmitAssignment,
    required this.submittingAssignment,
    required this.assignmentSubmitErrorMessage,
    required this.onPickAssignmentFile,
    required this.onCancelAssignmentFileUpload,
    required this.onRemoveAssignmentFile,
    required this.assignmentFileUploadSizeBytes,
    required this.assignmentFile,
    required this.assignmentFileErrorMessage,
    required this.assignmentForm,
    required this.savingNote,
    required this.noteSaveErrorMessage,
    required this.onDownloadMaterial,
    required this.isDownloadingMaterial,
    required this.isMaterialOpened,
    required this.materialDownloadErrorMessage,
  });

  final ExerciseTab tab;
  final CourseExercise exercise;
  final CourseExerciseNote? note;
  final Future<bool> Function(String content) onSaveNote;
  final Future<bool> Function({String? link, String? description})
  onSubmitAssignment;
  final bool submittingAssignment;
  final String? assignmentSubmitErrorMessage;
  final VoidCallback onPickAssignmentFile;
  final VoidCallback onCancelAssignmentFileUpload;
  final VoidCallback onRemoveAssignmentFile;
  final int? assignmentFileUploadSizeBytes;
  final UploadedFile? assignmentFile;
  final String? assignmentFileErrorMessage;
  final AssignmentForm? assignmentForm;
  final bool savingNote;
  final String? noteSaveErrorMessage;
  final ValueChanged<int>? onDownloadMaterial;
  final bool Function(int materialId) isDownloadingMaterial;
  final bool Function(int materialId) isMaterialOpened;
  final String? Function(int materialId) materialDownloadErrorMessage;

  @override
  Widget build(BuildContext context) {
    // The sample simulates; a backend lesson can submit only when it has an
    // assignment to submit to.
    final assignment = exercise.assignment;
    final submitsToBackend = !exercise.simulatesWrites && assignment != null;
    return switch (tab) {
      ExerciseTab.assignment => AssignmentTab(
        feedbackSequence: exercise.assignmentFeedback,
        attachment: exercise.assignmentAttachment,
        submission: exercise.assignment?.submission,
        enabled: exercise.simulatesWrites || assignment != null,
        onSubmit: submitsToBackend
            ? (link, description) =>
                  onSubmitAssignment(link: link, description: description)
            : null,
        submitting: submittingAssignment,
        errorMessage: assignmentSubmitErrorMessage,
        form: assignment == null
            ? AssignmentForm.link
            : assignmentForm ?? _formFor(assignment),
        onPickFile: onPickAssignmentFile,
        onCancelFileUpload: onCancelAssignmentFileUpload,
        onRemoveFile: onRemoveAssignmentFile,
        fileUploadSizeBytes: assignmentFileUploadSizeBytes,
        uploadedFile: assignmentFile,
        fileErrorMessage: assignmentFileErrorMessage,
      ),
      // The lesson's materials and its assignment's attachment, together.
      ExerciseTab.materials => CourseMaterialsTab(
        materials: exercise.allMaterials,
        onDownload: onDownloadMaterial,
        isDownloading: isDownloadingMaterial,
        isDownloaded: isMaterialOpened,
        errorMessageFor: materialDownloadErrorMessage,
      ),
      ExerciseTab.note => NoteTab(
        note: note,
        onSave: onSaveNote,
        saving: savingNote,
        errorMessage: noteSaveErrorMessage,
      ),
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
                    style: AppTypography.cardSupporting.copyWith(
                      color: context.palette.textSecondary,
                    ),
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
