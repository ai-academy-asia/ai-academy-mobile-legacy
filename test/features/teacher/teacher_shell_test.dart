import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_class_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/gradebook_student_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_shell.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_bottom_nav.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_session_sheet.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_tabs.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/program_widgets.dart';
import 'package:aia_mobile/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/fake_current_user_repository.dart';
import 'fake_teacher_gradebook_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_gradebook_screen_test.dart' show classRepository;
import 'teacher_home_screen_test.dart' show tuesday;
import 'teacher_schedule_screen_test.dart' show upcomingLabel, weekRepository;

/// The Teacher tabs as one persistent shell (Issue #241): one bar, owned by
/// the shell, that never moves or is rebuilt as a route while the content
/// above it switches. Профайл is the Teacher Profile (Issue #243). Three
/// tabs since Issue #370 — Хуваарь, Дүнгийн хуудас, Профайл — with Хуваарь
/// first and the default.
void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late FakeTeacherScheduleRepository schedule;
  late FakeTeacherGradebookRepository grades;

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpShell(
    WidgetTester tester, {
    TeacherTab initialTab = TeacherTab.schedule,
  }) async {
    tallView(tester);
    navigatorKey = GlobalKey<NavigatorState>();
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
            schedule: TeacherScheduleScreen(
              repository: schedule,
              clock: tuesday,
              showBottomNav: false,
            ),
            grades: TeacherGradebookScreen(
              repository: grades,
              showBottomNav: false,
            ),
            profile: TeacherProfileScreen(
              repository: FakeCurrentUserRepository(),
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
      TeacherScheduleScreen,
      TeacherGradebookScreen,
      TeacherProfileScreen,
    ]) {
      expect(
        find.byType(screen),
        screen == type ? findsOneWidget : findsNothing,
        reason: '$screen',
      );
    }
  }

  testWidgets('starts on Хуваарь, with Хуваарь selected', (tester) async {
    await pumpShell(tester);

    expectShowing(TeacherScheduleScreen);
    expect(selectedTab(tester), TeacherTab.schedule.index);
    expect(selectedTab(tester), 0);
  });

  testWidgets('keeps Хуваарь, Дүнгийн хуудас, Профайл in that order, with no '
      'Нүүр', (tester) async {
    await pumpShell(tester);

    final xs = [
      for (final label in [
        TeacherHomeStrings.navSchedule,
        TeacherHomeStrings.navGrades,
        TeacherHomeStrings.navProfile,
      ])
        tester.getCenter(barLabel(label)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).items,
      hasLength(3),
    );
    expect(barLabel('Нүүр'), findsNothing);
    expect(find.byType(TeacherHomeScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('each tab selects itself and shows its own content', (
    tester,
  ) async {
    await pumpShell(tester);

    await tapTab(tester, TeacherHomeStrings.navGrades);
    expectShowing(TeacherGradebookScreen);
    expect(selectedTab(tester), TeacherTab.grades.index);

    await tapTab(tester, TeacherHomeStrings.navProfile);
    expectShowing(TeacherProfileScreen);
    expect(selectedTab(tester), TeacherTab.profile.index);

    await tapTab(tester, TeacherHomeStrings.navGrades);
    await tapTab(tester, TeacherHomeStrings.navSchedule);
    expectShowing(TeacherScheduleScreen);
    expect(selectedTab(tester), TeacherTab.schedule.index);
  });

  testWidgets('Профайл opens the Teacher Profile from every tab, selected, '
      'with no route pushed (Issue #243)', (tester) async {
    await pumpShell(tester);

    for (final label in [
      TeacherHomeStrings.navSchedule,
      TeacherHomeStrings.navGrades,
    ]) {
      await tapTab(tester, label);
      await tapTab(tester, TeacherHomeStrings.navProfile);

      expectShowing(TeacherProfileScreen);
      expect(selectedTab(tester), TeacherTab.profile.index, reason: label);
      expect(navigatorKey.currentState!.canPop(), isFalse);
    }
  });

  testWidgets('the bar belongs to the shell, not to a tab screen', (
    tester,
  ) async {
    await pumpShell(tester);
    await tapTab(tester, TeacherHomeStrings.navGrades);

    await tapTab(tester, TeacherHomeStrings.navProfile);

    expect(find.byType(TeacherBottomNav), findsOneWidget);
    for (final screen in [
      TeacherScheduleScreen,
      TeacherGradebookScreen,
      TeacherProfileScreen,
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
      TeacherHomeStrings.navGrades,
      TeacherHomeStrings.navProfile,
      TeacherHomeStrings.navSchedule,
      TeacherHomeStrings.navProfile,
      TeacherHomeStrings.navGrades,
      TeacherHomeStrings.navSchedule,
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
        home: TeacherScheduleScreen(
          repository: weekRepository(),
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
      find.byType(TeacherGradebookScreen, skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byType(TeacherProfileScreen, skipOffstage: false),
      findsNothing,
    );
    final scheduleState = tester.state(find.byType(TeacherScheduleScreen));

    await tapTab(tester, TeacherHomeStrings.navGrades);
    final gradesState = tester.state(find.byType(TeacherGradebookScreen));
    await tapTab(tester, TeacherHomeStrings.navSchedule);
    await tapTab(tester, TeacherHomeStrings.navGrades);
    await tapTab(tester, TeacherHomeStrings.navSchedule);

    expect(
      identical(
        tester.state(find.byType(TeacherScheduleScreen)),
        scheduleState,
      ),
      isTrue,
    );
    expect(
      schedule.sessionCalls,
      hasLength(1),
      reason: 'Хуваарь is not reloaded on return',
    );
    expect(grades.classCalls, 1, reason: 'nor is Дүнгийн хуудас');
    await tapTab(tester, TeacherHomeStrings.navGrades);
    expect(
      identical(tester.state(find.byType(TeacherGradebookScreen)), gradesState),
      isTrue,
    );
  });

  testWidgets('system back on another tab returns to Хуваарь, and does not '
      'leave the shell', (tester) async {
    await pumpShell(tester);

    for (final label in [
      TeacherHomeStrings.navGrades,
      TeacherHomeStrings.navProfile,
    ]) {
      await tapTab(tester, label);
      await navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expectShowing(TeacherScheduleScreen);
      expect(selectedTab(tester), TeacherTab.schedule.index);
      expect(find.byType(TeacherShell), findsOneWidget);
    }
  });

  testWidgets('opens on the tab its route names', (tester) async {
    for (final tab in TeacherTab.values) {
      await pumpShell(tester, initialTab: tab);

      expect(selectedTab(tester), tab.index);
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

  testWidgets('Хөтөлбөрүүд: the class\'s actions, its students and a student '
      'open over the shell, and back out to Хөтөлбөрүүд', (tester) async {
    await pumpShell(tester);
    await tapTab(tester, TeacherHomeStrings.navGrades);

    await tester.tap(
      find.widgetWithText(PillButton, TeacherGradebookStrings.details),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CohortActionSheet), findsOneWidget);
    await tester.tap(find.text(TeacherGradebookStrings.studentsInfo));
    await tester.pumpAndSettle();
    expect(find.byType(GradebookClassScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    await tester.tap(find.text('Student A'));
    await tester.pumpAndSettle();
    expect(find.byType(GradebookStudentScreen), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }
    expectShowing(TeacherGradebookScreen);
    expect(selectedTab(tester), TeacherTab.grades.index);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('Профайл: Change password still opens over the shell, and backs '
      'out to Профайл', (tester) async {
    await pumpShell(tester);
    await tapTab(tester, TeacherHomeStrings.navProfile);

    await tester.tap(find.text(ProfileStrings.changePassword));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expectShowing(TeacherProfileScreen);
    expect(selectedTab(tester), TeacherTab.profile.index);
  });
}
