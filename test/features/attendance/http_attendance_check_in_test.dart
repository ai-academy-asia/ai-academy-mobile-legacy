import 'dart:convert';

import 'package:aia_mobile/features/attendance/data/http_attendance_repository.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// `POST /me/attendance/check-in` (Issue #382), against fake clients only —
/// the shapes are the backend source's (`app/services/attendance/
/// checkin.py`, `check_in`), with test values. No production call is made
/// and no attendance is written. The tokens below are made-up fixtures.
void main() {
  const token = 'fixture-qr-token_AbC-123';

  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  HttpAttendanceRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpAttendanceRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
  );

  http.Response json(Object body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, Object?> record({
    String status = 'present',
    String? method = 'qr',
    String? checkedInAt = '2026-10-13T06:01:00',
  }) => {
    'session_id': 41,
    'status': status,
    'method': method,
    'checked_in_at': checkedInAt,
  };

  Future<AttendanceFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on AttendanceFailure catch (failure) {
      return failure;
    }
    fail('expected an AttendanceFailure');
  }

  test('POSTs the raw token as {"token"} to /me/attendance/check-in, with '
      'the session\'s bearer token', () async {
    late http.Request sent;
    final repo = repositoryReturning((request) async {
      sent = request;
      return json(record(), 201);
    });

    await repo.checkIn(token);
    expect(sent.method, 'POST');
    expect(sent.url.path, '/me/attendance/check-in');
    expect(sent.url.query, isEmpty);
    expect(sent.headers['Authorization'], 'Bearer tok-123');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    // Exactly the scanned string — nothing wrapped, trimmed or added.
    expect(jsonDecode(sent.body), {'token': token});
  });

  test('201: a first check-in, every field as returned', () async {
    final repo = repositoryReturning((_) async => json(record(), 201));
    final checkIn = await repo.checkIn(token);
    expect(checkIn.firstCheckIn, isTrue);
    expect(checkIn.sessionId, 41);
    expect(checkIn.status, 'present');
    expect(checkIn.method, 'qr');
    expect(checkIn.checkedInAt, DateTime.parse('2026-10-13T06:01:00'));
  });

  test('201 late: kept as late', () async {
    final repo = repositoryReturning(
      (_) async => json(record(status: 'late'), 201),
    );
    expect((await repo.checkIn(token)).status, 'late');
  });

  test('200: a repeat — the existing record, not a new success', () async {
    final repo = repositoryReturning((_) async => json(record(), 200));
    final checkIn = await repo.checkIn(token);
    expect(checkIn.firstCheckIn, isFalse);
    expect(checkIn.status, 'present');
  });

  for (final status in ['absent', 'excused']) {
    test('200 with a teacher\'s "$status": returned as "$status", never '
        'as a success', () async {
      final repo = repositoryReturning(
        (_) async => json(record(status: status, method: 'manual'), 200),
      );
      final checkIn = await repo.checkIn(token);
      expect(checkIn.status, status);
      expect(checkIn.method, 'manual');
      expect(checkIn.firstCheckIn, isFalse);
    });
  }

  test('a null method and checked_in_at are kept as null', () async {
    final repo = repositoryReturning(
      (_) async => json(record(method: null, checkedInAt: null), 200),
    );
    final checkIn = await repo.checkIn(token);
    expect(checkIn.method, isNull);
    expect(checkIn.checkedInAt, isNull);
  });

  group('refusals keep the backend\'s code', () {
    for (final (status, code) in [
      (400, 'token_required'),
      (400, 'invalid_token'),
      (403, 'not_enrolled'),
    ]) {
      test('$status $code', () async {
        final repo = repositoryReturning(
          (_) async => json({'error': code}, status),
        );
        final failure = await failureOf(repo.checkIn(token));
        expect(failure.kind, AttendanceFailureKind.rejected);
        expect(failure.code, code);
      });
    }

    test('401: sign in again, and the session is cleared', () async {
      final store = signedIn();
      final repo = repositoryReturning(
        (_) async => json({'error': 'token_expired'}, 401),
        sessionStore: store,
      );
      final failure = await failureOf(repo.checkIn(token));
      expect(failure.kind, AttendanceFailureKind.sessionExpired);
      expect(failure.code, 'token_expired');
      expect(store.isSignedIn, isFalse);
    });

    test('a 5xx is a server failure; a non-JSON refusal has no code', () async {
      final repo = repositoryReturning(
        (_) async => http.Response('<html>bad gateway</html>', 502),
      );
      final failure = await failureOf(repo.checkIn(token));
      expect(failure.kind, AttendanceFailureKind.server);
      expect(failure.code, isNull);
    });
  });

  group('never sends without a session; transport and shape failures', () {
    test('nothing is sent without a session', () async {
      var sent = 0;
      final repo = repositoryReturning((_) async {
        sent++;
        return json(record(), 201);
      }, sessionStore: AuthSessionStore());
      final failure = await failureOf(repo.checkIn(token));
      expect(failure.kind, AttendanceFailureKind.sessionExpired);
      expect(sent, 0);
    });

    test('a request that never completes is a network failure', () async {
      final repo = repositoryReturning(
        (_) async => throw http.ClientException('offline'),
      );
      expect(
        (await failureOf(repo.checkIn(token))).kind,
        AttendanceFailureKind.network,
      );
    });

    test('a 2xx other than 200/201 is unexpected', () async {
      final repo = repositoryReturning((_) async => http.Response('', 204));
      expect(
        (await failureOf(repo.checkIn(token))).kind,
        AttendanceFailureKind.unexpected,
      );
    });

    for (final (name, body) in <(String, Object)>[
      ('a missing session_id', {'status': 'present'}),
      ('an empty status', {'session_id': 41, 'status': ''}),
      (
        'a non-string method',
        {'session_id': 41, 'status': 'present', 'method': 3},
      ),
      (
        'an unreadable checked_in_at',
        {'session_id': 41, 'status': 'present', 'checked_in_at': 'soon'},
      ),
      ('a list', [1, 2]),
    ]) {
      test('$name is a server failure', () async {
        final repo = repositoryReturning((_) async => json(body, 201));
        expect(
          (await failureOf(repo.checkIn(token))).kind,
          AttendanceFailureKind.server,
        );
      });
    }
  });

  test(
    'the token appears in no failure — not its code, detail or text',
    () async {
      final failures = <AttendanceFailure>[];
      for (final handler in <Future<http.Response> Function(http.Request)>[
        (_) async => json({'error': 'invalid_token'}, 400),
        (_) async => json({'error': 'not_enrolled'}, 403),
        (_) async => json({'error': 'token_expired'}, 401),
        (_) async => http.Response('not json', 201),
        (_) async => json({'status': 'present'}, 201),
        (_) async => throw http.ClientException('offline'),
      ]) {
        failures.add(
          await failureOf(repositoryReturning(handler).checkIn(token)),
        );
      }
      for (final failure in failures) {
        // Checked without echoing the value into a failure message.
        expect(failure.toString().contains(token), isFalse);
        expect(failure.detail?.contains(token) ?? false, isFalse);
        expect(failure.code?.contains(token) ?? false, isFalse);
      }
    },
  );
}
