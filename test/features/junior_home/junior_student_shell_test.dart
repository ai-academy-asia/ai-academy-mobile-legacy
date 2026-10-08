import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_student_shell.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_bottom_nav.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../profile/fake_current_user_repository.dart';
import 'fake_junior_home_repository.dart';
import 'fake_junior_progress_repository.dart';

/// The Junior Student tabs as one persistent shell (Issue #241): one bar,
/// owned by the shell, that never moves or is rebuilt as a route while the
/// content above it switches.
void main() {
  setUpAll(loadAppFonts);

  late GlobalKey<NavigatorState> navigatorKey;
  late FakeJuniorHomeRepository home;
  late FakeJuniorProgressRepository progress;

  Future<void> pumpShell(
    WidgetTester tester, {
    StudentTab initialTab = StudentTab.home,
  }) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    // Junior Home's scenery drifts forever; settling needs it still.
    useReducedMotion(tester);
    navigatorKey = GlobalKey<NavigatorState>();
    home = FakeJuniorHomeRepository();
    progress = FakeJuniorProgressRepository();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light,
        initialRoute: HomeRoutes.junior,
        routes: {
          HomeRoutes.junior: (_) => JuniorStudentShell(
            initialTab: initialTab,
            home: JuniorHomeScreen(repository: home, showBottomNav: false),
            progress: JuniorProgressScreen(
              repository: progress,
              showBottomNav: false,
            ),
            profile: JuniorProfileScreen(
              repository: FakeCurrentUserRepository(),
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

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Exactly one of the three junior tab screens is on display — and never
  /// an adult one.
  void expectShowing(Type type) {
    for (final screen in [
      JuniorHomeScreen,
      JuniorProgressScreen,
      JuniorProfileScreen,
    ]) {
      expect(
        find.byType(screen),
        screen == type ? findsOneWidget : findsNothing,
        reason: '$screen',
      );
    }
    for (final adult in [HomeScreen, CohortListScreen, ProfileScreen]) {
      expect(find.byType(adult, skipOffstage: false), findsNothing);
    }
  }

  testWidgets('starts on Нүүр, with Нүүр selected', (tester) async {
    await pumpShell(tester);

    expectShowing(JuniorHomeScreen);
    expect(selectedTab(tester), StudentTab.home.index);
  });

  testWidgets('each tab selects itself and shows its own content', (
    tester,
  ) async {
    await pumpShell(tester);

    await tapTab(tester, JuniorHomeStrings.navProgress);
    expectShowing(JuniorProgressScreen);
    expect(selectedTab(tester), StudentTab.progress.index);

    await tapTab(tester, JuniorHomeStrings.navProfile);
    expectShowing(JuniorProfileScreen);
    expect(selectedTab(tester), StudentTab.profile.index);

    await tapTab(tester, JuniorHomeStrings.navHome);
    expectShowing(JuniorHomeScreen);
    expect(selectedTab(tester), StudentTab.home.index);

    await tapTab(tester, JuniorHomeStrings.navProfile);
    await tapTab(tester, JuniorHomeStrings.navProgress);
    expectShowing(JuniorProgressScreen);
    expect(selectedTab(tester), StudentTab.progress.index);
  });

  testWidgets('the bar belongs to the shell, not to a tab screen', (
    tester,
  ) async {
    await pumpShell(tester);
    await tapTab(tester, JuniorHomeStrings.navProgress);
    await tapTab(tester, JuniorHomeStrings.navProfile);

    expect(find.byType(JuniorBottomNav), findsOneWidget);
    for (final screen in [
      JuniorHomeScreen,
      JuniorProgressScreen,
      JuniorProfileScreen,
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
      JuniorHomeStrings.navProgress,
      JuniorHomeStrings.navProfile,
      JuniorHomeStrings.navHome,
      JuniorHomeStrings.navProfile,
      JuniorHomeStrings.navProgress,
      JuniorHomeStrings.navHome,
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text(label),
        ),
      );
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
        home: JuniorProfileScreen(repository: FakeCurrentUserRepository()),
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
      find.byType(JuniorProgressScreen, skipOffstage: false),
      findsNothing,
    );
    expect(find.byType(JuniorProfileScreen, skipOffstage: false), findsNothing);
    final homeState = tester.state(find.byType(JuniorHomeScreen));

    await tapTab(tester, JuniorHomeStrings.navProgress);
    final progressState = tester.state(find.byType(JuniorProgressScreen));
    await tapTab(tester, JuniorHomeStrings.navHome);
    await tapTab(tester, JuniorHomeStrings.navProgress);
    await tapTab(tester, JuniorHomeStrings.navHome);

    expect(
      identical(tester.state(find.byType(JuniorHomeScreen)), homeState),
      isTrue,
    );
    expect(home.calls, 1, reason: 'Нүүр is not reloaded on return');
    expect(progress.callCount, 1, reason: 'nor is Сурлагын явц');
    await tapTab(tester, JuniorHomeStrings.navProgress);
    expect(
      identical(tester.state(find.byType(JuniorProgressScreen)), progressState),
      isTrue,
    );
  });

  testWidgets('system back on another tab returns to Нүүр, and does not '
      'leave the shell', (tester) async {
    await pumpShell(tester);

    for (final label in [
      JuniorHomeStrings.navProgress,
      JuniorHomeStrings.navProfile,
    ]) {
      await tapTab(tester, label);
      await navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expectShowing(JuniorHomeScreen);
      expect(selectedTab(tester), StudentTab.home.index);
      expect(find.byType(JuniorStudentShell), findsOneWidget);
    }
  });

  testWidgets('opens on the tab its route names', (tester) async {
    await pumpShell(tester, initialTab: StudentTab.profile);

    expectShowing(JuniorProfileScreen);
    expect(selectedTab(tester), StudentTab.profile.index);
    expect(find.byType(JuniorHomeScreen, skipOffstage: false), findsNothing);
  });

  testWidgets('a Profile detail screen still opens over the whole shell, and '
      'backs out to the tab it came from', (tester) async {
    await pumpShell(tester);
    await tapTab(tester, JuniorHomeStrings.navProfile);

    await tester.ensureVisible(find.text(JuniorProfileStrings.changePassword));
    await tester.tap(find.text(JuniorProfileStrings.changePassword));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expectShowing(JuniorProfileScreen);
    expect(selectedTab(tester), StudentTab.profile.index);
  });
}
