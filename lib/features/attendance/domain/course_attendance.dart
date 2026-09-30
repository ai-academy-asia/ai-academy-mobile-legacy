/// The student's attendance in one course, as
/// `GET /me/attendance?course={slug}` reports it.
///
/// `mobile_api_v1_1.md` §8 documents the endpoint as "sessions + attended %".
/// The field names are the ones a verified production response for the adult
/// test account showed:
///
///     {
///       "cohort_id": 1, "course_id": 6, "sessions": [],
///       "summary": {"attended": 0, "percent": 0, "total_past": 0}
///     }
///
/// Only `summary` is modelled — it is everything the Home attendance card
/// draws. `sessions` is not: the verified response showed an empty list, so
/// no session field has been confirmed.
class CourseAttendance {
  const CourseAttendance({
    required this.attended,
    required this.totalPast,
    required this.percent,
  });

  /// Sessions the student attended.
  final int attended;

  /// Sessions held so far — `summary.total_past`.
  final int totalPast;

  /// The server's attended percentage, 0–100. Displayed, never re-derived.
  final int percent;
}
