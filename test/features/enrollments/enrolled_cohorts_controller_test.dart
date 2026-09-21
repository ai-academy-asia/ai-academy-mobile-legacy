import 'package:aia_mobile/features/enrollments/domain/enrolled_cohorts_repository.dart';
import 'package:aia_mobile/features/enrollments/domain/enrollment_failure.dart';
import 'package:aia_mobile/features/enrollments/presentation/enrolled_cohorts_controller.dart';
import 'package:aia_mobile/features/enrollments/presentation/enrollment_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_enrolled_cohorts_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = EnrolledCohortsController(
      repository: FakeEnrolledCohortsRepository(),
    );

    expect(controller.loading, isFalse);
    expect(controller.hasLoadedOnce, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.enrolledCohortIds, isEmpty);
    expect(controller.isEnrolled(1), isFalse);
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeEnrolledCohortsRepository(hold: true);
    final controller = EnrolledCohortsController(repository: repository);

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(controller.loading, isTrue);
    expect(controller.hasLoadedOnce, isFalse);

    repository.release();
    await pending;

    expect(controller.loading, isFalse);
    expect(controller.hasLoadedOnce, isTrue);
  });

  test('holds the fetched ids on success', () async {
    final controller = EnrolledCohortsController(
      repository: FakeEnrolledCohortsRepository(enrolledCohortIds: {1, 3}),
    );

    await controller.load();

    expect(controller.enrolledCohortIds, {1, 3});
    expect(controller.isEnrolled(1), isTrue);
    expect(controller.isEnrolled(2), isFalse);
    expect(controller.isEnrolled(3), isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('maps each EnrollmentFailureKind to its own message', () async {
    final repository = FakeEnrolledCohortsRepository();
    final controller = EnrolledCohortsController(repository: repository);

    for (final kind in EnrollmentFailureKind.values) {
      repository.failure = EnrollmentFailure(kind);
      await controller.load();
      expect(
        controller.errorMessage,
        EnrollmentStrings.messageFor(kind),
        reason: kind.name,
      );
    }
  });

  test(
    'a failure clears any previously loaded ids and defaults to unenrolled',
    () async {
      final repository = FakeEnrolledCohortsRepository(enrolledCohortIds: {1});
      final controller = EnrolledCohortsController(repository: repository);
      await controller.load();
      expect(controller.isEnrolled(1), isTrue);

      repository.failure = const EnrollmentFailure(
        EnrollmentFailureKind.server,
      );
      await controller.load();

      expect(controller.isEnrolled(1), isFalse);
      expect(controller.enrolledCohortIds, isEmpty);
      expect(controller.errorMessage, isNotNull);
    },
  );

  test('a retry that succeeds clears the previous error', () async {
    final repository = FakeEnrolledCohortsRepository(
      failure: const EnrollmentFailure(EnrollmentFailureKind.network),
    );
    final controller = EnrolledCohortsController(repository: repository);
    await controller.load();
    expect(controller.errorMessage, isNotNull);

    repository.failure = null;
    repository.enrolledCohortIds = {5};
    await controller.load();

    expect(controller.errorMessage, isNull);
    expect(controller.isEnrolled(5), isTrue);
  });

  test(
    'an unrecognised exception still surfaces as a message, not a crash',
    () async {
      final controller = EnrolledCohortsController(
        repository: _ThrowsNonEnrollmentFailure(),
      );

      await controller.load();

      expect(controller.errorMessage, EnrollmentStrings.unexpectedError);
      expect(controller.loading, isFalse);
    },
  );

  test('notifies listeners on every state change', () async {
    final repository = FakeEnrolledCohortsRepository(enrolledCohortIds: {1});
    final controller = EnrolledCohortsController(repository: repository);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();

    expect(notifications, greaterThanOrEqualTo(2));
  });

  test('does not notify after being disposed', () async {
    final repository = FakeEnrolledCohortsRepository(hold: true);
    final controller = EnrolledCohortsController(repository: repository);

    final pending = controller.load();
    controller.dispose();
    repository.release();

    await pending;
  });

  test(
    'holds the progress each entry carried, and none for one without',
    () async {
      final controller = EnrolledCohortsController(
        repository: FakeEnrolledCohortsRepository(
          enrolledCohorts: const [
            EnrolledCohortSummary(cohortId: 1, progressPct: 42.5),
            EnrolledCohortSummary(cohortId: 2),
            EnrolledCohortSummary(cohortId: 3, progressPct: 0),
          ],
        ),
      );

      await controller.load();

      expect(controller.enrolledCohortIds, {1, 2, 3});
      expect(controller.progressFor(1), 42.5);
      // No figure is null, not 0.
      expect(controller.progressFor(2), isNull);
      // A reported 0 is still a figure.
      expect(controller.progressFor(3), 0);
      // Not enrolled at all.
      expect(controller.progressFor(9), isNull);
    },
  );

  test('a failed reload forgets the progress it held', () async {
    final repository = FakeEnrolledCohortsRepository(
      enrolledCohorts: const [
        EnrolledCohortSummary(cohortId: 1, progressPct: 80),
      ],
    );
    final controller = EnrolledCohortsController(repository: repository);
    await controller.load();
    expect(controller.progressFor(1), 80);

    repository.failure = const EnrollmentFailure(EnrollmentFailureKind.network);
    await controller.load();

    expect(controller.progressFor(1), isNull);
    expect(controller.enrolledCohortIds, isEmpty);
  });
}

/// A repository whose failure is not `EnrollmentFailure` at all, so the
/// controller's catch-all branch — not the typed one — has to handle it.
class _ThrowsNonEnrollmentFailure implements EnrolledCohortsRepository {
  @override
  Future<Set<int>> getEnrolledCohortIds() => throw StateError('boom');

  @override
  Future<List<EnrolledCohortSummary>> getEnrolledCohorts() =>
      throw StateError('boom');
}
