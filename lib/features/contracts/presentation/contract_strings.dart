import '../../notifications/presentation/notification_strings.dart';
import '../../profile/presentation/profile_strings.dart';
import '../domain/contract_failure.dart';

/// Copy for the E-Contract screen (Issue #294). No Figma frame draws this
/// screen, so the title is the Profile row's own label and the two state
/// lines are the app's plain wording (a `PRODUCT DECISION` until a frame
/// exists).
abstract final class ContractStrings {
  /// The screen's title — the "E-Contract" row that opens it.
  static const String title = ProfileStrings.eContract;

  /// `{"contracts": []}`.
  static const String empty = 'Одоогоор гэрээ алга байна';

  /// One or more contracts, none of which can be drawn: no item field beyond
  /// `id` is documented (`BACKEND GAP`), so neither a title nor a status is
  /// shown in their place.
  static const String notShownYet =
      'Таны гэрээг апп дээр одоогоор харуулах боломжгүй байна';

  static const String retry = NotificationStrings.retry;

  static String messageFor(ContractFailureKind kind) => switch (kind) {
    ContractFailureKind.sessionExpired => ProfileStrings.sessionExpired,
    ContractFailureKind.network => ProfileStrings.networkError,
    ContractFailureKind.server ||
    ContractFailureKind.storageError => ProfileStrings.serverError,
    // The signing kinds (Issue #302) have no screen and no design yet; until
    // one gives them words, the generic line stands in rather than invented
    // copy. Only the list reaches this today.
    ContractFailureKind.unexpected ||
    ContractFailureKind.forbidden ||
    ContractFailureKind.contractNotFound ||
    ContractFailureKind.invalidFields ||
    ContractFailureKind.agreementRequired ||
    ContractFailureKind.signatureRequired ||
    ContractFailureKind.invalidSignature ||
    ContractFailureKind.emptySignature ||
    ContractFailureKind.signatureTooLarge ||
    ContractFailureKind.alreadySigned ||
    ContractFailureKind.contractCancelled ||
    ContractFailureKind.templateMissing ||
    ContractFailureKind.templateInvalid ||
    ContractFailureKind.notSigned => ProfileStrings.unexpectedError,
  };
}
