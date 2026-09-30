import 'ledger_entry.dart';

abstract interface class LedgerRepository {
  /// The signed-in student's ledger, one entry per enrollment.
  ///
  /// Throws `LedgerFailure` when there is no usable session, the API refuses
  /// or cannot be reached, or the response does not match the verified shape.
  Future<List<LedgerEntry>> getLedger();
}
