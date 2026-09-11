/// Changing the signed-in user's own password.
///
/// Kept separate from `AuthRepository` because it is a different conversation
/// with the backend: sign-in exchanges credentials for a token, this changes a
/// credential while already holding one.
///
/// Implemented by `HttpPasswordRepository` against
/// `POST /auth/change-password`. The screen depends on this rather than on the
/// HTTP class, so the transport can be swapped — a mock during development, a
/// different client — without the screen being rewritten.
///
/// The confirm-password field on the screen is a client-side check and is not
/// part of this contract: only the two passwords the API names cross it.
abstract interface class PasswordRepository {
  /// Replaces the current password with a new one.
  ///
  /// Throws [AuthFailure] when the change does not succeed — in particular
  /// [AuthFailureKind.invalidCredentials] when the backend rejects the current
  /// password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
