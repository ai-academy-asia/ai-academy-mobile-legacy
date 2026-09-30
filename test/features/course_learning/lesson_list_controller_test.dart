import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
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
    expect(controller.errorMessage, isNull);
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

  test('a failure becomes its own copy, with no lessons', () async {
    for (final kind in CourseLearningFailureKind.values) {
      final controller = LessonListController(
        repository: FakeCourseLearningRepository(
          lessonsFailure: CourseLearningFailure(kind),
        ),
        moduleId: 2,
      );

      await controller.load();

      expect(
        controller.errorMessage,
        CourseLearningStrings.messageFor(kind),
        reason: kind.name,
      );
      expect(controller.lessons, isEmpty, reason: kind.name);
      expect(controller.loading, isFalse, reason: kind.name);
    }
  });

  test('an unexpected error reads as the generic copy', () async {
    final controller = LessonListController(
      repository: _ThrowingRepository(),
      moduleId: 2,
    );

    await controller.load();

    expect(controller.errorMessage, CourseLearningStrings.unexpectedError);
  });

  test('a retry recovers, clearing the error as it starts', () async {
    final repository = FakeCourseLearningRepository(
      lessonsFailure: const CourseLearningFailure(
        CourseLearningFailureKind.network,
      ),
    );
    final controller = LessonListController(
      repository: repository,
      moduleId: 2,
    );
    await controller.load();
    expect(controller.errorMessage, isNotNull);

    repository
      ..lessonsFailure = null
      ..holdLessons = true;
    final retry = controller.load();
    await Future<void>.delayed(Duration.zero);
    // The old message is gone while the retry is in flight.
    expect(controller.errorMessage, isNull);
    expect(controller.loading, isTrue);

    repository.releaseLessons();
    await retry;

    expect(controller.errorMessage, isNull);
    expect(controller.lessons, hasLength(3));
    expect(repository.lessonCalls, [2, 2]);
  });

  test('a failed reload drops the lessons it had', () async {
    final repository = FakeCourseLearningRepository();
    final controller = LessonListController(
      repository: repository,
      moduleId: 2,
    );
    await controller.load();
    expect(controller.lessons, isNotEmpty);

    repository.lessonsFailure = const CourseLearningFailure(
      CourseLearningFailureKind.server,
    );
    await controller.load();

    expect(controller.lessons, isEmpty);
    expect(controller.errorMessage, CourseLearningStrings.serverError);
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

  test('does not notify after being disposed, on failure either', () async {
    final repository = FakeCourseLearningRepository(
      holdLessons: true,
      lessonsFailure: const CourseLearningFailure(
        CourseLearningFailureKind.network,
      ),
    );
    final controller = LessonListController(
      repository: repository,
      moduleId: 2,
    );

    final pending = controller.load();
    controller.dispose();
    repository.releaseLessons();

    await pending;
  });
}

/// Throws something that is not a `CourseLearningFailure`.
class _ThrowingRepository extends FakeCourseLearningRepository {
  @override
  Future<List<Lesson>> getLessons(int moduleId) async =>
      throw StateError('boom');
}
