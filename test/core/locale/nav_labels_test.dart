import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_screen.dart';
import 'package:aia_mobile/features/home/presentation/adult_student_shell.dart';
import 'package:aia_mobile/features/home/presentation/home_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_profile_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_student_shell.dart';
import 'package:aia_mobile/features/profile/presentation/profile_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_shell.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/cohorts/fake_cohort_repository.dart';
import '../../features/courses/fake_course_repository.dart';
import '../../features/enrollments/fake_enrolled_cohorts_repository.dart';
import '../../features/enrollments/fake_enrollment_repository.dart';
import '../../features/home/fake_home_dashboard_repository.dart';
import '../../features/junior_home/fake_junior_home_repository.dart';
import '../../features/junior_home/fake_junior_progress_repository.dart';
import '../../features/profile/fake_current_user_repository.dart';
import '../../features/teacher/fake_schedule_change_repository.dart';
import '../../features/teacher/teacher_gradebook_screen_test.dart'
    show classRepository;
import '../../features/teacher/teacher_home_screen_test.dart' show tuesday;
import '../../features/teacher/teacher_schedule_screen_test.dart'
    show weekRepository;
import '../../support/screenshot.dart';

/// Issue #511: every role's bottom navigation in the selected language.
/// Layout at every width and text size, in both languages, is
/// `app_bottom_nav_test.dart`'s.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// The approved labels, by key.
  const labels = <String, ({String mongolian, String english})>{
    'navHome': (mongolian: 'Нүүр', english: 'Home'),
    'navCourses': (mongolian: 'Хичээл', english: 'Courses'),
    'navProfile': (mongolian: 'Профайл', english: 'Profile'),
    'navProgress': (mongolian: 'Сурлагын явц', english: 'Progress'),
    'navSchedule': (mongolian: 'Хуваарь', english: 'Schedule'),
    'navPrograms': (mongolian: 'Хөтөлбөрүүд', english: 'Programs'),
  };

  String expected(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? labels[key]!.mongolian
      : labels[key]!.english;

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final strings = L10n.of(language);
        expect(
          {
            'navHome': strings.navHome,
            'navCourses': strings.navCourses,
            'navProfile': strings.navProfile,
            'navProgress': strings.navProgress,
            'navSchedule': strings.navSchedule,
            'navPrograms': strings.navPrograms,
          },
          {for (final key in labels.keys) key: expected(key, language)},
        );
      });
    }

    test('read differently from one another in both languages, so a '
        'declaration wired to the wrong key cannot pass', () {
      expect({for (final l in labels.values) l.mongolian}, hasLength(6));
      expect({for (final l in labels.values) l.english}, hasLength(6));
    });
  });

  group('the nine declarations', () {
    final members = <(String, String Function(), String)>[
      ('HomeStrings.navHome', () => HomeStrings.navHome, 'navHome'),
      ('HomeStrings.navCourses', () => HomeStrings.navCourses, 'navCourses'),
      ('HomeStrings.navProfile', () => HomeStrings.navProfile, 'navProfile'),
      ('JuniorHomeStrings.navHome', () => JuniorHomeStrings.navHome, 'navHome'),
      (
        'JuniorHomeStrings.navProgress',
        () => JuniorHomeStrings.navProgress,
        'navProgress',
      ),
      (
        'JuniorHomeStrings.navProfile',
        () => JuniorHomeStrings.navProfile,
        'navProfile',
      ),
      (
        'TeacherHomeStrings.navSchedule',
        () => TeacherHomeStrings.navSchedule,
        'navSchedule',
      ),
      (
        'TeacherHomeStrings.navGrades',
        () => TeacherHomeStrings.navGrades,
        'navPrograms',
      ),
      // The alias of the adult bar's Profile.
      (
        'TeacherHomeStrings.navProfile',
        () => TeacherHomeStrings.navProfile,
        'navProfile',
      ),
    ];

    test('are nine', () => expect(members, hasLength(9)));

    for (final language in LocalePreference.values) {
      test(language.name, () async {
        await locale.setPreference(language);
        for (final (name, read, key) in members) {
          expect(read(), expected(key, language), reason: name);
        }
      });
    }
  });

  group('switching language while a role\'s shell is mounted', () {
    late GlobalKey<NavigatorState> navigatorKey;

    Future<void> pump(WidgetTester tester, WidgetBuilder shell) async {
      useLogicalViewport(tester, const Size(393, 1000), padding: iPhonePadding);
      navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        L10nRebuildScope(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.light,
            initialRoute: '/shell',
            routes: {'/shell': shell},
          ),
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

    /// The shell's mounted tabs — a tab is built the first time it is shown
    /// — as their states, by screen. The same objects after a switch means
    /// nothing was rebuilt from scratch.
    Map<Type, State> tabStates(WidgetTester tester, List<Type> screens) => {
      for (final screen in screens)
        if (find.byType(screen, skipOffstage: false).evaluate().isNotEmpty)
          screen: tester.state(find.byType(screen, skipOffstage: false)),
    };

    /// Selects the last tab, switches to English and back, and checks the
    /// bar, the selected tab and each tab's state along the way; then that
    /// a tap on an English label still switches tabs.
    Future<void> exercise(
      WidgetTester tester, {
      required List<String> keys,
      required List<Type> screens,
    }) async {
      await tester.tap(
        barLabel(expected(keys.last, LocalePreference.mongolian)),
      );
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 2);
      final before = tabStates(tester, screens);
      // The first tab, then the last: both kept alive from here on.
      expect(before.keys, containsAll([screens.first, screens.last]));

      await locale.setEnglish(true);
      await tester.pump();

      for (final key in keys) {
        expect(
          barLabel(expected(key, LocalePreference.english)),
          findsOneWidget,
        );
        expect(
          barLabel(expected(key, LocalePreference.mongolian)),
          findsNothing,
        );
      }
      expect(selectedTab(tester), 2);
      expect(tabStates(tester, screens), before);
      expect(navigatorKey.currentState!.canPop(), isFalse);

      // A tap on an English label still switches tabs.
      await tester.tap(
        barLabel(expected(keys.first, LocalePreference.english)),
      );
      await tester.pumpAndSettle();
      expect(selectedTab(tester), 0);
      expect(tabStates(tester, screens), before);

      await locale.setEnglish(false);
      await tester.pump();
      for (final key in keys) {
        expect(
          barLabel(expected(key, LocalePreference.mongolian)),
          findsOneWidget,
        );
      }
      expect(selectedTab(tester), 0);
      expect(tabStates(tester, screens), before);
    }

    testWidgets('Adult: Нүүр / Хичээл / Профайл ↔ Home / Courses / Profile', (
      tester,
    ) async {
      await pump(
        tester,
        (_) => AdultStudentShell(
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
        ),
      );
      await exercise(
        tester,
        keys: const ['navHome', 'navCourses', 'navProfile'],
        screens: const [HomeScreen, CohortListScreen, ProfileScreen],
      );
    });

    testWidgets('Junior: Нүүр / Сурлагын явц / Профайл ↔ Home / Progress / '
        'Profile', (tester) async {
      // Junior Home's scenery drifts forever; settling needs it still.
      useReducedMotion(tester);
      await pump(
        tester,
        (_) => JuniorStudentShell(
          home: JuniorHomeScreen(
            repository: FakeJuniorHomeRepository(),
            showBottomNav: false,
          ),
          progress: JuniorProgressScreen(
            repository: FakeJuniorProgressRepository(),
            showBottomNav: false,
          ),
          profile: JuniorProfileScreen(
            repository: FakeCurrentUserRepository(),
            showBottomNav: false,
          ),
        ),
      );
      await exercise(
        tester,
        keys: const ['navHome', 'navProgress', 'navProfile'],
        screens: const [
          JuniorHomeScreen,
          JuniorProgressScreen,
          JuniorProfileScreen,
        ],
      );
    });

    testWidgets('Teacher: Хуваарь / Хөтөлбөрүүд / Профайл ↔ Schedule / '
        'Programs / Profile', (tester) async {
      await pump(
        tester,
        (_) => TeacherShell(
          schedule: TeacherScheduleScreen(
            repository: weekRepository(),
            clock: tuesday,
            showBottomNav: false,
            // Never the real API (Issue #449).
            scheduleChangeRepository: FakeScheduleChangeRepository(),
          ),
          grades: TeacherGradebookScreen(
            repository: classRepository(),
            showBottomNav: false,
          ),
          profile: TeacherProfileScreen(
            repository: FakeCurrentUserRepository(),
          ),
        ),
      );
      await exercise(
        tester,
        keys: const ['navSchedule', 'navPrograms', 'navProfile'],
        screens: const [
          TeacherScheduleScreen,
          TeacherGradebookScreen,
          TeacherProfileScreen,
        ],
      );
    });
  });
}
