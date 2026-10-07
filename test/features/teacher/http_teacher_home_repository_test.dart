import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:aia_mobile/features/teacher/data/http_teacher_home_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../courses/fake_course_repository.dart';
import '../profile/fake_current_user_repository.dart';
import 'fake_teacher_home_repository.dart';

http.Response jsonResponse(String body, int statusCode) => http.Response(
  body,
  statusCode,
  headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
);

/// The verified `GET /teachers/{teacher_id}/schedule` shape: `{teacher_id,
/// cohorts}`, each cohort in `GET /cohorts`'s shape. Values are test values,
/// not the live account's.
String scheduleBody({int teacherId = 7, List<Object?>? cohorts}) => jsonEncode({
  'teacher_id': teacherId,
  'cohorts':
      cohorts ??
      [
        {
          'capacity': 30,
          'classroom': {'center_name': 'Center', 'id': 3, 'name': 'Room 204'},
          'course': {
            'id': 8,
            'slug': 'ai-engineering',
            'title_en': 'AI Engineer',
            'title_mn': null,
          },
          'course_id': 8,
          'end_date': '2026-12-20',
          'end_time': '17:00',
          'enrolled_count': 24,
          'graduation_date': '2026-12-25',
          'id': 2,
          'meeting_days': ['tue', 'thu'],
          'name': 'Cohort 01',
          'parent_cohort_id': null,
          'schedule_note': null,
          'seats_available': 6,
          'start_date': '2026-09-01',
          'start_time': '14:00',
          'status': 'open',
          'teacher': {'id': 7, 'name': 'Test Teacher'},
        },
      ],
});

void main() {
  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  HttpTeacherHomeRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
    FakeCurrentUserRepository? currentUser,
    FakeCourseRepository? courses,
  }) => HttpTeacherHomeRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
    currentUser: currentUser ?? FakeCurrentUserRepository(user: teacherUser()),
    courses:
        courses ??
        FakeCourseRepository(courses: [sampleCourse(id: 8, level: 'adult')]),
  );

  Future<TeacherFailure> failureFrom(HttpTeacherHomeRepository repo) async {
    try {
      await repo.getClasses();
    } on TeacherFailure catch (failure) {
      return failure;
    }
    fail('expected a TeacherFailure');
  }

  group('the request', () {
    test('GETs the schedule of the signed-in teacher\'s actor_id', () async {
      late http.Request sent;
      final repository = repositoryReturning(
        (request) async {
          sent = request;
          return jsonResponse(scheduleBody(teacherId: 42), 200);
        },
        currentUser: FakeCurrentUserRepository(user: teacherUser(actorId: 42)),
      );

      await repository.getClasses();

      expect(sent.method, 'GET');
      expect(
        sent.url.toString(),
        'https://api.ai-academy.asia/teachers/42/schedule',
      );
      expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
    });

    test('sends nothing without a session', () async {
      var sent = false;
      final currentUser = FakeCurrentUserRepository(user: teacherUser());
      final repository = repositoryReturning(
        (_) async {
          sent = true;
          return jsonResponse(scheduleBody(), 200);
        },
        sessionStore: AuthSessionStore(),
        currentUser: currentUser,
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, TeacherFailureKind.sessionExpired);
      expect(sent, isFalse);
      expect(currentUser.callCount, 0);
    });

    test(
      'refuses a non-teacher account without asking for a schedule',
      () async {
        var sent = false;
        final repository = repositoryReturning(
          (_) async {
            sent = true;
            return jsonResponse(scheduleBody(), 200);
          },
          // The default fake user is a student.
          currentUser: FakeCurrentUserRepository(),
        );

        final failure = await failureFrom(repository);

        expect(failure.kind, TeacherFailureKind.rejected);
        expect(sent, isFalse);
      },
    );

    test('carries a /auth/me failure through as its own kind', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(scheduleBody(), 200),
        currentUser: FakeCurrentUserRepository(
          failure: const CurrentUserFailure(CurrentUserFailureKind.network),
        ),
      );

      expect((await failureFrom(repository)).kind, TeacherFailureKind.network);
    });
  });

  group('a successful response', () {
    test('reads each cohort and its course\'s track', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(scheduleBody(), 200),
      );

      final classes = await repository.getClasses();

      final only = classes.single;
      expect(only.cohort.id, 2);
      expect(only.cohort.name, 'Cohort 01');
      expect(only.cohort.course.title.preferred, 'AI Engineer');
      expect(only.cohort.classroom?.name, 'Room 204');
      expect(only.cohort.enrolledCount, 24);
      expect(only.cohort.startTime, '14:00');
      expect(only.cohort.endTime, '17:00');
      expect(only.cohort.meetingDays, ['tue', 'thu']);
      expect(only.track, 'adult');
    });

    test('an empty cohorts list is no classes, not a failure', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(scheduleBody(cohorts: []), 200),
      );

      expect(await repository.getClasses(), isEmpty);
    });

    test('a catalog that cannot be read leaves the track off', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(scheduleBody(), 200),
        courses: FakeCourseRepository(
          failure: const ApiFailure(ApiFailureKind.network),
        ),
      );

      final classes = await repository.getClasses();

      expect(classes.single.track, isNull);
    });

    test('a course the catalog does not list has no track', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse(scheduleBody(), 200),
        courses: FakeCourseRepository(courses: [sampleCourse(id: 99)]),
      );

      expect((await repository.getClasses()).single.track, isNull);
    });
  });

  group('a failed response', () {
    test('401 is an expired session, and the token is forgotten', () async {
      final store = signedIn();
      final repository = repositoryReturning(
        (_) async => jsonResponse('{"error":"unauthorized"}', 401),
        sessionStore: store,
      );

      expect(
        (await failureFrom(repository)).kind,
        TeacherFailureKind.sessionExpired,
      );
      expect(store.isSignedIn, isFalse);
    });

    test('403 and 404 are rejected', () async {
      for (final status in [403, 404]) {
        final repository = repositoryReturning(
          (_) async => jsonResponse('{"error":"forbidden"}', status),
        );
        expect(
          (await failureFrom(repository)).kind,
          TeacherFailureKind.rejected,
          reason: 'HTTP $status',
        );
      }
    });

    test('5xx is a server failure', () async {
      final repository = repositoryReturning(
        (_) async => jsonResponse('oops', 502),
      );

      expect((await failureFrom(repository)).kind, TeacherFailureKind.server);
    });

    test('a request that never completes is a network failure', () async {
      final repository = repositoryReturning(
        (_) async => throw const SocketException('offline'),
      );

      expect((await failureFrom(repository)).kind, TeacherFailureKind.network);
    });

    test('a body off the verified shape is a server failure', () async {
      for (final body in [
        'not json',
        '[]',
        '{"teacher_id": 7}',
        '{"teacher_id": 7, "cohorts": [{"id": 2}]}',
      ]) {
        final repository = repositoryReturning(
          (_) async => jsonResponse(body, 200),
        );
        expect(
          (await failureFrom(repository)).kind,
          TeacherFailureKind.server,
          reason: body,
        );
      }
    });
  });
}
