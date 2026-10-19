/// The teacher schedule-change (class handover) request, phase 1 (Issue
/// #449): who a session can be handed to, and sending the request.
///
/// From the backend's documented contract — `ai-academy-backend`
/// `docs/schedule_change_api_v1.md`, commit `c6e6ce0` — not from an observed
/// response: whether the deployed backend serves it is `UNKNOWN`. Incoming
/// requests, accept / reject and covering sessions are later phases.
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

/// Reads who a session can be handed to and sends the request. Failures are
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
}
