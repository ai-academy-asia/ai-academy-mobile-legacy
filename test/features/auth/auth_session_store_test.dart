import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthSessionStore store;

  setUp(() => store = AuthSessionStore());

  test('starts signed out', () {
    expect(store.isSignedIn, isFalse);
    expect(store.accessToken, isNull);
    expect(store.authorizationHeader, isEmpty);
  });

  test('keeps the token a sign-in issued', () {
    store.save(const AuthSession(accessToken: 'tok-123'));

    expect(store.isSignedIn, isTrue);
    expect(store.accessToken, 'tok-123');
  });

  test('offers the token as the Bearer header the API expects', () {
    store.save(const AuthSession(accessToken: 'tok-123'));

    expect(store.authorizationHeader, {'Authorization': 'Bearer tok-123'});
  });

  test('dates the session from the reported lifetime', () {
    final now = DateTime(2026, 9, 11, 12);
    store.save(
      const AuthSession(accessToken: 'tok', expiresIn: Duration(hours: 1)),
      now: now,
    );

    expect(store.expiresAt, DateTime(2026, 9, 11, 13));
    expect(store.isExpired(now: now.add(const Duration(minutes: 59))), isFalse);
    expect(store.isExpired(now: now.add(const Duration(hours: 1))), isTrue);
  });

  test('a session with no reported lifetime is never called expired', () {
    // expires_in is optional in the contract, and guessing a lifetime would
    // sign people out for no reason — the backend's 401 is the authority.
    store.save(const AuthSession(accessToken: 'tok'));

    expect(store.expiresAt, isNull);
    expect(store.isExpired(now: DateTime(2099)), isFalse);
  });

  test('clearing forgets the token and its expiry', () {
    store.save(const AuthSession(accessToken: 'tok', expiresIn: Duration(hours: 1)));

    store.clear();

    expect(store.isSignedIn, isFalse);
    expect(store.accessToken, isNull);
    expect(store.expiresAt, isNull);
    expect(store.authorizationHeader, isEmpty);
  });

  test('signing in again replaces the previous session', () {
    store.save(const AuthSession(accessToken: 'first'));
    store.save(const AuthSession(accessToken: 'second'));

    expect(store.accessToken, 'second');
  });
}
