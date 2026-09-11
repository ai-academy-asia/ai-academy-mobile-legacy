import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/auth_failure.dart';

/// The transport the auth endpoints share.
///
/// Both auth calls talk to the same API the same way — JSON in, bearer token
/// when there is one, and the same mapping from status codes and socket
/// failures onto [AuthFailure]. That mapping lived inside the sign-in
/// repository; it is here so the change-password repository reuses it rather
/// than restating it, and so there is one place to correct if the API's error
/// behaviour turns out to differ.
///
/// Returns the response for any 2xx and throws [AuthFailure] otherwise. It does
/// not read the body: what a success body contains differs per endpoint, and
/// one of them has no confirmed shape at all.
Future<http.Response> postJson({
  required http.Client client,
  required Uri url,
  required Map<String, Object?> body,
  required Duration timeout,
  Map<String, String> headers = const {},
}) async {
  final http.Response response;
  try {
    response = await client
        .post(
          url,
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.acceptHeader: 'application/json',
            ...headers,
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
  } on TimeoutException {
    throw const AuthFailure(AuthFailureKind.network, detail: 'request timed out');
  } on SocketException catch (e) {
    throw AuthFailure(AuthFailureKind.network, detail: e.message);
  } on http.ClientException catch (e) {
    throw AuthFailure(AuthFailureKind.network, detail: e.message);
  }

  final failure = failureForStatus(response.statusCode, body: response.body);
  if (failure != null) throw failure;

  return response;
}

/// Error codes this API returns in `{"error": "..."}` on a 401 when the problem
/// is the session rather than the credentials.
///
/// Both were observed directly against `POST /auth/change-password`: sending no
/// token answers `authentication_required`, and sending an invalid one answers
/// `invalid_token`. Any other code falls through to [
/// AuthFailureKind.invalidCredentials], which is what `/auth/login` answers with
/// (`invalid_credentials`).
const Set<String> _sessionErrorCodes = {'authentication_required', 'invalid_token'};

/// The failure a status code means, or null when it is a success.
///
/// 401 and 403 are a refusal — but a 401 can mean the password was wrong *or*
/// that the request was not authenticated at all, and the two need different
/// answers from the UI. [body] is read only far enough to tell them apart.
AuthFailure? failureForStatus(int statusCode, {String? body}) {
  if (statusCode == 401 || statusCode == 403) {
    final code = _errorCode(body);
    if (statusCode == 401 && code != null && _sessionErrorCodes.contains(code)) {
      return AuthFailure(AuthFailureKind.sessionExpired, detail: 'HTTP 401 $code');
    }
    return AuthFailure(AuthFailureKind.invalidCredentials, detail: 'HTTP $statusCode');
  }
  if (statusCode >= 500) {
    return AuthFailure(AuthFailureKind.server, detail: 'HTTP $statusCode');
  }
  if (statusCode < 200 || statusCode >= 300) {
    return AuthFailure(AuthFailureKind.unexpected, detail: 'HTTP $statusCode');
  }
  return null;
}

/// The machine code from `{"error": "..."}`, the form this backend uses.
///
/// Anything unreadable is simply no code — an error body is never the reason a
/// request is reported as something other than what its status already said.
String? _errorCode(String? body) {
  if (body == null || body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final code = decoded['error'];
      if (code is String && code.isNotEmpty) return code;
    }
  } on FormatException {
    return null;
  }
  return null;
}
