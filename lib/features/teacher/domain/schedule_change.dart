/// The teacher schedule-change (class handover) request: who a session can
/// be handed to and sending the request (phase 1, Issue #449), and reading
/// and answering an incoming one (phase 2, Issue #453).
///
/// From the backend's documented contract — `ai-academy-backend`
/// `docs/schedule_change_api_v1.md`, commit `c6e6ce0` — not from an observed
/// response: whether the deployed backend serves it is `UNKNOWN`. A
/// received-requests list, cancel and covering sessions are later phases.
library;

/// A teacher a session can be handed to — one `items` entry of
/// `GET /teacher/sessions/{id}/eligible-teachers`: `{id, name, photo_url}`.
///
/// `photo_url` is always `null` in the contract (teachers have no photo
/// yet), so it is not modelled; the row keeps its placeholder avatar.
class EligibleTeacher {
  const EligibleTeacher({required this.id, required this.name});

  final int id;
  final String name;
}

/// What the server confirmed for a sent request — the parts of
/// `POST /teacher/schedule-change-requests`'s request object the screen
/// uses. Built only from a `201 Created` or a `200 OK` (an identical
/// retry), never assumed.
class SentScheduleChange {
  const SentScheduleChange({
    required this.id,
    required this.recipientTeacherId,
    required this.status,
  });

  /// The request's own id.
  final int id;

  /// `recipient.id` — the teacher the session would go to.
  final int recipientTeacherId;

  /// The request's status as sent: `pending`, `accepted`, `rejected`,
  /// `cancelled` or `expired` (contract §2). A new request is `pending`;
  /// an identical retry answers whatever the existing one now is.
  final String status;
}

/// A request's status, as the contract spells it (§2): `pending`, then one
/// of the four terminal ones.
abstract final class ScheduleChangeStatus {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
  static const expired = 'expired';

  static const all = {pending, accepted, rejected, cancelled, expired};
}

/// One request as `GET /teacher/schedule-change-requests/{id}` and its
/// accept / reject answer it (contract §3) — the parts the incoming-request
/// sheet draws (Issue #453). Teachers appear by name only; the session is
/// the request's own brief, so there is no student count or track to draw.
class ScheduleChangeRequest {
  const ScheduleChangeRequest({
    required this.id,
    required this.sessionId,
    required this.status,
    required this.senderName,
    required this.sessionDate,
    this.startTime,
    this.endTime,
    this.courseTitle,
    this.cohortName,
    this.room,
  });

  final int id;
  final int sessionId;

  /// One of [ScheduleChangeStatus.all] — the server's current answer.
  final String status;

  /// `sender.name` — the teacher asking to hand the session over.
  final String senderName;

  /// `session.date`, a calendar day (`YYYY-MM-DD`, Ulaanbaatar).
  final DateTime sessionDate;

  /// `session.start_time` / `end_time`, "HH:MM" as sent; either may be null.
  final String? startTime;
  final String? endTime;

  /// `session.title` (the course, Mongolian), `session.cohort_name` and
  /// `session.room`; each may be null.
  final String? courseTitle;
  final String? cohortName;
  final String? room;

  bool get isPending => status == ScheduleChangeStatus.pending;
}

/// Reads who a session can be handed to and sends the request (phase 1);
/// reads and answers an incoming request (phase 2). Failures are
/// `TeacherFailure`s carrying the backend's `{"error": code}` as `code`.
abstract interface class ScheduleChangeRepository {
  /// `GET /teacher/sessions/{sessionId}/eligible-teachers`, in the server's
  /// order.
  Future<List<EligibleTeacher>> getEligibleTeachers(int sessionId);

  /// `POST /teacher/schedule-change-requests` with
  /// `{session_id, recipient_teacher_id, message: null}` — the screen has no
  /// message field in this phase.
  Future<SentScheduleChange> sendRequest({
    required int sessionId,
    required int recipientTeacherId,
  });

  /// `GET /teacher/schedule-change-requests/{requestId}` — the request's
  /// current state (Issue #453). The server settles expiry first.
  Future<ScheduleChangeRequest> getRequest(int requestId);

  /// `POST /teacher/schedule-change-requests/{requestId}/accept`. Answers
  /// the request once the server reports it `accepted`.
  Future<ScheduleChangeRequest> acceptRequest(int requestId);

  /// `POST /teacher/schedule-change-requests/{requestId}/reject` with
  /// `{"reason": reason}` — null, as the sheet has no reason field. Answers
  /// the request once the server reports it `rejected`.
  Future<ScheduleChangeRequest> rejectRequest(int requestId, {String? reason});
}
