import '../../../core/locale/app_format.dart';
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

  /// Hour and minute the session starts and ends. [end] is null when the
  /// session has no end time — the backend allows it (`end_time` is
  /// optional when a session is created, and generated sessions copy the
  /// cohort's, which may be unset), and sends `end_time: null`
  /// (Issue #479). No end is ever made up for it.
  final (int, int) start;
  final (int, int)? end;

  DateTime get startsAt =>
      DateTime(date.year, date.month, date.day, start.$1, start.$2);

  /// Null when [end] is.
  DateTime? get endsAt => switch (end) {
    final end? => DateTime(date.year, date.month, date.day, end.$1, end.$2),
    null => null,
  };

  /// True once the session is over — the calendar's "already held" state:
  /// once its end time has passed, or, with no end time, only once its day
  /// is over (Issue #479), never before. This is the clock, not attendance:
  /// no endpoint reports whether a session was "entered", and reading every
  /// past session's attendance to find out would be one request per block.
  bool isOverAt(DateTime now) =>
      !now.isBefore(endsAt ?? DateTime(date.year, date.month, date.day + 1));

  /// `HH:mm`.
  String get startLabel => _clock(start);

  /// `HH:mm`, or null with no end time.
  String? get endLabel => switch (end) {
    final end? => _clock(end),
    null => null,
  };

  /// `09:00-12:00`, or the start alone — `09:00` — with no end time.
  String get timeLabel => switch (endLabel) {
    final end? => '$startLabel-$end',
    null => startLabel,
  };
}

/// `09:00` — 24-hour in either language ([AppFormat], Issue #505).
String _clock((int, int) time) => AppFormat.clock(time.$1, time.$2);

/// A session placed on the calendar (Issue #231).
///
/// Either one of the teacher's own sessions, with the class it belongs to —
/// the class supplies the title, room, track and student count — and, once
/// another teacher has accepted to cover it, [coveredBy] (Issue #455); or a
/// session the teacher covers for someone else ([ScheduledSession.covering]),
/// known only by its brief: there is no [TeacherClass] for a cohort the
/// teacher does not teach, and none is invented.
class ScheduledSession {
  const ScheduledSession({
    required this.session,
    required TeacherClass this.teacherClass,
    this.coveredBy,
  }) : covering = null;

  /// A session the signed-in teacher covers (Issue #455).
  const ScheduledSession.covering({
    required this.session,
    required CoveringSession this.covering,
  }) : teacherClass = null,
       coveredBy = null;

  final TeacherSession session;

  /// The teacher's own class. Null for a covering session.
  final TeacherClass? teacherClass;

  /// The teacher covering this own session — `covered_by.name` — or null
  /// while nobody does.
  final String? coveredBy;

  /// What is known of a session the teacher covers. Null for an own one.
  final CoveringSession? covering;

  bool get isCovering => covering != null;

  /// The block's and card's title: the class's course (Mongolian first), or
  /// a covering session's own `title`, else its `cohort_name`; null when a
  /// covering session names neither.
  String? get title {
    final teacherClass = this.teacherClass;
    if (teacherClass != null) {
      final course = teacherClass.cohort.course;
      return course.title.preferred ?? course.slug;
    }
    return covering?.courseTitle ?? covering?.cohortName;
  }
}

/// A session the teacher covers — an item of `GET /teacher/sessions` with
/// `assignment_type: covering` (Issue #455): the session brief and whose
/// session it is. No student count or track: the brief carries neither.
class CoveringSession {
  const CoveringSession({
    required this.requestId,
    this.courseTitle,
    this.cohortName,
    this.room,
    this.originalTeacher,
  });

  /// The accepted request — `request_id`.
  final int requestId;

  /// `title` (the course, Mongolian), `cohort_name` and `room`; each may be
  /// null.
  final String? courseTitle;
  final String? cohortName;
  final String? room;

  /// `original_teacher.name` — the cohort's own teacher; null when the
  /// cohort has none.
  final String? originalTeacher;
}

/// One item of `GET /teacher/sessions?from=&to=` (Issue #455): a session of
/// the teacher's — their own (`regular`), matched by [sessionId] onto the
/// cohort read's session, with [coveredBy] once someone covers it; or one
/// they cover ([AssignedSession.covering]), placed from its own [session].
class AssignedSession {
  const AssignedSession.regular({required this.sessionId, this.coveredBy})
    : session = null,
      covering = null;

  const AssignedSession.covering({
    required this.sessionId,
    required TeacherSession this.session,
    required CoveringSession this.covering,
  }) : coveredBy = null;

  /// The session's `id`.
  final int sessionId;

  /// For an own session: the covering teacher's name, or null.
  final String? coveredBy;

  /// For a covering session: its date and times, and its brief. Null for
  /// an own session, which the cohort read already places.
  final TeacherSession? session;
  final CoveringSession? covering;

  bool get isCovering => covering != null;
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
