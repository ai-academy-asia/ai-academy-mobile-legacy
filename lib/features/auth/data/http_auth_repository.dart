import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import 'auth_http.dart';

/// Signs in against the AI Academy API.
///
/// One endpoint, the confirmed one:
///
///     POST https://api.ai-academy.asia/auth/login
///     { "email": "...", "password": "..." }
///     -> { "access_token": "...", "expires_in": 3600 }
///
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
    return AuthSession(
      accessToken: token,
      expiresIn: expiresIn is num && expiresIn > 0
          ? Duration(seconds: expiresIn.toInt())
          : null,
    );
  }
}
