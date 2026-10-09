/// Every word on the Junior Profile screen, verbatim from the frame —
/// including "Term of Service", which the frame spells without the plural.
///
/// No placeholder account data lives here (Issue #223): the header shows the
/// fetched `CurrentUser.displayName` and nothing while it loads or fails, the
/// same arrangement the adult Profile uses, and the frame's join date,
/// contract status and version have no source to show.
abstract final class JuniorProfileStrings {
  static const String heading = 'Profile';

  static const String accountSection = 'Account';
  static const String eContract = 'E-Contract';
  static const String certificate = 'Certificate';
  static const String transactionHistory = 'Transaction history';
  static const String paymentReceipt = 'Payment receipt';

  static const String appSettingsSection = 'App settings';
  static const String language = 'Хэл / Language';
  static const String languageMn = 'MN';
  static const String languageEn = 'EN';
  static const String changePassword = 'Change password';

  static const String darkMode = 'Dark mode';
  static const String notificationSection = 'Notification';
  static const String notification = 'Notification';

  static const String contactSection = 'Contact';
  static const String helpCenter = 'Help center';
  static const String termsOfService = 'Term of Service';
  static const String privacyPolicy = 'Privacy Policy';

  static const String logOut = 'Log out';
}

/// Junior Profile's own exported artwork. Every other row reuses the adult
/// Profile's SVGs (`ProfileIcons`), which the junior frame draws unchanged.
abstract final class JuniorProfileIcons {
  static const String paymentReceipt = 'assets/icons/payment_receipt.svg';
}
