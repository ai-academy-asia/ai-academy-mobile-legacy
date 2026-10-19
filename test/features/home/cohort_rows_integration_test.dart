import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/certificates/data/enrolled_certificate_list_repository.dart';
import 'package:aia_mobile/features/cohorts/data/http_cohort_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/enrollments/domain/enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/home/data/enrolled_home_dashboard_repository.dart';
import 'package:aia_mobile/features/home/domain/home_failure.dart';
import 'package:aia_mobile/features/payments/domain/ledger_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../attendance/fake_attendance_repository.dart';
import '../contracts/fake_contract_repository.dart';
import '../course_learning/fake_course_learning_repository.dart';
import '../courses/fake_course_repository.dart';
import '../enrollments/fake_enrolled_cohorts_repository.dart';
import '../payments/fake_ledger_repository.dart';
import '../profile/fake_current_user_repository.dart';

/// Issue #445, end to end: a real [HttpCohortRepository] on a `MockClient`
/// feeding Home and Certificates, so the parser's skipped-row ids and the
/// fail-closed check (`CohortListing.mayHideAny`) are proven to agree —
/// the other suites drive each side with a hand-built listing.
void main() {
  /// One `GET /cohorts` row in the confirmed shape. Test values only.
  Map<String, dynamic> row(
    int id, {
    Map<String, dynamic> overrides = const {},
  }) => {
    'id': id,
    'name': 'Cohort $id',
    'course_id': 6,
    'course': {
      'id': 6,
      'slug': 'ai-basics',
      'title_en': 'AI Basics',
      'title_mn': 'AI Үндэс',
    },
    'classroom': null,
    'teacher': {'id': 2, 'name': 'Test Teacher'},
    'capacity': 20,
    'enrolled_count': 1,
    'seats_available': 19,
    'status': 'open',
    'start_date': '2026-08-06',
    'end_date': '2026-10-06',
    'start_time': '18:00',
    'end_time': '20:00',
    'graduation_date': '2026-10-10',
    'meeting_days': ['mon', 'wed'],
    'parent_cohort_id': null,
    'schedule_note': null,
    ...overrides,
  };

  HttpCohortRepository cohortsAnswering(List<Object?> rows) =>
      HttpCohortRepository(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'cohorts': rows}),
            200,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
            },
          ),
        ),
      );

  EnrolledHomeDashboardRepository home(
    List<Object?> rows, {
    required List<int> enrolledIds,
  }) => EnrolledHomeDashboardRepository(
    enrolledCohorts: FakeEnrolledCohortsRepository(
      enrolledCohorts: [
        for (final id in enrolledIds) EnrolledCohortSummary(cohortId: id),
      ],
    ),
    cohorts: cohortsAnswering(rows),
    courses: FakeCourseRepository(),
    currentUser: FakeCurrentUserRepository(),
    courseLearning: FakeCourseLearningRepository(
      failure: const CourseLearningFailure(
        CourseLearningFailureKind.notEnrolled,
      ),
    ),
    ledger: FakeLedgerRepository(
      failure: const LedgerFailure(LedgerFailureKind.network),
    ),
    attendance: FakeAttendanceRepository(
      failure: const AttendanceFailure(AttendanceFailureKind.network),
    ),
    contracts: FakeContractRepository(),
    clock: () => DateTime(2026, 8, 10, 9),
  );

  EnrolledCertificateListRepository certificates(
    List<Object?> rows, {
    required List<int> enrolledIds,
  }) => EnrolledCertificateListRepository(
    enrolledCohorts: FakeEnrolledCohortsRepository(
      enrolledCohorts: [
        for (final id in enrolledIds) EnrolledCohortSummary(cohortId: id),
      ],
    ),
    cohorts: cohortsAnswering(rows),
    courses: FakeCourseRepository(),
    courseLearning: FakeCourseLearningRepository(),
  );

  Matcher homeServerFailure() => throwsA(
    isA<HomeFailure>().having((f) => f.kind, 'kind', HomeFailureKind.server),
  );

  group('Home', () {
    test(
      'an unrelated row with a null teacher still loads the dashboard',
      () async {
        final dashboard = await home(
          [
            row(1),
            row(2, overrides: {'teacher': null}),
          ],
          enrolledIds: [1],
        ).getDashboard();

        expect(dashboard.program!.cohortId, 1);
      },
    );

    test('the student\'s own row with a bad teacher is a server failure, '
        'whose detail names the row and field, never a value', () async {
      Object? caught;
      try {
        await home(
          [
            row(1),
            row(2, overrides: {'teacher': 'Private Name'}),
          ],
          enrolledIds: [2],
        ).getDashboard();
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<HomeFailure>());
      final failure = caught! as HomeFailure;
      expect(failure.kind, HomeFailureKind.server);
      expect(failure.detail, contains('2: cohort.teacher'));
      expect(failure.detail, isNot(contains('Private Name')));
    });

    test('a row with an unreadable id fails closed while the student\'s '
        'cohort is not among the valid rows', () async {
      await expectLater(
        home(
          [
            row(1),
            row(2, overrides: {'id': '2'}),
          ],
          enrolledIds: [2],
        ).getDashboard(),
        homeServerFailure(),
      );
    });

    test(
      'a non-whole-number id is never read as the student\'s cohort',
      () async {
        await expectLater(
          home(
            [
              row(1),
              row(2, overrides: {'id': 2.5, 'teacher': null}),
            ],
            enrolledIds: [2],
          ).getDashboard(),
          homeServerFailure(),
        );
      },
    );
  });

  group('Certificates', () {
    test(
      'an unrelated malformed row still draws the student\'s card',
      () async {
        final entries = await certificates(
          [
            row(1),
            row(2, overrides: {'meeting_days': null}),
          ],
          enrolledIds: [1],
        ).getCertificates();

        expect([for (final e in entries) e.cohortId], [1]);
      },
    );

    test('the student\'s own malformed row is a server failure, not an empty '
        'list', () async {
      await expectLater(
        certificates(
          [
            row(1),
            row(2, overrides: {'meeting_days': null}),
          ],
          enrolledIds: [2],
        ).getCertificates(),
        throwsA(
          isA<CourseLearningFailure>().having(
            (f) => f.kind,
            'kind',
            CourseLearningFailureKind.server,
          ),
        ),
      );
    });
  });
}
