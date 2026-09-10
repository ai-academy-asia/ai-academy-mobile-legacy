/// Why a sign-in attempt did not produce a session.
///
/// The repository classifies the failure; it does not phrase it. The words the
/// user reads live with the screen, so the data layer stays free of UI copy and
/// of any particular language.
enum AuthFailureKind {
  /// The API rejected the email/password pair (401 or 403).
  invalidCredentials,

  /// The request never completed — no connectivity, DNS failure, timeout.
  network,

  /// The API answered, but with a fault of its own (5xx, or a body that did
  /// not contain a token).
  server,

  /// Anything not covered above.
  unexpected,
}

class AuthFailure implements Exception {
  const AuthFailure(this.kind, {this.detail});

  final AuthFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() => 'AuthFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
