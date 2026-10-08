import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/adult_student_shell.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../cohorts/fake_cohort_repository.dart';
import '../courses/fake_course_repository.dart';
import '../enrollments/fake_enrolled_cohorts_repository.dart';
import '../enrollments/fake_enrollment_repository.dart';
import '../home/fake_home_dashboard_repository.dart';
import '../junior_home/fake_junior_home_repository.dart';
import '../junior_home/fake_junior_progress_repository.dart';
import '../profile/fake_current_user_repository.dart';

/// The junior tab bar across its real screens.
///
/// Junior Home is pumped as the root it is after sign-in, with **every** tab
/// route registered the way `AiAcademyApp` registers them — the adult ones
/// as `AdultStudentShell` — so a junior tab that opened an adult screen would
/// land on it here and fail, rather than on a missing route. The adult tabs
/// switch inside that shell rather than by route (Issue #237):
/// `adult_student_shell_test.dart`.
void main() {
  setUpAll(loadAppFonts);

  test('each track names its own routes', () {
    expect(
      StudentTabRoutes.of(StudentTrack.adult, StudentTab.progress),
      '/my-cohorts',
    );
    expect(
      StudentTabRoutes.of(StudentTrack.adult, StudentTab.profile),
      '/profile',
    );
    expect(
      StudentTabRoutes.of(StudentTrack.junior, StudentTab.progress),
      '/junior-progress',
    );
    expect(
      StudentTabRoutes.of(StudentTrack.junior, StudentTab.profile),
      '/junior-profile',
    );
    expect(
      StudentTabRoutes.of(StudentTrack.junior, StudentTab.home),
      HomeRoutes.junior,
    );
    expect(
      StudentTabRoutes.of(StudentTrack.adult, StudentTab.home),
      HomeRoutes.adult,
    );
  });

  /// The adult routes, as `AiAcademyApp` registers them.
  Widget adultShell(StudentTab initialTab) => AdultStudentShell(
    initialTab: initialTab,
    home: HomeScreen(
      repository: FakeHomeDashboardRepository(),
      showBottomNav: false,
    ),
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

  /// One track: its Home, the screens its other two tabs open, the screens
  /// they must never open, and the labels its bars draw.
  final tracks = [
    (
      name: 'Junior',
      route: HomeRoutes.junior,
      homeType: JuniorHomeScreen,
      progressType: JuniorProgressScreen,
      profileType: JuniorProfileScreen,
      foreignTypes: const [CohortListScreen, ProfileScreen],
      homeLabel: JuniorHomeStrings.navHome,
      progressLabel: JuniorHomeStrings.navProgress,
      profileLabel: JuniorHomeStrings.navProfile,
    ),
  ];

  for (final track in tracks) {
    group('${track.name} track', () {
      late GlobalKey<NavigatorState> navigatorKey;

      Future<void> pumpApp(WidgetTester tester) async {
        useLogicalViewport(
          tester,
          const Size(393, 852),
          padding: iPhonePadding,
        );
        // Junior Home's scenery drifts forever; settling needs it still.
        if (track.homeType == JuniorHomeScreen) useReducedMotion(tester);
        navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.light,
            initialRoute: track.route,
            routes: {
              HomeRoutes.adult: (_) => adultShell(StudentTab.home),
              HomeRoutes.junior: (_) =>
                  JuniorHomeScreen(repository: FakeJuniorHomeRepository()),
              StudentTabRoutes.adultProgress: (_) =>
                  adultShell(StudentTab.progress),
              StudentTabRoutes.adultProfile: (_) =>
                  adultShell(StudentTab.profile),
              StudentTabRoutes.juniorProgress: (_) => JuniorProgressScreen(
                repository: FakeJuniorProgressRepository(),
              ),
              StudentTabRoutes.juniorProfile: (_) =>
                  JuniorProfileScreen(repository: FakeCurrentUserRepository()),
            },
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tapTab(WidgetTester tester, String label) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      int selectedTab(WidgetTester tester) =>
          tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex;

      void expectOnScreen(Type type) {
        expect(find.byType(type), findsOneWidget);
        for (final foreign in track.foreignTypes) {
          expect(find.byType(foreign), findsNothing, reason: '$foreign');
        }
      }

      /// Pops once and checks that uncovered Home — i.e. the screen on show
      /// was the only one stacked above it.
      Future<void> expectOneAboveHome(WidgetTester tester) async {
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(track.homeType), findsOneWidget);
        expect(navigatorKey.currentState!.canPop(), isFalse);
      }

      testWidgets('starts on its own Home, Home selected', (tester) async {
        await pumpApp(tester);

        expectOnScreen(track.homeType);
        expect(selectedTab(tester), 0);
      });

      testWidgets('the progress tab opens its own progress screen', (
        tester,
      ) async {
        await pumpApp(tester);

        await tapTab(tester, track.progressLabel);

        expectOnScreen(track.progressType);
        expect(selectedTab(tester), 1);
        await expectOneAboveHome(tester);
      });

      testWidgets('the profile tab opens its own profile screen', (
        tester,
      ) async {
        await pumpApp(tester);

        await tapTab(tester, track.profileLabel);

        expectOnScreen(track.profileType);
        expect(selectedTab(tester), 2);
        await expectOneAboveHome(tester);
      });

      testWidgets('switching between the tabs never stacks duplicates', (
        tester,
      ) async {
        await pumpApp(tester);

        await tapTab(tester, track.progressLabel);
        await tapTab(tester, track.profileLabel);
        expectOnScreen(track.profileType);
        expect(selectedTab(tester), 2);

        await tapTab(tester, track.progressLabel);
        expectOnScreen(track.progressType);
        expect(selectedTab(tester), 1);

        await tapTab(tester, track.profileLabel);
        expectOnScreen(track.profileType);
        await expectOneAboveHome(tester);
      });

      testWidgets('Нүүр returns to its own Home from either tab', (
        tester,
      ) async {
        await pumpApp(tester);

        await tapTab(tester, track.progressLabel);
        await tapTab(tester, track.homeLabel);
        expectOnScreen(track.homeType);
        expect(selectedTab(tester), 0);

        await tapTab(tester, track.profileLabel);
        await tapTab(tester, track.homeLabel);
        expectOnScreen(track.homeType);
        expect(selectedTab(tester), 0);
        expect(navigatorKey.currentState!.canPop(), isFalse);
      });

      testWidgets('the current tab is inert', (tester) async {
        await pumpApp(tester);

        await tapTab(tester, track.progressLabel);
        await tapTab(tester, track.progressLabel);

        expectOnScreen(track.progressType);
        await expectOneAboveHome(tester);
      });
    });
  }
}
