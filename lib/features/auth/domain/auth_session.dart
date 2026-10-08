import 'user_type.dart';

/// A signed-in session: the bearer token the API issued, and how long it lasts.
///
/// Held — and, in the app, persisted across restarts — by `AuthSessionStore`
/// (Issue #235).
class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.userType = UserType.unknown,
  });

  final String accessToken;

  /// The login (or refresh) response's `refresh_token`: what `SessionRefresher`
  /// renews the session with (`POST /auth/refresh`, rotated on every renewal)
  /// and sign-out revokes (`POST /auth/logout`). Null when the response
  /// carried none.
  final String? refreshToken;

  /// Which app experience the login response says to open. [UserType.unknown]
  /// when it carried none.
  final UserType userType;

  /// Lifetime reported by the backend. Absent when it does not report one.
  final Duration? expiresIn;
}
