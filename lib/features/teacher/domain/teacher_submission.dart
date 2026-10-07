/// A student's submission as the teacher reviews it —
/// `GET /teacher/submissions/{submission_id}` (Issue #233).
///
/// Only the confirmed fields are modelled: `status` (`"submitted"` while it
/// waits for review, `"reviewed"` once reviewed) with the review's `score`
/// and `feedback`. The response's `history` (the previous versions) is
/// confirmed but not drawn, so it is not modelled. The submission's content
/// — its file, link or description — has no confirmed field: `BACKEND GAP`.
class TeacherSubmission {
  const TeacherSubmission({
    required this.id,
    required this.status,
    this.score,
    this.feedback,
  });

  final int id;

  /// The wire value, kept raw: only `submitted` and `reviewed` are
  /// confirmed, so the set is not known to be closed.
  final String status;

  /// The review's score — present once reviewed. A number on the wire (the
  /// review request sends an integer; the response's type is not pinned).
  final num? score;

  /// The review's feedback — present once reviewed.
  final String? feedback;

  bool get isReviewed => status == SubmissionStatus.reviewed;
  bool get isPending => status == SubmissionStatus.submitted;
}

/// The confirmed `status` values of a teacher submission.
abstract final class SubmissionStatus {
  /// Waiting for the teacher's review — "Хүлээгдэж буй".
  static const String submitted = 'submitted';

  /// Reviewed, with a score and feedback — "Дүгнэгдсэн".
  static const String reviewed = 'reviewed';
}

/// The Gradebook student list's filter chips.
enum GradebookFilter {
  /// Бүгд — every row.
  all,

  /// Хүлээгдэж буй — `status: "submitted"`.
  pending,

  /// Дүгнэгдсэн — `status: "reviewed"`.
  graded,
}

/// Whether a submission with the wire [status] belongs under [filter]. A
/// status other than the two confirmed ones shows under Бүгд only — it is
/// never guessed into pending or graded.
bool matchesFilter(String status, GradebookFilter filter) => switch (filter) {
  GradebookFilter.all => true,
  GradebookFilter.pending => status == SubmissionStatus.submitted,
  GradebookFilter.graded => status == SubmissionStatus.reviewed,
};
