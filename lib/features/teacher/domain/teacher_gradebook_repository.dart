import 'teacher_home_repository.dart';
import 'teacher_submission.dart';

/// What Teacher Programs — formerly the Gradebook — reads and writes
/// (Issues #233, #390): the classes, their roster, assignments and
/// submissions, and a teacher's review.
///
/// Extends [TeacherHomeRepository] because the Gradebook's classes are
/// exactly Teacher Home's (`GET /teachers/{actor_id}/schedule`).
///
/// Every method throws `TeacherFailure` when there is no usable session, the
/// API refuses or cannot be reached, or the response does not match the
/// confirmed shape.
abstract interface class TeacherGradebookRepository
    implements TeacherHomeRepository {
  /// The class's assignments — `GET /teacher/cohorts/{cohort_id}/assignments`.
  Future<List<TeacherAssignment>> getAssignments(int cohortId);

  /// The latest submission of each student who submitted —
  /// `GET /teacher/assignments/{assignment_id}/submissions`.
  Future<List<TeacherSubmission>> getSubmissions(int assignmentId);

  /// One submission — `GET /teacher/submissions/{submission_id}`.
  Future<TeacherSubmission> getSubmission(int submissionId);

  /// The class's enrolled students —
  /// `GET /teacher/cohorts/{cohort_id}/students`.
  Future<List<CohortStudent>> getStudents(int cohortId);

  /// Saves the teacher's review — `POST /teacher/submissions/{id}/review`
  /// with `{feedback, score}` — and answers the submission as stored. A
  /// second review overwrites the first. Refusals carry the backend's code
  /// (`TeacherFailure.code`): `feedback_required`, `feedback_too_long`,
  /// `invalid_score`, `submission_not_found`.
  Future<TeacherSubmission> reviewSubmission({
    required int submissionId,
    required String feedback,
    num? score,
  });
}

/// A student enrolled in a class — an entry of
/// `GET /teacher/cohorts/{cohort_id}/students`'s `students`. Only `id` and
/// `name` are read; `enrollment_id` and `phone` are not.
class CohortStudent {
  const CohortStudent({required this.id, required this.name});

  final int id;
  final String name;
}
