import 'course_attendance.dart';
import '../../teacher/domain/teacher_attendance.dart';

/// Whether [attendance] confirms Junior's lesson to continue with (Issue
/// #443) — the one rule Junior Home and the attendance-gated Junior Course
/// Detail both ask.
///
/// **The most recent session dated today or earlier**, in Ulaanbaatar
/// ([ulaanbaatarToday], the backend's own `local_today()`), counts as
/// attended — `present` or `late` ([AttendanceSession.countsAsAttended]).
/// "Most recent" is the backend's own order: by date, then `start_time`
/// (the two make a session unique within a cohort); a session without a
/// start time sorts first on its day, and sessions that still tie keep the
/// order they arrived in.
///
/// So access lasts after the class has ended, until the next class day: on
/// that day the backend reports the new session `absent` from midnight
/// until a record exists, which locks the lesson again until the student
/// checks in. `absent`, `excused`, no session yet, and [attendance] unknown
/// (null — not read, or unreadable) all answer false: it fails closed.
///
/// An approximation (Issue #414, `BACKEND GAP`): a session names a module
/// (`topic_id`), not a lesson, so this cannot tell *which* lesson a class
/// was for — the most recent class stands for the lesson to continue with.
bool continueAttendanceConfirmedBy(
  CourseAttendance? attendance, {
  required DateTime now,
}) {
  if (attendance == null) return false;
  final today = ulaanbaatarToday(now);
  final held = [
    for (final (i, session) in attendance.sessions.indexed)
      if (!_day(session.date).isAfter(today)) (i, session),
  ];
  if (held.isEmpty) return false;
  held.sort((a, b) {
    final byDay = _day(a.$2.date).compareTo(_day(b.$2.date));
    if (byDay != 0) return byDay;
    final byStart = (a.$2.startTime ?? '').compareTo(b.$2.startTime ?? '');
    if (byStart != 0) return byStart;
    return a.$1.compareTo(b.$1);
  });
  return held.last.$2.countsAsAttended;
}

/// [date]'s calendar day.
DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
