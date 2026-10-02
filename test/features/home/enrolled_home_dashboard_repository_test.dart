import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:aia_mobile/features/auth/domain/current_user.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/courses/domain/course.dart';
import 'package:aia_mobile/features/enrollments/domain/enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:aia_mobile/features/home/data/enrolled_home_dashboard_repository.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/payments/domain/ledger_entry.dart';
import 'package:aia_mobile/features/payments/domain/ledger_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../attendance/fake_attendance_repository.dart';
import '../cohorts/fake_cohort_repository.dart';
import '../course_learning/fake_course_learning_repository.dart';
import '../courses/fake_course_repository.dart';
import '../enrollments/fake_enrolled_cohorts_repository.dart';
import '../payments/fake_ledger_repository.dart';
import '../profile/fake_current_user_repository.dart';

/// Exercises how [EnrolledHomeDashboardRepository] maps `GET /me/cohorts`,
/// `GET /cohorts`, `GET /courses`, `GET /auth/me`,
/// `GET /me/courses/{slug}/learning`, `GET /me/ledger` and
/// `GET /me/attendance` — each already tested against the wire in its own
/// suite — onto a [HomeDashboard]. Nothing here talks to the
/// network: each dependency is a fake, so this is purely about the
/// composition.
void main() {
  /// Learning path unavailable — the student is not enrolled in the course,
  /// as far as `GET /me/courses/{slug}/learning` can tell.
  FakeCourseLearningRepository unavailableLearning() =>
      FakeCourseLearningRepository(
        failure: const CourseLearningFailure(
          CourseLearningFailureKind.notEnrolled,
        ),
      );

  FakeLedgerRepository unavailableLedger() => FakeLedgerRepository(
    failure: const LedgerFailure(LedgerFailureKind.network),
  );

  FakeAttendanceRepository unavailableAttendance() => FakeAttendanceRepository(
    failure: const AttendanceFailure(AttendanceFailureKind.network),
  );

  EnrolledHomeDashboardRepository repository({
    required List<EnrolledCohortSummary> enrolled,
    required List<Cohort> cohorts,
    List<Course> courses = const [],
    FakeCurrentUserRepository? currentUser,
    FakeCourseLearningRepository? courseLearning,
    FakeLedgerRepository? ledger,
    FakeAttendanceRepository? attendance,
    DateTime? now,
  }) => EnrolledHomeDashboardRepository(
    enrolledCohorts: FakeEnrolledCohortsRepository(enrolledCohorts: enrolled),
    cohorts: FakeCohortRepository(cohorts: cohorts),
    courses: FakeCourseRepository(courses: courses),
    currentUser: currentUser ?? FakeCurrentUserRepository(),
    // Unavailable unless a test says otherwise, so every test written before
    // the learning call existed still covers the `/me/cohorts` behaviour it
    // was written for.
    courseLearning: courseLearning ?? unavailableLearning(),
    ledger: ledger ?? unavailableLedger(),
    attendance: attendance ?? unavailableAttendance(),
    clock: () => now ?? DateTime(2026, 8, 10, 9),
  );

  /// The `/auth/me` account with only its `ui_mode` chosen.
  FakeCurrentUserRepository accountWithUiMode(String? uiMode) =>
      FakeCurrentUserRepository(
        user: CurrentUser(
          id: 9,
          actorId: 5,
          actorType: 'student',
          email: 'student@example.mn',
          role: 'student',
          isActive: true,
          mustChangePassword: false,
          profile: UserProfile(
            id: 5,
            firstName: 'Test',
            lastName: 'Student',
            phone: '99123456',
            uiMode: uiMode,
          ),
        ),
      );

  group('no enrollment', () {
    test(
      'answers an empty dashboard when the student is enrolled nowhere',
      () async {
        final dashboard = await repository(
          enrolled: const [],
          cohorts: [sampleCohort(id: 1)],
        ).getDashboard();

        expect(dashboard.isEmpty, isTrue);
        expect(dashboard.program, isNull);
      },
    );

    test('ignores a cohort id no longer in the catalog', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 99)],
        cohorts: [sampleCohort(id: 1)],
      ).getDashboard();

      expect(dashboard.program, isNull);
    });
  });

  group('progress', () {
    test(
      'reads a whole-number progress_pct straight onto the percent',
      () async {
        final dashboard = await repository(
          enrolled: const [EnrolledCohortSummary(cohortId: 1, progressPct: 40)],
          cohorts: [sampleCohort(id: 1)],
        ).getDashboard();

        final progress = dashboard.program!.progress!;
        expect(progress.percent, 40);
        expect(progress.fraction, 0.4);
      },
    );

    test('rounds a fractional progress_pct', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1, progressPct: 62.6)],
        cohorts: [sampleCohort(id: 1)],
      ).getDashboard();

      expect(dashboard.program!.progress!.percent, 63);
    });

    test('never invents a module count from a bare percentage', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1, progressPct: 40)],
        cohorts: [sampleCohort(id: 1)],
      ).getDashboard();

      final progress = dashboard.program!.progress!;
      expect(progress.completed, isNull);
      expect(progress.total, isNull);
    });

    test('leaves progress null when the entry carries none', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
      ).getDashboard();

      expect(dashboard.program!.progress, isNull);
    });
  });

  group('learning progress', () {
    test('fills percent and the module count from the learning path', () async {
      // samplePath: 30%, modules 1–2 completed, 3–5 not.
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        courseLearning: FakeCourseLearningRepository(path: samplePath()),
      ).getDashboard();

      final progress = dashboard.program!.progress!;
      expect(progress.percent, 30);
      expect(progress.completed, 2);
      expect(progress.total, 5);
    });

    test('counts the server\'s completed flags, not locked ones', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        courseLearning: FakeCourseLearningRepository(
          path: samplePath(
            percentComplete: 55,
            modules: [
              sampleModule(id: 1, completed: true),
              sampleModule(id: 2),
              sampleModule(id: 3, completed: true),
              sampleModule(id: 4, locked: true),
            ],
          ),
        ),
      ).getDashboard();

      final progress = dashboard.program!.progress!;
      // The server's lesson-based percent, never re-derived from 2 of 4.
      expect(progress.percent, 55);
      expect(progress.completed, 2);
      expect(progress.total, 4);
    });

    test('wins over the /me/cohorts progress_pct', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1, progressPct: 80)],
        cohorts: [sampleCohort(id: 1)],
        courseLearning: FakeCourseLearningRepository(path: samplePath()),
      ).getDashboard();

      expect(dashboard.program!.progress!.percent, 30);
    });

    test('is asked for the resolved catalog slug', () async {
      final learning = FakeCourseLearningRepository(path: samplePath());
      await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        courses: [sampleCourse()],
        courseLearning: learning,
      ).getDashboard();

      expect(learning.calls, ['summer-bootcamp']);
    });

    test('a path with no modules gives the percent without a count', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        courseLearning: FakeCourseLearningRepository(
          path: samplePath(percentComplete: 0, modules: const []),
        ),
      ).getDashboard();

      final progress = dashboard.program!.progress!;
      expect(progress.percent, 0);
      expect(progress.completed, isNull);
      expect(progress.total, isNull);
    });

    test('a failure falls back to the /me/cohorts progress_pct', () async {
      for (final kind in CourseLearningFailureKind.values) {
        final dashboard = await repository(
          enrolled: const [EnrolledCohortSummary(cohortId: 1, progressPct: 40)],
          cohorts: [sampleCohort(id: 1)],
          courseLearning: FakeCourseLearningRepository(
            failure: CourseLearningFailure(kind),
          ),
        ).getDashboard();

        final progress = dashboard.program!.progress!;
        expect(progress.percent, 40, reason: kind.name);
        expect(progress.completed, isNull, reason: kind.name);
        expect(progress.total, isNull, reason: kind.name);
      }
    });

    test('a failure leaves the rest of the dashboard as it was', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        courses: [sampleCourse()],
        currentUser: accountWithUiMode('adult'),
        courseLearning: FakeCourseLearningRepository(
          failure: const CourseLearningFailure(
            CourseLearningFailureKind.network,
          ),
        ),
      ).getDashboard();

      final program = dashboard.program!;
      expect(program.progress, isNull);
      expect(program.cohortName, sampleCohort(id: 1).name);
      expect(program.courseSlug, 'summer-bootcamp');
      expect(program.uiMode, 'adult');
      expect(program.nextLesson, isNotNull);
      expect(dashboard.contract, isNull);
      expect(dashboard.stats, isEmpty);
    });

    test('is not requested when the student is enrolled nowhere', () async {
      final learning = FakeCourseLearningRepository(path: samplePath());
      final dashboard = await repository(
        enrolled: const [],
        cohorts: [sampleCohort(id: 1)],
        courseLearning: learning,
      ).getDashboard();

      expect(dashboard.isEmpty, isTrue);
      expect(learning.calls, isEmpty);
    });
  });

  group('statistics', () {
    // The default clock: 2026-08-10, 09:00.
    LedgerEntry owing({
      num balance = 150000,
      DateTime? nextDueDate,
      int cohortId = 1,
    }) => LedgerEntry(
      enrollmentId: 2,
      cohortId: cohortId,
      balance: balance,
      nextDueDate: nextDueDate,
    );

    Future<HomeDashboard> dashboardWith({
      FakeLedgerRepository? ledger,
      FakeAttendanceRepository? attendance,
      List<Course> courses = const [],
    }) => repository(
      enrolled: const [EnrolledCohortSummary(cohortId: 1)],
      cohorts: [sampleCohort(id: 1)],
      courses: courses,
      ledger: ledger,
      attendance: attendance,
    ).getDashboard();

    PaymentStatus? paymentOf(HomeDashboard dashboard) =>
        dashboard.stats.whereType<PaymentStat>().firstOrNull?.payment;

    AttendanceSummary? attendanceOf(HomeDashboard dashboard) =>
        dashboard.stats.whereType<AttendanceStat>().firstOrNull?.attendance;

    test('the verified adult test account: attendance only, as a row, '
        'and progress 0% at 0 of 1', () async {
      // /me/ledger: balance 0, installments [], next_due_date null.
      // /me/attendance: sessions [], summary 0 / 0 / 0.
      // /learning: one incomplete module, progress.percent 0.
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        courseLearning: FakeCourseLearningRepository(
          path: samplePath(percentComplete: 0, modules: [sampleModule(id: 1)]),
        ),
        ledger: FakeLedgerRepository(entries: [owing(balance: 0)]),
        attendance: FakeAttendanceRepository(),
      ).getDashboard();

      expect(paymentOf(dashboard), isNull);
      final attendance = attendanceOf(dashboard)!;
      expect(attendance.attended, 0);
      expect(attendance.total, 0);
      expect(attendance.percent, 0);
      expect(dashboard.stats.single.layout, HomeStatLayout.row);
      expect(dashboard.contract, isNull);

      final progress = dashboard.program!.progress!;
      expect(progress.percent, 0);
      expect(progress.completed, 0);
      expect(progress.total, 1);
    });

    test('attendance is the server\'s summary, percent included', () async {
      final dashboard = await dashboardWith(
        attendance: FakeAttendanceRepository(
          attendance: const CourseAttendance(
            attended: 1,
            totalPast: 20,
            percent: 10,
          ),
        ),
      );

      final attendance = attendanceOf(dashboard)!;
      expect(attendance.attended, 1);
      expect(attendance.total, 20);
      expect(attendance.percent, 10);
    });

    test('attended session dates pass through; nothing else does', () async {
      final dashboard = await dashboardWith(
        attendance: FakeAttendanceRepository(
          attendance: CourseAttendance(
            attended: 2,
            totalPast: 3,
            percent: 67,
            sessions: [
              AttendanceSession(date: DateTime(2026, 6, 16), status: 'present'),
              AttendanceSession(date: DateTime(2026, 6, 20), status: 'late'),
              // Not a confirmed status: neither attended nor missed.
              AttendanceSession(date: DateTime(2026, 6, 23), status: 'other'),
            ],
          ),
        ),
      );

      final attendance = attendanceOf(dashboard)!;
      expect(attendance.attendedDates, {
        DateTime(2026, 6, 16),
        DateTime(2026, 6, 20),
      });
      // The card's own figures are still the server's summary.
      expect(attendance.attended, 2);
      expect(attendance.total, 3);
      expect(attendance.percent, 67);
    });

    test('no sessions: no attended dates', () async {
      final dashboard = await dashboardWith(
        attendance: FakeAttendanceRepository(),
      );

      expect(attendanceOf(dashboard)!.attendedDates, isEmpty);
    });

    test('attendance is asked for the resolved catalog slug', () async {
      final attendance = FakeAttendanceRepository();
      await dashboardWith(courses: [sampleCourse()], attendance: attendance);

      expect(attendance.calls, ['summer-bootcamp']);
    });

    test('a balance with a future due date counts the days down', () async {
      final dashboard = await dashboardWith(
        ledger: FakeLedgerRepository(
          entries: [owing(nextDueDate: DateTime(2026, 8, 13))],
        ),
      );

      final payment = paymentOf(dashboard)!;
      expect(payment.isOverdue, isFalse);
      expect(payment.daysUntilDue, 3);
    });

    test('a balance due today is due in 0 days, not overdue', () async {
      final dashboard = await dashboardWith(
        ledger: FakeLedgerRepository(
          entries: [owing(nextDueDate: DateTime(2026, 8, 10))],
        ),
      );

      expect(paymentOf(dashboard)!.daysUntilDue, 0);
    });

    test('a balance past its due date is overdue', () async {
      final dashboard = await dashboardWith(
        ledger: FakeLedgerRepository(
          entries: [owing(nextDueDate: DateTime(2026, 8, 9))],
        ),
      );

      expect(paymentOf(dashboard)!.isOverdue, isTrue);
    });

    test('nothing owed draws no payment card, whatever the date', () async {
      final dashboard = await dashboardWith(
        ledger: FakeLedgerRepository(
          entries: [owing(balance: 0, nextDueDate: DateTime(2026, 8, 9))],
        ),
      );

      expect(paymentOf(dashboard), isNull);
    });

    test('a balance with no due date draws no payment card', () async {
      final dashboard = await dashboardWith(
        ledger: FakeLedgerRepository(entries: [owing()]),
      );

      expect(paymentOf(dashboard), isNull);
    });

    test('reads only the entry for the cohort on the card', () async {
      final dashboard = await dashboardWith(
        ledger: FakeLedgerRepository(
          entries: [owing(cohortId: 99, nextDueDate: DateTime(2026, 8, 9))],
        ),
      );

      expect(paymentOf(dashboard), isNull);
    });

    test(
      'both cards: payment then attendance, side by side as tiles',
      () async {
        final dashboard = await dashboardWith(
          ledger: FakeLedgerRepository(
            entries: [owing(nextDueDate: DateTime(2026, 8, 13))],
          ),
          attendance: FakeAttendanceRepository(),
        );

        expect(dashboard.stats, hasLength(2));
        expect(dashboard.stats[0], isA<PaymentStat>());
        expect(dashboard.stats[1], isA<AttendanceStat>());
        expect(
          dashboard.stats.map((stat) => stat.layout),
          everyElement(HomeStatLayout.tile),
        );
      },
    );

    test('a failed ledger leaves only the attendance card, as a row', () async {
      final dashboard = await dashboardWith(
        ledger: unavailableLedger(),
        attendance: FakeAttendanceRepository(),
      );

      expect(paymentOf(dashboard), isNull);
      expect(dashboard.stats.single, isA<AttendanceStat>());
      expect(dashboard.stats.single.layout, HomeStatLayout.row);
      expect(dashboard.program, isNotNull);
    });

    test(
      'a failed attendance leaves only the payment card, as a row',
      () async {
        final dashboard = await dashboardWith(
          ledger: FakeLedgerRepository(
            entries: [owing(nextDueDate: DateTime(2026, 8, 13))],
          ),
          attendance: unavailableAttendance(),
        );

        expect(dashboard.stats.single, isA<PaymentStat>());
        expect(dashboard.stats.single.layout, HomeStatLayout.row);
      },
    );

    test('both failing leaves the rest of the dashboard as it was', () async {
      final dashboard = await dashboardWith();

      expect(dashboard.stats, isEmpty);
      expect(dashboard.program!.cohortName, sampleCohort(id: 1).name);
      expect(dashboard.program!.nextLesson, isNotNull);
    });

    test('neither is requested when the student is enrolled nowhere', () async {
      final ledger = FakeLedgerRepository();
      final attendance = FakeAttendanceRepository();
      final dashboard = await repository(
        enrolled: const [],
        cohorts: [sampleCohort(id: 1)],
        ledger: ledger,
        attendance: attendance,
      ).getDashboard();

      expect(dashboard.isEmpty, isTrue);
      expect(ledger.callCount, 0);
      expect(attendance.calls, isEmpty);
    });
  });

  group('which cohort', () {
    test('prefers the active cohort over other enrolled ones', () async {
      final dashboard = await repository(
        enrolled: const [
          EnrolledCohortSummary(cohortId: 1),
          EnrolledCohortSummary(cohortId: 2),
        ],
        cohorts: [
          sampleCohort(id: 1, name: 'Finished cohort', status: 'finished'),
          sampleCohort(id: 2, name: 'Active cohort', status: 'active'),
        ],
      ).getDashboard();

      expect(dashboard.program!.cohortId, 2);
    });

    test(
      'falls back to the first enrolled cohort when none is active',
      () async {
        final dashboard = await repository(
          enrolled: const [
            EnrolledCohortSummary(cohortId: 5),
            EnrolledCohortSummary(cohortId: 1),
          ],
          cohorts: [
            sampleCohort(id: 1, name: 'First in the catalog', status: 'open'),
            sampleCohort(id: 5, name: 'Also enrolled', status: 'open'),
          ],
        ).getDashboard();

        // `/cohorts`' own order decides, not the enrollment list's — matching
        // the order the catalog and cohort list already show cohorts in.
        expect(dashboard.program!.cohortId, 1);
      },
    );
  });

  group('schedule', () {
    test('carries the chosen cohort\'s own schedule', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [
          sampleCohort(id: 1, meetingDays: const ['tue', 'thu']),
        ],
      ).getDashboard();

      final schedule = dashboard.program!.schedule!;
      expect(schedule.weekdays, {DateTime.tuesday, DateTime.thursday});
      expect(schedule.firstDay, DateTime(2026, 8, 6));
      expect(schedule.lastDay, DateTime(2026, 10, 6));
    });

    test('is null when the cohort has no parseable schedule', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1, meetingDays: const [])],
      ).getDashboard();

      expect(dashboard.program!.schedule, isNull);
      expect(dashboard.program!.nextLesson, isNull);
    });
  });

  group('course title', () {
    test('prefers Mongolian, then English, then the cohort name', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [
          sampleCohort(
            id: 1,
            course: const CohortCourse(
              id: 6,
              slug: 'ai-engineer',
              title: LocalizedText(en: 'AI Engineer', mn: 'АЙ инженер'),
            ),
          ),
        ],
      ).getDashboard();

      expect(dashboard.program!.courseTitle, 'АЙ инженер');
    });
  });

  group('course slug resolution', () {
    test('resolves the catalog slug when the cohort\'s own is stale', () async {
      // Reproduces the real, confirmed drift: the cohort's embedded course
      // stub names id 6 / slug "summer-bootcamp-2027" — `sampleCohort`'s
      // own defaults — while the catalog's matching course (same title)
      // is id 4 / slug "summer-bootcamp" — `sampleCourse`'s own defaults.
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        courses: [sampleCourse()],
      ).getDashboard();

      expect(dashboard.program!.courseSlug, 'summer-bootcamp');
    });

    test('falls back to the cohort\'s own slug when nothing matches', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        courses: const [],
      ).getDashboard();

      expect(dashboard.program!.courseSlug, 'summer-bootcamp-2027');
    });

    test('a failed GET /courses falls back, not the whole dashboard', () async {
      final dashboard = await EnrolledHomeDashboardRepository(
        enrolledCohorts: FakeEnrolledCohortsRepository(
          enrolledCohorts: const [EnrolledCohortSummary(cohortId: 1)],
        ),
        cohorts: FakeCohortRepository(cohorts: [sampleCohort(id: 1)]),
        courses: FakeCourseRepository(
          failure: const ApiFailure(ApiFailureKind.server),
        ),
        currentUser: FakeCurrentUserRepository(),
      ).getDashboard();

      expect(dashboard.program, isNotNull);
      expect(dashboard.program!.courseSlug, 'summer-bootcamp-2027');
    });
  });

  group('ui mode', () {
    List<EnrolledCohortSummary> enrolledInOne() => const [
      EnrolledCohortSummary(cohortId: 1),
    ];

    test('reads it from the profile GET /auth/me returns', () async {
      final dashboard = await repository(
        enrolled: enrolledInOne(),
        cohorts: [sampleCohort(id: 1)],
        currentUser: accountWithUiMode('kids'),
      ).getDashboard();

      expect(dashboard.program!.uiMode, 'kids');
    });

    test('passes any value through as the API sent it', () async {
      final dashboard = await repository(
        enrolled: enrolledInOne(),
        cohorts: [sampleCohort(id: 1)],
        currentUser: accountWithUiMode('teen'),
      ).getDashboard();

      expect(dashboard.program!.uiMode, 'teen');
    });

    test('does not come from the course or the cohort', () async {
      // Two students on the same cohort get their own account's mode.
      final cohorts = [sampleCohort(id: 1, courseId: 6)];
      final first = await repository(
        enrolled: enrolledInOne(),
        cohorts: cohorts,
        currentUser: accountWithUiMode('kids'),
      ).getDashboard();
      final second = await repository(
        enrolled: enrolledInOne(),
        cohorts: cohorts,
        currentUser: accountWithUiMode('adult'),
      ).getDashboard();

      expect(first.program!.uiMode, 'kids');
      expect(second.program!.uiMode, 'adult');
    });

    test('a null ui_mode reads as none (Issue #168)', () async {
      final dashboard = await repository(
        enrolled: enrolledInOne(),
        cohorts: [sampleCohort(id: 1, name: 'Cohort 01')],
        currentUser: accountWithUiMode(null),
      ).getDashboard();

      expect(dashboard.program!.uiMode, isNull);
      expect(dashboard.program!.cohortName, 'Cohort 01');
    });

    test('an empty ui_mode reads as none', () async {
      final dashboard = await repository(
        enrolled: enrolledInOne(),
        cohorts: [sampleCohort(id: 1)],
        currentUser: accountWithUiMode(''),
      ).getDashboard();

      expect(dashboard.program!.uiMode, isNull);
    });

    test(
      'a failed /auth/me leaves the ui mode null, not the whole dashboard',
      () async {
        final dashboard = await repository(
          enrolled: enrolledInOne(),
          cohorts: [sampleCohort(id: 1, name: 'Cohort 01')],
          currentUser: FakeCurrentUserRepository(
            failure: const CurrentUserFailure(CurrentUserFailureKind.server),
          ),
        ).getDashboard();

        expect(dashboard.program, isNotNull);
        expect(dashboard.program!.cohortName, 'Cohort 01');
        expect(dashboard.program!.uiMode, isNull);
      },
    );

    test('is not requested when the student is enrolled nowhere', () async {
      final currentUser = FakeCurrentUserRepository();
      final dashboard = await repository(
        enrolled: const [],
        cohorts: [sampleCohort(id: 1)],
        currentUser: currentUser,
      ).getDashboard();

      expect(dashboard.isEmpty, isTrue);
      expect(currentUser.callCount, 0);
    });
  });

  group('next lesson', () {
    test('derives it from the cohort schedule at the given clock', () async {
      // sampleCohort meets Mon/Wed 18:00-20:00, 2026-08-06 to 2026-10-06.
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        // A Monday, before that day's lesson.
        now: DateTime(2026, 8, 10, 9),
      ).getDashboard();

      final lesson = dashboard.program!.nextLesson!;
      expect(lesson.startsAt, DateTime(2026, 8, 10, 18));
      expect(lesson.isLiveAt(DateTime(2026, 8, 10, 19)), isTrue);
    });

    test('is null when the cohort has no parseable schedule', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1, meetingDays: const [])],
      ).getDashboard();

      expect(dashboard.program!.nextLesson, isNull);
    });
  });

  group('failures', () {
    test(
      'an enrollment failure becomes the matching HomeFailureKind',
      () async {
        final repo = EnrolledHomeDashboardRepository(
          enrolledCohorts: FakeEnrolledCohortsRepository(
            failure: const EnrollmentFailure(
              EnrollmentFailureKind.sessionExpired,
            ),
          ),
          cohorts: FakeCohortRepository(cohorts: const []),
        );

        await expectLater(
          repo.getDashboard(),
          throwsA(
            isA<HomeFailure>().having(
              (f) => f.kind,
              'kind',
              HomeFailureKind.sessionExpired,
            ),
          ),
        );
      },
    );

    test(
      'a cohort-list failure becomes the matching HomeFailureKind',
      () async {
        final repo = EnrolledHomeDashboardRepository(
          enrolledCohorts: FakeEnrolledCohortsRepository(),
          cohorts: FakeCohortRepository(
            failure: const ApiFailure(ApiFailureKind.network),
          ),
        );

        await expectLater(
          repo.getDashboard(),
          throwsA(
            isA<HomeFailure>().having(
              (f) => f.kind,
              'kind',
              HomeFailureKind.network,
            ),
          ),
        );
      },
    );
  });
}
