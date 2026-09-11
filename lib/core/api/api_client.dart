import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_failure.dart';

/// The transport for public, unauthenticated GET endpoints.
///
/// The sibling of `auth_http.dart`'s `postJson`, added rather than extended
/// because it serves a different family of endpoints: no request body to
/// encode, no bearer token to expect, and failures reported as [ApiFailure]
/// rather than `AuthFailure`. `GET /courses` is the first caller; any later
/// public GET endpoint reuses this rather than restating the try/catch and
/// status mapping.
///
/// Returns the response for any 2xx and throws [ApiFailure] otherwise. It does
/// not read the body — each endpoint's success shape is its own concern.
Future<http.Response> getJson({
  required http.Client client,
  required Uri url,
  required Duration timeout,
  Map<String, String> headers = const {},
}) async {
  final http.Response response;
  try {
    response = await client
        .get(url, headers: {HttpHeaders.acceptHeader: 'application/json', ...headers})
        .timeout(timeout);
  } on TimeoutException {
    throw const ApiFailure(ApiFailureKind.network, detail: 'request timed out');
  } on SocketException catch (e) {
    throw ApiFailure(ApiFailureKind.network, detail: e.message);
  } on http.ClientException catch (e) {
    throw ApiFailure(ApiFailureKind.network, detail: e.message);
  }

  final failure = failureForStatus(response.statusCode);
  if (failure != null) throw failure;

  return response;
}

/// The failure a status code means, or null when it is a success.
///
/// No 401/403 special-casing here the way `auth_http.dart` has: this transport
/// is for endpoints confirmed to need no authentication, so a 401 from one
/// would be the API behaving unexpectedly, not a credential or session being
/// refused — it falls through to [ApiFailureKind.unexpected] like any other
/// unrecognised non-2xx.
ApiFailure? failureForStatus(int statusCode) {
  if (statusCode >= 500) {
    return ApiFailure(ApiFailureKind.server, detail: 'HTTP $statusCode');
  }
  if (statusCode < 200 || statusCode >= 300) {
    return ApiFailure(ApiFailureKind.unexpected, detail: 'HTTP $statusCode');
  }
  return null;
}
