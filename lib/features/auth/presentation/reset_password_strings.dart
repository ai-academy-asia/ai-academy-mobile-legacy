import '../../../core/locale/l10n.dart';
import '../domain/password_policy.dart';

/// Every word on the reset-password screen.
///
/// Read off the Figma reference for `Sign in - 6` … `10`. Same arrangement as
/// `LoginStrings`: the screen is the only caller, so rewording or translating
/// it is a single-file edit.
///
/// In the selected language (Issue #515): every member but [supporting] reads
/// an ARB key — `reset*`, the shared error keys, and `authShowPassword` /
/// `authHidePassword`, Login's own eye-button labels.
abstract final class ResetPasswordStrings {
  /// Screen title.
  static String get title => L10n.current.resetTitle;

  /// The line under the title. The design ships Lorem ipsum here — the real
  /// copy has not been written yet, so it is carried through verbatim rather
  /// than invented.
  static const String supporting = 'Lorem ipsum dolor sit amet consectetur.';

  static String get currentPassword => L10n.current.resetCurrentPassword;
  static String get newPassword => L10n.current.resetNewPassword;
  static String get confirmPassword => L10n.current.resetConfirmPassword;

  /// Heading of the requirements panel.
  static String get requirementsTitle => L10n.current.resetRequirementsTitle;

  /// Submit. Not in the reference crop — see `ResetPasswordScreen`.
  static String get submit => L10n.current.resetSubmit;

  static String requirement(PasswordRequirement requirement) => switch (requirement) {
    PasswordRequirement.minLength => L10n.current.resetRuleMinLength,
    PasswordRequirement.uppercase => L10n.current.resetRuleUppercase,
    PasswordRequirement.lowercase => L10n.current.resetRuleLowercase,
    PasswordRequirement.digit => L10n.current.resetRuleDigit,
    PasswordRequirement.special => L10n.current.resetRuleSpecial,
  };

  // --- Validation ----------------------------------------------------------

  static String get currentPasswordRequired =>
      L10n.current.resetCurrentPasswordRequired;
  static String get newPasswordRequired =>
      L10n.current.resetNewPasswordRequired;

  /// Shown when the new password fails one or more of the five rules. The
  /// panel already says which, so this only points at the field.
  static String get newPasswordWeak => L10n.current.resetNewPasswordWeak;

  static String get confirmPasswordRequired =>
      L10n.current.resetConfirmPasswordRequired;

  /// Exact wording from `Sign in - 10`.
  static String get confirmPasswordMismatch =>
      L10n.current.resetConfirmPasswordMismatch;

  /// A new password identical to the current one is not a change.
  static String get newPasswordSameAsCurrent =>
      L10n.current.resetNewPasswordSameAsCurrent;

  // --- Outcomes ------------------------------------------------------------

  static String get success => L10n.current.resetSuccess;

  static String get invalidCurrentPassword =>
      L10n.current.resetInvalidCurrentPassword;

  /// The request was not authenticated — the session has gone, not the password.
  static String get sessionExpired => L10n.current.commonSessionExpired;
  static String get networkError => L10n.current.commonNetworkError;
  static String get serverError => L10n.current.commonServerError;
  static String get unexpectedError => L10n.current.commonUnexpectedError;

  // --- Accessibility -------------------------------------------------------

  static String get showPassword => L10n.current.authShowPassword;
  static String get hidePassword => L10n.current.authHidePassword;
}
