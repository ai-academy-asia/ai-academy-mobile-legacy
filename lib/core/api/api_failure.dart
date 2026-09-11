/// Why a call to a public (non-auth) API endpoint did not produce a result.
///
/// Deliberately separate from `AuthFailureKind`: that type's cases —
/// `invalidCredentials`, `sessionExpired` — describe a login or session being
/// refused, which has no meaning for an endpoint that takes no credentials and
/// holds no session. Forcing this feature's failures through that enum would
/// mean every caller's `switch` carries cases that can never occur here.
enum ApiFailureKind {
  /// The request never completed — no connectivity, DNS failure, timeout.
  network,

  /// The API answered, but with a fault of its own: 5xx, or a 2xx body that
  /// did not match the confirmed shape.
  server,

  /// A non-2xx status this client has no more specific reading for.
  unexpected,
}

class ApiFailure implements Exception {
  const ApiFailure(this.kind, {this.detail});

  final ApiFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() => 'ApiFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
