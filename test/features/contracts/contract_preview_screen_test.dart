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
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_pdf_view.dart';
import 'package:aia_mobile/shared/widgets/app_back_button.dart';
import 'package:aia_mobile/features/profile/presentation/profile_strings.dart';
import 'package:aia_mobile/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// The E-Contract preview step (Issue #316) and the form's Continue into it,
/// against the hand-driven repository fake and a fake PDF renderer — no
/// backend is reached, nothing is signed, and nothing is drawn natively.
/// Test values only.
void main() {
  // The app's own fonts: under the test font the centred title spans the
  // header row and covers the back button.
  setUpAll(loadAppFonts);

  /// A real 1×1 PNG, so `Image.memory` gets decodable bytes.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );
  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7 test'));

  ContractDetail detail({bool signed = false}) => ContractDetail(
    contract: StudentContract(
      id: '12',
      status: signed
          ? StudentContractStatus.signed
          : StudentContractStatus.pending,
      canSign: !signed,
      canView: true,
      isCurrent: true,
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
    document: const ContractDocument(
      format: 'pdf',
      preview: '/me/contracts/12/preview',
    ),
  );

  late FakeContractRepository repository;
  late _FakeRenderer renderer;

  setUp(() {
    repository = FakeContractRepository(detail: detail(), preview: pdf);
    renderer = _FakeRenderer(png);
  });

  /// The preview step's whole contract: no sign request, ever.
  void expectNotSigned() => expect(repository.signCalls, isEmpty);

  /// The form, whose Continue pushes the preview with the fake renderer —
  /// what [ContractFormScreen.open] wires, with drawing kept off `pdfx`.
  Future<void> pumpFlow(WidgetTester tester) async {
    useLogicalViewport(tester, const Size(393, 1400));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ContractFormScreen(
          contractId: '12',
          repository: repository,
          onContinue: (context, controller) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ContractPreviewScreen(
                controller: controller,
                renderer: renderer,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
  }

  /// The header's back button — the app's own, not Material's.
  Future<void> goBack(WidgetTester tester) async {
    // The circle itself: the widget spans the header row, whose centre is
    // the title.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBackButton),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(ContractFormField f) =>
      find.widgetWithText(TextField, ContractStrings.fieldLabel(f));

  group('form → preview', () {
    testWidgets('Continue on a valid form shows the PDF for that form', (
      tester,
    ) async {
      await pumpFlow(tester);
      await tapContinue(tester);

      expect(find.byType(ContractPreviewScreen), findsOneWidget);
      expect(repository.previewCalls, hasLength(1));
      expect(repository.previewCalls.single.id, '12');
      expect(repository.previewCalls.single.form.address, 'Улаанбаатар');
      final view = tester.widget<ContractPdfView>(find.byType(ContractPdfView));
      expect(view.bytes, same(pdf));
      expect(renderer.opened, [same(pdf)]);
      expectNotSigned();
    });

    testWidgets('Continue on an invalid form asks for no preview', (
      tester,
    ) async {
      await pumpFlow(tester);
      await tester.enterText(field(ContractFormField.address), '');
      await tapContinue(tester);

      expect(find.byType(ContractPreviewScreen), findsNothing);
      expect(repository.previewCalls, isEmpty);
    });

    testWidgets('editing the form after a preview fetches a fresh one with '
        'the new value; an unchanged form reuses it', (tester) async {
      await pumpFlow(tester);
      await tapContinue(tester);
      expect(repository.previewCalls, hasLength(1));

      // Back to the form, unchanged: the same bytes, no second request.
      await goBack(tester);
      await tapContinue(tester);
      expect(repository.previewCalls, hasLength(1));
      expect(find.byType(ContractPdfView), findsOneWidget);

      // Back, edit, Continue: a new request carrying the edit.
      await goBack(tester);
      await tester.enterText(field(ContractFormField.address), 'Дархан');
      await tapContinue(tester);

      expect(repository.previewCalls, hasLength(2));
      expect(repository.previewCalls.last.form.address, 'Дархан');
      expect(find.byType(ContractPdfView), findsOneWidget);
      expectNotSigned();
    });

    testWidgets('the form keeps its controller and values after the preview '
        'is closed', (tester) async {
      await pumpFlow(tester);
      await tester.enterText(field(ContractFormField.address), 'Дархан');
      await tapContinue(tester);
      await goBack(tester);

      // Still the form's controller, alive and holding the edit.
      expect(
        tester
            .widget<TextField>(field(ContractFormField.address))
            .controller!
            .text,
        'Дархан',
      );
      await tester.enterText(field(ContractFormField.address), 'Эрдэнэт');
      await tapContinue(tester);
      expect(repository.previewCalls.last.form.address, 'Эрдэнэт');
    });

    testWidgets('ContractFormScreen.open leads to the preview by default', (
      tester,
    ) async {
      useLogicalViewport(tester, const Size(393, 1400));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => ContractFormScreen.open(
                context,
                contractId: '12',
                repository: repository,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // The PDF itself is held back so the default `pdfx` renderer is never
      // reached in a widget test; the route and the request are the point.
      repository.previewGate = Completer<void>();
      await tester.ensureVisible(find.byType(AppButton));
      await tester.tap(find.byType(AppButton));
      // Not settled: the preview's spinner runs while the answer is held.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ContractPreviewScreen), findsOneWidget);
      expect(repository.previewCalls, hasLength(1));
      expectNotSigned();
    });
  });

  group('preview states', () {
    Future<ContractSigningController> loaded({bool signed = false}) async {
      repository.detail = detail(signed: signed);
      final controller = ContractSigningController(
        contractId: '12',
        repository: repository,
      );
      addTearDown(controller.dispose);
      await controller.load();
      return controller;
    }

    Future<void> pumpPreview(
      WidgetTester tester,
      ContractSigningController controller,
    ) async {
      useLogicalViewport(tester, const Size(393, 854));
      await tester.pumpWidget(
        MaterialApp(
          home: ContractPreviewScreen(
            controller: controller,
            renderer: renderer,
          ),
        ),
      );
    }

    testWidgets('a spinner while the preview is fetched, then the PDF', (
      tester,
    ) async {
      final controller = await loaded();
      repository.previewGate = Completer<void>();
      await pumpPreview(tester, controller);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ContractPdfView), findsNothing);

      repository.previewGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ContractPdfView), findsOneWidget);
    });

    testWidgets('a failure shows its line, and retry asks again', (
      tester,
    ) async {
      final controller = await loaded();
      repository.previewFailure = const ContractFailure(
        ContractFailureKind.network,
      );
      await pumpPreview(tester, controller);
      await tester.pumpAndSettle();

      expect(find.text(ProfileStrings.networkError), findsOneWidget);
      expect(find.byType(ContractPdfView), findsNothing);

      repository.previewFailure = null;
      await tester.tap(find.text(ContractStrings.retry));
      await tester.pumpAndSettle();

      expect(repository.previewCalls, hasLength(2));
      expect(find.byType(ContractPdfView), findsOneWidget);
      expectNotSigned();
    });

    testWidgets('a contract that cannot be signed requests nothing', (
      tester,
    ) async {
      final controller = await loaded(signed: true);
      await pumpPreview(tester, controller);
      await tester.pumpAndSettle();

      expect(find.text(ProfileStrings.unexpectedError), findsOneWidget);
      expect(find.text(ContractStrings.retry), findsNothing);
      expect(repository.previewCalls, isEmpty);
    });

    testWidgets('closing the preview does not dispose a shared controller', (
      tester,
    ) async {
      final controller = await loaded();
      await pumpPreview(tester, controller);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());

      // Disposed controllers throw on listener registration.
      expect(() => controller.addListener(() {}), returnsNormally);
      expect(renderer.documents.single.closeCalls, 1);
    });
  });
}

class _FakeRenderer implements ContractPdfRenderer {
  _FakeRenderer(this.png);

  final Uint8List png;
  final List<Uint8List> opened = [];
  final List<_FakeDocument> documents = [];

  @override
  Future<ContractPdfDocument> open(Uint8List bytes) async {
    opened.add(bytes);
    final document = _FakeDocument(png);
    documents.add(document);
    return document;
  }
}

class _FakeDocument implements ContractPdfDocument {
  _FakeDocument(this.png);

  final Uint8List png;
  int closeCalls = 0;

  @override
  int get pageCount => 1;

  @override
  Future<ContractPdfPageImage> renderPage(
    int pageNumber, {
    required int width,
  }) async => ContractPdfPageImage(
    bytes: png,
    width: width,
    height: (width * 1.414).round(),
  );

  @override
  Future<void> close() async => closeCalls++;
}
