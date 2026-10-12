/// Every word in the Adult payment flow (Issue #198), read off its Figma
/// references and carried verbatim, as `PaymentStrings` does.
abstract final class PaymentFlowStrings {
  /// The amount and method screens' title.
  static const String title = 'Төлбөр төлөх';

  // --- Amount (references 1–3) ---------------------------------------------

  static const String yourAmount = 'Таны төлөх дүн';
  static const String balance = 'Төлөх үлдэгдэл';
  static const String minimum = 'доод хязгаар';
  static const String maximum = 'дээд хязгаар';

  /// "Дараагийн 2 төлөлт тус бүр " — the amount follows in bold.
  static String eachLater(int count) => 'Дараагийн $count төлөлт тус бүр ';

  // --- Method (references 4–7) ---------------------------------------------

  /// "3-р төлөлт".
  static String installment(int number) => '$number-р төлөлт';

  static const String methods = 'Төлбөрийн хэлбэр';
  static const String qpay = 'Qpay';
  static const String storePay = 'Store pay';
  static const String card = 'Карт / Card';
  static const String transfer = 'Шилжүүлэх';

  /// Both screens' bottom button.
  static const String check = 'Төлбөр шалгах';

  // --- Bank transfer (references 6–7) --------------------------------------

  static const String transferTitle = 'Банкны шилжүүлгийн мэдээлэл';
  static const String bank = 'Банк';
  static const String recipient = 'Хүлээн авагч';
  static const String accountNumber = 'Дансны дугаар';
  static const String iban = 'IBAN';
  static const String reference = 'Гүйлгээний утга';

  /// Read out for a copy button: "Хуулах" and what it copies. Not drawn.
  static String copy(String what) => '$what хуулах';

  // --- Success (reference 8) -----------------------------------------------

  static const String success = 'Төлбөр амжилттай төлөгдлөө';
  static const String understood = 'Ойлголоо';

  // --- eBarimt (reference 9) -----------------------------------------------

  static const String receiptTitle = 'eBarimt · Баримт';
  static String transaction(String id) => 'Transaction: $id';
  static String date(String label) => 'Date: $label';
  static const String vatIncluded = 'VAT included · И-баримт олгогдсон';
  static const String qrTitle = 'eBarimt QR code';
  static const String lottery = 'Сугалааны дугаар';
  static const String ddtd = 'ДДТД';
  static const String download = 'Татаж авах';
}
