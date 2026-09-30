import 'package:aia_mobile/features/payments/domain/ledger_entry.dart';
import 'package:aia_mobile/features/payments/domain/ledger_failure.dart';
import 'package:aia_mobile/features/payments/domain/ledger_repository.dart';

/// A repository the tests drive by hand: returns [entries], or throws a
/// chosen [LedgerFailure].
class FakeLedgerRepository implements LedgerRepository {
  FakeLedgerRepository({this.entries = const [], this.failure});

  /// Returned on success.
  List<LedgerEntry> entries;

  /// Thrown instead of returning, when set.
  LedgerFailure? failure;

  /// How many times [getLedger] has been called.
  int callCount = 0;

  @override
  Future<List<LedgerEntry>> getLedger() async {
    callCount++;
    if (failure case final failure?) throw failure;
    return entries;
  }
}
