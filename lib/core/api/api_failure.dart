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

  /// 404 — the resource named in the request does not exist. Split out from
  /// [unexpected] because it is not the API misbehaving: a course slug that
  /// was valid a moment ago (a stale link, a deep link, a course removed
  /// between the catalog load and the tap) is a real, distinguishable outcome
  /// a screen may want to word differently from "something went wrong".
  notFound,

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
