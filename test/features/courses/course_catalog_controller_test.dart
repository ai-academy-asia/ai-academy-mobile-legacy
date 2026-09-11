import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/features/courses/domain/course.dart';
import 'package:aia_mobile/features/courses/domain/course_repository.dart';
import 'package:aia_mobile/features/courses/presentation/course_catalog_controller.dart';
import 'package:aia_mobile/features/courses/presentation/course_catalog_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = CourseCatalogController(repository: FakeCourseRepository());

    expect(controller.loading, isFalse);
    expect(controller.courses, isEmpty);
    expect(controller.errorMessage, isNull);
    // isEmpty requires a completed, error-free fetch — an untouched controller
    // has not fetched anything yet, so it is not "empty", it is unstarted.
    expect(controller.isEmpty, isFalse);
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeCourseRepository(hold: true);
    final controller = CourseCatalogController(repository: repository);

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);

    expect(controller.loading, isTrue);
    expect(controller.isEmpty, isFalse, reason: 'not empty — still loading');

    repository.release();
    await pending;

    expect(controller.loading, isFalse);
  });

  test('holds the fetched list on success', () async {
    final courses = [sampleCourse(id: 1, slug: 'a'), sampleCourse(id: 2, slug: 'b')];
    final controller = CourseCatalogController(
      repository: FakeCourseRepository(courses: courses),
    );

    await controller.load();

    expect(controller.courses, courses);
    expect(controller.errorMessage, isNull);
    expect(controller.isEmpty, isFalse);
  });

  test('an empty catalog is reported through isEmpty, not as an error', () async {
    final controller = CourseCatalogController(
      repository: FakeCourseRepository(courses: const []),
    );

    await controller.load();

    expect(controller.courses, isEmpty);
    expect(controller.errorMessage, isNull);
    expect(controller.isEmpty, isTrue);
  });

  test('maps each ApiFailureKind to its own message', () async {
    final repository = FakeCourseRepository();
    final controller = CourseCatalogController(repository: repository);

    repository.failure = const ApiFailure(ApiFailureKind.network);
    await controller.load();
    expect(controller.errorMessage, CourseCatalogStrings.networkError);

    repository.failure = const ApiFailure(ApiFailureKind.server);
    await controller.load();
    expect(controller.errorMessage, CourseCatalogStrings.serverError);

    repository.failure = const ApiFailure(ApiFailureKind.unexpected);
    await controller.load();
    expect(controller.errorMessage, CourseCatalogStrings.unexpectedError);
  });

  test('a failure clears any previously loaded list', () async {
    final repository = FakeCourseRepository(courses: [sampleCourse()]);
    final controller = CourseCatalogController(repository: repository);
    await controller.load();
    expect(controller.courses, isNotEmpty);

    repository.failure = const ApiFailure(ApiFailureKind.server);
    await controller.load();

    expect(controller.courses, isEmpty);
    expect(controller.errorMessage, isNotNull);
    expect(
      controller.isEmpty,
      isFalse,
      reason: 'this is the error state, not the empty state',
    );
  });

  test('a retry that succeeds clears the previous error', () async {
    final repository = FakeCourseRepository(
      failure: const ApiFailure(ApiFailureKind.network),
    );
    final controller = CourseCatalogController(repository: repository);
    await controller.load();
    expect(controller.errorMessage, isNotNull);

    repository.failure = null;
    repository.courses = [sampleCourse()];
    await controller.load();

    expect(controller.errorMessage, isNull);
    expect(controller.courses, isNotEmpty);
  });

  test('an unrecognised exception still surfaces as a message, not a crash', () async {
    final controller = CourseCatalogController(repository: _ThrowsNonApiFailure());

    await controller.load();

    expect(controller.errorMessage, CourseCatalogStrings.unexpectedError);
  });

  test('notifies listeners on every state change', () async {
    final repository = FakeCourseRepository(courses: [sampleCourse()]);
    final controller = CourseCatalogController(repository: repository);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();

    // At least once for "loading started", once for "loading finished".
    expect(notifications, greaterThanOrEqualTo(2));
  });

  test('does not notify after being disposed', () async {
    final repository = FakeCourseRepository(hold: true);
    final controller = CourseCatalogController(repository: repository);

    final pending = controller.load();
    controller.dispose();
    repository.release();

    // Would throw "used after being disposed" if the guard were missing.
    await pending;
  });
}

/// A repository whose failure is not `ApiFailure` at all, so the controller's
/// catch-all branch — not the typed one — is what has to handle it.
class _ThrowsNonApiFailure implements CourseRepository {
  @override
  Future<List<Course>> getCourses() => throw StateError('boom');
}
