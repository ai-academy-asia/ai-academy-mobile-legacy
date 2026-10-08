/// Why a notification request did not succeed (Issue #246).
enum NotificationFailureKind {
  /// No usable session, or a 401 the session could not recover from.
  sessionExpired,

  /// `404 notification_not_found` — marking an id that is not the user's.
  notFound,

  /// The request never completed.
  network,

  /// A 5xx, or a body that does not match the verified contract.
  server,

  /// Anything else.
  unexpected,
}

class NotificationFailure implements Exception {
  const NotificationFailure(this.kind, {this.detail});

  final NotificationFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() =>
      'NotificationFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
