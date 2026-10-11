import 'package:flutter/foundation.dart';

import '../domain/home_dashboard.dart';
import '../domain/home_dashboard_repository.dart';
import '../domain/home_failure.dart';
import 'home_strings.dart';

/// Loads the Home dashboard.
///
/// Same shape as `CourseCatalogController` and `ProfileController`: a plain
/// [ChangeNotifier], a `_disposed` guard, one fixed string per
/// [HomeFailureKind] via [HomeStrings.messageFor], and [isEmpty] that only
/// answers true once a fetch has actually completed.
class HomeController extends ChangeNotifier {
  HomeController({required this._repository});

  final HomeDashboardRepository _repository;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  HomeDashboard? _dashboard;
  String? _errorMessage;

  bool get loading => _loading;

  /// True once a fetch has *completed*, successfully or not.
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Null until the first fetch succeeds, and again after one fails.
  HomeDashboard? get dashboard => _dashboard;

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts.
  String? get errorMessage => _errorMessage;

  /// True once a fetch has completed and left nothing to show — the student
  /// is enrolled in no cohort.
  bool get isEmpty =>
      _hasLoadedOnce &&
      !_loading &&
      _errorMessage == null &&
      (_dashboard?.isEmpty ?? false);

  /// The fetch in flight, so a second [load] joins it rather than starting
  /// an overlapping request.
  Future<void>? _inFlight;

  /// Fetches the dashboard. Safe to call again — retry, pull to refresh, or
  /// a tap on the header logo (Issue #221). A call made while a fetch is
  /// already running joins that fetch instead of sending another request.
  Future<void> load() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<void> _fetch() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _dashboard = await _repository.getDashboard();
    } on HomeFailure catch (failure) {
      _dashboard = null;
      _errorMessage = HomeStrings.messageFor(failure.kind);
    } catch (_) {
      _dashboard = null;
      _errorMessage = HomeStrings.unexpectedError;
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
      _notify();
    }
  }

  /// Re-reads the contract banner's status alone (Issue #322) — after the
  /// student comes back from the contract list, whose fresh statuses the
  /// banner should agree with. One request; the rest of the dashboard stays.
  ///
  /// Nothing happens once disposed, with no dashboard yet, or with a [load]
  /// in flight (that load brings the contract with it). A failure keeps the banner as it was —
  /// it never turns into a failed Home — and an answer arriving after a
  /// [load] replaced the dashboard is dropped.
  Future<void> refreshContract() async {
    final dashboard = _dashboard;
    if (_disposed || dashboard == null || _loading) return;
    final ContractStatus? notice;
    try {
      notice = await _repository.getContractNotice();
    } catch (_) {
      return;
    }
    if (_disposed || !identical(_dashboard, dashboard)) return;
    _dashboard = dashboard.withContract(notice);
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
