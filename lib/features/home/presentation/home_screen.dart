import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_system_ui.dart';
import '../../../core/theme/app_palette.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/presentation/student_tabs.dart';
import '../../contracts/domain/contract_repository.dart';
import '../../contracts/presentation/contract_screen.dart';
import '../../course_learning/presentation/course_module_list_screen.dart';
import '../../notifications/presentation/notification_center.dart';
import '../data/enrolled_home_dashboard_repository.dart';
import '../domain/home_dashboard.dart';
import '../domain/home_dashboard_repository.dart';
import 'attendance_detail_screen.dart';
import 'home_controller.dart';
import 'payment_previews.dart';
import 'home_strings.dart';
import 'widgets/adult_bottom_nav.dart';
import 'widgets/attendance_card.dart';
import 'widgets/contract_banner.dart';
import 'widgets/home_header.dart';
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
/// **On the empty sections.** A section whose source did not answer stays
/// dark rather than shipping the reference's sample figures as if they were
/// this student's — the cohort card from `GET /me/cohorts` and
/// `GET /cohorts`, the module count, payment and attendance cards from their
/// own endpoints, and the contract warning from `GET /me/contracts` (Issue
/// #300). See `EnrolledHomeDashboardRepository`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.repository,
    this.clock,
    this.showPaymentPreview = !kReleaseMode,
    this.showBottomNav = true,
    this.notifications,
    this.contractRepository,
  });

  /// Defaults to the composition over the real API. Injected in tests.
  final HomeDashboardRepository? repository;

  /// What the contract banner's E-Contract screen reads (Issue #300).
  /// Defaults to the real API; injected in tests.
  final ContractRepository? contractRepository;

  /// The unread count the header's bell shows, refreshed with the screen's
  /// own data (Issue #291). Defaults to [NotificationCenter.instance];
  /// injected in tests.
  final NotificationCenter? notifications;

  /// Decides whether the next lesson is under way. Injected in tests so the
  /// live state does not depend on when the suite happens to run.
  final DateTime Function()? clock;

  /// Whether the payment card's "Дэлгэрэнгүй" and its live pay action open
  /// the Payment screen. Off in release builds: until `/me/ledger`'s
  /// installments are confirmed the screen has only temporary UI fixtures to
  /// show (Issue #196), and no real student may see those as theirs.
  /// Debug and profile builds open it, for design review on a device.
  final bool showPaymentPreview;

  /// Whether this screen draws the adult tab bar itself. False inside
  /// `AdultStudentShell`, which owns the one persistent bar (Issue #237).
  final bool showBottomNav;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  /// The dashboard's pull-to-refresh, which the header logo also drives.
  final _refreshIndicator = GlobalKey<RefreshIndicatorState>();

  /// A tap on the header logo (Issue #221): the dashboard's own
  /// pull-to-refresh, its indicator included, when the dashboard is on
  /// screen; otherwise — loading, failed or empty — the same [load] the
  /// retry uses. Either way one request at a time ([HomeController.load]).
  void _refreshFromLogo() {
    final indicator = _refreshIndicator.currentState;
    if (indicator != null) {
      indicator.show();
    } else {
      _refresh();
    }
  }

  NotificationCenter get _notifications =>
      widget.notifications ?? NotificationCenter.instance;

  /// The screen's data and the bell's unread count together (Issue #291):
  /// a refresh the student asks for should not leave the badge stale.
  Future<void> _refresh() async {
    await Future.wait([_controller.load(), _notifications.load()]);
  }

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
      value: AppSystemUi.page(context, navigationBar: context.palette.surface),
      child: Scaffold(
        backgroundColor: context.palette.surfaceSubtle,
        bottomNavigationBar: widget.showBottomNav
            ? const AdultBottomNav(current: StudentTab.home)
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // White behind the status bar, as every frame draws it, rather
            // than the page's grey.
            ColoredBox(
              color: context.palette.surface,
              child: SizedBox(height: MediaQuery.paddingOf(context).top),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: SafeArea(
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
                            HomeHeader(
                              onLogoTap: _refreshFromLogo,
                              notifications: widget.notifications,
                            ),
                            Container(
                              height: AppDimens.borderWidth,
                              color: context.palette.divider,
                            ),
                            Expanded(child: _buildBody()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
      clock: widget.clock,
      onRefresh: _refresh,
      refreshIndicatorKey: _refreshIndicator,
      showPaymentPreview: widget.showPaymentPreview,
      contractRepository: widget.contractRepository,
    );
  }
}

/// The dashboard itself, once there is something to show.
class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.dashboard,
    required this.now,
    required this.clock,
    required this.onRefresh,
    required this.refreshIndicatorKey,
    required this.showPaymentPreview,
    required this.contractRepository,
  });

  final HomeDashboard dashboard;
  final ContractRepository? contractRepository;
  final DateTime now;

  /// [HomeScreen.clock], passed on to the attendance screen so its calendar
  /// opens on the same "today" the dashboard used.
  final DateTime Function()? clock;
  final Future<void> Function() onRefresh;

  /// Lets the header logo start this view's pull-to-refresh.
  final GlobalKey<RefreshIndicatorState> refreshIndicatorKey;
  final bool showPaymentPreview;

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
      // An unsigned contract the API reported (Issue #300) — the banner
      // opens the E-Contract screen, as the Profile row does.
      if (contract != null && !contract.signed)
        ContractBanner(
          onTap: () =>
              ContractScreen.open(context, repository: contractRepository),
        ),
      ..._statRows(
        dashboard.stats,
        noDestinationYet,
        // "Дэлгэрэнгүй" on the attendance card: the attendance screen, drawn
        // from the figures this dashboard already loaded (Issue #172).
        (attendance) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AttendanceDetailScreen(
              attendance: attendance,
              schedule: program?.schedule,
              nextLesson: program?.nextLesson,
              clock: clock,
            ),
          ),
        ),
        // The payment card: the Payment screen on its temporary fixtures,
        // outside release builds only (Issue #196).
        showPaymentPreview
            ? (payment) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => paymentPreviewFor(overdue: payment.isOverdue),
                ),
              )
            : null,
      ),
    ];

    return RefreshIndicator(
      key: refreshIndicatorKey,
      onRefresh: onRefresh,
      color: context.palette.primary,
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
    void Function(AttendanceSummary attendance) openAttendance,
    void Function(PaymentStatus payment)? openPayment,
  ) {
    Widget card(HomeStat stat) => switch (stat) {
      PaymentStat(:final payment, :final layout) => PaymentCard(
        payment: payment,
        layout: layout,
        // The card keeps its own rule for the pay action: live only while
        // overdue, muted otherwise.
        onPay: openPayment == null
            ? noDestinationYet
            : () => openPayment(payment),
        onDetails: openPayment == null
            ? noDestinationYet
            : () => openPayment(payment),
      ),
      AttendanceStat(:final attendance, :final layout) => AttendanceCard(
        attendance: attendance,
        layout: layout,
        onDetails: () => openAttendance(attendance),
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
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: context.palette.primary,
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
          style: AppTypography.cardSupporting.copyWith(
            color: context.palette.textSecondary,
          ),
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
              style: AppTypography.cardSupporting.copyWith(
                color: context.palette.textSecondary,
              ),
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
