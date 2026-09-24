import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/describe_json.dart';
import '../../../shared/widgets/app_button.dart';
import '../../course_learning/presentation/course_module_list_screen.dart';
import '../data/http_course_repository.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';
import 'course_detail_controller.dart';
import 'course_detail_strings.dart';
import 'widgets/course_badge.dart';
import 'widgets/course_banner.dart';
import 'widgets/course_detail_section.dart';
import 'widgets/course_meta_row.dart';
import 'widgets/course_price_row.dart';

/// One course's full detail — reached by tapping its `CourseCard` in the
/// catalog.
///
/// Reuses the catalog's system throughout rather than a second visual
/// language for one course's own page: the same page grey, the same gutters
/// and [AppDimens.maxContentWidth] cap, the same [AppTypography.heading] the
/// other top-level screens use for their title, and — literally, not just
/// stylistically — the same [CourseBanner], [CourseBadges], [CourseMetaRow]
/// and [CoursePriceRow] the catalog card already renders.
///
/// No authentication: `GET /courses/{slug}` is confirmed public, same as the
/// list.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({required this.slug, super.key, this.repository});

  /// Which course to load.
  final String slug;

  /// Defaults to the real API. Injected in tests.
  final CourseRepository? repository;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late final CourseDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CourseDetailController(
      repository: widget.repository ?? HttpCourseRepository(),
      slug: widget.slug,
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
                    _BackButton(),
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
    if (_controller.loading && _controller.course == null) {
      return const _LoadingView();
    }

    if (_controller.errorMessage != null) {
      return _ErrorView(
        message: _controller.errorMessage!,
        onRetry: _controller.load,
      );
    }

    // Loading is checked above only for the *first* fetch — a retry after an
    // error keeps showing that error until it resolves, same as
    // CourseCatalogScreen; there is nothing stale to show underneath it here.
    return _CourseDetailBody(course: _controller.course!);
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, AppDimens.screenPadding, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          label: CourseDetailStrings.back,
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                AppIcons.caretLeft,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
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
              label: CourseDetailStrings.retry,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseDetailBody extends StatelessWidget {
  const _CourseDetailBody({required this.course});

  final Course course;

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
          if (course.bannerImageUrl case final url?) ...[
            CourseBanner(url: url),
            const SizedBox(height: 16),
          ],

          CourseBadges(course: course),
          const SizedBox(height: 12),

          Text(
            course.title.preferred ?? course.slug,
            style: AppTypography.heading,
          ),

          if (course.tagline.preferred case final tagline?) ...[
            const SizedBox(height: AppDimens.titleToSupporting),
            Text(tagline, style: AppTypography.cardSupporting),
          ],

          if (course.targetAudience case final audience?) ...[
            const SizedBox(height: AppDimens.cardLineGap),
            Text(audience, style: AppTypography.cardSupporting),
          ],

          const SizedBox(height: 16),
          CourseMetaRow(course: course),

          const SizedBox(height: 12),
          CoursePriceRow(course: course),

          const SizedBox(height: 16),
          AppButton(
            label: CourseDetailStrings.openCourseLearning,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CourseModuleListScreen(courseSlug: course.slug),
              ),
            ),
          ),

          const SizedBox(height: 24),

          CourseDetailSection(
            title: CourseDetailStrings.descriptionTitle,
            lines: _describeField(course.description),
          ),
          CourseDetailSection(
            title: CourseDetailStrings.curriculumTitle,
            lines: describeJsonLines(course.curriculum),
          ),
          CourseDetailSection(
            title: CourseDetailStrings.instructorsTitle,
            lines: describeJsonLines(course.instructors),
          ),
          CourseDetailSection(
            title: CourseDetailStrings.prerequisitesTitle,
            lines: describeJsonLines(course.prerequisites),
          ),
          CourseDetailSection(
            title: CourseDetailStrings.whatsIncludedTitle,
            lines: describeJsonLines(course.whatsIncluded),
          ),
        ],
      ),
    );
  }
}

/// `description` is the one detail-only field plausibly shaped like [title]
/// and [Course.tagline] — a `{"en", "mn"}` object on the same resource. Try
/// that reading first; fall back to the fully generic renderer for whatever
/// shape it turns out to actually be.
List<String> _describeField(Object? value) {
  if (preferMongolianText(value) case final text?) return [text];
  return describeJsonLines(value);
}
