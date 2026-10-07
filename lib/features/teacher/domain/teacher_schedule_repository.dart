import 'teacher_class.dart';
import 'teacher_session.dart';

/// What Teacher Schedule reads (Issue #231). Read-only: nothing here writes.
///
/// Every method throws `TeacherFailure` when there is no usable session, the
/// API refuses or cannot be reached, or the response does not match the
/// verified shape.
abstract interface class TeacherScheduleRepository {
  /// Every class the signed-in teacher teaches —
  /// `GET /teachers/{actor_id}/schedule`, as Teacher Home reads it.
  Future<List<TeacherClass>> getClasses();

  /// The cohort's dated sessions between [from] and [to] —
  /// `GET /teacher/cohorts/{cohort_id}/sessions?from=&to=`.
  Future<List<TeacherSession>> getSessions({
    required int cohortId,
    required DateTime from,
    required DateTime to,
  });

  /// The session's attendance tally —
  /// `GET /teacher/sessions/{session_id}/attendance`.
  Future<AttendanceCounts> getAttendance(int sessionId);
}
