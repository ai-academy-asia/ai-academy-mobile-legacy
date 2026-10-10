import '../../notifications/presentation/notification_strings.dart';
import '../../profile/presentation/profile_strings.dart';
import '../domain/contract_failure.dart';

/// Copy for the E-Contract screen. The list's title, status pills and
/// actions are the Figma export's own words (`e-contract1.png`, Issue #312).
/// The empty line is the app's plain wording — no frame draws an empty list
/// (a `PRODUCT DECISION` until one does).
abstract final class ContractStrings {
  /// The screen's title, as both E-Contract exports draw it.
  static const String title = 'Гэрээ · E-Contract';

  /// `{"contracts": []}`.
  static const String empty = 'Одоогоор гэрээ алга байна';

  /// A `signed` contract's status pill.
  static const String statusSigned = 'Гэрээ байгуулсан';

  /// A `pending` contract's status pill.
  static const String statusPending = 'Гэрээ хийгдээгүй байна';

  /// A signed contract's action — fetches the signed PDF.
  static const String download = 'Гэрээ татах';

  /// A pending contract's action — leads to signing.
  static const String sign = 'Гэрээ байгуулах';

  static const String retry = NotificationStrings.retry;

  /// The contract PDF could not be opened or a page drawn (Issue #310). No
  /// design gives the preview its own words yet, so it is the app's generic
  /// line.
  static const String previewFailed = ProfileStrings.unexpectedError;

  /// The signature section's title and the pad's label — the signing
  /// screenshot's own words (Issue #304).
  static const String signHere = 'Гарын үсэг зурна уу · Sign here';

  /// Under the signature pad — the screenshot's own words.
  static const String clear = 'Цэвэрлэх / Clear';

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
