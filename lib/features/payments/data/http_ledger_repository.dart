import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/ledger_entry.dart';
import '../domain/ledger_failure.dart';
import '../domain/ledger_repository.dart';

/// Reads the signed-in student's ledger against the AI Academy API.
///
///     GET https://api.ai-academy.asia/me/ledger
///     Authorization: Bearer <access_token>
///
/// The shape is the verified production response's — see [LedgerEntry]:
/// `{"enrollments": [ … ]}`, one entry per enrollment, which is what
/// `mobile_api_v1_1.md` §7's "per enrollment" describes. Anything else fails
/// loudly as a `server` failure rather than being guessed at.
///
/// Money amounts are JSON numbers (`0.0` in the verified body);
/// `next_due_date` is an ISO date (the contract's §0 convention), or null.
///
/// The token is the one `LoginScreen` saved into [AuthSessionStore]. With no
/// usable session the request is not sent at all — the guard every other
/// authenticated repository applies.
class HttpLedgerRepository implements LedgerRepository {
  HttpLedgerRepository({
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
  Future<List<LedgerEntry>> getLedger() async {
    if (!_sessionStore.isSignedIn) {
      throw const LedgerFailure(
        LedgerFailureKind.sessionExpired,
        detail: 'no session held',
      );
    }
    if (_sessionStore.isExpired()) {
      throw const LedgerFailure(
        LedgerFailureKind.sessionExpired,
        detail: 'session lifetime ran out',
      );
    }

    final http.Response response;
    try {
      response = await getRaw(
        client: _client,
        url: _baseUrl.resolve('/me/ledger'),
        headers: _sessionStore.authorizationHeader,
        timeout: timeout,
      );
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw LedgerFailure(LedgerFailureKind.network, detail: failure.detail);
    }

    final failure = _failureForStatus(response.statusCode);
    if (failure != null) {
      // What the store asks of a token the backend has rejected: forget it,
      // so nothing goes on sending it.
      if (failure.kind == LedgerFailureKind.sessionExpired) {
        _sessionStore.clear();
      }
      throw failure;
    }

    return _ledgerFromBody(response.body);
  }
}

/// Same mapping every other authenticated GET keeps its own copy of.
LedgerFailure? _failureForStatus(int statusCode) {
  if (statusCode == 401) {
    return const LedgerFailure(
      LedgerFailureKind.sessionExpired,
      detail: 'HTTP 401',
    );
  }
  if (statusCode >= 500) {
    return LedgerFailure(LedgerFailureKind.server, detail: 'HTTP $statusCode');
  }
  if (statusCode >= 400) {
    return LedgerFailure(
      LedgerFailureKind.rejected,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode < 200 || statusCode >= 300) {
    return LedgerFailure(
      LedgerFailureKind.unexpected,
      detail: 'HTTP $statusCode',
    );
  }
  return null;
}

List<LedgerEntry> _ledgerFromBody(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw LedgerFailure(
      LedgerFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const LedgerFailure(
      LedgerFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }

  final enrollments = decoded['enrollments'];
  if (enrollments is! List) {
    throw LedgerFailure(
      LedgerFailureKind.server,
      detail:
          'response carried no "enrollments" list '
          '(got ${enrollments.runtimeType})',
    );
  }

  return [for (final entry in enrollments) _entryFrom(entry)];
}

LedgerEntry _entryFrom(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw LedgerFailure(
      LedgerFailureKind.server,
      detail: 'a ledger entry was not a JSON object (got ${entry.runtimeType})',
    );
  }

  return LedgerEntry(
    enrollmentId: _requireInt(entry, 'enrollment_id'),
    cohortId: _requireInt(_requireObject(entry, 'cohort'), 'id'),
    balance: _requireAmount(entry, 'balance'),
    nextDueDate: _optionalDate(entry, 'next_due_date'),
  );
}

Map<String, dynamic> _requireObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw LedgerFailure(
    LedgerFailureKind.server,
    detail: 'ledger.$key: expected an object, got ${value.runtimeType}',
  );
}

int _requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw LedgerFailure(
    LedgerFailureKind.server,
    detail: 'ledger.$key: expected a number, got ${value.runtimeType}',
  );
}

num _requireAmount(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value;
  throw LedgerFailure(
    LedgerFailureKind.server,
    detail: 'ledger.$key: expected an amount, got ${value.runtimeType}',
  );
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw LedgerFailure(
      LedgerFailureKind.server,
      detail: 'ledger.$key: expected an ISO date or null, got "$value"',
    );
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}
