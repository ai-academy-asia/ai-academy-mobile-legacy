import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../enrollments/data/http_enrollment_repository.dart';
import '../../enrollments/domain/enrollment_repository.dart';
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
/// Enrolling does: each card's enroll action goes through
/// [EnrollmentRepository], which carries the signed-in student's token.
class CohortListScreen extends StatefulWidget {
  const CohortListScreen({super.key, this.repository, this.enrollmentRepository});

  /// Defaults to the real API. Injected in tests.
  final CohortRepository? repository;

  /// Defaults to the real API with the app-wide session. Injected in tests.
  final EnrollmentRepository? enrollmentRepository;

  @override
  State<CohortListScreen> createState() => _CohortListScreenState();
}

class _CohortListScreenState extends State<CohortListScreen> {
  late final CohortListController _controller;
  late final EnrollmentController _enrollment;

  @override
  void initState() {
    super.initState();
    _controller = CohortListController(
      repository: widget.repository ?? HttpCohortRepository(),
    )..load();
    _enrollment = EnrollmentController(
      repository: widget.enrollmentRepository ?? HttpEnrollmentRepository(),
    );
  }

  @override
  void dispose() {
    _enrollment.dispose();
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
            listenable: Listenable.merge([_controller, _enrollment]),
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
      return _ErrorView(message: _controller.errorMessage!, onRetry: _controller.load);
    }

    if (_controller.isEmpty) {
      return const _EmptyView();
    }

    return _CohortList(
      cohorts: _controller.cohorts,
      enrollment: _enrollment,
      onRefresh: _controller.load,
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
    required this.onRefresh,
  });

  final List<Cohort> cohorts;
  final EnrollmentController enrollment;
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
        // pull-to-refresh is reachable regardless of how many cohorts there
        // are.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: cohorts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final cohort = cohorts[index];
          return CohortCard(
            cohort: cohort,
            enrolling: enrollment.isEnrolling(cohort.id),
            enrolled: enrollment.enrollmentFor(cohort.id) != null,
            enrollError: enrollment.errorFor(cohort.id),
            onEnroll: () => enrollment.enroll(cohort.id),
          );
        },
      ),
    );
  }
}
