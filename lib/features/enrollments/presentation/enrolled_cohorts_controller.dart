import 'package:flutter/foundation.dart';

import '../domain/enrolled_cohorts_repository.dart';
import '../domain/enrollment_failure.dart';
import 'enrollment_strings.dart';

/// Loads the signed-in student's already-enrolled cohort ids, and the progress
/// each one's `GET /me/cohorts` entry carries.
///
/// Same shape as `CohortListController`: a plain [ChangeNotifier], a
/// `_disposed` guard, one fixed string per [EnrollmentFailureKind] (via
/// [EnrollmentStrings.messageFor], shared with `EnrollmentController`), and
/// [hasLoadedOnce] that says whether the first fetch has actually completed.
///
/// A separate controller from `EnrollmentController` for the same reason
/// `EnrolledCohortsRepository` is a separate interface: this reads what
/// already exists rather than creating something new, on a schedule of its
/// own (once per screen load, not once per tap).
class EnrolledCohortsController extends ChangeNotifier {
  EnrolledCohortsController({required this._repository});

  final EnrolledCohortsRepository _repository;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  Set<int> _enrolledCohortIds = const {};
  Map<int, double> _progressByCohortId = const {};
  String? _errorMessage;

  bool get loading => _loading;

  /// True once a fetch has *completed*, successfully or not.
  bool get hasLoadedOnce => _hasLoadedOnce;

  Set<int> get enrolledCohortIds => _enrolledCohortIds;

  /// The progress percentage `GET /me/cohorts` reported for [cohortId], or
  /// null when that entry carried none — or the cohort is not enrolled, or no
  /// fetch has succeeded. Never zero-filled: no figure is not 0%.
  double? progressFor(int cohortId) => _progressByCohortId[cohortId];

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts.
  String? get errorMessage => _errorMessage;

  /// Whether [cohortId] is among the student's enrolled cohorts, as of the
  /// last successful fetch.
  ///
  /// False before the first fetch completes and after a failed one — the safe
  /// default, since attempting to enroll again in an already-enrolled cohort
  /// is refused by the enroll endpoint rather than silently duplicated.
  bool isEnrolled(int cohortId) => _enrolledCohortIds.contains(cohortId);

  /// Fetches the list. Safe to call again — retry or pull-to-refresh — while
  /// a previous call is still in flight.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      // The one request that yields both the ids and the progress figures,
      // rather than `getEnrolledCohortIds` plus a second call.
      final summaries = await _repository.getEnrolledCohorts();
      _enrolledCohortIds = {for (final entry in summaries) entry.cohortId};
      _progressByCohortId = {
        for (final entry in summaries) entry.cohortId: ?entry.progressPct,
      };
    } on EnrollmentFailure catch (failure) {
      _enrolledCohortIds = const {};
      _progressByCohortId = const {};
      _errorMessage = EnrollmentStrings.messageFor(failure.kind);
    } catch (_) {
      _enrolledCohortIds = const {};
      _progressByCohortId = const {};
      _errorMessage = EnrollmentStrings.unexpectedError;
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
