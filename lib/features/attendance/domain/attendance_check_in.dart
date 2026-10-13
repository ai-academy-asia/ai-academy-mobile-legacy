/// A student's QR check-in, as `POST /me/attendance/check-in` answered it
/// (Issue #382): the record the server holds for that session.
///
/// Every field is kept exactly as returned. [status] in particular is the
/// server's — `present`, or `late` more than 15 minutes after the start, on
/// a first check-in; on a repeat, whatever is already recorded, which can be
/// a teacher's `absent` or `excused`. It is never replaced with a generic
/// success, so a screen can say what actually happened.
class AttendanceCheckIn {
  const AttendanceCheckIn({
    required this.sessionId,
    required this.status,
    required this.method,
    required this.checkedInAt,
    required this.firstCheckIn,
  });

  /// The class session the token belonged to.
  final int sessionId;

  /// The recorded status, as sent — not narrowed to a known set.
  final String status;

  /// How the record was made: `qr`, or `manual` when a teacher had already
  /// marked it. Null if the server sends none.
  final String? method;

  /// When the record was made (UTC, as the server stamps it). Null if the
  /// server sends none.
  final DateTime? checkedInAt;

  /// `201` — this scan made the record. `false` for `200`: the student was
  /// already recorded, and the record above is the earlier one, unchanged.
  final bool firstCheckIn;
}
