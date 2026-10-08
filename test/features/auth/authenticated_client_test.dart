import 'dart:async';
import 'dart:convert';

import 'package:aia_mobile/features/auth/data/authenticated_client.dart';
import 'package:aia_mobile/features/auth/data/session_refresher.dart';
import 'package:aia_mobile/features/auth/domain/auth_failure.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/domain/user_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_auth_repository.dart';

/// [AuthenticatedClient] and [SessionRefresher] (Issue #176): an expired
/// access token is renewed once, the request retried once, and a session that
/// cannot be renewed ends exactly once.
void main() {
  final url = Uri.parse('https://api.ai-academy.asia/me/attendance?course=x');
  const tokenExpired = '{"error":"token_expired"}';

  late AuthSessionStore store;
  late FakeAuthRepository auth;
  late SessionRefresher refresher;
  late int sessionsEnded;

  /// Every request the server saw, by its bearer token.
  late List<String?> sentTokens;

  setUp(() {
    store = AuthSessionStore()
      ..save(
        const AuthSession(
          accessToken: 'old',
          refreshToken: 'r1',
          userType: UserType.adult,
        ),
      );
    auth = FakeAuthRepository()
      ..refreshed = const AuthSession(
        accessToken: 'new',
        refreshToken: 'r2',
        expiresIn: Duration(hours: 1),
        userType: UserType.adult,
      );
    sessionsEnded = 0;
    refresher = SessionRefresher(
      sessionStore: store,
      authRepository: auth,
      onSessionEnded: () => sessionsEnded++,
    );
    sentTokens = [];
  });

  /// A server that refuses `old` with [refusal] and accepts anything else.
  AuthenticatedClient clientFor({
    String refusal = tokenExpired,
    bool refuseNewToo = false,
  }) => AuthenticatedClient(
    sessionStore: store,
    refresher: refresher,
    inner: MockClient((request) async {
      final token = request.headers['Authorization']?.substring(7);
      sentTokens.add(token);
      if (token == 'old' || (refuseNewToo && token == 'new')) {
        return http.Response(refusal, 401);
      }
      return http.Response('{"ok":true}', 200);
    }),
  );

  Future<http.Response> get(AuthenticatedClient client, [String? token]) =>
      client.get(
        url,
        headers: {'Authorization': 'Bearer ${token ?? store.accessToken}'},
      );

  test('a valid request goes through untouched', () async {
    store.save(const AuthSession(accessToken: 'fine', refreshToken: 'r1'));

    final response = await get(clientFor());

    expect(response.statusCode, 200);
    expect(sentTokens, ['fine']);
    expect(auth.refreshCalls, isEmpty);
  });

  test('a token failure is refreshed, stored and retried once', () async {
    final response = await get(clientFor());

    expect(response.statusCode, 200);
    expect(response.body, '{"ok":true}');
    expect(auth.refreshCalls, ['r1']);
    expect(sentTokens, ['old', 'new']);
    // The new session, rotated refresh token and lifetime included.
    expect(store.accessToken, 'new');
    expect(store.session?.refreshToken, 'r2');
    expect(store.expiresAt, isNotNull);
    expect(store.session?.userType, UserType.adult);
    expect(sessionsEnded, 0);
  });

  for (final code in AuthenticatedClient.tokenFailureCodes) {
    test('refreshes on the contract\'s 401 "$code"', () async {
      final response = await get(clientFor(refusal: '{"error":"$code"}'));

      expect(response.statusCode, 200);
      expect(auth.refreshCalls, ['r1']);
    });
  }

  test(
    'a retry that is refused again is returned, not refreshed again',
    () async {
      final response = await get(clientFor(refuseNewToo: true));

      expect(response.statusCode, 401);
      expect(response.body, tokenExpired);
      expect(auth.refreshCalls, ['r1']);
      expect(sentTokens, ['old', 'new']);
    },
  );

  test('a failed refresh clears the session, signals once, and returns the '
      '401', () async {
    auth.refreshed = null;
    auth.refreshFailure = const AuthFailure(
      AuthFailureKind.invalidCredentials,
      detail: 'HTTP 401',
    );

    final response = await get(clientFor());

    expect(response.statusCode, 401);
    expect(store.isSignedIn, isFalse);
    expect(sessionsEnded, 1);
    expect(sentTokens, ['old']);
  });

  for (final kind in SessionRefresher.transientFailures) {
    test('a ${kind.name} failure during refresh keeps the session for the '
        'next request (Issue #235)', () async {
      final renewed = auth.refreshed;
      auth.refreshed = null;
      auth.refreshFailure = AuthFailure(kind);
      final client = clientFor();

      final response = await get(client);

      // The refresh token was never refused: nothing ends.
      expect(response.statusCode, 401);
      expect(store.isSignedIn, isTrue);
      expect(store.session?.refreshToken, 'r1');
      expect(sessionsEnded, 0);

      // Back online, the same refresh token renews it.
      auth.refreshFailure = null;
      auth.refreshed = renewed;
      expect((await get(client)).statusCode, 200);
      expect(auth.refreshCalls, ['r1', 'r1']);
      expect(store.session?.refreshToken, 'r2');
    });
  }

  test('a session with no refresh token ends instead of refreshing', () async {
    store.save(const AuthSession(accessToken: 'old'));

    final response = await get(clientFor());

    expect(response.statusCode, 401);
    expect(auth.refreshCalls, isEmpty);
    expect(store.isSignedIn, isFalse);
    expect(sessionsEnded, 1);
  });

  group('concurrent failures', () {
    test('share one refresh, and every retry uses the new token', () async {
      final gate = Completer<void>();
      auth.refreshGate = gate;
      final client = clientFor();

      final responses = Future.wait([get(client), get(client), get(client)]);
      // Let all three be refused while the refresh is held.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      gate.complete();

      expect((await responses).map((r) => r.statusCode), [200, 200, 200]);
      expect(auth.refreshCalls, ['r1']);
      expect(sentTokens.where((t) => t == 'old'), hasLength(3));
      expect(sentTokens.where((t) => t == 'new'), hasLength(3));
    });

    test('end the session once when the shared refresh fails', () async {
      final gate = Completer<void>();
      auth
        ..refreshGate = gate
        ..refreshed = null;
      final client = clientFor();

      final responses = Future.wait([get(client), get(client), get(client)]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      gate.complete();

      expect((await responses).map((r) => r.statusCode), [401, 401, 401]);
      expect(auth.refreshCalls, ['r1']);
      expect(sessionsEnded, 1);
    });

    test(
      'a refusal arriving after the refresh retries without another',
      () async {
        final client = clientFor();
        await get(client); // refreshes old -> new

        // A request that went out with the old token before the refresh.
        final late = await get(client, 'old');

        expect(late.statusCode, 200);
        expect(auth.refreshCalls, ['r1']);
      },
    );
  });

  group('left alone', () {
    test(
      'change-password\'s wrong current password (invalid_credentials)',
      () async {
        final response = await get(
          clientFor(refusal: '{"error":"invalid_credentials"}'),
        );

        expect(response.statusCode, 401);
        expect(response.body, '{"error":"invalid_credentials"}');
        expect(auth.refreshCalls, isEmpty);
        expect(store.accessToken, 'old');
        expect(sessionsEnded, 0);
      },
    );

    test('a 401 with no recognisable code', () async {
      final response = await get(clientFor(refusal: 'nope'));

      expect(response.statusCode, 401);
      expect(auth.refreshCalls, isEmpty);
    });

    test('a request without an Authorization header', () async {
      final response = await clientFor().get(url);

      expect(response.statusCode, 200);
      expect(sentTokens, [null]);
      expect(auth.refreshCalls, isEmpty);
    });

    test('other statuses', () async {
      final client = AuthenticatedClient(
        sessionStore: store,
        refresher: refresher,
        inner: MockClient((_) async => http.Response(tokenExpired, 403)),
      );

      expect((await get(client)).statusCode, 403);
      expect(auth.refreshCalls, isEmpty);
    });
  });

  test('a locally expired access token is renewed before sending', () async {
    store.save(
      const AuthSession(
        accessToken: 'old',
        refreshToken: 'r1',
        expiresIn: Duration(hours: 1),
      ),
      now: DateTime.now().subtract(const Duration(hours: 2)),
    );
    // A refreshable session is not "expired" to the repositories' guard.
    expect(store.isExpired(), isFalse);
    expect(store.isAccessTokenExpired(), isTrue);

    final response = await get(clientFor());

    expect(response.statusCode, 200);
    expect(sentTokens, ['new']);
    expect(auth.refreshCalls, ['r1']);
  });

  test('an upload is retried with exactly the same body', () async {
    final bodies = <List<int>>[];
    final contentTypes = <String?>[];
    final client = AuthenticatedClient(
      sessionStore: store,
      refresher: refresher,
      inner: MockClient((request) async {
        bodies.add(request.bodyBytes);
        contentTypes.add(request.headers['content-type']);
        return request.headers['Authorization'] == 'Bearer old'
            ? http.Response(tokenExpired, 401)
            : http.Response('{"id":1}', 201);
      }),
    );
    final upload = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer old'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          utf8.encode('hello'),
          filename: 'a.txt',
        ),
      );

    final response = await http.Response.fromStream(await client.send(upload));

    expect(response.statusCode, 201);
    expect(bodies, hasLength(2));
    expect(bodies[1], bodies[0]);
    expect(contentTypes[1], contentTypes[0]);
    expect(contentTypes[0], startsWith('multipart/form-data; boundary='));
  });

  test('signing out while a refresh is in flight is not undone', () async {
    final gate = Completer<void>();
    auth.refreshGate = gate;

    final response = get(clientFor());
    await Future<void>.delayed(Duration.zero);
    store.clear(); // "Гарах" meanwhile
    gate.complete();

    expect((await response).statusCode, 401);
    expect(store.isSignedIn, isFalse);
    expect(sessionsEnded, 0);
  });

  test('keeps the user type when the refresh response has none', () async {
    auth.refreshed = const AuthSession(accessToken: 'new', refreshToken: 'r2');

    await get(clientFor());

    expect(store.session?.userType, UserType.adult);
  });
}
