import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/data/http_current_user_repository.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/domain/current_user_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against the confirmed contract:
///
///     GET https://api.ai-academy.asia/auth/me
///     Authorization: Bearer <access_token>
///
///     {
///       "actor_id": 5,
///       "actor_type": "student",
///       "email": "crud-test-student-20260909@example.mn",
///       "id": 9,
///       "is_active": true,
///       "must_change_password": true,
///       "profile": {
///         "first_name": "CRUD",
///         "id": 5,
///         "last_name": "TestStudent",
///         "phone": "99123456",
///         "ui_mode": "kids"
///       },
///       "role": "student"
///     }
void main() {
  /// Never the app-wide store: a test must not read a token another test
  /// left.
  AuthSessionStore signedIn([String token = 'tok-123']) =>
      AuthSessionStore()..save(AuthSession(accessToken: token));

  HttpCurrentUserRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpCurrentUserRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
  );

  Future<CurrentUserFailure> failureFrom(HttpCurrentUserRepository repository) async {
    try {
      await repository.getCurrentUser();
    } on CurrentUserFailure catch (failure) {
      return failure;
    }
    fail('expected a CurrentUserFailure');
  }

  String validBody({
    int id = 9,
    int actorId = 5,
    String actorType = 'student',
    String email = 'crud-test-student-20260909@example.mn',
    String role = 'student',
    bool isActive = true,
    bool mustChangePassword = true,
    int profileId = 5,
    String firstName = 'CRUD',
    String lastName = 'TestStudent',
    String phone = '99123456',
    String uiMode = 'kids',
  }) => jsonEncode({
    'actor_id': actorId,
    'actor_type': actorType,
    'email': email,
    'id': id,
    'is_active': isActive,
    'must_change_password': mustChangePassword,
    'profile': {
      'first_name': firstName,
      'id': profileId,
      'last_name': lastName,
      'phone': phone,
      'ui_mode': uiMode,
    },
    'role': role,
  });

  group('the request', () {
    test('GETs the contract URL with an Accept header and no body', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(validBody(), 200);
      });

      await repository.getCurrentUser();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), 'https://api.ai-academy.asia/auth/me');
      expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
      expect(sent.body, isEmpty);
    });

    test('carries the signed-in user\'s token as a Bearer header', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(validBody(), 200);
      }, sessionStore: signedIn('student-tok'));

      await repository.getCurrentUser();

      expect(sent.headers['Authorization'], 'Bearer student-tok');
    });
  });

  group('without a usable session', () {
    test('signed out: sends nothing and asks for sign-in', () async {
      var requests = 0;
      final repository = repositoryReturning((_) async {
        requests++;
        return http.Response(validBody(), 200);
      }, sessionStore: AuthSessionStore());

      final failure = await failureFrom(repository);

      expect(failure.kind, CurrentUserFailureKind.sessionExpired);
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
        return http.Response(validBody(), 200);
      }, sessionStore: store);

      final failure = await failureFrom(repository);

      expect(failure.kind, CurrentUserFailureKind.sessionExpired);
      expect(requests, 0);
    });
  });

  group('a successful response', () {
    test('parses every field of the confirmed contract', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(validBody(), 200),
      );

      final user = await repository.getCurrentUser();

      expect(user.id, 9);
      expect(user.actorId, 5);
      expect(user.actorType, 'student');
      expect(user.email, 'crud-test-student-20260909@example.mn');
      expect(user.role, 'student');
      expect(user.isActive, isTrue);
      expect(user.mustChangePassword, isTrue);
      expect(user.profile.id, 5);
      expect(user.profile.firstName, 'CRUD');
      expect(user.profile.lastName, 'TestStudent');
      expect(user.profile.phone, '99123456');
      expect(user.profile.uiMode, 'kids');
      expect(user.displayName, 'CRUD TestStudent');
    });

    test('keeps the session', () async {
      final store = signedIn();
      final repository = repositoryReturning(
        (_) async => http.Response(validBody(), 200),
        sessionStore: store,
      );

      await repository.getCurrentUser();

      expect(store.isSignedIn, isTrue);
    });
  });

  group('malformed responses', () {
    test('a malformed body is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('<html>nope</html>', 200)),
      );
      expect(failure.kind, CurrentUserFailureKind.server);
      expect(failure.detail, contains('malformed JSON'));
    });

    test('a JSON array instead of an object is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('[]', 200)),
      );
      expect(failure.kind, CurrentUserFailureKind.server);
    });

    test('a response missing "profile" is a server fault', () async {
      final body = jsonEncode({
        'actor_id': 5,
        'actor_type': 'student',
        'email': 'a@example.mn',
        'id': 9,
        'is_active': true,
        'must_change_password': true,
        'role': 'student',
      });
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response(body, 200)),
      );
      expect(failure.kind, CurrentUserFailureKind.server);
      expect(failure.detail, contains('profile'));
    });

    test('a top-level field of the wrong type is a server fault', () async {
      final body = jsonEncode({
        'actor_id': 5,
        'actor_type': 'student',
        'email': 'a@example.mn',
        'id': 'not-a-number',
        'is_active': true,
        'must_change_password': true,
        'profile': {
          'first_name': 'CRUD',
          'id': 5,
          'last_name': 'TestStudent',
          'phone': '99123456',
          'ui_mode': 'kids',
        },
        'role': 'student',
      });
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response(body, 200)),
      );
      expect(failure.kind, CurrentUserFailureKind.server);
      expect(failure.detail, contains('id'));
    });

    test('a profile field of the wrong type is a server fault', () async {
      final body = jsonEncode({
        'actor_id': 5,
        'actor_type': 'student',
        'email': 'a@example.mn',
        'id': 9,
        'is_active': true,
        'must_change_password': true,
        'profile': {
          'first_name': 'CRUD',
          'id': 5,
          'last_name': null,
          'phone': '99123456',
          'ui_mode': 'kids',
        },
        'role': 'student',
      });
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response(body, 200)),
      );
      expect(failure.kind, CurrentUserFailureKind.server);
      expect(failure.detail, contains('last_name'));
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

      expect(failure.kind, CurrentUserFailureKind.sessionExpired);
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
        expect(failure.kind, CurrentUserFailureKind.rejected, reason: 'HTTP $status');
        expect(store.isSignedIn, isTrue, reason: 'HTTP $status');
      }
    });

    test('5xx is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('boom', 500)),
      );
      expect(failure.kind, CurrentUserFailureKind.server);
    });

    test('a non-2xx outside 4xx/5xx is unexpected', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('', 302)),
      );
      expect(failure.kind, CurrentUserFailureKind.unexpected);
    });

    test('an unreachable host is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw const SocketException('no route')),
      );
      expect(failure.kind, CurrentUserFailureKind.network);
    });

    test('a client exception is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw http.ClientException('closed')),
      );
      expect(failure.kind, CurrentUserFailureKind.network);
    });

    test('a slow backend times out rather than hanging the screen', () async {
      final repository = HttpCurrentUserRepository(
        client: MockClient(
          (_) => Future.delayed(
            const Duration(milliseconds: 200),
            () => http.Response(validBody(), 200),
          ),
        ),
        sessionStore: signedIn(),
        timeout: const Duration(milliseconds: 20),
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, CurrentUserFailureKind.network);
      expect(failure.detail, 'request timed out');
    });
  });

  group('configuration', () {
    test('the default base URL is the contract host', () {
      expect(
        HttpCurrentUserRepository.defaultBaseUrl,
        'https://api.ai-academy.asia',
      );
    });

    test('a base URL can be overridden without touching the path', () async {
      late Uri url;
      final repository = HttpCurrentUserRepository(
        baseUrl: Uri.parse('https://staging.example.test'),
        sessionStore: signedIn(),
        client: MockClient((request) async {
          url = request.url;
          return http.Response(validBody(), 200);
        }),
      );

      await repository.getCurrentUser();

      expect(url.toString(), 'https://staging.example.test/auth/me');
    });
  });
}
