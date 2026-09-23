import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/enrollments/data/http_enrollment_repository.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against the confirmed contract:
///
///     POST https://api.ai-academy.asia/cohorts/{cohort_id}/enroll
///     Authorization: Bearer <student_access_token>
///     (no body)
///     -> 201 { id, student_id, cohort_id, course_id, status, progress_pct,
///              completed_at, created_at, created_by_admin_id, created_via }
void main() {
  /// Never the app-wide store: a test must not read a token another test left.
  AuthSessionStore signedIn([String token = 'tok-123']) =>
      AuthSessionStore()..save(AuthSession(accessToken: token));

  HttpEnrollmentRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpEnrollmentRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
  );

  Future<EnrollmentFailure> failureFrom(
    HttpEnrollmentRepository repository, {
    int cohortId = 7,
  }) async {
    try {
      await repository.enroll(cohortId);
    } on EnrollmentFailure catch (failure) {
      return failure;
    }
    fail('expected an EnrollmentFailure');
  }

  final createdBody = jsonEncode(_enrollmentJson());

  group('the request', () {
    test('POSTs to the cohort\'s enroll URL with no body', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(createdBody, 201);
      });

      await repository.enroll(7);

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.ai-academy.asia/cohorts/7/enroll');
      expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
      expect(sent.body, isEmpty);
      expect(sent.headers.containsKey(HttpHeaders.contentTypeHeader), isFalse);
    });

    test('carries the signed-in student\'s token as a Bearer header', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(createdBody, 201);
      }, sessionStore: signedIn('student-tok'));

      await repository.enroll(7);

      expect(sent.headers['Authorization'], 'Bearer student-tok');
    });
  });

  group('without a usable session', () {
    test('signed out: sends nothing and asks for sign-in', () async {
      var requests = 0;
      final repository = repositoryReturning((_) async {
        requests++;
        return http.Response(createdBody, 201);
      }, sessionStore: AuthSessionStore());

      final failure = await failureFrom(repository);

      expect(failure.kind, EnrollmentFailureKind.sessionExpired);
      expect(requests, 0);
    });

    test('a session past its reported lifetime: sends nothing', () async {
      var requests = 0;
      final store = AuthSessionStore()
        ..save(
          const AuthSession(accessToken: 'old', expiresIn: Duration(hours: 1)),
          now: DateTime(2000),
        );
      final repository = repositoryReturning((_) async {
        requests++;
        return http.Response(createdBody, 201);
      }, sessionStore: store);

      final failure = await failureFrom(repository);

      expect(failure.kind, EnrollmentFailureKind.sessionExpired);
      expect(requests, 0);
    });
  });

  group('a successful response', () {
    test('parses every field the contract names', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(createdBody, 201),
      );

      final enrollment = await repository.enroll(7);

      expect(enrollment.id, 11);
      expect(enrollment.studentId, 42);
      expect(enrollment.cohortId, 7);
      expect(enrollment.courseId, 6);
      expect(enrollment.status, 'active');
      expect(enrollment.progressPct, 0);
      expect(enrollment.completedAt, isNull);
      expect(enrollment.createdAt, '2026-09-14T09:30:00Z');
      expect(enrollment.createdByAdminId, isNull);
      expect(enrollment.createdVia, 'self');
    });

    test('parses the nullable fields when they are present', () async {
      final body = jsonEncode(
        _enrollmentJson(
          overrides: {'completed_at': '2026-12-01T00:00:00Z', 'created_by_admin_id': 3},
        ),
      );
      final repository = repositoryReturning((_) async => http.Response(body, 201));

      final enrollment = await repository.enroll(7);

      expect(enrollment.completedAt, '2026-12-01T00:00:00Z');
      expect(enrollment.createdByAdminId, 3);
    });

    test('reads progress_pct whether it is a whole number or not', () async {
      for (final (wire, expected) in [(0, 0.0), (40, 40.0), (12.5, 12.5)]) {
        final body = jsonEncode(_enrollmentJson(overrides: {'progress_pct': wire}));
        final repository = repositoryReturning((_) async => http.Response(body, 201));

        expect((await repository.enroll(7)).progressPct, expected, reason: '$wire');
      }
    });

    test('keeps the session', () async {
      final store = signedIn();
      final repository = repositoryReturning(
        (_) async => http.Response(createdBody, 201),
        sessionStore: store,
      );

      await repository.enroll(7);

      expect(store.isSignedIn, isTrue);
    });
  });

  group('malformed responses', () {
    test('a malformed body is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('<html>nope</html>', 201)),
      );
      expect(failure.kind, EnrollmentFailureKind.server);
      expect(failure.detail, contains('malformed JSON'));
    });

    test('a JSON array instead of an object is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('[]', 201)),
      );
      expect(failure.kind, EnrollmentFailureKind.server);
    });

    test('a missing required field names that field', () async {
      final body = jsonEncode(_enrollmentJson()..remove('student_id'));

      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response(body, 201)),
      );

      expect(failure.kind, EnrollmentFailureKind.server);
      expect(failure.detail, contains('enrollment.student_id'));
    });

    test('a required field with the wrong type names that field', () async {
      final body = jsonEncode(_enrollmentJson(overrides: {'progress_pct': 'none'}));

      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response(body, 201)),
      );

      expect(failure.kind, EnrollmentFailureKind.server);
      expect(failure.detail, contains('enrollment.progress_pct'));
    });
  });

  group('HTTP failures', () {
    test('a 401 means the session was refused, and forgets it', () async {
      final store = signedIn();

      final failure = await failureFrom(
        repositoryReturning(
          (_) async => http.Response('{"error":"invalid_token"}', 401),
          sessionStore: store,
        ),
      );

      expect(failure.kind, EnrollmentFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);
    });

    test('a 401 is a refused session whatever its body says', () async {
      for (final body in ['', 'not json', '{"error":"authentication_required"}']) {
        final failure = await failureFrom(
          repositoryReturning((_) async => http.Response(body, 401)),
        );
        expect(failure.kind, EnrollmentFailureKind.sessionExpired, reason: 'body: "$body"');
      }
    });

    test('other 4xx are a refused enrollment, and keep the session', () async {
      for (final status in [400, 403, 404, 409, 422]) {
        final store = signedIn();
        final failure = await failureFrom(
          repositoryReturning(
            (_) async => http.Response('{"error":"nope"}', status),
            sessionStore: store,
          ),
        );
        expect(failure.kind, EnrollmentFailureKind.rejected, reason: 'HTTP $status');
        expect(store.isSignedIn, isTrue, reason: 'HTTP $status');
      }
    });

    test('5xx is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('boom', 500)),
      );
      expect(failure.kind, EnrollmentFailureKind.server);
    });

    test('a non-2xx outside 4xx/5xx is unexpected', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('', 302)),
      );
      expect(failure.kind, EnrollmentFailureKind.unexpected);
    });

    test('an unreachable host is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw const SocketException('no route')),
      );
      expect(failure.kind, EnrollmentFailureKind.network);
    });

    test('a client exception is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw http.ClientException('closed')),
      );
      expect(failure.kind, EnrollmentFailureKind.network);
    });

    test('a slow backend times out rather than hanging the button', () async {
      final repository = HttpEnrollmentRepository(
        client: MockClient(
          (_) => Future.delayed(
            const Duration(milliseconds: 200),
            () => http.Response(createdBody, 201),
          ),
        ),
        sessionStore: signedIn(),
        timeout: const Duration(milliseconds: 20),
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, EnrollmentFailureKind.network);
      expect(failure.detail, 'request timed out');
    });
  });

  group('configuration', () {
    test('the default base URL is the contract host', () {
      expect(HttpEnrollmentRepository.defaultBaseUrl, 'https://api.ai-academy.asia');
    });

    test('a base URL can be overridden without touching the path', () async {
      late Uri url;
      final repository = HttpEnrollmentRepository(
        baseUrl: Uri.parse('https://staging.example.test'),
        sessionStore: signedIn(),
        client: MockClient((request) async {
          url = request.url;
          return http.Response(createdBody, 201);
        }),
      );

      await repository.enroll(3);

      expect(url.toString(), 'https://staging.example.test/cohorts/3/enroll');
    });
  });
}

/// An enrollment JSON object carrying every field the contract names, with
/// [overrides] applied. The values are illustrative — the contract lists
/// fields, not example values.
Map<String, dynamic> _enrollmentJson({Map<String, dynamic> overrides = const {}}) => {
  'id': 11,
  'student_id': 42,
  'cohort_id': 7,
  'course_id': 6,
  'status': 'active',
  'progress_pct': 0,
  'completed_at': null,
  'created_at': '2026-09-14T09:30:00Z',
  'created_by_admin_id': null,
  'created_via': 'self',
  ...overrides,
};
