import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/contracts/data/http_contract_repository.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// `GET /me/contracts` (Issue #294). The empty body is the one an Adult
/// student account answered live; the non-empty bodies are test values only
/// — no populated response has been seen. No live backend is called.
void main() {
  late AuthSessionStore store;
  final requests = <http.Request>[];

  setUp(() {
    store = AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));
    requests.clear();
  });

  HttpContractRepository repositoryAnswering(String body, [int status = 200]) =>
      HttpContractRepository(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(
            utf8.encode(body),
            status,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
            },
          );
        }),
        sessionStore: store,
      );

  Future<ContractFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on ContractFailure catch (failure) {
      return failure;
    }
    fail('expected a ContractFailure');
  }

  test('sends an authenticated GET /me/contracts', () async {
    await repositoryAnswering(jsonEncode({'contracts': []})).getContracts();

    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/me/contracts');
    expect(requests.single.headers['Authorization'], 'Bearer tok-123');
  });

  test('the verified empty response is an empty list', () async {
    final contracts = await repositoryAnswering(
      '{"contracts": []}',
    ).getContracts();

    expect(contracts, isEmpty);
  });

  test('reads each item\'s id whether it is a number or a string, and keeps '
      'an item without one', () async {
    final contracts = await repositoryAnswering(
      jsonEncode({
        'contracts': [
          {'id': 12},
          {'id': 'c-7'},
          <String, Object?>{},
        ],
      }),
    ).getContracts();

    expect(contracts.map((c) => c.id), ['12', 'c-7', null]);
  });

  test('a body without the contracts array is a server failure', () async {
    final failure = await failureOf(
      repositoryAnswering('{"items": []}').getContracts(),
    );
    expect(failure.kind, ContractFailureKind.server);
  });

  test('an entry that is not an object is a server failure', () async {
    final failure = await failureOf(
      repositoryAnswering('{"contracts": [3]}').getContracts(),
    );
    expect(failure.kind, ContractFailureKind.server);
  });

  test('malformed JSON is a server failure', () async {
    final failure = await failureOf(
      repositoryAnswering('<html>').getContracts(),
    );
    expect(failure.kind, ContractFailureKind.server);
  });

  test('a 5xx is a server failure', () async {
    final failure = await failureOf(
      repositoryAnswering('{}', 502).getContracts(),
    );
    expect(failure.kind, ContractFailureKind.server);
  });

  test('a 403 or 404 is unexpected — neither is documented here', () async {
    for (final status in [403, 404]) {
      final failure = await failureOf(
        repositoryAnswering('{}', status).getContracts(),
      );
      expect(failure.kind, ContractFailureKind.unexpected, reason: '$status');
    }
  });

  test('a 401 ends the session', () async {
    final failure = await failureOf(
      repositoryAnswering('{}', 401).getContracts(),
    );

    expect(failure.kind, ContractFailureKind.sessionExpired);
    expect(store.isSignedIn, isFalse);
  });

  test('without a session nothing is sent', () async {
    store.clear();

    final failure = await failureOf(
      repositoryAnswering('{"contracts": []}').getContracts(),
    );

    expect(failure.kind, ContractFailureKind.sessionExpired);
    expect(requests, isEmpty);
  });

  test('a request that never completes is a network failure', () async {
    final repository = HttpContractRepository(
      client: MockClient((_) async => throw const SocketException('offline')),
      sessionStore: store,
    );

    final failure = await failureOf(repository.getContracts());
    expect(failure.kind, ContractFailureKind.network);
  });
}
