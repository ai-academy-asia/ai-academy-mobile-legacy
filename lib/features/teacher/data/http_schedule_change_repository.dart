import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../auth/data/authenticated_client.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/schedule_change.dart';
import '../domain/teacher_failure.dart';
import 'teacher_http.dart';

/// The schedule-change request, phase 1 (Issue #449), against the AI Academy
/// API:
///
///     GET  https://api.ai-academy.asia/teacher/sessions/{session_id}/eligible-teachers
///     POST https://api.ai-academy.asia/teacher/schedule-change-requests
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
        _eligibleTeacher(item),
  ];
}

EligibleTeacher _eligibleTeacher(Map<String, dynamic> json) {
  final id = json['id'];
  final name = json['name'];
  final photoUrl = json['photo_url'];
  if (id is! int) throw _shape('items[].id: not an integer');
  if (name is! String || name.trim().isEmpty) {
    throw _shape('items[].name: not a non-empty string');
  }
  if (photoUrl != null && photoUrl is! String) {
    throw _shape('items[].photo_url: neither null nor a string');
  }
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

TeacherFailure _shape(String detail) =>
    TeacherFailure(TeacherFailureKind.server, detail: detail);
