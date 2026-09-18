import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
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

/// Exercises how [EnrolledHomeDashboardRepository] maps `GET /me/cohorts`,
/// `GET /cohorts` and `GET /courses` — all three already confirmed and
/// already tested against the wire in their own suites — onto a
/// [HomeDashboard]. Nothing here talks to the network: each dependency is a
/// fake, so this is purely about the composition.
void main() {
  EnrolledHomeDashboardRepository repository({
    required List<EnrolledCohortSummary> enrolled,
    required List<Cohort> cohorts,
    List<Course> courses = const [],
    DateTime? now,
  }) => EnrolledHomeDashboardRepository(
    enrolledCohorts: FakeEnrolledCohortsRepository(enrolledCohorts: enrolled),
    cohorts: FakeCohortRepository(cohorts: cohorts),
    courses: FakeCourseRepository(courses: courses),
    clock: () => now ?? DateTime(2026, 8, 10, 9),
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

  group('course title and level', () {
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

    test('reads the level from the matching course in the catalog', () async {
      final dashboard = await repository(
        enrolled: const [EnrolledCohortSummary(cohortId: 1)],
        cohorts: [sampleCohort(id: 1, courseId: 6)],
        courses: [sampleCourse(id: 6, level: 'adult')],
      ).getDashboard();

      expect(dashboard.program!.level, 'adult');
    });

    test(
      'leaves the level null when the catalog has no matching course',
      () async {
        final dashboard = await repository(
          enrolled: const [EnrolledCohortSummary(cohortId: 1)],
          cohorts: [sampleCohort(id: 1, courseId: 6)],
          courses: [sampleCourse(id: 999, level: 'adult')],
        ).getDashboard();

        expect(dashboard.program!.level, isNull);
      },
    );

    test(
      'a failed catalog fetch leaves the level null, not the whole dashboard',
      () async {
        final dashboard = await EnrolledHomeDashboardRepository(
          enrolledCohorts: FakeEnrolledCohortsRepository(
            enrolledCohorts: const [EnrolledCohortSummary(cohortId: 1)],
          ),
          cohorts: FakeCohortRepository(cohorts: [sampleCohort(id: 1)]),
          courses: FakeCourseRepository(
            failure: const ApiFailure(ApiFailureKind.server),
          ),
          clock: () => DateTime(2026, 8, 10, 9),
        ).getDashboard();

        expect(dashboard.program, isNotNull);
        expect(dashboard.program!.level, isNull);
      },
    );
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
