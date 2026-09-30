/// One enrollment's money position, as `GET /me/ledger` reports it.
///
/// `mobile_api_v1_1.md` §7 documents the endpoint as "per enrollment:
/// due/paid/balance + installments". The verified production response for
/// the adult test account, verbatim:
///
///     {
///       "enrollments": [
///         {
///           "balance": 0.0,
///           "cohort": {"end_date": "2026-10-06", "id": 1,
///                      "name": "Corporate Leaders 2026-08",
///                      "start_date": "2026-08-06"},
///           "course": {"id": 6, "slug": "summer-bootcamp-2027",
///                      "title": {"en": "Summer Bootcamp",
///                                "mn": "Зуны бүтээлч кэмп"}},
///           "currency": "MNT",
///           "enrollment_id": 2,
///           "installments": [],
///           "next_due_date": null,
///           "status": "active",
///           "total_due": 0.0,
///           "total_paid": 0.0
///         }
///       ]
///     }
///
/// Only what the Home payment card needs is modelled. `installments` is not:
/// the verified response showed an empty list, so no installment field has
/// been confirmed, and `next_due_date` already carries the one date the card
/// draws. `total_due`, `total_paid`, `status`, `currency`, `course` and the
/// rest of `cohort` are real fields with no slot in the Figma card, so they
/// are not modelled either — see `docs/ai/DATA_AND_API.md` §8.2.
class LedgerEntry {
  const LedgerEntry({
    required this.enrollmentId,
    required this.cohortId,
    required this.balance,
    this.nextDueDate,
  });

  final int enrollmentId;

  /// Which cohort this enrollment is in — `cohort.id`. How Home finds the
  /// entry for the cohort it shows.
  final int cohortId;

  /// What is still owed, in the ledger's currency. Zero when settled.
  final num balance;

  /// When the next payment falls due, as a local calendar date. Null when
  /// nothing is scheduled.
  final DateTime? nextDueDate;
}
