import 'course_attendance.dart';

abstract interface class AttendanceRepository {
  /// The signed-in student's attendance in the course [courseSlug] names —
  /// `Course.slug`, the same key the learning path uses.
  ///
  /// Throws `AttendanceFailure` when there is no usable session, the API
  /// refuses or cannot be reached, or the response does not match the
  /// verified shape.
  Future<CourseAttendance> getCourseAttendance(String courseSlug);
}
