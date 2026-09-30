import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_controller.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = CourseExerciseDetailController(
      repository: FakeCourseLearningRepository(),
      lessonId: 204,
    );

    expect(controller.loading, isFalse);
    expect(controller.exercise, isNull);
    expect(controller.errorMessage, isNull);
  });

  test('remembers which lesson id it was built for', () {
    final controller = CourseExerciseDetailController(
      repository: FakeCourseLearningRepository(),
      lessonId: 204,
    );

    expect(controller.lessonId, 204);
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeCourseLearningRepository(holdExercise: true);
    final controller = CourseExerciseDetailController(
      repository: repository,
      lessonId: 204,
    );

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);

    repository.releaseExercise();
    await pending;
    expect(controller.loading, isFalse);
  });

  test('calls the repository with the controller\'s own lesson id', () async {
    final repository = FakeCourseLearningRepository();
    final controller = CourseExerciseDetailController(
      repository: repository,
      lessonId: 205,
    );

    await controller.load();

    expect(repository.exerciseCalls, [205]);
  });

  test('holds the fetched exercise on success', () async {
    final exercise = sampleExercise(lessonId: 204);
    final controller = CourseExerciseDetailController(
      repository: FakeCourseLearningRepository(exercise: exercise),
      lessonId: 204,
    );

    await controller.load();

    expect(controller.exercise, exercise);
    expect(controller.errorMessage, isNull);
  });

  test('a failure becomes its own copy, with no exercise', () async {
    for (final kind in CourseLearningFailureKind.values) {
      final controller = CourseExerciseDetailController(
        repository: FakeCourseLearningRepository(
          exerciseFailure: CourseLearningFailure(kind),
        ),
        lessonId: 204,
      );

      await controller.load();

      expect(
        controller.errorMessage,
        CourseLearningStrings.messageFor(kind),
        reason: kind.name,
      );
      expect(controller.exercise, isNull, reason: kind.name);
      expect(controller.loading, isFalse, reason: kind.name);
    }
  });

  test('409 lesson_locked reads as the generic copy, not success', () async {
    final controller = CourseExerciseDetailController(
      repository: FakeCourseLearningRepository(
        exerciseFailure: const CourseLearningFailure(
          CourseLearningFailureKind.locked,
        ),
      ),
      lessonId: 204,
    );

    await controller.load();

    expect(controller.exercise, isNull);
    expect(controller.errorMessage, CourseLearningStrings.unexpectedError);
  });

  test('an unexpected error reads as the generic copy', () async {
    final controller = CourseExerciseDetailController(
      repository: _ThrowingRepository(),
      lessonId: 204,
    );

    await controller.load();

    expect(controller.errorMessage, CourseLearningStrings.unexpectedError);
  });

  test('a retry recovers, clearing the error as it starts', () async {
    final repository = FakeCourseLearningRepository(
      exerciseFailure: const CourseLearningFailure(
        CourseLearningFailureKind.network,
      ),
    );
    final controller = CourseExerciseDetailController(
      repository: repository,
      lessonId: 204,
    );
    await controller.load();
    expect(controller.errorMessage, CourseLearningStrings.networkError);

    repository
      ..exerciseFailure = null
      ..holdExercise = true;
    final retry = controller.load();
    await Future<void>.delayed(Duration.zero);
    // The old message is gone while the retry is in flight.
    expect(controller.errorMessage, isNull);
    expect(controller.loading, isTrue);

    repository.releaseExercise();
    await retry;

    expect(controller.errorMessage, isNull);
    expect(controller.exercise, isNotNull);
    expect(repository.exerciseCalls, [204, 204]);
  });

  test('does not notify after being disposed', () async {
    final repository = FakeCourseLearningRepository(holdExercise: true);
    final controller = CourseExerciseDetailController(
      repository: repository,
      lessonId: 204,
    );

    final pending = controller.load();
    controller.dispose();
    repository.releaseExercise();

    // Would throw "used after being disposed" if the guard were missing.
    await pending;
  });

  test('does not notify after being disposed, on failure either', () async {
    final repository = FakeCourseLearningRepository(
      holdExercise: true,
      exerciseFailure: const CourseLearningFailure(
        CourseLearningFailureKind.server,
      ),
    );
    final controller = CourseExerciseDetailController(
      repository: repository,
      lessonId: 204,
    );

    final pending = controller.load();
    controller.dispose();
    repository.releaseExercise();

    await pending;
  });
}

/// Throws something that is not a `CourseLearningFailure`.
class _ThrowingRepository extends FakeCourseLearningRepository {
  @override
  Future<CourseExercise> getExercise(int lessonId) async =>
      throw StateError('boom');
}
