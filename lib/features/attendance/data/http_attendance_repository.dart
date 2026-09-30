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
/// Field names are the verified production response's — see
/// [CourseAttendance]. Only `summary` is read; `sessions` is left alone, so
/// an empty list, or entries of any shape, cannot fail the parse.
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
