import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/data/authenticated_client.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/contract_failure.dart';
import '../domain/contract_repository.dart';
import '../domain/student_contract.dart';

/// The student contract list (Issue #294):
///
///     GET /me/contracts
///       -> {"contracts": [...]}
///
/// From the manager's Postman collection (Student → Contracts). The envelope
/// was checked live with an Adult student token, which answered
/// `{"contracts": []}`; no non-empty response has been seen. Each item is
/// read for its `id` alone — the field the collection's test script reads —
/// see [StudentContract].
///
/// **The envelope is required, the items are not inspected further.** A
/// missing `contracts` array, or an entry that is not an object, is the
/// server's fault ([ContractFailureKind.server]). An item without a usable
/// `id` still counts, so the list's length stays the server's.
///
/// The collection's other four contract endpoints — detail, `/preview`,
/// `/sign` and `/download` — are deliberately not called: their responses
/// are not documented (`BACKEND GAP`, see `DATA_AND_API.md`).
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
      contracts.add(StudentContract(id: _id(item['id'])));
    }
    return contracts;
  }
}

String? _id(Object? raw) => switch (raw) {
  final int id => '$id',
  final String id when id.isNotEmpty => id,
  _ => null,
};
