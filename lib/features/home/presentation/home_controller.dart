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

  /// Fetches the dashboard. Safe to call again — retry, or pull to refresh.
  Future<void> load() async {
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
