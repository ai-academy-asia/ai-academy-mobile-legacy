import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/data/http_password_repository.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against the contract:
///
///     POST https://api.ai-academy.asia/auth/change-password
///     { "current_password": "...", "new_password": "..." }
///
/// The success body has no confirmed shape, so nothing here asserts one — only
/// that a 2xx is accepted and a non-2xx is not.
void main() {
  HttpPasswordRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpPasswordRepository(
    client: MockClient(handler),
    // Never the app-wide store: a test must not read a token another test left.
    sessionStore: sessionStore ?? AuthSessionStore(),
  );

  group('the request', () {
    test('posts JSON to the contract URL with the contract body', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response('', 200);
      });

      await repository.changePassword(
        currentPassword: 'Huuchin1!',
        newPassword: 'Nuutsug1!',
      );

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.ai-academy.asia/auth/change-password');
      expect(sent.headers[HttpHeaders.contentTypeHeader], contains('application/json'));
      expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
      expect(jsonDecode(sent.body), {
        'current_password': 'Huuchin1!',
        'new_password': 'Nuutsug1!',
      });
    });

    test('never sends the confirm-password field', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response('', 200);
      });

      await repository.changePassword(
        currentPassword: 'Huuchin1!',
        newPassword: 'Nuutsug1!',
      );

      // The screen's third field is a client-side check. Exactly the two keys
      // the contract names cross the wire, and nothing else.
      expect(
        (jsonDecode(sent.body) as Map).keys,
        unorderedEquals(['current_password', 'new_password']),
      );
    });

    test('carries the session token when one is held', () async {
      final store = AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response('', 200);
      }, sessionStore: store);

      await repository.changePassword(currentPassword: 'a', newPassword: 'b');

      expect(sent.headers['Authorization'], 'Bearer tok-123');
    });

    test('sends no Authorization header when signed out', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response('', 200);
      });

      await repository.changePassword(currentPassword: 'a', newPassword: 'b');

      expect(sent.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('a successful response', () {
    test('accepts any 2xx without asserting a body shape', () async {
      for (final status in [200, 201, 204]) {
        final repository = repositoryReturning((_) async => http.Response('', status));

        await expectLater(
          repository.changePassword(currentPassword: 'a', newPassword: 'b'),
          completes,
          reason: 'HTTP $status',
        );
      }
    });

    test('does not reject an unexpected success body', () async {
      // The shape is unconfirmed, so anything a 2xx carries is left alone
      // rather than being failed against a contract nobody has recorded.
      final repository = repositoryReturning(
        (_) async => http.Response('<html>ok</html>', 200),
      );

      await expectLater(
        repository.changePassword(currentPassword: 'a', newPassword: 'b'),
        completes,
      );
    });
  });

  group('failures', () {
    Future<AuthFailure> failureFrom(HttpPasswordRepository repository) async {
      try {
        await repository.changePassword(currentPassword: 'a', newPassword: 'b');
      } on AuthFailure catch (failure) {
        return failure;
      }
      fail('expected an AuthFailure');
    }

    test('401 and 403 mean the current password was refused', () async {
      for (final status in [401, 403]) {
        final failure = await failureFrom(
          repositoryReturning(
            (_) async => http.Response('{"error":"invalid_credentials"}', status),
          ),
        );
        expect(failure.kind, AuthFailureKind.invalidCredentials, reason: 'HTTP $status');
      }
    });

    test('a 401 about the session is not reported as a wrong password', () async {
      // Both codes observed live: no token answers authentication_required,
      // an invalid one answers invalid_token. Calling either a wrong password
      // would have the user retype a correct one indefinitely.
      for (final code in ['authentication_required', 'invalid_token']) {
        final failure = await failureFrom(
          repositoryReturning((_) async => http.Response('{"error":"$code"}', 401)),
        );
        expect(failure.kind, AuthFailureKind.sessionExpired, reason: code);
      }
    });

    test('a 401 with an unreadable body still reads as a refusal', () async {
      for (final body in ['', 'not json', '{}']) {
        final failure = await failureFrom(
          repositoryReturning((_) async => http.Response(body, 401)),
        );
        expect(failure.kind, AuthFailureKind.invalidCredentials, reason: 'body: "$body"');
      }
    });

    test('5xx is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('boom', 500)),
      );
      expect(failure.kind, AuthFailureKind.server);
    });

    test('other non-2xx are unexpected', () async {
      for (final status in [400, 404, 422]) {
        final failure = await failureFrom(
          repositoryReturning((_) async => http.Response('{"error":"nope"}', status)),
        );
        expect(failure.kind, AuthFailureKind.unexpected, reason: 'HTTP $status');
      }
    });

    test('an unreachable host is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw const SocketException('no route')),
      );
      expect(failure.kind, AuthFailureKind.network);
    });

    test('a client exception is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw http.ClientException('closed')),
      );
      expect(failure.kind, AuthFailureKind.network);
    });

    test('a slow backend times out rather than hanging the form', () async {
      final repository = HttpPasswordRepository(
        client: MockClient(
          (_) => Future.delayed(
            const Duration(milliseconds: 200),
            () => http.Response('', 200),
          ),
        ),
        sessionStore: AuthSessionStore(),
        timeout: const Duration(milliseconds: 20),
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, AuthFailureKind.network);
      expect(failure.detail, 'request timed out');
    });
  });

  group('configuration', () {
    test('the default base URL is the contract host', () {
      expect(HttpPasswordRepository.defaultBaseUrl, 'https://api.ai-academy.asia');
    });

    test('a base URL can be overridden without touching the path', () async {
      late Uri url;
      final repository = HttpPasswordRepository(
        baseUrl: Uri.parse('https://staging.example.test'),
        sessionStore: AuthSessionStore(),
        client: MockClient((request) async {
          url = request.url;
          return http.Response('', 200);
        }),
      );

      await repository.changePassword(currentPassword: 'a', newPassword: 'b');

      expect(url.toString(), 'https://staging.example.test/auth/change-password');
    });
  });
}
