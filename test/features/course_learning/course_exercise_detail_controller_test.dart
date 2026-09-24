import 'package:aia_mobile/features/course_learning/presentation/course_exercise_detail_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

void main() {
  test('starts idle, before load() is ever called', () {
    final controller = CourseExerciseDetailController(
      repository: FakeCourseLearningRepository(),
      moduleId: 2,
    );

    expect(controller.loading, isFalse);
    expect(controller.exercise, isNull);
  });

  test('remembers which module id it was built for', () {
    final controller = CourseExerciseDetailController(
      repository: FakeCourseLearningRepository(),
      moduleId: 2,
    );

    expect(controller.moduleId, 2);
  });

  test('reports loading while the request is in flight', () async {
    final repository = FakeCourseLearningRepository(holdExercise: true);
    final controller = CourseExerciseDetailController(
      repository: repository,
      moduleId: 2,
    );

    final pending = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);

    repository.releaseExercise();
    await pending;
    expect(controller.loading, isFalse);
  });

  test('calls the repository with the controller\'s own module id', () async {
    final repository = FakeCourseLearningRepository();
    final controller = CourseExerciseDetailController(
      repository: repository,
      moduleId: 3,
    );

    await controller.load();

    expect(repository.exerciseCalls, [3]);
  });

  test('holds the fetched exercise on success', () async {
    final exercise = sampleExercise(moduleId: 2);
    final controller = CourseExerciseDetailController(
      repository: FakeCourseLearningRepository(exercise: exercise),
      moduleId: 2,
    );

    await controller.load();

    expect(controller.exercise, exercise);
  });

  test('does not notify after being disposed', () async {
    final repository = FakeCourseLearningRepository(holdExercise: true);
    final controller = CourseExerciseDetailController(
      repository: repository,
      moduleId: 2,
    );

    final pending = controller.load();
    controller.dispose();
    repository.releaseExercise();

    // Would throw "used after being disposed" if the guard were missing.
    await pending;
  });
}
