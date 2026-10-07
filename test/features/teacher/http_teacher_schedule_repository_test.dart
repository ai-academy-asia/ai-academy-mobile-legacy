import 'dart:convert';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/teacher/data/http_teacher_schedule_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_teacher_home_repository.dart';
import 'http_teacher_home_repository_test.dart' show jsonResponse;
import 'teacher_home_screen_test.dart' show sampleClass;

/// The verified `GET /teacher/cohorts/{id}/sessions` shape. Test values.
String sessionsBody({List<Object?>? sessions}) => jsonEncode({
  'cohort_id': 2,
  'sessions':
      sessions ??
      [
        {
          'id': 41,
          'cohort_id': 2,
          'session_date': '2026-10-06',
          'start_time': '14:00',
          'end_time': '17:00',
          'topic_id': 5,
          'created_at': '2026-09-01T02:00:00Z',
        },
      ],
});

/// The verified `GET /teacher/sessions/{id}/attendance` shape. Test values.
String attendanceBody({Object? counts}) => jsonEncode({
  'session': {'id': 41},
  'counts': counts ?? {'present': 12, 'late': 2, 'absent': 9, 'excused': 1},
  'students': [
    {
      'student_id': 1,
      'name': 'A',
      'status': 'absent',
      'method': null,
      'checked_in_at': null,
    },
  ],
});

void main() {
  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  HttpTeacherScheduleRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpTeacherScheduleRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
    classes: FakeTeacherHomeRepository(classes: [sampleClass()]),
  );

  Future<TeacherFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on TeacherFailure catch (failure) {
      return failure;
    }
    fail('expected a TeacherFailure');
  }

  group('getSessions', () {
    test('asks the cohort\'s sessions for the range, with the token', () async {
      late http.Request sent;
      final repo = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(sessionsBody(), 200);
      });

      final sessions = await repo.getSessions(
        cohortId: 2,
        from: DateTime(2026, 10, 4),
        to: DateTime(2026, 10, 11),
      );

      expect(sent.method, 'GET');
      expect(sent.url.path, '/teacher/cohorts/2/sessions');
      expect(sent.url.queryParameters, {
        'from': '2026-10-04',
        'to': '2026-10-11',
      });
      expect(sent.headers['Authorization'], 'Bearer tok-123');

      expect(sessions, hasLength(1));
      final session = sessions.single;
      expect(session.id, 41);
      expect(session.cohortId, 2);
      expect(session.date, DateTime(2026, 10, 6));
      expect(session.start, (14, 0));
      expect(session.end, (17, 0));
      expect(session.startsAt, DateTime(2026, 10, 6, 14));
      expect(session.endsAt, DateTime(2026, 10, 6, 17));
      expect(session.startLabel, '14:00');
      expect(session.endLabel, '17:00');
    });

    test('an empty list is no sessions', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(sessionsBody(sessions: []), 200),
      );
      final sessions = await repo.getSessions(
        cohortId: 2,
        from: DateTime(2026, 10, 4),
        to: DateTime(2026, 10, 11),
      );
      expect(sessions, isEmpty);
    });

    test('a session off the verified shape is a server failure', () async {
      for (final bad in [
        {'id': 1, 'cohort_id': 2, 'session_date': '2026-10-06'},
        {
          'id': 1,
          'cohort_id': 2,
          'session_date': 'soon',
          'start_time': '14:00',
          'end_time': '17:00',
        },
        {
          'id': '1',
          'cohort_id': 2,
          'session_date': '2026-10-06',
          'start_time': '14:00',
          'end_time': '17:00',
        },
      ]) {
        final repo = repositoryReturning(
          (_) async => jsonResponse(sessionsBody(sessions: [bad]), 200),
        );
        final failure = await failureOf(
          repo.getSessions(
            cohortId: 2,
            from: DateTime(2026, 10, 4),
            to: DateTime(2026, 10, 11),
          ),
        );
        expect(failure.kind, TeacherFailureKind.server, reason: '$bad');
      }
    });

    test(
      'maps statuses to failure kinds, and a 401 clears the session',
      () async {
        for (final (status, kind) in [
          (401, TeacherFailureKind.sessionExpired),
          (403, TeacherFailureKind.rejected),
          (404, TeacherFailureKind.rejected),
          (500, TeacherFailureKind.server),
        ]) {
          final store = signedIn();
          final repo = repositoryReturning(
            (_) async => jsonResponse('{}', status),
            sessionStore: store,
          );
          final failure = await failureOf(
            repo.getSessions(
              cohortId: 2,
              from: DateTime(2026, 10, 4),
              to: DateTime(2026, 10, 11),
            ),
          );
          expect(failure.kind, kind, reason: 'HTTP $status');
          expect(store.isSignedIn, status != 401, reason: 'HTTP $status');
        }
      },
    );

    test('sends nothing without a session', () async {
      var sent = false;
      final repo = repositoryReturning((_) async {
        sent = true;
        return jsonResponse(sessionsBody(), 200);
      }, sessionStore: AuthSessionStore());

      final failure = await failureOf(
        repo.getSessions(
          cohortId: 2,
          from: DateTime(2026, 10, 4),
          to: DateTime(2026, 10, 11),
        ),
      );
      expect(failure.kind, TeacherFailureKind.sessionExpired);
      expect(sent, isFalse);
    });
  });

  group('getAttendance', () {
    test('reads the session\'s counts', () async {
      late http.Request sent;
      final repo = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(attendanceBody(), 200);
      });

      final counts = await repo.getAttendance(41);

      expect(sent.url.path, '/teacher/sessions/41/attendance');
      expect(sent.headers['Authorization'], 'Bearer tok-123');
      expect(counts.present, 12);
      expect(counts.late, 2);
      expect(counts.absent, 9);
      expect(counts.excused, 1);
      expect(counts.attended, 14);
      expect(counts.total, 24);
    });

    test('counts off the verified shape are a server failure', () async {
      for (final bad in [
        null,
        {'present': 1, 'late': 0, 'absent': 0},
        {'present': '1', 'late': 0, 'absent': 0, 'excused': 0},
      ]) {
        final repo = repositoryReturning(
          (_) async => jsonResponse(
            bad == null
                ? jsonEncode({'session': {}, 'students': []})
                : attendanceBody(counts: bad),
            200,
          ),
        );
        final failure = await failureOf(repo.getAttendance(41));
        expect(failure.kind, TeacherFailureKind.server, reason: '$bad');
      }
    });

    test('malformed JSON is a server failure', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse('not json', 200),
      );
      final failure = await failureOf(repo.getAttendance(41));
      expect(failure.kind, TeacherFailureKind.server);
    });
  });

  test('getClasses is Teacher Home\'s own read', () async {
    final repo = repositoryReturning((_) async => jsonResponse('{}', 500));
    final classes = await repo.getClasses();
    expect(classes.single.cohort.name, 'Cohort 01');
  });
}
