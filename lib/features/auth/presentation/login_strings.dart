import '../../../core/locale/l10n.dart';

/// Every word on the login screen, in one place.
///
/// These are read off the Figma reference for the Adult login flow
/// (`Sign in - 1` … `5`), so unlike the first pass they are the design's real
/// copy rather than placeholders. Keeping them collected here still pays off:
/// the screen is the only caller, and translating or rewording it is a
/// single-file edit.
///
/// In the selected language (Issue #513): every member reads an ARB key —
/// `login*`, the shared error keys, and `authShowPassword` /
/// `authHidePassword`, which every password field shares. The heading and the
/// button are the one `loginTitle`, "Нэвтрэх" / "Log in".
abstract final class LoginStrings {
  /// Screen heading.
  static String get heading => L10n.current.loginTitle;

  /// Shown inside the first field while it is empty and unfocused. The field
  /// takes either a phone number or an email address.
  static String get identifierPlaceholder =>
      L10n.current.loginIdentifierPlaceholder;

  /// The same field's floating label once what is typed is recognisably a
  /// phone number. The design shows this one; the field takes an email too
  /// (Issue #146), so while it cannot tell, the label stays [identifierPlaceholder].
  static String get identifierPhoneLabel =>
      L10n.current.loginIdentifierPhoneLabel;

  /// The floating label once what is typed is recognisably an email address.
  static String get identifierEmailLabel =>
      L10n.current.loginIdentifierEmailLabel;

  /// Second field, in both resting and floating positions.
  static String get passwordLabel => L10n.current.loginPasswordLabel;

  /// Checkbox row under the fields.
  static String get rememberMe => L10n.current.loginRememberMe;

  /// Filled primary button.
  static String get signIn => L10n.current.loginTitle;

  /// Outlined secondary button. Its screen is not built yet.
  static String get resetPassword => L10n.current.loginResetPassword;

  /// Supporting line in the bottom card.
  static String get contactSupporting => L10n.current.loginContactSupporting;

  /// Title line in the bottom card.
  static String get contactManager => L10n.current.loginContactManager;

  // --- Contact sheet (Issue #186) ------------------------------------------

  /// The contact sheet's heading (#239) — its own, not the bottom card's
  /// [contactManager].
  static String get contactSheetTitle => L10n.current.loginContactSheetTitle;

  /// Under the sheet's heading: what the two options below are for (#239).
  static String get contactMessage => L10n.current.loginContactMessage;

  /// Opens the manager's phone number.
  static String get contactCall => L10n.current.loginContactCall;

  /// Opens a new email to the manager's address.
  static String get contactEmail => L10n.current.loginContactEmail;

  // --- Validation ----------------------------------------------------------

  static String get identifierRequired =>
      L10n.current.loginIdentifierRequired;
  static String get identifierInvalid => L10n.current.loginIdentifierInvalid;
  static String get passwordRequired => L10n.current.loginPasswordRequired;
  static String get passwordTooShort => L10n.current.loginPasswordTooShort;

  // --- API failures --------------------------------------------------------

  static String get invalidCredentials =>
      L10n.current.loginInvalidCredentials;
  static String get networkError => L10n.current.commonNetworkError;
  static String get serverError => L10n.current.commonServerError;
  static String get unexpectedError => L10n.current.commonUnexpectedError;

  // --- Accessibility labels ------------------------------------------------

  static String get showPassword => L10n.current.authShowPassword;
  static String get hidePassword => L10n.current.authHidePassword;
}
