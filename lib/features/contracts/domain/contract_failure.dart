/// Why a contract request did not succeed (Issues #294, #302).
///
/// The backend answers errors as `{"error": "<code>", ...extra}`
/// (`ai-academy-backend` `app/services/errors.py`), and the contract codes
/// below are the ones its contract service raises (`docs/e_contract_api_v1.md`
/// §9, `app/services/contracts/`). A documented code gets its own kind; a
/// status without one keeps the reading it had before (#294).
enum ContractFailureKind {
  /// No usable session, or a 401 the session could not recover from.
  sessionExpired,

  /// The request never completed.
  network,

  /// A 5xx without a documented code, or a body that does not match the
  /// documented shape.
  server,

  /// Anything else — a status or code this client has no reading for.
  unexpected,

  /// `403 forbidden` — the token is not a student's.
  forbidden,

  /// `404 contract_not_found` — an unknown id, or another student's.
  contractNotFound,

  /// `400 invalid_fields` — see [ContractFailure.fieldErrors].
  invalidFields,

  /// `400 agreement_required` — `agreed` was not `true`.
  agreementRequired,

  /// `400 signature_required` — no signature was sent.
  signatureRequired,

  /// `400 invalid_signature` — the signature is not a readable PNG.
  invalidSignature,

  /// `400 empty_signature` — nothing is drawn on it.
  emptySignature,

  /// `413 signature_too_large` — over 2 MB, or a PNG declaring over 8
  /// megapixels.
  signatureTooLarge,

  /// `409 already_signed` — signing (or previewing) a signed contract.
  alreadySigned,

  /// `409 contract_cancelled` — the enrollment was cancelled.
  contractCancelled,

  /// `409 contract_template_missing` — the course's template was removed.
  templateMissing,

  /// `409 contract_template_invalid` — the template is not a readable PDF.
  templateInvalid,

  /// `409 not_signed` — the download asked for before signing.
  notSigned,

  /// `502 storage_error` — the backend's file storage failed; a retry may
  /// succeed, and a failed sign leaves the contract `pending`.
  storageError,
}

/// One `invalid_fields` reason — `fields.validate`'s five, and [unknown] for
/// anything else.
enum ContractFieldReason {
  required,
  tooLong,
  cyrillicOnly,
  invalidFormat,
  outOfRange,
  unknown;

  static ContractFieldReason fromApi(Object? value) => switch (value) {
    'required' => required,
    'too_long' => tooLong,
    'cyrillic_only' => cyrillicOnly,
    'invalid_format' => invalidFormat,
    'out_of_range' => outOfRange,
    _ => unknown,
  };
}

class ContractFailure implements Exception {
  const ContractFailure(this.kind, {this.detail, this.fieldErrors = const {}});

  final ContractFailureKind kind;

  /// Technical context for logs — never shown to the user.
  final String? detail;

  /// For [ContractFailureKind.invalidFields]: each rejected form field (the
  /// API's key, e.g. `register`) and why. Empty for every other kind.
  final Map<String, ContractFieldReason> fieldErrors;

  @override
  String toString() =>
      'ContractFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}
