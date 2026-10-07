import 'teacher_home_repository.dart';
import 'teacher_submission.dart';

/// What Teacher Gradebook reads (Issue #233). Read-only: no review is sent —
/// the review's response contract is not verified.
///
/// Extends [TeacherHomeRepository] because the Gradebook's classes are
/// exactly Teacher Home's (`GET /teachers/{actor_id}/schedule`).
///
/// Every method throws `TeacherFailure` when there is no usable session, the
/// API refuses or cannot be reached, or the response does not match the
/// confirmed shape.
abstract interface class TeacherGradebookRepository
    implements TeacherHomeRepository {
  /// One submission — `GET /teacher/submissions/{submission_id}`.
  Future<TeacherSubmission> getSubmission(int submissionId);
}
