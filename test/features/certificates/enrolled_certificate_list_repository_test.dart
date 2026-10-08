import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/features/certificates/data/enrolled_certificate_list_repository.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/course_learning/domain/course_certificate.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/enrollments/domain/enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cohorts/fake_cohort_repository.dart';
import '../course_learning/fake_course_learning_repository.dart';
import '../courses/fake_course_repository.dart';
import '../enrollments/fake_enrolled_cohorts_repository.dart';

/// The Certificate screen's cards (Issue #155), composed from `/me/cohorts`,
/// `/cohorts`, `/courses` and the two §2 course endpoints.
void main() {
  const issued = CourseCertificate(
    status: CertificateStatus.issued,
    issued: IssuedCertificate(certNumber: 'AIAA-1'),
  );

  Cohort cohort(int id, String slug, {String name = 'Cohort 01'}) =>
      sampleCohort(
        id: id,
        name: name,
        course: CohortCourse(
          id: id,
          slug: slug,
          title: LocalizedText(en: 'Course $id', mn: 'Хөтөлбөр $id'),
        ),
      );

  late FakeCourseLearningRepository learning;

  EnrolledCertificateListRepository repository({
    List<EnrolledCohortSummary> enrolled = const [
      EnrolledCohortSummary(cohortId: 1),
    ],
    List<Cohort>? cohorts,
    EnrollmentFailure? enrolledFailure,
    ApiFailure? cohortsFailure,
  }) => EnrolledCertificateListRepository(
    enrolledCohorts: FakeEnrolledCohortsRepository(
      enrolledCohorts: enrolled,
      failure: enrolledFailure,
    ),
    cohorts: FakeCohortRepository(
      cohorts: cohorts ?? [cohort(1, 'ai-basics')],
      failure: cohortsFailure,
    ),
    courses: FakeCourseRepository(),
    courseLearning: learning,
  );

  setUp(() => learning = FakeCourseLearningRepository());

  test(
    'one card per enrolled cohort, with its name, course and slug',
    () async {
      final entries = await repository(
        enrolled: const [
          EnrolledCohortSummary(cohortId: 1),
          EnrolledCohortSummary(cohortId: 3),
        ],
        cohorts: [
          cohort(1, 'ai-basics', name: 'Cohort 01'),
          cohort(2, 'not-mine'),
          cohort(3, 'ml-intro', name: 'Cohort 07'),
        ],
      ).getCertificates();

      expect([for (final e in entries) e.cohortId], [1, 3]);
      expect(entries.first.cohortName, 'Cohort 01');
      expect(entries.first.courseTitle, 'Хөтөлбөр 1');
      expect(entries.first.courseSlug, 'ai-basics');
      expect(
        learning.certificateCalls,
        unorderedEquals(['ai-basics', 'ml-intro']),
      );
    },
  );

  test('an issued certificate needs no progress', () async {
    learning.certificates = {'ai-basics': issued};

    final entry = (await repository().getCertificates()).single;

    expect(entry.certificate.isIssued, isTrue);
    expect(entry.certificate.issued?.certNumber, 'AIAA-1');
    expect(entry.progressPercent, isNull);
    expect(learning.calls, isEmpty);
  });

  test('one not yet issued carries the learning path\'s progress', () async {
    learning.path = samplePath(percentComplete: 42);

    final entry = (await repository().getCertificates()).single;

    expect(entry.progressPercent, 42);
    expect(learning.calls, ['ai-basics']);
  });

  test('without the learning path, /me/cohorts\' progress_pct stands in, '
      'and without either there is no figure', () async {
    learning.failure = const CourseLearningFailure(
      CourseLearningFailureKind.network,
    );

    final withPct = await repository(
      enrolled: const [EnrolledCohortSummary(cohortId: 1, progressPct: 63.6)],
    ).getCertificates();
    expect(withPct.single.progressPercent, 64);

    final without = await repository().getCertificates();
    expect(without.single.progressPercent, isNull);
  });

  test(
    'enrolled in nothing is an empty list, with no certificate asked',
    () async {
      final entries = await repository(enrolled: const []).getCertificates();

      expect(entries, isEmpty);
      expect(learning.certificateCalls, isEmpty);
    },
  );

  test('a failed certificate request fails the list — a card is never drawn '
      'without its status', () async {
    learning.certificateFailure = const CourseLearningFailure(
      CourseLearningFailureKind.server,
    );

    await expectLater(
      repository().getCertificates(),
      throwsA(
        isA<CourseLearningFailure>().having(
          (f) => f.kind,
          'kind',
          CourseLearningFailureKind.server,
        ),
      ),
    );
  });

  test(
    'the enrolment and cohort failures read as course-learning ones',
    () async {
      await expectLater(
        repository(
          enrolledFailure: const EnrollmentFailure(
            EnrollmentFailureKind.sessionExpired,
          ),
        ).getCertificates(),
        throwsA(
          isA<CourseLearningFailure>().having(
            (f) => f.kind,
            'kind',
            CourseLearningFailureKind.sessionExpired,
          ),
        ),
      );
      await expectLater(
        repository(
          cohortsFailure: const ApiFailure(ApiFailureKind.network),
        ).getCertificates(),
        throwsA(
          isA<CourseLearningFailure>().having(
            (f) => f.kind,
            'kind',
            CourseLearningFailureKind.network,
          ),
        ),
      );
    },
  );
}
