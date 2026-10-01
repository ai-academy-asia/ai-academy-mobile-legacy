import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/attendance_failure.dart';
import '../domain/attendance_repository.dart';
import '../domain/course_attendance.dart';

/// Reads the signed-in student's attendance in one course against the AI
/// Academy API.
///
///     GET https://api.ai-academy.asia/me/attendance?course={course_slug}
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
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl),
       _sessionStore = sessionStore ?? AuthSessionStore.instance;

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

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
          status: _requireString(entry, 'status'),
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

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw AttendanceFailure(
    AttendanceFailureKind.server,
    detail: 'sessions[].$key: expected a string, got ${value.runtimeType}',
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
