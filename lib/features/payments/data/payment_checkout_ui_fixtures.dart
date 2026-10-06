import '../domain/payment_checkout.dart';

/// **TEMPORARY UI FIXTURES — not backend data.** (Issue #198)
///
/// The Adult payment flow was built from its Figma references before any
/// invoice, payment, bank-account or eBarimt endpoint was confirmed. These
/// are the references' own values, typed in by hand: the amounts, the
/// account details and the receipt numbers describe no real student, account
/// or transaction, and must never be shown as such. The flow is reachable
/// only from the debug-only Payment screen preview, and these go away once a
/// real integration fills [PaymentCheckout].
abstract final class PaymentCheckoutUiFixtures {
  static const PaymentCheckout checkout = PaymentCheckout(
    // References 1–3: 500,000₮ "доод хязгаар" to 1,500,000₮ "дээд
    // хязгаар", two installments after this one. The 50,000₮ step is not in
    // any reference — it only lets the slider land on 750,000₮.
    range: PaymentAmountRange(
      min: 500000,
      max: 1500000,
      step: 50000,
      laterInstallments: 2,
    ),
    // The method screen's "3-р төлөлт 500,000₮", kept verbatim.
    installmentNumber: 3,
    installmentAmount: 500000,
    // Reference 5, in its order.
    banks: [
      PaymentBank(id: 'khan', name: 'Хаан банк'),
      PaymentBank(id: 'socialpay', name: 'Social Pay'),
      PaymentBank(id: 'tdb', name: 'ХХБ'),
      PaymentBank(id: 'turiin', name: 'Төрийн банк'),
      PaymentBank(id: 'golomt', name: 'Голомт банк'),
      PaymentBank(id: 'mbank', name: 'М Банк'),
      PaymentBank(id: 'xac', name: 'Хас банк'),
      PaymentBank(id: 'mostmoney', name: 'Most Money'),
      PaymentBank(id: 'chinggis', name: 'Чингис хаан банк'),
      PaymentBank(id: 'ukhob', name: 'ҮХОБ'),
    ],
    // References 6 and 7.
    transfer: BankTransferDetails(
      bankName: 'Голомт банк',
      recipient: 'Хиймэл Оюун Ухааны Хаб',
      accountNumber: '3215155471',
      iban: '820015003215155471',
      reference: 'Test',
    ),
    // Reference 9.
    receipt: PaymentReceipt(
      transactionId: '#TRX-992104',
      dateLabel: 'Nov 25, 2024',
      lotteryNumber: 'UV37143572',
      ddtd: '000006119026001231023057030027901',
    ),
  );
}
