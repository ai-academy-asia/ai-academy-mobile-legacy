import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/enrollments/data/http_enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against the confirmed contract:
///
///     GET https://api.ai-academy.asia/me/cohorts
///     Authorization: Bearer <access_token>
///
/// The response shape is unconfirmed beyond that; every JSON body below
/// follows the same `{ "cohorts": [ { "id": ... } ] }` envelope `GET
/// /cohorts` is confirmed to use, per `HttpEnrolledCohortsRepository`'s own
/// doc comment.
void main() {
  /// Never the app-wide store: a test must not read a token another test
  /// left.
  AuthSessionStore signedIn([String token = 'tok-123']) =>
      AuthSessionStore()..save(AuthSession(accessToken: token));

  HttpEnrolledCohortsRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpEnrolledCohortsRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
  );

  Future<EnrollmentFailure> failureFrom(HttpEnrolledCohortsRepository repository) async {
    try {
      await repository.getEnrolledCohortIds();
    } on EnrollmentFailure catch (failure) {
      return failure;
    }
    fail('expected an EnrollmentFailure');
  }

  String bodyWithIds(List<int> ids) => jsonEncode({
    'cohorts': [
      for (final id in ids) {'id': id},
    ],
  });

  group('the request', () {
    test('GETs the contract URL with an Accept header and no body', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(bodyWithIds([]), 200);
      });

      await repository.getEnrolledCohortIds();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), 'https://api.ai-academy.asia/me/cohorts');
      expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
      expect(sent.body, isEmpty);
    });

    test('carries the signed-in student\'s token as a Bearer header', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(bodyWithIds([]), 200);
      }, sessionStore: signedIn('student-tok'));

      await repository.getEnrolledCohortIds();

      expect(sent.headers['Authorization'], 'Bearer student-tok');
    });
  });

  group('without a usable session', () {
    test('signed out: sends nothing and asks for sign-in', () async {
      var requests = 0;
      final repository = repositoryReturning((_) async {
        requests++;
        return http.Response(bodyWithIds([]), 200);
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
        return http.Response(bodyWithIds([]), 200);
      }, sessionStore: store);

      final failure = await failureFrom(repository);

      expect(failure.kind, EnrollmentFailureKind.sessionExpired);
      expect(requests, 0);
    });
  });

  group('a successful response', () {
    test('parses the id of every cohort entry', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(bodyWithIds([1, 4, 9]), 200),
      );

      final ids = await repository.getEnrolledCohortIds();

      expect(ids, {1, 4, 9});
    });

    test('an empty list is an empty set, not an error', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(bodyWithIds([]), 200),
      );

      expect(await repository.getEnrolledCohortIds(), isEmpty);
    });

    test('ignores fields on an entry other than id', () async {
      final body = jsonEncode({
        'cohorts': [
          {'id': 1, 'name': 'Corporate Leaders 2026-08', 'status': 'open'},
        ],
      });
      final repository = repositoryReturning((_) async => http.Response(body, 200));

      expect(await repository.getEnrolledCohortIds(), {1});
    });

    test('keeps the session', () async {
      final store = signedIn();
      final repository = repositoryReturning(
        (_) async => http.Response(bodyWithIds([]), 200),
        sessionStore: store,
      );

      await repository.getEnrolledCohortIds();

      expect(store.isSignedIn, isTrue);
    });
  });

  group('malformed responses', () {
    test('a malformed body is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('<html>nope</html>', 200)),
      );
      expect(failure.kind, EnrollmentFailureKind.server);
      expect(failure.detail, contains('malformed JSON'));
    });

    test('a JSON array instead of an object is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('[]', 200)),
      );
      expect(failure.kind, EnrollmentFailureKind.server);
    });

    test('a response with no "cohorts" key is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response(jsonEncode({'data': []}), 200)),
      );
      expect(failure.kind, EnrollmentFailureKind.server);
      expect(failure.detail, contains('cohorts'));
    });

    test('a cohort entry that is not an object is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning(
          (_) async => http.Response(
            jsonEncode({
              'cohorts': ['not-an-object'],
            }),
            200,
          ),
        ),
      );
      expect(failure.kind, EnrollmentFailureKind.server);
      expect(failure.detail, contains('cohort entry'));
    });

    test('an entry missing id is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning(
          (_) async => http.Response(
            jsonEncode({
              'cohorts': [
                {'name': 'no id'},
              ],
            }),
            200,
          ),
        ),
      );
      expect(failure.kind, EnrollmentFailureKind.server);
      expect(failure.detail, contains('cohort.id'));
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

    test('other 4xx are a refused request, and keep the session', () async {
      for (final status in [400, 403, 404, 422]) {
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

    test('a slow backend times out rather than hanging the screen', () async {
      final repository = HttpEnrolledCohortsRepository(
        client: MockClient(
          (_) => Future.delayed(
            const Duration(milliseconds: 200),
            () => http.Response(bodyWithIds([]), 200),
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
      expect(
        HttpEnrolledCohortsRepository.defaultBaseUrl,
        'https://api.ai-academy.asia',
      );
    });

    test('a base URL can be overridden without touching the path', () async {
      late Uri url;
      final repository = HttpEnrolledCohortsRepository(
        baseUrl: Uri.parse('https://staging.example.test'),
        sessionStore: signedIn(),
        client: MockClient((request) async {
          url = request.url;
          return http.Response(bodyWithIds([]), 200);
        }),
      );

      await repository.getEnrolledCohortIds();

      expect(url.toString(), 'https://staging.example.test/me/cohorts');
    });
  });
}
