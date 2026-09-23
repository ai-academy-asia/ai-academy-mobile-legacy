import 'package:aia_mobile/core/api/api_failure.dart';
import 'package:aia_mobile/features/courses/domain/course.dart';
import 'package:aia_mobile/features/courses/domain/course_repository.dart';
import 'package:aia_mobile/features/courses/presentation/course_detail_controller.dart';
import 'package:aia_mobile/features/courses/presentation/course_detail_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = CourseDetailController(
      repository: FakeCourseRepository(),
      slug: 'summer-bootcamp',
    );

    expect(controller.loading, isFalse);
    expect(controller.course, isNull);
    expect(controller.errorMessage, isNull);
  });

  test('remembers which slug it was built for', () {
    final controller = CourseDetailController(
      repository: FakeCourseRepository(),
      slug: 'summer-bootcamp',
    );

    expect(controller.slug, 'summer-bootcamp');
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeCourseRepository(holdDetail: true);
    final controller = CourseDetailController(
      repository: repository,
      slug: 'summer-bootcamp',
    );

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);

    repository.releaseDetail();
    await pending;
    expect(controller.loading, isFalse);
  });

  test('calls the repository with the controller\'s own slug', () async {
    final repository = FakeCourseRepository();
    final controller = CourseDetailController(
      repository: repository,
      slug: 'ai-for-everyone',
    );

    await controller.load();

    expect(repository.detailCalls, ['ai-for-everyone']);
  });

  test('holds the fetched course on success', () async {
    final course = sampleCourse(slug: 'summer-bootcamp');
    final controller = CourseDetailController(
      repository: FakeCourseRepository(courseDetail: course),
      slug: 'summer-bootcamp',
    );

    await controller.load();

    expect(controller.course, course);
    expect(controller.errorMessage, isNull);
  });

  test('notFound reads differently from every other failure', () async {
    final repository = FakeCourseRepository(
      detailFailure: const ApiFailure(ApiFailureKind.notFound),
    );
    final controller = CourseDetailController(
      repository: repository,
      slug: 'does-not-exist',
    );

    await controller.load();

    expect(controller.errorMessage, CourseDetailStrings.notFound);
    expect(controller.course, isNull);
  });

  test('maps every other ApiFailureKind to its own message', () async {
    final repository = FakeCourseRepository();
    final controller = CourseDetailController(
      repository: repository,
      slug: 'summer-bootcamp',
    );

    repository.detailFailure = const ApiFailure(ApiFailureKind.network);
    await controller.load();
    expect(controller.errorMessage, CourseDetailStrings.networkError);

    repository.detailFailure = const ApiFailure(ApiFailureKind.server);
    await controller.load();
    expect(controller.errorMessage, CourseDetailStrings.serverError);

    repository.detailFailure = const ApiFailure(ApiFailureKind.unexpected);
    await controller.load();
    expect(controller.errorMessage, CourseDetailStrings.unexpectedError);
  });

  test('a failure clears any previously loaded course', () async {
    final repository = FakeCourseRepository(courseDetail: sampleCourse());
    final controller = CourseDetailController(
      repository: repository,
      slug: 'summer-bootcamp',
    );
    await controller.load();
    expect(controller.course, isNotNull);

    repository.detailFailure = const ApiFailure(ApiFailureKind.server);
    await controller.load();

    expect(controller.course, isNull);
    expect(controller.errorMessage, isNotNull);
  });

  test('a retry that succeeds clears the previous error', () async {
    final repository = FakeCourseRepository(
      detailFailure: const ApiFailure(ApiFailureKind.network),
    );
    final controller = CourseDetailController(
      repository: repository,
      slug: 'summer-bootcamp',
    );
    await controller.load();
    expect(controller.errorMessage, isNotNull);

    repository.detailFailure = null;
    repository.courseDetail = sampleCourse();
    await controller.load();

    expect(controller.errorMessage, isNull);
    expect(controller.course, isNotNull);
  });

  test('an unrecognised exception still surfaces as a message, not a crash', () async {
    final controller = CourseDetailController(
      repository: _ThrowsNonApiFailure(),
      slug: 'summer-bootcamp',
    );

    await controller.load();

    expect(controller.errorMessage, CourseDetailStrings.unexpectedError);
  });

  test('does not notify after being disposed', () async {
    final repository = FakeCourseRepository(holdDetail: true);
    final controller = CourseDetailController(
      repository: repository,
      slug: 'summer-bootcamp',
    );

    final pending = controller.load();
    controller.dispose();
    repository.releaseDetail();

    // Would throw "used after being disposed" if the guard were missing.
    await pending;
  });
}

/// A repository whose failure is not `ApiFailure` at all, so the controller's
/// catch-all branch — not the typed one — is what has to handle it.
class _ThrowsNonApiFailure implements CourseRepository {
  @override
  Future<List<Course>> getCourses() => throw StateError('boom');

  @override
  Future<Course> getCourseDetail(String slug) => throw StateError('boom');
}
