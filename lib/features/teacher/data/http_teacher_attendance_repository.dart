import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../auth/data/authenticated_client.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/teacher_attendance.dart';
import '../domain/teacher_failure.dart';
import 'http_teacher_schedule_repository.dart';
import 'teacher_http.dart';

/// Teacher attendance against the AI Academy API (Issue #374):
///
///     POST https://api.ai-academy.asia/teacher/sessions/{session_id}/qr
///     GET  https://api.ai-academy.asia/teacher/sessions/{session_id}/attendance
///     PUT  https://api.ai-academy.asia/teacher/sessions/{session_id}/attendance/{student_id}
///     Authorization: Bearer <access_token>
///
/// Verified from the backend's source (`app/routes/attendance.py`,
/// `app/services/attendance/checkin.py`) and `docs/mobile_api_v1.md` §8;
/// no live response is captured. The QR answers `{token, expires_at}`; the
/// roster `{session, students: [{student_id, name, status, method,
/// checked_in_at}], counts}`; a mark takes `{"status"}` and answers
/// `{student_id, session_id, status, method, checked_in_at}`. Refusals are
/// `{"error": code}`, kept as `TeacherFailure.code`.
class HttpTeacherAttendanceRepository implements TeacherAttendanceRepository {
  HttpTeacherAttendanceRepository({
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
  Future<AttendanceQrToken> issueQr(int sessionId) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherSend(
      send: (headers) => postWithoutBody(
        client: _client,
        url: _baseUrl.resolve('/teacher/sessions/$sessionId/qr'),
        headers: headers,
        timeout: timeout,
      ),
      sessionStore: _sessionStore,
    );
    return qrTokenFromJson(teacherJsonObject(response.body));
  }

  @override
  Future<SessionAttendance> getSessionAttendance(int sessionId) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherGet(
      client: _client,
      url: _baseUrl.resolve('/teacher/sessions/$sessionId/attendance'),
      sessionStore: _sessionStore,
      timeout: timeout,
    );
    return sessionAttendanceFromJson(teacherJsonObject(response.body));
  }

  @override
  Future<AttendanceStatus> markAttendance({
    required int sessionId,
    required int studentId,
    required AttendanceStatus status,
  }) async {
    ensureTeacherSession(_sessionStore);
    final response = await teacherSend(
      send: (headers) => putJsonRaw(
        client: _client,
        url: _baseUrl.resolve(
          '/teacher/sessions/$sessionId/attendance/$studentId',
        ),
        body: {'status': status.wire},
        headers: headers,
        timeout: timeout,
      ),
      sessionStore: _sessionStore,
    );
    return markedStatusFromJson(
      teacherJsonObject(response.body),
      studentId: studentId,
    );
  }
}

/// `{token, expires_at}`.
AttendanceQrToken qrTokenFromJson(Map<String, dynamic> json) {
  final token = json['token'];
  final expiresAt = json['expires_at'];
  if (token is! String || token.isEmpty) throw _shape('token: not a string');
  final expiry = expiresAt is String ? DateTime.tryParse(expiresAt) : null;
  if (expiry == null) throw _shape('expires_at: not a timestamp');
  return AttendanceQrToken(token: token, expiresAt: expiry);
}

/// The roster and counts of an attendance response. A status outside the
/// four is the API misbehaving — never mapped onto one of them.
SessionAttendance sessionAttendanceFromJson(Map<String, dynamic> json) {
  final students = json['students'];
  if (students is! List) throw _shape('students: expected a list');
  return SessionAttendance(
    students: [for (final entry in students) _student(entry)],
    counts: attendanceCountsFromJson(json),
  );
}

StudentAttendance _student(Object? entry) {
  if (entry is! Map<String, dynamic>) throw _shape('student: not an object');
  final id = entry['student_id'];
  final name = entry['name'];
  final status = AttendanceStatus.fromWire(entry['status']);
  final method = entry['method'];
  if (id is! int) throw _shape('student: student_id');
  if (name is! String) throw _shape('student $id: name');
  if (status == null) throw _shape('student $id: status ${entry['status']}');
  if (method != null && method is! String) throw _shape('student $id: method');
  return StudentAttendance(
    studentId: id,
    name: name,
    status: status,
    method: method as String?,
  );
}

/// The stored status of a mark's answer — for the student asked about.
AttendanceStatus markedStatusFromJson(
  Map<String, dynamic> json, {
  required int studentId,
}) {
  if (json['student_id'] != studentId) throw _shape('mark: student_id');
  final status = AttendanceStatus.fromWire(json['status']);
  if (status == null) throw _shape('mark: status ${json['status']}');
  return status;
}

TeacherFailure _shape(String detail) =>
    TeacherFailure(TeacherFailureKind.server, detail: detail);
