import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/home_route.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/auth/presentation/student_tabs.dart';
import 'features/cohorts/presentation/cohort_list_screen.dart';
import 'features/courses/presentation/course_catalog_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/junior_home/presentation/junior_home_screen.dart';
import 'features/junior_home/presentation/junior_profile_screen.dart';
import 'features/junior_home/presentation/junior_progress_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/teacher/presentation/teacher_home_screen.dart';

/// The application root.
///
/// A named-route table — the app has a handful of screens, which does not yet
/// justify a routing package. When the navigation grows deep links or nested
/// shells, this is the single place that changes.
///
/// `/` is [SplashScreen] rather than [LoginScreen] directly: it runs its own
/// short animation, then waits for a tap before it hands off to `/login`
/// (see [SplashScreen.nextRoute]) — nothing else in the app should ever
/// navigate back to `/`.
/// The app's navigator — how a session that could not be renewed returns to
/// Login from outside the widget tree (see `returnToLoginWhenSessionEnds`).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AiAcademyApp extends StatelessWidget {
  const AiAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'AI academy Asia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        // Pushed over Login while a session is held — a voluntary change, so
        // it can go back (Issue #227). The required change never uses this
        // route: `openSignedIn` builds its own screen, without a back control.
        '/reset-password': (_) =>
            const ResetPasswordScreen(showBackButton: true),
        // Sign-in lands on one of these two, by `user_type` — see
        // `homeRouteFor`. `/home` is the adult Нүүр tab, the dashboard.
        HomeRoutes.adult: (_) => const HomeScreen(),
        HomeRoutes.junior: (_) => const JuniorHomeScreen(),
        HomeRoutes.teacher: (_) => const TeacherHomeScreen(),
        // Each Home's other two tabs — the adult pair and the junior pair;
        // see `openStudentTab`.
        StudentTabRoutes.adultProgress: (_) =>
            const CohortListScreen(enrolledOnly: true),
        StudentTabRoutes.adultProfile: (_) => const ProfileScreen(),
        StudentTabRoutes.juniorProgress: (_) => const JuniorProgressScreen(),
        StudentTabRoutes.juniorProfile: (_) => const JuniorProfileScreen(),
        // The draft course catalog. No longer reached from Home's Хичээл tab
        // (or anywhere else); still registered, and still pushes `/cohorts`
        // with a course id, until it is deleted.
        '/courses': (_) => const CourseCatalogScreen(),
        // Arguments are the tapped course's id (an int), set by
        // `CourseCatalogScreen`'s navigation — null for any other caller,
        // which shows every cohort unfiltered.
        '/cohorts': (context) {
          final courseId = ModalRoute.of(context)?.settings.arguments;
          return CohortListScreen(courseId: courseId is int ? courseId : null);
        },
      },
    );
  }
}
