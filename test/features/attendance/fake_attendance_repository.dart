import 'package:aia_mobile/features/attendance/domain/attendance_check_in.dart';
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

  /// Returned by [checkIn] when set; with neither it nor [checkInFailure]
  /// set, a check-in is an unexpected call.
  AttendanceCheckIn? checkInResult;

  /// Thrown by [checkIn] when set.
  AttendanceFailure? checkInFailure;

  /// How many check-ins were asked for — never the tokens themselves.
  int checkInCalls = 0;

  @override
  Future<AttendanceCheckIn> checkIn(String token) async {
    checkInCalls++;
    if (checkInFailure case final failure?) throw failure;
    if (checkInResult case final result?) return result;
    throw StateError('FakeAttendanceRepository.checkIn: no result set');
  }
}
