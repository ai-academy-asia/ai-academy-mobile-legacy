import 'dart:async';
import 'dart:typed_data';

import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_signing_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_contract_repository.dart';

/// The E-Contract signing logic (Issue #306), against a hand-driven fake —
/// no backend is reached, and every attempt that must be blocked is checked
/// to have sent no sign request. Test values only.
void main() {
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

  final rules = ContractRules(
    guardianRequired: false,
    finalPaymentDateRequired: false,
    finalPaymentDateMin: DateTime(2026, 10, 10),
    finalPaymentDateMax: DateTime(2026, 10, 30),
  );

  const finance = ContractFinance(
    totalDue: 1000000,
    totalPaid: 1000000,
    balance: 0,
    discountPercent: 0,
    currency: 'MNT',
  );

  /// A pending, signable contract whose prefilled form lacks register and
  /// address — as the backend prefills it.
  ContractDetail pending({ContractForm? form}) => ContractDetail(
    contract: const StudentContract(
      id: '12',
      status: StudentContractStatus.pending,
      canSign: true,
      canView: true,
      isCurrent: true,
    ),
    form:
        form ??
        const ContractForm(
          lastName: 'Тест',
          firstName: 'Сурагч',
          phone: '00000000',
          email: 'student@example.test',
        ),
    rules: rules,
    finance: finance,
    document: const ContractDocument(
      format: 'pdf',
      preview: '/me/contracts/12/preview',
    ),
  );

  final signedDetail = ContractDetail(
    contract: StudentContract(
      id: '12',
      status: StudentContractStatus.signed,
      canView: true,
      isCurrent: true,
      signedAt: DateTime.utc(2026, 10, 11, 3),
      documentUrl: '/me/contracts/12/download',
    ),
    form: const ContractForm(
      lastName: 'Тест',
      firstName: 'Сурагч',
      register: 'УБ12345678',
      phone: '00000000',
      address: 'Улаанбаатар',
    ),
    rules: rules,
    finance: finance,
    document: const ContractDocument(
      format: 'pdf',
      download: '/me/contracts/12/download',
    ),
  );

  late FakeContractRepository repository;
  late List<Uri> opened;
  late bool openSucceeds;
  late ContractSigningController controller;

  setUp(() {
    repository = FakeContractRepository(detail: pending());
    opened = [];
    openSucceeds = true;
    controller = ContractSigningController(
      contractId: '12',
      repository: repository,
      openUrl: (url) async {
        opened.add(url);
        return openSucceeds;
      },
    );
  });

  tearDown(() => controller.dispose());

  /// Loads, then fills the two fields the backend never prefills.
  Future<void> loadAndComplete() async {
    await controller.load();
    controller
      ..updateField(ContractFormField.register, 'уб12345678')
      ..updateField(ContractFormField.address, ' Улаанбаатар ');
  }

  group('load', () {
    test('loads the detail and starts the form from it', () async {
      expect(controller.hasLoadedOnce, isFalse);

      final loading = controller.load();
      expect(controller.loading, isTrue);
      await loading;

      expect(controller.loading, isFalse);
      expect(controller.detail?.contract.id, '12');
      expect(controller.form.lastName, 'Тест');
      expect(controller.canSign, isTrue);
      expect(repository.detailCalls, ['12']);
    });

    test('a failure is kept whole, and retry loads again', () async {
      repository.detailFailure = const ContractFailure(
        ContractFailureKind.network,
        detail: 'offline',
      );
      await controller.load();

      expect(controller.detail, isNull);
      expect(controller.loadFailure?.kind, ContractFailureKind.network);
      expect(controller.loadFailure?.detail, 'offline');
      expect(controller.canSign, isFalse);

      repository.detailFailure = null;
      await controller.load();

      expect(controller.loadFailure, isNull);
      expect(controller.detail, isNotNull);
      expect(repository.detailCalls, ['12', '12']);
    });

    test('a signed contract cannot be signed', () async {
      repository.detail = signedDetail;
      await controller.load();

      expect(controller.canSign, isFalse);
    });
  });

  group('editing', () {
    test('the prefilled form misses register and address', () async {
      await controller.load();

      expect(controller.fieldErrors, {
        ContractFormField.register: ContractFieldReason.required,
        ContractFormField.address: ContractFieldReason.required,
      });
    });

    test('an edit is revalidated', () async {
      await controller.load();

      controller.updateField(ContractFormField.register, 'AB1');
      expect(
        controller.errorFor(ContractFormField.register),
        ContractFieldReason.invalidFormat,
      );

      controller.updateField(ContractFormField.register, 'АБ12345678');
      expect(controller.errorFor(ContractFormField.register), isNull);
    });

    test('an edit notifies listeners', () async {
      await controller.load();
      var notified = 0;
      controller.addListener(() => notified++);

      controller.updateField(ContractFormField.address, 'Улаанбаатар');

      expect(notified, 1);
      expect(controller.form.address, 'Улаанбаатар');
    });
  });

  group('sign — blocked locally, nothing sent', () {
    test('before the detail is loaded', () async {
      expect(
        await controller.sign(png, agreed: true),
        ContractSignResult.notSignable,
      );
      expect(repository.signCalls, isEmpty);
    });

    test('when the contract cannot be signed', () async {
      repository.detail = signedDetail;
      await controller.load();

      expect(
        await controller.sign(png, agreed: true),
        ContractSignResult.notSignable,
      );
      expect(repository.signCalls, isEmpty);
    });

    test('when the form is invalid', () async {
      await controller.load();

      expect(
        await controller.sign(png, agreed: true),
        ContractSignResult.invalidForm,
      );
      expect(repository.signCalls, isEmpty);
    });

    test('when the signature is empty or missing', () async {
      await loadAndComplete();

      expect(
        await controller.sign(null, agreed: true),
        ContractSignResult.emptySignature,
      );
      expect(
        await controller.sign(Uint8List(0), agreed: true),
        ContractSignResult.emptySignature,
      );
      expect(repository.signCalls, isEmpty);
    });

    test('when the student has not agreed', () async {
      await loadAndComplete();

      expect(
        await controller.sign(png, agreed: false),
        ContractSignResult.notAgreed,
      );
      expect(repository.signCalls, isEmpty);
    });

    test('while another sign is in flight — one request only', () async {
      await loadAndComplete();
      repository
        ..signed = signedDetail
        ..signGate = Completer<void>();

      final first = controller.sign(png, agreed: true);
      expect(controller.signing, isTrue);
      expect(
        await controller.sign(png, agreed: true),
        ContractSignResult.inProgress,
      );

      repository.signGate!.complete();
      expect(await first, ContractSignResult.signed);
      expect(repository.signCalls, hasLength(1));
      expect(controller.signing, isFalse);
    });
  });

  group('sign — sent', () {
    test('sends the normalised form, agreed and the PNG data URL, and '
        'adopts the signed detail', () async {
      await loadAndComplete();
      repository.signed = signedDetail;

      expect(
        await controller.sign(png, agreed: true),
        ContractSignResult.signed,
      );

      final call = repository.signCalls.single;
      expect(call.id, '12');
      expect(call.agreed, isTrue);
      expect(call.signature, signatureDataUrl(png));
      expect(call.form.register, 'УБ12345678');
      expect(call.form.address, 'Улаанбаатар');

      expect(controller.detail?.contract.status, StudentContractStatus.signed);
      expect(controller.detail?.contract.signedAt, isNotNull);
      expect(controller.canSign, isFalse);
      expect(controller.signFailure, isNull);
    });

    test('invalid_fields reasons land on their fields and win over the '
        'client\'s; unknown keys are kept', () async {
      await loadAndComplete();
      repository.signFailure = const ContractFailure(
        ContractFailureKind.invalidFields,
        detail: 'HTTP 400 invalid_fields',
        fieldErrors: {
          'register': ContractFieldReason.invalidFormat,
          'final_payment_date': ContractFieldReason.outOfRange,
          'something_new': ContractFieldReason.required,
        },
      );

      expect(
        await controller.sign(png, agreed: true),
        ContractSignResult.failed,
      );

      expect(controller.signFailure?.kind, ContractFailureKind.invalidFields);
      expect(
        controller.errorFor(ContractFormField.register),
        ContractFieldReason.invalidFormat,
      );
      expect(
        controller.errorFor(ContractFormField.finalPaymentDate),
        ContractFieldReason.outOfRange,
      );
      expect(controller.unmatchedServerErrors, {
        'something_new': ContractFieldReason.required,
      });
    });

    test('editing a field drops its server reason', () async {
      await loadAndComplete();
      repository.signFailure = const ContractFailure(
        ContractFailureKind.invalidFields,
        fieldErrors: {'register': ContractFieldReason.invalidFormat},
      );
      await controller.sign(png, agreed: true);

      controller.updateField(ContractFormField.register, 'УБ87654321');

      expect(controller.errorFor(ContractFormField.register), isNull);
    });

    test('already_signed reloads the detail and shows it signed', () async {
      await loadAndComplete();
      repository.signFailure = const ContractFailure(
        ContractFailureKind.alreadySigned,
        detail: 'HTTP 409 already_signed',
      );
      repository.detail = signedDetail;

      expect(
        await controller.sign(png, agreed: true),
        ContractSignResult.failed,
      );

      expect(controller.signFailure?.kind, ContractFailureKind.alreadySigned);
      expect(repository.detailCalls, ['12', '12']);
      expect(controller.detail?.contract.status, StudentContractStatus.signed);
      expect(controller.canSign, isFalse);
      expect(controller.signing, isFalse);
    });

    test('while already_signed reloads, a second sign sends nothing', () async {
      await loadAndComplete();
      repository
        ..signFailure = const ContractFailure(ContractFailureKind.alreadySigned)
        ..detail = signedDetail
        ..detailGate = Completer<void>();

      final first = controller.sign(png, agreed: true);
      await pumpEventQueue();
      expect(repository.detailCalls, ['12', '12']);
      expect(controller.signing, isTrue);
      expect(
        await controller.sign(png, agreed: true),
        ContractSignResult.inProgress,
      );

      repository.detailGate!.complete();
      expect(await first, ContractSignResult.failed);
      expect(repository.signCalls, hasLength(1));
      expect(controller.canSign, isFalse);
    });

    for (final failure in const [
      ContractFailure(
        ContractFailureKind.contractCancelled,
        detail: 'HTTP 409 contract_cancelled',
      ),
      ContractFailure(
        ContractFailureKind.storageError,
        detail: 'HTTP 502 storage_error',
      ),
      ContractFailure(ContractFailureKind.network, detail: 'offline'),
      ContractFailure(
        ContractFailureKind.templateMissing,
        detail: 'HTTP 409 contract_template_missing',
      ),
      ContractFailure(ContractFailureKind.sessionExpired, detail: 'HTTP 401'),
    ]) {
      test('${failure.kind.name} is kept whole, and the contract stays as '
          'it was', () async {
        await loadAndComplete();
        repository.signFailure = failure;

        expect(
          await controller.sign(png, agreed: true),
          ContractSignResult.failed,
        );

        expect(controller.signFailure, same(failure));
        expect(controller.signFailure?.detail, failure.detail);
        expect(
          controller.detail?.contract.status,
          StudentContractStatus.pending,
        );
        expect(controller.form.register, 'уб12345678');
        expect(controller.signing, isFalse);
        expect(repository.detailCalls, ['12']);
      });
    }

    test(
      'an exception that is not a ContractFailure is kept as its text',
      () async {
        final throwing = _ThrowingSign();
        final c = ContractSigningController(
          contractId: '12',
          repository: throwing,
        );
        addTearDown(c.dispose);
        await c.load();
        c
          ..updateField(ContractFormField.register, 'УБ12345678')
          ..updateField(ContractFormField.address, 'Улаанбаатар');

        expect(await c.sign(png, agreed: true), ContractSignResult.failed);
        expect(c.signFailure?.kind, ContractFailureKind.unexpected);
        expect(c.signFailure?.detail, contains('boom'));
      },
    );

    test('a later success clears the earlier failure', () async {
      await loadAndComplete();
      repository.signFailure = const ContractFailure(
        ContractFailureKind.storageError,
      );
      await controller.sign(png, agreed: true);

      repository
        ..signFailure = null
        ..signed = signedDetail;

      expect(
        await controller.sign(png, agreed: true),
        ContractSignResult.signed,
      );
      expect(controller.signFailure, isNull);
      expect(repository.signCalls, hasLength(2));
    });
  });

  group('download', () {
    ContractDownload link(String name) => ContractDownload(
      url: Uri.parse('https://files.example.test/$name.pdf'),
      expiresAt: DateTime.utc(2026, 10, 11, 3, 5),
    );

    test('fetches a fresh link on every call and opens it', () async {
      repository.downloads.addAll([link('first'), link('second')]);

      expect(await controller.download(), ContractDownloadResult.opened);
      expect(await controller.download(), ContractDownloadResult.opened);

      expect(repository.downloadCalls, ['12', '12']);
      expect(opened, [
        Uri.parse('https://files.example.test/first.pdf'),
        Uri.parse('https://files.example.test/second.pdf'),
      ]);
      expect(controller.downloadFailure, isNull);
    });

    test('not_signed is a failure, and nothing is opened', () async {
      repository.downloadFailure = const ContractFailure(
        ContractFailureKind.notSigned,
        detail: 'HTTP 409 not_signed',
      );

      expect(await controller.download(), ContractDownloadResult.failed);
      expect(controller.downloadFailure?.kind, ContractFailureKind.notSigned);
      expect(opened, isEmpty);
    });

    test('a link the OS will not open is a failure, not success', () async {
      repository.downloads.add(link('refused'));
      openSucceeds = false;

      expect(await controller.download(), ContractDownloadResult.failed);
      expect(controller.downloadFailure?.kind, ContractFailureKind.unexpected);
      expect(opened, hasLength(1));
    });

    test('a second call while one is in flight asks for nothing', () async {
      final gate = Completer<bool>();
      final slow = ContractSigningController(
        contractId: '12',
        repository: repository,
        openUrl: (_) => gate.future,
      );
      addTearDown(slow.dispose);
      repository.downloads.add(link('only'));

      final first = slow.download();
      expect(slow.downloading, isTrue);
      expect(await slow.download(), ContractDownloadResult.inProgress);

      gate.complete(true);
      expect(await first, ContractDownloadResult.opened);
      expect(repository.downloadCalls, ['12']);
    });

    test('a later success clears the earlier failure', () async {
      repository.downloadFailure = const ContractFailure(
        ContractFailureKind.storageError,
      );
      await controller.download();

      repository
        ..downloadFailure = null
        ..downloads.add(link('retry'));

      expect(await controller.download(), ContractDownloadResult.opened);
      expect(controller.downloadFailure, isNull);
    });
  });
}

/// A repository whose sign throws something that is not a ContractFailure.
class _ThrowingSign extends FakeContractRepository {
  _ThrowingSign()
    : super(
        detail: ContractDetail(
          contract: const StudentContract(
            id: '12',
            status: StudentContractStatus.pending,
            canSign: true,
            isCurrent: true,
          ),
          form: const ContractForm(
            lastName: 'Тест',
            firstName: 'Сурагч',
            phone: '00000000',
          ),
          rules: ContractRules(
            guardianRequired: false,
            finalPaymentDateRequired: false,
            finalPaymentDateMin: DateTime(2026, 10, 10),
          ),
          finance: const ContractFinance(
            totalDue: 0,
            totalPaid: 0,
            balance: 0,
            discountPercent: 0,
            currency: 'MNT',
          ),
          document: const ContractDocument(format: 'pdf'),
        ),
      );

  @override
  Future<ContractDetail> signContract(
    String contractId, {
    required ContractForm form,
    required bool agreed,
    required String signature,
  }) async {
    signCalls.add((
      id: contractId,
      form: form,
      agreed: agreed,
      signature: signature,
    ));
    throw StateError('boom');
  }
}
