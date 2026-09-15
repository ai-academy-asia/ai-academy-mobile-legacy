import 'dart:async';

import 'package:aia_mobile/features/enrollments/domain/enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';

/// A repository the tests drive by hand. Same shape as
/// `FakeEnrollmentRepository`: either returns [enrolledCohortIds], throws a
/// chosen [EnrollmentFailure], or — when [hold] is set — waits for [release],
/// which is how the loading state gets observed while the request is still in
/// flight.
class FakeEnrolledCohortsRepository implements EnrolledCohortsRepository {
  FakeEnrolledCohortsRepository({
    this.enrolledCohortIds = const {},
    this.failure,
    this.hold = false,
  });

  /// Returned on success.
  Set<int> enrolledCohortIds;

  /// Thrown instead of returning, when set.
  EnrollmentFailure? failure;

  /// When true, [getEnrolledCohortIds] blocks until [release] is called.
  bool hold;

  /// How many times [getEnrolledCohortIds] has been called — so a test can
  /// assert a retry or a pull-to-refresh actually asked again.
  int callCount = 0;

  Completer<void>? _gate;

  /// Lets a held [getEnrolledCohortIds] finish.
  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<Set<int>> getEnrolledCohortIds() async {
    callCount++;

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    final failure = this.failure;
    if (failure != null) throw failure;

    return enrolledCohortIds;
  }
}
