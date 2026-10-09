import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_screen.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_learning_map.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:aia_mobile/features/splash/presentation/splash_screen.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screenshot.dart';
import 'auth/fake_auth_repository.dart';
import 'course_learning/fake_course_learning_repository.dart' hide sampleLesson;
import 'home/fake_home_dashboard_repository.dart';
import 'junior_home/fake_junior_home_repository.dart';
import 'notifications/fake_notification_repository.dart';
import 'profile/fake_current_user_repository.dart';
import 'teacher/fake_teacher_schedule_repository.dart';
import 'teacher/teacher_home_screen_test.dart' show sampleClass;

/// Dark Mode Phase 9 (Issue #276): the **candidate** dark theme, reached in
/// tests only — no user can reach it until Phase 10.
///
/// Two things, for screens of every role (Login, Adult Home, Course
/// Learning, Quiz, Junior Home, Teacher Schedule and its sheet,
/// Notifications):
///
///  * **Propagation.** Under `AppTheme.dark` each screen reads
///    `AppPalette.dark` — its page is the dark role, not a light colour left
///    behind — and the status bar follows: light glyphs on a page, and still
///    light over Teacher Schedule's band.
///  * **Dark goldens** (`*_dark.png`), for design review of the candidate.
///    They are not approved designs; the light goldens are untouched.
void main() {
  setUpAll(loadAppFonts);

  const dark = AppPalette.dark;

  Widget app(Widget home) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    // The candidate is reached by asking for it, as a Phase 10 switch would.
    themeMode: ThemeMode.dark,
    debugShowCheckedModeBanner: false,
    home: home,
  );

  DateTime teacherClock() => DateTime(2026, 10, 7, 13, 30);

  FakeTeacherScheduleRepository
  teacherSchedule() => FakeTeacherScheduleRepository(
    classes: [sampleClass()],
    sessions: {
      2: [
        sampleSession(id: 1, date: '2026-10-07', start: (9, 0), end: (13, 0)),
        sampleSession(id: 2, date: '2026-10-07', start: (14, 0), end: (17, 0)),
      ],
    },
    attendance: {
      1: const AttendanceCounts(present: 12, late: 2, absent: 9, excused: 1),
    },
  );

  /// Each representative screen, its golden name, the dark role its page
  /// must be, and its capture height.
  final screens = <String, (Widget Function(), Color, double)>{
    'login': (
      () => LoginScreen(
        repository: FakeAuthRepository(),
        sessionStore: AuthSessionStore(),
        currentUserRepository: FakeCurrentUserRepository(),
      ),
      dark.surfaceSubtle,
      852,
    ),
    'home': (
      () => HomeScreen(
        repository: FakeHomeDashboardRepository(
          dashboard: HomeDashboard(
            program: sampleProgram(
              progress: const ModuleProgress(
                percent: 35,
                completed: 2,
                total: 5,
              ),
              nextLesson: sampleLesson(start: DateTime(2026, 4, 8, 9)),
            ),
            stats: const [
              AttendanceStat(
                AttendanceSummary(attended: 1, total: 20),
                layout: HomeStatLayout.row,
              ),
              PaymentStat(PaymentStatus.dueIn(3), layout: HomeStatLayout.row),
            ],
          ),
        ),
        clock: () => DateTime(2026, 4, 8, 8),
      ),
      dark.surfaceSubtle,
      944,
    ),
    'course_module_list': (
      () => CourseModuleListScreen(
        courseSlug: 'how-ai-works',
        repository: FakeCourseLearningRepository(),
      ),
      dark.surface,
      1391,
    ),
    'exercise': (
      () => CourseExerciseDetailScreen(
        lessonId: 1,
        repository: FakeCourseLearningRepository(),
      ),
      dark.surfaceSubtle,
      1088,
    ),
    'quiz': (
      () => CourseQuizScreen(
        quiz: sampleQuiz(),
        repository: FakeCourseLearningRepository(),
      ),
      dark.surfaceSubtle,
      852,
    ),
    'junior_home': (
      () => JuniorHomeScreen(
        repository: FakeJuniorHomeRepository(),
        clock: () => sampleLessonTime,
      ),
      dark.surface,
      1428,
    ),
    'teacher_schedule': (
      () => TeacherScheduleScreen(
        repository: teacherSchedule(),
        clock: teacherClock,
      ),
      dark.surface,
      852,
    ),
    'notification': (
      () => NotificationScreen(
        center: NotificationCenter(repository: FakeNotificationRepository()),
      ),
      dark.surface,
      852,
    ),
  };

  Future<void> pumpScreen(WidgetTester tester, String name) async {
    final (build, _, height) = screens[name]!;
    useLogicalViewport(tester, Size(393, height), padding: iPhonePadding);
    useReducedMotion(tester);
    await tester.pumpWidget(app(build()));
    await tester.pumpAndSettle();
    await precacheImages(tester);
  }

  SystemUiOverlayStyle statusBar(WidgetTester tester) => tester
      .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      )
      .first
      .value;

  group('propagation: every screen reads the dark palette', () {
    for (final name in [
      'login',
      'home',
      'course_module_list',
      'exercise',
      'quiz',
      'junior_home',
      'teacher_schedule',
      'notification',
    ]) {
      testWidgets(name, (tester) async {
        await pumpScreen(tester, name);
        final (_, page, _) = screens[name]!;
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor ?? dark.pageBackground, page);
        final context = tester.element(find.byType(Scaffold).first);
        expect(context.palette, same(AppPalette.dark));
        expect(Theme.of(context).brightness, Brightness.dark);
      });
    }
  });

  group('status bar under the candidate', () {
    testWidgets('a page turns its glyphs light, its bar the dark role', (
      tester,
    ) async {
      await pumpScreen(tester, 'notification');
      final style = statusBar(tester);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, dark.surface);
    });

    testWidgets('Teacher Schedule stays light over its band in both modes', (
      tester,
    ) async {
      await pumpScreen(tester, 'teacher_schedule');
      expect(statusBar(tester).statusBarIconBrightness, Brightness.light);
      expect(
        tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .map((b) => b.color),
        contains(dark.scheduleBand),
      );
    });

    testWidgets('the session sheet is surfaceElevated over the barrier', (
      tester,
    ) async {
      await pumpScreen(tester, 'teacher_schedule');
      await tester.tap(find.bySemanticsLabel('AI Engineer, 09:00-13:00'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        dark.surfaceElevated,
      );
    });
  });

  testWidgets('Splash: the dark page, and the navy wordmark tinted '
      'wordmark (proposal §7) — invisible on a dark ground otherwise', (
    tester,
  ) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      app(SplashScreen(sessionStore: AuthSessionStore())),
    );
    await tester.pump(Duration.zero);
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    // Inside the 3–5 s hold, the lockup at rest and fully shown.
    await tester.pump(const Duration(milliseconds: 3500));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      dark.surfaceSubtle,
    );
    expect(
      tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
      ColorFilter.mode(dark.wordmark, BlendMode.srcIn),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../goldens/splash_dark.png'),
    );
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
  });

  group('dark goldens (candidate, for design review)', () {
    for (final name in screens.keys) {
      testWidgets(name, (tester) async {
        await pumpScreen(tester, name);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../goldens/${name}_dark.png'),
        );
      });
    }
  });
}
