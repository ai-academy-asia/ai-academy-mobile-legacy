import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/http_course_learning_repository.dart';
import '../domain/course_learning_repository.dart';
import '../domain/lesson.dart';
import 'course_exercise_detail_screen.dart';
import 'course_learning_strings.dart';
import 'lesson_list_controller.dart';
import 'widgets/course_learning_back_button.dart';
import 'widgets/lesson_list_item.dart';

/// The Lesson List — one module's lessons, from
/// `GET /me/modules/{module_id}/lessons`.
///
/// Opened by an unlocked module card on `CourseModuleListScreen`. The Figma
/// flow goes straight from Module List to Exercise Detail, but a module card
/// knows only its module and the contract names no lesson for one, so this
/// screen is where the student picks the lesson instead of the client
/// inventing a rule for it. "Continue learning" still skips it, opening the
/// server's `continue.lesson_id` directly.
///
/// No Figma screenshot exists for this screen (unlike Module List and
/// Exercise Detail, both built strictly against provided references) — it
/// reuses `CourseModuleListScreen`'s own structure (the same back button, the
/// same heading style, the same card treatment via `LessonListItem`) rather
/// than inventing a new visual language for a screen nothing has designed.
///
/// An unlocked lesson opens `CourseExerciseDetailScreen` for that lesson's
/// own `Lesson.id`.
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

  /// Defaults to `HttpCourseLearningRepository` —
  /// `GET /me/modules/{module_id}/lessons` against the signed-in student's
  /// token. Injected in tests.
  final CourseLearningRepository? repository;

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  late final CourseLearningRepository _repository =
      widget.repository ?? HttpCourseLearningRepository();
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
    if (_controller.errorMessage case final message?) {
      return _ErrorView(message: message, onRetry: () => _controller.load());
    }
    if (_controller.loading && _controller.lessons.isEmpty) {
      return const _LoadingView();
    }
    if (_controller.isEmpty) {
      return _EmptyLessonListBody(moduleTitle: widget.moduleTitle);
    }
    return _LessonListBody(
      moduleTitle: widget.moduleTitle,
      lessons: _controller.lessons,
      repository: _repository,
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

/// Shown when the lessons could not be loaded.
///
/// No design exists for this screen at all, so this is
/// `CourseModuleListScreen._ErrorView` reproduced: the same centred message
/// in `cardSupporting`, the same 16 of air, the same outlined `AppButton`
/// retry. Kept as its own copy rather than extracted, the existing habit —
/// `CourseCatalogScreen` and `CohortListScreen` keep theirs too.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}

class _LessonListBody extends StatelessWidget {
  const _LessonListBody({
    required this.moduleTitle,
    required this.lessons,
    required this.repository,
  });

  final String moduleTitle;
  final List<Lesson> lessons;
  final CourseLearningRepository repository;

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
          _LessonListHeading(moduleTitle: moduleTitle),
          const SizedBox(height: 12),
          for (final lesson in lessons) ...[
            LessonListItem(
              lesson: lesson,
              onTap: lesson.locked
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourseExerciseDetailScreen(
                          lessonId: lesson.id,
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

/// The module title and the "LESSONS" label — drawn the same way whether the
/// module has lessons ([_LessonListBody]) or none ([_EmptyLessonListBody]).
class _LessonListHeading extends StatelessWidget {
  const _LessonListHeading({required this.moduleTitle});

  final String moduleTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(moduleTitle, style: AppTypography.heading),
        const SizedBox(height: AppDimens.titleToSupporting),
        Text(
          CourseLearningStrings.lessonsLabel,
          style: AppTypography.catalogSectionLabel,
        ),
      ],
    );
  }
}

/// A module whose lessons loaded but number none.
///
/// The heading stays exactly where [_LessonListBody] draws it, and the space
/// the rows would fill holds [_EmptyView] instead.
class _EmptyLessonListBody extends StatelessWidget {
  const _EmptyLessonListBody({required this.moduleTitle});

  final String moduleTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            8,
            AppDimens.screenPadding,
            0,
          ),
          child: _LessonListHeading(moduleTitle: moduleTitle),
        ),
        const Expanded(child: _EmptyView()),
      ],
    );
  }
}

/// No design exists for this screen at all, so this is
/// `CohortListScreen._EmptyView` reproduced: a centred message in
/// `cardSupporting` with the `screenPadding` gutter — kept as its own copy,
/// the existing habit (see [_ErrorView]).
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDimens.screenPadding),
        child: Text(
          CourseLearningStrings.lessonsEmpty,
          style: AppTypography.cardSupporting,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
