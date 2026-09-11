import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/data/http_auth_repository.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against the confirmed contract:
///
///     POST https://api.ai-academy.asia/auth/login
///     { "email": "...", "password": "..." }
///     -> { "access_token": "...", "expires_in": 3600 }
///
/// `MockClient` ships with the `http` package already in the project, so none of
/// this needs a new dependency or a live backend.
void main() {
  HttpAuthRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler,
  ) => HttpAuthRepository(client: MockClient(handler));

  group('the request', () {
    test('posts JSON to the contract URL with the contract body', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(jsonEncode({'access_token': 'tok'}), 200);
      });

      await repository.signIn(email: 'suragch@ai-academy.asia', password: 'nuutsug');

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.ai-academy.asia/auth/login');
      expect(sent.headers[HttpHeaders.contentTypeHeader], contains('application/json'));
      expect(sent.headers[HttpHeaders.acceptHeader], 'application/json');
      expect(jsonDecode(sent.body), {
        'email': 'suragch@ai-academy.asia',
        'password': 'nuutsug',
      });
    });

    test('sends exactly the two contract keys, and nothing else', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return http.Response(jsonEncode({'access_token': 'tok'}), 200);
      });

      await repository.signIn(email: 'a@b.mn', password: 'p');

      expect((jsonDecode(sent.body) as Map).keys, unorderedEquals(['email', 'password']));
    });
  });

  group('a successful response', () {
    test('reads the token and the reported lifetime', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(
          jsonEncode({'access_token': 'tok-123', 'expires_in': 3600}),
          200,
        ),
      );

      final session = await repository.signIn(email: 'a@b.mn', password: 'p');

      expect(session.accessToken, 'tok-123');
      expect(session.expiresIn, const Duration(hours: 1));
    });

    test('carries a missing expires_in through as null rather than guessing', () async {
      final repository = repositoryReturning(
        (_) async => http.Response(jsonEncode({'access_token': 'tok-123'}), 200),
      );

      final session = await repository.signIn(email: 'a@b.mn', password: 'p');

      expect(session.accessToken, 'tok-123');
      expect(session.expiresIn, isNull);
    });

    test('ignores a nonsensical expires_in instead of dating the token', () async {
      final repository = repositoryReturning(
        (_) async =>
            http.Response(jsonEncode({'access_token': 'tok', 'expires_in': 0}), 200),
      );

      expect((await repository.signIn(email: 'a@b.mn', password: 'p')).expiresIn, isNull);
    });
  });

  group('failures', () {
    Future<AuthFailure> failureFrom(HttpAuthRepository repository) async {
      try {
        await repository.signIn(email: 'a@b.mn', password: 'p');
      } on AuthFailure catch (failure) {
        return failure;
      }
      fail('expected an AuthFailure');
    }

    test('401 and 403 are rejected credentials, not server faults', () async {
      for (final status in [401, 403]) {
        final failure = await failureFrom(
          repositoryReturning(
            (_) async => http.Response('{"error":"unauthorized"}', status),
          ),
        );
        expect(failure.kind, AuthFailureKind.invalidCredentials, reason: 'HTTP $status');
      }
    });

    test('the login 401 stays a credentials refusal', () async {
      // /auth/login answers {"error":"invalid_credentials"}, which must not be
      // caught by the session-code handling added for change-password.
      final failure = await failureFrom(
        repositoryReturning(
          (_) async => http.Response('{"error":"invalid_credentials"}', 401),
        ),
      );
      expect(failure.kind, AuthFailureKind.invalidCredentials);
    });

    test('5xx is a server fault', () async {
      for (final status in [500, 503]) {
        final failure = await failureFrom(
          repositoryReturning((_) async => http.Response('boom', status)),
        );
        expect(failure.kind, AuthFailureKind.server, reason: 'HTTP $status');
      }
    });

    test('other non-2xx are unexpected', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('{"error":"not_found"}', 404)),
      );
      expect(failure.kind, AuthFailureKind.unexpected);
    });

    test('a 200 with no token is a server fault, not a silent success', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response(jsonEncode({'ok': true}), 200)),
      );
      expect(failure.kind, AuthFailureKind.server);
      expect(failure.detail, contains('access_token'));
    });

    test('a 200 with an empty token is rejected too', () async {
      final failure = await failureFrom(
        repositoryReturning(
          (_) async => http.Response(jsonEncode({'access_token': ''}), 200),
        ),
      );
      expect(failure.kind, AuthFailureKind.server);
    });

    test('a malformed body is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('<html>nope</html>', 200)),
      );
      expect(failure.kind, AuthFailureKind.server);
      expect(failure.detail, contains('malformed JSON'));
    });

    test('a JSON array instead of an object is a server fault', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => http.Response('[]', 200)),
      );
      expect(failure.kind, AuthFailureKind.server);
    });

    test('an unreachable host is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw const SocketException('no route to host')),
      );
      expect(failure.kind, AuthFailureKind.network);
    });

    test('a client exception is a network failure', () async {
      final failure = await failureFrom(
        repositoryReturning((_) async => throw http.ClientException('connection closed')),
      );
      expect(failure.kind, AuthFailureKind.network);
    });

    test('a slow backend times out rather than hanging the form', () async {
      final repository = HttpAuthRepository(
        client: MockClient(
          (_) => Future.delayed(
            const Duration(milliseconds: 200),
            () => http.Response('{}', 200),
          ),
        ),
        timeout: const Duration(milliseconds: 20),
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, AuthFailureKind.network);
      expect(failure.detail, 'request timed out');
    });
  });

  group('configuration', () {
    test('the default base URL is the contract host', () {
      expect(HttpAuthRepository.defaultBaseUrl, 'https://api.ai-academy.asia');
    });

    test('a base URL can be overridden without touching the path', () async {
      late Uri url;
      final repository = HttpAuthRepository(
        baseUrl: Uri.parse('https://staging.example.test'),
        client: MockClient((request) async {
          url = request.url;
          return http.Response(jsonEncode({'access_token': 'tok'}), 200);
        }),
      );

      await repository.signIn(email: 'a@b.mn', password: 'p');

      expect(url.toString(), 'https://staging.example.test/auth/login');
    });
  });
}
