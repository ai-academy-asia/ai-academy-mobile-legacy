import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/data/authenticated_client.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/contract_failure.dart';
import '../domain/contract_repository.dart';
import '../domain/student_contract.dart';

/// The student contract list (Issues #294, #300):
///
///     GET /me/contracts
///       -> {"contracts": [{id, contract_number, status, enrollment_id,
///           course_id, course {id, slug, title {mn, en}, level},
///           cohort {id, name, start_date, end_date}, created_at,
///           signed_at, cancelled_at, can_view, can_sign, is_current,
///           document_url}, ...]}
///
/// The item shape is the backend's own (`ai-academy-backend`
/// `docs/e_contract_api_v1.md`, commit `208e1c9`), **not observed live**:
/// the only production response seen is `{"contracts": []}` (Adult student).
/// The list is newest first. Calling it is not side-effect free on the
/// backend: it creates `pending` rows for the student's own eligible
/// enrollments (`core.sync()`), by design.
///
/// **The envelope is required, the fields are lenient.** A missing
/// `contracts` array, or an entry that is not an object, is the server's
/// fault ([ContractFailureKind.server]). Inside an entry, a missing or
/// mistyped field reads as null (false for the flags) — see
/// [StudentContract] — so the list's length stays the server's.
///
/// Detail, `/preview`, `/sign` and `/download` are deliberately not called
/// (Issue #300's scope; no design for those steps).
///
/// Sent through [AuthenticatedClient.instance], so an expired access token is
/// renewed and the request retried once; a 401 that survives that ends the
/// session here too, as every authenticated repository does.
class HttpContractRepository implements ContractRepository {
  HttpContractRepository({
    http.Client? client,
    Uri? baseUrl,
    AuthSessionStore? sessionStore,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? AuthenticatedClient.instance,
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl),
       _sessionStore = sessionStore ?? AuthSessionStore.instance;

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;
  final Duration timeout;

  @override
  Future<List<StudentContract>> getContracts() async {
    if (!_sessionStore.isSignedIn || _sessionStore.isExpired()) {
      throw const ContractFailure(
        ContractFailureKind.sessionExpired,
        detail: 'no usable session',
      );
    }

    final http.Response response;
    try {
      response = await getRaw(
        client: _client,
        url: _baseUrl.resolve('/me/contracts'),
        headers: _sessionStore.authorizationHeader,
        timeout: timeout,
      );
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw ContractFailure(
        ContractFailureKind.network,
        detail: failure.detail,
      );
    }

    final status = response.statusCode;
    if (status == 401) {
      // A token the backend refused even after renewal: forget it.
      _sessionStore.clear();
      throw const ContractFailure(
        ContractFailureKind.sessionExpired,
        detail: 'HTTP 401',
      );
    }
    if (status < 200 || status >= 300) {
      throw ContractFailure(
        status >= 500
            ? ContractFailureKind.server
            : ContractFailureKind.unexpected,
        detail: 'HTTP $status',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (e) {
      throw ContractFailure(
        ContractFailureKind.server,
        detail: 'malformed JSON: ${e.message}',
      );
    }
    final items = decoded is Map<String, dynamic> ? decoded['contracts'] : null;
    if (items is! List) {
      throw const ContractFailure(
        ContractFailureKind.server,
        detail: 'contracts: expected a list',
      );
    }
    final contracts = <StudentContract>[];
    for (final (i, item) in items.indexed) {
      if (item is! Map<String, dynamic>) {
        throw ContractFailure(
          ContractFailureKind.server,
          detail: 'contracts[$i]: not an object',
        );
      }
      contracts.add(contractFrom(item));
    }
    return contracts;
  }
}

/// One contract item, read leniently. Public so the mapping can be tested on
/// its own.
StudentContract contractFrom(Map<String, dynamic> json) {
  final course = json['course'];
  final cohort = json['cohort'];
  final title = course is Map<String, dynamic> ? course['title'] : null;
  return StudentContract(
    id: _id(json['id']),
    contractNumber: _string(json['contract_number']),
    status: StudentContractStatus.fromApi(json['status']),
    course: course is Map<String, dynamic>
        ? ContractCourse(
            id: _int(course['id']),
            slug: _string(course['slug']),
            titleMn: title is Map<String, dynamic>
                ? _string(title['mn'])
                : null,
            titleEn: title is Map<String, dynamic>
                ? _string(title['en'])
                : null,
            level: _string(course['level']),
          )
        : null,
    cohort: cohort is Map<String, dynamic>
        ? ContractCohort(
            id: _int(cohort['id']),
            name: _string(cohort['name']),
            startDate: _time(cohort['start_date']),
            endDate: _time(cohort['end_date']),
          )
        : null,
    createdAt: _time(json['created_at']),
    signedAt: _time(json['signed_at']),
    cancelledAt: _time(json['cancelled_at']),
    canView: json['can_view'] == true,
    canSign: json['can_sign'] == true,
    isCurrent: json['is_current'] == true,
    documentUrl: _string(json['document_url']),
  );
}

String? _string(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

int? _int(Object? raw) => raw is int ? raw : null;

DateTime? _time(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

String? _id(Object? raw) => switch (raw) {
  final int id => '$id',
  final String id when id.isNotEmpty => id,
  _ => null,
};
