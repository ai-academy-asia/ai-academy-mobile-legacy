import 'package:flutter/foundation.dart';

import '../../../core/api/api_failure.dart';
import '../domain/cohort.dart';
import '../domain/cohort_repository.dart';
import 'cohort_list_strings.dart';

/// Loads the public cohort list.
///
/// Same shape as `CourseCatalogController`: a plain [ChangeNotifier], a
/// `_disposed` guard, one fixed string per [ApiFailureKind], and
/// [isEmpty] that is false until the first fetch has actually completed —
/// an untouched controller has not established emptiness yet.
///
/// When [courseId] is given, [cohorts] (and therefore [isEmpty]) only ever
/// holds cohorts whose `courseId` matches it. The filter is applied client
/// side, after `GET /cohorts` returns — there is no confirmed per-course
/// query parameter on that endpoint, so the request itself is unchanged.
class CohortListController extends ChangeNotifier {
  CohortListController({required this._repository, this.courseId});

  final CohortRepository _repository;

  /// Restricts [cohorts] to this course. Null shows every cohort, the
  /// screen's original behaviour.
  final int? courseId;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  List<Cohort> _cohorts = const [];
  String? _errorMessage;

  bool get loading => _loading;
  List<Cohort> get cohorts => _cohorts;

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts.
  String? get errorMessage => _errorMessage;

  /// True once a fetch has *completed* successfully and returned nothing.
  /// Never true while [loading] or while [errorMessage] is set.
  bool get isEmpty =>
      _hasLoadedOnce && !_loading && _errorMessage == null && _cohorts.isEmpty;

  /// Fetches the list. Safe to call again — retry or pull-to-refresh — while
  /// a previous call is still in flight.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      final fetched = await _repository.getCohorts();
      _cohorts = courseId == null
          ? fetched
          : fetched.where((cohort) => cohort.courseId == courseId).toList();
    } on ApiFailure catch (failure) {
      _cohorts = const [];
      _errorMessage = _messageFor(failure.kind);
    } catch (_) {
      _cohorts = const [];
      _errorMessage = CohortListStrings.unexpectedError;
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
      _notify();
    }
  }

  static String _messageFor(ApiFailureKind kind) => switch (kind) {
    ApiFailureKind.network => CohortListStrings.networkError,
    ApiFailureKind.server => CohortListStrings.serverError,
    ApiFailureKind.notFound => CohortListStrings.unexpectedError,
    ApiFailureKind.unexpected => CohortListStrings.unexpectedError,
  };

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
