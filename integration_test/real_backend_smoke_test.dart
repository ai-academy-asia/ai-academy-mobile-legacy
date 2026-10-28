// A read-only smoke test of the real app against the real backend, on a
// device or simulator (Issue #557). Runbook: docs/ai/DATA_AND_API.md §3.2.
//
//     flutter test integration_test/real_backend_smoke_test.dart -d <device> \
//       --dart-define=AIA_SMOKE_STUDENT_LOGIN=… \
//       --dart-define=AIA_SMOKE_STUDENT_PASSWORD=…
//
// Without credentials only the launch section runs. Each signed-in section
// runs only when its own account is given, and none of them writes: no
// attendance, enrolment, submission, note, quiz attempt, signing, lesson
// completion or time-change request. Credentials are passed on the command
// line and never committed.

import 'package:aia_mobile/core/api/api_config.dart';
import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/features/auth/data/http_current_user_repository.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/presentation/login_screen.dart';
import 'package:aia_mobile/features/auth/presentation/login_strings.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out_strings.dart';
import 'package:aia_mobile/features/cohorts/data/http_cohort_repository.dart';
import 'package:aia_mobile/features/course_learning/data/http_course_learning_repository.dart';
import 'package:aia_mobile/features/courses/data/http_course_repository.dart';
import 'package:aia_mobile/features/enrollments/data/http_enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/home/presentation/adult_student_shell.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_student_shell.dart';
import 'package:aia_mobile/features/profile/presentation/widgets/profile_parts.dart';
import 'package:aia_mobile/features/splash/presentation/splash_strings.dart';
import 'package:aia_mobile/features/teacher/data/http_teacher_gradebook_repository.dart';
import 'package:aia_mobile/features/teacher/data/http_teacher_schedule_repository.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_shell.dart';
import 'package:aia_mobile/main.dart' as app;
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// One account per role, each optional.
const _accounts = [
  (
    role: _Role.adult,
    login: String.fromEnvironment('AIA_SMOKE_STUDENT_LOGIN'),
    password: String.fromEnvironment('AIA_SMOKE_STUDENT_PASSWORD'),
  ),
  (
    role: _Role.junior,
    login: String.fromEnvironment('AIA_SMOKE_JUNIOR_LOGIN'),
    password: String.fromEnvironment('AIA_SMOKE_JUNIOR_PASSWORD'),
  ),
  (
    role: _Role.teacher,
    login: String.fromEnvironment('AIA_SMOKE_TEACHER_LOGIN'),
    password: String.fromEnvironment('AIA_SMOKE_TEACHER_PASSWORD'),
  ),
];

enum _Role { adult, junior, teacher }

/// Signs out a session the device already held at launch, so the run can
/// start from Login. Off by default: it is someone's saved sign-in.
const _signOutRestored = bool.fromEnvironment('AIA_SMOKE_SIGN_OUT_RESTORED');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // One app launch for the whole run: `main` attaches the app's
  // singletons once, as a real start does. Sections run in order, each
  // recording its own result, so one failure does not hide the next.
  testWidgets('real backend smoke (read-only)', (tester) async {
    final report = _Report();

    var onLogin = false;
    _Role? restored;
    await report.section('launch: Splash hands off, the API in use', () async {
      await app.main();
      report.note('API: ${ApiConfig.current.label}');
      final landing = {
        'Login': find.byType(LoginScreen),
        'a saved Adult session': find.byType(AdultStudentShell),
        'a saved Junior session': find.byType(JuniorStudentShell),
        'a saved Teacher session': find.byType(TeacherShell),
        "Splash's network error": find.text(SplashStrings.networkError),
      };
      final where = await _waitForAny(tester, landing);
      report.note('landed on $where');
      if (where == "Splash's network error") fail('no network from Splash');
      if (where != 'Login' && _signOutRestored) {
        await _signOut(tester, profileTab: L10n.current.navProfile);
        await _waitFor(tester, find.byType(LoginScreen));
        report.note(
          'signed the saved session out (AIA_SMOKE_SIGN_OUT_RESTORED)',
        );
      }
      onLogin = find.byType(LoginScreen).evaluate().isNotEmpty;
      if (!onLogin) {
        restored = switch (where) {
          'a saved Adult session' => _Role.adult,
          'a saved Junior session' => _Role.junior,
          _ => _Role.teacher,
        };
      }
    });

    await report.section(
      'public catalog parses (GET /courses, /cohorts)',
      () async {
        final courses = await HttpCourseRepository().getCourses();
        final listing = await HttpCohortRepository().getCohorts();
        report.note(
          '${courses.length} courses, ${listing.cohorts.length} cohorts '
          '(${listing.skipped.length} skipped as unreadable)',
        );
        expect(courses, isNotEmpty);
        expect(
          listing.skipped,
          isEmpty,
          reason: 'a cohort the app cannot read',
        );
      },
    );

    if (!onLogin) {
      // The saved session's own journey, read-only, and left signed in.
      final role = restored;
      if (role != null) {
        await _journey(tester, report, role, 'saved ${role.name}');
      }
      report.skip(
        'Login checks and sign-ins: the device holds a saved session — sign '
        'it out in the app, or pass AIA_SMOKE_SIGN_OUT_RESTORED=true',
      );
      report.print();
      expect(report.failures, isEmpty, reason: report.failures.join('\n'));
      return;
    }

    await report.section('Login in both languages and at 2.0× text', () async {
      for (final language in LocalePreference.values) {
        await AppLocaleController.instance.setPreference(language);
        await _settle(tester);
        expect(find.text(LoginStrings.signIn), findsWidgets);
      }
      await AppLocaleController.instance.setPreference(
        LocalePreference.mongolian,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await _settle(tester);
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await _settle(tester);
    });

    for (final account in _accounts) {
      if (account.login.isEmpty || account.password.isEmpty) {
        report.skip('${account.role.name}: no account given');
        continue;
      }
      await report.section('${account.role.name}: sign in', () async {
        await _signIn(tester, account.login, account.password);
        final shell = switch (account.role) {
          _Role.adult => find.byType(AdultStudentShell),
          _Role.junior => find.byType(JuniorStudentShell),
          _Role.teacher => find.byType(TeacherShell),
        };
        await _waitFor(tester, shell);
        expect(AuthSessionStore.instance.session, isNotNull);
      });
      if (AuthSessionStore.instance.session == null) continue;

      await _journey(tester, report, account.role, account.role.name);

      await report.section('${account.role.name}: sign out', () async {
        await _signOut(tester, profileTab: _tabs(account.role).last);
        await _waitFor(tester, find.byType(LoginScreen));
        expect(AuthSessionStore.instance.session, isNull);
      });
    }

    report.print();
    expect(report.failures, isEmpty, reason: report.failures.join('\n'));
  });
}

/// A signed-in [role]'s read-only journey: every tab, its real data, and
/// the language round trip.
Future<void> _journey(
  WidgetTester tester,
  _Report report,
  _Role role,
  String name,
) async {
  await report.section('$name: every tab loads', () async {
    for (final tab in _tabs(role)) {
      await tester.tap(find.text(tab).last);
      await _settle(tester, const Duration(seconds: 6));
      _expectNoFailureLine(tab);
    }
  });

  await report.section('$name: every tab at 2.0× text, in English', () async {
    await AppLocaleController.instance.setPreference(LocalePreference.english);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    try {
      await _settle(tester);
      for (final tab in _tabs(role)) {
        if (find.text(tab).evaluate().isEmpty) {
          final shown = [
            for (final e
                in find
                    .descendant(
                      of: find.byType(AppBottomNav),
                      matching: find.byType(Text),
                    )
                    .evaluate())
              (e.widget as Text).data,
          ];
          fail('no "$tab" tab at 2.0×; the bar shows $shown');
        }
        await tester.tap(find.text(tab).last);
        await _settle(tester, const Duration(seconds: 4));
        expect(tester.takeException(), isNull, reason: '$tab at 2.0×');
        _expectNoFailureLine('$tab at 2.0×');
      }
    } finally {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await AppLocaleController.instance.setPreference(
        LocalePreference.mongolian,
      );
      await _settle(tester);
    }
  });

  await report.section('$name: real data parses', () async {
    final me = await HttpCurrentUserRepository().getCurrentUser();
    report.note('signed in as user type ${me.userType.name}');
    if (role == _Role.teacher) {
      await _teacherData(report);
    } else {
      await _studentData(report);
    }
  });

  await report.section('$name: MN → EN → MN', () async {
    await tester.tap(find.text(_tabs(role).last).last);
    await _settle(tester);
    await _tapToggle(tester, 'EN');
    expect(L10n.current.navProfile, 'Profile');
    expect(find.text('Profile'), findsWidgets);
    _expectNoFailureLine('Profile in English');
    await _tapToggle(tester, 'MN');
    expect(L10n.current.navProfile, 'Профайл');
  });
}

/// The bottom bar's labels, Profile last.
List<String> _tabs(_Role role) {
  final s = L10n.current;
  return switch (role) {
    _Role.adult => [s.navHome, s.navCourses, s.navProfile],
    _Role.junior => [s.navHome, s.navProgress, s.navProfile],
    _Role.teacher => [s.navSchedule, s.navPrograms, s.navProfile],
  };
}

/// No shared failure line on screen: a read that failed shows one of these.
void _expectNoFailureLine(String where) {
  final s = L10n.current;
  for (final line in [
    s.commonNetworkError,
    s.commonServerError,
    s.commonUnexpectedError,
    s.commonSessionExpired,
  ]) {
    expect(find.text(line), findsNothing, reason: '$where: "$line"');
  }
}

Future<void> _studentData(_Report report) async {
  final enrolled = await HttpEnrolledCohortsRepository().getEnrolledCohorts();
  report.note('${enrolled.length} enrolled cohorts');
  if (enrolled.isEmpty) return;
  final listing = await HttpCohortRepository().getCohorts();
  final cohort = listing.cohorts
      .where((c) => c.id == enrolled.first.cohortId)
      .firstOrNull;
  if (cohort == null) {
    report.note('enrolled cohort ${enrolled.first.cohortId} not in /cohorts');
    return;
  }
  final learning = HttpCourseLearningRepository();
  final path = await learning.getCourseLearning(cohort.course.slug);
  report.note(
    '${cohort.course.slug}: ${path.modules.length} modules, '
    '${path.percentComplete}% complete',
  );
  if (path.modules.isEmpty) return;
  final moduleId = path.continueModuleId ?? path.modules.first.id;
  final lessons = await learning.getLessons(moduleId);
  report.note('module $moduleId: ${lessons.length} lessons');
  // Only the server's continue lesson: a locked lesson answers 409.
  final lessonId = path.continueLessonId;
  if (lessonId != null) {
    final exercise = await learning.getExercise(lessonId);
    report.note('lesson $lessonId read (${exercise.title})');
  }
}

Future<void> _teacherData(_Report report) async {
  final schedule = HttpTeacherScheduleRepository();
  final classes = await schedule.getClasses();
  report.note('${classes.length} classes');
  final today = DateTime.now();
  final from = today.subtract(const Duration(days: 7));
  final to = today.add(const Duration(days: 7));
  final assigned = await schedule.getAssignedSessions(from: from, to: to);
  report.note('${assigned.length} assigned sessions this fortnight');
  if (classes.isEmpty) return;
  final cohortId = classes.first.cohort.id;
  final sessions = await schedule.getSessions(
    cohortId: cohortId,
    from: from,
    to: to,
  );
  final gradebook = HttpTeacherGradebookRepository();
  final students = await gradebook.getStudents(cohortId);
  final assignments = await gradebook.getAssignments(cohortId);
  report.note(
    'cohort $cohortId: ${sessions.length} sessions, ${students.length} '
    'students, ${assignments.length} assignments',
  );
}

Future<void> _signIn(WidgetTester tester, String login, String password) async {
  await _waitFor(tester, find.byType(LoginScreen));
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), login);
  await tester.enterText(fields.at(1), password);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.tap(find.text(LoginStrings.signIn).last);
  await _settle(tester, const Duration(seconds: 2));
}

Future<void> _signOut(WidgetTester tester, {required String profileTab}) async {
  if (find.text(profileTab).evaluate().isNotEmpty) {
    await tester.tap(find.text(profileTab).last);
    await _settle(tester);
  }
  final button = find.byType(ProfileLogOutButton);
  final target = button.evaluate().isNotEmpty
      ? button
      : find.text('Log out').last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await _settle(tester);
  await tester.tap(find.text(SignOutStrings.confirm).last);
  await _settle(tester, const Duration(seconds: 2));
}

/// The Profile's MN/EN control's [label] — Adult and Teacher share
/// [ProfileLanguageToggle]; Junior Profile draws its own with the same labels.
Finder _inToggle(String label) {
  final shared = find.descendant(
    of: find.byType(ProfileLanguageToggle),
    matching: find.text(label),
  );
  return shared.evaluate().isNotEmpty ? shared : find.text(label).last;
}

Future<void> _tapToggle(WidgetTester tester, String label) async {
  await tester.ensureVisible(_inToggle(label));
  await _settle(tester);
  await tester.tap(_inToggle(label));
  await _settle(tester);
}

/// Pumps until [finder] shows, or fails after [timeout]. Not
/// `pumpAndSettle`: some screens animate without end.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('timed out after ${timeout.inSeconds}s waiting for $finder');
}

/// Pumps until one of [targets] shows, and returns its name.
Future<String> _waitForAny(
  WidgetTester tester,
  Map<String, Finder> targets, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    for (final MapEntry(:key, :value) in targets.entries) {
      if (value.evaluate().isNotEmpty) return key;
    }
  }
  fail('timed out after ${timeout.inSeconds}s: none of ${targets.keys}');
}

/// Pumps for [time], letting network replies and animations land.
Future<void> _settle(
  WidgetTester tester, [
  Duration time = const Duration(seconds: 1),
]) async {
  final end = DateTime.now().add(time);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Each section's outcome, printed at the end in one block.
class _Report {
  final List<String> _lines = [];
  final List<String> failures = [];

  Future<void> section(String name, Future<void> Function() body) async {
    try {
      await body();
      _lines.add('PASS  $name');
    } catch (error) {
      final line = 'FAIL  $name: ${'$error'.split('\n').first}';
      _lines.add(line);
      failures.add(line);
    }
  }

  void skip(String why) => _lines.add('SKIP  $why');

  void note(String text) => _lines.add('      · $text');

  void print() => debugPrint(
    [
      '── real backend smoke ──',
      ..._lines,
      '────────────────────────',
    ].join('\n'),
  );
}
