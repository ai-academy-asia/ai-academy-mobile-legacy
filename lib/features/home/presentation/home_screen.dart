import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/enrolled_home_dashboard_repository.dart';
import '../domain/home_dashboard.dart';
import '../domain/home_dashboard_repository.dart';
import 'home_controller.dart';
import 'home_strings.dart';
import 'widgets/attendance_card.dart';
import 'widgets/contract_banner.dart';
import 'widgets/home_header.dart';
import 'widgets/payment_card.dart';
import 'widgets/program_card.dart';

/// The student's dashboard — the app's Home tab.
///
/// Built against the Figma Home frames, which are four states of this one
/// screen rather than four screens: a scheduled lesson with the attendance
/// action flat, an unsigned e-contract, a payment either due or overdue, and
/// a lesson under way with its "Live" badge and the action live. Each is a
/// different [HomeDashboard], not a different layout — the sections are the
/// same and each draws only when it has data.
///
/// Composition, top to bottom: the brand header, the cohort card, the
/// contract warning, and the payment and attendance statistics side by side.
///
/// **On the empty sections.** The API has no endpoint for modules,
/// attendance, payments or contracts, so in the app as it stands only the
/// cohort card and its lesson draw — those come from `GET /me/cohorts` and
/// `GET /cohorts`, and the lesson's time and live state are derived from the
/// cohort's own schedule. The rest is built and tested and stays dark until a
/// repository can fill it, rather than shipping the reference's sample
/// figures as if they were this student's. See
/// `EnrolledHomeDashboardRepository`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository, this.clock});

  /// Defaults to the composition over the real API. Injected in tests.
  final HomeDashboardRepository? repository;

  /// Decides whether the next lesson is under way. Injected in tests so the
  /// live state does not depend on when the suite happens to run.
  final DateTime Function()? clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController(
      repository: widget.repository ?? EnrolledHomeDashboardRepository(),
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
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surfaceSubtle,
        bottomNavigationBar: AppBottomNav(
          currentIndex: 0,
          items: [
            const AppBottomNavItem(
              icon: AppIcons.house,
              label: HomeStrings.navHome,
              // Already here.
            ),
            AppBottomNavItem(
              icon: AppIcons.bookOpenText,
              label: HomeStrings.navCourses,
              onTap: () => Navigator.of(context).pushNamed('/my-cohorts'),
            ),
            AppBottomNavItem(
              icon: AppIcons.user,
              label: HomeStrings.navProfile,
              onTap: () => Navigator.of(context).pushNamed('/profile'),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
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
                    const HomeHeader(),
                    Container(
                      height: AppDimens.borderWidth,
                      color: AppColors.border,
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
    final dashboard = _controller.dashboard;

    if (_controller.loading && dashboard == null) return const _LoadingView();

    if (_controller.errorMessage case final message?) {
      return _ErrorView(message: message, onRetry: _controller.load);
    }

    if (_controller.isEmpty || dashboard == null) return const _EmptyView();

    return _DashboardView(
      dashboard: dashboard,
      now: widget.clock?.call() ?? DateTime.now(),
      onRefresh: _controller.load,
    );
  }
}

/// The dashboard itself, once there is something to show.
class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.dashboard,
    required this.now,
    required this.onRefresh,
  });

  final HomeDashboard dashboard;
  final DateTime now;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final program = dashboard.program;
    final contract = dashboard.contract;
    final payment = dashboard.payment;
    final attendance = dashboard.attendance;

    // None of these four actions has a destination in the app yet, and each
    // is given an empty callback rather than null for the reason Profile's
    // log-out button documents: null renders the disabled treatment, and the
    // reference draws every one of them in full contrast. Wiring them up is a
    // separate issue per destination.
    void noDestinationYet() {}

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          16,
          AppDimens.screenPadding,
          24,
        ),
        // Always scrollable, so pull-to-refresh works even on a short
        // dashboard that fits the viewport.
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (program != null)
            ProgramCard(
              program: program,
              live: program.nextLesson?.isLiveAt(now) ?? false,
              onRegisterAttendance: noDestinationYet,
            ),

          if (contract != null && !contract.signed) ...[
            const SizedBox(height: 12),
            ContractBanner(onTap: noDestinationYet),
          ],

          if (payment != null || attendance != null) ...[
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (payment != null)
                    Expanded(
                      child: PaymentCard(
                        payment: payment,
                        onPay: noDestinationYet,
                      ),
                    ),
                  if (payment != null && attendance != null)
                    const SizedBox(width: 12),
                  if (attendance != null)
                    Expanded(
                      child: AttendanceCard(
                        attendance: attendance,
                        onDetails: noDestinationYet,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: Text(
          HomeStrings.empty,
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
              label: HomeStrings.retry,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
