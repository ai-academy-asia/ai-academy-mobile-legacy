import '../domain/password_repository.dart';

/// A stand-in for a backend that does not exist yet.
///
/// This talks to nothing. It exists so the reset screen has something to call
/// while the real endpoint is unconfirmed — see [PasswordRepository] for why
/// none was invented. It reports success after a short pause, which is enough
/// to exercise the submitting and success states.
///
/// **Delete this when the real contract lands.** Anything that ships against it
/// will appear to change passwords and will not.
class StubPasswordRepository implements PasswordRepository {
  const StubPasswordRepository({this.delay = const Duration(milliseconds: 600)});

  /// Stands in for round-trip time, so the loading state is visible.
  final Duration delay;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(delay);
  }
}
