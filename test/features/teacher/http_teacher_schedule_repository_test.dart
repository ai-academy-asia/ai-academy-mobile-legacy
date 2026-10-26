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

/// One item of `GET /teacher/sessions` (Issue #455, contract §6). Test
/// values only.
Map<String, Object?> assignedItem({
  int id = 41,
  String type = 'regular',
  Object? coveredBy,
  Object? originalTeacher,
  Object? requestId,
  Object? date = '2026-10-06',
  Object? start = '14:00',
  Object? end = '17:00',
  Object? title = 'Corporate Leaders',
}) => {
  'id': id,
  'cohort_id': 7,
  'cohort_name': 'CL-2026-10',
  'title': title,
  'topic_id': null,
  'topic': null,
  'date': date,
  'start_time': start,
  'end_time': end,
  'room': 'Room 204',
  'assignment_type': type,
  'request_id': requestId,
  'original_teacher': originalTeacher,
  'covered_by': coveredBy,
};

String assignedBody(List<Object?> items) =>
    jsonEncode({'from': '2026-10-04', 'to': '2026-10-10', 'items': items});

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

    test('a session with no end time (null) reads, with its start alone '
        '(Issue #479)', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(
          sessionsBody(
            sessions: [
              {
                'id': 41,
                'cohort_id': 2,
                'topic_id': null,
                'session_date': '2026-10-06',
                'start_time': '18:30',
                'end_time': null,
                'created_at': '2026-09-28T03:56:11',
              },
            ],
          ),
          200,
        ),
      );

      final sessions = await repo.getSessions(
        cohortId: 2,
        from: DateTime(2026, 10, 4),
        to: DateTime(2026, 10, 11),
      );

      expect(sessions.single.start, (18, 30));
      expect(sessions.single.end, isNull);
      expect(sessions.single.timeLabel, '18:30');
    });

    test('a session off the verified shape is a server failure', () async {
      for (final bad in [
        {'id': 1, 'cohort_id': 2, 'session_date': '2026-10-06'},
        // An end time may be null, but never unreadable or another type.
        {
          'id': 1,
          'cohort_id': 2,
          'session_date': '2026-10-06',
          'start_time': '14:00',
          'end_time': '25:00',
        },
        {
          'id': 1,
          'cohort_id': 2,
          'session_date': '2026-10-06',
          'start_time': '14:00',
          'end_time': 17,
        },
        {
          'id': 1,
          'cohort_id': 2,
          'session_date': '2026-10-06',
          'start_time': null,
          'end_time': '17:00',
        },
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

  // Issue #455: the teacher's own sessions and covers for a range.
  group('getAssignedSessions', () {
    test('GETs /teacher/sessions with from and to as YYYY-MM-DD, the week\'s '
        'first and last day, with the token', () async {
      late http.Request sent;
      final repo = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(assignedBody([]), 200);
      });

      final items = await repo.getAssignedSessions(
        from: DateTime(2026, 10, 4),
        to: DateTime(2026, 10, 10),
      );

      expect(items, isEmpty);
      expect(sent.method, 'GET');
      expect(sent.url.path, '/teacher/sessions');
      expect(sent.url.queryParameters, {
        'from': '2026-10-04',
        'to': '2026-10-10',
      });
      expect(sent.headers['Authorization'], 'Bearer tok-123');
    });

    test('reads regular (own), covered and covering items', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(
          assignedBody([
            assignedItem(id: 41),
            assignedItem(
              id: 42,
              coveredBy: {'id': 5, 'name': 'Болд Бат', 'photo_url': null},
            ),
            assignedItem(
              id: 77,
              type: 'covering',
              requestId: 12,
              originalTeacher: {'id': 3, 'name': 'Анар Бат', 'photo_url': null},
              date: '2026-10-08',
              start: '09:00',
              end: '11:00',
            ),
          ]),
          200,
        ),
      );

      final items = await repo.getAssignedSessions(
        from: DateTime(2026, 10, 4),
        to: DateTime(2026, 10, 10),
      );

      expect([for (final i in items) i.sessionId], [41, 42, 77]);
      expect(items[0].isCovering, isFalse);
      expect(items[0].coveredBy, isNull);
      expect(items[0].session, isNull);
      expect(items[1].coveredBy, 'Болд Бат');
      final covering = items[2];
      expect(covering.isCovering, isTrue);
      expect(covering.session!.id, 77);
      expect(covering.session!.date, DateTime(2026, 10, 8));
      expect(covering.session!.start, (9, 0));
      expect(covering.session!.end, (11, 0));
      expect(covering.covering!.requestId, 12);
      expect(covering.covering!.courseTitle, 'Corporate Leaders');
      expect(covering.covering!.cohortName, 'CL-2026-10');
      expect(covering.covering!.room, 'Room 204');
      expect(covering.covering!.originalTeacher, 'Анар Бат');
    });

    test('a blank name keeps a covered session covered, unnamed; a blank '
        'original teacher reads as none (Issue #537)', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(
          assignedBody([
            assignedItem(
              id: 42,
              coveredBy: {'id': 5, 'name': '  ', 'photo_url': null},
            ),
            assignedItem(
              id: 77,
              type: 'covering',
              requestId: 12,
              originalTeacher: {'id': 3, 'name': '', 'photo_url': null},
            ),
            assignedItem(
              id: 43,
              coveredBy: {'id': 6, 'name': 'Болд Бат', 'photo_url': null},
            ),
          ]),
          200,
        ),
      );

      final items = await repo.getAssignedSessions(
        from: DateTime(2026, 10, 4),
        to: DateTime(2026, 10, 10),
      );

      expect([for (final i in items) i.sessionId], [42, 77, 43]);
      // Still covered: `coveredBy != null` is what marks it.
      expect(items[0].coveredBy, isNotNull);
      expect(items[0].coveredBy, '');
      expect(items[1].covering!.originalTeacher, isNull);
      expect(items[1].covering!.requestId, 12);
      expect(items[1].covering!.room, 'Room 204');
      expect(items[2].coveredBy, 'Болд Бат');
    });

    test('a covering item may name no course or original teacher', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(
          assignedBody([
            assignedItem(id: 77, type: 'covering', requestId: 12, title: null),
          ]),
          200,
        ),
      );

      final item = (await repo.getAssignedSessions(
        from: DateTime(2026, 10, 4),
        to: DateTime(2026, 10, 10),
      )).single;
      expect(item.covering!.courseTitle, isNull);
      expect(item.covering!.originalTeacher, isNull);
    });

    test('a covering item with no end time reads, with its start alone '
        '(Issue #479)', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(
          assignedBody([
            assignedItem(type: 'covering', requestId: 12, end: null),
          ]),
          200,
        ),
      );

      final items = await repo.getAssignedSessions(
        from: DateTime(2026, 10, 4),
        to: DateTime(2026, 10, 10),
      );

      final session = items.single.session!;
      expect(session.end, isNull);
      expect(session.timeLabel, '14:00');
    });

    test('a body off the documented shape is a server failure', () async {
      final bodies = <String, String>{
        'no items': jsonEncode({'from': '2026-10-04', 'to': '2026-10-10'}),
        'an item not an object': assignedBody(['x']),
        'an unknown assignment_type': assignedBody([
          assignedItem(type: 'substitute'),
        ]),
        'covered_by without a name': assignedBody([
          assignedItem(coveredBy: {'id': 5}),
        ]),
        'covered_by with a numeric name': assignedBody([
          assignedItem(coveredBy: {'id': 5, 'name': 5}),
        ]),
        'covering without request_id': assignedBody([
          assignedItem(type: 'covering'),
        ]),
        'covering with an unreadable end time': assignedBody([
          assignedItem(type: 'covering', requestId: 12, end: '25:00'),
        ]),
        'covering with an unreadable date': assignedBody([
          assignedItem(type: 'covering', requestId: 12, date: 'soon'),
        ]),
        'covering with a numeric title': assignedBody([
          assignedItem(type: 'covering', requestId: 12, title: 3),
        ]),
        'malformed JSON': '<html></html>',
      };
      for (final entry in bodies.entries) {
        final failure = await failureOf(
          repositoryReturning(
            (_) async => jsonResponse(entry.value, 200),
          ).getAssignedSessions(
            from: DateTime(2026, 10, 4),
            to: DateTime(2026, 10, 10),
          ),
        );
        expect(failure.kind, TeacherFailureKind.server, reason: entry.key);
      }
    });

    test('errors: 401 expires the session, 5xx is the server, offline is '
        'the network; without a session nothing is sent', () async {
      Future<TeacherFailure> of(
        Future<http.Response> Function(http.Request) handler, {
        AuthSessionStore? store,
      }) => failureOf(
        repositoryReturning(handler, sessionStore: store).getAssignedSessions(
          from: DateTime(2026, 10, 4),
          to: DateTime(2026, 10, 10),
        ),
      );

      expect(
        (await of((_) async => jsonResponse('{}', 401))).kind,
        TeacherFailureKind.sessionExpired,
      );
      expect(
        (await of((_) async => jsonResponse('{}', 503))).kind,
        TeacherFailureKind.server,
      );
      expect(
        (await of((_) async => throw http.ClientException('offline'))).kind,
        TeacherFailureKind.network,
      );
      var sent = 0;
      final none = await of((_) async {
        sent++;
        return jsonResponse(assignedBody([]), 200);
      }, store: AuthSessionStore());
      expect(none.kind, TeacherFailureKind.sessionExpired);
      expect(sent, 0);
    });
  });
}
