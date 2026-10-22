import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api/api_config.dart';
import 'core/api/api_override_banner.dart';
import 'core/locale/app_locale_controller.dart';
import 'core/locale/l10n.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_controller.dart';
import 'features/auth/presentation/home_route.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/auth/presentation/student_tabs.dart';
import 'features/cohorts/presentation/cohort_list_screen.dart';
import 'features/courses/presentation/course_catalog_screen.dart';
import 'features/home/presentation/adult_student_shell.dart';
import 'features/junior_home/presentation/junior_student_shell.dart';
import 'features/notifications/push/push_notifications.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/teacher/presentation/teacher_shell.dart';
import 'features/teacher/presentation/widgets/teacher_tabs.dart';

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

/// The app's [ScaffoldMessenger] — how a push received in the foreground
/// shows its SnackBar from outside a screen (Issue #398).
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AiAcademyApp extends StatelessWidget {
  const AiAcademyApp({super.key, this.themeController, this.localeController});

  /// The one theme state for every role (Issue #252). Defaults to
  /// [AppThemeController.instance]; injected in tests.
  final AppThemeController? themeController;

  /// The one language state for every role (Issue #501). Defaults to
  /// [AppLocaleController.instance]; injected in tests.
  final AppLocaleController? localeController;

  @override
  Widget build(BuildContext context) {
    final controller = themeController ?? AppThemeController.instance;
    final locale = localeController ?? AppLocaleController.instance;
    // Above the whole navigator, so Adult, Junior and Teacher — and Login
    // and Splash — all draw in the same theme and language. `darkTheme` is
    // the candidate (Issue #276), unreachable: the controller stays light
    // and nothing sets another mode until Phase 10.
    //
    // Above all of it, the scope that redraws the app's own strings when the
    // language changes (Issue #503). It follows `AppLocaleController.instance`
    // — the controller `L10n.current` reads — whichever controller a test
    // gives this widget.
    return L10nRebuildScope(
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, locale]),
        builder: (context, _) => _app(controller.mode, locale.locale),
      ),
    );
  }

  Widget _app(ThemeMode themeMode, Locale locale) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      // Push notifications start on the signed-in home routes (Issue #398).
      navigatorObservers: [PushNotifications.instance.routeObserver],
      title: 'AI academy Asia',
      debugShowCheckedModeBanner: false,
      // A debug build pointed at another API says so on every screen
      // (Issue #388); otherwise nothing is added.
      builder: ApiConfig.current.isOverride
          ? (context, child) => ApiOverrideBanner(
              label: ApiConfig.current.label,
              child: child ?? const SizedBox.shrink(),
            )
          : null,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Flutter's own widgets in the chosen language (Issue #501). The app's
      // own UI copy is read through `L10n.current` instead (Issue #503), so
      // no delegate of its own is listed — see `docs/ai/PROJECT_CONTEXT.md`.
      locale: locale,
      supportedLocales: AppLocaleController.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
        // The adult tabs are one persistent shell (Issue #237): each of its
        // routes opens it on that tab.
        HomeRoutes.adult: (_) => const AdultStudentShell(),
        // The junior and teacher tabs are persistent shells too (Issue #241):
        // each of their routes opens the shell on that tab.
        HomeRoutes.junior: (_) => const JuniorStudentShell(),
        // The Teacher landing route opens on Хуваарь, the Teacher area's
        // first tab (Issue #370).
        HomeRoutes.teacher: (_) => const TeacherShell(),
        // The teacher bar's Хуваарь (Issue #231) and Хөтөлбөрүүд (#233, #390).
        TeacherTabRoutes.schedule: (_) =>
            const TeacherShell(initialTab: TeacherTab.schedule),
        TeacherTabRoutes.gradebook: (_) =>
            const TeacherShell(initialTab: TeacherTab.grades),
        // Each Home's other two tabs, the adult and the junior pair — each
        // as its track's shell.
        StudentTabRoutes.adultProgress: (_) =>
            const AdultStudentShell(initialTab: StudentTab.progress),
        StudentTabRoutes.adultProfile: (_) =>
            const AdultStudentShell(initialTab: StudentTab.profile),
        StudentTabRoutes.juniorProgress: (_) =>
            const JuniorStudentShell(initialTab: StudentTab.progress),
        StudentTabRoutes.juniorProfile: (_) =>
            const JuniorStudentShell(initialTab: StudentTab.profile),
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
