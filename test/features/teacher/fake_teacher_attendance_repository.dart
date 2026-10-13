import 'dart:async';

import 'package:aia_mobile/features/teacher/domain/teacher_attendance.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';

/// A roster row, in the verified `students[]` shape's fields.
StudentAttendance student(
  int id,
  String name,
  AttendanceStatus status, {
  String? method,
}) => StudentAttendance(
  studentId: id,
  name: name,
  status: status,
  method: method,
);

/// Records every call, answers from what the test set. Never touches a
/// network.
class FakeTeacherAttendanceRepository implements TeacherAttendanceRepository {
  FakeTeacherAttendanceRepository({
    List<StudentAttendance>? students,
    this.counts = const AttendanceCounts(
      present: 14,
      late: 0,
      absent: 10,
      excused: 0,
    ),
  }) : students = students ?? const [];

  List<StudentAttendance> students;
  AttendanceCounts counts;

  /// Thrown by [issueQr] when set.
  TeacherFailure? qrFailure;

  /// Thrown by [getSessionAttendance] when set.
  TeacherFailure? readFailure;

  /// Student ids whose [markAttendance] fails.
  final Set<int> failingStudents = {};

  /// When set, [markAttendance] waits on it — to hold writes in flight.
  Completer<void>? markGate;

  final List<int> qrCalls = [];
  final List<int> readCalls = [];
  final List<(int sessionId, int studentId, AttendanceStatus status)>
  markCalls = [];
  var _tokens = 0;

  @override
  Future<AttendanceQrToken> issueQr(int sessionId) async {
    qrCalls.add(sessionId);
    final failure = qrFailure;
    if (failure != null) throw failure;
    _tokens++;
    return AttendanceQrToken(
      token: 'token-$_tokens',
      expiresAt: DateTime.utc(2026, 10, 13, 6, 5),
    );
  }

  @override
  Future<SessionAttendance> getSessionAttendance(int sessionId) async {
    readCalls.add(sessionId);
    final failure = readFailure;
    if (failure != null) throw failure;
    return SessionAttendance(students: students, counts: counts);
  }

  @override
  Future<AttendanceStatus> markAttendance({
    required int sessionId,
    required int studentId,
    required AttendanceStatus status,
  }) async {
    markCalls.add((sessionId, studentId, status));
    await markGate?.future;
    if (failingStudents.contains(studentId)) {
      throw const TeacherFailure(TeacherFailureKind.network);
    }
    return status;
  }
}
