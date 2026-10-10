import 'dart:convert';
import 'dart:typed_data';

import 'student_contract.dart';

/// `GET /me/contracts/{contract_id}` — and the success body of
/// `POST …/sign` (Issue #302).
///
/// **Backend-source-documented, not observed live**: `ai-academy-backend`
/// `docs/e_contract_api_v1.md` and `student._detail` (commit `208e1c9`,
/// unchanged at `8dc89df`). The summary is the list item's, read as leniently
/// as the list reads it; [form], [rules], [finance] and [document] are what a
/// signing screen needs, so they are required — a missing or mistyped part is
/// the server's fault, never filled in here.
class ContractDetail {
  const ContractDetail({
    required this.contract,
    required this.form,
    required this.rules,
    required this.finance,
    required this.document,
  });

  /// The summary fields, as `GET /me/contracts` lists them.
  final StudentContract contract;

  /// Prefilled from the profile while pending (names, phone, e-mail — the
  /// parent's phone for a junior course); what was signed afterwards.
  final ContractForm form;

  final ContractRules rules;
  final ContractFinance finance;
  final ContractDocument document;
}

/// The contract form — the backend's eleven fields, every one a string (an
/// empty one is `""`, as the backend always sends all eleven).
class ContractForm {
  const ContractForm({
    this.lastName = '',
    this.firstName = '',
    this.register = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.guardianRelation = '',
    this.guardianLastName = '',
    this.guardianFirstName = '',
    this.guardianRegister = '',
    this.finalPaymentDate = '',
  });

  final String lastName;
  final String firstName;

  /// Two Cyrillic letters and eight digits, e.g. `УБ12345678`.
  final String register;

  /// Eight digits — the guardian's for a junior course.
  final String phone;
  final String email;
  final String address;
  final String guardianRelation;
  final String guardianLastName;
  final String guardianFirstName;
  final String guardianRegister;

  /// `YYYY-MM-DD`, or empty.
  final String finalPaymentDate;

  /// The request's `form` object, keyed as the API names the fields.
  Map<String, String> toJson() => {
    'last_name': lastName,
    'first_name': firstName,
    'register': register,
    'phone': phone,
    'email': email,
    'address': address,
    'guardian_relation': guardianRelation,
    'guardian_last_name': guardianLastName,
    'guardian_first_name': guardianFirstName,
    'guardian_register': guardianRegister,
    'final_payment_date': finalPaymentDate,
  };
}

/// What the form must satisfy (`core.rules`).
class ContractRules {
  const ContractRules({
    required this.guardianRequired,
    required this.finalPaymentDateRequired,
    required this.finalPaymentDateMin,
    this.finalPaymentDateMax,
  });

  /// A junior course: the four guardian fields are required.
  final bool guardianRequired;

  /// A balance is owed: `final_payment_date` is required.
  final bool finalPaymentDateRequired;

  /// The earliest allowed `final_payment_date` (the backend's today, in
  /// Ulaanbaatar), as a calendar date.
  final DateTime finalPaymentDateMin;

  /// The latest — the cohort's end date. Null when the cohort has none or
  /// it has already ended.
  final DateTime? finalPaymentDateMax;
}

/// The money on the contract, from the enrollment's ledger; frozen once
/// signed.
class ContractFinance {
  const ContractFinance({
    required this.totalDue,
    required this.totalPaid,
    required this.balance,
    required this.discountPercent,
    required this.currency,
  });

  final double totalDue;
  final double totalPaid;
  final double balance;
  final int discountPercent;

  /// e.g. `MNT`.
  final String currency;
}

/// How the contract's file is reached.
class ContractDocument {
  const ContractDocument({required this.format, this.preview, this.download});

  /// `pdf`.
  final String format;

  /// The preview call's API path while pending; null once signed.
  final String? preview;

  /// The download call's API path once signed; null before.
  final String? download;
}

/// `GET /me/contracts/{contract_id}/download` — a pre-signed link to the
/// signed PDF, valid five minutes. Fetched fresh when needed, never cached.
class ContractDownload {
  const ContractDownload({required this.url, required this.expiresAt});

  final Uri url;
  final DateTime expiresAt;
}

/// [png] as the data URL `POST …/sign` takes for `signature`
/// (`data:image/png;base64,…`). The backend also accepts bare base64; it
/// checks the bytes are a PNG with something drawn, at most 2 MB and 8
/// megapixels — nothing is checked here.
String signatureDataUrl(Uint8List png) =>
    'data:image/png;base64,${base64Encode(png)}';
