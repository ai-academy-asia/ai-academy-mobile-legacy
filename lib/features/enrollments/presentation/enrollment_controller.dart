import 'package:flutter/foundation.dart';

import '../domain/enrollment.dart';
import '../domain/enrollment_failure.dart';
import '../domain/enrollment_repository.dart';
import 'enrollment_strings.dart';

/// Tracks the enroll action for each cohort on screen.
///
/// Keyed by cohort id rather than holding one state, because the action sits
/// on every card of a list: one card in flight, or failed, says nothing about
/// the others. Otherwise the same shape as `CohortListController` — a plain
/// [ChangeNotifier], a `_disposed` guard, one fixed string per failure kind.
///
/// Enrollments are remembered for as long as the controller lives, so a
/// pull-to-refresh of the list does not put an enrolled cohort's button back.
/// Nothing recovers them after a restart: no endpoint listing a student's
/// enrollments is confirmed.
class EnrollmentController extends ChangeNotifier {
  EnrollmentController({required this._repository});

  final EnrollmentRepository _repository;

  bool _disposed = false;
  final Set<int> _inFlight = {};
  final Map<int, Enrollment> _enrollments = {};
  final Map<int, String> _errors = {};

  bool isEnrolling(int cohortId) => _inFlight.contains(cohortId);

  /// The enrollment the API created for [cohortId], once it has.
  Enrollment? enrollmentFor(int cohortId) => _enrollments[cohortId];

  /// Set only when the most recent attempt for [cohortId] failed. Cleared as
  /// soon as another attempt starts.
  String? errorFor(int cohortId) => _errors[cohortId];

  /// Enrolls in [cohortId]. Does nothing while an attempt for it is already in
  /// flight, or once it has succeeded — a double tap must not send two
  /// requests.
  Future<void> enroll(int cohortId) async {
    if (_inFlight.contains(cohortId) || _enrollments.containsKey(cohortId)) return;

    _inFlight.add(cohortId);
    _errors.remove(cohortId);
    _notify();

    try {
      _enrollments[cohortId] = await _repository.enroll(cohortId);
    } on EnrollmentFailure catch (failure) {
      _errors[cohortId] = _messageFor(failure.kind);
    } catch (_) {
      _errors[cohortId] = EnrollmentStrings.unexpectedError;
    } finally {
      _inFlight.remove(cohortId);
      _notify();
    }
  }

  static String _messageFor(EnrollmentFailureKind kind) => switch (kind) {
    EnrollmentFailureKind.sessionExpired => EnrollmentStrings.sessionExpired,
    EnrollmentFailureKind.rejected => EnrollmentStrings.rejected,
    EnrollmentFailureKind.network => EnrollmentStrings.networkError,
    EnrollmentFailureKind.server => EnrollmentStrings.serverError,
    EnrollmentFailureKind.unexpected => EnrollmentStrings.unexpectedError,
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
