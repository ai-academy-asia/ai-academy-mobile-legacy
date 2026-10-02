import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/attendance/data/http_attendance_repository.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against the verified production responses — the
/// adult test account's (empty `sessions`), and the junior test student's
/// (populated; see the junior group below). The adult one:
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

    test('unmodelled session fields are left alone', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(
          verifiedBody(
            sessions: const [
              {'date': '2026-06-16', 'status': 'present', 'anything': true},
            ],
          ),
          200,
        ),
      );

      final sessions = (await repository.getCourseAttendance('s')).sessions;
      expect(sessions.single.date, DateTime(2026, 6, 16));
      expect(sessions.single.status, 'present');
    });
  });

  group('the verified adult response (corp.s01, cohort 3, Issue #170)', () {
    /// Captured from production for `corp.s01` in `ai-corporate-leaders`:
    /// nine held sessions, then three not held yet whose status is null.
    /// Only `date` and `status` matter to the parser; the other fields are
    /// kept as the server sends them.
    final sessions = [
      for (final (date, status) in [
        ('2026-08-06', 'present'),
        ('2026-08-13', 'present'),
        ('2026-08-20', 'late'),
        ('2026-08-27', 'present'),
        ('2026-09-03', 'present'),
        ('2026-09-10', 'present'),
        ('2026-09-17', 'present'),
        ('2026-09-24', 'present'),
        ('2026-10-01', 'absent'),
        ('2026-10-08', null),
        ('2026-10-15', null),
        ('2026-10-22', null),
      ])
        {
          'date': date,
          'end_time': '21:30',
          'session_id': 96,
          'start_time': '18:30',
          'status': status,
          'topic_id': 8,
        },
    ];

    Future<CourseAttendance> adult() => repositoryReturning(
      (_) async => http.Response(
        verifiedBody(
          attended: 8,
          totalPast: 9,
          percent: 88,
          sessions: sessions,
        ),
        200,
      ),
    ).getCourseAttendance('ai-corporate-leaders');

    test('parses despite the null statuses, summary untouched', () async {
      final attendance = await adult();

      expect(attendance.sessions, hasLength(12));
      expect(attendance.attended, 8);
      expect(attendance.totalPast, 9);
      expect(attendance.percent, 88);
    });

    test('reads every status verbatim, null included', () async {
      final statuses = (await adult()).sessions.map((s) => s.status).toList();

      expect(statuses.where((s) => s == 'present'), hasLength(7));
      expect(statuses.where((s) => s == 'late'), hasLength(1));
      expect(statuses.where((s) => s == 'absent'), hasLength(1));
      expect(statuses.where((s) => s == null), hasLength(3));
      expect(
        (await adult()).sessions
            .where((s) => s.status == null)
            .map((s) => s.date),
        [DateTime(2026, 10, 8), DateTime(2026, 10, 15), DateTime(2026, 10, 22)],
      );
    });

    test(
      'present and late count as attended; absent and null do not',
      () async {
        final attendance = await adult();
        bool counts(String? status) => attendance.sessions
            .firstWhere((s) => s.status == status)
            .countsAsAttended;

        expect(counts('present'), isTrue);
        expect(counts('late'), isTrue);
        expect(counts('absent'), isFalse);
        expect(counts(null), isFalse);
        // Only absent counts as missed (Issue #172); null is neither.
        bool missed(String? status) => attendance.sessions
            .firstWhere((s) => s.status == status)
            .countsAsMissed;
        expect(missed('absent'), isTrue);
        expect(missed('present'), isFalse);
        expect(missed('late'), isFalse);
        expect(missed(null), isFalse);
        // 7 present + 1 late = summary.attended 8.
        expect(
          attendance.sessions.where((s) => s.countsAsAttended),
          hasLength(attendance.attended),
        );
      },
    );

    test(
      'a status that is neither a string nor null is still rejected',
      () async {
        for (final status in [42, true, <String, Object?>{}, <Object?>[]]) {
          final failure = await failureFrom(
            repositoryReturning(
              (_) async => http.Response(
                verifiedBody(
                  sessions: [
                    {'date': '2026-10-08', 'status': status},
                  ],
                ),
                200,
              ),
            ),
          );
          expect(failure.kind, AttendanceFailureKind.server, reason: '$status');
          expect(failure.detail, contains('status'), reason: '$status');
        }
      },
    );
  });

  group('the verified junior response (cohort 7, junior-ai-summer-10-14)', () {
    /// Captured from production for the junior test student, verbatim.
    const juniorBody = r'''
{
  "cohort_id": 7,
  "course_id": 13,
  "sessions": [
      {
        "date": "2026-06-16",
        "end_time": "12:00",
        "session_id": 148,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 24
      },
      {
        "date": "2026-06-18",
        "end_time": "12:00",
        "session_id": 149,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 24
      },
      {
        "date": "2026-06-20",
        "end_time": "12:00",
        "session_id": 150,
        "start_time": "09:00",
        "status": "late",
        "topic_id": 24
      },
      {
        "date": "2026-06-23",
        "end_time": "12:00",
        "session_id": 151,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 24
      },
      {
        "date": "2026-06-25",
        "end_time": "12:00",
        "session_id": 152,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 24
      },
      {
        "date": "2026-06-27",
        "end_time": "12:00",
        "session_id": 153,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 24
      },
      {
        "date": "2026-06-30",
        "end_time": "12:00",
        "session_id": 154,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 25
      },
      {
        "date": "2026-07-02",
        "end_time": "12:00",
        "session_id": 155,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 25
      },
      {
        "date": "2026-07-04",
        "end_time": "12:00",
        "session_id": 156,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 25
      },
      {
        "date": "2026-07-07",
        "end_time": "12:00",
        "session_id": 157,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 26
      },
      {
        "date": "2026-07-09",
        "end_time": "12:00",
        "session_id": 158,
        "start_time": "09:00",
        "status": "present",
        "topic_id": 26
      }
  ],
  "summary": {
    "attended": 11,
    "percent": 100,
    "total_past": 11
  }
}''';

    Future<CourseAttendance> junior() => repositoryReturning(
      (_) async => http.Response(juniorBody, 200),
    ).getCourseAttendance('junior-ai-summer-10-14');

    test('parses every session, in the server\'s order', () async {
      final attendance = await junior();

      expect(attendance.sessions, hasLength(11));
      expect(attendance.sessions.first.date, DateTime(2026, 6, 16));
      expect(attendance.sessions.last.date, DateTime(2026, 7, 9));
      expect(attendance.attended, 11);
      expect(attendance.totalPast, 11);
      expect(attendance.percent, 100);
    });

    test('reads the statuses verbatim: 10 present, 1 late', () async {
      final statuses = (await junior()).sessions.map((s) => s.status).toList();

      expect(statuses.where((s) => s == 'present'), hasLength(10));
      expect(statuses.where((s) => s == 'late'), hasLength(1));
      expect(
        (await junior()).sessions.singleWhere((s) => s.status == 'late').date,
        DateTime(2026, 6, 20),
      );
    });

    test(
      'late counts as attended, as the server\'s own summary does',
      () async {
        final attendance = await junior();

        // 10 present + 1 late = summary.attended 11.
        expect(
          attendance.sessions.where((s) => s.countsAsAttended),
          hasLength(attendance.attended),
        );
      },
    );
  });

  group('session statuses', () {
    test('only present and late count as attended', () {
      AttendanceSession session(String status) =>
          AttendanceSession(date: DateTime(2026, 6, 16), status: status);

      expect(session('present').countsAsAttended, isTrue);
      expect(session('late').countsAsAttended, isTrue);
      // Never seen on the wire: not known to mean attended — nor missed.
      expect(session('excused').countsAsAttended, isFalse);
      expect(session('').countsAsAttended, isFalse);
    });
  });

  group('session failures', () {
    Future<AttendanceFailure> failing(Object? sessions) => failureFrom(
      repositoryReturning(
        (_) async => http.Response(
          jsonEncode({
            'sessions': sessions,
            'summary': {'attended': 0, 'percent': 0, 'total_past': 0},
          }),
          200,
        ),
      ),
    );

    test('sessions that is not a list fails as server', () async {
      final failure = await failing({'date': '2026-06-16'});

      expect(failure.kind, AttendanceFailureKind.server);
      expect(failure.detail, contains('sessions'));
    });

    test('a session without a valid date fails as server', () async {
      for (final date in <Object?>[null, 'yesterday', 20260616]) {
        final failure = await failing([
          {'date': date, 'status': 'present'},
        ]);

        expect(failure.kind, AttendanceFailureKind.server, reason: '$date');
        expect(failure.detail, contains('date'), reason: '$date');
      }
    });

    test('a session without a string status fails as server', () async {
      final failure = await failing([
        {'date': '2026-06-16', 'status': 1},
      ]);

      expect(failure.kind, AttendanceFailureKind.server);
      expect(failure.detail, contains('status'));
    });

    test('a session entry that is not an object fails as server', () async {
      final failure = await failing(['2026-06-16']);

      expect(failure.kind, AttendanceFailureKind.server);
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
