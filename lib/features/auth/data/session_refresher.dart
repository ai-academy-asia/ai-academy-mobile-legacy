import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/auth_session_store.dart';
import '../domain/user_type.dart';
import 'http_auth_repository.dart';

/// Renews the signed-in session with its refresh token (Issue #176).
///
/// **One refresh at a time.** The backend rotates the refresh token on every
/// exchange and refuses a spent one (`401 refresh_token_reused`), so two
/// refreshes racing with the same token would end the session. [refresh]
/// therefore runs at most one `POST /auth/refresh`: a caller arriving while
/// one is in flight waits for that same result, and a caller whose rejected
/// token has already been replaced is told to retry with the current one
/// without refreshing again.
///
/// **On success** the store holds the new access token, the rotated refresh
/// token, the new lifetime, and the user type (the old one when the response
/// carries none).
///
/// **On failure** — a refused or spent refresh token, no refresh token at
/// all, or a refresh that could not complete — the local session is cleared
/// and [onSessionEnded] fires once. `POST /auth/logout` is not called: the
/// refresh token is already unusable, and local sign-out never depends on the
/// server.
class SessionRefresher {
  SessionRefresher({
    required AuthSessionStore sessionStore,
    AuthRepository? authRepository,
    this.onSessionEnded,
  }) : _store = sessionStore,
       _auth = authRepository ?? HttpAuthRepository();

  /// The app's own, on [AuthSessionStore.instance]. `main` sets its
  /// [onSessionEnded] to return to Login.
  static final SessionRefresher instance = SessionRefresher(
    sessionStore: AuthSessionStore.instance,
  );

  final AuthSessionStore _store;
  final AuthRepository _auth;

  /// Called once each time a refresh fails and the session is cleared.
  VoidCallback? onSessionEnded;

  Future<bool>? _inFlight;

  /// Makes the session usable again after [failedToken] was refused (or ran
  /// out locally). Completes with true when the store now holds an access
  /// token to retry with, false when the session has ended.
  Future<bool> refresh({String? failedToken}) {
    // Already ended (or never signed in): nothing to renew, and the session's
    // end has been signalled once already.
    if (!_store.isSignedIn) return Future.value(false);
    final current = _store.accessToken;
    // Another request's refresh already replaced the token that failed.
    if (failedToken != null && current != null && current != failedToken) {
      return Future.value(true);
    }
    final running = _inFlight ??= _run();
    unawaited(
      running.whenComplete(() {
        if (identical(_inFlight, running)) _inFlight = null;
      }),
    );
    return running;
  }

  Future<bool> _run() async {
    final session = _store.session;
    final refreshToken = session?.refreshToken;
    if (session == null || refreshToken == null) {
      _end();
      return false;
    }

    final AuthSession renewed;
    try {
      renewed = await _auth.refresh(refreshToken: refreshToken);
    } catch (_) {
      // Signed out (or in again) meanwhile: that session is not this one's
      // to end.
      if (identical(_store.session, session)) _end();
      return false;
    }

    // Signed out (or in again) while the refresh was in flight: never bring
    // the old session back.
    if (!identical(_store.session, session)) return _store.isSignedIn;

    _store.save(
      AuthSession(
        accessToken: renewed.accessToken,
        refreshToken: renewed.refreshToken ?? refreshToken,
        expiresIn: renewed.expiresIn,
        userType: renewed.userType == UserType.unknown
            ? session.userType
            : renewed.userType,
      ),
    );
    return true;
  }

  void _end() {
    _store.clear();
    onSessionEnded?.call();
  }
}
