import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/course_quiz.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_quiz_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_course_learning_repository.dart';

void main() {
  CourseQuizController controllerFor(
    FakeCourseLearningRepository repository, {
    int quizId = 9,
  }) => CourseQuizController(repository: repository, quizId: quizId);

  group('start', () {
    test('starts an attempt at its own quiz id', () async {
      final repository = FakeCourseLearningRepository();
      final controller = controllerFor(repository, quizId: 12);

      await controller.start();

      expect(repository.startQuizCalls, [12]);
      expect(controller.attempt?.attemptId, sampleAttemptId);
      expect(controller.index, 0);
      expect(controller.question?.id, 101);
      expect(controller.errorMessage, isNull);
    });

    test('reports starting while the request is in flight', () async {
      final repository = FakeCourseLearningRepository(holdStartQuiz: true);
      final controller = controllerFor(repository);

      final pending = controller.start();
      expect(controller.starting, isTrue);
      expect(controller.attempt, isNull);

      repository.releaseStartQuiz();
      await pending;

      expect(controller.starting, isFalse);
      expect(controller.attempt, isNotNull);
    });

    test('a failure is copy, and starting again is the retry', () async {
      final repository = FakeCourseLearningRepository(
        startQuizFailure: const CourseLearningFailure(
          CourseLearningFailureKind.network,
        ),
      );
      final controller = controllerFor(repository);

      await controller.start();
      expect(controller.errorMessage, CourseLearningStrings.networkError);
      expect(controller.attempt, isNull);

      repository.startQuizFailure = null;
      await controller.start();

      expect(controller.errorMessage, isNull);
      expect(controller.attempt, isNotNull);
    });

    test('no_attempts_left and a 404 read as the quiz\'s own copy', () async {
      final expected = {
        CourseLearningFailureKind.noAttemptsLeft:
            CourseLearningStrings.quizNoAttemptsLeft,
        CourseLearningFailureKind.notFound: CourseLearningStrings.quizNotFound,
      };
      for (final MapEntry(key: kind, value: copy) in expected.entries) {
        final controller = controllerFor(
          FakeCourseLearningRepository(
            startQuizFailure: CourseLearningFailure(kind),
          ),
        );

        await controller.start();

        expect(controller.errorMessage, copy, reason: kind.name);
      }
    });

    test(
      'a resumed attempt picks up at its first unanswered question',
      () async {
        final repository = FakeCourseLearningRepository(
          quizAttempt: sampleQuizAttempt(answered: {101}),
        );
        final controller = controllerFor(repository);

        await controller.start();

        expect(controller.index, 1);
        expect(controller.question?.id, 102);
        expect(controller.isLastQuestion, isTrue);
      },
    );

    test('a resumed attempt with nothing left to answer is finished', () async {
      final repository = FakeCourseLearningRepository(
        quizAttempt: sampleQuizAttempt(answered: {101, 102}),
      );
      final controller = controllerFor(repository);

      await controller.start();

      expect(repository.finishCalls, [sampleAttemptId]);
      expect(controller.result, isNotNull);
    });
  });

  group('answer', () {
    test('sends the attempt, question and option ids, and holds the server\'s '
        'reply', () async {
      final repository = FakeCourseLearningRepository();
      final controller = controllerFor(repository);
      await controller.start();

      await controller.answer(502);

      expect(repository.answerCalls, [(sampleAttemptId, 101, 502)]);
      final answer = controller.answerFor(101)!;
      expect(answer.correct, isFalse);
      expect(answer.correctOptionId, 501);
      expect(controller.questionAnswered, isTrue);
    });

    test(
      'reports answering while in flight, and ignores another pick',
      () async {
        final repository = FakeCourseLearningRepository(holdAnswer: true);
        final controller = controllerFor(repository);
        await controller.start();

        final pending = controller.answer(501);
        expect(controller.answering, isTrue);
        await controller.answer(502);

        repository.releaseAnswer();
        await pending;

        expect(controller.answering, isFalse);
        expect(repository.answerCalls, [(sampleAttemptId, 101, 501)]);
      },
    );

    test('an answered question takes no other answer', () async {
      final repository = FakeCourseLearningRepository();
      final controller = controllerFor(repository);
      await controller.start();

      await controller.answer(501);
      await controller.answer(502);

      expect(repository.answerCalls, hasLength(1));
      expect(controller.answerFor(101)!.optionId, 501);
    });

    test('a failure is copy, and the question can be answered again', () async {
      final repository = FakeCourseLearningRepository(
        answerFailure: const CourseLearningFailure(
          CourseLearningFailureKind.server,
        ),
      );
      final controller = controllerFor(repository);
      await controller.start();

      await controller.answer(501);
      expect(controller.answerErrorMessage, CourseLearningStrings.serverError);
      expect(controller.questionAnswered, isFalse);

      repository.answerFailure = null;
      await controller.answer(501);

      expect(controller.answerErrorMessage, isNull);
      expect(controller.questionAnswered, isTrue);
    });

    test('already_answered re-reads the attempt and moves on', () async {
      final repository = FakeCourseLearningRepository(
        answerFailure: const CourseLearningFailure(
          CourseLearningFailureKind.alreadyAnswered,
        ),
      );
      final controller = controllerFor(repository);
      await controller.start();
      repository.nextQuizAttempts.add(sampleQuizAttempt(answered: {101}));

      await controller.answer(501);

      expect(repository.startQuizCalls, [9, 9]);
      expect(controller.question?.id, 102);
      expect(controller.answerErrorMessage, isNull);
    });

    test('attempt_finished reads the finished attempt\'s result', () async {
      final repository = FakeCourseLearningRepository(
        answerFailure: const CourseLearningFailure(
          CourseLearningFailureKind.attemptFinished,
        ),
        attemptResult: sampleAttemptResult(percent: 50),
      );
      final controller = controllerFor(repository);
      await controller.start();

      await controller.answer(501);

      expect(repository.attemptReadCalls, [sampleAttemptId]);
      expect(controller.result?.percent, 50);
    });
  });

  group('next and finish', () {
    test('does nothing until the question is answered', () async {
      final repository = FakeCourseLearningRepository();
      final controller = controllerFor(repository);
      await controller.start();

      await controller.next();

      expect(controller.index, 0);
      expect(repository.finishCalls, isEmpty);
    });

    test('moves to the next question', () async {
      final controller = controllerFor(FakeCourseLearningRepository());
      await controller.start();
      expect(controller.isLastQuestion, isFalse);

      await controller.answer(501);
      await controller.next();

      expect(controller.index, 1);
      expect(controller.question?.id, 102);
      expect(controller.isLastQuestion, isTrue);
    });

    test('on the last question, finishes the attempt and holds the server\'s '
        'result', () async {
      final repository = FakeCourseLearningRepository(
        finishResult: sampleAttemptResult(
          correct: 1,
          percent: 50,
          passed: false,
        ),
      );
      final controller = controllerFor(repository);
      await controller.start();
      await controller.answer(501);
      await controller.next();
      await controller.answer(504);

      await controller.next();

      expect(repository.finishCalls, [sampleAttemptId]);
      final result = controller.result!;
      expect(result.percent, 50);
      expect(result.correct, 1);
      expect(result.passed, isFalse);
    });

    test('reports finishing while in flight', () async {
      final repository = FakeCourseLearningRepository(holdFinish: true);
      final controller = controllerFor(repository);
      await controller.start();
      await controller.answer(501);
      await controller.next();
      await controller.answer(504);

      final pending = controller.next();
      expect(controller.finishing, isTrue);

      repository.releaseFinish();
      await pending;

      expect(controller.finishing, isFalse);
      expect(controller.result, isNotNull);
    });

    test('a failed finish is copy, and next() again retries it', () async {
      final repository = FakeCourseLearningRepository(
        finishFailure: const CourseLearningFailure(
          CourseLearningFailureKind.network,
        ),
      );
      final controller = controllerFor(repository);
      await controller.start();
      await controller.answer(501);
      await controller.next();
      await controller.answer(504);

      await controller.next();
      expect(controller.finishErrorMessage, CourseLearningStrings.networkError);
      expect(controller.result, isNull);

      repository.finishFailure = null;
      await controller.next();

      expect(repository.finishCalls, [sampleAttemptId, sampleAttemptId]);
      expect(controller.finishErrorMessage, isNull);
      expect(controller.result, isNotNull);
    });

    test(
      'a finish answered attempt_finished reads the result instead',
      () async {
        final repository = FakeCourseLearningRepository(
          finishFailure: const CourseLearningFailure(
            CourseLearningFailureKind.attemptFinished,
          ),
        );
        final controller = controllerFor(repository);
        await controller.start();
        await controller.answer(501);
        await controller.next();
        await controller.answer(504);

        await controller.next();

        expect(repository.attemptReadCalls, [sampleAttemptId]);
        expect(controller.result, isNotNull);
        expect(controller.finishErrorMessage, isNull);
      },
    );

    test(
      'a resumed, fully answered attempt whose finish failed can retry it',
      () async {
        final repository = FakeCourseLearningRepository(
          quizAttempt: sampleQuizAttempt(answered: {101, 102}),
          finishFailure: const CourseLearningFailure(
            CourseLearningFailureKind.server,
          ),
        );
        final controller = controllerFor(repository);

        await controller.start();
        expect(controller.result, isNull);
        expect(controller.questionAnswered, isTrue);

        repository.finishFailure = null;
        await controller.next();

        expect(controller.result, isNotNull);
      },
    );
  });

  test('never grades: no result exists until the server finishes', () async {
    final controller = controllerFor(FakeCourseLearningRepository());
    await controller.start();
    await controller.answer(501);
    await controller.next();
    await controller.answer(504);

    expect(controller.result, isNull);
    expect(controller.answerFor(102), isA<QuizAnswerResult>());
  });
}
