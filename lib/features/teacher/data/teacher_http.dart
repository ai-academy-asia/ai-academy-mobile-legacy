import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/teacher_failure.dart';

/// What every teacher repository shares: the session guard, the
/// authenticated GET and the status mapping. Teacher Home (Issue #229) and
/// Teacher Schedule (Issue #231) read the same API with the same rules, so
/// they keep one copy of them here rather than one each.

/// Refuses to send anything without a usable session — the guard every
/// authenticated repository applies.
void ensureTeacherSession(AuthSessionStore sessionStore) {
  if (!sessionStore.isSignedIn) {
    throw const TeacherFailure(
      TeacherFailureKind.sessionExpired,
      detail: 'no session held',
    );
  }
  if (sessionStore.isExpired()) {
    throw const TeacherFailure(
      TeacherFailureKind.sessionExpired,
      detail: 'session lifetime ran out',
    );
  }
}

/// An authenticated GET whose non-2xx answer is thrown as its
/// [TeacherFailure]. A 401 that survives renewal also clears the session —
/// what the store asks of a token the backend has rejected.
Future<http.Response> teacherGet({
  required http.Client client,
  required Uri url,
  required AuthSessionStore sessionStore,
  required Duration timeout,
}) async {
  final http.Response response;
  try {
    response = await getRaw(
      client: client,
      url: url,
      headers: sessionStore.authorizationHeader,
      timeout: timeout,
    );
  } on ApiFailure catch (failure) {
    // The transport throws only for a request that never completed.
    throw TeacherFailure(TeacherFailureKind.network, detail: failure.detail);
  }

  final failure = teacherFailureForStatus(response.statusCode);
  if (failure != null) {
    if (failure.kind == TeacherFailureKind.sessionExpired) {
      sessionStore.clear();
    }
    throw failure;
  }
  return response;
}

/// Same mapping every other authenticated GET keeps its own copy of.
TeacherFailure? teacherFailureForStatus(int statusCode) {
  if (statusCode == 401) {
    return const TeacherFailure(
      TeacherFailureKind.sessionExpired,
      detail: 'HTTP 401',
    );
  }
  if (statusCode >= 500) {
    return TeacherFailure(
      TeacherFailureKind.server,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode >= 400) {
    return TeacherFailure(
      TeacherFailureKind.rejected,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode < 200 || statusCode >= 300) {
    return TeacherFailure(
      TeacherFailureKind.unexpected,
      detail: 'HTTP $statusCode',
    );
  }
  return null;
}

/// The body as a JSON object. Anything else is the API misbehaving: a
/// `server` failure.
Map<String, dynamic> teacherJsonObject(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw TeacherFailure(
      TeacherFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const TeacherFailure(
      TeacherFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }
  return decoded;
}
