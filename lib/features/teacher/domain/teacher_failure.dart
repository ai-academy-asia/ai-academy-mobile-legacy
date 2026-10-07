/// Why Teacher Home could not load the teacher's classes.
///
/// Its own family, as every authenticated feature keeps one, so a `switch`
/// over it never carries a case that cannot occur here.
enum TeacherFailureKind {
  /// No usable session: nobody is signed in, the session's lifetime has run
  /// out, or the API refused the token with a 401.
  sessionExpired,

  /// The API refused the request itself — a 4xx other than 401, or the
  /// signed-in account is not a teacher.
  rejected,

  /// The request never completed — no connectivity, DNS failure, timeout.
  network,

  /// The API answered with a fault of its own: 5xx, or a 2xx body that did
  /// not match the verified shape.
  server,

  /// A status this client has no more specific reading for.
  unexpected,
}

class TeacherFailure implements Exception {
  const TeacherFailure(this.kind, {this.detail});

  final TeacherFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() =>
      'TeacherFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
