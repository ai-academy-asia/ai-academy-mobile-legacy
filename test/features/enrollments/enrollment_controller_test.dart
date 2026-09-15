import 'package:aia_mobile/features/enrollments/domain/enrollment.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_repository.dart';
import 'package:aia_mobile/features/enrollments/presentation/enrollment_controller.dart';
import 'package:aia_mobile/features/enrollments/presentation/enrollment_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_enrollment_repository.dart';

void main() {
  test('starts idle for every cohort', () {
    final controller = EnrollmentController(repository: FakeEnrollmentRepository());

    expect(controller.isEnrolling(1), isFalse);
    expect(controller.enrollmentFor(1), isNull);
    expect(controller.errorFor(1), isNull);
  });

  test('reports enrolling for that cohort only, while in flight', () async {
    final repository = FakeEnrollmentRepository(hold: true);
    final controller = EnrollmentController(repository: repository);

    final pending = controller.enroll(1);
    await Future<void>.delayed(Duration.zero);

    expect(controller.isEnrolling(1), isTrue);
    expect(controller.isEnrolling(2), isFalse);

    repository.release();
    await pending;

    expect(controller.isEnrolling(1), isFalse);
  });

  test('holds the created enrollment on success', () async {
    final controller = EnrollmentController(repository: FakeEnrollmentRepository());

    await controller.enroll(5);

    expect(controller.enrollmentFor(5)?.cohortId, 5);
    expect(controller.errorFor(5), isNull);
  });

  test('maps each EnrollmentFailureKind to its own message', () async {
    const expected = {
      EnrollmentFailureKind.sessionExpired: EnrollmentStrings.sessionExpired,
      EnrollmentFailureKind.rejected: EnrollmentStrings.rejected,
      EnrollmentFailureKind.network: EnrollmentStrings.networkError,
      EnrollmentFailureKind.server: EnrollmentStrings.serverError,
      EnrollmentFailureKind.unexpected: EnrollmentStrings.unexpectedError,
    };
    expect(expected.keys, unorderedEquals(EnrollmentFailureKind.values));

    final repository = FakeEnrollmentRepository();
    final controller = EnrollmentController(repository: repository);

    for (final MapEntry(key: kind, value: message) in expected.entries) {
      repository.failure = EnrollmentFailure(kind);
      await controller.enroll(1);
      expect(controller.errorFor(1), message, reason: kind.name);
      expect(controller.enrollmentFor(1), isNull, reason: kind.name);
    }
  });

  test('a failure on one cohort leaves the others alone', () async {
    final repository = FakeEnrollmentRepository();
    final controller = EnrollmentController(repository: repository);
    await controller.enroll(1);

    repository.failure = const EnrollmentFailure(EnrollmentFailureKind.rejected);
    await controller.enroll(2);

    expect(controller.enrollmentFor(1), isNotNull);
    expect(controller.errorFor(1), isNull);
    expect(controller.errorFor(2), EnrollmentStrings.rejected);
  });

  test('a retry that succeeds clears the previous error', () async {
    final repository = FakeEnrollmentRepository(
      failure: const EnrollmentFailure(EnrollmentFailureKind.network),
    );
    final controller = EnrollmentController(repository: repository);
    await controller.enroll(1);
    expect(controller.errorFor(1), isNotNull);

    repository.failure = null;
    await controller.enroll(1);

    expect(controller.errorFor(1), isNull);
    expect(controller.enrollmentFor(1), isNotNull);
  });

  test('a second tap while in flight sends no second request', () async {
    final repository = FakeEnrollmentRepository(hold: true);
    final controller = EnrollmentController(repository: repository);

    final first = controller.enroll(1);
    await Future<void>.delayed(Duration.zero);
    await controller.enroll(1);

    repository.release();
    await first;

    expect(repository.requests, [1]);
  });

  test('an enrolled cohort is not enrolled again', () async {
    final repository = FakeEnrollmentRepository();
    final controller = EnrollmentController(repository: repository);

    await controller.enroll(1);
    await controller.enroll(1);

    expect(repository.requests, [1]);
  });

  test('an unrecognised exception still surfaces as a message, not a crash', () async {
    final controller = EnrollmentController(repository: _ThrowsNonEnrollmentFailure());

    await controller.enroll(1);

    expect(controller.errorFor(1), EnrollmentStrings.unexpectedError);
    expect(controller.isEnrolling(1), isFalse);
  });

  test('notifies listeners when an attempt starts and when it ends', () async {
    final controller = EnrollmentController(repository: FakeEnrollmentRepository());
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.enroll(1);

    expect(notifications, 2);
  });

  test('does not notify after being disposed', () async {
    final repository = FakeEnrollmentRepository(hold: true);
    final controller = EnrollmentController(repository: repository);

    final pending = controller.enroll(1);
    controller.dispose();
    repository.release();

    await pending;
  });
}

/// A repository whose failure is not `EnrollmentFailure` at all, so the
/// controller's catch-all branch — not the typed one — has to handle it.
class _ThrowsNonEnrollmentFailure implements EnrollmentRepository {
  @override
  Future<Enrollment> enroll(int cohortId) => throw StateError('boom');
}
