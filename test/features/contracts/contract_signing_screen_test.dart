import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/contract_failure.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_form_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_preview_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_signing_controller.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_pdf_renderer.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_signature_pad.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/exercise_submit_button.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// Signing from the preview step (Issue #320), against the hand-driven
/// repository fake, a fake PDF renderer and a fake URL opener: no request
/// leaves the test, `POST …/sign` and `GET …/download` included. Every sign
/// below is the fake's. Test values only.
void main() {
  // The app's own fonts, so the header's back button is where it really is.
  setUpAll(loadAppFonts);

  final whitePage = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC',
  );
  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7 test'));

  ContractDetail detail({StudentContractStatus? status}) {
    final signed = status == StudentContractStatus.signed;
    return ContractDetail(
      contract: StudentContract(
        id: '12',
        status: status ?? StudentContractStatus.pending,
        canSign: !signed,
        canView: true,
        isCurrent: true,
        documentUrl: signed ? '/me/contracts/12/download' : null,
      ),
      form: const ContractForm(
        lastName: 'Тест',
        firstName: 'Сурагч',
        register: 'УБ12345678',
        phone: '00000000',
        address: 'Улаанбаатар',
      ),
      rules: ContractRules(
        guardianRequired: false,
        finalPaymentDateRequired: false,
        finalPaymentDateMin: DateTime(2026, 10, 10),
      ),
      finance: const ContractFinance(
        totalDue: 1000000,
        totalPaid: 1000000,
        balance: 0,
        discountPercent: 0,
        currency: 'MNT',
      ),
      document: ContractDocument(
        format: 'pdf',
        preview: signed ? null : '/me/contracts/12/preview',
        download: signed ? '/me/contracts/12/download' : null,
      ),
    );
  }

  late FakeContractRepository repository;
  late List<Uri> opened;
  late ContractSigningController controller;

  setUp(() {
    repository = FakeContractRepository(
      detail: detail(),
      preview: pdf,
      signed: detail(status: StudentContractStatus.signed),
      downloads: [
        ContractDownload(
          url: Uri.parse('https://files.example.test/signed.pdf'),
          expiresAt: DateTime.utc(2026, 10, 11, 4),
        ),
      ],
    );
    opened = [];
    controller = ContractSigningController(
      contractId: '12',
      repository: repository,
      openUrl: (url) async {
        opened.add(url);
        return true;
      },
    );
  });

  tearDown(() => controller.dispose());

  /// The preview step alone, over a blank home so it can be left.
  Future<void> pumpPreview(WidgetTester tester) async {
    useLogicalViewport(tester, const Size(393, 844), padding: iPhonePadding);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ContractPreviewScreen(
                  controller: controller,
                  renderer: _BlankPages(whitePage),
                ),
              ),
            ),
            child: const Text('home'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  /// The form, whose Continue pushes the preview — the real flow, with the
  /// fake renderer.
  Future<void> pumpFlow(WidgetTester tester) async {
    useLogicalViewport(tester, const Size(393, 1400), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        // A Scaffold where the student lands, as the contract list is — a
        // SnackBar shown on leaving needs one to appear on.
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ContractFormScreen(
                    contractId: '12',
                    controller: controller,
                    onContinue: (context, controller) =>
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ContractPreviewScreen(
                              controller: controller,
                              renderer: _BlankPages(whitePage),
                            ),
                          ),
                        ),
                  ),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ContractStrings.formContinue));
    await tester.pumpAndSettle();
    expect(find.byType(ContractPreviewScreen), findsOneWidget);
  }

  Finder signButton() =>
      find.widgetWithText(ExerciseSubmitButton, ContractStrings.signSubmit);

  bool signEnabled(WidgetTester tester) =>
      tester.widget<ExerciseSubmitButton>(signButton()).onPressed != null;

  Future<void> draw(WidgetTester tester) async {
    final pad = tester.getRect(find.bySemanticsLabel(ContractStrings.signHere));
    final gesture = await tester.startGesture(pad.center - const Offset(60, 0));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset(20, i.isEven ? -15 : 15));
    }
    await gesture.up();
    await tester.pump();
  }

  Future<void> agree(WidgetTester tester) async {
    await tester.tap(find.text(ContractStrings.signAgreement));
    await tester.pump();
  }

  /// Presses Sign and lets the PNG export (real async) and the fake's
  /// answer land. With [settle] false, only pumps — for a held answer.
  Future<void> pressSign(WidgetTester tester, {bool settle = true}) async {
    await tester.tap(signButton());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> readyAndSign(WidgetTester tester, {bool settle = true}) async {
    await draw(tester);
    await agree(tester);
    expect(signEnabled(tester), isTrue);
    await pressSign(tester, settle: settle);
  }

  void expectNoLiveCalls() {
    // Only the fake is ever reached; downloads only through the fake opener.
    for (final url in opened) {
      expect(url.host, 'files.example.test');
    }
  }

  group('Sign is offered only when everything is in place', () {
    testWidgets('not before a signature and the agreement, nor without '
        'either', (tester) async {
      await pumpPreview(tester);
      expect(signEnabled(tester), isFalse);

      await draw(tester);
      expect(signEnabled(tester), isFalse, reason: 'not agreed');

      await agree(tester);
      expect(signEnabled(tester), isTrue);

      await agree(tester); // untick
      expect(signEnabled(tester), isFalse, reason: 'agreement withdrawn');
      await agree(tester);

      await tester.tap(find.text(ContractStrings.clear));
      await tester.pump();
      expect(signEnabled(tester), isFalse, reason: 'signature cleared');
      expect(repository.signCalls, isEmpty);
    });

    testWidgets('no Sign while the preview is loading or failed', (
      tester,
    ) async {
      repository.previewGate = Completer<void>();
      useLogicalViewport(tester, const Size(393, 844), padding: iPhonePadding);
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          home: ContractPreviewScreen(
            controller: controller,
            renderer: _BlankPages(whitePage),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(signButton(), findsNothing);
      expect(find.byType(ContractSignaturePad), findsNothing);

      repository.previewFailure = const ContractFailure(
        ContractFailureKind.network,
      );
      repository.previewGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(ProfileStrings.networkError), findsOneWidget);
      expect(signButton(), findsNothing);
    });

    testWidgets('no Sign for a contract that cannot be signed', (tester) async {
      repository.detail = detail(status: StudentContractStatus.signed);
      await pumpPreview(tester);
      expect(signButton(), findsNothing);
      expect(repository.previewCalls, isEmpty);
    });
  });

  group('the request', () {
    testWidgets('one sign: the normalized form, agreed, the PNG data URL', (
      tester,
    ) async {
      await controller.load();
      controller
        ..updateField(ContractFormField.register, 'уб12345678')
        ..updateField(ContractFormField.address, ' Улаанбаатар ');
      await pumpPreview(tester);
      await readyAndSign(tester);

      expect(repository.signCalls, hasLength(1));
      final sent = repository.signCalls.single;
      expect(sent.id, '12');
      expect(sent.agreed, isTrue);
      expect(sent.form.register, 'УБ12345678');
      expect(sent.form.address, 'Улаанбаатар');
      // The same form the preview was asked for.
      expect(sent.form.toJson(), repository.previewCalls.single.form.toJson());
      const prefix = 'data:image/png;base64,';
      expect(sent.signature, startsWith(prefix));
      final png = base64Decode(sent.signature.substring(prefix.length));
      expect(png.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
    });

    testWidgets('while it is in flight: one request only, nothing editable, '
        'and back is blocked', (tester) async {
      repository.signGate = Completer<void>();
      await pumpPreview(tester);
      await readyAndSign(tester, settle: false);

      expect(repository.signCalls, hasLength(1));
      expect(signButton(), findsNothing, reason: 'a spinner stands in');
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // A second press has nothing to land on; the agreement is off.
      await tester.tap(find.text(ContractStrings.signAgreement));
      await tester.pump();
      expect(repository.signCalls, hasLength(1));

      // Back — the header's button and the system's — goes nowhere.
      await tester.tap(
        find.descendant(
          of: find.byType(CourseLearningBackButton),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ContractPreviewScreen), findsOneWidget);
      // A vetoed pop is still "handled", so maybePop's answer says nothing;
      // the route staying is what counts.
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ContractPreviewScreen), findsOneWidget);

      repository.signGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(ContractStrings.signedTitle), findsOneWidget);
      expect(repository.signCalls, hasLength(1));
    });
  });

  group('success', () {
    testWidgets('the success state; download opens a fresh link through '
        'the opener; Back leaves', (tester) async {
      await pumpPreview(tester);
      await readyAndSign(tester);

      expect(find.text(ContractStrings.signedTitle), findsOneWidget);
      expect(signButton(), findsNothing);
      expect(controller.detail?.contract.status, StudentContractStatus.signed);

      await tester.tap(find.text(ContractStrings.download));
      await tester.pumpAndSettle();
      expect(repository.downloadCalls, ['12']);
      expect(opened, [Uri.parse('https://files.example.test/signed.pdf')]);

      await tester.tap(find.text(ContractStrings.signedDone));
      await tester.pumpAndSettle();
      expect(find.byType(ContractPreviewScreen), findsNothing);
      expectNoLiveCalls();
    });

    testWidgets('a failed download says so and stays on success', (
      tester,
    ) async {
      repository.downloadFailure = const ContractFailure(
        ContractFailureKind.network,
      );
      await pumpPreview(tester);
      await readyAndSign(tester);
      await tester.tap(find.text(ContractStrings.download));
      await tester.pumpAndSettle();

      expect(find.text(ProfileStrings.networkError), findsOneWidget);
      expect(find.text(ContractStrings.signedTitle), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('from the form: Back after signing closes the form too', (
      tester,
    ) async {
      await pumpFlow(tester);
      await readyAndSign(tester);
      await tester.tap(find.text(ContractStrings.signedDone));
      await tester.pumpAndSettle();

      expect(find.byType(ContractPreviewScreen), findsNothing);
      expect(find.byType(ContractFormScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('refusals', () {
    testWidgets('invalid_fields: back to the form, showing the reasons', (
      tester,
    ) async {
      repository.signFailure = const ContractFailure(
        ContractFailureKind.invalidFields,
        fieldErrors: {'register': ContractFieldReason.invalidFormat},
      );
      await pumpFlow(tester);
      await readyAndSign(tester);

      expect(find.byType(ContractPreviewScreen), findsNothing);
      expect(find.byType(ContractFormScreen), findsOneWidget);
      expect(find.text(ContractStrings.signFixForm), findsOneWidget);
      expect(
        find.text(
          ContractStrings.fieldError(
            ContractFormField.register,
            ContractFieldReason.invalidFormat,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('already_signed: says so and leaves the whole flow', (
      tester,
    ) async {
      repository.signFailure = const ContractFailure(
        ContractFailureKind.alreadySigned,
      );
      await pumpFlow(tester);
      // The reload `already_signed` triggers finds it signed.
      repository.detail = detail(status: StudentContractStatus.signed);
      await readyAndSign(tester);

      expect(find.text(ContractStrings.signAlreadySigned), findsOneWidget);
      expect(find.byType(ContractPreviewScreen), findsNothing);
      expect(find.byType(ContractFormScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(repository.signCalls, hasLength(1));
    });

    testWidgets('already_signed with a failed reload still leaves', (
      tester,
    ) async {
      repository.signFailure = const ContractFailure(
        ContractFailureKind.alreadySigned,
      );
      await pumpFlow(tester);
      repository.detailFailure = const ContractFailure(
        ContractFailureKind.network,
      );
      await readyAndSign(tester);

      expect(find.byType(ContractPreviewScreen), findsNothing);
      expect(find.byType(ContractFormScreen), findsNothing);
    });

    for (final (kind, line) in [
      (ContractFailureKind.contractCancelled, ContractStrings.signCancelled),
      (
        ContractFailureKind.templateMissing,
        ContractStrings.signTemplateUnavailable,
      ),
      (
        ContractFailureKind.templateInvalid,
        ContractStrings.signTemplateUnavailable,
      ),
      (ContractFailureKind.forbidden, ProfileStrings.unexpectedError),
      (ContractFailureKind.contractNotFound, ProfileStrings.unexpectedError),
    ]) {
      testWidgets('${kind.name}: its line, and Sign stays off', (tester) async {
        repository.signFailure = ContractFailure(kind);
        await pumpPreview(tester);
        await readyAndSign(tester);

        expect(find.text(line), findsOneWidget);
        expect(signEnabled(tester), isFalse);
        // Nothing the student does turns it back on.
        await agree(tester);
        await agree(tester);
        expect(signEnabled(tester), isFalse);
        expect(repository.signCalls, hasLength(1));
      });
    }

    for (final (kind, line) in [
      (ContractFailureKind.network, ProfileStrings.networkError),
      (ContractFailureKind.server, ProfileStrings.serverError),
      (ContractFailureKind.storageError, ProfileStrings.serverError),
      (ContractFailureKind.unexpected, ProfileStrings.unexpectedError),
      (ContractFailureKind.sessionExpired, ProfileStrings.sessionExpired),
      (ContractFailureKind.signatureTooLarge, ProfileStrings.unexpectedError),
    ]) {
      testWidgets('${kind.name}: its line; signature and agreement kept, and '
          'Sign again succeeds', (tester) async {
        repository.signFailure = ContractFailure(kind);
        await pumpPreview(tester);
        await readyAndSign(tester);

        expect(find.text(line), findsOneWidget);
        expect(find.byType(ContractPreviewScreen), findsOneWidget);
        // Kept: Sign is live again without drawing or ticking anything.
        expect(signEnabled(tester), isTrue);

        repository.signFailure = null;
        await pressSign(tester);
        expect(repository.signCalls, hasLength(2));
        expect(
          repository.signCalls.last.signature,
          repository.signCalls.first.signature,
        );
        expect(find.text(ContractStrings.signedTitle), findsOneWidget);
      });
    }
  });

  group('ownership', () {
    testWidgets('leaving disposes the pad, never the signing controller', (
      tester,
    ) async {
      await pumpPreview(tester);
      await draw(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(ContractSignaturePad), findsNothing);
      // Still usable: a disposed ChangeNotifier throws here.
      expect(() => controller.addListener(() {}), returnsNormally);
      expect(controller.canSign, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}

/// One blank page.
class _BlankPages implements ContractPdfRenderer, ContractPdfDocument {
  _BlankPages(this.page);

  final Uint8List page;

  @override
  Future<ContractPdfDocument> open(Uint8List bytes) async => this;

  @override
  int get pageCount => 1;

  @override
  Future<ContractPdfPageImage> renderPage(
    int pageNumber, {
    required int width,
  }) async => ContractPdfPageImage(
    bytes: page,
    width: width,
    height: (width * 1.4142).round(),
  );

  @override
  Future<void> close() async {}
}
