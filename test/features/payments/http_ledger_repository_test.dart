import 'dart:convert';
import 'dart:io';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/payments/data/http_ledger_repository.dart';
import 'package:aia_mobile/features/payments/domain/ledger_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Exercises the wire format against the verified production response for
/// the adult test account — [verifiedBody], verbatim:
///
///     GET https://api.ai-academy.asia/me/ledger
///     -> {"enrollments": [ { "enrollment_id": 2, "cohort": {"id": 1, …},
///                            "balance": 0.0, "next_due_date": null,
///                            "installments": [], … } ]}
void main() {
  /// The production body, exactly as the backend returned it.
  const verifiedBody = '''
{
  "enrollments": [
    {
      "balance": 0.0,
      "cohort": {
        "end_date": "2026-10-06",
        "id": 1,
        "name": "Corporate Leaders 2026-08",
        "start_date": "2026-08-06"
      },
      "course": {
        "id": 6,
        "slug": "summer-bootcamp-2027",
        "title": {
          "en": "Summer Bootcamp",
          "mn": "Зуны бүтээлч кэмп"
        }
      },
      "currency": "MNT",
      "enrollment_id": 2,
      "installments": [],
      "next_due_date": null,
      "status": "active",
      "total_due": 0.0,
      "total_paid": 0.0
    }
  ]
}
''';

  /// The verified body's single entry, decoded, for a test that changes one
  /// field of it.
  Map<String, dynamic> verifiedEntry() =>
      ((jsonDecode(verifiedBody) as Map<String, dynamic>)['enrollments']
                  as List)
              .single
          as Map<String, dynamic>;

  /// The real envelope around [entries].
  String bodyOf(List<Object?> entries) => jsonEncode({'enrollments': entries});

  /// Never the app-wide store: a test must not read a token another test
  /// left.
  AuthSessionStore signedIn() =>
      AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));

  HttpLedgerRepository repositoryReturning(
    Future<http.Response> Function(http.Request request) handler, {
    AuthSessionStore? sessionStore,
  }) => HttpLedgerRepository(
    client: MockClient(handler),
    sessionStore: sessionStore ?? signedIn(),
  );

  /// `http.Response`'s String constructor encodes latin-1; the verified body
  /// carries Mongolian text, so it goes out as UTF-8 bytes, as the API sends.
  http.Response ok(String body) => http.Response.bytes(
    utf8.encode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<LedgerFailure> failureFrom(HttpLedgerRepository repository) async {
    try {
      await repository.getLedger();
    } on LedgerFailure catch (failure) {
      return failure;
    }
    fail('expected a LedgerFailure');
  }

  group('the request', () {
    test('GETs /me/ledger with the bearer token', () async {
      late http.Request sent;
      final repository = repositoryReturning((request) async {
        sent = request;
        return ok(verifiedBody);
      });

      await repository.getLedger();

      expect(sent.method, 'GET');
      expect(sent.url.toString(), 'https://api.ai-academy.asia/me/ledger');
      expect(sent.headers[HttpHeaders.authorizationHeader], 'Bearer tok-123');
    });

    test('no session: sends nothing', () async {
      var requests = 0;
      final repository = repositoryReturning((_) async {
        requests++;
        return ok(verifiedBody);
      }, sessionStore: AuthSessionStore());

      final failure = await failureFrom(repository);

      expect(failure.kind, LedgerFailureKind.sessionExpired);
      expect(requests, 0);
    });
  });

  group('the verified response', () {
    test('parses the adult test account\'s ledger verbatim', () async {
      final repository = repositoryReturning((_) async => ok(verifiedBody));

      final entries = await repository.getLedger();

      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.enrollmentId, 2);
      // Nested under `cohort`, not a top-level `cohort_id`.
      expect(entry.cohortId, 1);
      expect(entry.balance, 0);
      expect(entry.nextDueDate, isNull);
    });

    test('empty installments is not a failure', () async {
      // The verified body itself carries `"installments": []`.
      final repository = repositoryReturning((_) async => ok(verifiedBody));

      expect(await repository.getLedger(), hasLength(1));
    });

    test('installment entries are not read, whatever they carry', () async {
      final entry = verifiedEntry()
        ..['installments'] = [
          {'anything': true},
        ];
      final repository = repositoryReturning((_) async => ok(bodyOf([entry])));

      expect(await repository.getLedger(), hasLength(1));
    });

    test('no enrollments: an empty ledger', () async {
      final repository = repositoryReturning((_) async => ok(bodyOf([])));

      expect(await repository.getLedger(), isEmpty);
    });

    test('reads every enrollment, each with its own cohort', () async {
      final second = verifiedEntry()
        ..['enrollment_id'] = 3
        ..['cohort'] = {'id': 4};
      final repository = repositoryReturning(
        (_) async => ok(bodyOf([verifiedEntry(), second])),
      );

      final entries = await repository.getLedger();

      expect(entries.map((e) => e.enrollmentId), [2, 3]);
      expect(entries.map((e) => e.cohortId), [1, 4]);
    });

    test('reads a balance and next_due_date as a calendar date', () async {
      final entry = verifiedEntry()
        ..['balance'] = 150000.0
        ..['next_due_date'] = '2026-10-01';
      final repository = repositoryReturning((_) async => ok(bodyOf([entry])));

      final parsed = (await repository.getLedger()).single;

      expect(parsed.balance, 150000);
      expect(parsed.nextDueDate, DateTime(2026, 10, 1));
    });
  });

  group('failures', () {
    Future<void> expectServerFailure(Object? body) async {
      final repository = repositoryReturning(
        (_) async => ok(body is String ? body : jsonEncode(body)),
      );
      expect((await failureFrom(repository)).kind, LedgerFailureKind.server);
    }

    test(
      'a body without the enrollments list fails loudly as server',
      () async {
        // Neither a bare list nor a bare entry is the verified shape.
        await expectServerFailure([verifiedEntry()]);
        await expectServerFailure(verifiedEntry());
        await expectServerFailure({'enrollments': null});
      },
    );

    test('malformed JSON fails as server', () async {
      await expectServerFailure('{not json');
    });

    test('an entry without its cohort object fails as server', () async {
      await expectServerFailure({
        'enrollments': [verifiedEntry()..remove('cohort')],
      });
      await expectServerFailure({
        'enrollments': [verifiedEntry()..['cohort'] = 1],
      });
    });

    test('a top-level cohort_id does not stand in for cohort.id', () async {
      await expectServerFailure({
        'enrollments': [
          verifiedEntry()
            ..remove('cohort')
            ..['cohort_id'] = 1,
        ],
      });
    });

    test('a missing or non-numeric balance fails as server', () async {
      await expectServerFailure({
        'enrollments': [verifiedEntry()..remove('balance')],
      });
      await expectServerFailure({
        'enrollments': [verifiedEntry()..['balance'] = '0.0'],
      });
    });

    test('a next_due_date that is not a date fails as server', () async {
      await expectServerFailure({
        'enrollments': [verifiedEntry()..['next_due_date'] = 'soon'],
      });
    });

    test('401 is a dead session, and forgets it', () async {
      final store = signedIn();
      final repository = repositoryReturning(
        (_) async => http.Response('{"error":"token_expired"}', 401),
        sessionStore: store,
      );

      final failure = await failureFrom(repository);

      expect(failure.kind, LedgerFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);
    });

    test('maps the other statuses', () async {
      const expected = {
        403: LedgerFailureKind.rejected,
        404: LedgerFailureKind.rejected,
        500: LedgerFailureKind.server,
        503: LedgerFailureKind.server,
      };
      for (final entry in expected.entries) {
        final repository = repositoryReturning(
          (_) async => http.Response('{}', entry.key),
        );
        expect(
          (await failureFrom(repository)).kind,
          entry.value,
          reason: 'HTTP ${entry.key}',
        );
      }
    });

    test('a request that never completes is a network failure', () async {
      final repository = repositoryReturning(
        (_) async => throw const SocketException('offline'),
      );

      expect((await failureFrom(repository)).kind, LedgerFailureKind.network);
    });
  });
}
