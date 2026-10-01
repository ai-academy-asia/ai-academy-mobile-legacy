import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/auth/presentation/student_tabs.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_strings.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
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
import '../home/fake_home_dashboard_repository.dart';
import '../junior_home/fake_junior_home_repository.dart';
import '../profile/fake_current_user_repository.dart';

/// The student tab bar across its real screens, for both Homes.
///
/// Each Home is pumped as the root it is after sign-in, with the two tab
/// routes registered the way `AiAcademyApp` registers them — over the real
/// `CohortListScreen` and `ProfileScreen`, against fakes.
void main() {
  setUpAll(loadAppFonts);

  /// One Home experience: its route, its screen, and the labels its own bar
  /// draws for the two tabs it leaves from.
  final tracks = [
    (
      name: 'Junior',
      route: HomeRoutes.junior,
      home: (BuildContext _) =>
          JuniorHomeScreen(repository: FakeJuniorHomeRepository()),
      homeType: JuniorHomeScreen,
      progressLabel: JuniorHomeStrings.navProgress,
      profileLabel: JuniorHomeStrings.navProfile,
    ),
    (
      name: 'Adult',
      route: HomeRoutes.adult,
      home: (BuildContext _) =>
          HomeScreen(repository: FakeHomeDashboardRepository()),
      homeType: HomeScreen,
      progressLabel: HomeStrings.navCourses,
      profileLabel: HomeStrings.navProfile,
    ),
  ];

  for (final track in tracks) {
    group('${track.name} Home', () {
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
              track.route: track.home,
              StudentTabRoutes.progress: (_) => CohortListScreen(
                enrolledOnly: true,
                repository: FakeCohortRepository(),
                courseRepository: FakeCourseRepository(),
                enrollmentRepository: FakeEnrollmentRepository(),
                enrolledCohortsRepository: FakeEnrolledCohortsRepository(),
              ),
              StudentTabRoutes.profile: (_) =>
                  ProfileScreen(repository: FakeCurrentUserRepository()),
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

      /// Pops once and reports whether that uncovered Home — i.e. the screen
      /// on show was the only one stacked above it.
      Future<void> expectOneAboveHome(WidgetTester tester) async {
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(track.homeType), findsOneWidget);
        expect(navigatorKey.currentState!.canPop(), isFalse);
      }

      testWidgets('progress tab opens the enrolled cohorts, selected', (
        tester,
      ) async {
        await pumpApp(tester);
        expect(selectedTab(tester), 0);

        await tapTab(tester, track.progressLabel);

        final list = tester.widget<CohortListScreen>(
          find.byType(CohortListScreen),
        );
        expect(list.enrolledOnly, isTrue);
        expect(selectedTab(tester), 1);
        await expectOneAboveHome(tester);
      });

      testWidgets('profile tab opens Profile, selected', (tester) async {
        await pumpApp(tester);

        await tapTab(tester, track.profileLabel);

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(selectedTab(tester), 2);
        await expectOneAboveHome(tester);
      });

      testWidgets('switching between the tabs never stacks duplicates', (
        tester,
      ) async {
        await pumpApp(tester);

        await tapTab(tester, track.progressLabel);
        await tapTab(tester, CohortListStrings.navProfile);
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(selectedTab(tester), 2);

        await tapTab(tester, ProfileStrings.navCourses);
        expect(find.byType(CohortListScreen), findsOneWidget);
        expect(selectedTab(tester), 1);

        await tapTab(tester, CohortListStrings.navProfile);
        expect(find.byType(ProfileScreen), findsOneWidget);
        await expectOneAboveHome(tester);
      });

      testWidgets('Нүүр returns to this Home from either tab', (tester) async {
        await pumpApp(tester);

        await tapTab(tester, track.progressLabel);
        await tapTab(tester, CohortListStrings.navHome);
        expect(find.byType(track.homeType), findsOneWidget);
        expect(selectedTab(tester), 0);

        await tapTab(tester, track.profileLabel);
        await tapTab(tester, ProfileStrings.navHome);
        expect(find.byType(track.homeType), findsOneWidget);
        expect(selectedTab(tester), 0);
        expect(navigatorKey.currentState!.canPop(), isFalse);
      });
    });
  }
}
