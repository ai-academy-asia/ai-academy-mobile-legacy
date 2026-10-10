import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/home/domain/lesson_schedule.dart';
import 'package:aia_mobile/features/home/presentation/attendance_detail_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/payment_screen.dart';
import 'package:aia_mobile/features/home/presentation/payment_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/attendance_card.dart';
import 'package:aia_mobile/features/home/presentation/widgets/contract_banner.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_pill_button.dart';
import 'package:aia_mobile/features/home/presentation/widgets/payment_card.dart';
import 'package:aia_mobile/features/home/presentation/widgets/program_card.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_header.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_home_dashboard_repository.dart';
import '../contracts/fake_contract_repository.dart';
import '../notifications/fake_notification_repository.dart';

/// Loads the real Manrope face, the same reason the other screen tests do —
/// without it, text is measured in the fallback font.
Future<void> _loadFonts() async {
  final loader = FontLoader('Manrope')
    ..addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'));
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  /// The control's own `Semantics`, found by the label it sets rather than by
  /// walking ancestors — `Material` and `InkWell` put their own between the
  /// label and the wrapper under test.
  Semantics semanticsLabelled(WidgetTester tester, String label) =>
      tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        ),
      );

  /// The lesson every state below is built around: 2026-04-08, 09:00–11:00 —
  /// the window the reference frames show.
  final lessonStart = DateTime(2026, 4, 8, 9);
  final beforeLesson = DateTime(2026, 4, 8, 8);
  final duringLesson = DateTime(2026, 4, 8, 10);

  Future<void> pumpHome(
    WidgetTester tester,
    FakeHomeDashboardRepository repository, {
    DateTime? now,
    Size size = const Size(393, 852),
    Map<String, WidgetBuilder> routes = const {},
    bool showPaymentPreview = true,
    NotificationCenter? notifications,
    FakeContractRepository? contracts,
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          repository: repository,
          clock: () => now ?? beforeLesson,
          showPaymentPreview: showPaymentPreview,
          notifications: notifications,
          contractRepository: contracts,
        ),
        routes: routes,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// State A — a scheduled lesson, progress, and both statistic cards.
  HomeDashboard scheduledDashboard() => HomeDashboard(
    program: sampleProgram(
      progress: const ModuleProgress(percent: 40, completed: 2, total: 5),
      nextLesson: sampleLesson(start: lessonStart),
    ),
    stats: const [
      PaymentStat(PaymentStatus.dueIn(3), layout: HomeStatLayout.tile),
      AttendanceStat(
        AttendanceSummary(attended: 1, total: 20),
        layout: HomeStatLayout.tile,
      ),
    ],
  );

  group('cohort card', () {
    testWidgets('shows the cohort, its course and its status', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
      );

      expect(find.byType(ProgramCard), findsOneWidget);
      expect(find.text('Cohort 01'), findsOneWidget);
      expect(find.text('AI Engineer'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Adult'), findsOneWidget);
    });

    testWidgets(
      'labels the badge with the account\'s ui mode, not a fixed one',
      (tester) async {
        await pumpHome(
          tester,
          FakeHomeDashboardRepository(
            dashboard: HomeDashboard(program: sampleProgram(uiMode: 'kids')),
          ),
        );

        expect(find.text('Kids'), findsOneWidget);
        expect(find.text('Adult'), findsNothing);
      },
    );

    Finder glyph(String asset) => find.byWidgetPredicate(
      (widget) =>
          widget is SvgPicture &&
          widget.bytesLoader is SvgAssetLoader &&
          (widget.bytesLoader as SvgAssetLoader).assetName == asset,
    );

    testWidgets('draws the junior mark for a younger ui mode', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(program: sampleProgram(uiMode: 'kids')),
        ),
      );

      expect(glyph(HomeIcons.junior), findsOneWidget);
      expect(glyph(HomeIcons.adult), findsNothing);
    });

    testWidgets('draws the adult mark for any other ui mode', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(program: sampleProgram(uiMode: 'adult')),
        ),
      );

      expect(glyph(HomeIcons.adult), findsOneWidget);
      expect(glyph(HomeIcons.junior), findsNothing);
    });

    testWidgets('leaves the badge off when there is no ui mode', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(program: sampleProgram(uiMode: null)),
        ),
      );

      expect(find.byType(ProgramCard), findsOneWidget);
      expect(find.text('Adult'), findsNothing);
      expect(find.text('Kids'), findsNothing);
      expect(find.text('AI Engineer'), findsOneWidget);
    });

    testWidgets('shows module progress and fills the bar to match', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
      );

      expect(find.text(HomeStrings.modules(2, 5)), findsOneWidget);
      expect(find.text(HomeStrings.percentComplete(40)), findsOneWidget);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.4);
    });

    testWidgets('leaves progress off entirely when there is none', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(
              nextLesson: sampleLesson(start: lessonStart),
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('complete'), findsNothing);
    });

    testWidgets(
      'shows just the percentage and the bar when there is no module count',
      (tester) async {
        // `Enrollment.progressPct` — the one real progress figure the API
        // confirms — is a bare percentage, with no module count behind it.
        await pumpHome(
          tester,
          FakeHomeDashboardRepository(
            dashboard: HomeDashboard(
              program: sampleProgram(
                progress: const ModuleProgress(percent: 62),
                nextLesson: sampleLesson(start: lessonStart),
              ),
            ),
          ),
        );

        expect(find.text(HomeStrings.percentComplete(62)), findsOneWidget);
        // No count to report — the "Modules X of Y" line stays off rather
        // than showing an invented one.
        expect(find.textContaining('Modules'), findsNothing);

        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(bar.value, 0.62);
      },
    );

    testWidgets('shows the next lesson window', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
      );

      expect(find.text(HomeStrings.nextLesson), findsOneWidget);
      expect(find.text('08/04 • 09:00 – 11:00'), findsOneWidget);
    });
  });

  group('course navigation', () {
    testWidgets(
      'tapping the programme card opens Course Module List directly',
      (tester) async {
        // The Figma flow has no Course Detail step between a Home course
        // card and Module List.
        await pumpHome(
          tester,
          FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
        );

        await tester.tap(find.byType(ProgramCard));
        await tester.pumpAndSettle();

        final moduleList = tester.widget<CourseModuleListScreen>(
          find.byType(CourseModuleListScreen),
        );
        expect(moduleList.courseSlug, 'ai-engineer');
      },
    );
  });

  group('attendance action', () {
    testWidgets('is flat before the lesson starts, with no Live badge', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
        now: beforeLesson,
      );

      expect(find.text(HomeStrings.live), findsNothing);
      expect(find.text(HomeStrings.liveHint), findsNothing);

      final action = semanticsLabelled(tester, HomeStrings.attendanceAction);
      expect(action.properties.enabled, isFalse);
    });

    testWidgets('goes live while the lesson is under way', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
        now: duringLesson,
      );

      expect(find.text(HomeStrings.live), findsOneWidget);
      expect(find.text(HomeStrings.liveHint), findsOneWidget);

      final action = semanticsLabelled(tester, HomeStrings.attendanceAction);
      expect(action.properties.enabled, isTrue);
    });
  });

  group('contract warning', () {
    testWidgets('warns while the contract is unsigned', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(),
            contract: const ContractStatus(signed: false),
          ),
        ),
      );

      expect(find.byType(ContractBanner), findsOneWidget);
      expect(find.text(HomeStrings.contractTitle), findsOneWidget);
    });

    testWidgets('tapping it opens the E-Contract screen (Issue #300)', (
      tester,
    ) async {
      final contracts = FakeContractRepository();
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(),
            contract: const ContractStatus(signed: false),
          ),
        ),
        contracts: contracts,
      );

      await tester.tap(find.byType(ContractBanner));
      await tester.pumpAndSettle();

      expect(find.byType(ContractScreen), findsOneWidget);
      expect(contracts.callCount, 1);
      expect(find.text(ContractStrings.empty), findsOneWidget);
    });

    testWidgets('says nothing once it is signed', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(),
            contract: const ContractStatus(signed: true),
          ),
        ),
      );

      expect(find.byType(ContractBanner), findsNothing);
    });
  });

  group('payment', () {
    testWidgets('counts down, with the pay action flat, while it is due', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
      );

      expect(find.byType(PaymentCard), findsOneWidget);
      expect(find.text(HomeStrings.paymentDueIn(3)), findsOneWidget);

      final pay = tester.widget<HomePillButton>(
        find.widgetWithText(HomePillButton, HomeStrings.payAction),
      );
      expect(pay.onPressed, isNull);
    });

    testWidgets('turns the pay action on once it is overdue', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(),
            stats: const [
              PaymentStat(PaymentStatus.overdue(), layout: HomeStatLayout.tile),
            ],
          ),
        ),
      );

      expect(find.text(HomeStrings.paymentOverdue), findsOneWidget);

      final pay = tester.widget<HomePillButton>(
        find.widgetWithText(HomePillButton, HomeStrings.payAction),
      );
      expect(pay.onPressed, isNotNull);
    });

    testWidgets('as a row, offers details instead of the pay action', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(),
            stats: const [
              PaymentStat(PaymentStatus.dueIn(3), layout: HomeStatLayout.row),
            ],
          ),
        ),
      );

      expect(find.text(HomeStrings.paymentDueIn(3)), findsOneWidget);
      expect(find.text(HomeStrings.payAction), findsNothing);
      expect(
        find.widgetWithText(HomePillButton, HomeStrings.details),
        findsOneWidget,
      );
    });
  });

  group('payment card → Payment screen (Issue #196)', () {
    FakeHomeDashboardRepository withPayment(PaymentStat stat) =>
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(program: sampleProgram(), stats: [stat]),
        );

    const dueRow = PaymentStat(
      PaymentStatus.dueIn(3),
      layout: HomeStatLayout.row,
    );
    const overdueTile = PaymentStat(
      PaymentStatus.overdue(),
      layout: HomeStatLayout.tile,
    );
    const dueTile = PaymentStat(
      PaymentStatus.dueIn(3),
      layout: HomeStatLayout.tile,
    );

    Finder detailsButton() =>
        find.widgetWithText(HomePillButton, HomeStrings.details);
    Finder payButton() =>
        find.widgetWithText(HomePillButton, HomeStrings.payAction);

    testWidgets('"Дэлгэрэнгүй" opens the partly-paid preview', (tester) async {
      await pumpHome(tester, withPayment(dueRow));

      await tester.tap(detailsButton());
      await tester.pumpAndSettle();

      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text(PaymentStrings.dueIn(3)), findsOneWidget);
      expect(find.text(PaymentStrings.overdue), findsNothing);
    });

    testWidgets('the overdue tile\'s live pay action opens the overdue '
        'preview', (tester) async {
      await pumpHome(tester, withPayment(overdueTile));

      await tester.tap(payButton());
      await tester.pumpAndSettle();

      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.text(PaymentStrings.overdue), findsOneWidget);
    });

    testWidgets('a due tile keeps its pay action muted', (tester) async {
      await pumpHome(tester, withPayment(dueTile));

      expect(tester.widget<HomePillButton>(payButton()).onPressed, isNull);
    });

    testWidgets('with previews off (release builds) "Дэлгэрэнгүй" opens '
        'nothing', (tester) async {
      await pumpHome(tester, withPayment(dueRow), showPaymentPreview: false);

      await tester.tap(detailsButton());
      await tester.pumpAndSettle();

      expect(find.byType(PaymentScreen), findsNothing);
    });

    testWidgets('with previews off (release builds) the overdue pay action '
        'stays live but opens nothing', (tester) async {
      await pumpHome(
        tester,
        withPayment(overdueTile),
        showPaymentPreview: false,
      );

      expect(tester.widget<HomePillButton>(payButton()).onPressed, isNotNull);
      await tester.tap(payButton());
      await tester.pumpAndSettle();

      expect(find.byType(PaymentScreen), findsNothing);
    });

    test('previews follow the build: on unless this is a release build', () {
      expect(const HomeScreen().showPaymentPreview, !kReleaseMode);
    });
  });

  group('attendance card', () {
    testWidgets('shows the tally and its percentage', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
      );

      expect(find.byType(AttendanceCard), findsOneWidget);
      expect(find.text(HomeStrings.attendanceLabel), findsOneWidget);
      // The reference prints "1/20 · 10%", which does not add up — 1 of 20 is
      // 5%. The percentage is computed from the tally rather than carried
      // alongside it, so it cannot drift from the figure beside it.
      expect(find.text('1/20  · 5%'), findsOneWidget);
    });

    Finder attendanceDetails() => find.descendant(
      of: find.byType(AttendanceCard),
      matching: find.text(HomeStrings.details),
    );

    for (final layout in HomeStatLayout.values) {
      testWidgets(
        '"Дэлгэрэнгүй" opens the attendance screen (${layout.name})',
        (tester) async {
          const schedule = LessonSchedule(
            weekdays: {DateTime.wednesday},
            start: (9, 0),
            end: (11, 0),
          );
          final lesson = sampleLesson(start: lessonStart);
          final attendance = AttendanceSummary(
            attended: 8,
            total: 9,
            percent: 88,
            attendedDates: {DateTime(2026, 4, 1)},
            missedDates: {DateTime(2026, 3, 25)},
          );
          await pumpHome(
            tester,
            FakeHomeDashboardRepository(
              dashboard: HomeDashboard(
                program: sampleProgram(schedule: schedule, nextLesson: lesson),
                stats: [AttendanceStat(attendance, layout: layout)],
              ),
            ),
          );

          await tester.ensureVisible(attendanceDetails());
          await tester.tap(attendanceDetails());
          await tester.pumpAndSettle();

          // The dashboard's own figures, handed over — nothing re-fetched.
          final screen = tester.widget<AttendanceDetailScreen>(
            find.byType(AttendanceDetailScreen),
          );
          expect(screen.attendance, same(attendance));
          expect(screen.schedule, same(schedule));
          expect(screen.nextLesson, same(lesson));
          expect(find.text('8/9 · 88%'), findsOneWidget);
        },
      );
    }
  });

  group('statistic layout', () {
    testWidgets('pairs tiles side by side and stacks rows full width', (
      tester,
    ) async {
      // The contract frame: an overdue tile beside the attendance tile, and
      // the upcoming instalment as a row under them.
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(),
            stats: const [
              PaymentStat(PaymentStatus.overdue(), layout: HomeStatLayout.tile),
              AttendanceStat(
                AttendanceSummary(attended: 1, total: 20),
                layout: HomeStatLayout.tile,
              ),
              PaymentStat(PaymentStatus.dueIn(3), layout: HomeStatLayout.row),
            ],
          ),
        ),
        size: const Size(393, 1073),
      );

      final overdue = tester.getRect(find.byType(PaymentCard).first);
      final attendance = tester.getRect(find.byType(AttendanceCard));
      final row = tester.getRect(find.byType(PaymentCard).last);

      expect(overdue.top, attendance.top);
      expect(overdue.width, attendance.width);
      expect(attendance.left - overdue.right, 8);
      expect(row.width, 393 - 2 * 16);
      expect(row.top, greaterThan(overdue.bottom));
    });
  });

  group('sections with no data', () {
    testWidgets('draws only the sections the dashboard actually carries', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(program: sampleProgram()),
        ),
      );

      expect(find.byType(ProgramCard), findsOneWidget);
      expect(find.byType(ContractBanner), findsNothing);
      expect(find.byType(PaymentCard), findsNothing);
      expect(find.byType(AttendanceCard), findsNothing);
    });

    testWidgets('renders the verified adult test account\'s all-zero data', (
      tester,
    ) async {
      // What `EnrolledHomeDashboardRepository` builds from that account's
      // real responses: one incomplete module at 0%, nothing owed (so no
      // payment card), and no sessions held yet.
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(
              progress: const ModuleProgress(
                percent: 0,
                completed: 0,
                total: 1,
              ),
            ),
            stats: const [
              AttendanceStat(
                AttendanceSummary(attended: 0, total: 0, percent: 0),
                layout: HomeStatLayout.row,
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(HomeStrings.modules(0, 1)), findsOneWidget);
      expect(find.text(HomeStrings.percentComplete(0)), findsOneWidget);
      expect(find.text(HomeStrings.attendanceValue(0, 0, 0)), findsOneWidget);
      expect(find.byType(PaymentCard), findsNothing);
      expect(find.byType(ContractBanner), findsNothing);
    });
  });

  group('states', () {
    testWidgets('shows a spinner while the first load is in flight', (
      tester,
    ) async {
      final repository = FakeHomeDashboardRepository(hold: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(repository: repository),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ProgramCard), findsNothing);

      repository.release();
      await tester.pumpAndSettle();
    });

    testWidgets('tells the student when they are enrolled in nothing', (
      tester,
    ) async {
      await pumpHome(tester, FakeHomeDashboardRepository());

      expect(find.text(HomeStrings.empty), findsOneWidget);
      expect(find.byType(ProgramCard), findsNothing);
    });

    testWidgets('surfaces a failure, and retries on demand', (tester) async {
      final repository = FakeHomeDashboardRepository(
        failure: const HomeFailure(HomeFailureKind.network),
      );
      await pumpHome(tester, repository);

      expect(find.text(HomeStrings.networkError), findsOneWidget);

      repository.failure = null;
      repository.dashboard = scheduledDashboard();
      await tester.tap(find.widgetWithText(AppButton, HomeStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
      expect(find.byType(ProgramCard), findsOneWidget);
    });

    testWidgets('pull to refresh asks again', (tester) async {
      final repository = FakeHomeDashboardRepository(
        dashboard: scheduledDashboard(),
      );
      await pumpHome(tester, repository);

      await tester.fling(find.byType(ProgramCard), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
    });

    testWidgets('pull to refresh refreshes the bell\'s unread count too '
        '(Issue #291)', (tester) async {
      final notifications = FakeNotificationRepository();
      final center = NotificationCenter(repository: notifications);
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
        notifications: center,
      );
      expect(notifications.feedCalls, 1);
      expect(find.byKey(HomeHeader.unreadBadgeKey), findsNothing);

      notifications.notifications = [sampleNotification()];
      await tester.fling(find.byType(ProgramCard), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(notifications.feedCalls, 2);
      expect(center.unreadCount, 1);
      expect(find.byKey(HomeHeader.unreadBadgeKey), findsOneWidget);
    });
  });

  group('bottom navigation', () {
    testWidgets('marks the home tab as the current one', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
      );

      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, 0);
      expect(nav.items.map((item) => item.label), [
        HomeStrings.navHome,
        HomeStrings.navCourses,
        HomeStrings.navProfile,
      ]);

      // The shared adult bar, unmodified — the geometry is the same on every
      // adult tab screen (Issue #188).
      const shared = AppBottomNav(items: [], currentIndex: 0);
      expect(nav.iconSize, shared.iconSize);
      expect(nav.labelSize, shared.labelSize);
      expect(nav.horizontalPadding, shared.horizontalPadding);
      expect(nav.selectedColor, shared.selectedColor);
    });

    testWidgets('the courses tab opens the student\'s cohort list directly', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
        routes: {
          '/my-cohorts': (_) => const Scaffold(body: Text('my cohorts route')),
          // Must not be reached: the draft catalog is out of this flow.
          '/courses': (_) => const Scaffold(body: Text('courses route')),
        },
      );

      await tester.tap(find.text(HomeStrings.navCourses));
      await tester.pumpAndSettle();

      expect(find.text('my cohorts route'), findsOneWidget);
      expect(find.text('courses route'), findsNothing);
    });

    testWidgets('the profile tab opens the profile route', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
        routes: {
          '/profile': (_) => const Scaffold(body: Text('profile route')),
        },
      );

      await tester.tap(find.text(HomeStrings.navProfile));
      await tester.pumpAndSettle();

      expect(find.text('profile route'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('keeps a phone-width column on a desktop window', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
        size: const Size(1200, 900),
      );

      expect(
        tester.getRect(find.byType(ProgramCard)).width,
        lessThanOrEqualTo(480 - 2 * 16),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a short viewport', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
        size: const Size(393, 420),
      );

      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('header logo refresh (Issue #221)', () {
    Finder logo() => find.bySemanticsLabel(HomeStrings.logo);

    testWidgets('a tap runs the dashboard\'s pull-to-refresh: the same '
        'repository, its indicator, and Home stays', (tester) async {
      final repository = FakeHomeDashboardRepository(
        dashboard: scheduledDashboard(),
      );
      await pumpHome(tester, repository);
      expect(repository.callCount, 1);

      repository.hold = true;
      await tester.tap(logo());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.callCount, 2);
      // RefreshIndicator's own spinner — the one a pull shows.
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      // The dashboard stays on screen while it refreshes.
      expect(find.byType(ProgramCard), findsOneWidget);

      repository.release();
      await tester.pumpAndSettle();
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('taps during a refresh do not send more requests', (
      tester,
    ) async {
      final repository = FakeHomeDashboardRepository(
        dashboard: scheduledDashboard(),
      );
      await pumpHome(tester, repository);

      repository.hold = true;
      await tester.tap(logo());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(logo());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(logo());
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.callCount, 2);

      repository.release();
      await tester.pumpAndSettle();
      expect(repository.callCount, 2);
    });

    testWidgets('a successful refresh shows the latest data', (tester) async {
      final repository = FakeHomeDashboardRepository(
        dashboard: scheduledDashboard(),
      );
      await pumpHome(tester, repository);
      expect(find.text('AI Engineer'), findsOneWidget);

      repository.dashboard = HomeDashboard(
        program: sampleProgram(courseTitle: 'Data Analyst'),
      );
      await tester.tap(logo());
      await tester.pumpAndSettle();

      expect(find.text('Data Analyst'), findsOneWidget);
      expect(find.text('AI Engineer'), findsNothing);
    });

    testWidgets('a failed refresh shows the existing error view and retry', (
      tester,
    ) async {
      final repository = FakeHomeDashboardRepository(
        dashboard: scheduledDashboard(),
      );
      await pumpHome(tester, repository);

      repository.failure = const HomeFailure(HomeFailureKind.network);
      await tester.tap(logo());
      await tester.pumpAndSettle();

      expect(
        find.text(HomeStrings.messageFor(HomeFailureKind.network)),
        findsOneWidget,
      );
      expect(find.text(HomeStrings.retry), findsOneWidget);
    });

    testWidgets('with no dashboard on screen — after a failure — a tap '
        'reloads through the same load', (tester) async {
      final repository = FakeHomeDashboardRepository(
        failure: const HomeFailure(HomeFailureKind.server),
      );
      await pumpHome(tester, repository);
      expect(find.text(HomeStrings.retry), findsOneWidget);

      repository
        ..failure = null
        ..dashboard = scheduledDashboard();
      await tester.tap(logo());
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
      expect(find.byType(ProgramCard), findsOneWidget);
      expect(find.text(HomeStrings.retry), findsNothing);
    });
  });
}
