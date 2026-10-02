import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/auth_session_store.dart';
import 'session_refresher.dart';

/// The `http.Client` every authenticated repository sends through: it keeps
/// a session alive across its access token's expiry (Issue #176).
///
/// It only acts on requests that carry an `Authorization` header — the ones
/// the repositories authenticate with the stored token. Anything else (the
/// public catalog, sign-in, refresh, sign-out) passes straight through.
///
/// For an authenticated request:
///
///  1. **Before sending**, a session whose access token has outlived its
///     reported `expires_in` is renewed first, and the request goes out with
///     the new token.
///  2. **On a 401 whose `error` is a token failure** — the contract's
///     `authentication_required`, `token_expired`, `invalid_token`,
///     `account_inactive` — the session is renewed through [SessionRefresher]
///     and the request is **retried once** with the new token. Whatever the
///     retry answers is returned as is: a second refusal never refreshes
///     again, so there is no loop.
///  3. **Any other 401** — `invalid_credentials` from change-password's wrong
///     current password, or a body with no recognised code — and every other
///     status are returned untouched, for the repository to read as it
///     always has.
///
/// When the renewal fails, [SessionRefresher] has already cleared the
/// session and signalled the return to Login; the original 401 is returned.
///
/// The request body is buffered before the first send, so a retry — uploads
/// included — re-sends exactly the same bytes and headers.
class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    http.Client? inner,
    AuthSessionStore? sessionStore,
    SessionRefresher? refresher,
  }) : _inner = inner ?? http.Client(),
       _store = sessionStore ?? AuthSessionStore.instance,
       _refresher = refresher ?? SessionRefresher.instance;

  /// The app's own, on [AuthSessionStore.instance] and
  /// [SessionRefresher.instance] — the default client of every authenticated
  /// repository, Adult and Junior alike.
  static final AuthenticatedClient instance = AuthenticatedClient();

  /// The contract's 401 codes for a missing, expired, invalid or inactive
  /// token (`course_learning_api_contract_v1.md` §0).
  static const Set<String> tokenFailureCodes = {
    'authentication_required',
    'token_expired',
    'invalid_token',
    'account_inactive',
  };

  final http.Client _inner;
  final AuthSessionStore _store;
  final SessionRefresher _refresher;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sentAuthorization = request.headers[HttpHeaders.authorizationHeader];
    if (sentAuthorization == null) return _inner.send(request);

    final body = await request.finalize().toBytes();
    var token = _bearer(sentAuthorization);

    if (_store.isAccessTokenExpired() && _store.canRefresh) {
      if (await _refresher.refresh(failedToken: _store.accessToken)) {
        token = _store.accessToken ?? token;
      }
    }

    final first = await _inner.send(_copy(request, body, token));
    if (first.statusCode != HttpStatus.unauthorized) return first;

    final firstBody = await first.stream.toBytes();
    final unchanged = _replay(first, firstBody);
    if (!tokenFailureCodes.contains(_errorCode(firstBody))) return unchanged;

    if (!await _refresher.refresh(failedToken: token)) return unchanged;
    final renewed = _store.accessToken;
    if (renewed == null) return unchanged;

    return _inner.send(_copy(request, body, renewed));
  }

  @override
  void close() => _inner.close();

  static String? _bearer(String authorization) =>
      authorization.startsWith('Bearer ')
      ? authorization.substring('Bearer '.length)
      : null;

  /// [request] again, with [body] and — when there is one — [token].
  static http.Request _copy(
    http.BaseRequest request,
    List<int> body,
    String? token,
  ) {
    final copy = http.Request(request.method, request.url)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..headers.addAll(request.headers)
      ..bodyBytes = body;
    if (token != null) {
      copy.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    return copy;
  }

  static http.StreamedResponse _replay(
    http.StreamedResponse response,
    List<int> body,
  ) => http.StreamedResponse(
    Stream.value(body),
    response.statusCode,
    contentLength: body.length,
    request: response.request,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );

  /// The `error` code of a `{"error": "..."}` body, or null.
  static String? _errorCode(List<int> body) {
    try {
      final decoded = jsonDecode(utf8.decode(body));
      if (decoded is Map<String, dynamic>) {
        final code = decoded['error'];
        if (code is String) return code;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
