import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort_repository.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_controller.dart';
import 'package:aia_mobile/features/cohorts/presentation/cohort_list_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../courses/fake_course_repository.dart';
import 'fake_cohort_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = CohortListController(
      courseRepository: FakeCourseRepository(),
      repository: FakeCohortRepository(),
    );

    expect(controller.loading, isFalse);
    expect(controller.cohorts, isEmpty);
    expect(controller.errorMessage, isNull);
    expect(controller.isEmpty, isFalse);
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeCohortRepository(hold: true);
    final controller = CohortListController(
      courseRepository: FakeCourseRepository(),
      repository: repository,
    );

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(controller.loading, isTrue);
    expect(controller.isEmpty, isFalse, reason: 'not empty — still loading');

    repository.release();
    await pending;

    expect(controller.loading, isFalse);
  });

  test('holds the fetched list on success', () async {
    final cohorts = [
      sampleCohort(id: 1, name: 'A'),
      sampleCohort(id: 2, name: 'B'),
    ];
    final controller = CohortListController(
      courseRepository: FakeCourseRepository(),
      repository: FakeCohortRepository(cohorts: cohorts),
    );

    await controller.load();

    expect(controller.cohorts, cohorts);
    expect(controller.errorMessage, isNull);
    expect(controller.isEmpty, isFalse);
  });

  test('an empty list is reported through isEmpty, not as an error', () async {
    final controller = CohortListController(
      courseRepository: FakeCourseRepository(),
      repository: FakeCohortRepository(cohorts: const []),
    );

    await controller.load();

    expect(controller.cohorts, isEmpty);
    expect(controller.errorMessage, isNull);
    expect(controller.isEmpty, isTrue);
  });

  test('maps each ApiFailureKind to its own message', () async {
    final repository = FakeCohortRepository();
    final controller = CohortListController(
      courseRepository: FakeCourseRepository(),
      repository: repository,
    );

    repository.failure = const ApiFailure(ApiFailureKind.network);
    await controller.load();
    expect(controller.errorMessage, CohortListStrings.networkError);

    repository.failure = const ApiFailure(ApiFailureKind.server);
    await controller.load();
    expect(controller.errorMessage, CohortListStrings.serverError);

    repository.failure = const ApiFailure(ApiFailureKind.unexpected);
    await controller.load();
    expect(controller.errorMessage, CohortListStrings.unexpectedError);
  });

  test('a failure clears any previously loaded list', () async {
    final repository = FakeCohortRepository(cohorts: [sampleCohort()]);
    final controller = CohortListController(
      courseRepository: FakeCourseRepository(),
      repository: repository,
    );
    await controller.load();
    expect(controller.cohorts, isNotEmpty);

    repository.failure = const ApiFailure(ApiFailureKind.server);
    await controller.load();

    expect(controller.cohorts, isEmpty);
    expect(controller.errorMessage, isNotNull);
    expect(
      controller.isEmpty,
      isFalse,
      reason: 'this is the error state, not the empty state',
    );
  });

  test('a retry that succeeds clears the previous error', () async {
    final repository = FakeCohortRepository(
      failure: const ApiFailure(ApiFailureKind.network),
    );
    final controller = CohortListController(
      courseRepository: FakeCourseRepository(),
      repository: repository,
    );
    await controller.load();
    expect(controller.errorMessage, isNotNull);

    repository.failure = null;
    repository.cohorts = [sampleCohort()];
    await controller.load();

    expect(controller.errorMessage, isNull);
    expect(controller.cohorts, isNotEmpty);
  });

  test(
    'an unrecognised exception still surfaces as a message, not a crash',
    () async {
      final controller = CohortListController(
        courseRepository: FakeCourseRepository(),
        repository: _ThrowsNonApiFailure(),
      );

      await controller.load();

      expect(controller.errorMessage, CohortListStrings.unexpectedError);
    },
  );

  test('notifies listeners on every state change', () async {
    final repository = FakeCohortRepository(cohorts: [sampleCohort()]);
    final controller = CohortListController(
      courseRepository: FakeCourseRepository(),
      repository: repository,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();

    expect(notifications, greaterThanOrEqualTo(2));
  });

  group('course filter', () {
    test('keeps only cohorts matching courseId when one is given', () async {
      final cohorts = [
        sampleCohort(id: 1, courseId: 6),
        sampleCohort(id: 2, courseId: 9),
        sampleCohort(id: 3, courseId: 6),
      ];
      final controller = CohortListController(
        courseRepository: FakeCourseRepository(),
        repository: FakeCohortRepository(cohorts: cohorts),
        courseId: 6,
      );

      await controller.load();

      expect(controller.cohorts.map((cohort) => cohort.id), [1, 3]);
    });

    test('keeps every cohort when no courseId is given', () async {
      final cohorts = [
        sampleCohort(id: 1, courseId: 6),
        sampleCohort(id: 2, courseId: 9),
      ];
      final controller = CohortListController(
        courseRepository: FakeCourseRepository(),
        repository: FakeCohortRepository(cohorts: cohorts),
      );

      await controller.load();

      expect(controller.cohorts, cohorts);
    });

    test('isEmpty is true when no cohort matches the given courseId', () async {
      final controller = CohortListController(
        courseRepository: FakeCourseRepository(),
        repository: FakeCohortRepository(
          cohorts: [sampleCohort(id: 1, courseId: 9)],
        ),
        courseId: 6,
      );

      await controller.load();

      expect(controller.cohorts, isEmpty);
      expect(controller.errorMessage, isNull);
      expect(controller.isEmpty, isTrue);
    });
  });

  test('does not notify after being disposed', () async {
    final repository = FakeCohortRepository(hold: true);
    final controller = CohortListController(
      courseRepository: FakeCourseRepository(),
      repository: repository,
    );

    final pending = controller.load();
    controller.dispose();
    repository.release();

    await pending;
  });

  group('courseSlugFor', () {
    test('resolves the catalog slug when the cohort\'s own is stale', () async {
      // Reproduces the real, confirmed drift — see `resolveCohortCourse`'s
      // own doc comment: `sampleCohort`'s embedded course (id 6, slug
      // "summer-bootcamp-2027") shares its title with `sampleCourse`'s
      // catalog entry (id 4, slug "summer-bootcamp").
      final controller = CohortListController(
        repository: FakeCohortRepository(),
        courseRepository: FakeCourseRepository(courses: [sampleCourse()]),
      );
      await controller.load();

      expect(controller.courseSlugFor(sampleCohort()), 'summer-bootcamp');
    });

    test('falls back to the cohort\'s own slug when nothing matches', () async {
      final controller = CohortListController(
        repository: FakeCohortRepository(),
        courseRepository: FakeCourseRepository(courses: const []),
      );
      await controller.load();

      expect(controller.courseSlugFor(sampleCohort()), 'summer-bootcamp-2027');
    });

    test('a failed GET /courses falls back, not to an exception', () async {
      final controller = CohortListController(
        repository: FakeCohortRepository(),
        courseRepository: FakeCourseRepository(
          failure: const ApiFailure(ApiFailureKind.server),
        ),
      );
      await controller.load();

      expect(controller.courseSlugFor(sampleCohort()), 'summer-bootcamp-2027');
    });
  });
}

/// A repository whose failure is not `ApiFailure` at all, so the controller's
/// catch-all branch — not the typed one — is what has to handle it.
class _ThrowsNonApiFailure implements CohortRepository {
  @override
  Future<List<Cohort>> getCohorts() => throw StateError('boom');
}
