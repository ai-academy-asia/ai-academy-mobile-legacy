import 'home_dashboard.dart';

abstract interface class HomeDashboardRepository {
  /// Everything the signed-in student's Home screen shows.
  ///
  /// Throws `HomeFailure` when there is no usable session, the API refuses or
  /// cannot be reached, or a response does not match its modeled shape. A
  /// student enrolled in nothing is not a failure — it answers a
  /// [HomeDashboard] whose sections are all null.
  Future<HomeDashboard> getDashboard();
}
