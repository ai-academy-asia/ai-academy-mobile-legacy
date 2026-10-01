/// Every word on the Junior Profile screen, verbatim from the frame —
/// including "Term of Service", which the frame spells without the plural.
///
/// [name] is shown only while `ProfileController`'s `GET /auth/me` fetch is
/// loading or has failed; once it succeeds the header shows the fetched
/// `CurrentUser.displayName`, the same arrangement the adult Profile uses.
/// [joinedDate] and [version] stay the design's own placeholder copy: the
/// confirmed `/auth/me` response carries no join date, and reading the
/// build's version would need a dependency this screen does not justify.
abstract final class JuniorProfileStrings {
  static const String heading = 'Profile';

  static const String name = 'Хулан';
  static const String joinedDate = 'Joined Oct 2026';

  static const String accountSection = 'Account';
  static const String eContract = 'E-Contract';
  static const String eContractStatus = 'Гэрээ хийгдээгүй байна';
  static const String certificate = 'Certificate';
  static const String transactionHistory = 'Transaction history';
  static const String paymentReceipt = 'Payment receipt';

  static const String appSettingsSection = 'App settings';
  static const String language = 'Хэл / Language';
  static const String languageMn = 'MN';
  static const String languageEn = 'EN';
  static const String changePassword = 'Change password';

  static const String notificationSection = 'Notification';
  static const String notification = 'Notification';

  static const String contactSection = 'Contact';
  static const String helpCenter = 'Help center';
  static const String termsOfService = 'Term of Service';
  static const String privacyPolicy = 'Privacy Policy';

  static const String logOut = 'Log out';
  static const String version = 'Version 1.2.4 (2025)';
}
