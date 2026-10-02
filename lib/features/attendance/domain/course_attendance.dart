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
/// `summary` is everything the Home attendance card draws. `sessions` was
/// first seen populated for the junior test student (cohort 7,
/// `junior-ai-summer-10-14`), one entry per held session:
///
///     {"date": "2026-06-16", "end_time": "12:00", "session_id": 148,
///      "start_time": "09:00", "status": "present", "topic_id": 24}
///
/// Only what the Junior calendar needs is modelled — see [AttendanceSession].
class CourseAttendance {
  const CourseAttendance({
    required this.attended,
    required this.totalPast,
    required this.percent,
    this.sessions = const [],
  });

  /// Sessions the student attended.
  final int attended;

  /// Sessions held so far — `summary.total_past`.
  final int totalPast;

  /// The server's attended percentage, 0–100. Displayed, never re-derived.
  final int percent;

  /// The held sessions, in the order the server listed them.
  final List<AttendanceSession> sessions;
}

/// One session from `GET /me/attendance` `sessions` — held, or still to come.
///
/// Modelled: [date] and [status] — what the Junior calendar marks. The entry
/// also carries `session_id`, `start_time`, `end_time` and `topic_id`
/// (confirmed in the same response); nothing reads them yet, so they are not
/// modelled, and a later change to them cannot fail this parse.
class AttendanceSession {
  const AttendanceSession({required this.date, required this.status});

  /// The session's calendar day, as a local date.
  final DateTime date;

  /// The raw wire value. Seen: `"present"`, `"late"`, `"absent"`, and `null`
  /// for a session not held yet (Issue #170). That is not enough to call the
  /// set closed, so it stays a `String` — the same policy `Cohort.status`
  /// follows.
  final String? status;

  /// Whether the server counts this session as attended.
  ///
  /// `present` and `late` only. The evidence is the server's own arithmetic:
  /// the confirmed response lists 10 `present` sessions and 1 `late`, and its
  /// `summary.attended` is 11 of `total_past` 11 — `late` is counted as
  /// attended (and the adult `corp.s01` response agrees: 7 `present` + 1
  /// `late` = `attended` 8). `absent`, a `null` status (a session not held
  /// yet) and any unknown value answer false: no attended mark. Nothing here
  /// draws a "missed" mark either — that is a design decision no frame has
  /// made.
  bool get countsAsAttended => status == 'present' || status == 'late';
}
