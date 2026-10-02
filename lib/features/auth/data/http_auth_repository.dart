import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/user_type.dart';
import 'auth_http.dart';

/// Signs in and out against the AI Academy API.
///
///     POST https://api.ai-academy.asia/auth/login
///     { "email": "...", "password": "..." }
///     -> { "access_token": "...", "refresh_token": "...", "expires_in": 3600,
///          "user_type": "adult" }
///
///     POST https://api.ai-academy.asia/auth/logout      (no auth)
///     { "refresh_token": "..." }
///
///     POST https://api.ai-academy.asia/auth/refresh     (no auth)
///     { "refresh_token": "..." }
///     -> the login response's shape, with a rotated refresh_token
///
/// Refresh was confirmed against a test account (Issue #176): 200 carries
/// `access_token`, a new `refresh_token`, `expires_in` and `user_type`, read
/// by the same parser as sign-in; re-sending a spent refresh token answers
/// `401 {"error": "refresh_token_reused"}`, an unknown one
/// `401 {"error": "invalid_refresh_token"}`.
///
/// The logout shape is the Postman collection's "Logout (this device)" — see
/// `docs/course_learning_backend_api_audit_v2.md`. Its response body has no
/// confirmed shape, so only the status is read.
///
/// `user_type` is read into [AuthSession.userType] — see [UserType].
/// `expires_in` is optional — the backend does not always report it — so a
/// missing value is carried through as null rather than guessed at.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    http.Client? client,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl);

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

  final http.Client _client;
  final Uri _baseUrl;
  final Duration timeout;

  @override
  Future<AuthSession> signIn({required String email, required String password}) async {
    final response = await postJson(
      client: _client,
      url: _baseUrl.resolve('/auth/login'),
      body: {'email': email, 'password': password},
      timeout: timeout,
    );
    return _sessionFrom(response);
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    final response = await postJson(
      client: _client,
      url: _baseUrl.resolve('/auth/refresh'),
      body: {'refresh_token': refreshToken},
      timeout: timeout,
    );
    return _sessionFrom(response);
  }

  /// A session out of a sign-in or refresh response — the two share a shape.
  AuthSession _sessionFrom(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (e) {
      throw AuthFailure(AuthFailureKind.server, detail: 'malformed JSON: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AuthFailure(
        AuthFailureKind.server,
        detail: 'response was not a JSON object',
      );
    }

    final token = decoded['access_token'];
    if (token is! String || token.isEmpty) {
      throw const AuthFailure(
        AuthFailureKind.server,
        detail: 'response carried no access_token',
      );
    }

    final expiresIn = decoded['expires_in'];
    final refreshToken = decoded['refresh_token'];
    return AuthSession(
      accessToken: token,
      refreshToken: refreshToken is String && refreshToken.isNotEmpty
          ? refreshToken
          : null,
      expiresIn: expiresIn is num && expiresIn > 0
          ? Duration(seconds: expiresIn.toInt())
          : null,
      userType: UserType.fromApi(decoded['user_type']),
    );
  }

  @override
  Future<void> signOut({required String refreshToken}) async {
    await postJson(
      client: _client,
      url: _baseUrl.resolve('/auth/logout'),
      body: {'refresh_token': refreshToken},
      timeout: timeout,
    );
  }
}
