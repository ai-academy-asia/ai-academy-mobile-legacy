import '../../../core/models/localized_text.dart';

/// An assignment of a teacher's class —
/// `GET /teacher/cohorts/{cohort_id}/assignments` (Issue #233).
///
/// Only what the Gradebook reads is modelled: `id`, the title
/// (`title_mn` / `title_en`, falling back to `title`) and `max_score`. The
/// other confirmed fields — `cohort_id`, `lesson_id`, `instructions`,
/// `due_date`, `submitted_students`, `teacher_id`, `is_active`,
/// `attachment` / `attachment_material_id` — are unread. No field names the
/// assignment's module (BACKEND GAP, Issue #390).
class TeacherAssignment {
  const TeacherAssignment({
    required this.id,
    required this.title,
    this.maxScore,
  });

  final int id;
  final LocalizedText title;

  /// The most a review may score. When set, a review must carry a score
  /// from 0 to it (`invalid_score` otherwise); when null, feedback alone is
  /// a review.
  final num? maxScore;

  /// Mongolian first, as every course title is shown.
  String get displayTitle => title.preferred ?? '#$id';
}

/// A person on a submission — its `student`, or its feedback's `mentor`
/// (`{id, name, initials}`).
class SubmissionStudent {
  const SubmissionStudent({
    required this.id,
    required this.name,
    this.initials,
  });

  final int id;
  final String name;

  /// What the avatar shows: no photo URL is in any confirmed response.
  final String? initials;
}

/// A student's submission as the teacher reviews it (Issue #233) — an entry
/// of `GET /teacher/assignments/{assignment_id}/submissions` (the latest
/// per student) or `GET /teacher/submissions/{submission_id}`.
///
/// Modelled: `id`, `assignment_id`, `student`, `status` (`"submitted"`
/// while it waits for review, `"reviewed"` once reviewed), `score`,
/// `feedback.message`, `description`, `link`, `submitted_at`. Confirmed but
/// unread: `feedback.created_at` / `mentor`, `graded_at`, `version`,
/// `version_count`, and the detail's `history`. `file` is not read: only
/// `null` has been seen, and its download (`/file`) is not verified.
class TeacherSubmission {
  const TeacherSubmission({
    required this.id,
    required this.status,
    this.assignmentId,
    this.student,
    this.score,
    this.feedback,
    this.description,
    this.link,
    this.submittedAt,
    this.feedbackAt,
    this.mentor,
  });

  final int id;

  /// The wire value, kept raw: only `submitted` and `reviewed` are
  /// confirmed, so the set is not known to be closed.
  final String status;

  final int? assignmentId;
  final SubmissionStudent? student;

  /// The review's score — present once reviewed.
  final num? score;

  /// The review's feedback text (`feedback.message`) — present once
  /// reviewed.
  final String? feedback;

  /// What the student wrote with the submission.
  final String? description;

  /// The link the student submitted.
  final String? link;

  final DateTime? submittedAt;

  /// When the review was saved — `feedback.created_at`.
  final DateTime? feedbackAt;

  /// Who reviewed it — `feedback.mentor`; null for a staff reviewer.
  final SubmissionStudent? mentor;

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
