import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aia_mobile/features/auth/domain/auth_session.dart';
import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/contracts/data/http_contract_repository.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Contract detail, sign and download (Issue #302), against the shapes the
/// backend's own source documents and asserts (`ai-academy-backend`
/// `docs/e_contract_api_v1.md`, `tests/test_contracts_*.py`) — with test
/// values only. **Not live-verified**, and nothing here reaches a backend:
/// every request goes to a `MockClient`. `/sign` is never sent anywhere real.
void main() {
  /// A pending contract's detail, as `student._detail` builds it.
  Map<String, Object?> pendingDetail() => {
    'id': 12,
    'contract_number': 'TEST-C-0012',
    'status': 'pending',
    'enrollment_id': 40,
    'course_id': 9,
    'course': {
      'id': 9,
      'slug': 'test-course',
      'title': {'mn': 'Тест', 'en': 'Test'},
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
    'form': <String, Object?>{
      'last_name': 'Тест',
      'first_name': 'Сурагч',
      'register': '',
      'phone': '00000000',
      'email': 'student@example.test',
      'address': '',
      'guardian_relation': '',
      'guardian_last_name': '',
      'guardian_first_name': '',
      'guardian_register': '',
      'final_payment_date': '',
    },
    'rules': <String, Object?>{
      'guardian_required': false,
      'final_payment_date_required': true,
      'final_payment_date_min': '2026-10-08',
      'final_payment_date_max': '2026-10-30',
    },
    'finance': <String, Object?>{
      'total_due': 1000000.0,
      'total_paid': 400000.0,
      'balance': 600000.0,
      'discount_percent': 0,
      'currency': 'MNT',
    },
    'document': <String, Object?>{
      'format': 'pdf',
      'preview': '/me/contracts/12/preview',
      'download': null,
    },
  };

  /// The same contract once signed — what `POST …/sign` answers.
  Map<String, Object?> signedDetail() => {
    ...pendingDetail(),
    'status': 'signed',
    'signed_at': '2026-10-09T02:30:00+00:00',
    'can_sign': false,
    'document_url': '/me/contracts/12/download',
    'document': <String, Object?>{
      'format': 'pdf',
      'preview': null,
      'download': '/me/contracts/12/download',
    },
  };

  late AuthSessionStore store;
  final requests = <http.Request>[];

  setUp(() {
    store = AuthSessionStore()..save(const AuthSession(accessToken: 'tok-123'));
    requests.clear();
  });

  HttpContractRepository answering(Object? body, [int status = 200]) =>
      HttpContractRepository(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(
            utf8.encode(body is String ? body : jsonEncode(body)),
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

  group('getContractDetail', () {
    test('sends an authenticated GET /me/contracts/{id}', () async {
      await answering(pendingDetail()).getContractDetail('12');

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/me/contracts/12');
      expect(requests.single.headers['Authorization'], 'Bearer tok-123');
    });

    test('reads the summary and every documented part', () async {
      final detail = await answering(pendingDetail()).getContractDetail('12');

      expect(detail.contract.id, '12');
      expect(detail.contract.status, StudentContractStatus.pending);
      expect(detail.contract.canSign, isTrue);
      expect(detail.contract.course?.slug, 'test-course');

      expect(detail.form.lastName, 'Тест');
      expect(detail.form.firstName, 'Сурагч');
      expect(detail.form.phone, '00000000');
      expect(detail.form.email, 'student@example.test');
      expect(detail.form.register, isEmpty);
      expect(detail.form.address, isEmpty);
      expect(detail.form.finalPaymentDate, isEmpty);

      expect(detail.rules.guardianRequired, isFalse);
      expect(detail.rules.finalPaymentDateRequired, isTrue);
      expect(detail.rules.finalPaymentDateMin, DateTime(2026, 10, 8));
      expect(detail.rules.finalPaymentDateMax, DateTime(2026, 10, 30));

      expect(detail.finance.totalDue, 1000000.0);
      expect(detail.finance.totalPaid, 400000.0);
      expect(detail.finance.balance, 600000.0);
      expect(detail.finance.discountPercent, 0);
      expect(detail.finance.currency, 'MNT');

      expect(detail.document.format, 'pdf');
      expect(detail.document.preview, '/me/contracts/12/preview');
      expect(detail.document.download, isNull);
    });

    test('a null final_payment_date_max is no upper bound', () async {
      final body = pendingDetail();
      (body['rules']! as Map)['final_payment_date_max'] = null;

      final detail = await answering(body).getContractDetail('12');

      expect(detail.rules.finalPaymentDateMax, isNull);
    });

    test('whole-number amounts sent as integers are read as numbers', () async {
      final body = pendingDetail();
      body['finance'] = {
        'total_due': 1000000,
        'total_paid': 0,
        'balance': 1000000,
        'discount_percent': 20.0,
        'currency': 'MNT',
      };

      final finance = (await answering(body).getContractDetail('12')).finance;

      expect(finance.totalDue, 1000000.0);
      expect(finance.discountPercent, 20);
    });

    test('encodes the id into the path', () async {
      await answering(pendingDetail()).getContractDetail('a/b');

      expect(requests.single.url.path, '/me/contracts/a%2Fb');
    });

    group('a missing or mistyped required part is the server\'s fault', () {
      final cases = <String, void Function(Map<String, Object?>)>{
        'no form': (b) => b.remove('form'),
        'no rules': (b) => b.remove('rules'),
        'no finance': (b) => b.remove('finance'),
        'no document': (b) => b['document'] = 'pdf',
        'a form field missing': (b) => (b['form']! as Map).remove('register'),
        'a form field not a string': (b) => (b['form']! as Map)['phone'] = 0,
        'a rule not a bool': (b) =>
            (b['rules']! as Map)['guardian_required'] = 'no',
        'a min date not a date': (b) =>
            (b['rules']! as Map)['final_payment_date_min'] = '2026/10/08',
        'a max date not a date': (b) =>
            (b['rules']! as Map)['final_payment_date_max'] = 'soon',
        'an amount not a number': (b) =>
            (b['finance']! as Map)['balance'] = '600000',
        'a fractional discount': (b) =>
            (b['finance']! as Map)['discount_percent'] = 12.5,
        'no currency': (b) => (b['finance']! as Map).remove('currency'),
        'no document format': (b) => (b['document']! as Map).remove('format'),
        'a preview path not a string': (b) =>
            (b['document']! as Map)['preview'] = 1,
      };
      for (final MapEntry(key: name, value: corrupt) in cases.entries) {
        test(name, () async {
          final body = pendingDetail();
          corrupt(body);

          final failure = await failureOf(
            answering(body).getContractDetail('12'),
          );

          expect(failure.kind, ContractFailureKind.server, reason: name);
        });
      }

      test('a body that is not an object', () async {
        final failure = await failureOf(
          answering('[]').getContractDetail('12'),
        );
        expect(failure.kind, ContractFailureKind.server);
      });
    });
  });

  group('signContract', () {
    const form = ContractForm(
      lastName: 'Тест',
      firstName: 'Сурагч',
      register: 'АА00000000',
      phone: '00000000',
      email: 'student@example.test',
      address: 'Тест хаяг',
      finalPaymentDate: '2026-10-20',
    );
    const signature = 'data:image/png;base64,iVBORw0KGgo=';

    test('POSTs exactly {form, agreed, signature} to …/sign', () async {
      await answering(
        signedDetail(),
      ).signContract('12', form: form, agreed: true, signature: signature);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/me/contracts/12/sign');
      expect(request.headers['Authorization'], 'Bearer tok-123');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {
        'form': <String, Object?>{
          'last_name': 'Тест',
          'first_name': 'Сурагч',
          'register': 'АА00000000',
          'phone': '00000000',
          'email': 'student@example.test',
          'address': 'Тест хаяг',
          'guardian_relation': '',
          'guardian_last_name': '',
          'guardian_first_name': '',
          'guardian_register': '',
          'final_payment_date': '2026-10-20',
        },
        'agreed': true,
        'signature': signature,
      });
    });

    test('sends agreed as given — never assumed', () async {
      await answering(
        signedDetail(),
      ).signContract('12', form: form, agreed: false, signature: signature);

      expect(jsonDecode(requests.single.body)['agreed'], isFalse);
    });

    test('a bare base64 signature is sent untouched', () async {
      await answering(
        signedDetail(),
      ).signContract('12', form: form, agreed: true, signature: 'iVBORw0KGgo=');

      expect(jsonDecode(requests.single.body)['signature'], 'iVBORw0KGgo=');
    });

    test('reads the signed detail', () async {
      final detail = await answering(
        signedDetail(),
      ).signContract('12', form: form, agreed: true, signature: signature);

      expect(detail.contract.status, StudentContractStatus.signed);
      expect(detail.contract.signedAt, DateTime.utc(2026, 10, 9, 2, 30));
      expect(detail.contract.documentUrl, '/me/contracts/12/download');
      expect(detail.document.preview, isNull);
      expect(detail.document.download, '/me/contracts/12/download');
    });

    test('signatureDataUrl wraps PNG bytes as the data URL', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

      expect(signatureDataUrl(png), 'data:image/png;base64,iVBORw==');
    });

    test('invalid_fields carries each field\'s reason', () async {
      final failure = await failureOf(
        answering(
          {
            'error': 'invalid_fields',
            'fields': {
              'register': 'invalid_format',
              'address': 'required',
              'last_name': 'cyrillic_only',
              'email': 'too_long',
              'final_payment_date': 'out_of_range',
              'phone': 'something_new',
            },
          },
          400,
        ).signContract('12', form: form, agreed: true, signature: signature),
      );

      expect(failure.kind, ContractFailureKind.invalidFields);
      expect(failure.fieldErrors, {
        'register': ContractFieldReason.invalidFormat,
        'address': ContractFieldReason.required,
        'last_name': ContractFieldReason.cyrillicOnly,
        'email': ContractFieldReason.tooLong,
        'final_payment_date': ContractFieldReason.outOfRange,
        'phone': ContractFieldReason.unknown,
      });
    });
  });

  group('getContractDownload', () {
    test('GETs …/download and reads {url, expires_at}', () async {
      final download = await answering({
        'url': 'https://files.example.test/contract.pdf?sig=x',
        'expires_at': '2026-10-09T02:35:00+00:00',
      }).getContractDownload('12');

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/me/contracts/12/download');
      expect(
        download.url,
        Uri.parse('https://files.example.test/contract.pdf?sig=x'),
      );
      expect(download.expiresAt, DateTime.utc(2026, 10, 9, 2, 35));
    });

    for (final (name, body) in [
      ('no url', {'expires_at': '2026-10-09T02:35:00+00:00'}),
      (
        'a url that is not http(s)',
        {'url': 'file:///x.pdf', 'expires_at': '2026-10-09T02:35:00+00:00'},
      ),
      ('no expires_at', {'url': 'https://files.example.test/c.pdf'}),
      (
        'an expires_at that is not a timestamp',
        {'url': 'https://files.example.test/c.pdf', 'expires_at': 'soon'},
      ),
    ]) {
      test('$name is the server\'s fault', () async {
        final failure = await failureOf(
          answering(body).getContractDownload('12'),
        );
        expect(failure.kind, ContractFailureKind.server);
      });
    }

    test('409 not_signed before signing', () async {
      final failure = await failureOf(
        answering({'error': 'not_signed'}, 409).getContractDownload('12'),
      );
      expect(failure.kind, ContractFailureKind.notSigned);
    });
  });

  group('documented error codes', () {
    for (final (status, code, kind) in [
      (400, 'agreement_required', ContractFailureKind.agreementRequired),
      (400, 'signature_required', ContractFailureKind.signatureRequired),
      (400, 'invalid_signature', ContractFailureKind.invalidSignature),
      (400, 'empty_signature', ContractFailureKind.emptySignature),
      (413, 'signature_too_large', ContractFailureKind.signatureTooLarge),
      (403, 'forbidden', ContractFailureKind.forbidden),
      (404, 'contract_not_found', ContractFailureKind.contractNotFound),
      (409, 'already_signed', ContractFailureKind.alreadySigned),
      (409, 'contract_cancelled', ContractFailureKind.contractCancelled),
      (409, 'contract_template_missing', ContractFailureKind.templateMissing),
      (409, 'contract_template_invalid', ContractFailureKind.templateInvalid),
      (409, 'not_signed', ContractFailureKind.notSigned),
      (502, 'storage_error', ContractFailureKind.storageError),
    ]) {
      test('$status $code', () async {
        final failure = await failureOf(
          answering({'error': code}, status).getContractDetail('12'),
        );
        expect(failure.kind, kind);
        expect(failure.fieldErrors, isEmpty);
      });
    }

    test('a code under a status it is not documented for reads by status', () {
      expect(
        contractFailureFor(409, '{"error": "contract_not_found"}').kind,
        ContractFailureKind.unexpected,
      );
      expect(
        contractFailureFor(503, '{"error": "storage_error"}').kind,
        ContractFailureKind.server,
      );
    });

    test('an unknown code, or no body, reads by status', () {
      expect(
        contractFailureFor(409, '{"error": "something_new"}').kind,
        ContractFailureKind.unexpected,
      );
      expect(contractFailureFor(500, '').kind, ContractFailureKind.server);
      expect(
        contractFailureFor(404, '<html>').kind,
        ContractFailureKind.unexpected,
      );
    });

    test('invalid_fields without a fields map has no field reasons', () {
      final failure = contractFailureFor(400, '{"error": "invalid_fields"}');

      expect(failure.kind, ContractFailureKind.invalidFields);
      expect(failure.fieldErrors, isEmpty);
    });
  });

  group('session and transport, as the list has them', () {
    test('a 401 ends the session', () async {
      final failure = await failureOf(
        answering({'error': 'token_expired'}, 401).getContractDetail('12'),
      );

      expect(failure.kind, ContractFailureKind.sessionExpired);
      expect(store.isSignedIn, isFalse);
    });

    test('without a session nothing is sent — sign included', () async {
      store.clear();
      final repository = answering(signedDetail());

      for (final call in <Future<Object?> Function()>[
        () => repository.getContractDetail('12'),
        () => repository.signContract(
          '12',
          form: const ContractForm(),
          agreed: true,
          signature: 'x',
        ),
        () => repository.getContractDownload('12'),
      ]) {
        expect(
          (await failureOf(call())).kind,
          ContractFailureKind.sessionExpired,
        );
      }
      expect(requests, isEmpty);
    });

    test('a request that never completes is a network failure', () async {
      final repository = HttpContractRepository(
        client: MockClient((_) async => throw const SocketException('offline')),
        sessionStore: store,
      );

      final failure = await failureOf(
        repository.signContract(
          '12',
          form: const ContractForm(),
          agreed: true,
          signature: 'x',
        ),
      );
      expect(failure.kind, ContractFailureKind.network);
    });
  });
}
