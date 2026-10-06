/// What the Adult payment flow (Issue #198) needs to take a payment: how
/// much may be paid, the ways to pay, where a bank transfer goes, and the
/// receipt that comes back.
///
/// **Not tied to any response shape, and no backend sends it yet.** No
/// invoice, payment-status, bank-account or eBarimt endpoint is confirmed, so
/// the flow runs only on the temporary UI fixtures
/// (`PaymentCheckoutUiFixtures`). A real integration fills this same model
/// later — see `docs/ai/DATA_AND_API.md` §10.
class PaymentCheckout {
  const PaymentCheckout({
    required this.range,
    required this.installmentNumber,
    required this.installmentAmount,
    required this.banks,
    required this.transfer,
    required this.receipt,
  });

  /// How much the amount screen lets the student pay.
  final PaymentAmountRange range;

  /// The installment the method screen names — the 3 in "3-р төлөлт".
  final int installmentNumber;

  /// What the method screen says that installment comes to.
  final num installmentAmount;

  /// The banks and wallets the transfer sheet offers, in the order drawn.
  final List<PaymentBank> banks;

  /// Where a bank transfer goes.
  final BankTransferDetails transfer;

  /// The eBarimt receipt shown once the payment is confirmed.
  final PaymentReceipt receipt;
}

/// The amount a student may choose to pay now: at least the installment
/// that is due ([min]), at most everything still owed ([max]).
class PaymentAmountRange {
  const PaymentAmountRange({
    required this.min,
    required this.max,
    required this.step,
    required this.laterInstallments,
  });

  final num min;
  final num max;

  /// The amounts the slider stops at, counted from [min].
  final num step;

  /// How many installments are left after this payment — the 2 in
  /// "Дараагийн 2 төлөлт тус бүр …".
  final int laterInstallments;

  /// [amount] brought inside the range and onto a [step] — or onto [max],
  /// which stays reachable even when it is not a whole number of steps up.
  num snap(num amount) {
    final clamped = amount.clamp(min, max);
    final stepped = min + ((clamped - min) / step).round() * step;
    if (stepped >= max || max - clamped < (clamped - stepped).abs()) {
      return max;
    }
    return stepped;
  }

  /// What each later installment comes to once [amount] is paid: what is
  /// left, shared evenly. The rule the three references agree with
  /// (500,000 → 500,000; 750,000 → 375,000; 1,500,000 → 0); which rule the
  /// real plan follows is a product decision still to be confirmed.
  num eachLaterInstallment(num amount) =>
      laterInstallments == 0 ? 0 : (max - amount) / laterInstallments;
}

/// The ways the flow offers to pay, in the order the method screen lists
/// them.
enum PaymentMethod { qpay, storePay, card, transfer }

/// One bank or wallet in the transfer sheet.
class PaymentBank {
  const PaymentBank({required this.id, required this.name});

  /// Stable key — what a logo is looked up by.
  final String id;

  /// As the sheet prints it.
  final String name;
}

/// The account a bank transfer is made to.
class BankTransferDetails {
  const BankTransferDetails({
    required this.bankName,
    required this.recipient,
    required this.accountNumber,
    required this.iban,
    required this.reference,
  });

  final String bankName;
  final String recipient;
  final String accountNumber;
  final String iban;

  /// "Гүйлгээний утга" — what the student writes on the transfer.
  final String reference;
}

/// An eBarimt receipt, as the receipt screen prints it.
class PaymentReceipt {
  const PaymentReceipt({
    required this.transactionId,
    required this.dateLabel,
    required this.lotteryNumber,
    required this.ddtd,
  });

  /// "#TRX-992104".
  final String transactionId;

  /// Already formatted — "Nov 25, 2024".
  final String dateLabel;

  /// "Сугалааны дугаар".
  final String lotteryNumber;

  /// "ДДТД" — the receipt's state document number.
  final String ddtd;
}
