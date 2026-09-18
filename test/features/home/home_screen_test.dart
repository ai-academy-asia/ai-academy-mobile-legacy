import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/attendance_card.dart';
import 'package:aia_mobile/features/home/presentation/widgets/contract_banner.dart';
import 'package:aia_mobile/features/home/presentation/widgets/payment_card.dart';
import 'package:aia_mobile/features/home/presentation/widgets/program_card.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_home_dashboard_repository.dart';

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
        ),
        routes: routes,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// State A — a scheduled lesson, progress, and both statistic cards.
  HomeDashboard scheduledDashboard() => HomeDashboard(
    program: sampleProgram(
      progress: const ModuleProgress(completed: 2, total: 5),
      nextLesson: sampleLesson(start: lessonStart),
    ),
    payment: const PaymentStatus.dueIn(3),
    attendance: const AttendanceSummary(attended: 1, total: 20),
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

    testWidgets('shows the next lesson window', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
      );

      expect(find.text(HomeStrings.nextLesson), findsOneWidget);
      expect(find.text('08/04 • 09:00 – 11:00'), findsOneWidget);
    });
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

      final pay = tester.widget<AppButton>(
        find.widgetWithText(AppButton, HomeStrings.payAction),
      );
      expect(pay.onPressed, isNull);
    });

    testWidgets('turns the pay action on once it is overdue', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(),
            payment: const PaymentStatus.overdue(),
          ),
        ),
      );

      expect(find.text(HomeStrings.paymentOverdue), findsOneWidget);

      final pay = tester.widget<AppButton>(
        find.widgetWithText(AppButton, HomeStrings.payAction),
      );
      expect(pay.onPressed, isNotNull);
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
      expect(find.text('1/20 · 5%'), findsOneWidget);
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
    });

    testWidgets('the courses tab opens the catalog route', (tester) async {
      await pumpHome(
        tester,
        FakeHomeDashboardRepository(dashboard: scheduledDashboard()),
        routes: {
          '/courses': (_) => const Scaffold(body: Text('courses route')),
        },
      );

      await tester.tap(find.text(HomeStrings.navCourses));
      await tester.pumpAndSettle();

      expect(find.text('courses route'), findsOneWidget);
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
}
