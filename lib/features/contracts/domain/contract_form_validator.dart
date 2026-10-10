import 'contract_detail.dart';
import 'contract_failure.dart';

/// The backend's contract-form check, mirrored on the client (Issue #306) —
/// `ai-academy-backend` `app/services/contracts/fields.py` (`clean`,
/// `validate`, `_date_problem`), read at backend `8dc89df`. No Flutter
/// import: plain rules over [ContractForm] and [ContractRules].
///
/// **The server stays authoritative.** Its `invalid_fields` reasons are what
/// a signing attempt is finally judged by; this lets a screen say the same
/// thing before sending. Where the two can differ, the client is the
/// stricter one, deliberately:
///
///  * `final_payment_date` must be `YYYY-MM-DD`. The backend runs Python
///    3.12, whose `date.fromisoformat` also accepts forms like `20261015` or
///    week dates; a date picker only ever produces `YYYY-MM-DD`.
///  * A digit is `0`–`9`. Python's `\d` also matches other scripts' decimal
///    digits; a phone keypad only produces ASCII ones.
abstract final class ContractFormValidator {
  /// `fields.MAX_LENGTH`, counted in code points as Python's `len` counts.
  static const int maxLength = 300;

  /// `fields.STUDENT_REQUIRED`.
  static const List<ContractFormField> studentRequired = [
    ContractFormField.lastName,
    ContractFormField.firstName,
    ContractFormField.register,
    ContractFormField.phone,
    ContractFormField.address,
  ];

  /// `fields.GUARDIAN_REQUIRED` — when `rules.guardian_required`.
  static const List<ContractFormField> guardianRequired = [
    ContractFormField.guardianRelation,
    ContractFormField.guardianLastName,
    ContractFormField.guardianFirstName,
    ContractFormField.guardianRegister,
  ];

  /// `fields.CYRILLIC_ONLY` — "Cyrillic only" in the backend's sense: no
  /// Latin letter (`[A-Za-z]`); digits and punctuation pass.
  static const List<ContractFormField> cyrillicOnly = [
    ContractFormField.lastName,
    ContractFormField.firstName,
    ContractFormField.guardianRelation,
    ContractFormField.guardianLastName,
    ContractFormField.guardianFirstName,
    ContractFormField.address,
  ];

  /// `fields.RE_REGISTER`: two letters in U+0400–U+04FF, then eight digits.
  static final RegExp _register = RegExp(r'^[Ѐ-ӿ]{2}[0-9]{8}$');
  static final RegExp _phone = RegExp(r'^[0-9]{8}$');
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _latin = RegExp('[A-Za-z]');
  static final RegExp _isoDate = RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

  /// `fields.clean`: every field trimmed, and the two letters of a register
  /// number upper-cased (the web form did it while typing; the backend does
  /// it before checking and storing).
  static ContractForm normalize(ContractForm form) {
    var clean = form;
    for (final field in ContractFormField.values) {
      var value = form.valueOf(field).trim();
      if (field == ContractFormField.register ||
          field == ContractFormField.guardianRegister) {
        value = _upperFirstTwo(value);
      }
      clean = clean.withValue(field, value);
    }
    return clean;
  }

  /// `fields.validate` over [normalize]d [form]: each field's first problem
  /// — `required`, then `too_long`, then its format — and nothing for a
  /// field that passes. Empty when the form can be signed.
  static Map<ContractFormField, ContractFieldReason> validate(
    ContractForm form,
    ContractRules rules,
  ) {
    final clean = normalize(form);
    String value(ContractFormField field) => clean.valueOf(field);

    final required = [
      ...studentRequired,
      if (rules.guardianRequired) ...guardianRequired,
      if (rules.finalPaymentDateRequired) ContractFormField.finalPaymentDate,
    ];

    final errors = <ContractFormField, ContractFieldReason>{
      for (final field in required)
        if (value(field).isEmpty) field: ContractFieldReason.required,
    };
    for (final field in ContractFormField.values) {
      if (value(field).runes.length > maxLength) {
        errors[field] = ContractFieldReason.tooLong;
      }
    }
    for (final field in ContractFormField.values) {
      final text = value(field);
      if (text.isEmpty || errors.containsKey(field)) continue;
      final reason = _formatProblem(field, text, rules);
      if (reason != null) errors[field] = reason;
    }
    return errors;
  }

  static ContractFieldReason? _formatProblem(
    ContractFormField field,
    String text,
    ContractRules rules,
  ) {
    if (cyrillicOnly.contains(field)) {
      return _latin.hasMatch(text) ? ContractFieldReason.cyrillicOnly : null;
    }
    return switch (field) {
      ContractFormField.register || ContractFormField.guardianRegister =>
        _register.hasMatch(text) ? null : ContractFieldReason.invalidFormat,
      ContractFormField.phone =>
        _phone.hasMatch(text) ? null : ContractFieldReason.invalidFormat,
      ContractFormField.email =>
        _email.hasMatch(text) ? null : ContractFieldReason.invalidFormat,
      ContractFormField.finalPaymentDate => _dateProblem(text, rules),
      _ => null,
    };
  }

  /// `fields._date_problem`: not a date is `invalid_format`; before the
  /// minimum (the backend's today) or after a set maximum is
  /// `out_of_range`.
  static ContractFieldReason? _dateProblem(String text, ContractRules rules) {
    final date = _isoDate.hasMatch(text) ? DateTime.tryParse(text) : null;
    // `tryParse` rolls an impossible day over ("2026-02-30" → March 2);
    // Python rejects it, so a date must read back as itself.
    if (date == null || _isoDay(date) != text) {
      return ContractFieldReason.invalidFormat;
    }
    final max = rules.finalPaymentDateMax;
    if (date.isBefore(rules.finalPaymentDateMin) ||
        (max != null && date.isAfter(max))) {
      return ContractFieldReason.outOfRange;
    }
    return null;
  }

  static String _isoDay(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-'
        '${two(date.month)}-${two(date.day)}';
  }

  /// Python's `value[:2].upper() + value[2:]`, by code point.
  static String _upperFirstTwo(String value) {
    final runes = value.runes.toList();
    if (runes.isEmpty) return value;
    final head = String.fromCharCodes(runes.take(2)).toUpperCase();
    return head + String.fromCharCodes(runes.skip(2));
  }
}
