import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/attendance/data/http_attendance_repository.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against the verified production response for
/// the adult test account:
///
///     GET https://api.ai-academy.asia/me/attendance?course={slug}
///
///     { "cohort_id": 1, "course_id": 6, "sessions": [],
///       "summary": {"attended": 0, "percent": 0, "total_past": 0} }
void main() {
  /// Never the app-wide store: a test must not read a token another test
  /// left.
  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  HttpAttendanceRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpAttendanceRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
  );

  String verifiedBody({
    int attended = 0,
    num percent = 0,
    int totalPast = 0,
    List<Object?> sessions = const [],
  }) => jsonEncode({
    'cohort_id': 1,
    'course_id': 6,
    'sessions': sessions,
    'summary': {
      'attended': attended,
      'percent': percent,
      'total_past': totalPast,
    },
  });

  Future<AttendanceFailure> failureFrom(
    HttpAttendanceRepository repository,
  ) async {
    try {
      await repository.getCourseAttendance('summer-bootcamp-2027');
    } on AttendanceFailure catch (failure) {
      return failure;
    }
    fail('expected an AttendanceFailure');
  }

  group('the request', () {
    test('GETs /me/attendance with the course as a query parameter', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(verifiedBody(), 200);
      });

      await repository.getCourseAttendance('summer-bootcamp-2027');

      expect(sent.method, 'GET');
      expect(sent.url.path, '/me/attendance');
      expect(sent.url.queryParameters, {'course': 'summer-bootcamp-2027'});
      expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
    });

    test('encodes a slug rather than letting it break the URL', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(verifiedBody(), 200);
      });

      await repository.getCourseAttendance('a&b=c');

      expect(sent.url.queryParameters, {'course': 'a&b=c'});
    });

    test('no session: sends nothing', () async {
      var requests = 0;
      final repository = repositoryReturning((_) async {
        requests++;
        return http.Response(verifiedBody(), 200);
      }, sessionStore: AuthSessionStore());

      final failure = await failureFrom(repository);

      expect(failure.kind, AttendanceFailureKind.sessionExpired);
      expect(requests, 0);
    });
  });

  group('the verified response', () {
    test('parses the adult test account\'s all-zero summary', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(verifiedBody(), 200),
      );

      final attendance = await repository.getCourseAttendance('s');

      expect(attendance.attended, 0);
      expect(attendance.totalPast, 0);
      expect(attendance.percent, 0);
    });

    test('takes the server\'s percent, never re-deriving it', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(
          // 1 of 20 is 5%; the server says 10, and 10 is what is read.
          verifiedBody(attended: 1, totalPast: 20, percent: 10),
          200,
        ),
      );

      final attendance = await repository.getCourseAttendance('s');

      expect(attendance.attended, 1);
      expect(attendance.totalPast, 20);
      expect(attendance.percent, 10);
    });

    test('empty sessions is not a failure', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(verifiedBody(sessions: const []), 200),
      );

      expect((await repository.getCourseAttendance('s')).percent, 0);
    });

    test('session entries are not read, whatever they carry', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(
          verifiedBody(
            sessions: const [
              {'anything': true},
            ],
          ),
          200,
        ),
      );

      expect((await repository.getCourseAttendance('s')).attended, 0);
    });
  });

  group('failures', () {
    test('a missing summary fails loudly as server', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(jsonEncode({'sessions': []}), 200),
      );

      expect(
        (await failureFrom(repository)).kind,
        AttendanceFailureKind.server,
      );
    });

    test('a summary figure that is not a number fails as server', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(
          jsonEncode({
            'summary': {'attended': '0', 'percent': 0, 'total_past': 0},
          }),
          200,
        ),
      );

      expect(
        (await failureFrom(repository)).kind,
        AttendanceFailureKind.server,
      );
    });

    test('401 is a dead session, and forgets it', () async {
      final store = signedIn();
      final repository = repositoryReturning(
        (_) async => http.Response('{"error":"token_expired"}', 401),
        sessionStore: store,
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, AttendanceFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);
    });

    test('maps the other statuses', () async {
      const expected = {
        403: AttendanceFailureKind.rejected,
        404: AttendanceFailureKind.rejected,
        500: AttendanceFailureKind.server,
      };
      for (final entry in expected.entries) {
        final repository = repositoryReturning(
          (_) async => http.Response('{}', entry.key),
        );
        expect(
          (await failureFrom(repository)).kind,
          entry.value,
          reason: 'HTTP ${entry.key}',
        );
      }
    });

    test('a request that never completes is a network failure', () async {
      final repository = repositoryReturning(
        (_) async => throw const SocketException('offline'),
      );

      expect(
        (await failureFrom(repository)).kind,
        AttendanceFailureKind.network,
      );
    });
  });
}
