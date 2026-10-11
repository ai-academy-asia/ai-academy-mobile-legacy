import '../../home/domain/home_dashboard.dart';
import 'junior_progress.dart';

abstract interface class JuniorProgressRepository {
  /// The signed-in junior student's learning progress.
  ///
  /// Null when the student is enrolled in nothing — not a failure. Throws
  /// `HomeFailure` when there is no usable session, the API refuses or cannot
  /// be reached, or a response does not match its modelled shape.
  Future<JuniorProgress?> getProgress();

  /// The contract banner's status alone — [JuniorProgress.contract] — for
  /// refreshing it without reloading the rest (Issue #322). Null when no
  /// contract warrants a banner; throws when the contracts cannot be read.
  Future<ContractStatus?> getContractNotice();
}
