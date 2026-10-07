import 'dart:async';

import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_schedule_repository.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';

/// A repository the tests drive by hand: [classes], the [sessions] of each
/// cohort (filtered to the asked range, as a server would), and the
/// [attendance] of each session. [failure] / [attendanceFailure] throw;
/// [hold] parks the next class read until [release].
class FakeTeacherScheduleRepository implements TeacherScheduleRepository {
  FakeTeacherScheduleRepository({
    this.classes = const [],
    this.sessions = const {},
    this.attendance = const {},
    this.failure,
    this.attendanceFailure,
    this.hold = false,
  });

  List<TeacherClass> classes;
  Map<int, List<TeacherSession>> sessions;
  Map<int, AttendanceCounts> attendance;
  TeacherFailure? failure;
  TeacherFailure? attendanceFailure;
  bool hold;

  int classCalls = 0;
  final List<(int, DateTime, DateTime)> sessionCalls = [];
  final List<int> attendanceCalls = [];

  Completer<void>? _gate;

  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<List<TeacherClass>> getClasses() async {
    classCalls++;
    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }
    final failure = this.failure;
    if (failure != null) throw failure;
    return classes;
  }

  @override
  Future<List<TeacherSession>> getSessions({
    required int cohortId,
    required DateTime from,
    required DateTime to,
  }) async {
    sessionCalls.add((cohortId, from, to));
    final failure = this.failure;
    if (failure != null) throw failure;
    return [
      for (final session in sessions[cohortId] ?? const <TeacherSession>[])
        if (!session.date.isBefore(from) && !session.date.isAfter(to)) session,
    ];
  }

  @override
  Future<AttendanceCounts> getAttendance(int sessionId) async {
    attendanceCalls.add(sessionId);
    final failure = attendanceFailure;
    if (failure != null) throw failure;
    final counts = attendance[sessionId];
    if (counts == null) {
      throw const TeacherFailure(TeacherFailureKind.rejected);
    }
    return counts;
  }
}

/// A session of [cohortId] on [date] (`YYYY-MM-DD`) from [start] to [end].
TeacherSession sampleSession({
  int id = 100,
  int cohortId = 2,
  String date = '2026-10-06',
  (int, int) start = (14, 0),
  (int, int) end = (17, 0),
}) {
  final day = DateTime.parse(date);
  return TeacherSession(
    id: id,
    cohortId: cohortId,
    date: DateTime(day.year, day.month, day.day),
    start: start,
    end: end,
  );
}
