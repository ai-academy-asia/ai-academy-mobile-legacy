import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../data/sample_course_learning_repository.dart';
import '../domain/course_learning_repository.dart';
import '../domain/lesson.dart';
import 'course_exercise_detail_screen.dart';
import 'course_learning_strings.dart';
import 'lesson_list_controller.dart';
import 'widgets/course_learning_back_button.dart';
import 'widgets/lesson_list_item.dart';

/// The Lesson List.
///
/// **Not part of the app's normal navigation.** The Figma flow goes straight
/// from Module List to Exercise Detail, with no Lesson List step between
/// them — `CourseModuleListScreen`'s unlocked module cards and "Continue
/// learning" buttons both open `CourseExerciseDetailScreen` directly. This
/// screen is kept, working and tested, for when a real per-lesson backend
/// contract exists to justify a Lesson List step; nothing currently pushes
/// it, but it stays reachable by constructing it directly (e.g. from a test,
/// or a future dev-only route) without needing to be rebuilt from scratch.
///
/// No Figma screenshot exists for this screen (unlike Module List and
/// Exercise Detail, both built strictly against provided references) — it
/// reuses `CourseModuleListScreen`'s own structure (the same back button, the
/// same heading style, the same card treatment via `LessonListItem`) rather
/// than inventing a new visual language for a screen nothing has designed.
///
/// An unlocked lesson opens the existing `CourseExerciseDetailScreen`,
/// unchanged — see `CourseLearningRepository.getExercise`'s doc comment on
/// why that is still keyed by module rather than by `Lesson.id`.
class LessonListScreen extends StatefulWidget {
  const LessonListScreen({
    required this.moduleId,
    required this.moduleTitle,
    super.key,
    this.repository,
  });

  /// `CourseModule.id` — which module's lessons to load.
  final int moduleId;

  /// `CourseModule.title` — shown as this screen's own heading. Passed in
  /// rather than re-fetched: `CourseModuleListScreen` already has it, and
  /// there is no separate "module detail" endpoint to ask for it again.
  final String moduleTitle;

  /// Defaults to the sample data. Injected in tests.
  final CourseLearningRepository? repository;

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  late final CourseLearningRepository _repository =
      widget.repository ?? SampleCourseLearningRepository();
  late final LessonListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LessonListController(
      repository: _repository,
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
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimens.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CourseLearningBackButton(),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading && _controller.lessons.isEmpty) {
      return const _LoadingView();
    }
    return _LessonListBody(
      moduleTitle: widget.moduleTitle,
      lessons: _controller.lessons,
      repository: _repository,
      moduleId: widget.moduleId,
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _LessonListBody extends StatelessWidget {
  const _LessonListBody({
    required this.moduleTitle,
    required this.lessons,
    required this.repository,
    required this.moduleId,
  });

  final String moduleTitle;
  final List<Lesson> lessons;
  final CourseLearningRepository repository;
  final int moduleId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        8,
        AppDimens.screenPadding,
        AppDimens.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(moduleTitle, style: AppTypography.heading),
          const SizedBox(height: AppDimens.titleToSupporting),
          Text(
            CourseLearningStrings.lessonsLabel,
            style: AppTypography.catalogSectionLabel,
          ),
          const SizedBox(height: 12),
          for (final lesson in lessons) ...[
            LessonListItem(
              lesson: lesson,
              onTap: lesson.locked
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourseExerciseDetailScreen(
                          moduleId: moduleId,
                          repository: repository,
                        ),
                      ),
                    ),
            ),
            if (lesson != lessons.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
