import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
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
import '../profile/fake_current_user_repository.dart';

/// The student tab bar across its real screens, for both tracks.
///
/// Each Home is pumped as the root it is after sign-in, with **every** tab
/// route registered the way `AiAcademyApp` registers them — both tracks' —
/// so a junior tab that opened an adult screen (or the reverse) would land on
/// it here and fail, rather than on a missing route.
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
    (
      name: 'Adult',
      route: HomeRoutes.adult,
      homeType: HomeScreen,
      progressType: CohortListScreen,
      profileType: ProfileScreen,
      foreignTypes: const [JuniorProgressScreen, JuniorProfileScreen],
      homeLabel: HomeStrings.navHome,
      progressLabel: HomeStrings.navCourses,
      profileLabel: HomeStrings.navProfile,
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
        navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.light,
            initialRoute: track.route,
            routes: {
              HomeRoutes.adult: (_) =>
                  HomeScreen(repository: FakeHomeDashboardRepository()),
              HomeRoutes.junior: (_) =>
                  JuniorHomeScreen(repository: FakeJuniorHomeRepository()),
              StudentTabRoutes.adultProgress: (_) => CohortListScreen(
                enrolledOnly: true,
                repository: FakeCohortRepository(),
                courseRepository: FakeCourseRepository(),
                enrollmentRepository: FakeEnrollmentRepository(),
                enrolledCohortsRepository: FakeEnrolledCohortsRepository(),
              ),
              StudentTabRoutes.adultProfile: (_) =>
                  ProfileScreen(repository: FakeCurrentUserRepository()),
              StudentTabRoutes.juniorProgress: (_) =>
                  const JuniorProgressScreen(),
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
