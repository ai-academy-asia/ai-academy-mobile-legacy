import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/enrollment.dart';
import '../domain/enrollment_failure.dart';
import '../domain/enrollment_repository.dart';

/// Enrolls the signed-in student against the AI Academy API.
///
///     POST https://api.ai-academy.asia/cohorts/{cohort_id}/enroll
///     Authorization: Bearer <student_access_token>
///     (no body)
///     -> 201 { "id", "student_id", "cohort_id", "course_id", "status",
///              "progress_pct", "completed_at", "created_at",
///              "created_by_admin_id", "created_via" }
///
/// The token is the one `LoginScreen` saved into [AuthSessionStore]. With no
/// usable session the request is not sent at all: the API could only refuse
/// it, so the student is told to sign in again without the round trip.
class HttpEnrollmentRepository implements EnrollmentRepository {
  HttpEnrollmentRepository({
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
  Future<Enrollment> enroll(int cohortId) async {
    if (!_sessionStore.isSignedIn) {
      throw const EnrollmentFailure(
        EnrollmentFailureKind.sessionExpired,
        detail: 'no session held',
      );
    }
    if (_sessionStore.isExpired()) {
      throw const EnrollmentFailure(
        EnrollmentFailureKind.sessionExpired,
        detail: 'session lifetime ran out',
      );
    }

    final http.Response response;
    try {
      response = await postWithoutBody(
        client: _client,
        url: _baseUrl.resolve('/cohorts/$cohortId/enroll'),
        headers: _sessionStore.authorizationHeader,
        timeout: timeout,
      );
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw EnrollmentFailure(EnrollmentFailureKind.network, detail: failure.detail);
    }

    final failure = _failureForStatus(response.statusCode);
    if (failure != null) {
      // What the store asks of a token the backend has rejected: forget it, so
      // nothing goes on sending it.
      if (failure.kind == EnrollmentFailureKind.sessionExpired) _sessionStore.clear();
      throw failure;
    }

    return _enrollmentFromBody(response.body);
  }
}

/// The failure a status code means, or null when it is a success.
///
/// A 401 is read as the session being refused whatever its body says.
/// `auth_http.dart` has to read the body to tell a wrong password from a dead
/// session; this request carries no credentials but the token, so there is
/// nothing else a 401 here could be about.
EnrollmentFailure? _failureForStatus(int statusCode) {
  if (statusCode == 401) {
    return const EnrollmentFailure(EnrollmentFailureKind.sessionExpired, detail: 'HTTP 401');
  }
  if (statusCode >= 500) {
    return EnrollmentFailure(EnrollmentFailureKind.server, detail: 'HTTP $statusCode');
  }
  if (statusCode >= 400) {
    return EnrollmentFailure(EnrollmentFailureKind.rejected, detail: 'HTTP $statusCode');
  }
  if (statusCode < 200 || statusCode >= 300) {
    return EnrollmentFailure(EnrollmentFailureKind.unexpected, detail: 'HTTP $statusCode');
  }
  return null;
}

Enrollment _enrollmentFromBody(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw EnrollmentFailure(
      EnrollmentFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const EnrollmentFailure(
      EnrollmentFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }

  return Enrollment(
    id: _requireInt(decoded, 'id'),
    studentId: _requireInt(decoded, 'student_id'),
    cohortId: _requireInt(decoded, 'cohort_id'),
    courseId: _requireInt(decoded, 'course_id'),
    status: _requireString(decoded, 'status'),
    progressPct: _requireDouble(decoded, 'progress_pct'),
    completedAt: _optionalString(decoded, 'completed_at'),
    createdAt: _requireString(decoded, 'created_at'),
    createdByAdminId: _optionalInt(decoded, 'created_by_admin_id'),
    createdVia: _requireString(decoded, 'created_via'),
  );
}

// --- Field readers -----------------------------------------------------
//
// Same style as `http_cohort_repository.dart`: named per field so a parse
// failure says which field rather than leaving a bare stack trace.

EnrollmentFailure _fieldFailure(String key, String expected, Object? value) =>
    EnrollmentFailure(
      EnrollmentFailureKind.server,
      detail: 'enrollment.$key: expected $expected, got ${value.runtimeType}',
    );

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw _fieldFailure(key, 'a number', value);
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toInt();
  throw _fieldFailure(key, 'a number or null', value);
}

double _requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw _fieldFailure(key, 'a number', value);
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw _fieldFailure(key, 'a string', value);
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw _fieldFailure(key, 'a string or null', value);
}
