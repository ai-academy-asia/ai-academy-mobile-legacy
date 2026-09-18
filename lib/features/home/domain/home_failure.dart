/// Why the Home dashboard could not be assembled.
///
/// A type of its own, for the reason every other feature's failure type has
/// one: the dashboard is composed from several repositories, each throwing a
/// failure of its own kind (`EnrollmentFailure` from `GET /me/cohorts`,
/// `ApiFailure` from `GET /cohorts` and `GET /courses`). This is the one kind
/// the screen has to phrase, so the composition maps all of them onto it —
/// callers never see which underlying call went wrong.
enum HomeFailureKind {
  /// No usable session: nobody is signed in, the session's reported lifetime
  /// has run out, or the API refused the token. Signing in again is the only
  /// recovery — the API has no refresh endpoint.
  sessionExpired,

  /// The request never completed — no connectivity, DNS failure, timeout.
  network,

  /// The API answered with a fault of its own: 5xx, or a 2xx body that did
  /// not match the confirmed shape.
  server,

  /// Anything this client has no more specific reading for.
  unexpected,
}

class HomeFailure implements Exception {
  const HomeFailure(this.kind, {this.detail});

  final HomeFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() =>
      'HomeFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
