import 'dart:async';

import 'package:aia_mobile/features/auth/data/authenticated_client.dart';
import 'package:aia_mobile/features/auth/data/secure_session_persistence.dart';
import 'package:aia_mobile/features/auth/data/session_refresher.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/domain/session_persistence.dart';
import 'package:aia_mobile/features/auth/domain/user_type.dart';
import 'package:aia_mobile/features/auth/presentation/sign_out.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_auth_repository.dart';

/// The session outlives the process (Issue #235): the OS killing a
/// backgrounded app is not a sign-out. Each "restart" below is a fresh
/// [AuthSessionStore] attached to the same storage — exactly what a cold
/// start does in `main`.
void main() {
  late _MemoryPersistence storage;

  setUp(() => storage = _MemoryPersistence());

  /// A cold start: a new store, restored from [storage].
  Future<AuthSessionStore> restart() async {
    final store = AuthSessionStore();
    await store.attach(storage);
    return store;
  }

  test('a signed-in session is restored after a restart', () async {
    final before = await restart();
    final now = DateTime(2026, 10, 8, 12);
    before.save(
      const AuthSession(
        accessToken: 'a1',
        refreshToken: 'r1',
        expiresIn: Duration(hours: 1),
        userType: UserType.child,
      ),
      now: now,
    );
    await before.flush();

    final after = await restart();

    expect(after.isSignedIn, isTrue);
    expect(after.accessToken, 'a1');
    expect(after.session?.refreshToken, 'r1');
    expect(after.session?.userType, UserType.child);
    // The absolute expiry, not a lifetime re-counted from the restart.
    expect(after.expiresAt, DateTime(2026, 10, 8, 13));
  });

  for (final type in UserType.values) {
    test(
      'a ${type.name} session keeps its user type across a restart',
      () async {
        final before = await restart();
        before.save(AuthSession(accessToken: 'a', userType: type));
        await before.flush();

        expect((await restart()).session?.userType, type);
      },
    );
  }

  test('nothing stored restores nothing', () async {
    final store = await restart();

    expect(store.isSignedIn, isFalse);
  });

  test('an unreadable value restores nothing and is deleted', () async {
    storage.value = 'not json';

    final store = await restart();
    await store.flush();

    expect(store.isSignedIn, isFalse);
    expect(storage.value, isNull);
  });

  test(
    'storage that cannot be read restores nothing, without throwing',
    () async {
      storage.readFailure = Exception('keychain locked');

      final store = await restart();

      expect(store.isSignedIn, isFalse);
    },
  );

  test('clearing deletes the stored session', () async {
    final store = await restart();
    store.save(const AuthSession(accessToken: 'a', refreshToken: 'r'));
    store.clear();
    await store.flush();

    expect(storage.value, isNull);
    expect((await restart()).isSignedIn, isFalse);
  });

  test('a sign-out during the restore read is not undone by it', () async {
    storage.value = '{"access_token":"stale","refresh_token":"r"}';
    storage.readGate = Completer<void>();
    final store = AuthSessionStore();

    final attaching = store.attach(storage);
    store.clear();
    storage.readGate!.complete();
    await attaching;

    expect(store.isSignedIn, isFalse);
  });

  test('a store never attached writes nothing', () async {
    AuthSessionStore().save(const AuthSession(accessToken: 'a'));

    expect(storage.writes, 0);
  });

  group('across a restart, through the shared client', () {
    final url = Uri.parse('https://api.ai-academy.asia/auth/me');

    /// A server that accepts only [valid].
    AuthenticatedClient clientFor(
      AuthSessionStore store,
      SessionRefresher refresher,
      String valid,
    ) => AuthenticatedClient(
      sessionStore: store,
      refresher: refresher,
      inner: MockClient((request) async {
        final token = request.headers['Authorization']?.substring(7);
        return token == valid
            ? http.Response('{"ok":true}', 200)
            : http.Response('{"error":"token_expired"}', 401);
      }),
    );

    test('an access token that ran out while closed is renewed, and the '
        'rotated refresh token is what the next launch uses', () async {
      final signedInAt = DateTime.now().subtract(const Duration(hours: 2));
      final first = await restart();
      first.save(
        const AuthSession(
          accessToken: 'a1',
          refreshToken: 'r1',
          expiresIn: Duration(hours: 1),
          userType: UserType.teacher,
        ),
        now: signedInAt,
      );
      await first.flush();

      // Launch 2: the access token is past its lifetime, the session is not.
      final second = await restart();
      expect(second.isAccessTokenExpired(), isTrue);
      expect(second.isExpired(), isFalse);

      final auth = FakeAuthRepository()
        ..refreshed = const AuthSession(
          accessToken: 'a2',
          refreshToken: 'r2',
          expiresIn: Duration(hours: 1),
        );
      var ended = 0;
      final refresher = SessionRefresher(
        sessionStore: second,
        authRepository: auth,
        onSessionEnded: () => ended++,
      );
      final response = await clientFor(
        second,
        refresher,
        'a2',
      ).get(url, headers: second.authorizationHeader);
      await second.flush();

      expect(response.statusCode, 200);
      expect(auth.refreshCalls, ['r1']);
      expect(ended, 0);

      // Launch 3 holds the rotated pair, and the user type the refresh
      // response left out.
      final third = await restart();
      expect(third.accessToken, 'a2');
      expect(third.session?.refreshToken, 'r2');
      expect(third.session?.userType, UserType.teacher);
    });

    test(
      'a refused refresh token ends the session on this device too',
      () async {
        final first = await restart();
        first.save(
          const AuthSession(accessToken: 'a1', refreshToken: 'revoked'),
        );
        await first.flush();

        final store = await restart();
        var ended = 0;
        final refresher = SessionRefresher(
          sessionStore: store,
          // Refuses every refresh — the fake's default.
          authRepository: FakeAuthRepository(),
          onSessionEnded: () => ended++,
        );
        final response = await clientFor(
          store,
          refresher,
          'never',
        ).get(url, headers: store.authorizationHeader);
        await store.flush();

        expect(response.statusCode, 401);
        expect(ended, 1);
        expect(store.isSignedIn, isFalse);
        expect((await restart()).isSignedIn, isFalse);
      },
    );
  });

  testWidgets('an explicit sign-out leaves nothing for the next launch', (
    tester,
  ) async {
    final store = AuthSessionStore();
    await tester.runAsync(() => store.attach(storage));
    store.save(const AuthSession(accessToken: 'a1', refreshToken: 'r1'));
    final auth = FakeAuthRepository();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        routes: {
          '/': (_) => const Text('home'),
          loginRoute: (_) => const Text('login'),
        },
      ),
    );

    await signOutToLogin(
      navigatorKey.currentState!,
      repository: auth,
      sessionStore: store,
    );
    await tester.pumpAndSettle();
    await tester.runAsync(store.flush);

    expect(auth.signOutCalls, ['r1']);
    expect(find.text('login'), findsOneWidget);
    expect(storage.value, isNull);
    expect((await tester.runAsync(restart))!.isSignedIn, isFalse);
  });

  test('SecureSessionPersistence round-trips through secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final secure = SecureSessionPersistence();

    final before = AuthSessionStore();
    await before.attach(secure);
    before.save(const AuthSession(accessToken: 'a1', refreshToken: 'r1'));
    await before.flush();

    final after = AuthSessionStore();
    await after.attach(SecureSessionPersistence());
    expect(after.accessToken, 'a1');
    expect(after.session?.refreshToken, 'r1');

    after.clear();
    await after.flush();
    expect(await secure.read(), isNull);
  });
}

/// Device storage, in memory — one value, like the real one.
class _MemoryPersistence implements SessionPersistence {
  String? value;

  /// Thrown by [read], when set.
  Object? readFailure;

  /// When set, [read] waits for it.
  Completer<void>? readGate;

  int writes = 0;

  @override
  Future<String?> read() async {
    if (readGate case final gate?) await gate.future;
    if (readFailure case final failure?) throw failure;
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    this.value = value;
  }

  @override
  Future<void> delete() async => value = null;
}
