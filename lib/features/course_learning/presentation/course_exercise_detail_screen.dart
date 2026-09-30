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
/// **What reaches the backend.** Every lesson's Note tab saves through
/// `CourseLearningRepository.saveNote` — `PUT /me/lessons/{id}/note` for a
/// backend lesson, a local simulation for the sample. For a lesson whose
/// [CourseExercise.simulatesWrites] is false, a material's download button
/// fetches a fresh link (`GET /me/materials/{id}/download`) and opens it
/// outside the app. The other writes are not integrated, so for such a
/// lesson the Assignment tab is disabled and the quiz card does not draw (the
/// lesson detail carries a quiz summary, not questions). The layout is
/// unchanged either way. The sample exercise keeps the local simulations
/// described below, which the Figma states and the goldens were built
/// against.
///
/// **Scope.** The description's expanded/collapsed toggle is UI-only, same
/// as before. The Assignment tab cycles through submit → pending review →
/// "submitted successfully", entirely as local widget state, gated on an
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
/// preview card and its own screens, not a fourth tab. Its score is held
/// here (see `_quizResult`): the student pops back to this screen after
/// finishing it, and the preview card needs to keep showing that result.
/// None of this reaches a backend: the Assignment and Quiz endpoints the
/// contract documents are not integrated yet.
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
    this.openUrl,
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

  @override
  State<CourseExerciseDetailScreen> createState() =>
      _CourseExerciseDetailScreenState();
}

class _CourseExerciseDetailScreenState
    extends State<CourseExerciseDetailScreen> {
  late final CourseExerciseDetailController _controller;

  bool _descriptionExpanded = false;
  ExerciseTab _selectedTab = ExerciseTab.assignment;

  /// The Quiz's last completed attempt — null until the student finishes it
  /// at least once. Held here, not inside `QuizPreviewCard`:
  /// `CourseQuizScreen`/`CourseQuizResultScreen` are pushed on top of this
  /// screen, so their result has to survive popping back to it.
  ({int correct, int total})? _quizResult;

  @override
  void initState() {
    super.initState();
    _controller = CourseExerciseDetailController(
      repository: widget.repository ?? HttpCourseLearningRepository(),
      lessonId: widget.lessonId,
      openUrl: widget.openUrl,
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
    required this.savingNote,
    required this.noteSaveErrorMessage,
    required this.onDownloadMaterial,
    required this.isDownloadingMaterial,
    required this.isMaterialOpened,
    required this.materialDownloadErrorMessage,
    required this.quizResult,
    required this.onQuizResult,
  });

  final CourseExercise exercise;
  final bool descriptionExpanded;
  final VoidCallback onToggleDescription;
  final ExerciseTab selectedTab;
  final ValueChanged<ExerciseTab> onSelectTab;
  final CourseExerciseNote? note;
  final Future<bool> Function(String content) onSaveNote;
  final bool savingNote;
  final String? noteSaveErrorMessage;
  final ValueChanged<int>? onDownloadMaterial;
  final bool Function(int materialId) isDownloadingMaterial;
  final bool Function(int materialId) isMaterialOpened;
  final String? Function(int materialId) materialDownloadErrorMessage;
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
  final bool savingNote;
  final String? noteSaveErrorMessage;
  final ValueChanged<int>? onDownloadMaterial;
  final bool Function(int materialId) isDownloadingMaterial;
  final bool Function(int materialId) isMaterialOpened;
  final String? Function(int materialId) materialDownloadErrorMessage;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      ExerciseTab.assignment => AssignmentTab(
        feedbackSequence: exercise.assignmentFeedback,
        attachment: exercise.assignmentAttachment,
        submission: exercise.assignment?.submission,
        // The submission API is not integrated: a backend lesson's tab is
        // drawn, but nothing in it can be submitted.
        enabled: exercise.simulatesWrites,
      ),
      ExerciseTab.materials => CourseMaterialsTab(
        materials: exercise.materials,
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
