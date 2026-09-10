/// A signed-in session: the bearer token the API issued, and how long it lasts.
///
/// Nothing persists this yet. The login flow ends at the placeholder home
/// screen, so the token lives only as long as the object holding it. Storing it
/// (and attaching it to later requests) belongs to the screen that first needs
/// an authenticated call.
class AuthSession {
  const AuthSession({required this.accessToken, this.expiresIn});

  final String accessToken;

  /// Lifetime reported by the backend. Absent when it does not report one.
  final Duration? expiresIn;
}
