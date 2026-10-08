import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/presentation/student_tabs.dart';
import '../../course_learning/presentation/course_module_list_screen.dart';
import '../../courses/domain/course_repository.dart';
import '../../enrollments/data/http_enrolled_cohorts_repository.dart';
import '../../enrollments/data/http_enrollment_repository.dart';
import '../../enrollments/domain/enrolled_cohorts_repository.dart';
import '../../enrollments/domain/enrollment_repository.dart';
import '../../enrollments/presentation/enrolled_cohorts_controller.dart';
import '../../enrollments/presentation/enrollment_controller.dart';
import '../../home/presentation/widgets/adult_bottom_nav.dart';
import '../data/http_cohort_repository.dart';
import '../domain/cohort.dart';
import '../domain/cohort_repository.dart';
import 'cohort_list_controller.dart';
import 'cohort_list_strings.dart';
import 'widgets/cohort_card.dart';

/// The heading's size and the rule beneath it, measured off the reference at
/// 1:1. The heading is a size up from [AppTypography.heading]'s 22, which four
/// other screens share, so it is overridden here rather than on the token; the
/// rule is a lighter grey than the global [AppColors.border].
const double _headingSize = 24;
const double _headingToRule = 14;
const Color _ruleColor = Color(0xFFEAEDF0);

/// The heading's line box starts flush with the safe-area inset — this screen
/// does not take [AppDimens.resetHeadingTop]'s 32, which three other screens
/// share. The box carries 8 of its own leading above the cap, so the title
/// still clears the status bar; the reference's own chain confirms it, at a
/// 59pt inset: 59 + 34 (box) + 14 = 107, the rule, and +1+16 = 124, card one.
const double _headingTop = 0;

/// The cohort list — every scheduled cohort across every course, or, when
/// reached with a [courseId], only that course's cohorts. With [enrolledOnly]
/// it is the signed-in student's own list instead: `GET /cohorts` narrowed to
/// the ids `GET /me/cohorts` names, each card carrying that entry's progress.
///
/// Reuses `CourseCatalogScreen`'s system directly: the same page grey, the
/// same [AppDimens.screenPadding] gutters and [AppDimens.maxContentWidth]
/// cap, the same heading style, the same [AppButton] for retry, the same
/// four states (loading, loaded, empty, error).
///
/// Listing needs no authentication: `GET /cohorts` is modelled as public,
/// matching `CourseCatalogScreen` — see `CohortRepository`'s doc comment.
/// Enrolling does, through [EnrollmentRepository], and so does knowing which
/// cohorts are already enrolled, through [EnrolledCohortsRepository] — both
/// carry the signed-in student's token.
class CohortListScreen extends StatefulWidget {
  const CohortListScreen({
    super.key,
    this.repository,
    this.courseRepository,
    this.enrollmentRepository,
    this.enrolledCohortsRepository,
    this.courseId,
    this.enrolledOnly = false,
    this.showBottomNav = true,
  });

  /// Defaults to the real API. Injected in tests.
  final CohortRepository? repository;

  /// `GET /courses`, used only to resolve each cohort's real course-catalog
  /// slug — see `CohortListController.courseSlugFor`. Defaults to the real
  /// API. Injected in tests.
  final CourseRepository? courseRepository;

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final EnrollmentRepository? enrollmentRepository;

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final EnrolledCohortsRepository? enrolledCohortsRepository;

  /// The course tapped on the catalog, carried here as the `/cohorts` route's
  /// arguments. Null shows every cohort, unfiltered — reaching this screen
  /// with no course context still works.
  final int? courseId;

  /// Shows only the cohorts the student is enrolled in, active or finished,
  /// with their progress — the Хичээл tab's destination. Set, "already
  /// enrolled" is no longer a nicety the list can do without: it decides what
  /// the list *is*, so a failed `GET /me/cohorts` is an error, not a banner.
  final bool enrolledOnly;

  /// Whether this screen draws the adult tab bar itself. False inside
  /// `AdultStudentShell`, which owns the one persistent bar (Issue #237).
  final bool showBottomNav;

  @override
  State<CohortListScreen> createState() => _CohortListScreenState();
}

class _CohortListScreenState extends State<CohortListScreen> {
  late final CohortListController _controller;
  late final EnrollmentController _enrollment;
  late final EnrolledCohortsController _enrolledCohorts;

  @override
  void initState() {
    super.initState();
    _controller = CohortListController(
      repository: widget.repository ?? HttpCohortRepository(),
      courseRepository: widget.courseRepository,
      courseId: widget.courseId,
    )..load();
    _enrollment = EnrollmentController(
      repository: widget.enrollmentRepository ?? HttpEnrollmentRepository(),
    );
    _enrolledCohorts = EnrolledCohortsController(
      repository:
          widget.enrolledCohortsRepository ?? HttpEnrolledCohortsRepository(),
    )..load();
  }

  @override
  void dispose() {
    _enrolledCohorts.dispose();
    _enrollment.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Retries every fetch the screen depends on — the cohort list and the
  /// student's own enrolled cohorts — so pull-to-refresh and either error
  /// view's retry button both leave the screen fully up to date rather than
  /// only half of it.
  Future<void> _refresh() =>
      Future.wait([_controller.load(), _enrolledCohorts.load()]);

  /// What the list draws: every cohort the controller holds, or — for the
  /// student's own list — only those `GET /me/cohorts` named. Keeps the
  /// order `GET /cohorts` returned.
  List<Cohort> get _visibleCohorts => widget.enrolledOnly
      ? [
          for (final cohort in _controller.cohorts)
            if (_enrolledCohorts.isEnrolled(cohort.id)) cohort,
        ]
      : _controller.cohorts;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        // The reference draws this screen the other way round from the rest of
        // the app: a white page carrying faintly-tinted cards, rather than a
        // grey page carrying white ones. The cards keep their own tint from
        // `cohort_background.svg`, so only the page changes here.
        backgroundColor: AppColors.surface,
        bottomNavigationBar: widget.showBottomNav
            ? AdultBottomNav(
                current: StudentTab.progress,
                // The student's own list *is* the Хичээл tab, so there is
                // nowhere to go. Any other list was pushed from the course
                // catalog, where returning to "Хичээл" is a plain pop.
                onCurrentTap: widget.enrolledOnly
                    ? null
                    : () => Navigator.of(context).maybePop(),
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _controller,
              _enrollment,
              _enrolledCohorts,
            ]),
            builder: (context, _) => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimens.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.screenPadding,
                        _headingTop,
                        AppDimens.screenPadding,
                        _headingToRule,
                      ),
                      // A top-level tab destination: the title stands alone, the
                      // way Figma draws it, with no back control.
                      child: Text(
                        CohortListStrings.heading,
                        style: AppTypography.heading.copyWith(
                          fontSize: _headingSize,
                          // The line box stays the 34 the token sets, so only
                          // the glyphs grow and the heading's top edge does not
                          // drift: the reference's ink is what was measured,
                          // its leading was not.
                          height: 34 / _headingSize,
                        ),
                      ),
                    ),
                    // The header's own bottom rule — this screen had none
                    // before.
                    Container(height: AppDimens.borderWidth, color: _ruleColor),
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
    final enrolledOnly = widget.enrolledOnly;

    // The student's own list cannot say anything until both fetches have
    // answered: the cohorts alone would show every cohort, the ids alone
    // name nothing.
    if (enrolledOnly && !_enrolledCohorts.hasLoadedOnce) {
      return const _LoadingView();
    }
    if (_controller.loading && _controller.cohorts.isEmpty) {
      return const _LoadingView();
    }

    if (_controller.errorMessage case final message?) {
      return _ErrorView(message: message, onRetry: _refresh);
    }
    if (enrolledOnly) {
      if (_enrolledCohorts.errorMessage case final message?) {
        return _ErrorView(message: message, onRetry: _refresh);
      }
    }

    final cohorts = _visibleCohorts;
    if (enrolledOnly ? cohorts.isEmpty : _controller.isEmpty) {
      return _EmptyView(
        message: enrolledOnly
            ? CohortListStrings.emptyMine
            : CohortListStrings.empty,
      );
    }

    return _CohortList(
      cohorts: cohorts,
      enrollment: _enrollment,
      enrolledCohorts: _enrolledCohorts,
      onRefresh: _refresh,
      showProgress: enrolledOnly,
      courseSlugFor: _controller.courseSlugFor,
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

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: Text(
          message,
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
              label: CohortListStrings.retry,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _CohortList extends StatelessWidget {
  const _CohortList({
    required this.cohorts,
    required this.enrollment,
    required this.enrolledCohorts,
    required this.onRefresh,
    required this.showProgress,
    required this.courseSlugFor,
  });

  /// Draws each card's `GET /me/cohorts` progress, when it has one.
  final bool showProgress;

  final List<Cohort> cohorts;
  final EnrollmentController enrollment;
  final EnrolledCohortsController enrolledCohorts;
  final Future<void> Function() onRefresh;

  /// `CohortListController.courseSlugFor` — resolves a cohort's real
  /// course-catalog slug rather than trusting its own, possibly stale,
  /// embedded one. See `resolveCohortCourse`'s doc comment.
  final String Function(Cohort cohort) courseSlugFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Does not block the list: the cohorts themselves loaded fine, only
        // *which* are already enrolled is unknown, and every card already
        // falls back to "not yet enrolled" while that is true.
        if (enrolledCohorts.errorMessage case final message?)
          _EnrolledCohortsErrorBanner(message: message, onRetry: onRefresh),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            color: AppColors.blue,
            child: ListView.separated(
              // The same 16 Home leaves between its header rule and its first
              // card.
              padding: const EdgeInsets.all(AppDimens.screenPadding),
              // Always scrollable, even when every card fits on screen, so
              // pull-to-refresh is reachable regardless of how many cohorts
              // there are.
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: cohorts.length,
              // 16 between cards, matching the reference and the list's own
              // 16pt gutter — the gap was 12 before this was measured.
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppDimens.screenPadding),
              itemBuilder: (context, index) {
                final cohort = cohorts[index];
                final enrolled =
                    enrollment.enrollmentFor(cohort.id) != null ||
                    enrolledCohorts.isEnrolled(cohort.id);
                return CohortCard(
                  cohort: cohort,
                  enrolling: enrollment.isEnrolling(cohort.id),
                  enrolled: enrolled,
                  enrollError: enrollment.errorFor(cohort.id),
                  progressPct: showProgress
                      ? enrolledCohorts.progressFor(cohort.id)
                      : null,
                  onEnroll: () => enrollment.enroll(cohort.id),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseModuleListScreen(
                        courseSlug: courseSlugFor(cohort),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The one line telling the student "already enrolled" could not be fetched.
///
/// Not [AppButton] for the retry action: that widget is documented as "a
/// 44pt full-width button", which reads wrong for a single inline word next
/// to a line of text. An [InkWell] on [AppTypography.buttonLabel] in the
/// brand blue is the smallest control this design system already has.
class _EnrolledCohortsErrorBanner extends StatelessWidget {
  const _EnrolledCohortsErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        0,
        AppDimens.screenPadding,
        12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTypography.fieldError,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: CohortListStrings.retry,
            child: InkWell(
              onTap: onRetry,
              child: Text(
                CohortListStrings.retry,
                style: AppTypography.buttonLabel.copyWith(
                  color: AppColors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
