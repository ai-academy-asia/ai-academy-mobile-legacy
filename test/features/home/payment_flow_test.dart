import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_learning_back_button.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/ebarimt_receipt_screen.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_amount_screen.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_flow_strings.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_flow_widgets.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_method_screen.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_sheets.dart';
import 'package:aia_mobile/features/home/presentation/payment_flow/payment_success_dialog.dart';
import 'package:aia_mobile/features/home/presentation/payment_previews.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_pill_button.dart';
import 'package:aia_mobile/features/payments/data/payment_checkout_ui_fixtures.dart';
import 'package:aia_mobile/features/payments/domain/payment_checkout.dart';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const checkout = PaymentCheckoutUiFixtures.checkout;

Future<void> pumpFlow(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(393, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  await tester.pumpAndSettle();
}

/// Whether the method row named [label] has its radio on.
bool isSelected(WidgetTester tester, String label) {
  final row = find
      .ancestor(of: find.text(label), matching: find.byType(InkWell))
      .first;
  return tester
      .widget<PaymentRadio>(
        find.descendant(of: row, matching: find.byType(PaymentRadio)),
      )
      .selected;
}

Finder slider() => find.byWidgetPredicate(
  (widget) => widget is Semantics && (widget.properties.slider ?? false),
);

Finder button(String label) => find.widgetWithText(HomePillButton, label);

/// Records what the copy buttons put on the clipboard.
List<String> recordClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

void main() {
  group('amount screen (references 1–3)', () {
    testWidgets('starts at the minimum with no bubble', (tester) async {
      await pumpFlow(tester, paymentFlowPreview());

      expect(find.text(PaymentFlowStrings.title), findsOneWidget);
      expect(find.text(PaymentFlowStrings.yourAmount), findsOneWidget);
      expect(find.text(PaymentFlowStrings.balance), findsOneWidget);
      expect(find.text(PaymentFlowStrings.minimum), findsOneWidget);
      expect(find.text(PaymentFlowStrings.maximum), findsOneWidget);
      expect(find.text('500,000₮'), findsOneWidget);
      expect(find.text('1,500,000₮'), findsOneWidget);
      expect(
        find.textContaining('Дараагийн 2 төлөлт тус бүр 500,000₮'),
        findsOneWidget,
      );
    });

    testWidgets('tapping the track at 750,000₮ updates the amount, the '
        'bubble and the later installments', (tester) async {
      await pumpFlow(tester, paymentFlowPreview());
      final track = tester.getRect(slider());

      await tester.tapAt(
        Offset(track.left + track.width * 119 / 361, track.center.dy),
      );
      await tester.pumpAndSettle();

      // The amount on the left and the bubble.
      expect(find.text('750,000₮'), findsNWidgets(2));
      expect(
        find.textContaining('Дараагийн 2 төлөлт тус бүр 375,000₮'),
        findsOneWidget,
      );
    });

    testWidgets('dragging to the end chooses everything owed', (tester) async {
      await pumpFlow(tester, paymentFlowPreview());
      final track = tester.getRect(slider());

      await tester.dragFrom(
        Offset(track.left + 12, track.center.dy),
        Offset(track.width + 40, 0),
      );
      await tester.pumpAndSettle();

      // The amount, the balance and the bubble.
      expect(find.text('1,500,000₮'), findsNWidgets(3));
      expect(
        find.textContaining('Дараагийн 2 төлөлт тус бүр 0₮'),
        findsOneWidget,
      );
    });

    testWidgets('the slider steps by 50,000₮ for assistive technology', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpFlow(tester, paymentFlowPreview());

      tester.semantics.performAction(
        find.semantics.byAction(SemanticsAction.increase),
        SemanticsAction.increase,
      );
      await tester.pumpAndSettle();

      expect(find.text('550,000₮'), findsNWidgets(2));
      semantics.dispose();
    });

    testWidgets('its methods select locally', (tester) async {
      await pumpFlow(tester, paymentFlowPreview());

      expect(isSelected(tester, PaymentFlowStrings.qpay), isTrue);
      expect(find.text(PaymentFlowStrings.card), findsNothing);

      await tester.tap(find.text(PaymentFlowStrings.storePay));
      await tester.pumpAndSettle();

      expect(isSelected(tester, PaymentFlowStrings.storePay), isTrue);
      expect(isSelected(tester, PaymentFlowStrings.qpay), isFalse);
      // No sheet from here — the amount screen only selects.
      await tester.tap(find.text(PaymentFlowStrings.transfer));
      await tester.pumpAndSettle();
      expect(find.byType(BankSelectSheet), findsNothing);
      expect(isSelected(tester, PaymentFlowStrings.transfer), isTrue);
    });

    testWidgets('"Төлбөр шалгах" goes on to the method screen', (tester) async {
      await pumpFlow(tester, paymentFlowPreview());

      await tester.tap(button(PaymentFlowStrings.check));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentMethodScreen), findsOneWidget);
    });
  });

  group('method screen (references 4–7)', () {
    testWidgets('names the installment and offers four methods, Qpay '
        'selected', (tester) async {
      await pumpFlow(tester, const PaymentMethodScreen(checkout: checkout));

      expect(find.text('3-р төлөлт'), findsOneWidget);
      expect(find.text('500,000₮'), findsOneWidget);
      for (final label in [
        PaymentFlowStrings.qpay,
        PaymentFlowStrings.storePay,
        PaymentFlowStrings.card,
        PaymentFlowStrings.transfer,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(isSelected(tester, PaymentFlowStrings.qpay), isTrue);
      expect(find.byType(BankTransferDetailsView), findsNothing);
    });

    testWidgets('Store pay and Card select locally', (tester) async {
      await pumpFlow(tester, const PaymentMethodScreen(checkout: checkout));

      await tester.tap(find.text(PaymentFlowStrings.card));
      await tester.pumpAndSettle();

      expect(isSelected(tester, PaymentFlowStrings.card), isTrue);
      expect(isSelected(tester, PaymentFlowStrings.qpay), isFalse);
      expect(find.byType(BankSelectSheet), findsNothing);
    });

    testWidgets('Шилжүүлэх → bank sheet → bank → transfer sheet → '
        'transfer details on the screen', (tester) async {
      await pumpFlow(tester, const PaymentMethodScreen(checkout: checkout));

      await tester.tap(find.text(PaymentFlowStrings.transfer));
      await tester.pumpAndSettle();

      // Reference 5: every bank, Qpay still selected behind.
      expect(find.byType(BankSelectSheet), findsOneWidget);
      for (final bank in checkout.banks) {
        expect(find.text(bank.name), findsOneWidget);
      }
      expect(isSelected(tester, PaymentFlowStrings.qpay), isTrue);

      await tester.tap(find.text('Голомт банк'));
      await tester.pumpAndSettle();

      // Reference 6.
      expect(find.byType(BankSelectSheet), findsNothing);
      expect(find.byType(BankTransferSheet), findsOneWidget);
      expect(find.text(PaymentFlowStrings.transferTitle), findsOneWidget);
      expect(find.text('Хиймэл Оюун Ухааны Хаб'), findsOneWidget);
      expect(isSelected(tester, PaymentFlowStrings.qpay), isTrue);

      await tester.tapAt(const Offset(196, 100));
      await tester.pumpAndSettle();

      // Reference 7.
      expect(find.byType(BankTransferSheet), findsNothing);
      expect(isSelected(tester, PaymentFlowStrings.transfer), isTrue);
      expect(isSelected(tester, PaymentFlowStrings.qpay), isFalse);
      expect(find.byType(BankTransferDetailsView), findsOneWidget);
      for (final value in [
        checkout.transfer.bankName,
        checkout.transfer.recipient,
        checkout.transfer.accountNumber,
        checkout.transfer.iban,
        checkout.transfer.reference,
      ]) {
        expect(find.text(value), findsOneWidget);
      }

      // Another method hides the details again.
      await tester.tap(find.text(PaymentFlowStrings.qpay));
      await tester.pumpAndSettle();
      expect(find.byType(BankTransferDetailsView), findsNothing);
      expect(isSelected(tester, PaymentFlowStrings.qpay), isTrue);
    });

    testWidgets('closing the bank sheet without a bank changes nothing', (
      tester,
    ) async {
      await pumpFlow(tester, const PaymentMethodScreen(checkout: checkout));

      await tester.tap(find.text(PaymentFlowStrings.transfer));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(196, 100));
      await tester.pumpAndSettle();

      expect(find.byType(BankSelectSheet), findsNothing);
      expect(find.byType(BankTransferSheet), findsNothing);
      expect(isSelected(tester, PaymentFlowStrings.qpay), isTrue);
      expect(find.byType(BankTransferDetailsView), findsNothing);
    });

    testWidgets('the copy buttons copy the account number and IBAN', (
      tester,
    ) async {
      final copied = recordClipboard(tester);
      await pumpFlow(
        tester,
        const PaymentMethodScreen(
          checkout: checkout,
          initialMethod: PaymentMethod.transfer,
          initialTransferShown: true,
        ),
      );

      final buttons = find.byType(PaymentCopyButton);
      expect(buttons, findsNWidgets(2));
      await tester.tap(buttons.at(0));
      await tester.tap(buttons.at(1));
      await tester.pump();

      expect(copied, ['3215155471', '820015003215155471']);
    });

    testWidgets('"Төлбөр шалгах" → success → "Ойлголоо" → eBarimt; back '
        'returns to the method screen', (tester) async {
      await pumpFlow(tester, const PaymentMethodScreen(checkout: checkout));

      await tester.tap(button(PaymentFlowStrings.check));
      await tester.pumpAndSettle();

      // Reference 8.
      expect(find.byType(PaymentSuccessDialog), findsOneWidget);
      expect(find.text(PaymentFlowStrings.success), findsOneWidget);

      await tester.tap(button(PaymentFlowStrings.understood));
      await tester.pumpAndSettle();

      // Reference 9.
      expect(find.byType(PaymentSuccessDialog), findsNothing);
      expect(find.byType(EbarimtReceiptScreen), findsOneWidget);

      await tester.tap(find.byType(CourseLearningBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(EbarimtReceiptScreen), findsNothing);
      expect(find.byType(PaymentMethodScreen), findsOneWidget);
    });

    testWidgets('the success dialog does not close on its barrier', (
      tester,
    ) async {
      await pumpFlow(tester, const PaymentMethodScreen(checkout: checkout));
      await tester.tap(button(PaymentFlowStrings.check));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(196, 60));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentSuccessDialog), findsOneWidget);
    });
  });

  group('eBarimt receipt (reference 9)', () {
    testWidgets('prints the receipt and copies its numbers', (tester) async {
      final copied = recordClipboard(tester);
      await pumpFlow(tester, EbarimtReceiptScreen(receipt: checkout.receipt));

      expect(find.text(PaymentFlowStrings.receiptTitle), findsOneWidget);
      expect(find.text('Transaction: #TRX-992104'), findsOneWidget);
      expect(find.text('Date: Nov 25, 2024'), findsOneWidget);
      expect(find.text(PaymentFlowStrings.vatIncluded), findsOneWidget);
      expect(find.text(PaymentFlowStrings.qrTitle), findsOneWidget);
      expect(find.text('UV37143572'), findsOneWidget);
      expect(find.text('000006119026001231023057030027901'), findsOneWidget);

      final buttons = find.byType(PaymentCopyButton);
      await tester.tap(buttons.at(0));
      await tester.tap(buttons.at(1));
      await tester.pump();
      expect(copied, ['UV37143572', '000006119026001231023057030027901']);
    });

    testWidgets('"Татаж авах" is live but leads nowhere', (tester) async {
      await pumpFlow(tester, EbarimtReceiptScreen(receipt: checkout.receipt));

      final download = button(PaymentFlowStrings.download);
      expect(tester.widget<HomePillButton>(download).onPressed, isNotNull);
      await tester.tap(download);
      await tester.pumpAndSettle();

      expect(find.byType(EbarimtReceiptScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the whole flow from the Payment screen', (tester) async {
    await pumpFlow(tester, PaymentPreviews.partlyPaid.screen());

    await tester.tap(find.text('Төлбөр төлөх'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentAmountScreen), findsOneWidget);

    await tester.tap(button(PaymentFlowStrings.check));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PaymentFlowStrings.transfer));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хаан банк'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(196, 100));
    await tester.pumpAndSettle();
    await tester.tap(button(PaymentFlowStrings.check));
    await tester.pumpAndSettle();
    await tester.tap(button(PaymentFlowStrings.understood));
    await tester.pumpAndSettle();

    expect(find.byType(EbarimtReceiptScreen), findsOneWidget);
  });
}
