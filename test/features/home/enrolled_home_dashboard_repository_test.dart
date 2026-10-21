import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:aia_mobile/features/auth/domain/current_user.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort_listing.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
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
import '../contracts/fake_contract_repository.dart';
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
    List<SkippedCohort> skipped = const [],
    List<Course> courses = const [],
    FakeCurrentUserRepository? currentUser,
    FakeCourseLearningRepository? courseLearning,
    FakeLedgerRepository? ledger,
    FakeAttendanceRepository? attendance,
    FakeContractRepository? contracts,
    DateTime? now,
  }) => EnrolledHomeDashboardRepository(
    enrolledCohorts: FakeEnrolledCohortsRepository(enrolledCohorts: enrolled),
    cohorts: FakeCohortRepository(cohorts: cohorts, skipped: skipped),
    courses: FakeCourseRepository(courses: courses),
    currentUser: currentUser ?? FakeCurrentUserRepository(),
    // Unavailable unless a test says otherwise, so every test written before
    // the learning call existed still covers the `/me/cohorts` behaviour it
    // was written for.
    courseLearning: courseLearning ?? unavailableLearning(),
    ledger: ledger ?? unavailableLedger(),
    attendance: attendance ?? unavailableAttendance(),
    contracts: contracts ?? FakeContractRepository(),
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

  group('getContractNotice — the banner alone (Issue #322)', () {
    EnrolledHomeDashboardRepository withContracts(
      FakeContractRepository contracts,
    ) => repository(
      enrolled: const [EnrolledCohortSummary(cohortId: 1)],
      cohorts: [sampleCohort(id: 1)],
      contracts: contracts,
    );

    test('the same rule as the dashboard, from the contracts alone', () async {
      final pending = FakeContractRepository(
        contracts: const [
          StudentContract(
            status: StudentContractStatus.pending,
            canSign: true,
            isCurrent: true,
          ),
        ],
      );
      expect(
        (await withContracts(pending).getContractNotice())?.signed,
        isFalse,
      );
      expect(pending.callCount, 1);

      final signed = FakeContractRepository(
        contracts: const [
          StudentContract(
            status: StudentContractStatus.signed,
            isCurrent: true,
          ),
        ],
      );
      expect((await withContracts(signed).getContractNotice())?.signed, isTrue);

      expect(
        await withContracts(FakeContractRepository()).getContractNotice(),
        isNull,
      );
    });

    test('a failed call throws — unlike the dashboard, which leaves the '
        'banner off', () async {
      final failing = withContracts(
        FakeContractRepository(
          failure: const ContractFailure(ContractFailureKind.network),
        ),
      );

      await expectLater(
        failing.getContractNotice(),
        throwsA(isA<ContractFailure>()),
      );
      expect((await failing.getDashboard()).contract, isNull);
    });
  });

  group('contract (Issue #300)', () {
    Future<HomeDashboard> dashboardWith(FakeContractRepository contracts) =>
        repository(
          enrolled: const [EnrolledCohortSummary(cohortId: 1)],
          cohorts: [sampleCohort(id: 1)],
          contracts: contracts,
        ).getDashboard();

    const pending = StudentContract(
      status: StudentContractStatus.pending,
      canSign: true,
      isCurrent: true,
    );
    const signed = StudentContract(
      status: StudentContractStatus.signed,
      isCurrent: true,
    );
    const cancelled = StudentContract(status: StudentContractStatus.cancelled);

    test('a signable pending contract is unsigned', () async {
      final contracts = FakeContractRepository(contracts: [signed, pending]);
      final dashboard = await dashboardWith(contracts);

      expect(dashboard.contract?.signed, isFalse);
      expect(contracts.callCount, 1);
    });

    test('with none signable, the newest current one — signed', () async {
      final dashboard = await dashboardWith(
        FakeContractRepository(contracts: [cancelled, signed]),
      );

      expect(dashboard.contract?.signed, isTrue);
    });

    test('only cancelled contracts: nothing to report', () async {
      final dashboard = await dashboardWith(
        FakeContractRepository(contracts: [cancelled]),
      );

      expect(dashboard.contract, isNull);
    });

    test('no contracts: nothing to report', () async {
      expect((await dashboardWith(FakeContractRepository())).contract, isNull);
    });

    test('a selected contract with a status this build does not know is '
        'not read as unsigned', () async {
      final dashboard = await dashboardWith(
        FakeContractRepository(
          contracts: const [StudentContract(canSign: true, isCurrent: true)],
        ),
      );

      expect(dashboard.contract, isNull);
    });

    test(
      'a failed contract call leaves the banner off, not the dashboard',
      () async {
        final dashboard = await dashboardWith(
          FakeContractRepository(
            failure: const ContractFailure(ContractFailureKind.server),
          ),
        );

        expect(dashboard.contract, isNull);
        expect(dashboard.program, isNotNull);
      },
    );

    test('is not requested when the student is enrolled nowhere', () async {
      final contracts = FakeContractRepository(contracts: [pending]);
      final dashboard = await repository(
        enrolled: const [],
        cohorts: [sampleCohort(id: 1)],
        contracts: contracts,
      ).getDashboard();

      expect(dashboard.isEmpty, isTrue);
      expect(contracts.callCount, 0);
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
      DateTime? now,
    }) => repository(
      enrolled: const [EnrolledCohortSummary(cohortId: 1)],
      cohorts: [sampleCohort(id: 1)],
      courses: courses,
      ledger: ledger,
      attendance: attendance,
      now: now,
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

    test('future null-status and absent sessions keep the card, unmarked '
        '(Issue #170)', () async {
      // The adult corp.s01 shape: past present/late/absent sessions, and
      // sessions not held yet with a null status — seen on 5 October, so
      // the 1 October absent is over (Issue #475) and the rest are to come.
      final dashboard = await dashboardWith(
        now: DateTime(2026, 10, 5, 9),
        attendance: FakeAttendanceRepository(
          attendance: CourseAttendance(
            attended: 2,
            totalPast: 3,
            percent: 66,
            sessions: [
              AttendanceSession(date: DateTime(2026, 9, 24), status: 'present'),
              AttendanceSession(date: DateTime(2026, 8, 20), status: 'late'),
              AttendanceSession(date: DateTime(2026, 10, 1), status: 'absent'),
              AttendanceSession(date: DateTime(2026, 10, 8), status: null),
              AttendanceSession(date: DateTime(2026, 10, 15), status: null),
            ],
          ),
        ),
      );

      final attendance = attendanceOf(dashboard)!;
      expect(attendance.attendedDates, {
        DateTime(2026, 9, 24),
        DateTime(2026, 8, 20),
      });
      // `absent` is missed (Issue #172); the null-status days are neither.
      expect(attendance.missedDates, {DateTime(2026, 10, 1)});
      expect(attendance.attended, 2);
      expect(attendance.total, 3);
      expect(attendance.percent, 66);
    });

    test('today\'s absent is not missed until the session has ended '
        '(Issue #475)', () async {
      // The backend reports today's unrecorded session `absent` from
      // midnight. Ulaanbaatar wall-clock times; the clock here is UTC.
      Future<Set<DateTime>> missedAt(DateTime now) async {
        final dashboard = await dashboardWith(
          now: now,
          attendance: FakeAttendanceRepository(
            attendance: CourseAttendance(
              attended: 0,
              totalPast: 2,
              percent: 0,
              sessions: [
                AttendanceSession(
                  date: DateTime(2026, 10, 19),
                  status: 'absent',
                  startTime: '18:30',
                  endTime: '21:30',
                ),
                AttendanceSession(
                  date: DateTime(2026, 10, 20),
                  status: 'absent',
                  startTime: '18:30',
                  endTime: '21:30',
                ),
              ],
            ),
          ),
        );
        return attendanceOf(dashboard)!.missedDates;
      }

      // 20 October, 10:00 in Ulaanbaatar: yesterday's is missed, today's
      // has not even started.
      expect(await missedAt(DateTime.utc(2026, 10, 20, 2)), {
        DateTime(2026, 10, 19),
      });
      // 20:00, under way: still not missed.
      expect(await missedAt(DateTime.utc(2026, 10, 20, 12)), {
        DateTime(2026, 10, 19),
      });
      // 21:30, over: missed.
      expect(await missedAt(DateTime.utc(2026, 10, 20, 13, 30)), {
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
      });
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

  // Issue #495: the cohort is chosen by its dates against the Ulaanbaatar
  // date — never by `status`, which the backend sends only as `draft`,
  // `open` or `closed`.
  group('which cohort', () {
    /// Noon in Ulaanbaatar on [day] of October 2026 (04:00 UTC).
    DateTime ubNoonOct(int day) => DateTime.utc(2026, 10, day, 4);

    Future<int?> chosenAt(DateTime now, List<Cohort> cohorts) async {
      final dashboard = await repository(
        enrolled: [
          for (final cohort in cohorts)
            EnrolledCohortSummary(cohortId: cohort.id),
        ],
        cohorts: cohorts,
        now: now,
      ).getDashboard();
      return dashboard.program?.cohortId;
    }

    Cohort dated(int id, String start, String end, {String status = 'open'}) =>
        sampleCohort(
          id: id,
          name: 'Cohort $id',
          status: status,
          startDate: start,
          endDate: end,
        );

    test('an in-progress cohort wins over an ended one, in either list '
        'order', () async {
      final ended = dated(1, '2026-06-01', '2026-07-31', status: 'closed');
      final current = dated(2, '2026-09-01', '2026-12-20');

      expect(await chosenAt(ubNoonOct(15), [ended, current]), 2);
      expect(await chosenAt(ubNoonOct(15), [current, ended]), 2);
    });

    test('with only upcoming cohorts, the earliest start wins', () async {
      expect(
        await chosenAt(ubNoonOct(15), [
          dated(1, '2027-03-01', '2027-05-01'),
          dated(2, '2026-11-01', '2027-01-01'),
          dated(3, '2027-01-10', '2027-02-10'),
        ]),
        2,
      );
    });

    test('with only ended cohorts, the latest end wins', () async {
      expect(
        await chosenAt(ubNoonOct(15), [
          dated(1, '2026-01-01', '2026-03-01', status: 'closed'),
          dated(2, '2026-05-01', '2026-09-30', status: 'closed'),
          dated(3, '2026-04-01', '2026-06-01', status: 'closed'),
        ]),
        2,
      );
    });

    test('an upcoming cohort wins over an ended one', () async {
      expect(
        await chosenAt(ubNoonOct(15), [
          dated(1, '2026-05-01', '2026-09-30', status: 'closed'),
          dated(2, '2026-11-01', '2027-01-01'),
        ]),
        2,
      );
    });

    test('a single enrolled cohort is chosen whatever its dates', () async {
      for (final cohort in [
        dated(1, '2026-09-01', '2026-12-20'),
        dated(1, '2027-01-01', '2027-02-01'),
        dated(1, '2026-01-01', '2026-02-01', status: 'closed'),
        dated(1, '', ''),
      ]) {
        expect(await chosenAt(ubNoonOct(15), [cohort]), 1);
      }
    });

    test(
      'cohorts with no usable dates fall back to the first listed',
      () async {
        expect(
          await chosenAt(ubNoonOct(15), [
            dated(4, '', ''),
            dated(2, 'soon', 'later'),
          ]),
          4,
        );
      },
    );

    test('a known start with no end is in progress once started', () async {
      final openEnded = dated(2, '2026-09-01', '');
      final ended = dated(1, '2026-05-01', '2026-09-30', status: 'closed');

      expect(await chosenAt(ubNoonOct(15), [ended, openEnded]), 2);
      // Not started yet: upcoming, not in progress.
      final later = dated(3, '2026-11-01', '');
      final current = dated(4, '2026-09-01', '2026-12-20');
      expect(await chosenAt(ubNoonOct(15), [later, current]), 4);
    });

    test('a known end with no start is in progress through its end', () async {
      final noStart = dated(2, '', '2026-10-20');
      final ended = dated(1, '2026-05-01', '2026-09-30', status: 'closed');

      expect(await chosenAt(ubNoonOct(15), [ended, noStart]), 2);
      // After its end it counts as ended — the latest end still wins.
      expect(await chosenAt(ubNoonOct(25), [ended, noStart]), 2);
    });

    test('several in progress: the first listed wins, not the latest '
        'start', () async {
      expect(
        await chosenAt(ubNoonOct(15), [
          dated(1, '2026-08-01', '2026-12-20'),
          dated(2, '2026-10-01', '2026-12-20'),
        ]),
        1,
      );
    });

    test('the end date counts through the last Ulaanbaatar day', () async {
      final endsOct6 = dated(1, '2026-09-01', '2026-10-06');
      final upcoming = dated(2, '2026-12-01', '2027-01-01');

      // 23:59 on 6 October in Ulaanbaatar: still in progress.
      expect(
        await chosenAt(DateTime.utc(2026, 10, 6, 15, 59), [upcoming, endsOct6]),
        1,
      );
      // 00:00 on 7 October in Ulaanbaatar: ended, so the upcoming one wins.
      expect(
        await chosenAt(DateTime.utc(2026, 10, 6, 16), [upcoming, endsOct6]),
        2,
      );
    });

    test('a start that is tomorrow in Ulaanbaatar is upcoming even while '
        'UTC is still on the day before', () async {
      final startsOct7 = dated(2, '2026-10-07', '2026-12-20');
      final ended = dated(1, '2026-05-01', '2026-09-30', status: 'closed');
      // 15:00 UTC on 6 October is 23:00 on 6 October in Ulaanbaatar:
      // `2026-10-07` has not started, so it is upcoming, not in progress.
      expect(
        await chosenAt(DateTime.utc(2026, 10, 6, 15), [ended, startsOct7]),
        2,
      );
      // 16:00 UTC on 6 October is already 7 October in Ulaanbaatar.
      final other = dated(3, '2026-10-01', '2026-12-20');
      expect(
        await chosenAt(DateTime.utc(2026, 10, 6, 15), [startsOct7, other]),
        3,
      );
      expect(
        await chosenAt(DateTime.utc(2026, 10, 6, 16), [startsOct7, other]),
        2,
      );
    });

    test(
      'between equally placed cohorts, the first enrolled one listed wins',
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
        contracts: FakeContractRepository(),
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

  // Issue #445: `GET /cohorts` reads row by row. An unrelated malformed
  // cohort is not listed; one that may be the student's own fails closed.
  group('malformed cohort rows', () {
    const unreadableTeacher = 'cohort.teacher: expected an object, got String';

    Matcher serverFailure() => throwsA(
      isA<HomeFailure>().having((f) => f.kind, 'kind', HomeFailureKind.server),
    );

    test('an unrelated malformed cohort still loads the dashboard', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1, progressPct: 40)],
        cohorts: [sampleCohort(id: 1)],
        skipped: const [SkippedCohort(id: 2, reason: unreadableTeacher)],
      ).getDashboard();

      expect(dashboard.program!.cohortId, 1);
      expect(dashboard.program!.progress!.percent, 40);
    });

    test('the student\'s own malformed cohort is a server failure, not the '
        'empty dashboard', () async {
      await expectLater(
        repository(
          enrolled: const [EnrolledCohortSummary(cohortId: 2)],
          cohorts: [sampleCohort(id: 1)],
          skipped: const [SkippedCohort(id: 2, reason: unreadableTeacher)],
        ).getDashboard(),
        serverFailure(),
      );
    });

    test('one of two enrolled cohorts malformed still fails closed', () async {
      await expectLater(
        repository(
          enrolled: const [
            EnrolledCohortSummary(cohortId: 1),
            EnrolledCohortSummary(cohortId: 2),
          ],
          cohorts: [sampleCohort(id: 1)],
          skipped: const [SkippedCohort(id: 2, reason: unreadableTeacher)],
        ).getDashboard(),
        serverFailure(),
      );
    });

    test('a row with an unreadable id fails closed while the student\'s '
        'cohort is not among the valid rows — it might be that row', () async {
      await expectLater(
        repository(
          enrolled: const [EnrolledCohortSummary(cohortId: 2)],
          cohorts: [sampleCohort(id: 1)],
          skipped: const [SkippedCohort(id: null, reason: 'cohort.id')],
        ).getDashboard(),
        serverFailure(),
      );
    });

    test('a row with an unreadable id is harmless once the student\'s '
        'cohort is listed', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1)],
        skipped: const [SkippedCohort(id: null, reason: 'cohort.id')],
      ).getDashboard();

      expect(dashboard.program!.cohortId, 1);
    });

    test('enrolled nowhere: a malformed cohort still gives the empty '
        'dashboard', () async {
      final dashboard = await repository(
        enrolled: const [],
        cohorts: const [],
        skipped: const [SkippedCohort(id: null, reason: 'cohort.id')],
      ).getDashboard();

      expect(dashboard.isEmpty, isTrue);
    });
  });
}
