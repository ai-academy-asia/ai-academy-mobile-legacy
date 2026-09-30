import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/home_route.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/cohorts/presentation/cohort_list_screen.dart';
import 'features/course_learning/data/sample_course_learning_repository.dart';
import 'features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'features/courses/presentation/course_catalog_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/junior_home/presentation/junior_home_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/splash/presentation/splash_screen.dart';

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
///
/// --- TEMPORARY: Exercise Detail visual QA ------------------------------
///
/// `/dev/course-exercise-preview` opens the new Exercise Detail screen
/// directly, without Module List → Lesson List → Exercise Detail
/// navigation, which does not exist yet (Lesson List is a later
/// increment). Manual visual testing only — push this route by name to
/// preview it; the app's own `initialRoute` is `'/'` as usual. The route
/// opens `CourseExerciseDetailScreen` against
/// `SampleCourseLearningRepository` — passed explicitly, now that the
/// screen's own default is the real API — at the sample's own lesson id, no
/// network call.
///
/// **Remove this route entry and this comment once Exercise Detail is
/// reachable through the real Module List → Lesson → Exercise flow.**
class AiAcademyApp extends StatelessWidget {
  const AiAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI academy Asia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        // TEMPORARY dev-only entry point — see the class doc above.
        '/dev/course-exercise-preview': (_) => CourseExerciseDetailScreen(
          lessonId: SampleCourseLearningRepository.previewLessonId,
          repository: SampleCourseLearningRepository(),
        ),
        '/login': (_) => const LoginScreen(),
        '/reset-password': (_) => const ResetPasswordScreen(),
        // Sign-in lands on one of these two, by `user_type` — see
        // `homeRouteFor`. `/home` is the adult Нүүр tab, the dashboard.
        HomeRoutes.adult: (_) => const HomeScreen(),
        HomeRoutes.junior: (_) => const JuniorHomeScreen(),
        // The student's own cohorts — Home's Хичээл tab opens this directly.
        '/my-cohorts': (_) => const CohortListScreen(enrolledOnly: true),
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
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}
