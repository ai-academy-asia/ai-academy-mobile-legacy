import 'auth_session.dart';

/// The one thing the login screen needs from the outside world.
///
/// The screen depends on this, never on the HTTP implementation, so the
/// transport can change — a different client, a mock during development, a
/// token cache in front — without the screen being rewritten.
abstract interface class AuthRepository {
  /// Exchanges credentials for a session.
  ///
  /// Throws [AuthFailure] when the exchange does not succeed.
  Future<AuthSession> signIn({required String email, required String password});
}
