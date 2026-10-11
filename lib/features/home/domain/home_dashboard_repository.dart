import 'home_dashboard.dart';

abstract interface class HomeDashboardRepository {
  /// Everything the signed-in student's Home screen shows.
  ///
  /// Throws `HomeFailure` when there is no usable session, the API refuses or
  /// cannot be reached, or a response does not match its modeled shape. A
  /// student enrolled in nothing is not a failure — it answers a
  /// [HomeDashboard] whose sections are all null.
  Future<HomeDashboard> getDashboard();

  /// The contract banner's status alone — what [getDashboard] puts in
  /// [HomeDashboard.contract] — for refreshing it without reloading the rest
  /// (Issue #322). Null when no contract warrants a banner.
  ///
  /// Unlike [getDashboard], which leaves the banner off when the contracts
  /// cannot be read, this throws then, so a refresh can tell "nothing to
  /// show" from "could not tell" and keep what it had.
  Future<ContractStatus?> getContractNotice();
}
