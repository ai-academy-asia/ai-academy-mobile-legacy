import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/contracts/data/http_contract_repository.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// `POST /me/contracts/{contract_id}/preview` (Issue #308), against the
/// backend's own source: `routes/contracts.py` answers
/// `Response(pdf, mimetype="application/pdf")`, `student.preview` refuses a
/// signed or cancelled contract with `409`. Test values only; every request
/// goes to a `MockClient` — no backend is reached.
void main() {
  /// A minimal PDF header and trailer — enough to carry the `%PDF`
  /// signature; the client checks only that.
  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7\n%test\n%%EOF\n'));

  const form = ContractForm(
    lastName: 'Тест',
    firstName: 'Сурагч',
    register: 'УБ12345678',
    phone: '00000000',
    email: 'student@example.test',
    address: 'Улаанбаатар',
    finalPaymentDate: '2026-10-20',
  );

  late AuthSessionStore store;
  final requests = <http.Request>[];

  setUp(() {
    store = AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));
    requests.clear();
  });

  HttpContractRepository answering(
    List<int> body, {
    int status = 200,
    String? contentType = 'application/pdf',
  }) => HttpContractRepository(
    client: MockClient((request) async {
      requests.add(request);
      return http.Response.bytes(
        body,
        status,
        headers: {HttpHeaders.contentTypeHeader: ?contentType},
      );
    }),
    sessionStore: store,
  );

  HttpContractRepository answeringError(int status, String code) => answering(
    utf8.encode(jsonEncode({'error': code})),
    status: status,
    contentType: 'application/json',
  );

  Future<ContractFailure> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on ContractFailure catch (failure) {
      return failure;
    }
    fail('expected a ContractFailure');
  }

  test('POSTs exactly {"form": {…}} to …/preview, authenticated, asking for '
      'a PDF', () async {
    await answering(pdf).getContractPreview('12', form: form);

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/me/contracts/12/preview');
    expect(request.headers['Authorization'], 'Bearer tok-123');
    expect(request.headers['Content-Type'], startsWith('application/json'));
    expect(request.headers['Accept'], 'application/pdf');
    expect(jsonDecode(request.body), {
      'form': {
        'last_name': 'Тест',
        'first_name': 'Сурагч',
        'register': 'УБ12345678',
        'guardian_relation': '',
        'guardian_last_name': '',
        'guardian_first_name': '',
        'guardian_register': '',
        'phone': '00000000',
        'email': 'student@example.test',
        'address': 'Улаанбаатар',
        'final_payment_date': '2026-10-20',
      },
    });
  });

  test('encodes the id into the path', () async {
    await answering(pdf).getContractPreview('a/b', form: form);

    expect(requests.single.url.path, '/me/contracts/a%2Fb/preview');
  });

  test('answers the PDF bytes exactly', () async {
    final bytes = await answering(pdf).getContractPreview('12', form: form);

    expect(bytes, pdf);
  });

  test('accepts application/pdf with parameters, in any case', () async {
    for (final type in ['application/pdf; charset=binary', 'Application/PDF']) {
      final bytes = await answering(
        pdf,
        contentType: type,
      ).getContractPreview('12', form: form);
      expect(bytes, pdf, reason: type);
    }
  });

  group('a success that is not a PDF is the server\'s fault', () {
    for (final (name, contentType) in [
      ('application/json', 'application/json'),
      ('text/html', 'text/html; charset=utf-8'),
      ('application/octet-stream', 'application/octet-stream'),
      ('no content type', null),
    ]) {
      test('content type: $name', () async {
        final failure = await failureOf(
          answering(
            pdf,
            contentType: contentType,
          ).getContractPreview('12', form: form),
        );
        expect(failure.kind, ContractFailureKind.server);
      });
    }

    for (final (name, body) in [
      ('HTML', utf8.encode('<html>error</html>')),
      ('JSON', utf8.encode('{"ok": true}')),
      ('a truncated signature', utf8.encode('%PD')),
      ('empty', <int>[]),
      ('the signature not at the start', utf8.encode(' %PDF-1.7')),
    ]) {
      test('body: $name', () async {
        final failure = await failureOf(
          answering(body).getContractPreview('12', form: form),
        );
        expect(failure.kind, ContractFailureKind.server);
      });
    }

    test('the failure names no form value and no PDF content', () async {
      final failure = await failureOf(
        answering(
          utf8.encode('%PDX secret'),
          contentType: 'application/pdf',
        ).getContractPreview('12', form: form),
      );

      final detail = failure.detail ?? '';
      for (final value in [
        ...form.toJson().values.where((v) => v.isNotEmpty),
      ]) {
        expect(detail, isNot(contains(value)), reason: value);
      }
      expect(detail, isNot(contains('secret')));
    });
  });

  group('documented refusals', () {
    for (final (status, code, kind) in [
      (409, 'already_signed', ContractFailureKind.alreadySigned),
      (409, 'contract_cancelled', ContractFailureKind.contractCancelled),
      (409, 'contract_template_missing', ContractFailureKind.templateMissing),
      (409, 'contract_template_invalid', ContractFailureKind.templateInvalid),
      (502, 'storage_error', ContractFailureKind.storageError),
      (404, 'contract_not_found', ContractFailureKind.contractNotFound),
      (403, 'forbidden', ContractFailureKind.forbidden),
    ]) {
      test('$status $code', () async {
        final failure = await failureOf(
          answeringError(status, code).getContractPreview('12', form: form),
        );
        expect(failure.kind, kind);
      });
    }
  });

  group('session and transport', () {
    test('a 401 ends the session', () async {
      final failure = await failureOf(
        answeringError(
          401,
          'token_expired',
        ).getContractPreview('12', form: form),
      );

      expect(failure.kind, ContractFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);
    });

    test('without a session nothing is sent', () async {
      store.clear();

      final failure = await failureOf(
        answering(pdf).getContractPreview('12', form: form),
      );

      expect(failure.kind, ContractFailureKind.sessionExpired);
      expect(requests, isEmpty);
    });

    test('a request that never completes is a network failure', () async {
      final repository = HttpContractRepository(
        client: MockClient((_) async => throw const SocketException('offline')),
        sessionStore: store,
      );

      final failure = await failureOf(
        repository.getContractPreview('12', form: form),
      );
      expect(failure.kind, ContractFailureKind.network);
    });
  });
}
