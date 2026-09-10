/// Changing the signed-in user's own password.
///
/// Kept separate from `AuthRepository` because it is a different conversation
/// with the backend: sign-in exchanges credentials for a token, this changes a
/// credential while already holding one.
///
/// **No confirmed API contract exists for this yet.** The only password
/// endpoint anywhere in the AI Academy repos is
/// `POST /admin/students/{id}/reset-password`, which an *administrator* calls
/// with a student id and a new password — it has no current-password field and
/// is not the self-service flow this screen implements. Rather than invent a
/// URL, body and response, the screen depends on this interface and runs
/// against [StubPasswordRepository] until the real endpoint is confirmed.
///
/// Implementing it later means writing one class and passing it in; nothing in
/// the screen or the controller changes.
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
