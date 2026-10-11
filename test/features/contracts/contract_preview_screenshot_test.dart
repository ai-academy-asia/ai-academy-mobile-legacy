import 'dart:convert';
import 'dart:typed_data';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_preview_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_signing_controller.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_pdf_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// Deterministic captures of the E-Contract preview step (Issue #316) at
/// `e-contract2.png`'s 393 × 844, 1:1, in light and dark — the header and
/// the document box. The box fills the screen here: the export's signature
/// section under it belongs to the signing step. The "PDF" is two blank
/// white pages from a fake renderer, not a real contract.
///
/// Run `flutter test --update-goldens <this file>` to refresh.
void main() {
  setUpAll(loadAppFonts);

  /// A white 1×1 PNG — a blank page, drawn as the PDF's own paper is.
  final whitePage = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC',
  );

  final detail = ContractDetail(
    contract: const StudentContract(
      id: '12',
      status: StudentContractStatus.pending,
      canSign: true,
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
    document: const ContractDocument(format: 'pdf'),
  );

  for (final (name, theme) in [
    ('contract_preview', AppTheme.light),
    ('contract_preview_dark', AppTheme.dark),
  ]) {
    testWidgets(name, (tester) async {
      useLogicalViewport(tester, const Size(393, 844), padding: iPhonePadding);
      final controller = ContractSigningController(
        contractId: '12',
        repository: FakeContractRepository(
          detail: detail,
          preview: Uint8List.fromList(utf8.encode('%PDF-1.7 test')),
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          home: ContractPreviewScreen(
            controller: controller,
            renderer: _BlankPages(whitePage),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/$name.png'),
      );
    });
  }
}

/// Two A4-proportioned blank pages.
class _BlankPages implements ContractPdfRenderer, ContractPdfDocument {
  _BlankPages(this.page);

  final Uint8List page;

  @override
  Future<ContractPdfDocument> open(Uint8List bytes) async => this;

  @override
  int get pageCount => 2;

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
