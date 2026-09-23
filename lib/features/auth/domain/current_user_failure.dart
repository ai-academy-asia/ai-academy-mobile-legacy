/// Why a `GET /auth/me` request did not produce the signed-in user's account.
///
/// A type of its own, for the reason `EnrollmentFailure` gives for existing:
/// `AuthFailureKind.invalidCredentials` cannot occur here — this request
/// sends no password, only the session's bearer token.
enum CurrentUserFailureKind {
  /// No usable session: nobody is signed in, the session's reported lifetime
  /// has run out, or the API refused the token with a 401. Signing in again is
  /// the only recovery — the API has no refresh endpoint.
  sessionExpired,

  /// The API refused the request itself — a 4xx other than 401. The contract
  /// confirms no error codes for this endpoint.
  rejected,

  /// The request never completed — no connectivity, DNS failure, timeout.
  network,

  /// The API answered with a fault of its own: 5xx, or a 2xx body that did not
  /// match the confirmed shape.
  server,

  /// A status this client has no more specific reading for.
  unexpected,
}

class CurrentUserFailure implements Exception {
  const CurrentUserFailure(this.kind, {this.detail});

  final CurrentUserFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() =>
      'CurrentUserFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
