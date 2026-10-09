import 'dart:async';
import 'dart:convert';

import 'package:aia_mobile/core/theme/app_theme_controller.dart';
import 'package:aia_mobile/core/theme/theme_preference.dart';
import 'package:aia_mobile/features/auth/data/http_current_user_repository.dart';
import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/auth/domain/session_persistence.dart';
import 'package:aia_mobile/features/auth/presentation/account_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/theme_storage.dart';

/// The theme preference is the signed-in account's own, not the device's
/// (Issue #286), through every sign-in, sign-out, restore and renewal.
///
/// Three accounts on one device, each signing in with its own token, which
/// the real `/auth/me` repository answers with its account `id`:
/// Adult A (9), Junior B (12), Teacher C (31).
void main() {
  const accounts = {
    'token-A': (id: 9, userType: 'adult'),
    'token-B': (id: 12, userType: 'child'),
    'token-C': (id: 31, userType: 'teacher'),
  };

  /// Held `/auth/me` answers, by token, for the stale-answer tests.
  final gates = <String, Completer<void>>{};

  final client = MockClient((request) async {
    final token = request.headers['Authorization']!.split(' ').last;
    await gates[token]?.future;
    final account = accounts[token]!;
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'actor_id': account.id + 100,
          'actor_type': account.userType == 'teacher' ? 'teacher' : 'student',
          'email': 'account${account.id}@example.mn',
          'id': account.id,
          'is_active': true,
          'must_change_password': false,
          'profile': {
            'first_name': 'Test',
            'id': account.id + 200,
            'last_name': 'Account',
            'phone': '99000000',
            'ui_mode': null,
          },
          'role': account.userType == 'teacher' ? 'teacher' : 'student',
          'user_type': account.userType,
        }),
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  late MemoryThemeStorage themes;
  late _MemorySession sessionStorage;
  late AuthSessionStore store;
  late AppThemeController theme;

  /// As `main()` does on launch.
  Future<void> launch() async {
    store = AuthSessionStore();
    await store.attach(sessionStorage);
    theme = AppThemeController();
    await theme.attach(themes);
    await followAccountTheme(store, theme);
  }

  /// As `LoginScreen` does: save the session, read `/auth/me` (which
  /// identifies the account), and wait for its theme before Home.
  Future<void> signIn(String token) async {
    store.save(AuthSession(accessToken: token));
    await HttpCurrentUserRepository(
      client: client,
      sessionStore: store,
    ).getCurrentUser();
    await theme.ready;
  }

  /// What `signOutToLogin` does locally.
  void signOut() => store.clear();

  setUp(() async {
    gates.clear();
    themes = MemoryThemeStorage();
    sessionStorage = _MemorySession();
    await launch();
  });

  test('Adult A chooses Dark → signs out → Junior B signs in: Light', () async {
    await signIn('token-A');
    await theme.setLightMode(false);
    expect(theme.mode, ThemeMode.dark);
    expect(themes.values, {'9': 'dark'});

    signOut();
    expect(theme.mode, ThemeMode.light, reason: 'Login, signed out');
    await signIn('token-B');
    expect(theme.account, '12');
    expect(theme.mode, ThemeMode.light);
    expect(theme.lightModeOn, isTrue);
  });

  test('Junior B chooses Light → signs out → Teacher C signs in: Light, its '
      'default', () async {
    await signIn('token-B');
    await theme.setLightMode(true);
    signOut();
    await signIn('token-C');
    expect(theme.mode, ThemeMode.light);
    expect(themes.values.containsKey('31'), isFalse);
  });

  test('Adult A returns, after B and C: A\'s own Dark', () async {
    await signIn('token-A');
    await theme.setLightMode(false);
    for (final other in ['token-B', 'token-C']) {
      signOut();
      await signIn(other);
      expect(theme.mode, ThemeMode.light, reason: other);
    }
    signOut();
    await signIn('token-A');
    expect(theme.mode, ThemeMode.dark);
    expect(theme.lightModeOn, isFalse);
  });

  test('each account switches and keeps its own choice', () async {
    final chosen = {'token-A': false, 'token-B': true, 'token-C': false};
    for (final MapEntry(key: token, value: light) in chosen.entries) {
      await signIn(token);
      await theme.setLightMode(light);
      signOut();
    }
    expect(themes.values, {'9': 'dark', '12': 'light', '31': 'dark'});
    for (final MapEntry(key: token, value: light) in chosen.entries) {
      await signIn(token);
      expect(theme.lightModeOn, light, reason: token);
      signOut();
    }
  });

  test('the same account signing out and in again gets its choice back, '
      'and sign-out deletes nothing', () async {
    await signIn('token-C');
    await theme.setLightMode(false);
    signOut();
    expect(themes.values, {'31': 'dark'});
    await signIn('token-C');
    expect(theme.mode, ThemeMode.dark);
  });

  test('a restart restores the signed-in account\'s choice before the first '
      'frame — no /auth/me needed', () async {
    await signIn('token-A');
    await theme.setLightMode(false);
    await store.flush();

    await launch();
    expect(store.userId, 9);
    expect(theme.mode, ThemeMode.dark);
  });

  test('a restart signed out is Light, whoever chose Dark last', () async {
    await signIn('token-A');
    await theme.setLightMode(false);
    signOut();
    await store.flush();

    await launch();
    expect(theme.account, isNull);
    expect(theme.mode, ThemeMode.light);
  });

  test('a renewal is the same account: its theme stays', () async {
    await signIn('token-A');
    await theme.setLightMode(false);
    store.save(
      const AuthSession(accessToken: 'token-A2', refreshToken: 'r'),
      renewal: true,
    );
    await theme.ready;
    expect(store.userId, 9);
    expect(theme.mode, ThemeMode.dark);
  });

  test('any clear — a rejected token, a failed renewal — is Light, and the '
      'account\'s choice is kept', () async {
    await signIn('token-A');
    await theme.setLightMode(false);
    store.clear(); // as a 401 or `SessionRefresher` does
    expect(theme.mode, ThemeMode.light);
    expect(themes.values, {'9': 'dark'});
  });

  test('between sign-in and /auth/me the account is unknown: Light, never '
      'the previous account\'s Dark', () async {
    await signIn('token-A');
    await theme.setLightMode(false);
    signOut();

    gates['token-B'] = Completer<void>();
    store.save(const AuthSession(accessToken: 'token-B'));
    expect(theme.mode, ThemeMode.light);
    final identifying = HttpCurrentUserRepository(
      client: client,
      sessionStore: store,
    ).getCurrentUser();
    expect(theme.mode, ThemeMode.light);
    gates['token-B']!.complete();
    await identifying;
    await theme.ready;
    expect(theme.account, '12');
    expect(theme.mode, ThemeMode.light);
  });

  test('a late /auth/me answer for A never identifies B\'s session', () async {
    themes.values['9'] = 'dark';
    gates['token-A'] = Completer<void>();
    store.save(const AuthSession(accessToken: 'token-A'));
    final late = HttpCurrentUserRepository(
      client: client,
      sessionStore: store,
    ).getCurrentUser();

    // A signs out and B signs in while A's answer is still on its way.
    signOut();
    await signIn('token-B');
    gates['token-A']!.complete();
    await late;
    await theme.ready;

    expect(store.userId, 12);
    expect(theme.account, '12');
    expect(theme.mode, ThemeMode.light);
  });

  test('a session saved before Issue #286 carries no account: Light until '
      '/auth/me identifies it, then its own choice', () async {
    themes.values['9'] = 'dark';
    sessionStorage.value = jsonEncode({
      'access_token': 'token-A',
      'refresh_token': null,
      'expires_at': null,
      'user_type': 'adult',
    });
    await launch();
    expect(store.isSignedIn, isTrue);
    expect(theme.mode, ThemeMode.light);

    await HttpCurrentUserRepository(
      client: client,
      sessionStore: store,
    ).getCurrentUser();
    await theme.ready;
    expect(theme.mode, ThemeMode.dark);
  });

  test('the legacy device-wide Dark is deleted on launch and reaches no '
      'account', () async {
    themes = MemoryThemeStorage({}, 'dark');
    await launch();
    expect(themes.legacy, isNull);
    for (final token in accounts.keys) {
      await signIn(token);
      expect(theme.mode, ThemeMode.light, reason: token);
      expect(theme.preference, ThemePreference.light, reason: token);
      signOut();
    }
  });
}

/// The session's secure storage, in memory.
class _MemorySession implements SessionPersistence {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  @override
  Future<void> delete() async => value = null;
}
