/// Why an enrollment attempt did not produce an enrollment.
///
/// A type of its own, for the reason `ApiFailure` gives for existing: the
/// neighbouring types either carry cases that cannot occur here
/// (`AuthFailureKind.invalidCredentials` — this request sends no password) or
/// lack one that can (`ApiFailureKind` has no refused session). The repository
/// classifies; the words the student reads live with the screen.
enum EnrollmentFailureKind {
  /// No usable session: nobody is signed in, the session's reported lifetime
  /// has run out, or the API refused the token with a 401. Signing in again is
  /// the only recovery — the API has no refresh endpoint.
  sessionExpired,

  /// The API refused the enrollment itself — a 4xx other than 401. The
  /// contract confirms no error codes, so the reason (already enrolled, a full
  /// or closed cohort, a non-student account) is not told apart.
  rejected,

  /// The request never completed — no connectivity, DNS failure, timeout.
  network,

  /// The API answered with a fault of its own: 5xx, or a 2xx body that did not
  /// match the confirmed shape.
  server,

  /// A status this client has no more specific reading for.
  unexpected,
}

class EnrollmentFailure implements Exception {
  const EnrollmentFailure(this.kind, {this.detail});

  final EnrollmentFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() =>
      'EnrollmentFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
