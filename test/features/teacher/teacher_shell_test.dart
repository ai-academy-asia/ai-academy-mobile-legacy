import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_class_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_student_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_submission_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_shell.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_bottom_nav.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_class_card.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_session_sheet.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_tabs.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_teacher_gradebook_repository.dart';
import 'fake_teacher_home_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_gradebook_screen_test.dart' show classRepository;
import 'teacher_home_screen_test.dart' show sampleClass, tuesday;
import 'teacher_schedule_screen_test.dart' show upcomingLabel, weekRepository;

/// The Teacher tabs as one persistent shell (Issue #241): one bar, owned by
/// the shell, that never moves or is rebuilt as a route while the content
/// above it switches. Профайл has no screen and stays inert.
void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late FakeTeacherHomeRepository home;
  late FakeTeacherScheduleRepository schedule;
  late FakeTeacherGradebookRepository grades;

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    TeacherTab initialTab = TeacherTab.home,
  }) async {
    tallView(tester);
    navigatorKey = GlobalKey<NavigatorState>();
    home = FakeTeacherHomeRepository(classes: [sampleClass()]);
    schedule = weekRepository();
    grades = classRepository();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light,
        initialRoute: HomeRoutes.teacher,
        routes: {
          HomeRoutes.teacher: (_) => TeacherShell(
            initialTab: initialTab,
            home: TeacherHomeScreen(
              repository: home,
              clock: tuesday,
              showBottomNav: false,
            ),
            schedule: TeacherScheduleScreen(
              repository: schedule,
              clock: tuesday,
              showBottomNav: false,
            ),
            grades: TeacherGradebookScreen(
              repository: grades,
              showBottomNav: false,
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedTab(WidgetTester tester) =>
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex;

  Finder barLabel(String label) => find.descendant(
    of: find.byType(AppBottomNav),
    matching: find.text(label),
  );

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(barLabel(label));
    await tester.pumpAndSettle();
  }

  /// Exactly one of the three teacher tab screens is on display: [type].
  void expectShowing(Type type) {
    for (final screen in [
      TeacherHomeScreen,
      TeacherScheduleScreen,
      TeacherGradebookScreen,
    ]) {
      expect(
        find.byType(screen),
        screen == type ? findsOneWidget : findsNothing,
        reason: '$screen',
      );
    }
  }

  testWidgets('starts on Нүүр, with Нүүр selected', (tester) async {
    await pumpShell(tester);

    expectShowing(TeacherHomeScreen);
    expect(selectedTab(tester), TeacherTab.home.index);
  });

  testWidgets('keeps Нүүр, Хуваарь, Дүнгийн хуудас, Профайл in that order', (
    tester,
  ) async {
    await pumpShell(tester);

    final xs = [
      for (final label in [
        TeacherHomeStrings.navHome,
        TeacherHomeStrings.navSchedule,
        TeacherHomeStrings.navGrades,
        TeacherHomeStrings.navProfile,
      ])
        tester.getCenter(barLabel(label)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).items,
      hasLength(4),
    );
  });

  testWidgets('each tab selects itself and shows its own content', (
    tester,
  ) async {
    await pumpShell(tester);

    await tapTab(tester, TeacherHomeStrings.navSchedule);
    expectShowing(TeacherScheduleScreen);
    expect(selectedTab(tester), TeacherTab.schedule.index);

    await tapTab(tester, TeacherHomeStrings.navGrades);
    expectShowing(TeacherGradebookScreen);
    expect(selectedTab(tester), TeacherTab.grades.index);

    await tapTab(tester, TeacherHomeStrings.navHome);
    expectShowing(TeacherHomeScreen);
    expect(selectedTab(tester), TeacherTab.home.index);

    await tapTab(tester, TeacherHomeStrings.navGrades);
    await tapTab(tester, TeacherHomeStrings.navSchedule);
    expectShowing(TeacherScheduleScreen);
    expect(selectedTab(tester), TeacherTab.schedule.index);
  });

  testWidgets('Профайл stays inert: nothing opens, nothing is selected', (
    tester,
  ) async {
    await pumpShell(tester);

    for (final label in [
      TeacherHomeStrings.navHome,
      TeacherHomeStrings.navSchedule,
      TeacherHomeStrings.navGrades,
    ]) {
      await tapTab(tester, label);
      final before = selectedTab(tester);
      await tapTab(tester, TeacherHomeStrings.navProfile);

      expect(selectedTab(tester), before, reason: 'from $label');
      expect(navigatorKey.currentState!.canPop(), isFalse);
    }
  });

  testWidgets('the bar belongs to the shell, not to a tab screen', (
    tester,
  ) async {
    await pumpShell(tester);
    await tapTab(tester, TeacherHomeStrings.navSchedule);
    await tapTab(tester, TeacherHomeStrings.navGrades);

    expect(find.byType(TeacherBottomNav), findsOneWidget);
    for (final screen in [
      TeacherHomeScreen,
      TeacherScheduleScreen,
      TeacherGradebookScreen,
    ]) {
      expect(
        find.descendant(
          of: find.byType(screen, skipOffstage: false),
          matching: find.byType(AppBottomNav, skipOffstage: false),
        ),
        findsNothing,
        reason: '$screen draws no bar of its own',
      );
    }
  });

  testWidgets('switching tabs is not navigation: no route, no transition, '
      'one bar that never moves or is rebuilt', (tester) async {
    await pumpShell(tester);
    final bar = tester.element(find.byType(AppBottomNav));
    final rect = tester.getRect(find.byType(AppBottomNav));

    for (final label in [
      TeacherHomeStrings.navSchedule,
      TeacherHomeStrings.navGrades,
      TeacherHomeStrings.navProfile,
      TeacherHomeStrings.navHome,
      TeacherHomeStrings.navGrades,
      TeacherHomeStrings.navSchedule,
      TeacherHomeStrings.navHome,
    ]) {
      await tester.tap(barLabel(label));
      // One frame: a page transition would still be running here, with the
      // old page — and its bar — on screen beside the new one.
      await tester.pump();

      expect(find.byType(AppBottomNav), findsOneWidget, reason: label);
      expect(tester.getRect(find.byType(AppBottomNav)), rect, reason: label);
      expect(
        identical(tester.element(find.byType(AppBottomNav)), bar),
        isTrue,
        reason: 'the bar is the same element after $label',
      );
      expect(navigatorKey.currentState!.canPop(), isFalse, reason: label);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the bar sits exactly where each screen drew its own', (
    tester,
  ) async {
    await pumpShell(tester);
    final inShell = tester.getRect(find.byType(AppBottomNav));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TeacherHomeScreen(
          repository: FakeTeacherHomeRepository(classes: [sampleClass()]),
          clock: tuesday,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(AppBottomNav)), inShell);
  });

  testWidgets('only the opened tabs are built, and each keeps its state', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(
      find.byType(TeacherScheduleScreen, skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byType(TeacherGradebookScreen, skipOffstage: false),
      findsNothing,
    );
    final homeState = tester.state(find.byType(TeacherHomeScreen));

    await tapTab(tester, TeacherHomeStrings.navSchedule);
    final scheduleState = tester.state(find.byType(TeacherScheduleScreen));
    await tapTab(tester, TeacherHomeStrings.navGrades);
    await tapTab(tester, TeacherHomeStrings.navHome);
    await tapTab(tester, TeacherHomeStrings.navSchedule);
    await tapTab(tester, TeacherHomeStrings.navGrades);
    await tapTab(tester, TeacherHomeStrings.navHome);

    expect(
      identical(tester.state(find.byType(TeacherHomeScreen)), homeState),
      isTrue,
    );
    expect(home.callCount, 1, reason: 'Нүүр is not reloaded on return');
    expect(schedule.sessionCalls, hasLength(1), reason: 'nor is Хуваарь');
    expect(grades.classCalls, 1, reason: 'nor is Дүнгийн хуудас');
    await tapTab(tester, TeacherHomeStrings.navSchedule);
    expect(
      identical(
        tester.state(find.byType(TeacherScheduleScreen)),
        scheduleState,
      ),
      isTrue,
    );
  });

  testWidgets('system back on another tab returns to Нүүр, and does not '
      'leave the shell', (tester) async {
    await pumpShell(tester);

    for (final label in [
      TeacherHomeStrings.navSchedule,
      TeacherHomeStrings.navGrades,
    ]) {
      await tapTab(tester, label);
      await navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expectShowing(TeacherHomeScreen);
      expect(selectedTab(tester), TeacherTab.home.index);
      expect(find.byType(TeacherShell), findsOneWidget);
    }
  });

  testWidgets('opens on the tab its route names', (tester) async {
    for (final tab in [TeacherTab.schedule, TeacherTab.grades]) {
      await pumpShell(tester, initialTab: tab);

      expect(selectedTab(tester), tab.index);
      expect(find.byType(TeacherHomeScreen, skipOffstage: false), findsNothing);
    }
  });

  testWidgets('Хуваарь: a session sheet and its "Цаг солих" screen still open '
      'over the shell, and back out to Хуваарь', (tester) async {
    await pumpShell(tester);
    await tapTab(tester, TeacherHomeStrings.navSchedule);

    await tester.tap(find.bySemanticsLabel(upcomingLabel));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherSessionSheet), findsOneWidget);

    await tester.tap(find.text(TeacherScheduleStrings.changeTime));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherRequestScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    navigatorKey.currentState!.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    expectShowing(TeacherScheduleScreen);
    expect(selectedTab(tester), TeacherTab.schedule.index);
  });

  testWidgets('Дүнгийн хуудас: class, student and submission still open over '
      'the shell, and back out to Дүнгийн хуудас', (tester) async {
    await pumpShell(tester);
    await tapTab(tester, TeacherHomeStrings.navGrades);

    await tester.tap(find.byType(TeacherClassCard));
    await tester.pumpAndSettle();
    expect(find.byType(GradebookClassScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    await tester.tap(find.bySemanticsLabel('Student A, Даалгавар 2'));
    await tester.pumpAndSettle();
    expect(find.byType(GradebookStudentScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Student A, Assignment 3'));
    await tester.pumpAndSettle();
    expect(find.byType(GradebookSubmissionScreen), findsOneWidget);
    expect(grades.submissionCalls, [30]);

    for (var i = 0; i < 3; i++) {
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }
    expectShowing(TeacherGradebookScreen);
    expect(selectedTab(tester), TeacherTab.grades.index);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });
}
