import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/http_course_repository.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';
import 'course_catalog_controller.dart';
import 'course_catalog_strings.dart';
import 'widgets/course_card.dart';

/// The public course catalog — where a signed-in student lands.
///
/// Reuses the login screen's system rather than restating it: the same page
/// grey under white surfaces, the same [AppDimens.screenPadding] gutters and
/// [AppDimens.maxContentWidth] cap, the same heading style, the same
/// [AppButton] for the one action this screen has (retry). Unlike Login, there
/// is no Figma frame for this screen to match — see `CourseCatalogStrings` and
/// `app_typography.dart`'s "Course catalog" section for what that meant had to
/// be decided rather than read off a design.
///
/// No authentication: `GET /courses` is confirmed public, so this screen needs
/// neither a session nor a token — unlike `LoginScreen`, it takes no
/// `AuthSessionStore`.
class CourseCatalogScreen extends StatefulWidget {
  const CourseCatalogScreen({super.key, this.repository});

  /// Defaults to the real API. Injected in tests.
  final CourseRepository? repository;

  @override
  State<CourseCatalogScreen> createState() => _CourseCatalogScreenState();
}

class _CourseCatalogScreenState extends State<CourseCatalogScreen> {
  late final CourseCatalogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CourseCatalogController(
      repository: widget.repository ?? HttpCourseRepository(),
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
                constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        AppDimens.resetHeadingTop,
                        AppDimens.screenPadding,
                        AppDimens.headingToForm,
                      ),
                      child: Text(
                        CourseCatalogStrings.heading,
                        style: AppTypography.heading,
                      ),
                    ),
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
    if (_controller.loading && _controller.courses.isEmpty) {
      return const _LoadingView();
    }

    if (_controller.errorMessage != null) {
      return _ErrorView(message: _controller.errorMessage!, onRetry: _controller.load);
    }

    if (_controller.isEmpty) {
      return const _EmptyView();
    }

    return _CourseList(courses: _controller.courses, onRefresh: _controller.load);
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
        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.blue),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenPadding),
        child: Text(
          CourseCatalogStrings.empty,
          style: AppTypography.cardSupporting,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.screenPadding),
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
              label: CourseCatalogStrings.retry,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({required this.courses, required this.onRefresh});

  final List<Course> courses;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.blue,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          0,
          AppDimens.screenPadding,
          AppDimens.screenPadding,
        ),
        // Always scrollable, even when every card fits on screen, so
        // pull-to-refresh is reachable regardless of how many courses there
        // are.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: courses.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => CourseCard(
          course: courses[index],
          // Opens every cohort, not only this course's: `GET /cohorts` is the
          // only confirmed cohort endpoint, and no course filter is confirmed.
          onTap: () => Navigator.of(context).pushNamed('/cohorts'),
        ),
      ),
    );
  }
}
