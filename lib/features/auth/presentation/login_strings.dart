/// Every word on the login screen, in one place.
///
/// These are read off the Figma reference for the Adult login flow
/// (`Sign in - 1` … `5`), so unlike the first pass they are the design's real
/// copy rather than placeholders. Keeping them collected here still pays off:
/// the screen is the only caller, and translating or rewording it is a
/// single-file edit.
abstract final class LoginStrings {
  /// Screen heading.
  static const String heading = 'Нэвтрэх';

  /// Shown inside the first field while it is empty and unfocused. The field
  /// takes either a phone number or an email address.
  static const String identifierPlaceholder = 'Утасны дугаар / Email хаяг';

  /// The same field's floating label, once it is focused or filled. The design
  /// shortens it — the long form only ever appears as the resting placeholder.
  static const String identifierLabel = 'Утасны дугаар';

  /// Second field, in both resting and floating positions.
  static const String passwordLabel = 'Нууц үг';

  /// Checkbox row under the fields.
  static const String rememberMe = 'Намайг сануулах';

  /// Filled primary button.
  static const String signIn = 'Нэвтрэх';

  /// Outlined secondary button. Its screen is not built yet.
  static const String resetPassword = 'Нууц үг сэргээх';

  /// Supporting line in the bottom card.
  static const String contactSupporting = 'Бүртгэлгүй эсвэл нууц үгээ мартсан бол';

  /// Title line in the bottom card.
  static const String contactManager = 'Менежертэй холбогдоорой';

  // --- Validation ----------------------------------------------------------

  static const String identifierRequired = 'Утасны дугаар эсвэл имэйл хаягаа оруулна уу';
  static const String identifierInvalid = 'Утасны дугаар эсвэл имэйл хаяг буруу байна';
  static const String passwordRequired = 'Нууц үгээ оруулна уу';
  static const String passwordTooShort = 'Нууц үг дор хаяж 6 тэмдэгт байх ёстой';

  // --- API failures --------------------------------------------------------

  static const String invalidCredentials = 'Утасны дугаар эсвэл нууц үг буруу байна';
  static const String networkError = 'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  // --- Accessibility labels ------------------------------------------------

  static const String showPassword = 'Нууц үг харуулах';
  static const String hidePassword = 'Нууц үг нуух';
}
