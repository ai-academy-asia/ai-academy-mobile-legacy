import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/attendance_check_in.dart';
import '../domain/attendance_failure.dart';
import '../domain/attendance_repository.dart';
import '../domain/course_attendance.dart';
import '../../auth/data/authenticated_client.dart';

/// Reads the signed-in student's attendance in one course, and checks the
/// student in from a teacher's QR, against the AI Academy API.
///
///     GET  https://api.ai-academy.asia/me/attendance?course={course_slug}
///     POST https://api.ai-academy.asia/me/attendance/check-in  {"token"}
///     Authorization: Bearer <access_token>
///
/// Field names are the verified production responses' — see
/// [CourseAttendance]. `summary` is read whole; from `sessions`, only each
/// entry's `date` and `status` — the rest of an entry is left alone.
///
/// The token is the one `LoginScreen` saved into [AuthSessionStore]. With no
/// usable session the request is not sent at all — the guard every other
/// authenticated repository applies.
class HttpAttendanceRepository implements AttendanceRepository {
  HttpAttendanceRepository({
    http.Client? client,
    Uri? baseUrl,
    AuthSessionStore? sessionStore,
    this.timeout = const Duration(seconds: 15),
  }) : // The shared client that renews an expired session and retries
       // once (Issue #176). Injected in tests.
       _client = client ?? AuthenticatedClient.instance,
       _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _sessionStore = sessionStore ?? AuthSessionStore.instance;

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;
  final Duration timeout;

  @override
  Future<CourseAttendance> getCourseAttendance(String courseSlug) async {
    if (!_sessionStore.isSignedIn) {
      throw const AttendanceFailure(
        AttendanceFailureKind.sessionExpired,
        detail: 'no session held',
      );
    }
    if (_sessionStore.isExpired()) {
      throw const AttendanceFailure(
        AttendanceFailureKind.sessionExpired,
        detail: 'session lifetime ran out',
      );
    }

    final http.Response response;
    try {
      response = await getRaw(
        client: _client,
        // A query parameter, so the slug is encoded by `Uri` rather than
        // interpolated raw.
        url: _baseUrl
            .resolve('/me/attendance')
            .replace(queryParameters: {'course': courseSlug}),
        headers: _sessionStore.authorizationHeader,
        timeout: timeout,
      );
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw AttendanceFailure(
        AttendanceFailureKind.network,
        detail: failure.detail,
      );
    }

    final failure = _failureForStatus(response.statusCode);
    if (failure != null) {
      // What the store asks of a token the backend has rejected: forget it,
      // so nothing goes on sending it.
      if (failure.kind == AttendanceFailureKind.sessionExpired) {
        _sessionStore.clear();
      }
      throw failure;
    }

    return _attendanceFromBody(response.body);
  }

  /// `POST /me/attendance/check-in` with `{"token": token}` — the token
  /// exactly as given (the backend trims it). Verified from the backend's
  /// source (`app/services/attendance/checkin.py`, `check_in`); no live
  /// response is captured. `201` is a first check-in, `200` a repeat that
  /// returns the existing record; both answer `{session_id, status,
  /// method, checked_in_at}`. Refusals are `{"error": code}`, kept as
  /// [AttendanceFailure.code]. The token is never put in a failure.
  @override
  Future<AttendanceCheckIn> checkIn(String token) async {
    _ensureSession();

    final http.Response response;
    try {
      response = await postJsonRaw(
        client: _client,
        url: _baseUrl.resolve('/me/attendance/check-in'),
        body: {'token': token},
        headers: _sessionStore.authorizationHeader,
        timeout: timeout,
      );
    } on ApiFailure catch (failure) {
      throw AttendanceFailure(
        AttendanceFailureKind.network,
        detail: failure.detail,
      );
    }

    final failure = _failureForStatus(response.statusCode);
    if (failure != null) {
      if (failure.kind == AttendanceFailureKind.sessionExpired) {
        _sessionStore.clear();
      }
      throw AttendanceFailure(
        failure.kind,
        detail: failure.detail,
        code: _errorCode(response.body),
      );
    }
    final first = switch (response.statusCode) {
      201 => true,
      200 => false,
      _ => throw AttendanceFailure(
        AttendanceFailureKind.unexpected,
        detail: 'HTTP ${response.statusCode}',
      ),
    };
    return _checkInFromBody(response.body, firstCheckIn: first);
  }

  void _ensureSession() {
    if (!_sessionStore.isSignedIn) {
      throw const AttendanceFailure(
        AttendanceFailureKind.sessionExpired,
        detail: 'no session held',
      );
    }
    if (_sessionStore.isExpired()) {
      throw const AttendanceFailure(
        AttendanceFailureKind.sessionExpired,
        detail: 'session lifetime ran out',
      );
    }
  }
}

/// The `error` of a `{"error": code, ...}` body, or null for any other body.
String? _errorCode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final code = decoded['error'];
      if (code is String && code.isNotEmpty) return code;
    }
  } on FormatException {
    // Not JSON: no code to read.
  }
  return null;
}

/// `{session_id, status, method, checked_in_at}`, every field kept as sent.
/// A detail names the field, never a value — the body is the server's, but
/// nothing here should echo what was posted.
AttendanceCheckIn _checkInFromBody(String body, {required bool firstCheckIn}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'check-in: malformed JSON',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'check-in: response was not a JSON object',
    );
  }

  final sessionId = decoded['session_id'];
  final status = decoded['status'];
  final method = decoded['method'];
  final checkedInAt = decoded['checked_in_at'];
  if (sessionId is! int) {
    throw const AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'check-in: session_id: expected an int',
    );
  }
  if (status is! String || status.isEmpty) {
    throw const AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'check-in: status: expected a string',
    );
  }
  if (method != null && method is! String) {
    throw const AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'check-in: method: expected a string or null',
    );
  }
  DateTime? at;
  if (checkedInAt != null) {
    at = checkedInAt is String ? DateTime.tryParse(checkedInAt) : null;
    if (at == null) {
      throw const AttendanceFailure(
        AttendanceFailureKind.server,
        detail: 'check-in: checked_in_at: expected a timestamp or null',
      );
    }
  }
  return AttendanceCheckIn(
    sessionId: sessionId,
    status: status,
    method: method as String?,
    checkedInAt: at,
    firstCheckIn: firstCheckIn,
  );
}

/// Same mapping every other authenticated GET keeps its own copy of.
AttendanceFailure? _failureForStatus(int statusCode) {
  if (statusCode == 401) {
    return const AttendanceFailure(
      AttendanceFailureKind.sessionExpired,
      detail: 'HTTP 401',
    );
  }
  if (statusCode >= 500) {
    return AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode >= 400) {
    return AttendanceFailure(
      AttendanceFailureKind.rejected,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode < 200 || statusCode >= 300) {
    return AttendanceFailure(
      AttendanceFailureKind.unexpected,
      detail: 'HTTP $statusCode',
    );
  }
  return null;
}

CourseAttendance _attendanceFromBody(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }

  final summary = decoded['summary'];
  if (summary is! Map<String, dynamic>) {
    throw AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'summary: expected an object, got ${summary.runtimeType}',
    );
  }

  return CourseAttendance(
    attended: _requireCount(summary, 'attended'),
    totalPast: _requireCount(summary, 'total_past'),
    percent: _requireCount(summary, 'percent').clamp(0, 100),
    sessions: _sessions(decoded['sessions']),
  );
}

/// Both verified responses carry `sessions` as a list — empty for the adult
/// test account, populated for the junior one. Anything else is a contract
/// change and fails loudly, like every other field here.
List<AttendanceSession> _sessions(Object? value) {
  if (value is! List) {
    throw AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'sessions: expected a list, got ${value.runtimeType}',
    );
  }
  return [
    for (final entry in value)
      if (entry is Map<String, dynamic>)
        AttendanceSession(
          date: _requireDate(entry, 'date'),
          // Null for a session on a later day (Issue #170); any other
          // non-string is still a malformed response.
          status: _optionalString(entry, 'status'),
          // Orders two sessions on one day (Issue #443).
          startTime: _optionalString(entry, 'start_time'),
          // When an `absent` becomes missed (Issue #475).
          endTime: _optionalString(entry, 'end_time'),
        )
      else
        throw AttendanceFailure(
          AttendanceFailureKind.server,
          detail: 'sessions: an entry was not an object (${entry.runtimeType})',
        ),
  ];
}

/// `"2026-06-16"` -> that local midnight.
DateTime _requireDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw AttendanceFailure(
      AttendanceFailureKind.server,
      detail: 'sessions[].$key: expected an ISO date, got "$value"',
    );
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw AttendanceFailure(
    AttendanceFailureKind.server,
    detail:
        'sessions[].$key: expected a string or null, got ${value.runtimeType}',
  );
}

int _requireCount(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.round();
  throw AttendanceFailure(
    AttendanceFailureKind.server,
    detail: 'summary.$key: expected a number, got ${value.runtimeType}',
  );
}
