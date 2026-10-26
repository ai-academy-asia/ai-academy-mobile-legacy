import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../auth/data/authenticated_client.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/schedule_change.dart';
import '../domain/teacher_failure.dart';
import 'teacher_http.dart';

/// The schedule-change request against the AI Academy API — phase 1
/// (Issue #449), sending:
///
///     GET  https://api.ai-academy.asia/teacher/sessions/{session_id}/eligible-teachers
///     POST https://api.ai-academy.asia/teacher/schedule-change-requests
///
/// and phase 2 (Issue #453), answering an incoming request:
///
///     GET  https://api.ai-academy.asia/teacher/schedule-change-requests/{id}
///     POST https://api.ai-academy.asia/teacher/schedule-change-requests/{id}/accept
///     POST https://api.ai-academy.asia/teacher/schedule-change-requests/{id}/reject
///     Authorization: Bearer <access_token>
///
/// From the backend's documented contract (`ai-academy-backend`
/// `docs/schedule_change_api_v1.md`, commit `c6e6ce0`, covered by its
/// `tests/test_schedule_change_*.py`); no live response is captured, and
/// whether the deployed backend serves these routes is `UNKNOWN`.
///
/// The read answers `{session_id, items: [{id, name, photo_url}]}`; the send
/// takes `{session_id, recipient_teacher_id, message}` and answers the
/// request object, `201` when created and `200` for an identical retry.
/// Refusals are `{"error": code}`, kept as `TeacherFailure.code` — both
/// calls go through [teacherSend], which reads it, the read included, since
/// its `404 session_not_found` and `409 session_started` must stay apart
/// from a backend that has no such route at all (no code).
class HttpScheduleChangeRepository implements ScheduleChangeRepository {
  HttpScheduleChangeRepository({
    http.Client? client,
    Uri? baseUrl,
    AuthSessionStore? sessionStore,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? AuthenticatedClient.instance,
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _sessionStore = sessionStore ?? AuthSessionStore.instance;

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;
  final Duration timeout;

  @override
  Future<List<EligibleTeacher>> getEligibleTeachers(int sessionId) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherSend(
      send: (headers) => getRaw(
        client: _client,
        url: _baseUrl.resolve('/teacher/sessions/$sessionId/eligible-teachers'),
        headers: headers,
        timeout: timeout,
      ),
      sessionStore: _sessionStore,
    );
    return eligibleTeachersFromJson(
      teacherJsonObject(response.body),
      sessionId: sessionId,
    );
  }

  @override
  Future<SentScheduleChange> sendRequest({
    required int sessionId,
    required int recipientTeacherId,
  }) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherSend(
      send: (headers) => postJsonRaw(
        client: _client,
        url: _baseUrl.resolve('/teacher/schedule-change-requests'),
        body: {
          'session_id': sessionId,
          'recipient_teacher_id': recipientTeacherId,
          // No message field in this phase; the contract takes `null`.
          'message': null,
        },
        headers: headers,
        timeout: timeout,
      ),
      sessionStore: _sessionStore,
    );
    // Only these two mean the server holds the request (contract §4): any
    // other 2xx is not a confirmed send.
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw TeacherFailure(
        TeacherFailureKind.unexpected,
        detail: 'HTTP ${response.statusCode}',
      );
    }
    return sentScheduleChangeFromJson(
      teacherJsonObject(response.body),
      sessionId: sessionId,
      recipientTeacherId: recipientTeacherId,
    );
  }

  @override
  Future<ScheduleChangeRequest> getRequest(int requestId) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherSend(
      send: (headers) => getRaw(
        client: _client,
        url: _requestUrl(requestId),
        headers: headers,
        timeout: timeout,
      ),
      sessionStore: _sessionStore,
    );
    return scheduleChangeRequestFromJson(
      teacherJsonObject(response.body),
      requestId: requestId,
    );
  }

  @override
  Future<ScheduleChangeRequest> acceptRequest(int requestId) => _decide(
    requestId,
    action: 'accept',
    body: const {},
    expected: ScheduleChangeStatus.accepted,
  );

  @override
  Future<ScheduleChangeRequest> rejectRequest(
    int requestId, {
    String? reason,
  }) => _decide(
    requestId,
    action: 'reject',
    // The contract's optional reason; the sheet has no field, so null.
    body: {'reason': reason},
    expected: ScheduleChangeStatus.rejected,
  );

  Uri _requestUrl(int requestId) =>
      _baseUrl.resolve('/teacher/schedule-change-requests/$requestId');

  /// POSTs [action] for [requestId] and answers the request — only a `200`
  /// whose request object is [requestId] at [expected], the decision just
  /// made (a repeat of the same decision answers it unchanged, contract
  /// §2). Anything else is not a confirmed decision: a failure.
  Future<ScheduleChangeRequest> _decide(
    int requestId, {
    required String action,
    required Map<String, Object?> body,
    required String expected,
  }) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherSend(
      send: (headers) => postJsonRaw(
        client: _client,
        url: _baseUrl.resolve(
          '/teacher/schedule-change-requests/$requestId/$action',
        ),
        body: body,
        headers: headers,
        timeout: timeout,
      ),
      sessionStore: _sessionStore,
    );
    if (response.statusCode != 200) {
      throw TeacherFailure(
        TeacherFailureKind.unexpected,
        detail: 'HTTP ${response.statusCode}',
      );
    }
    final request = scheduleChangeRequestFromJson(
      teacherJsonObject(response.body),
      requestId: requestId,
    );
    if (request.status != expected) {
      throw _shape('status: not "$expected"');
    }
    return request;
  }
}

/// `{session_id, items: [{id, name, photo_url}]}` for [sessionId]. Anything
/// else — another session's list, a missing field, a `photo_url` that is
/// neither `null` nor a string — is the API misbehaving: a `server` failure.
List<EligibleTeacher> eligibleTeachersFromJson(
  Map<String, dynamic> json, {
  required int sessionId,
}) {
  if (json['session_id'] != sessionId) {
    throw _shape('session_id: not $sessionId');
  }
  final items = json['items'];
  if (items is! List) throw _shape('items: expected a list');
  return [
    for (final item in items)
      if (item is! Map<String, dynamic>)
        throw _shape('items[]: expected an object')
      else
        ?_eligibleTeacher(item),
  ];
}

/// One eligible teacher, or null for one whose name is blank: the picker
/// leaves them out rather than offering a nameless row (Issue #537, product
/// decision) — the rest of the list still loads.
EligibleTeacher? _eligibleTeacher(Map<String, dynamic> json) {
  final id = json['id'];
  final name = json['name'];
  final photoUrl = json['photo_url'];
  if (id is! int) throw _shape('items[].id: not an integer');
  if (name is! String) throw _shape('items[].name: not a string');
  if (photoUrl != null && photoUrl is! String) {
    throw _shape('items[].photo_url: neither null nor a string');
  }
  if (name.trim().isEmpty) return null;
  return EligibleTeacher(id: id, name: name);
}

/// The request object a send answers, checked against what was sent: the
/// same session and recipient, and `pending` — what a new request is, and
/// the only open request an identical retry can return (an accepted one
/// answers `409 session_already_covered`). Anything else is not a
/// confirmed send: a `server` failure.
SentScheduleChange sentScheduleChangeFromJson(
  Map<String, dynamic> json, {
  required int sessionId,
  required int recipientTeacherId,
}) {
  final id = json['id'];
  final recipient = json['recipient'];
  final status = json['status'];
  if (id is! int) throw _shape('id: not an integer');
  if (json['session_id'] != sessionId) {
    throw _shape('session_id: not $sessionId');
  }
  if (recipient is! Map<String, dynamic> ||
      recipient['id'] != recipientTeacherId) {
    throw _shape('recipient.id: not $recipientTeacherId');
  }
  if (status != 'pending') throw _shape('status: not "pending"');
  return SentScheduleChange(
    id: id,
    recipientTeacherId: recipientTeacherId,
    status: status as String,
  );
}

/// The request object (contract §3) for [requestId]. Read: `id` (must be
/// [requestId]), `session_id`, `status` (one of [ScheduleChangeStatus.all]),
/// `sender.name`, and the `session` brief — `date` required, `start_time`,
/// `end_time`, `title`, `cohort_name` and `room` each a string or null.
/// Anything else is the API misbehaving: a `server` failure.
ScheduleChangeRequest scheduleChangeRequestFromJson(
  Map<String, dynamic> json, {
  required int requestId,
}) {
  final id = json['id'];
  final sessionId = json['session_id'];
  final status = json['status'];
  final sender = json['sender'];
  final session = json['session'];
  if (id != requestId) throw _shape('id: not $requestId');
  if (sessionId is! int) throw _shape('session_id: not an integer');
  if (status is! String || !ScheduleChangeStatus.all.contains(status)) {
    throw _shape('status: not a documented status');
  }
  if (sender is! Map<String, dynamic>) {
    throw _shape('sender: expected an object');
  }
  final senderName = sender['name'];
  // A blank name is the backend's data (Issue #537): read as `''`, so the
  // sheet still opens and a decision the server made is not reported failed.
  if (senderName is! String) throw _shape('sender.name: not a string');
  if (session is! Map<String, dynamic>) {
    throw _shape('session: expected an object');
  }
  final date = session['date'];
  final day = date is String ? DateTime.tryParse(date) : null;
  if (day == null) throw _shape('session.date: not a date');
  return ScheduleChangeRequest(
    id: requestId,
    sessionId: sessionId,
    status: status,
    senderName: senderName.trim().isEmpty ? '' : senderName,
    sessionDate: DateTime(day.year, day.month, day.day),
    startTime: _optionalText(session, 'start_time'),
    endTime: _optionalText(session, 'end_time'),
    courseTitle: _optionalText(session, 'title'),
    cohortName: _optionalText(session, 'cohort_name'),
    room: _optionalText(session, 'room'),
  );
}

String? _optionalText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw _shape('session.$key: neither null nor a string');
}

TeacherFailure _shape(String detail) =>
    TeacherFailure(TeacherFailureKind.server, detail: detail);
