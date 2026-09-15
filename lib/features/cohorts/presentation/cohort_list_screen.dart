import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../enrollments/data/http_enrolled_cohorts_repository.dart';
import '../../enrollments/data/http_enrollment_repository.dart';
import '../../enrollments/domain/enrolled_cohorts_repository.dart';
import '../../enrollments/domain/enrollment_repository.dart';
import '../../enrollments/presentation/enrolled_cohorts_controller.dart';
import '../../enrollments/presentation/enrollment_controller.dart';
import '../data/http_cohort_repository.dart';
import '../domain/cohort.dart';
import '../domain/cohort_repository.dart';
import 'cohort_list_controller.dart';
import 'cohort_list_strings.dart';
import 'widgets/cohort_card.dart';

/// The public cohort list — every scheduled cohort across every course.
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
    this.enrollmentRepository,
    this.enrolledCohortsRepository,
  });

  /// Defaults to the real API. Injected in tests.
  final CohortRepository? repository;

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final EnrollmentRepository? enrollmentRepository;

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final EnrolledCohortsRepository? enrolledCohortsRepository;

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
    )..load();
    _enrollment = EnrollmentController(
      repository: widget.enrollmentRepository ?? HttpEnrollmentRepository(),
    );
    _enrolledCohorts = EnrolledCohortsController(
      repository: widget.enrolledCohortsRepository ?? HttpEnrolledCohortsRepository(),
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
  Future<void> _refresh() => Future.wait([_controller.load(), _enrolledCohorts.load()]);

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
            listenable: Listenable.merge([_controller, _enrollment, _enrolledCohorts]),
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
                        CohortListStrings.heading,
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
    if (_controller.loading && _controller.cohorts.isEmpty) {
      return const _LoadingView();
    }

    if (_controller.errorMessage != null) {
      return _ErrorView(message: _controller.errorMessage!, onRetry: _refresh);
    }

    if (_controller.isEmpty) {
      return const _EmptyView();
    }

    return _CohortList(
      cohorts: _controller.cohorts,
      enrollment: _enrollment,
      enrolledCohorts: _enrolledCohorts,
      onRefresh: _refresh,
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
          CohortListStrings.empty,
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
  });

  final List<Cohort> cohorts;
  final EnrollmentController enrollment;
  final EnrolledCohortsController enrolledCohorts;
  final Future<void> Function() onRefresh;

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
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                0,
                AppDimens.screenPadding,
                AppDimens.screenPadding,
              ),
              // Always scrollable, even when every card fits on screen, so
              // pull-to-refresh is reachable regardless of how many cohorts
              // there are.
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: cohorts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                  onEnroll: () => enrollment.enroll(cohort.id),
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
  const _EnrolledCohortsErrorBanner({required this.message, required this.onRetry});

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
                style: AppTypography.buttonLabel.copyWith(color: AppColors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
