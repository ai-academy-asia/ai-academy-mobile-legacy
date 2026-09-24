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

/// The Exercise Detail screen — reached directly from an unlocked module
/// card on `CourseModuleListScreen`, or from either of its "Continue
/// learning" buttons. The Figma flow has no Lesson List step between them;
/// `LessonListScreen` still exists (with its own tests) for a real
/// per-lesson backend contract, but is not part of this screen's normal
/// navigation today — see `CourseModuleListScreen`'s own doc comment.
///
/// **Scope.** The description's expanded/collapsed toggle, the Course
/// materials tab, and the Note tab's empty/existing-note states are UI-only,
/// same as before. The Assignment tab now cycles through four sample-data
/// states — not submitted, pending review, needs resubmission, accepted —
/// entirely as local widget state; see `AssignmentTab`'s own doc comment.
/// Still out of scope, reserved for a separate future issue: real file
/// upload (an uploaded-file state, upload/download progress against an
/// actual file), the quiz and its scoring/retry, and the certificate. Every
/// widget that would eventually carry that behaviour (the play button, the
/// download buttons) is already in place and wired to nothing, the same
/// `_noDestinationYet`-style placeholder `CourseModuleListScreen` uses for
/// its own not-yet-built destinations, so this structure does not need to be
/// rewritten to add that behaviour later.
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

    return _ExerciseDetailBody(
      exercise: exercise!,
      descriptionExpanded: _descriptionExpanded,
      onToggleDescription: () =>
          setState(() => _descriptionExpanded = !_descriptionExpanded),
      selectedTab: _selectedTab,
      onSelectTab: (tab) => setState(() => _selectedTab = tab),
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
  });

  final CourseExercise exercise;
  final bool descriptionExpanded;
  final VoidCallback onToggleDescription;
  final ExerciseTab selectedTab;
  final ValueChanged<ExerciseTab> onSelectTab;

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
                          _TabContent(tab: selectedTab, exercise: exercise),
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
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.tab, required this.exercise});

  final ExerciseTab tab;
  final CourseExercise exercise;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      ExerciseTab.assignment => AssignmentTab(
        feedbackSequence: exercise.assignmentFeedback,
      ),
      ExerciseTab.materials => CourseMaterialsTab(
        materials: exercise.materials,
      ),
      ExerciseTab.note => NoteTab(note: exercise.note),
    };
  }
}
