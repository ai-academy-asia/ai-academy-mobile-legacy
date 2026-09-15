import '../domain/enrollment_failure.dart';

/// Every word the enroll action shows. No Figma reference exists for it —
/// same situation as `CohortListStrings`, whose failure wording the shared
/// messages below repeat so the card and the list read as one screen.
abstract final class EnrollmentStrings {
  static const String enroll = 'Бүртгүүлэх';

  /// Replaces the button once the API has created the enrollment.
  static const String enrolled = 'Бүртгүүлсэн';

  static const String sessionExpired = 'Нэвтрэх хугацаа дууссан. Дахин нэвтэрнэ үү';
  static const String rejected = 'Энэ ангид бүртгүүлэх боломжгүй байна';

  static const String networkError = 'Сүлжээнд холбогдож чадсангүй. Дахин оролдоно уу';
  static const String serverError =
      'Серверт алдаа гарлаа. Түр хүлээгээд дахин оролдоно уу';
  static const String unexpectedError = 'Алдаа гарлаа. Дахин оролдоно уу';

  /// The message for a failed enrollment-related request — one fixed string
  /// per [EnrollmentFailureKind], shared by every controller in this feature
  /// so the same failure reads the same wherever it is shown.
  static String messageFor(EnrollmentFailureKind kind) => switch (kind) {
    EnrollmentFailureKind.sessionExpired => sessionExpired,
    EnrollmentFailureKind.rejected => rejected,
    EnrollmentFailureKind.network => networkError,
    EnrollmentFailureKind.server => serverError,
    EnrollmentFailureKind.unexpected => unexpectedError,
  };
}
