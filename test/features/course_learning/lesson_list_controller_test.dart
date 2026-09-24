import 'package:aia_mobile/features/course_learning/presentation/lesson_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = LessonListController(
      repository: FakeCourseLearningRepository(),
      moduleId: 2,
    );

    expect(controller.loading, isFalse);
    expect(controller.lessons, isEmpty);
  });

  test('remembers which module id it was built for', () {
    final controller = LessonListController(
      repository: FakeCourseLearningRepository(),
      moduleId: 2,
    );

    expect(controller.moduleId, 2);
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeCourseLearningRepository(holdLessons: true);
    final controller = LessonListController(
      repository: repository,
      moduleId: 2,
    );

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);

    repository.releaseLessons();
    await pending;
    expect(controller.loading, isFalse);
  });

  test('calls the repository with the controller\'s own module id', () async {
    final repository = FakeCourseLearningRepository();
    final controller = LessonListController(
      repository: repository,
      moduleId: 3,
    );

    await controller.load();

    expect(repository.lessonCalls, [3]);
  });

  test('holds the fetched lessons on success', () async {
    final lessons = sampleLessons(moduleId: 2);
    final controller = LessonListController(
      repository: FakeCourseLearningRepository(lessons: lessons),
      moduleId: 2,
    );

    await controller.load();

    expect(controller.lessons, lessons);
  });

  test('does not notify after being disposed', () async {
    final repository = FakeCourseLearningRepository(holdLessons: true);
    final controller = LessonListController(
      repository: repository,
      moduleId: 2,
    );

    final pending = controller.load();
    controller.dispose();
    repository.releaseLessons();

    // Would throw "used after being disposed" if the guard were missing.
    await pending;
  });
}
