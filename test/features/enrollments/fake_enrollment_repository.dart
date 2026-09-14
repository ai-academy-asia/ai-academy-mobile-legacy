import 'dart:async';

import 'package:aia_mobile/features/enrollments/domain/enrollment.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_repository.dart';

/// A repository the tests drive by hand. Same shape as
/// `FakeCohortRepository`: either returns an enrollment for the cohort asked
/// for, throws a chosen [EnrollmentFailure], or — when [hold] is set — waits
/// for [release], which is how the in-flight state gets observed.
class FakeEnrollmentRepository implements EnrollmentRepository {
  FakeEnrollmentRepository({this.failure, this.hold = false});

  /// Thrown instead of returning, when set.
  EnrollmentFailure? failure;

  /// When true, [enroll] blocks until [release] is called.
  bool hold;

  /// Every cohort id [enroll] was called with, in order — so a test can
  /// assert a double tap did not send two requests.
  final List<int> requests = [];

  Completer<void>? _gate;

  /// Lets a held [enroll] finish.
  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<Enrollment> enroll(int cohortId) async {
    requests.add(cohortId);

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    final failure = this.failure;
    if (failure != null) throw failure;

    return sampleEnrollment(cohortId: cohortId);
  }
}

/// A valid enrollment with every field the contract names. The values are
/// illustrative — the contract lists fields, not example values.
Enrollment sampleEnrollment({
  int id = 11,
  int studentId = 42,
  int cohortId = 1,
  int courseId = 6,
  String status = 'active',
  double progressPct = 0,
  String createdAt = '2026-09-14T09:30:00Z',
  String createdVia = 'self',
  String? completedAt,
  int? createdByAdminId,
}) => Enrollment(
  id: id,
  studentId: studentId,
  cohortId: cohortId,
  courseId: courseId,
  status: status,
  progressPct: progressPct,
  createdAt: createdAt,
  createdVia: createdVia,
  completedAt: completedAt,
  createdByAdminId: createdByAdminId,
);
