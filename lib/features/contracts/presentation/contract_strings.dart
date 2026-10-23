import '../../../core/locale/l10n.dart';
import '../../notifications/presentation/notification_strings.dart';
import '../../profile/presentation/profile_strings.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_failure.dart';

/// Copy for the E-Contract screen. The list's title, status pills and
/// actions are the Figma export's own words (`e-contract1.png`, Issue #312).
/// The empty line is the app's plain wording — no frame draws an empty list
/// (a `PRODUCT DECISION` until one does).
///
/// In the selected language (Issue #527): the empty line, both status pills
/// and both actions. The bilingual title and the signing flow's own copy are
/// still constants.
abstract final class ContractStrings {
  /// The screen's title, as both E-Contract exports draw it.
  static const String title = 'Гэрээ · E-Contract';

  /// `{"contracts": []}`.
  static String get empty => L10n.current.contractEmpty;

  /// A `signed` contract's status pill.
  static String get statusSigned => L10n.current.contractStatusSigned;

  /// A `pending` contract's status pill. Its own key, not Junior Progress's
  /// `juniorContractTitle`: the same Mongolian, but a short pill label in
  /// English rather than the banner's sentence.
  static String get statusPending => L10n.current.contractStatusPending;

  /// A signed contract's action — fetches the signed PDF.
  static String get download => L10n.current.contractDownload;

  /// A pending contract's action — leads to signing.
  static String get sign => L10n.current.contractSign;

  static String get retry => NotificationStrings.retry;

  /// The contract PDF could not be opened or a page drawn (Issue #310). No
  /// design gives the preview its own words yet, so it is the app's generic
  /// line.
  static String get previewFailed => ProfileStrings.unexpectedError;

  /// The signature section's title and the pad's label — the signing
  /// screenshot's own words (Issue #304).
  static const String signHere = 'Гарын үсэг зурна уу · Sign here';

  /// Under the signature pad — the screenshot's own words.
  static const String clear = 'Цэвэрлэх / Clear';

  // ── The contract form (Issue #314) ──────────────────────────────────────
  // No frame draws the form: these are the app's own plain words — section
  // headings in the "Монгол · English" form the signing export uses, field
  // labels in Mongolian as Login's are. A `PRODUCT DECISION` until design
  // gives the form its own copy.

  static const String formStudentSection = 'Хувийн мэдээлэл · Personal details';
  static const String formGuardianSection =
      'Асран хамгаалагчийн мэдээлэл · Guardian details';
  static const String formPaymentSection = 'Төлбөр · Payment';

  /// The form's action — on to the contract preview.
  static const String formContinue = 'Үргэлжлүүлэх';

  /// Over a form that cannot be signed (`can_sign` false, or not pending):
  /// the fields are shown, not editable.
  static const String formReadOnly = 'Энэ гэрээг одоогоор засах боломжгүй.';

  /// Server `invalid_fields` reasons for keys this client has no field for.
  static const String formUnmatchedErrors =
      'Гэрээний мэдээлэлд алдаа байна. Дахин оролдоно уу.';

  /// Errors the student cannot fix here: on a field the form does not draw.
  static const String formHiddenErrors =
      'Гэрээний мэдээлэлд энд засах боломжгүй алдаа байна. '
      'Менежертэйгээ холбогдоно уу.';

  /// `final_payment_date_max` before `final_payment_date_min`: no date can
  /// be picked.
  static const String formDateRulesInvalid =
      'Төлбөрийн огнооны хязгаар буруу тохируулагдсан тул огноо сонгох '
      'боломжгүй. Менежертэйгээ холбогдоно уу.';

  /// The label of [field]. For a junior course ([guardianRequired]) the
  /// backend's `phone` is the parent's, and is labelled so.
  static String fieldLabel(
    ContractFormField field, {
    bool guardianRequired = false,
  }) => switch (field) {
    ContractFormField.lastName => 'Овог',
    ContractFormField.firstName => 'Нэр',
    ContractFormField.register => 'Регистрийн дугаар',
    ContractFormField.phone =>
      guardianRequired ? 'Асран хамгаалагчийн утасны дугаар' : 'Утасны дугаар',
    ContractFormField.email => 'Email хаяг',
    ContractFormField.address => 'Гэрийн хаяг',
    ContractFormField.guardianRelation => 'Таны хэн болох',
    ContractFormField.guardianLastName => 'Асран хамгаалагчийн овог',
    ContractFormField.guardianFirstName => 'Асран хамгаалагчийн нэр',
    ContractFormField.guardianRegister =>
      'Асран хамгаалагчийн регистрийн дугаар',
    ContractFormField.finalPaymentDate => 'Төлбөр төлж дуусах огноо',
  };

  /// Why [field] is refused — the validator's or the server's [reason].
  static String fieldError(
    ContractFormField field,
    ContractFieldReason reason,
  ) => switch (reason) {
    ContractFieldReason.required => 'Заавал бөглөнө үү',
    ContractFieldReason.tooLong => 'Хэт урт байна',
    ContractFieldReason.cyrillicOnly => 'Кирилл үсгээр бичнэ үү',
    ContractFieldReason.invalidFormat => switch (field) {
      ContractFormField.register ||
      ContractFormField.guardianRegister => 'Жишээ нь: УБ12345678',
      ContractFormField.phone => '8 оронтой утасны дугаар оруулна уу',
      ContractFormField.email => 'Email хаяг буруу байна',
      _ => 'Буруу утга байна',
    },
    ContractFieldReason.outOfRange => 'Зөвшөөрөгдөх хугацаанаас гадуур байна',
    ContractFieldReason.unknown => 'Энэ талбарыг шалгана уу',
  };

  // ── Signing (Issue #320) ────────────────────────────────────────────────
  // The Sign label and the agreement sentence are `e-contract2.png`'s own
  // words. No frame draws a signed state or a signing error, so the rest
  // is the app's plain wording — a `PRODUCT DECISION` until design gives
  // them copy.

  /// The signing screen's action — the export's own words.
  static const String signSubmit = 'Гарын үсэг зурах / Sign';

  /// The agreement checkbox's label — the export's own sentence.
  static const String signAgreement = 'Та гэрээний нөхцөлийг зөвшөөрч байна.';

  /// The success state's title.
  static const String signedTitle = 'Гэрээ амжилттай байгуулагдлаа';

  /// The success state's way out, back to the contracts.
  static const String signedDone = 'Буцах';

  /// `already_signed`: signed elsewhere, or by an earlier request.
  static const String signAlreadySigned =
      'Энэ гэрээ аль хэдийн байгуулагдсан байна.';

  /// `invalid_fields`: sent back to the form, whose fields say what.
  static const String signFixForm = 'Гэрээний мэдээллээ шалгаад засна уу.';

  /// `contract_cancelled`.
  static const String signCancelled =
      'Энэ гэрээ цуцлагдсан тул байгуулах боломжгүй.';

  /// `contract_template_missing` / `_invalid`.
  static const String signTemplateUnavailable =
      'Гэрээний загвар бэлэн биш байна. Менежертэйгээ холбогдоно уу.';

  static String messageFor(ContractFailureKind kind) => switch (kind) {
    ContractFailureKind.sessionExpired => ProfileStrings.sessionExpired,
    ContractFailureKind.network => ProfileStrings.networkError,
    ContractFailureKind.server ||
    ContractFailureKind.storageError => ProfileStrings.serverError,
    // The three a student can act on (Issue #320) — the same refusals the
    // preview and sign steps both meet.
    ContractFailureKind.alreadySigned => signAlreadySigned,
    ContractFailureKind.contractCancelled => signCancelled,
    ContractFailureKind.templateMissing ||
    ContractFailureKind.templateInvalid => signTemplateUnavailable,
    // The rest has no design and nothing the student can do differently;
    // the generic line stands in rather than invented copy.
    // `invalid_fields` is shown on the form's own fields instead.
    ContractFailureKind.unexpected ||
    ContractFailureKind.forbidden ||
    ContractFailureKind.contractNotFound ||
    ContractFailureKind.invalidFields ||
    ContractFailureKind.agreementRequired ||
    ContractFailureKind.signatureRequired ||
    ContractFailureKind.invalidSignature ||
    ContractFailureKind.emptySignature ||
    ContractFailureKind.signatureTooLarge ||
    ContractFailureKind.notSigned => ProfileStrings.unexpectedError,
  };
}
