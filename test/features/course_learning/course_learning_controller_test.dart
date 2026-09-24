import 'package:aia_mobile/features/course_learning/presentation/course_learning_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = CourseLearningController(
      repository: FakeCourseLearningRepository(),
      courseSlug: 'how-ai-works',
    );

    expect(controller.loading, isFalse);
    expect(controller.path, isNull);
  });

  test('remembers which slug it was built for', () {
    final controller = CourseLearningController(
      repository: FakeCourseLearningRepository(),
      courseSlug: 'how-ai-works',
    );

    expect(controller.courseSlug, 'how-ai-works');
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeCourseLearningRepository(hold: true);
    final controller = CourseLearningController(
      repository: repository,
      courseSlug: 'how-ai-works',
    );

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);

    repository.release();
    await pending;
    expect(controller.loading, isFalse);
  });

  test('calls the repository with the controller\'s own slug', () async {
    final repository = FakeCourseLearningRepository();
    final controller = CourseLearningController(
      repository: repository,
      courseSlug: 'how-ai-works',
    );

    await controller.load();

    expect(repository.calls, ['how-ai-works']);
  });

  test('holds the fetched path on success', () async {
    final path = samplePath(courseSlug: 'how-ai-works');
    final controller = CourseLearningController(
      repository: FakeCourseLearningRepository(path: path),
      courseSlug: 'how-ai-works',
    );

    await controller.load();

    expect(controller.path, path);
  });

  test('does not notify after being disposed', () async {
    final repository = FakeCourseLearningRepository(hold: true);
    final controller = CourseLearningController(
      repository: repository,
      courseSlug: 'how-ai-works',
    );

    final pending = controller.load();
    controller.dispose();
    repository.release();

    // Would throw "used after being disposed" if the guard were missing.
    await pending;
  });
}
