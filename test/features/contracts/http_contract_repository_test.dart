import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/contracts/data/http_contract_repository.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// `GET /me/contracts` (Issues #294, #300). The empty body is the one an
/// Adult student account answered live. The non-empty bodies follow the
/// backend's documented item shape (`ai-academy-backend`
/// `docs/e_contract_api_v1.md`) with test values — no populated response has
/// been seen. No live backend is called.
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

  group('the documented item (Issue #300)', () {
    /// The backend doc's example item, with test values.
    const documented = {
      'id': 12,
      'contract_number': 'TEST-C-0012',
      'status': 'pending',
      'enrollment_id': 40,
      'course_id': 9,
      'course': {
        'id': 9,
        'slug': 'test-course',
        'title': {'mn': 'Тест курс', 'en': 'Test course'},
        'level': 'adult',
      },
      'cohort': {
        'id': 3,
        'name': 'Test Cohort',
        'start_date': '2026-08-06',
        'end_date': '2026-10-30',
      },
      'created_at': '2026-10-08T07:00:00+00:00',
      'signed_at': null,
      'cancelled_at': null,
      'can_view': true,
      'can_sign': true,
      'is_current': true,
      'document_url': null,
    };

    test('reads every documented field', () async {
      final contract = (await repositoryAnswering(
        jsonEncode({
          'contracts': [documented],
        }),
      ).getContracts()).single;

      expect(contract.id, '12');
      expect(contract.contractNumber, 'TEST-C-0012');
      expect(contract.status, StudentContractStatus.pending);
      expect(contract.course?.id, 9);
      expect(contract.course?.slug, 'test-course');
      expect(contract.course?.titleMn, 'Тест курс');
      expect(contract.course?.titleEn, 'Test course');
      expect(contract.course?.level, 'adult');
      expect(contract.cohort?.id, 3);
      expect(contract.cohort?.name, 'Test Cohort');
      expect(contract.cohort?.startDate, DateTime(2026, 8, 6));
      expect(contract.cohort?.endDate, DateTime(2026, 10, 30));
      expect(contract.createdAt, DateTime.utc(2026, 10, 8, 7));
      expect(contract.signedAt, isNull);
      expect(contract.cancelledAt, isNull);
      expect(contract.canView, isTrue);
      expect(contract.canSign, isTrue);
      expect(contract.isCurrent, isTrue);
      expect(contract.documentUrl, isNull);
    });

    test('a signed contract carries its date and download path', () async {
      final contract = (await repositoryAnswering(
        jsonEncode({
          'contracts': [
            {
              ...documented,
              'status': 'signed',
              'signed_at': '2026-10-09T02:30:00+00:00',
              'can_sign': false,
              'document_url': '/me/contracts/12/download',
            },
          ],
        }),
      ).getContracts()).single;

      expect(contract.status, StudentContractStatus.signed);
      expect(contract.signedAt, DateTime.utc(2026, 10, 9, 2, 30));
      expect(contract.canSign, isFalse);
      expect(contract.documentUrl, '/me/contracts/12/download');
    });

    test('maps the three documented statuses, and anything else to '
        'unknown', () {
      expect(
        StudentContractStatus.fromApi('pending'),
        StudentContractStatus.pending,
      );
      expect(
        StudentContractStatus.fromApi('signed'),
        StudentContractStatus.signed,
      );
      expect(
        StudentContractStatus.fromApi('cancelled'),
        StudentContractStatus.cancelled,
      );
      for (final other in ['expired', 'SIGNED', '', null, 1]) {
        expect(
          StudentContractStatus.fromApi(other),
          StudentContractStatus.unknown,
          reason: '$other',
        );
      }
    });

    test('mistyped or missing fields read as null or false, and never fail '
        'the list', () async {
      final contracts = await repositoryAnswering(
        jsonEncode({
          'contracts': [
            {
              'id': 12,
              'contract_number': 7,
              'status': 3,
              'course': 'test-course',
              'cohort': {'id': '3', 'start_date': 'soon'},
              'created_at': 'yesterday',
              'can_view': 'true',
              'can_sign': 1,
              'is_current': null,
              'document_url': false,
            },
            <String, Object?>{},
          ],
        }),
      ).getContracts();

      expect(contracts, hasLength(2));
      final odd = contracts.first;
      expect(odd.contractNumber, isNull);
      expect(odd.status, StudentContractStatus.unknown);
      expect(odd.course, isNull);
      expect(odd.cohort?.id, isNull);
      expect(odd.cohort?.startDate, isNull);
      expect(odd.createdAt, isNull);
      expect(odd.canView, isFalse);
      expect(odd.canSign, isFalse);
      expect(odd.isCurrent, isFalse);
      expect(odd.documentUrl, isNull);

      final empty = contracts.last;
      expect(empty.status, StudentContractStatus.unknown);
      expect(empty.canSign, isFalse);
      expect(empty.isCurrent, isFalse);
    });
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
