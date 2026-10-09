import '../../auth/domain/current_user_failure.dart';

/// Every word on the profile screen.
///
/// Copy is taken from the Figma frame verbatim, which is why most of it is
/// English while `languageRow` is bilingual and `eContractStatus` is
/// Mongolian — the design mixes the two, and this screen matches the design
/// rather than translating it.
///
/// No placeholder account data lives here (Issue #223): the header shows the
/// fetched `CurrentUser.displayName` and nothing while it loads or fails, and
/// the frame's join date, contract status and version have no source to show
/// — see [ProfileScreen].
abstract final class ProfileStrings {
  static const String heading = 'Profile';

  // --- Header ---------------------------------------------------------------

  /// Accessibility label for the header's edit control.
  static const String editProfile = 'Edit profile';

  // --- Account ------------------------------------------------------------

  static const String accountSection = 'Account';
  static const String eContract = 'E-Contract';

  static const String certificate = 'Certificate';
  static const String transactionHistory = 'Transaction history';

  // --- App settings -------------------------------------------------------

  static const String appSettingsSection = 'App settings';
  static const String language = 'Хэл / Language';
  static const String languageMn = 'MN';
  static const String languageEn = 'EN';
  static const String darkMode = 'Dark mode';
  static const String changePassword = 'Change password';

  // --- Notification -------------------------------------------------------

  static const String notificationSection = 'Notification';
  static const String notification = 'Notification';

  // --- Contact ------------------------------------------------------------

  static const String contactSection = 'Contact';
  static const String helpCenter = 'Help center';
  static const String termsOfService = 'Term of Service';
  static const String privacyPolicy = 'Privacy Policy';

  // --- Footer -------------------------------------------------------------

  static const String logOut = 'Log out';

  // --- /auth/me failures ----------------------------------------------------
  //
  // Not shown on screen yet — the header stays empty instead, the
  // same way `CohortListScreen` lets a card fall back to "not yet enrolled"
  // rather than blocking on secondary data. Kept here, one fixed string per
  // [CurrentUserFailureKind], the same convention `EnrollmentStrings` follows,
  // so [ProfileController] has something to report and a future screen change
  // has somewhere to read it from.

  static const String sessionExpired = 'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү';
  static const String rejected = 'Мэдээлэл татаж чадсангүй';
  static const String networkError = 'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  /// The message for a failed `/auth/me` fetch — one fixed string per
  /// [CurrentUserFailureKind].
  static String messageFor(CurrentUserFailureKind kind) => switch (kind) {
    CurrentUserFailureKind.sessionExpired => sessionExpired,
    CurrentUserFailureKind.rejected => rejected,
    CurrentUserFailureKind.network => networkError,
    CurrentUserFailureKind.server => serverError,
    CurrentUserFailureKind.unexpected => unexpectedError,
  };
}

/// The screen's own icons, exported from the design.
///
/// Separate from the Phosphor glyphs in `AppIcons`: those are codepoints in a
/// bundled icon font, these are SVG files. The bottom navigation keeps using
/// `AppIcons`.
abstract final class ProfileIcons {
  static const String _dir = 'assets/icons';

  static const String edit = '$_dir/profile_edit.svg';
  static const String eContract = '$_dir/e_contract.svg';
  static const String certificate = '$_dir/certificate.svg';
  static const String transactionHistory = '$_dir/transaction_history.svg';
  static const String language = '$_dir/language.svg';
  static const String changePassword = '$_dir/change_password.svg';
  static const String notification = '$_dir/notification.svg';
  static const String helpCenter = '$_dir/help_center.svg';
  static const String termsOfService = '$_dir/term_of_service.svg';
  static const String privacyPolicy = '$_dir/privacy_policy.svg';
}
