import '../../../core/locale/l10n.dart';
import '../domain/enrollment_failure.dart';

/// Every word the enroll action shows. No Figma reference exists for it —
/// same situation as `CohortListStrings`, whose failure wording the shared
/// messages below repeat so the card and the list read as one screen.
abstract final class EnrollmentStrings {
  static const String enroll = 'Бүртгүүлэх';

  static String get sessionExpired => L10n.current.commonSessionExpired;
  static const String rejected = 'Энэ ангид бүртгүүлэх боломжгүй байна';

  static String get networkError => L10n.current.commonNetworkError;
  static String get serverError => L10n.current.commonServerError;
  static String get unexpectedError => L10n.current.commonUnexpectedError;

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
