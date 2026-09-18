import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/enrolled_cohorts_repository.dart';
import '../domain/enrollment_failure.dart';

/// Reads the signed-in student's enrolled cohorts against the AI Academy API.
///
///     GET https://api.ai-academy.asia/me/cohorts
///     Authorization: Bearer <access_token>
///
/// The response shape beyond the URL, method and auth header is not
/// confirmed. Modeled the same way `GET /cohorts` is confirmed to answer —
/// `{ "cohorts": [ { "id": ..., ... } ] }` — since this endpoint's name is
/// that one's own convention applied to "mine", and every cohort
/// representation this API has shown carries an "id". Only `id` and an
/// optional `progress_pct` (the same field name and meaning
/// `POST /cohorts/{id}/enroll` confirms on `Enrollment`) are read; anything
/// else an entry carries is ignored. If the real response uses a different
/// envelope or field name for `id`, this fails loudly rather than silently
/// getting it wrong — the same policy `HttpCohortRepository` follows.
/// `progress_pct` gets the gentler reading: absent or `null` simply means no
/// progress figure for that cohort, since this endpoint's envelope was never
/// confirmed to carry one at all.
///
/// The token is the one `LoginScreen` saved into [AuthSessionStore]. With no
/// usable session the request is not sent at all, the same guard
/// `HttpEnrollmentRepository.enroll` applies.
class HttpEnrolledCohortsRepository implements EnrolledCohortsRepository {
  HttpEnrolledCohortsRepository({
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
  Future<Set<int>> getEnrolledCohortIds() async {
    final cohorts = await _fetchEnrolledCohorts();
    return {for (final cohort in cohorts) cohort.cohortId};
  }

  @override
  Future<List<EnrolledCohortSummary>> getEnrolledCohorts() =>
      _fetchEnrolledCohorts();

  Future<List<EnrolledCohortSummary>> _fetchEnrolledCohorts() async {
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
      response = await getRaw(
        client: _client,
        url: _baseUrl.resolve('/me/cohorts'),
        headers: _sessionStore.authorizationHeader,
        timeout: timeout,
      );
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw EnrollmentFailure(
        EnrollmentFailureKind.network,
        detail: failure.detail,
      );
    }

    final failure = _failureForStatus(response.statusCode);
    if (failure != null) {
      // What the store asks of a token the backend has rejected: forget it,
      // so nothing goes on sending it.
      if (failure.kind == EnrollmentFailureKind.sessionExpired) {
        _sessionStore.clear();
      }
      throw failure;
    }

    return _enrolledCohortsFromBody(response.body);
  }
}

/// Same mapping `HttpEnrollmentRepository._failureForStatus` uses — a 401 is
/// the session, not the request, being refused; kept as its own copy rather
/// than shared, the way `ApiFailure`'s and `AuthFailure`'s own status
/// mappings are already kept apart in this codebase. `rejected` is the
/// closest existing case for "the API answered with a 4xx that is not a dead
/// session" — there is no confirmed error code to tell a reason apart on a
/// listing endpoint any more than there is on the enroll one.
EnrollmentFailure? _failureForStatus(int statusCode) {
  if (statusCode == 401) {
    return const EnrollmentFailure(
      EnrollmentFailureKind.sessionExpired,
      detail: 'HTTP 401',
    );
  }
  if (statusCode >= 500) {
    return EnrollmentFailure(
      EnrollmentFailureKind.server,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode >= 400) {
    return EnrollmentFailure(
      EnrollmentFailureKind.rejected,
      detail: 'HTTP $statusCode',
    );
  }
  if (statusCode < 200 || statusCode >= 300) {
    return EnrollmentFailure(
      EnrollmentFailureKind.unexpected,
      detail: 'HTTP $statusCode',
    );
  }
  return null;
}

List<EnrolledCohortSummary> _enrolledCohortsFromBody(String body) {
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

  final cohorts = decoded['cohorts'];
  if (cohorts is! List) {
    throw EnrollmentFailure(
      EnrollmentFailureKind.server,
      detail: 'response carried no "cohorts" list (got ${cohorts.runtimeType})',
    );
  }

  return [for (final entry in cohorts) _enrolledCohortFrom(entry)];
}

EnrolledCohortSummary _enrolledCohortFrom(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw EnrollmentFailure(
      EnrollmentFailureKind.server,
      detail: 'a cohort entry was not a JSON object (got ${entry.runtimeType})',
    );
  }

  final id = entry['id'];
  if (id is! num) {
    throw EnrollmentFailure(
      EnrollmentFailureKind.server,
      detail: 'cohort.id: expected a number, got ${id.runtimeType}',
    );
  }

  final progress = entry['progress_pct'];
  if (progress != null && progress is! num) {
    throw EnrollmentFailure(
      EnrollmentFailureKind.server,
      detail:
          'cohort.progress_pct: expected a number or null, got ${progress.runtimeType}',
    );
  }

  return EnrolledCohortSummary(
    cohortId: id.toInt(),
    progressPct: (progress as num?)?.toDouble(),
  );
}
