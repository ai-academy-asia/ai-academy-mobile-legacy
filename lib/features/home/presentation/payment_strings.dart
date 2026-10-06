import 'home_strings.dart';

/// Every word on the Adult Payment screen ("Төлбөр"), read off its three
/// Figma references (Issue #196) and carried verbatim, as `HomeStrings` does.
abstract final class PaymentStrings {
  static const String title = 'Төлбөр';

  /// The summary's caption — "Нийт сургалтын төлбөр", led by the course's
  /// name when the plan carries one ("AI Engineer Нийт сургалтын төлбөр").
  static String totalLabel(String? courseTitle) =>
      courseTitle == null || courseTitle.isEmpty
      ? _totalLabel
      : '$courseTitle $_totalLabel';
  static const String _totalLabel = 'Нийт сургалтын төлбөр';

  static const String paid = 'Төлсөн';

  /// The remaining amount's caption: how many installments are still unpaid.
  static String unpaidInstallments(int count) => '$count-нь төлөлт дутуу';

  /// The fully-paid summary line.
  static const String paidOff = 'Төлөгдөж дуссан';

  static const String schedule = 'Төлбөрийн хуваарь';

  /// The word on an unpaid installment's badge, above its number.
  static const String installment = 'Төлөлт';

  /// Under the next installment's date.
  static String dueIn(int days) => '$days хоног дутуу';

  /// Under an overdue installment's date.
  static const String overdue = 'Хугацаа хэтэрсэн';

  /// The bottom button — the same words the Home payment card's action uses.
  static const String payAction = HomeStrings.payAction;

  /// Read out for a paid installment, whose badge draws only a tick.
  static const String paidInstallment = 'Төлөгдсөн';

  /// `2,000,000₮` — thousands grouped with commas, the sign after. Built by
  /// hand rather than with `intl`, which the app does not depend on.
  static String amount(num value) {
    final whole = value.round();
    final digits = whole.abs().toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return '${whole < 0 ? '-' : ''}$grouped₮';
  }
}
