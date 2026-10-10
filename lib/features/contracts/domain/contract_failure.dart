/// Why a contract request did not succeed (Issue #294).
enum ContractFailureKind {
  /// No usable session, or a 401 the session could not recover from.
  sessionExpired,

  /// The request never completed.
  network,

  /// A 5xx, or a body that does not match the verified envelope.
  server,

  /// Anything else — including a 403 or 404, whose meaning on this endpoint
  /// is not documented.
  unexpected,
}

class ContractFailure implements Exception {
  const ContractFailure(this.kind, {this.detail});

  final ContractFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() =>
      'ContractFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
