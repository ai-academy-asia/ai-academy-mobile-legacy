import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/features/auth/domain/current_user.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/courses/domain/course.dart';
import 'package:aia_mobile/features/enrollments/domain/enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:aia_mobile/features/home/data/enrolled_home_dashboard_repository.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cohorts/fake_cohort_repository.dart';
import '../courses/fake_course_repository.dart';
import '../enrollments/fake_enrolled_cohorts_repository.dart';
import '../profile/fake_current_user_repository.dart';

/// Exercises how [EnrolledHomeDashboardRepository] maps `GET /me/cohorts`,
/// `GET /cohorts`, `GET /courses` and `GET /auth/me` — all four already
/// confirmed and already tested against the wire in their own suites — onto
/// a [HomeDashboard]. Nothing here talks to the network: each dependency is
/// a fake, so this is purely about the composition.
void main() {
  EnrolledHomeDashboardRepository repository({
    required List<EnrolledCohortSummary> enrolled,
    required List<Cohort> cohorts,
    List<Course> courses = const [],
    FakeCurrentUserRepository? currentUser,
    DateTime? now,
  }) => EnrolledHomeDashboardRepository(
    enrolledCohorts: FakeEnrolledCohortsRepository(enrolledCohorts: enrolled),
    cohorts: FakeCohortRepository(cohorts: cohorts),
    courses: FakeCourseRepository(courses: courses),
    currentUser: currentUser ?? FakeCurrentUserRepository(),
    clock: () => now ?? DateTime(2026, 8, 10, 9),
  );

  /// The `/auth/me` account with only its `ui_mode` chosen.
  FakeCurrentUserRepository accountWithUiMode(String uiMode) =>
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
