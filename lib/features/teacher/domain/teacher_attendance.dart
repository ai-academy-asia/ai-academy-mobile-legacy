import 'teacher_session.dart';

/// Teacher attendance registration (Issue #374): the QR a teacher shows for
/// students to scan, the session's roster with each student's status, and
/// marking a student by hand. The contract is the backend's own
/// (`app/routes/attendance.py`, `docs/mobile_api_v1.md` §8); see
/// `DATA_AND_API.md` §1.

/// A student's attendance at one session — exactly the backend's four
/// values (`ATTENDANCE_STATUSES`), each kept as itself: a `late` is never
/// shown or sent as `present`, an `excused` never as `absent`.
enum AttendanceStatus {
  present('present'),
  late('late'),
  absent('absent'),
  excused('excused');

  const AttendanceStatus(this.wire);

  /// The value the API sends and accepts.
  final String wire;

  /// The status [wire] names, or null for a value outside the four.
  static AttendanceStatus? fromWire(Object? wire) {
    for (final status in values) {
      if (status.wire == wire) return status;
    }
    return null;
  }
}

/// One roster row of `GET /teacher/sessions/{id}/attendance`'s `students`.
///
/// A student with no record comes back `absent` with a null [method] — the
/// backend has no "not marked" status.
class StudentAttendance {
  const StudentAttendance({
    required this.studentId,
    required this.name,
    required this.status,
    this.method,
  });

  final int studentId;

  /// As the backend joins it: first name, then last name.
  final String name;

  final AttendanceStatus status;

  /// `qr` or `manual`, null when unmarked. Shown nowhere; kept so a QR
  /// check-in is told apart from a teacher's mark.
  final String? method;
}

/// `GET /teacher/sessions/{id}/attendance`: the roster — active enrolments
/// only, ordered by name — and its four counts.
class SessionAttendance {
  const SessionAttendance({required this.students, required this.counts});

  final List<StudentAttendance> students;
  final AttendanceCounts counts;
}

/// `POST /teacher/sessions/{id}/qr`: a fresh check-in token. Each issue
/// voids the one before it.
class AttendanceQrToken {
  const AttendanceQrToken({required this.token, required this.expiresAt});

  final String token;

  /// As the server stamps it. The screen times the token from when it
  /// arrived instead ([AttendanceQrToken.lifetime]), so a phone whose clock
  /// is off cannot show a dead code as live.
  final DateTime expiresAt;

  /// The backend's `QR_TTL_MINUTES`.
  static const Duration lifetime = Duration(minutes: 5);
}

/// Today's date in Ulaanbaatar — the backend's own "today" for a session
/// (`clock.local_today()`, `Asia/Ulaanbaatar`), which allows a QR only on
/// the session's date. Ulaanbaatar is UTC+8 all year (no daylight saving
/// since 2017), so this needs no time-zone database, and holds whatever
/// zone the phone is set to.
DateTime ulaanbaatarToday(DateTime now) {
  final local = now.toUtc().add(const Duration(hours: 8));
  return DateTime(local.year, local.month, local.day);
}

/// Whether attendance can be registered for [session] at [now]: on its
/// date, in Ulaanbaatar.
bool attendanceOpenOn(TeacherSession session, DateTime now) =>
    isSameDay(session.date, ulaanbaatarToday(now));

/// What the attendance screens read and write.
///
/// Every method throws `TeacherFailure` when there is no usable session,
/// the API refuses or cannot be reached, or the response does not match the
/// verified shape; a refusal carries the backend's code
/// (`TeacherFailure.code`).
abstract interface class TeacherAttendanceRepository {
  /// `POST /teacher/sessions/{session_id}/qr` — a fresh token, voiding the
  /// last. Refused with `409 session_not_today` off the session's date.
  Future<AttendanceQrToken> issueQr(int sessionId);

  /// `GET /teacher/sessions/{session_id}/attendance` — the whole roster.
  Future<SessionAttendance> getSessionAttendance(int sessionId);

  /// `PUT /teacher/sessions/{session_id}/attendance/{student_id}` with
  /// `{"status"}` — creates or overwrites the record (its method becomes
  /// `manual`) and returns the status as stored.
  Future<AttendanceStatus> markAttendance({
    required int sessionId,
    required int studentId,
    required AttendanceStatus status,
  });
}

/// What the attendance QR encodes, given the issued token — **UNCONFIRMED**
/// (Issue #374, open question 1). The backend documents only that a
/// student's check-in sends "`{token}` from the teacher's QR"; whether the
/// QR holds the raw token or a URL/JSON around it is for the backend owner
/// to say. Until they do this stays null, and the QR screen asks for no
/// token and draws no code — manual registration works meanwhile.
///
/// **Required before setting this** (PR #375 review): the manual screen
/// compares each row against the roster it loaded, so a QR check-in that
/// lands after it loaded can be overwritten by a teacher's change to that
/// row (a `late` scan replaced by `present`, its method by `manual`).
/// Re-read the roster before confirming and flag rows the server moved.
const String Function(String token)? attendanceQrPayload = null;
