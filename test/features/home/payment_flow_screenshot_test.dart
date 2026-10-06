import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/ebarimt_receipt_screen.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_flow_strings.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_method_screen.dart';
import 'package:aia_mobile/features/home/presentation/payment_previews.dart';
import 'package:aia_mobile/features/payments/data/payment_checkout_ui_fixtures.dart';
import 'package:aia_mobile/features/payments/domain/payment_checkout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// Deterministic captures of the Adult payment flow (Issue #198), one per
/// Figma reference and in the references' own order:
///
///  1. amount, initial — 2. amount, 750,000₮ — 3. amount, 1,500,000₮ —
///  4. method, Qpay selected — 5. bank sheet — 6. transfer sheet —
///  7. full transfer screen — 8. success dialog — 9. eBarimt receipt.
///
/// The references are 3x exports of 393pt-wide frames (844pt tall, 1075 for
/// the full transfer screen, 946 for the receipt), so a reference pixel
/// divided by 3 is a point here. Reference 4 was not supplied: its capture is
/// the screen the bank and transfer sheets are drawn over. Reference 3 prints
/// 750,000₮ as "Таны төлөх дүн" with the slider at 1,500,000₮; the capture
/// follows the slider. Manrope renders about 1–2% wider here than in Figma.
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/payment_flow_*.png` against the references.
void main() {
  setUpAll(loadAppFonts);
  const checkout = PaymentCheckoutUiFixtures.checkout;

  Future<void> pump(WidgetTester tester, Widget home, double height) async {
    useLogicalViewport(tester, Size(393, height), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: home,
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
  }

  Future<void> capture(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/$name.png'),
  );

  testWidgets('1 — amount, initial', (tester) async {
    await pump(tester, paymentFlowPreview(), 844);
    await capture('payment_flow_1_amount');
  });

  testWidgets('2 — amount, 750,000₮', (tester) async {
    await pump(
      tester,
      paymentFlowPreview(amount: 750000, showTooltip: true),
      844,
    );
    await capture('payment_flow_2_amount_750000');
  });

  testWidgets('3 — amount, 1,500,000₮', (tester) async {
    await pump(
      tester,
      paymentFlowPreview(amount: 1500000, showTooltip: true),
      844,
    );
    await capture('payment_flow_3_amount_1500000');
  });

  testWidgets('4 — method, Qpay selected', (tester) async {
    await pump(tester, const PaymentMethodScreen(checkout: checkout), 844);
    await capture('payment_flow_4_method');
  });

  testWidgets('5 — bank sheet', (tester) async {
    await pump(tester, const PaymentMethodScreen(checkout: checkout), 844);
    await tester.tap(find.text(PaymentFlowStrings.transfer));
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await capture('payment_flow_5_bank_sheet');
  });

  testWidgets('6 — transfer sheet', (tester) async {
    await pump(tester, const PaymentMethodScreen(checkout: checkout), 844);
    await tester.tap(find.text(PaymentFlowStrings.transfer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Голомт банк'));
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await capture('payment_flow_6_transfer_sheet');
  });

  testWidgets('7 — full transfer screen', (tester) async {
    await pump(
      tester,
      const PaymentMethodScreen(
        checkout: checkout,
        initialMethod: PaymentMethod.transfer,
        initialTransferShown: true,
      ),
      1075,
    );
    await capture('payment_flow_7_transfer');
  });

  testWidgets('8 — success dialog', (tester) async {
    await pump(tester, const PaymentMethodScreen(checkout: checkout), 844);
    await tester.tap(find.text(PaymentFlowStrings.check));
    await tester.pumpAndSettle();
    await capture('payment_flow_8_success');
  });

  testWidgets('9 — eBarimt receipt', (tester) async {
    await pump(tester, EbarimtReceiptScreen(receipt: checkout.receipt), 946);
    await capture('payment_flow_9_ebarimt');
  });
}
