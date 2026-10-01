import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/presentation/student_tabs.dart';
import '../../course_learning/presentation/course_module_list_screen.dart';
import '../data/enrolled_home_dashboard_repository.dart';
import '../domain/home_dashboard.dart';
import '../domain/home_dashboard_repository.dart';
import 'home_controller.dart';
import 'home_strings.dart';
import 'widgets/attendance_card.dart';
import 'widgets/contract_banner.dart';
import 'widgets/home_header.dart';
import 'widgets/home_palette.dart';
import 'widgets/payment_card.dart';
import 'widgets/program_card.dart';

/// The student's dashboard — the app's Home tab.
///
/// Built against the four Figma Adult Home frames, which are states of this
/// one screen rather than four screens: statistics as full-width rows; an
/// unsigned e-contract with an overdue payment; statistics as side-by-side
/// tiles with the pay action muted; and a lesson under way with its "Live"
/// badge and the attendance action live. Each is a different
/// [HomeDashboard] — the live state comes from the clock, the arrangement of
/// the statistic cards from [HomeDashboard.stats] — and each section draws
/// only when it has data.
///
/// Composition, top to bottom: the brand header, the cohort card, the
/// contract warning, then the statistic cards in the order the dashboard
/// lists them. The `home_screenshot_test.dart` goldens capture all four
/// frames at their own 393pt width.
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
              selectedAsset: HomeIcons.navHomeSelected,
              // Already here.
            ),
            AppBottomNavItem(
              icon: AppIcons.bookOpenText,
              label: HomeStrings.navCourses,
              onTap: () => openStudentTab(context, StudentTab.progress),
            ),
            AppBottomNavItem(
              icon: AppIcons.user,
              label: HomeStrings.navProfile,
              onTap: () => openStudentTab(context, StudentTab.profile),
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
                      color: HomePalette.headerRule,
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

    // None of these actions has a destination in the app yet, and each is
    // given an empty callback rather than null for the reason Profile's
    // log-out button documents: null renders the disabled treatment, and the
    // reference draws every one of them in full contrast. Wiring them up is a
    // separate issue per destination.
    void noDestinationYet() {}

    final sections = <Widget>[
      if (program != null)
        ProgramCard(
          program: program,
          live: program.nextLesson?.isLiveAt(now) ?? false,
          onRegisterAttendance: noDestinationYet,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CourseModuleListScreen(courseSlug: program.courseSlug),
            ),
          ),
        ),
      if (contract != null && !contract.signed)
        ContractBanner(onTap: noDestinationYet),
      ..._statRows(dashboard.stats, noDestinationYet),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.blue,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.screenPadding,
          _sectionGap,
          AppDimens.screenPadding,
          24,
        ),
        // Always scrollable, so pull-to-refresh works even on a short
        // dashboard that fits the viewport.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: sections.length,
        itemBuilder: (_, index) => sections[index],
        separatorBuilder: (_, _) => const SizedBox(height: _sectionGap),
      ),
    );
  }

  /// Lays [stats] out in order: each full-width row on its own, and tiles two
  /// to a line. A tile left without a partner keeps its half width rather
  /// than stretching into a shape the reference never draws.
  static List<Widget> _statRows(
    List<HomeStat> stats,
    VoidCallback noDestinationYet,
  ) {
    Widget card(HomeStat stat) => switch (stat) {
      PaymentStat(:final payment, :final layout) => PaymentCard(
        payment: payment,
        layout: layout,
        onPay: noDestinationYet,
        onDetails: noDestinationYet,
      ),
      AttendanceStat(:final attendance, :final layout) => AttendanceCard(
        attendance: attendance,
        layout: layout,
        onDetails: noDestinationYet,
      ),
    };

    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      final stat = stats[i];
      if (stat.layout == HomeStatLayout.row) {
        rows.add(card(stat));
        continue;
      }

      final partner =
          i + 1 < stats.length && stats[i + 1].layout == HomeStatLayout.tile
          ? stats[++i]
          : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: card(stat)),
              const SizedBox(width: _tileGap),
              Expanded(
                child: partner == null ? const SizedBox() : card(partner),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}

/// Between the header rule and the first card, and between every card: 16
/// in each of the reference frames.
const double _sectionGap = 16;

/// Between two tiles on one line — each 176 wide inside the 361 column.
const double _tileGap = 8;

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
