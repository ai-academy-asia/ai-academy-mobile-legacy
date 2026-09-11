import '../domain/password_policy.dart';

/// Every word on the reset-password screen.
///
/// Read off the Figma reference for `Sign in - 6` … `10`. Same arrangement as
/// `LoginStrings`: the screen is the only caller, so rewording or translating
/// it is a single-file edit.
abstract final class ResetPasswordStrings {
  /// Screen title.
  static const String title = 'Нууц үгээ тохируулах';

  /// The line under the title. The design ships Lorem ipsum here — the real
  /// copy has not been written yet, so it is carried through verbatim rather
  /// than invented.
  static const String supporting = 'Lorem ipsum dolor sit amet consectetur.';

  static const String currentPassword = 'Одоогийн нууц үг';
  static const String newPassword = 'Шинэ нууц үг';
  static const String confirmPassword = 'Шинэ нууц үг давтах';

  /// Heading of the requirements panel.
  static const String requirementsTitle = 'Нууц үг нь дараах шаардлагыг хангасан байна:';

  /// Submit. Not in the reference crop — see `ResetPasswordScreen`.
  static const String submit = 'Хадгалах';

  static String requirement(PasswordRequirement requirement) => switch (requirement) {
    PasswordRequirement.minLength => '8 ба түүнээс дээш тэмдэгт ашиглах',
    PasswordRequirement.uppercase => 'Том үсэг ашиглах',
    PasswordRequirement.lowercase => 'Жижиг үсэг ашиглах',
    PasswordRequirement.digit => 'Тоо ашиглах',
    PasswordRequirement.special => 'Тусгай тэмдэгт ашиглах',
  };

  // --- Validation ----------------------------------------------------------

  static const String currentPasswordRequired = 'Одоогийн нууц үгээ оруулна уу';
  static const String newPasswordRequired = 'Шинэ нууц үгээ оруулна уу';

  /// Shown when the new password fails one or more of the five rules. The
  /// panel already says which, so this only points at the field.
  static const String newPasswordWeak = 'Нууц үг шаардлагыг хангахгүй байна';

  static const String confirmPasswordRequired = 'Шинэ нууц үгээ давтан оруулна уу';

  /// Exact wording from `Sign in - 10`.
  static const String confirmPasswordMismatch = 'Шинэ нууц үгтэй таарахгүй байна';

  /// A new password identical to the current one is not a change.
  static const String newPasswordSameAsCurrent =
      'Шинэ нууц үг одоогийнхоос өөр байх ёстой';

  // --- Outcomes ------------------------------------------------------------

  static const String success = 'Нууц үг амжилттай солигдлоо';

  static const String invalidCurrentPassword = 'Одоогийн нууц үг буруу байна';

  /// The request was not authenticated — the session has gone, not the password.
  static const String sessionExpired = 'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү';
  static const String networkError = 'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  // --- Accessibility -------------------------------------------------------

  static const String showPassword = 'Нууц үг харуулах';
  static const String hidePassword = 'Нууц үг нуух';
}
