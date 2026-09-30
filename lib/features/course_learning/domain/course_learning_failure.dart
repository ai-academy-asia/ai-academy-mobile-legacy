/// Why a Course Learning request did not produce data.
///
/// Its own type, for the reason every other failure family in this codebase
/// is its own type (`docs/ai/DATA_AND_API.md` §4): the neighbouring enums
/// either lack a case this endpoint really answers with — `ApiFailureKind`
/// has no refused session and nothing for "enrolled in this course? no" — or
/// carry cases that cannot occur here, the way
/// `AuthFailureKind.invalidCredentials` cannot on a request that sends no
/// password. The repository classifies; the words the student reads live in
/// `CourseLearningStrings`.
enum CourseLearningFailureKind {
  /// No usable session: nobody is signed in, the session's reported lifetime
  /// has run out, or the API refused the token with a 401. Signing in again
  /// is the only recovery — the API has no refresh endpoint this app calls.
  sessionExpired,

  /// HTTP 403. `course_learning_api_contract_v1.md` §2.1 documents exactly one
  /// 403 for this endpoint — `not_enrolled` — so for the case the endpoint
  /// names, the status alone already carries the meaning and the error body
  /// need not be read.
  ///
  /// The body *is* readable: §0 documents the envelope as
  /// `{"error": "<code>", ...extra}` and says the app branches on `error`,
  /// never on its text. So this is a choice about what is worth reading here,
  /// not a shape that is unconfirmed.
  ///
  /// **What that choice costs.** §0's general status table allows two codes on
  /// a 403 — `forbidden` (wrong actor) as well as `not_enrolled` — and this
  /// repository does not tell them apart: every 403 is reported as this kind.
  /// A token whose actor is not a student (`mobile_api_v1_1.md` has
  /// `user_type` returning `teacher`) would therefore read "not enrolled"
  /// rather than "wrong account". Distinguishing them means reading
  /// `error` out of the body and giving `forbidden` its own kind and copy.
  notEnrolled,

  /// HTTP 404 — the contract's `course_not_found`, `module_not_found` or
  /// `lesson_not_found`: an id or slug that no longer resolves.
  notFound,

  /// HTTP 409 — §2.3's `lesson_locked`: the lesson's module is still locked.
  /// Its own kind so the state is never mistaken for a transient fault; the
  /// copy is the generic one until the design gives it words of its own.
  locked,

  /// HTTP 400 `content_required` — §2.5's note save was sent empty once the
  /// server trimmed it. Read from the body's `error` code, since 400 alone
  /// does not say which rule was broken.
  contentRequired,

  /// HTTP 400 `content_too_long` — §2.5's note is over its 5000 characters.
  contentTooLong,

  /// The request never completed — no connectivity, DNS failure, timeout.
  network,

  /// The API answered with a fault of its own: 5xx, or a 200 body that did
  /// not match the contract's shape.
  server,

  /// A status this client has no more specific reading for — any other 4xx.
  unexpected,
}

class CourseLearningFailure implements Exception {
  const CourseLearningFailure(this.kind, {this.detail});

  final CourseLearningFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  @override
  String toString() =>
      'CourseLearningFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
