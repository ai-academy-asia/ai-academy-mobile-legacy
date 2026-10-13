import 'dart:convert';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/teacher/data/http_teacher_attendance_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_attendance.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'http_teacher_home_repository_test.dart' show jsonResponse;

/// Teacher attendance over HTTP (Issue #374), against fake clients only —
/// the shapes are the backend source's (`app/services/attendance/
/// checkin.py`), with test values. No production call is made.

/// The verified `GET /teacher/sessions/{id}/attendance` shape.
String rosterBody({List<Object?>? students, Object? counts}) => jsonEncode({
  'session': {
    'id': 41,
    'cohort_id': 2,
    'topic_id': null,
    'session_date': '2026-10-13',
    'start_time': '14:00',
    'end_time': '17:00',
    'created_at': '2026-09-01T02:00:00',
  },
  'students':
      students ??
      [
        {
          'student_id': 7,
          'name': 'Болд Батаа',
          'status': 'present',
          'method': 'qr',
          'checked_in_at': '2026-10-13T06:01:00',
        },
        {
          'student_id': 8,
          'name': 'Саруул Батбаатар',
          'status': 'late',
          'method': 'qr',
          'checked_in_at': '2026-10-13T06:20:00',
        },
        {
          'student_id': 9,
          'name': 'Ганчимэг Батбаяр',
          'status': 'absent',
          'method': null,
          'checked_in_at': null,
        },
        {
          'student_id': 10,
          'name': 'Анхбаяр Болд',
          'status': 'excused',
          'method': 'manual',
          'checked_in_at': '2026-10-13T05:00:00',
        },
      ],
  'counts': counts ?? {'present': 1, 'late': 1, 'absent': 1, 'excused': 1},
});

void main() {
  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  HttpTeacherAttendanceRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpTeacherAttendanceRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
  );

  Future<TeacherFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on TeacherFailure catch (failure) {
      return failure;
    }
    fail('expected a TeacherFailure');
  }

  group('issueQr', () {
    test('POSTs to the session\'s qr with no body and the token', () async {
      late http.Request sent;
      final repo = repositoryReturning((request) async {
        sent = request;
        return jsonResponse(
          jsonEncode({
            'token': 'abc_DEF-1',
            'expires_at': '2026-10-13T06:05:00',
          }),
          200,
        );
      });

      final token = await repo.issueQr(41);
      expect(sent.method, 'POST');
      expect(sent.url.path, '/teacher/sessions/41/qr');
      expect(sent.body, isEmpty);
      expect(sent.headers['Authorization'], 'Bearer tok-123');
      expect(token.token, 'abc_DEF-1');
      expect(token.expiresAt, DateTime.parse('2026-10-13T06:05:00'));
    });

    test('409 session_not_today is a rejection carrying its code', () async {
      final repo = repositoryReturning(
        (_) async =>
            jsonResponse(jsonEncode({'error': 'session_not_today'}), 409),
      );
      final failure = await failureOf(repo.issueQr(41));
      expect(failure.kind, TeacherFailureKind.rejected);
      expect(failure.code, 'session_not_today');
    });

    test('404 session_not_found keeps its code', () async {
      final repo = repositoryReturning(
        (_) async =>
            jsonResponse(jsonEncode({'error': 'session_not_found'}), 404),
      );
      final failure = await failureOf(repo.issueQr(41));
      expect(failure.kind, TeacherFailureKind.rejected);
      expect(failure.code, 'session_not_found');
    });

    test('a token missing from a 200 is a server failure', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(jsonEncode({'expires_at': 'x'}), 200),
      );
      expect(
        (await failureOf(repo.issueQr(41))).kind,
        TeacherFailureKind.server,
      );
    });
  });

  group('getSessionAttendance', () {
    test(
      'reads every student with each of the four statuses as itself',
      () async {
        late http.Request sent;
        final repo = repositoryReturning((request) async {
          sent = request;
          return jsonResponse(rosterBody(), 200);
        });

        final attendance = await repo.getSessionAttendance(41);
        expect(sent.method, 'GET');
        expect(sent.url.path, '/teacher/sessions/41/attendance');
        expect(sent.headers['Authorization'], 'Bearer tok-123');
        expect(
          [for (final s in attendance.students) s.status],
          [
            AttendanceStatus.present,
            AttendanceStatus.late,
            AttendanceStatus.absent,
            AttendanceStatus.excused,
          ],
        );
        expect(attendance.students.first.name, 'Болд Батаа');
        expect(attendance.students.first.studentId, 7);
        expect(attendance.students.first.method, 'qr');
        expect(attendance.students[2].method, isNull);
        expect(attendance.counts.total, 4);
        expect(attendance.counts.attended, 2);
      },
    );

    test(
      'a status outside the four is a server failure — never mapped',
      () async {
        final repo = repositoryReturning(
          (_) async => jsonResponse(
            rosterBody(
              students: [
                {
                  'student_id': 1,
                  'name': 'A',
                  'status': 'unknown',
                  'method': null,
                },
              ],
            ),
            200,
          ),
        );
        expect(
          (await failureOf(repo.getSessionAttendance(41))).kind,
          TeacherFailureKind.server,
        );
      },
    );

    test('an empty roster is an empty list', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(
          rosterBody(
            students: [],
            counts: {'present': 0, 'late': 0, 'absent': 0, 'excused': 0},
          ),
          200,
        ),
      );
      expect((await repo.getSessionAttendance(41)).students, isEmpty);
    });

    test('a 403 is a rejection', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(jsonEncode({'error': 'forbidden'}), 403),
      );
      expect(
        (await failureOf(repo.getSessionAttendance(41))).kind,
        TeacherFailureKind.rejected,
      );
    });
  });

  group('markAttendance', () {
    for (final status in AttendanceStatus.values) {
      test(
        'PUTs {"status": "${status.wire}"} to the student\'s record',
        () async {
          late http.Request sent;
          final repo = repositoryReturning((request) async {
            sent = request;
            return jsonResponse(
              jsonEncode({
                'student_id': 9,
                'session_id': 41,
                'status': status.wire,
                'method': 'manual',
                'checked_in_at': '2026-10-13T06:30:00',
              }),
              200,
            );
          });

          final stored = await repo.markAttendance(
            sessionId: 41,
            studentId: 9,
            status: status,
          );
          expect(sent.method, 'PUT');
          expect(sent.url.path, '/teacher/sessions/41/attendance/9');
          expect(sent.headers['Authorization'], 'Bearer tok-123');
          expect(sent.headers['Content-Type'], startsWith('application/json'));
          expect(jsonDecode(sent.body), {'status': status.wire});
          expect(stored, status);
        },
      );
    }

    test(
      '400 invalid_status and 404 student_not_found keep their codes',
      () async {
        for (final (code, status) in [
          ('invalid_status', 400),
          ('student_not_found', 404),
        ]) {
          final repo = repositoryReturning(
            (_) async => jsonResponse(jsonEncode({'error': code}), status),
          );
          final failure = await failureOf(
            repo.markAttendance(
              sessionId: 41,
              studentId: 9,
              status: AttendanceStatus.present,
            ),
          );
          expect(failure.kind, TeacherFailureKind.rejected, reason: code);
          expect(failure.code, code);
        }
      },
    );

    test('an answer for another student is a server failure', () async {
      final repo = repositoryReturning(
        (_) async => jsonResponse(
          jsonEncode({'student_id': 99, 'session_id': 41, 'status': 'present'}),
          200,
        ),
      );
      expect(
        (await failureOf(
          repo.markAttendance(
            sessionId: 41,
            studentId: 9,
            status: AttendanceStatus.present,
          ),
        )).kind,
        TeacherFailureKind.server,
      );
    });
  });

  group('session and transport', () {
    test('nothing is sent without a session', () async {
      var sent = 0;
      final repo = repositoryReturning((_) async {
        sent++;
        return jsonResponse('{}', 200);
      }, sessionStore: AuthSessionStore());
      for (final call in <Future<Object?> Function()>[
        () => repo.issueQr(41),
        () => repo.getSessionAttendance(41),
        () => repo.markAttendance(
          sessionId: 41,
          studentId: 9,
          status: AttendanceStatus.present,
        ),
      ]) {
        expect(
          (await failureOf(call())).kind,
          TeacherFailureKind.sessionExpired,
        );
      }
      expect(sent, 0);
    });

    test('a 401 on a write clears the session', () async {
      final store = signedIn();
      final repo = repositoryReturning(
        (_) async => jsonResponse(jsonEncode({'error': 'token_expired'}), 401),
        sessionStore: store,
      );
      final failure = await failureOf(
        repo.markAttendance(
          sessionId: 41,
          studentId: 9,
          status: AttendanceStatus.present,
        ),
      );
      expect(failure.kind, TeacherFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);
    });

    test('a request that never completes is a network failure', () async {
      final repo = repositoryReturning(
        (_) async => throw http.ClientException('offline'),
      );
      expect(
        (await failureOf(repo.issueQr(41))).kind,
        TeacherFailureKind.network,
      );
      expect(
        (await failureOf(
          repo.markAttendance(
            sessionId: 41,
            studentId: 9,
            status: AttendanceStatus.absent,
          ),
        )).kind,
        TeacherFailureKind.network,
      );
    });
  });

  group('ulaanbaatarToday', () {
    test('is the UTC+8 date, whatever the phone\'s zone', () {
      // 23:30 UTC on the 12th is 07:30 on the 13th in Ulaanbaatar.
      expect(
        ulaanbaatarToday(DateTime.utc(2026, 10, 12, 23, 30)),
        DateTime(2026, 10, 13),
      );
      // 15:59 UTC is 23:59 the same day; 16:00 UTC is the next day.
      expect(
        ulaanbaatarToday(DateTime.utc(2026, 10, 13, 15, 59)),
        DateTime(2026, 10, 13),
      );
      expect(
        ulaanbaatarToday(DateTime.utc(2026, 10, 13, 16)),
        DateTime(2026, 10, 14),
      );
    });
  });
}
