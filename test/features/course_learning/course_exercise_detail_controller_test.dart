import 'package:aia_mobile/core/utils/pick_local_file.dart';
import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/uploaded_file.dart';
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

  group('submitAssignment', () {
    const assignment = CourseAssignment(id: 17);

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

    FakeCourseLearningRepository withAssignment({
      CourseAssignment? assignment = assignment,
      bool holdSubmit = false,
      AssignmentSubmission? submission,
      CourseLearningFailure? submitFailure,
    }) => FakeCourseLearningRepository(
      exercise: sampleExercise(
        lessonId: 204,
        title: 'Давталт',
        simulatesWrites: false,
        assignment: assignment,
      ),
      holdSubmit: holdSubmit,
      submission: submission,
      submitFailure: submitFailure,
    );

    test('starts not submitting, with no submit error', () async {
      final controller = await loaded(withAssignment());

      expect(controller.submittingAssignment, isFalse);
      expect(controller.assignmentSubmitErrorMessage, isNull);
    });

    test('reports submitting while the request is in flight', () async {
      final repository = withAssignment(holdSubmit: true);
      final controller = await loaded(repository);

      final pending = controller.submitAssignment(link: 'https://x.test');
      await Future<void>.delayed(Duration.zero);
      expect(controller.submittingAssignment, isTrue);

      repository.releaseSubmit();
      await pending;
      expect(controller.submittingAssignment, isFalse);
    });

    test('sends the trimmed link and description to the assignment', () async {
      final repository = withAssignment();
      final controller = await loaded(repository);

      await controller.submitAssignment(
        link: '  https://x.test  ',
        description: '  Тайлбар  ',
      );
      await controller.submitAssignment(
        link: 'https://y.test',
        description: ' ',
      );

      expect(repository.submitCalls, [
        (17, 'https://x.test', 'Тайлбар'),
        // Blank is no description at all.
        (17, 'https://y.test', null),
      ]);
    });

    test('success holds the server\'s submission, not a local one', () async {
      final server = sampleSubmission(
        id: 999,
        version: 3,
        link: 'https://server.test/as-stored',
        feedback: const AssignmentMentorFeedback(
          mentorInitials: 'ДБ',
          mentorName: 'Дорж Бат',
          mentorRole: 'Lead Mentor',
          message: 'Сайн.',
          timestampLabel: 'Today, 14:20',
        ),
      );
      final controller = await loaded(withAssignment(submission: server));

      final result = await controller.submitAssignment(link: 'https://x.test');

      expect(result, isTrue);
      expect(controller.exercise!.assignment!.id, 17);
      expect(controller.exercise!.assignment!.submission, same(server));
      // The rest of the lesson is untouched.
      expect(controller.exercise!.title, 'Давталт');
      expect(controller.errorMessage, isNull);
    });

    test('a resubmission replaces the latest submission', () async {
      final first = sampleSubmission(id: 301, version: 1);
      final repository = withAssignment(
        assignment: CourseAssignment(id: 17, submission: first),
      )..submission = sampleSubmission(id: 302, version: 2);
      final controller = await loaded(repository);

      await controller.submitAssignment(link: 'https://x.test');

      final latest = controller.exercise!.assignment!.submission!;
      expect(latest.id, 302);
      expect(latest.version, 2);
      expect(repository.submitCalls.single.$1, 17);
    });

    test('a failure becomes its own copy and keeps the old state', () async {
      for (final kind in CourseLearningFailureKind.values) {
        final previous = sampleSubmission(id: 301);
        final controller = await loaded(
          withAssignment(
            assignment: CourseAssignment(id: 17, submission: previous),
            submitFailure: CourseLearningFailure(kind),
          ),
        );

        final result = await controller.submitAssignment(link: 'https://x');

        expect(result, isFalse, reason: kind.name);
        expect(
          controller.assignmentSubmitErrorMessage,
          kind == CourseLearningFailureKind.notFound
              ? CourseLearningStrings.assignmentNotFound
              : CourseLearningStrings.messageFor(kind),
          reason: kind.name,
        );
        expect(
          controller.exercise!.assignment!.submission,
          same(previous),
          reason: kind.name,
        );
        expect(controller.errorMessage, isNull, reason: kind.name);
        expect(controller.submittingAssignment, isFalse, reason: kind.name);
      }
    });

    test('the four submission rules read as their own copy', () async {
      final expected = {
        CourseLearningFailureKind.submissionEmpty:
            CourseLearningStrings.submissionEmpty,
        CourseLearningFailureKind.invalidLink:
            CourseLearningStrings.invalidLink,
        CourseLearningFailureKind.descriptionTooLong:
            CourseLearningStrings.descriptionTooLong,
        CourseLearningFailureKind.pastDue: CourseLearningStrings.pastDue,
      };
      for (final MapEntry(key: kind, value: copy) in expected.entries) {
        final controller = await loaded(
          withAssignment(submitFailure: CourseLearningFailure(kind)),
        );

        await controller.submitAssignment(link: 'https://x');

        expect(
          controller.assignmentSubmitErrorMessage,
          copy,
          reason: kind.name,
        );
      }
      // past_due is not the lesson-locked copy.
      expect(
        CourseLearningStrings.pastDue,
        isNot(
          CourseLearningStrings.messageFor(CourseLearningFailureKind.locked),
        ),
      );
    });

    test('a retry clears the error as it starts, and can succeed', () async {
      final repository = withAssignment(
        submitFailure: const CourseLearningFailure(
          CourseLearningFailureKind.network,
        ),
      );
      final controller = await loaded(repository);
      await controller.submitAssignment(link: 'https://x');
      expect(controller.assignmentSubmitErrorMessage, isNotNull);

      repository
        ..submitFailure = null
        ..holdSubmit = true;
      final pending = controller.submitAssignment(link: 'https://x');
      await Future<void>.delayed(Duration.zero);
      expect(controller.assignmentSubmitErrorMessage, isNull);

      repository.releaseSubmit();
      expect(await pending, isTrue);
      expect(controller.exercise!.assignment!.submission, isNotNull);
    });

    test('a second submit while one is in flight is ignored', () async {
      final repository = withAssignment(holdSubmit: true);
      final controller = await loaded(repository);

      final first = controller.submitAssignment(link: 'https://x');
      await Future<void>.delayed(Duration.zero);
      expect(await controller.submitAssignment(link: 'https://y'), isFalse);

      repository.releaseSubmit();
      await first;
      expect(repository.submitCalls, hasLength(1));
    });

    test('with no assignment, nothing is sent', () async {
      final repository = withAssignment(assignment: null);
      final controller = await loaded(repository);

      expect(await controller.submitAssignment(link: 'https://x'), isFalse);
      expect(repository.submitCalls, isEmpty);
    });

    test('with no lesson loaded, nothing is sent', () async {
      final repository = withAssignment();
      final controller = CourseExerciseDetailController(
        repository: repository,
        lessonId: 204,
      );

      expect(await controller.submitAssignment(link: 'https://x'), isFalse);
      expect(repository.submitCalls, isEmpty);
    });

    test('an unexpected error reads as the generic copy', () async {
      final controller = await loaded(_ThrowingRepository.onSubmit());

      expect(await controller.submitAssignment(link: 'https://x'), isFalse);
      expect(
        controller.assignmentSubmitErrorMessage,
        CourseLearningStrings.unexpectedError,
      );
    });

    test('does not notify after being disposed', () async {
      final repository = withAssignment(holdSubmit: true);
      final controller = await loaded(repository);

      final pending = controller.submitAssignment(link: 'https://x');
      controller.dispose();
      repository.releaseSubmit();

      await pending;
    });

    test('does not notify after being disposed, on failure either', () async {
      final repository = withAssignment(
        holdSubmit: true,
        submitFailure: const CourseLearningFailure(
          CourseLearningFailureKind.server,
        ),
      );
      final controller = await loaded(repository);

      final pending = controller.submitAssignment(link: 'https://x');
      controller.dispose();
      repository.releaseSubmit();

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

  group('assignment file', () {
    const picked = PickedFile(name: 'report.pdf', bytes: [1, 2, 3, 4]);

    FakeCourseLearningRepository withAssignment({
      CourseAssignment? assignment = const CourseAssignment(id: 17),
      bool holdUpload = false,
      CourseLearningFailure? uploadFailure,
      CourseLearningFailure? submitFailure,
    }) => FakeCourseLearningRepository(
      exercise: sampleExercise(
        lessonId: 204,
        simulatesWrites: false,
        assignment: assignment,
      ),
      holdUpload: holdUpload,
      uploadFailure: uploadFailure,
      submitFailure: submitFailure,
    );

    Future<CourseExerciseDetailController> loaded(
      FakeCourseLearningRepository repository, {
      Future<PickedFile?> Function()? pickFile,
    }) async {
      final controller = CourseExerciseDetailController(
        repository: repository,
        lessonId: 204,
        pickFile: pickFile ?? () async => picked,
      );
      await controller.load();
      return controller;
    }

    test('starts with no file, no upload and no error', () async {
      final controller = await loaded(withAssignment());

      expect(controller.assignmentFile, isNull);
      expect(controller.uploadingAssignmentFile, isFalse);
      expect(controller.assignmentFileUploadSizeBytes, isNull);
      expect(controller.assignmentFileErrorMessage, isNull);
    });

    test('uploads the picked file and holds what the server stored', () async {
      final stored = sampleUploadedFile(id: 501, fileName: 'as-stored.pdf');
      final repository = withAssignment()..uploadedFile = stored;
      final controller = await loaded(repository);

      expect(await controller.pickAndUploadAssignmentFile(), isTrue);

      expect(repository.uploadCalls.single.$1, 'report.pdf');
      expect(repository.uploadCalls.single.$2, [1, 2, 3, 4]);
      expect(controller.assignmentFile, same(stored));
      expect(controller.uploadingAssignmentFile, isFalse);
      expect(controller.assignmentFileErrorMessage, isNull);
    });

    test('reports the upload, and its size, while it is in flight', () async {
      final repository = withAssignment(holdUpload: true);
      final controller = await loaded(repository);

      final pending = controller.pickAndUploadAssignmentFile();
      await Future<void>.delayed(Duration.zero);
      expect(controller.uploadingAssignmentFile, isTrue);
      expect(controller.assignmentFileUploadSizeBytes, 4);
      expect(controller.assignmentFile, isNull);

      repository.releaseUpload();
      expect(await pending, isTrue);
      expect(controller.uploadingAssignmentFile, isFalse);
      expect(controller.assignmentFile, isNotNull);
    });

    test('picking nothing uploads nothing and is not an error', () async {
      final repository = withAssignment();
      final controller = await loaded(repository, pickFile: () async => null);

      expect(await controller.pickAndUploadAssignmentFile(), isFalse);

      expect(repository.uploadCalls, isEmpty);
      expect(controller.assignmentFile, isNull);
      expect(controller.assignmentFileErrorMessage, isNull);
    });

    test('a picker that fails reads as the generic copy', () async {
      final repository = withAssignment();
      final controller = await loaded(
        repository,
        pickFile: () async => throw StateError('no picker'),
      );

      expect(await controller.pickAndUploadAssignmentFile(), isFalse);

      expect(repository.uploadCalls, isEmpty);
      expect(
        controller.assignmentFileErrorMessage,
        CourseLearningStrings.unexpectedError,
      );
    });

    for (final (kind, copy) in [
      (
        CourseLearningFailureKind.unsupportedFileType,
        CourseLearningStrings.unsupportedFileType,
      ),
      (
        CourseLearningFailureKind.fileTooLarge,
        CourseLearningStrings.fileTooLarge,
      ),
      (CourseLearningFailureKind.network, CourseLearningStrings.networkError),
      (CourseLearningFailureKind.server, CourseLearningStrings.serverError),
      (
        CourseLearningFailureKind.sessionExpired,
        CourseLearningStrings.sessionExpired,
      ),
    ]) {
      test('an upload refused as ${kind.name} becomes its own copy', () async {
        final controller = await loaded(
          withAssignment(uploadFailure: CourseLearningFailure(kind)),
        );

        expect(await controller.pickAndUploadAssignmentFile(), isFalse);

        expect(controller.assignmentFileErrorMessage, copy);
        expect(controller.assignmentFile, isNull);
        expect(controller.uploadingAssignmentFile, isFalse);
        // The lesson stays on screen.
        expect(controller.errorMessage, isNull);
        expect(controller.exercise, isNotNull);
      });
    }

    test('an unexpected upload error reads as the generic copy', () async {
      final controller = await loaded(_ThrowingRepository.onUpload());

      expect(await controller.pickAndUploadAssignmentFile(), isFalse);

      expect(
        controller.assignmentFileErrorMessage,
        CourseLearningStrings.unexpectedError,
      );
      expect(controller.uploadingAssignmentFile, isFalse);
    });

    test('a retry clears the last error and can succeed', () async {
      final repository = withAssignment(
        uploadFailure: const CourseLearningFailure(
          CourseLearningFailureKind.network,
        ),
      );
      final controller = await loaded(repository);
      await controller.pickAndUploadAssignmentFile();
      expect(controller.assignmentFileErrorMessage, isNotNull);

      repository.uploadFailure = null;
      expect(await controller.pickAndUploadAssignmentFile(), isTrue);

      expect(controller.assignmentFileErrorMessage, isNull);
      expect(controller.assignmentFile, isNotNull);
    });

    test('a failed replacement keeps the file already uploaded', () async {
      final repository = withAssignment();
      final controller = await loaded(repository);
      await controller.pickAndUploadAssignmentFile();
      final first = controller.assignmentFile;

      repository.uploadFailure = const CourseLearningFailure(
        CourseLearningFailureKind.fileTooLarge,
      );
      expect(await controller.pickAndUploadAssignmentFile(), isFalse);

      expect(controller.assignmentFile, same(first));
    });

    test('a second pick is ignored while an upload is in flight', () async {
      final repository = withAssignment(holdUpload: true);
      final controller = await loaded(repository);

      final first = controller.pickAndUploadAssignmentFile();
      await Future<void>.delayed(Duration.zero);
      expect(await controller.pickAndUploadAssignmentFile(), isFalse);

      repository.releaseUpload();
      await first;
      expect(repository.uploadCalls, hasLength(1));
    });

    test('is ignored with no assignment to attach a file to', () async {
      final repository = withAssignment(assignment: null);
      final controller = await loaded(repository);

      expect(await controller.pickAndUploadAssignmentFile(), isFalse);
      expect(repository.uploadCalls, isEmpty);
    });

    test('cancel drops the upload, and its answer when it comes', () async {
      final repository = withAssignment(holdUpload: true);
      final controller = await loaded(repository);

      final pending = controller.pickAndUploadAssignmentFile();
      await Future<void>.delayed(Duration.zero);
      controller.cancelAssignmentFileUpload();
      expect(controller.uploadingAssignmentFile, isFalse);

      repository.releaseUpload();
      expect(await pending, isFalse);
      expect(controller.assignmentFile, isNull);
      expect(controller.assignmentFileErrorMessage, isNull);
    });

    test('a cancelled upload that then fails shows no error', () async {
      final repository = withAssignment(
        holdUpload: true,
        uploadFailure: const CourseLearningFailure(
          CourseLearningFailureKind.server,
        ),
      );
      final controller = await loaded(repository);

      final pending = controller.pickAndUploadAssignmentFile();
      await Future<void>.delayed(Duration.zero);
      controller.cancelAssignmentFileUpload();
      repository.releaseUpload();
      await pending;

      expect(controller.assignmentFileErrorMessage, isNull);
    });

    test('a new upload after a cancel is not undone by the old one', () async {
      final repository = withAssignment(holdUpload: true);
      final controller = await loaded(repository);

      final first = controller.pickAndUploadAssignmentFile();
      await Future<void>.delayed(Duration.zero);
      controller.cancelAssignmentFileUpload();

      repository.holdUpload = false;
      expect(await controller.pickAndUploadAssignmentFile(), isTrue);
      final second = controller.assignmentFile;

      repository.releaseUpload();
      await first;
      expect(controller.assignmentFile, same(second));
      expect(controller.uploadingAssignmentFile, isFalse);
    });

    test('remove drops the uploaded file', () async {
      final controller = await loaded(withAssignment());
      await controller.pickAndUploadAssignmentFile();

      controller.removeAssignmentFile();

      expect(controller.assignmentFile, isNull);
    });

    test('a submit sends the uploaded file\'s id as file_id', () async {
      final repository = withAssignment()
        ..uploadedFile = sampleUploadedFile(id: 501);
      final controller = await loaded(repository);
      await controller.pickAndUploadAssignmentFile();

      expect(await controller.submitAssignment(description: 'Тайлбар'), isTrue);

      // A file alone: no link is sent at all.
      expect(repository.submitCalls, [(17, null, 'Тайлбар')]);
      expect(repository.submitFileIds, [501]);
    });

    test('a link and a file go in the same submission', () async {
      final repository = withAssignment()
        ..uploadedFile = sampleUploadedFile(id: 501);
      final controller = await loaded(repository);
      await controller.pickAndUploadAssignmentFile();

      await controller.submitAssignment(link: ' https://x.test ');

      expect(repository.submitCalls, [(17, 'https://x.test', null)]);
      expect(repository.submitFileIds, [501]);
    });

    test('a submit with no file sends a null file_id', () async {
      final repository = withAssignment();
      final controller = await loaded(repository);

      await controller.submitAssignment(link: 'https://x.test');

      expect(repository.submitFileIds, [null]);
    });

    test('an accepted submission drops the file it carried', () async {
      final repository = withAssignment();
      final controller = await loaded(repository);
      await controller.pickAndUploadAssignmentFile();

      await controller.submitAssignment();
      expect(controller.assignmentFile, isNull);

      // So a resubmission does not send the same file again.
      await controller.submitAssignment(link: 'https://x.test');
      expect(repository.submitFileIds.last, isNull);
    });

    test('a refused submission keeps the file for the retry', () async {
      final repository = withAssignment(
        submitFailure: const CourseLearningFailure(
          CourseLearningFailureKind.pastDue,
        ),
      )..uploadedFile = sampleUploadedFile(id: 501);
      final controller = await loaded(repository);
      await controller.pickAndUploadAssignmentFile();

      expect(await controller.submitAssignment(), isFalse);

      expect(controller.assignmentFile!.id, 501);
      expect(
        controller.assignmentSubmitErrorMessage,
        CourseLearningStrings.pastDue,
      );
    });

    test('a submit is ignored while the file is still uploading', () async {
      final repository = withAssignment(holdUpload: true);
      final controller = await loaded(repository);

      final upload = controller.pickAndUploadAssignmentFile();
      await Future<void>.delayed(Duration.zero);
      expect(
        await controller.submitAssignment(link: 'https://x.test'),
        isFalse,
      );
      expect(repository.submitCalls, isEmpty);

      repository.releaseUpload();
      await upload;
    });

    test('does not notify after being disposed mid-upload', () async {
      final repository = withAssignment(holdUpload: true);
      final controller = await loaded(repository);

      final pending = controller.pickAndUploadAssignmentFile();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();

      repository.releaseUpload();
      await pending;
    });
  });

  group('refreshQuiz', () {
    test('re-reads the lesson and takes only its quiz summary', () async {
      final repository = FakeCourseLearningRepository(
        exercise: sampleExercise(lessonId: 204, quiz: sampleQuiz()),
      );
      final controller = CourseExerciseDetailController(
        repository: repository,
        lessonId: 204,
      );
      await controller.load();
      await controller.saveNote('Kept across the refresh.');

      repository.exercise = sampleExercise(
        lessonId: 204,
        quiz: sampleQuiz(attemptsLeft: 1, lastResult: sampleLastResult()),
      );
      await controller.refreshQuiz();

      expect(repository.exerciseCalls, [204, 204]);
      final quiz = controller.exercise!.quiz!;
      expect(quiz.lastResult?.percent, 80);
      expect(quiz.attemptsLeft, 1);
      // The rest of the lesson is what the screen already held.
      expect(controller.exercise!.note?.message, 'Kept across the refresh.');
    });

    test('a failure keeps the summary already showing', () async {
      final repository = FakeCourseLearningRepository(
        exercise: sampleExercise(lessonId: 204, quiz: sampleQuiz()),
      );
      final controller = CourseExerciseDetailController(
        repository: repository,
        lessonId: 204,
      );
      await controller.load();

      repository.exerciseFailure = const CourseLearningFailure(
        CourseLearningFailureKind.network,
      );
      await controller.refreshQuiz();

      expect(controller.exercise!.quiz?.id, 9);
      expect(controller.errorMessage, isNull);
    });
  });
}

/// Throws something that is not a `CourseLearningFailure` — from
/// [getExercise] by default, or, built with [_ThrowingRepository.onSave],
/// [_ThrowingRepository.onSubmit] or [_ThrowingRepository.onUpload], from
/// that call only.
class _ThrowingRepository extends FakeCourseLearningRepository {
  _ThrowingRepository() : _throwOn = _Throw.load;

  _ThrowingRepository.onSave() : _throwOn = _Throw.save;

  _ThrowingRepository.onSubmit()
    : _throwOn = _Throw.submit,
      super(
        exercise: sampleExercise(
          lessonId: 204,
          simulatesWrites: false,
          assignment: const CourseAssignment(id: 17),
        ),
      );

  _ThrowingRepository.onUpload()
    : _throwOn = _Throw.upload,
      super(
        exercise: sampleExercise(
          lessonId: 204,
          simulatesWrites: false,
          assignment: const CourseAssignment(id: 17),
        ),
      );

  final _Throw _throwOn;

  @override
  Future<CourseExercise> getExercise(int lessonId) async {
    if (_throwOn != _Throw.load) return super.getExercise(lessonId);
    throw StateError('boom');
  }

  @override
  Future<CourseExerciseNote> saveNote(int lessonId, String content) async {
    if (_throwOn != _Throw.save) return super.saveNote(lessonId, content);
    throw StateError('boom');
  }

  @override
  Future<AssignmentSubmission> submitAssignment(
    int assignmentId, {
    String? link,
    String? description,
    int? fileId,
  }) async {
    if (_throwOn != _Throw.submit) {
      return super.submitAssignment(
        assignmentId,
        link: link,
        description: description,
        fileId: fileId,
      );
    }
    throw StateError('boom');
  }

  @override
  Future<UploadedFile> uploadFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (_throwOn != _Throw.upload) {
      return super.uploadFile(fileName: fileName, bytes: bytes);
    }
    throw StateError('boom');
  }
}

enum _Throw { load, save, submit, upload }
