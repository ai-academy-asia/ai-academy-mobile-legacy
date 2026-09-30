/// Why a `GET /me/attendance` request did not produce the student's
/// attendance.
///
/// A type of its own, for the reason `CurrentUserFailure` gives: each
/// authenticated endpoint keeps its own failure family, so a `switch` over
/// one never carries a case that cannot occur there.
enum AttendanceFailureKind {
  /// No usable session: nobody is signed in, the session's reported lifetime
  /// has run out, or the API refused the token with a 401.
  sessionExpired,

  /// The API refused the request itself — a 4xx other than 401. No error
  /// codes are documented for this endpoint.
  rejected,

  /// The request never completed — no connectivity, DNS failure, timeout.
  network,

  /// The API answered with a fault of its own: 5xx, or a 2xx body that did not
  /// match the verified shape.
  server,

  /// A status this client has no more specific reading for.
  unexpected,
}

class AttendanceFailure implements Exception {
  const AttendanceFailure(this.kind, {this.detail});

  final AttendanceFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() =>
      'AttendanceFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
