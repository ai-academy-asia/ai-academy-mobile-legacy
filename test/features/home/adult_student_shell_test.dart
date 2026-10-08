import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/home/presentation/adult_student_shell.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../cohorts/fake_cohort_repository.dart';
import '../courses/fake_course_repository.dart';
import '../enrollments/fake_enrolled_cohorts_repository.dart';
import '../enrollments/fake_enrollment_repository.dart';
import '../profile/fake_current_user_repository.dart';
import 'fake_home_dashboard_repository.dart';

/// The Adult Student tabs as one persistent shell (Issue #237): one bar,
/// owned by the shell, that never moves or is rebuilt as a route while the
/// content above it switches.
void main() {
  setUpAll(loadAppFonts);

  late GlobalKey<NavigatorState> navigatorKey;
  late FakeHomeDashboardRepository home;

  Widget shell({StudentTab initialTab = StudentTab.home}) => AdultStudentShell(
    initialTab: initialTab,
    home: HomeScreen(repository: home, showBottomNav: false),
    progress: CohortListScreen(
      enrolledOnly: true,
      showBottomNav: false,
      repository: FakeCohortRepository(),
      courseRepository: FakeCourseRepository(),
      enrollmentRepository: FakeEnrollmentRepository(),
      enrolledCohortsRepository: FakeEnrolledCohortsRepository(),
    ),
    profile: ProfileScreen(
      repository: FakeCurrentUserRepository(),
      showBottomNav: false,
    ),
  );

  Future<void> pumpShell(
    WidgetTester tester, {
    StudentTab initialTab = StudentTab.home,
  }) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    navigatorKey = GlobalKey<NavigatorState>();
    home = FakeHomeDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light,
        initialRoute: HomeRoutes.adult,
        routes: {HomeRoutes.adult: (_) => shell(initialTab: initialTab)},
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedTab(WidgetTester tester) =>
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex;

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Exactly one of the three tab screens is on display: [type].
  void expectShowing(Type type) {
    for (final screen in [HomeScreen, CohortListScreen, ProfileScreen]) {
      expect(
        find.byType(screen),
        screen == type ? findsOneWidget : findsNothing,
        reason: '$screen',
      );
    }
  }

  testWidgets('starts on Home, with Home selected', (tester) async {
    await pumpShell(tester);

    expectShowing(HomeScreen);
    expect(selectedTab(tester), StudentTab.home.index);
  });

  testWidgets('each tab selects itself and shows its own content', (
    tester,
  ) async {
    await pumpShell(tester);

    await tapTab(tester, HomeStrings.navCourses);
    expectShowing(CohortListScreen);
    expect(selectedTab(tester), StudentTab.progress.index);

    await tapTab(tester, HomeStrings.navProfile);
    expectShowing(ProfileScreen);
    expect(selectedTab(tester), StudentTab.profile.index);

    await tapTab(tester, HomeStrings.navCourses);
    expectShowing(CohortListScreen);
    expect(selectedTab(tester), StudentTab.progress.index);

    await tapTab(tester, HomeStrings.navHome);
    expectShowing(HomeScreen);
    expect(selectedTab(tester), StudentTab.home.index);

    await tapTab(tester, HomeStrings.navProfile);
    await tapTab(tester, HomeStrings.navHome);
    expectShowing(HomeScreen);
    expect(selectedTab(tester), StudentTab.home.index);
  });

  testWidgets('the bar sits exactly where each screen drew its own', (
    tester,
  ) async {
    await pumpShell(tester);
    final inShell = tester.getRect(find.byType(AppBottomNav));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(repository: FakeHomeDashboardRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(AppBottomNav)), inShell);
  });

  testWidgets('the bar belongs to the shell, not to a tab screen', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.byType(AppBottomNav), findsOneWidget);
    for (final screen in [HomeScreen, CohortListScreen, ProfileScreen]) {
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
      HomeStrings.navCourses,
      HomeStrings.navProfile,
      HomeStrings.navHome,
      HomeStrings.navProfile,
      HomeStrings.navCourses,
      HomeStrings.navHome,
    ]) {
      await tester.tap(find.text(label).last);
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

  testWidgets('only the opened tabs are built, and each keeps its state', (
    tester,
  ) async {
    await pumpShell(tester);

    // Nothing but Home is built — opening Home loads only Home.
    expect(find.byType(CohortListScreen, skipOffstage: false), findsNothing);
    expect(find.byType(ProfileScreen, skipOffstage: false), findsNothing);
    final homeState = tester.state(find.byType(HomeScreen));

    await tapTab(tester, HomeStrings.navCourses);
    final coursesState = tester.state(find.byType(CohortListScreen));
    await tapTab(tester, HomeStrings.navHome);
    await tapTab(tester, HomeStrings.navCourses);
    await tapTab(tester, HomeStrings.navHome);

    expect(identical(tester.state(find.byType(HomeScreen)), homeState), isTrue);
    expect(home.callCount, 1, reason: 'Home is not reloaded on return');
    await tapTab(tester, HomeStrings.navCourses);
    expect(
      identical(tester.state(find.byType(CohortListScreen)), coursesState),
      isTrue,
    );
  });

  testWidgets('the current tab is inert', (tester) async {
    await pumpShell(tester);
    final homeState = tester.state(find.byType(HomeScreen));

    await tapTab(tester, HomeStrings.navHome);

    expectShowing(HomeScreen);
    expect(identical(tester.state(find.byType(HomeScreen)), homeState), isTrue);
  });

  testWidgets('system back on another tab returns to Home, and does not '
      'leave the shell', (tester) async {
    await pumpShell(tester);

    for (final label in [HomeStrings.navCourses, HomeStrings.navProfile]) {
      await tapTab(tester, label);
      await navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expectShowing(HomeScreen);
      expect(selectedTab(tester), StudentTab.home.index);
      expect(find.byType(AdultStudentShell), findsOneWidget);
    }
  });

  testWidgets('opens on the tab its route names', (tester) async {
    await pumpShell(tester, initialTab: StudentTab.profile);

    expectShowing(ProfileScreen);
    expect(selectedTab(tester), StudentTab.profile.index);
    expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('a detail screen still opens over the whole shell, and backs '
      'out to the tab it came from', (tester) async {
    await pumpShell(tester);
    await tapTab(tester, HomeStrings.navProfile);

    await tester.ensureVisible(find.text(ProfileStrings.changePassword));
    await tester.tap(find.text(ProfileStrings.changePassword));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expectShowing(ProfileScreen);
    expect(selectedTab(tester), StudentTab.profile.index);
  });
}
