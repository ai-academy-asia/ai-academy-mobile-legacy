import 'attendance_check_in.dart';
import 'course_attendance.dart';

abstract interface class AttendanceRepository {
  /// The signed-in student's attendance in the course [courseSlug] names —
  /// `Course.slug`, the same key the learning path uses.
  ///
  /// Throws `AttendanceFailure` when there is no usable session, the API
  /// refuses or cannot be reached, or the response does not match the
  /// verified shape.
  Future<CourseAttendance> getCourseAttendance(String courseSlug);

  /// Checks the signed-in student in with [token] — the raw string the
  /// teacher's QR encodes — via `POST /me/attendance/check-in`.
  ///
  /// Answers the record the server holds: a first check-in (`201`) or the
  /// existing one (`200`). Throws `AttendanceFailure` — with the backend's
  /// `AttendanceFailure.code` when it gives one — when there is no usable
  /// session, the token is refused (`token_required`, `invalid_token`),
  /// the student is not enrolled (`not_enrolled`), the API cannot be
  /// reached, or the response does not match the verified shape. The
  /// token is never part of a failure.
  Future<AttendanceCheckIn> checkIn(String token);
}
