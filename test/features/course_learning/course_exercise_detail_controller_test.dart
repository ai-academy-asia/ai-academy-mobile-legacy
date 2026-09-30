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

  group('saveNote', () {
    const serverNote = CourseExerciseNote(
      authorInitials: 'СД',
      authorName: 'Сараа Дорж',
      authorLabel: 'Me',
      message: 'Saved on the server.',
      timestampLabel: 'Today, 15:04',
    );

    Future<CourseExerciseDetailController> loaded(
      FakeCourseLearningRepository repository,
    ) async {
      final controller = CourseExerciseDetailController(
        repository: repository,
        lessonId: 204,
      );
      await controller.load();
      return controller;
    }

    test('a saved note leaves the lesson\'s assignment in place', () async {
      final assignment = CourseAssignment(
        id: 17,
        submission: AssignmentSubmission(
          id: 301,
          version: 1,
          status: AssignmentSubmissionStatus.submitted,
          submittedAt: DateTime.utc(2026, 8, 5, 3),
        ),
      );
      final controller = await loaded(
        FakeCourseLearningRepository(
          exercise: sampleExercise(lessonId: 204, assignment: assignment),
          savedNote: serverNote,
        ),
      );

      await controller.saveNote('A note');

      expect(controller.exercise!.note, serverNote);
      expect(controller.exercise!.assignment, same(assignment));
    });

    test('starts not saving, with no save error', () async {
      final controller = await loaded(FakeCourseLearningRepository());

      expect(controller.savingNote, isFalse);
      expect(controller.noteSaveErrorMessage, isNull);
    });

    test('reports saving while the request is in flight', () async {
      final repository = FakeCourseLearningRepository(holdSave: true);
      final controller = await loaded(repository);

      final pending = controller.saveNote('A note');
      await Future<void>.delayed(Duration.zero);
      expect(controller.savingNote, isTrue);

      repository.releaseSave();
      await pending;
      expect(controller.savingNote, isFalse);
    });

    test('a second save while one is in flight is ignored', () async {
      final repository = FakeCourseLearningRepository(holdSave: true);
      final controller = await loaded(repository);

      final first = controller.saveNote('First');
      await Future<void>.delayed(Duration.zero);
      expect(await controller.saveNote('Second'), isFalse);

      repository.releaseSave();
      await first;
      expect(repository.saveCalls, [(204, 'First')]);
    });

    test('success replaces the note with the repository\'s answer', () async {
      final repository = FakeCourseLearningRepository(
        exercise: sampleExercise(lessonId: 204, title: 'Давталт'),
        savedNote: serverNote,
      );
      final controller = await loaded(repository);

      final saved = await controller.saveNote('A note');

      expect(saved, isTrue);
      expect(repository.saveCalls, [(204, 'A note')]);
      expect(controller.exercise!.note, serverNote);
      // The rest of the lesson is untouched.
      expect(controller.exercise!.title, 'Давталт');
      expect(controller.errorMessage, isNull);
      expect(controller.noteSaveErrorMessage, isNull);
    });

    test('a failure becomes its own copy, and keeps the old note', () async {
      for (final kind in CourseLearningFailureKind.values) {
        final repository = FakeCourseLearningRepository(
          saveFailure: CourseLearningFailure(kind),
        );
        final controller = await loaded(repository);
        final before = controller.exercise!.note;

        final saved = await controller.saveNote('A note');

        expect(saved, isFalse, reason: kind.name);
        expect(
          controller.noteSaveErrorMessage,
          CourseLearningStrings.messageFor(kind),
          reason: kind.name,
        );
        expect(controller.exercise!.note, before, reason: kind.name);
        // A failed save is not a failed load: the lesson stays.
        expect(controller.errorMessage, isNull, reason: kind.name);
        expect(controller.savingNote, isFalse, reason: kind.name);
      }
    });

    test('the two validation codes read as their own copy', () async {
      final repository = FakeCourseLearningRepository(
        saveFailure: const CourseLearningFailure(
          CourseLearningFailureKind.contentRequired,
        ),
      );
      final controller = await loaded(repository);

      await controller.saveNote(' ');
      expect(
        controller.noteSaveErrorMessage,
        CourseLearningStrings.noteContentRequired,
      );

      repository.saveFailure = const CourseLearningFailure(
        CourseLearningFailureKind.contentTooLong,
      );
      await controller.saveNote('x' * 5001);
      expect(
        controller.noteSaveErrorMessage,
        CourseLearningStrings.noteContentTooLong,
      );
    });

    test('an unexpected error reads as the generic copy', () async {
      final controller = await loaded(_ThrowingRepository.onSave());

      expect(await controller.saveNote('A note'), isFalse);
      expect(
        controller.noteSaveErrorMessage,
        CourseLearningStrings.unexpectedError,
      );
    });

    test('a retry clears the error as it starts, and can succeed', () async {
      final repository = FakeCourseLearningRepository(
        savedNote: serverNote,
        saveFailure: const CourseLearningFailure(
          CourseLearningFailureKind.network,
        ),
      );
      final controller = await loaded(repository);
      await controller.saveNote('A note');
      expect(controller.noteSaveErrorMessage, isNotNull);

      repository
        ..saveFailure = null
        ..holdSave = true;
      final pending = controller.saveNote('A note');
      await Future<void>.delayed(Duration.zero);
      expect(controller.noteSaveErrorMessage, isNull);

      repository.releaseSave();
      expect(await pending, isTrue);
      expect(controller.exercise!.note, serverNote);
    });

    test('with no lesson loaded, nothing is sent', () async {
      final repository = FakeCourseLearningRepository();
      final controller = CourseExerciseDetailController(
        repository: repository,
        lessonId: 204,
      );

      expect(await controller.saveNote('A note'), isFalse);
      expect(repository.saveCalls, isEmpty);
    });

    test('does not notify after being disposed', () async {
      final repository = FakeCourseLearningRepository(holdSave: true);
      final controller = await loaded(repository);

      final pending = controller.saveNote('A note');
      controller.dispose();
      repository.releaseSave();

      // Would throw "used after being disposed" if the guard were missing.
      await pending;
    });

    test('does not notify after being disposed, on failure either', () async {
      final repository = FakeCourseLearningRepository(
        holdSave: true,
        saveFailure: const CourseLearningFailure(
          CourseLearningFailureKind.server,
        ),
      );
      final controller = await loaded(repository);

      final pending = controller.saveNote('A note');
      controller.dispose();
      repository.releaseSave();

      await pending;
    });
  });

  group('downloadMaterial', () {
    /// A loaded controller whose opener records what it was handed.
    Future<(CourseExerciseDetailController, List<Uri>)> loaded(
      FakeCourseLearningRepository repository, {
      Future<bool> Function(Uri url)? openUrl,
    }) async {
      final opened = <Uri>[];
      final controller = CourseExerciseDetailController(
        repository: repository,
        lessonId: 204,
        openUrl:
            openUrl ??
            (url) async {
              opened.add(url);
              return true;
            },
      );
      await controller.load();
      return (controller, opened);
    }

    test('starts idle for every material', () async {
      final (controller, _) = await loaded(FakeCourseLearningRepository());

      expect(controller.isDownloadingMaterial(1), isFalse);
      expect(controller.isMaterialOpened(1), isFalse);
      expect(controller.materialDownloadErrorMessage(1), isNull);
    });

    test('fetches the link and opens its URL', () async {
      final repository = FakeCourseLearningRepository();
      final (controller, opened) = await loaded(repository);

      final result = await controller.downloadMaterial(88);

      expect(result, isTrue);
      expect(repository.downloadCalls, [88]);
      expect(opened, [sampleDownload(materialId: 88).url]);
      expect(controller.isMaterialOpened(88), isTrue);
      expect(controller.isMaterialOpened(1), isFalse);
      expect(controller.materialDownloadErrorMessage(88), isNull);
    });

    test('reports that material in flight, and only that one', () async {
      final repository = FakeCourseLearningRepository(holdDownload: true);
      final (controller, _) = await loaded(repository);

      final pending = controller.downloadMaterial(88);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isDownloadingMaterial(88), isTrue);
      expect(controller.isDownloadingMaterial(1), isFalse);

      repository.releaseDownload();
      await pending;
      expect(controller.isDownloadingMaterial(88), isFalse);
    });

    test('a second tap on the same material in flight is ignored', () async {
      final repository = FakeCourseLearningRepository(holdDownload: true);
      final (controller, _) = await loaded(repository);

      final first = controller.downloadMaterial(88);
      await Future<void>.delayed(Duration.zero);
      expect(await controller.downloadMaterial(88), isFalse);

      repository.releaseDownload();
      await first;
      expect(repository.downloadCalls, [88]);
    });

    test('a failure becomes its own copy, and opens nothing', () async {
      for (final kind in CourseLearningFailureKind.values) {
        final repository = FakeCourseLearningRepository(
          downloadFailure: CourseLearningFailure(kind),
        );
        final (controller, opened) = await loaded(repository);

        final result = await controller.downloadMaterial(88);

        expect(result, isFalse, reason: kind.name);
        expect(
          controller.materialDownloadErrorMessage(88),
          kind == CourseLearningFailureKind.notFound
              ? CourseLearningStrings.materialNotFound
              : CourseLearningStrings.messageFor(kind),
          reason: kind.name,
        );
        expect(opened, isEmpty, reason: kind.name);
        expect(controller.isMaterialOpened(88), isFalse, reason: kind.name);
        expect(
          controller.isDownloadingMaterial(88),
          isFalse,
          reason: kind.name,
        );
        // A failed download is not a failed load: the lesson stays.
        expect(controller.errorMessage, isNull, reason: kind.name);
        expect(controller.exercise, isNotNull, reason: kind.name);
      }
    });

    test('a link the OS will not open reads as the generic copy', () async {
      final (controller, _) = await loaded(
        FakeCourseLearningRepository(),
        openUrl: (_) async => false,
      );

      expect(await controller.downloadMaterial(88), isFalse);
      expect(controller.isMaterialOpened(88), isFalse);
      expect(
        controller.materialDownloadErrorMessage(88),
        CourseLearningStrings.unexpectedError,
      );
    });

    test('an opener that throws reads as the generic copy', () async {
      final (controller, _) = await loaded(
        FakeCourseLearningRepository(),
        openUrl: (_) async => throw StateError('no channel'),
      );

      expect(await controller.downloadMaterial(88), isFalse);
      expect(
        controller.materialDownloadErrorMessage(88),
        CourseLearningStrings.unexpectedError,
      );
    });

    test('a failure is kept per material', () async {
      final repository = FakeCourseLearningRepository(
        downloadFailure: const CourseLearningFailure(
          CourseLearningFailureKind.network,
        ),
      );
      final (controller, _) = await loaded(repository);

      await controller.downloadMaterial(1);
      repository.downloadFailure = null;
      await controller.downloadMaterial(2);

      expect(
        controller.materialDownloadErrorMessage(1),
        CourseLearningStrings.networkError,
      );
      expect(controller.materialDownloadErrorMessage(2), isNull);
      expect(controller.isMaterialOpened(2), isTrue);
    });

    test('a retry clears the error as it starts, and can succeed', () async {
      final repository = FakeCourseLearningRepository(
        downloadFailure: const CourseLearningFailure(
          CourseLearningFailureKind.server,
        ),
      );
      final (controller, _) = await loaded(repository);
      await controller.downloadMaterial(88);
      expect(controller.materialDownloadErrorMessage(88), isNotNull);

      repository
        ..downloadFailure = null
        ..holdDownload = true;
      final pending = controller.downloadMaterial(88);
      await Future<void>.delayed(Duration.zero);
      expect(controller.materialDownloadErrorMessage(88), isNull);

      repository.releaseDownload();
      expect(await pending, isTrue);
      expect(controller.isMaterialOpened(88), isTrue);
    });

    test('does not notify after being disposed', () async {
      final repository = FakeCourseLearningRepository(holdDownload: true);
      final (controller, _) = await loaded(repository);

      final pending = controller.downloadMaterial(88);
      controller.dispose();
      repository.releaseDownload();

      // Would throw "used after being disposed" if the guard were missing.
      await pending;
    });

    test('does not notify after being disposed, on failure either', () async {
      final repository = FakeCourseLearningRepository(
        holdDownload: true,
        downloadFailure: const CourseLearningFailure(
          CourseLearningFailureKind.server,
        ),
      );
      final (controller, _) = await loaded(repository);

      final pending = controller.downloadMaterial(88);
      controller.dispose();
      repository.releaseDownload();

      await pending;
    });
  });
}

/// Throws something that is not a `CourseLearningFailure` — from
/// [getExercise] by default, or, built with [_ThrowingRepository.onSave],
/// from [saveNote] only.
class _ThrowingRepository extends FakeCourseLearningRepository {
  _ThrowingRepository() : _throwOnSave = false;

  _ThrowingRepository.onSave() : _throwOnSave = true;

  final bool _throwOnSave;

  @override
  Future<CourseExercise> getExercise(int lessonId) async {
    if (_throwOnSave) return super.getExercise(lessonId);
    throw StateError('boom');
  }

  @override
  Future<CourseExerciseNote> saveNote(int lessonId, String content) async {
    if (!_throwOnSave) return super.saveNote(lessonId, content);
    throw StateError('boom');
  }
}
