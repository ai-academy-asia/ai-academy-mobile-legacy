import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_path.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_quiz.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';
import 'package:aia_mobile/features/course_learning/domain/material_download.dart';
import 'package:aia_mobile/features/course_learning/domain/uploaded_file.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_controller.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

/// Throws something that is *not* a `CourseLearningFailure`, to prove the
/// controller's own `catch (_)` arm rather than only the typed one — a
/// repository bug must not escape through `build`.
class _ThrowingRepository implements CourseLearningRepository {
  _ThrowingRepository(this._delegate);

  final CourseLearningRepository _delegate;

  @override
  Future<CourseLearningPath> getCourseLearning(String courseSlug) =>
      Future.error(StateError('something the controller has no case for'));

  @override
  Future<List<Lesson>> getLessons(int moduleId) =>
      _delegate.getLessons(moduleId);

  @override
  Future<CourseExercise> getExercise(int moduleId) =>
      _delegate.getExercise(moduleId);

  @override
  Future<CourseExerciseNote> saveNote(int lessonId, String content) =>
      _delegate.saveNote(lessonId, content);

  @override
  Future<MaterialDownload> getMaterialDownload(int materialId) =>
      _delegate.getMaterialDownload(materialId);

  @override
  Future<AssignmentSubmission> submitAssignment(
    int assignmentId, {
    String? link,
    String? description,
    int? fileId,
  }) => _delegate.submitAssignment(
    assignmentId,
    link: link,
    description: description,
    fileId: fileId,
  );

  @override
  Future<UploadedFile> uploadFile({
    required String fileName,
    required List<int> bytes,
  }) => _delegate.uploadFile(fileName: fileName, bytes: bytes);

  @override
  Future<QuizAttempt> startQuizAttempt(int quizId) =>
      _delegate.startQuizAttempt(quizId);

  @override
  Future<QuizAnswerResult> answerQuizQuestion(
    int attemptId, {
    required int questionId,
    required int optionId,
  }) => _delegate.answerQuizQuestion(
    attemptId,
    questionId: questionId,
    optionId: optionId,
  );

  @override
  Future<QuizAttemptResult> finishQuizAttempt(int attemptId) =>
      _delegate.finishQuizAttempt(attemptId);

  @override
  Future<QuizAttemptResult> getQuizAttempt(int attemptId) =>
      _delegate.getQuizAttempt(attemptId);
}

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

  group('a failed load', () {
    CourseLearningController controllerFailingWith(
      CourseLearningFailureKind kind,
    ) => CourseLearningController(
      repository: FakeCourseLearningRepository(
        failure: CourseLearningFailure(kind),
      ),
      courseSlug: 'summer-bootcamp-2027',
    );

    test('turns each failure kind into that kind\'s own copy', () async {
      for (final kind in CourseLearningFailureKind.values) {
        final controller = controllerFailingWith(kind);

        await controller.load();

        expect(
          controller.errorMessage,
          CourseLearningStrings.messageFor(kind),
          reason: kind.name,
        );
      }
    });

    test('stops loading and holds no path', () async {
      final controller = controllerFailingWith(
        CourseLearningFailureKind.network,
      );

      await controller.load();

      expect(controller.loading, isFalse);
      expect(controller.path, isNull);
    });

    test('an unexpected exception still reaches the screen as copy', () async {
      final repository = FakeCourseLearningRepository();
      final controller = CourseLearningController(
        repository: _ThrowingRepository(repository),
        courseSlug: 'summer-bootcamp-2027',
      );

      await controller.load();

      expect(controller.errorMessage, CourseLearningStrings.unexpectedError);
      expect(controller.path, isNull);
    });

    test(
      'a retry clears the message before the next attempt resolves',
      () async {
        final repository = FakeCourseLearningRepository(
          failure: const CourseLearningFailure(
            CourseLearningFailureKind.network,
          ),
        );
        final controller = CourseLearningController(
          repository: repository,
          courseSlug: 'summer-bootcamp-2027',
        );
        await controller.load();
        expect(controller.errorMessage, isNotNull);

        // The retry succeeds: the message must not survive it.
        repository.failure = null;
        repository.hold = true;
        final pending = controller.load();
        await Future<void>.delayed(Duration.zero);
        expect(controller.errorMessage, isNull);
        expect(controller.loading, isTrue);

        repository.release();
        await pending;
        expect(controller.errorMessage, isNull);
        expect(controller.path, isNotNull);
      },
    );
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
