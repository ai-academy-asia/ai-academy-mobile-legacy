import 'dart:convert';
import 'dart:typed_data';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/contracts/domain/contract_detail.dart';
import 'package:aia_mobile/features/contracts/domain/student_contract.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_preview_screen.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_signing_controller.dart';
import 'package:aia_mobile/features/contracts/presentation/contract_strings.dart';
import 'package:aia_mobile/features/contracts/presentation/widgets/contract_pdf_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_contract_repository.dart';

/// Deterministic captures of the E-Contract preview and signing step
/// (Issues #316, #320) at `e-contract2.png`'s 393 × 844, 1:1, in light and
/// dark: the export's state — document box, a drawn signature, the
/// agreement ticked, Sign live — and the success state after Sign. The "PDF"
/// is two blank white pages from a fake renderer and the sign answer a fake
/// repository's, not a real contract; nothing is sent anywhere.
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

  final signedDetail = ContractDetail(
    contract: StudentContract(
      id: '12',
      status: StudentContractStatus.signed,
      canView: true,
      isCurrent: true,
      signedAt: DateTime.utc(2026, 10, 11, 3),
      documentUrl: '/me/contracts/12/download',
    ),
    form: detail.form,
    rules: detail.rules,
    finance: detail.finance,
    document: const ContractDocument(
      format: 'pdf',
      download: '/me/contracts/12/download',
    ),
  );

  /// The preview step with a signature drawn and the agreement ticked —
  /// Sign live, as the export draws it — or, with [sign], after Sign.
  Future<void> pumpSigning(
    WidgetTester tester,
    ThemeData theme, {
    bool sign = false,
  }) async {
    useLogicalViewport(tester, const Size(393, 844), padding: iPhonePadding);
    final controller = ContractSigningController(
      contractId: '12',
      repository: FakeContractRepository(
        detail: detail,
        preview: Uint8List.fromList(utf8.encode('%PDF-1.7 test')),
        signed: signedDetail,
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

    // A signature-like stroke across the pad, then the agreement.
    final pad = tester.getRect(find.bySemanticsLabel(ContractStrings.signHere));
    final gesture = await tester.startGesture(
      pad.centerLeft + const Offset(90, 10),
    );
    for (final step in const [
      Offset(30, -25),
      Offset(25, 20),
      Offset(30, -15),
      Offset(35, 25),
      Offset(30, -5),
    ]) {
      await gesture.moveBy(step);
    }
    await gesture.up();
    await tester.ensureVisible(find.text(ContractStrings.signAgreement));
    await tester.tap(find.text(ContractStrings.signAgreement));
    await tester.pumpAndSettle();

    if (sign) {
      await tester.ensureVisible(find.text(ContractStrings.signSubmit));
      await tester.tap(find.text(ContractStrings.signSubmit));
      // The PNG export renders an image: real async, not the fake clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    } else {
      // Back to the top, as the export frames it — by the scroll position,
      // not a drag, which would draw on the pad.
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
    }
    await precacheImages(tester);
    await tester.pumpAndSettle();
  }

  for (final (name, theme, sign) in [
    ('contract_preview', AppTheme.light, false),
    ('contract_preview_dark', AppTheme.dark, false),
    ('contract_signed', AppTheme.light, true),
    ('contract_signed_dark', AppTheme.dark, true),
  ]) {
    testWidgets(name, (tester) async {
      await pumpSigning(tester, theme, sign: sign);
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
