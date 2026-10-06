/// The backend's answer to marking one lesson complete —
/// `course_learning_api_contract_v1.md` §2.3 "Mark complete (Q7)":
/// `POST /me/lessons/{lesson_id}/complete` →
/// `{"completed": true, "progress": {…§2.1 progress…}}`.
///
/// Its own type rather than a reuse of `CourseLearningPath`: the answer
/// carries the course's progress only, not its modules or continue target.
///
/// Read: `completed` and `progress.percent` — the same progress field the
/// learning path reads. Not read: `progress.completed_lessons`/
/// `total_lessons`, for the reason `HttpCourseLearningRepository` gives on
/// §2.1: no screen draws them.
class LessonCompletion {
  const LessonCompletion({
    required this.completed,
    required this.percentComplete,
  });

  /// Whether the server now holds the lesson completed. The contract
  /// documents only `true`; the field is read rather than assumed, so the
  /// app never shows a completion the server did not report.
  final bool completed;

  /// The course's progress after this call — `progress.percent`,
  /// server-computed (§2.1 Q5), 0–100. Never derived on the client.
  final int percentComplete;
}
