import 'current_user.dart';

abstract interface class CurrentUserRepository {
  /// The signed-in user's own account.
  ///
  /// Throws `CurrentUserFailure` when there is no usable session, the API
  /// refuses or cannot be reached, or the response does not match the
  /// modeled shape.
  Future<CurrentUser> getCurrentUser();
}
