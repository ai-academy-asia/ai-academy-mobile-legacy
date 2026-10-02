import 'package:flutter/widgets.dart';

import '../data/http_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session_store.dart';

/// `AiAcademyApp`'s sign-in route, which [signOutToLogin] lands on.
const String loginRoute = '/login';

/// Signs the student out and returns them to the Login screen — the adult and
/// Junior Profile "Гарах" buttons both run this.
///
/// In order:
///
///   1. When the session carries a refresh token, asks the server to revoke
///      it (`POST /auth/logout`, this device only).
///   2. Clears the local session **whatever that request did**. A failed
///      revoke — an error status, no network — is swallowed, never shown: the
///      student asked to leave, and the local sign-out is what decides
///      whether they did. A session with no refresh token skips step 1.
///   3. Replaces the whole stack with [loginRoute], so no authenticated
///      screen is left to go back to.
///
/// [navigator] is taken rather than a `BuildContext` so nothing reads a
/// context across the request's async gap. [repository] and [sessionStore]
/// default to the app's own; tests inject both.
Future<void> signOutToLogin(
  NavigatorState navigator, {
  AuthRepository? repository,
  AuthSessionStore? sessionStore,
}) async {
  final store = sessionStore ?? AuthSessionStore.instance;
  final refreshToken = store.session?.refreshToken;

  if (refreshToken != null) {
    try {
      await (repository ?? HttpAuthRepository()).signOut(
        refreshToken: refreshToken,
      );
    } catch (_) {
      // See step 2: the local sign-out below does not depend on this.
    }
  }

  store.clear();
  navigator.pushNamedAndRemoveUntil(loginRoute, (_) => false);
}
