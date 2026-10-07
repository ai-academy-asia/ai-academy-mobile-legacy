import 'teacher_class.dart';

/// One dated session of a teacher's cohort, from
/// `GET /teacher/cohorts/{cohort_id}/sessions` (Issue #231).
///
/// Only the fields the calendar reads are modelled: `id`, `cohort_id`,
/// `session_date`, `start_time`, `end_time`. `topic_id` and `created_at`
/// are verified but unread. Dates and times are wall-clock values, read as
/// local time — the convention `LessonSchedule` already applies to a
/// cohort's `start_time`/`end_time`.
class TeacherSession {
  const TeacherSession({
    required this.id,
    required this.cohortId,
    required this.date,
    required this.start,
    required this.end,
  });

  final int id;
  final int cohortId;

  /// `session_date`, as that local midnight.
  final DateTime date;

  /// Hour and minute the session starts and ends.
  final (int, int) start;
  final (int, int) end;

  DateTime get startsAt =>
      DateTime(date.year, date.month, date.day, start.$1, start.$2);

  DateTime get endsAt =>
      DateTime(date.year, date.month, date.day, end.$1, end.$2);

  /// True once the session's end time has passed — the calendar's "already
  /// held" state. This is the clock, not attendance: no endpoint reports
  /// whether a session was "entered", and reading every past session's
  /// attendance to find out would be one request per block.
  bool isOverAt(DateTime now) => !now.isBefore(endsAt);

  /// `HH:mm`.
  String get startLabel => _clock(start);
  String get endLabel => _clock(end);
}

String _clock((int, int) time) =>
    '${time.$1.toString().padLeft(2, '0')}:${time.$2.toString().padLeft(2, '0')}';

/// A session placed on the calendar with the class it belongs to — the
/// class supplies the title, room, track and student count.
class ScheduledSession {
  const ScheduledSession({required this.session, required this.teacherClass});

  final TeacherSession session;
  final TeacherClass teacherClass;
}

/// A session's attendance tally, the `counts` of
/// `GET /teacher/sessions/{session_id}/attendance` (Issue #231).
///
/// Unmarked students come back as `absent` (with `method: null`), so the
/// four counts together are the session's whole roster.
class AttendanceCounts {
  const AttendanceCounts({
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
  });

  final int present;
  final int late;
  final int absent;
  final int excused;

  /// Students recorded as attending: `present` and `late`, the rule
  /// `/me/attendance` already confirms (`late` counts as attended). `absent`
  /// and `excused` do not.
  int get attended => present + late;

  /// Every student the session lists.
  int get total => present + late + absent + excused;

  /// [attended] of [total], 0 for an empty roster.
  double get fraction => total == 0 ? 0 : attended / total;
}

/// The Sunday that starts [day]'s week, as a local midnight. The calendar's
/// week runs Sunday → Saturday, as the Junior calendar's does.
DateTime weekStartOf(DateTime day) {
  final midnight = DateTime(day.year, day.month, day.day);
  return DateTime(
    midnight.year,
    midnight.month,
    midnight.day - midnight.weekday % DateTime.daysPerWeek,
  );
}

/// [day] with its time dropped.
DateTime dateOnly(DateTime day) => DateTime(day.year, day.month, day.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
