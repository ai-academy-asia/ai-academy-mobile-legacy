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
  final response = await _send(
    () => client.get(url, headers: {HttpHeaders.acceptHeader: 'application/json', ...headers}),
    timeout,
  );

  final failure = failureForStatus(response.statusCode);
  if (failure != null) throw failure;

  return response;
}

/// The transport for a POST that carries no request body at all —
/// `POST /cohorts/{id}/enroll` is the first caller. `postJson` cannot serve it:
/// that always encodes a JSON body, and this contract says there is none.
///
/// Unlike [getJson], this returns the response for **every** status and leaves
/// reading it to the caller. Its callers are authenticated, and an
/// authenticated endpoint has to read a 401 as "sign in again" — a reading
/// [failureForStatus] deliberately does not have, and one [ApiFailureKind]
/// cannot gain without every public caller's `switch` carrying a case that
/// never occurs there. Only a request that never completed is thrown, as
/// [ApiFailureKind.network].
Future<http.Response> postWithoutBody({
  required http.Client client,
  required Uri url,
  required Duration timeout,
  Map<String, String> headers = const {},
}) => _send(
  () => client.post(url, headers: {HttpHeaders.acceptHeader: 'application/json', ...headers}),
  timeout,
);

/// The transport for an authenticated GET whose caller must classify 401
/// itself — `GET /me/cohorts` is the first caller. Same reasoning
/// [postWithoutBody] documents for `POST /cohorts/{id}/enroll`: an
/// authenticated endpoint's 401 means "sign in again", a reading
/// [failureForStatus] deliberately does not have, and giving it one would put
/// a case on every public GET caller's `switch` that can never occur there.
///
/// Returns the response for **every** status, the same way [postWithoutBody]
/// does. Only a request that never completed is thrown, as
/// [ApiFailureKind.network].
Future<http.Response> getRaw({
  required http.Client client,
  required Uri url,
  required Duration timeout,
  Map<String, String> headers = const {},
}) => _send(
  () => client.get(url, headers: {HttpHeaders.acceptHeader: 'application/json', ...headers}),
  timeout,
);

/// Runs [request], turning one that never completed into
/// [ApiFailureKind.network] — so each transport above states the try/catch
/// once rather than restating it.
Future<http.Response> _send(
  Future<http.Response> Function() request,
  Duration timeout,
) async {
  try {
    return await request().timeout(timeout);
  } on TimeoutException {
    throw const ApiFailure(ApiFailureKind.network, detail: 'request timed out');
  } on SocketException catch (e) {
    throw ApiFailure(ApiFailureKind.network, detail: e.message);
  } on http.ClientException catch (e) {
    throw ApiFailure(ApiFailureKind.network, detail: e.message);
  }
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
