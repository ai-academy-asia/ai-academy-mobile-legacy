import 'package:aia_mobile/features/attendance/domain/attendance_failure.dart';
import 'package:aia_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';

/// A repository the tests drive by hand: returns [attendance], or throws a
/// chosen [AttendanceFailure].
class FakeAttendanceRepository implements AttendanceRepository {
  FakeAttendanceRepository({
    this.attendance = const CourseAttendance(
      attended: 0,
      totalPast: 0,
      percent: 0,
    ),
    this.failure,
  });

  /// Returned on success. Defaults to the verified adult test account's
  /// all-zero summary.
  CourseAttendance attendance;

  /// Thrown instead of returning, when set.
  AttendanceFailure? failure;

  /// Every slug [getCourseAttendance] was called with, in order.
  final List<String> calls = [];

  @override
  Future<CourseAttendance> getCourseAttendance(String courseSlug) async {
    calls.add(courseSlug);
    if (failure case final failure?) throw failure;
    return attendance;
  }
}
