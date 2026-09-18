import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../domain/auth_session_store.dart';
import '../domain/current_user.dart';
import '../domain/current_user_failure.dart';
import '../domain/current_user_repository.dart';

/// Reads the signed-in user's own account against the AI Academy API.
///
///     GET https://api.ai-academy.asia/auth/me
///     Authorization: Bearer <access_token>
///
/// Same shape as `HttpEnrolledCohortsRepository`: the token is the one
/// `LoginScreen` saved into [AuthSessionStore], the request is not sent at
/// all without a usable session, and a 401 is read as the session — not the
/// request — being refused.
class HttpCurrentUserRepository implements CurrentUserRepository {
  HttpCurrentUserRepository({
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
  Future<CurrentUser> getCurrentUser() async {
    if (!_sessionStore.isSignedIn) {
      throw const CurrentUserFailure(
        CurrentUserFailureKind.sessionExpired,
        detail: 'no session held',
      );
    }
    if (_sessionStore.isExpired()) {
      throw const CurrentUserFailure(
        CurrentUserFailureKind.sessionExpired,
        detail: 'session lifetime ran out',
      );
    }

    final http.Response response;
    try {
      response = await getRaw(
        client: _client,
        url: _baseUrl.resolve('/auth/me'),
        headers: _sessionStore.authorizationHeader,
        timeout: timeout,
      );
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw CurrentUserFailure(CurrentUserFailureKind.network, detail: failure.detail);
    }

    final failure = _failureForStatus(response.statusCode);
    if (failure != null) {
      // What the store asks of a token the backend has rejected: forget it,
      // so nothing goes on sending it.
      if (failure.kind == CurrentUserFailureKind.sessionExpired) _sessionStore.clear();
      throw failure;
    }

    return _currentUserFromBody(response.body);
  }
}

/// Same mapping `HttpEnrolledCohortsRepository`'s own copy uses — kept as its
/// own rather than shared, the way this codebase already keeps each
/// authenticated GET's status mapping apart.
CurrentUserFailure? _failureForStatus(int statusCode) {
  if (statusCode == 401) {
    return const CurrentUserFailure(CurrentUserFailureKind.sessionExpired, detail: 'HTTP 401');
  }
  if (statusCode >= 500) {
    return CurrentUserFailure(CurrentUserFailureKind.server, detail: 'HTTP $statusCode');
  }
  if (statusCode >= 400) {
    return CurrentUserFailure(CurrentUserFailureKind.rejected, detail: 'HTTP $statusCode');
  }
  if (statusCode < 200 || statusCode >= 300) {
    return CurrentUserFailure(CurrentUserFailureKind.unexpected, detail: 'HTTP $statusCode');
  }
  return null;
}

CurrentUser _currentUserFromBody(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw CurrentUserFailure(
      CurrentUserFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const CurrentUserFailure(
      CurrentUserFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }

  return CurrentUser(
    id: _requireInt(decoded, 'id'),
    actorId: _requireInt(decoded, 'actor_id'),
    actorType: _requireString(decoded, 'actor_type'),
    email: _requireString(decoded, 'email'),
    role: _requireString(decoded, 'role'),
    isActive: _requireBool(decoded, 'is_active'),
    mustChangePassword: _requireBool(decoded, 'must_change_password'),
    profile: _profileFrom(_requireObject(decoded, 'profile')),
  );
}

UserProfile _profileFrom(Map<String, dynamic> json) {
  return UserProfile(
    id: _requireInt(json, 'id'),
    firstName: _requireString(json, 'first_name'),
    lastName: _requireString(json, 'last_name'),
    phone: _requireString(json, 'phone'),
    uiMode: _requireString(json, 'ui_mode'),
  );
}

Map<String, dynamic> _requireObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw CurrentUserFailure(
    CurrentUserFailureKind.server,
    detail: '$key: expected an object, got ${value.runtimeType}',
  );
}

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw CurrentUserFailure(
    CurrentUserFailureKind.server,
    detail: '$key: expected a number, got ${value.runtimeType}',
  );
}

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw CurrentUserFailure(
    CurrentUserFailureKind.server,
    detail: '$key: expected a string, got ${value.runtimeType}',
  );
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw CurrentUserFailure(
    CurrentUserFailureKind.server,
    detail: '$key: expected a boolean, got ${value.runtimeType}',
  );
}
