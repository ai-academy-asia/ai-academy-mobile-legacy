import 'package:aia_mobile/features/home/presentation/payment_flow/payment_amount_screen.dart';
import 'package:aia_mobile/features/home/presentation/payment_previews.dart';
import 'package:aia_mobile/features/payments/data/payment_checkout_ui_fixtures.dart';
import 'package:aia_mobile/features/payments/domain/payment_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const range = PaymentAmountRange(
    min: 500000,
    max: 1500000,
    step: 50000,
    laterInstallments: 2,
  );

  group('PaymentAmountRange', () {
    test('snap keeps an amount inside the range and on a step', () {
      expect(range.snap(0), 500000);
      expect(range.snap(9000000), 1500000);
      expect(range.snap(760000), 750000);
      expect(range.snap(774999), 750000);
      expect(range.snap(775000), 800000);
      expect(range.snap(1500000), 1500000);
    });

    test('snap always reaches the maximum, even off the step grid', () {
      const odd = PaymentAmountRange(
        min: 100,
        max: 1030,
        step: 100,
        laterInstallments: 1,
      );
      expect(odd.snap(1029), 1030);
      expect(odd.snap(1000), 1000);
    });

    test('each later installment shares what is left evenly — the rule '
        'references 1–3 agree with', () {
      expect(range.eachLaterInstallment(500000), 500000);
      expect(range.eachLaterInstallment(750000), 375000);
      expect(range.eachLaterInstallment(1500000), 0);
    });

    test('with no later installments there is nothing to share', () {
      const last = PaymentAmountRange(
        min: 1,
        max: 10,
        step: 1,
        laterInstallments: 0,
      );
      expect(last.eachLaterInstallment(1), 0);
    });
  });

  group('PaymentSliderScale', () {
    test('linear spreads the range evenly', () {
      final scale = PaymentSliderScale.linear(range);
      expect(scale.shareOf(500000), 0);
      expect(scale.shareOf(1000000), 0.5);
      expect(scale.shareOf(1500000), 1);
      expect(scale.amountAt(0.25), 750000);
    });

    test('the reference scale puts each drawn amount where it is drawn', () {
      const scale = PaymentReferenceSlider.scale;
      expect(scale.shareOf(500000), 12 / 361);
      expect(scale.shareOf(750000), 119 / 361);
      expect(scale.shareOf(1500000), 1);
      expect(scale.amountAt(119 / 361), 750000);
      // Before the first knot: the minimum.
      expect(scale.amountAt(0), 500000);
    });
  });

  test('the UI fixture carries the references\' own values', () {
    const checkout = PaymentCheckoutUiFixtures.checkout;
    expect(checkout.range.min, 500000);
    expect(checkout.range.max, 1500000);
    expect(checkout.range.laterInstallments, 2);
    expect(checkout.installmentNumber, 3);
    expect(checkout.installmentAmount, 500000);
    expect(
      [for (final bank in checkout.banks) bank.name],
      [
        'Хаан банк',
        'Social Pay',
        'ХХБ',
        'Төрийн банк',
        'Голомт банк',
        'М Банк',
        'Хас банк',
        'Most Money',
        'Чингис хаан банк',
        'ҮХОБ',
      ],
    );
    expect(checkout.transfer.bankName, 'Голомт банк');
    expect(checkout.transfer.recipient, 'Хиймэл Оюун Ухааны Хаб');
    expect(checkout.transfer.accountNumber, '3215155471');
    expect(checkout.transfer.iban, '820015003215155471');
    expect(checkout.transfer.reference, 'Test');
    expect(checkout.receipt.transactionId, '#TRX-992104');
    expect(checkout.receipt.dateLabel, 'Nov 25, 2024');
    expect(checkout.receipt.lotteryNumber, 'UV37143572');
    expect(checkout.receipt.ddtd, '000006119026001231023057030027901');
  });
}
