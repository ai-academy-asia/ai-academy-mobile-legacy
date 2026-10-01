import 'package:flutter/foundation.dart';

import '../domain/course_learning_failure.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_quiz.dart';
import 'course_learning_strings.dart';

/// Runs one attempt at a quiz against §2.7: start (or resume), answer one
/// question at a time, finish, and hold the server-graded result.
///
/// Same `ChangeNotifier`/`_disposed`-guard shape as the feature's other
/// controllers. Nothing is graded here — whether an answer was right comes
/// back from the answer call, and the score from the finish call.
///
/// **Resume.** Starting returns the student's unfinished attempt when there
/// is one (§2.7 Q21). Its already-answered questions are final and their
/// `answer` has no documented shape, so they are skipped: the student picks
/// up at the first unanswered question, and an attempt with none left is
/// finished straight away.
///
/// **State conflicts** are refreshed rather than shown (§0: "409 → refresh
/// the screen state"): `already_answered` re-reads the attempt and moves on,
/// and `attempt_finished` reads the finished attempt's result.
class CourseQuizController extends ChangeNotifier {
  CourseQuizController({required this._repository, required this.quizId});

  final CourseLearningRepository _repository;

  /// `CourseQuiz.id` — which quiz to start.
  final int quizId;

  bool _disposed = false;
  bool _starting = false;
  QuizAttempt? _attempt;
  String? _errorMessage;
  int _index = 0;
  final Map<int, QuizAnswerResult> _answers = {};
  bool _answering = false;
  String? _answerErrorMessage;
  bool _finishing = false;
  String? _finishErrorMessage;
  QuizAttemptResult? _result;

  /// True while the attempt is being started (or resumed).
  bool get starting => _starting;

  /// The attempt in progress, or null before it has started.
  QuizAttempt? get attempt => _attempt;

  /// Copy for a failed start, or null. Cleared by every [start].
  String? get errorMessage => _errorMessage;

  /// 0-based position of the question showing.
  int get index => _index;

  /// The question showing, or null with no attempt.
  QuizQuestion? get question {
    final attempt = _attempt;
    if (attempt == null || attempt.questions.isEmpty) return null;
    return attempt.questions[_index];
  }

  /// The server's answer to [questionId], or null if it is unanswered here.
  QuizAnswerResult? answerFor(int questionId) => _answers[questionId];

  /// Whether the question showing has its answer — given here, or already
  /// held by a resumed attempt. Either way it takes no other, and
  /// "Үргэлжлүүлэх" may move on.
  bool get questionAnswered {
    final question = this.question;
    if (question == null) return false;
    return question.answered || _answers.containsKey(question.id);
  }

  /// True while an answer is in flight.
  bool get answering => _answering;

  /// Copy for the last failed answer, or null.
  String? get answerErrorMessage => _answerErrorMessage;

  /// True while the attempt is being finished.
  bool get finishing => _finishing;

  /// Copy for the last failed finish, or null.
  String? get finishErrorMessage => _finishErrorMessage;

  /// The server-graded result, once the attempt is finished.
  QuizAttemptResult? get result => _result;

  /// Whether the question showing is the last one still to answer — its
  /// "Үргэлжлүүлэх" finishes the attempt rather than moving on.
  bool get isLastQuestion => _nextUnanswered(_index + 1) == null;

  /// Starts or resumes the attempt. Safe to call again — that is the retry.
  Future<void> start() async {
    _starting = true;
    _errorMessage = null;
    _notify();

    try {
      final attempt = await _repository.startQuizAttempt(quizId);
      _attempt = attempt;
      _answers.clear();
      final first = _nextUnanswered(0);
      if (first == null) {
        _index = attempt.questions.isEmpty ? 0 : attempt.questions.length - 1;
        await _finish();
      } else {
        _index = first;
      }
    } on CourseLearningFailure catch (failure) {
      _attempt = null;
      _errorMessage = _messageFor(failure.kind);
    } catch (_) {
      _attempt = null;
      _errorMessage = CourseLearningStrings.unexpectedError;
    } finally {
      _starting = false;
      _notify();
    }
  }

  /// Answers the question showing with [optionId]. Ignored while another
  /// answer is in flight, or once the question has its answer.
  Future<void> answer(int optionId) async {
    final attempt = _attempt;
    final question = this.question;
    if (attempt == null || question == null) return;
    if (_answering || questionAnswered) return;

    _answering = true;
    _answerErrorMessage = null;
    _notify();

    try {
      _answers[question.id] = await _repository.answerQuizQuestion(
        attempt.attemptId,
        questionId: question.id,
        optionId: optionId,
      );
    } on CourseLearningFailure catch (failure) {
      switch (failure.kind) {
        case CourseLearningFailureKind.alreadyAnswered:
          await _resync();
        case CourseLearningFailureKind.attemptFinished:
          await _readResult();
        default:
          _answerErrorMessage = _messageFor(failure.kind);
      }
    } catch (_) {
      _answerErrorMessage = CourseLearningStrings.unexpectedError;
    } finally {
      _answering = false;
      _notify();
    }
  }

  /// "Үргэлжлүүлэх": on to the next unanswered question, or — on the last —
  /// finishes the attempt. Ignored until the question showing is answered.
  /// After a failed finish, calling it again retries the finish.
  Future<void> next() async {
    if (!questionAnswered || _finishing) return;

    final next = _nextUnanswered(_index + 1);
    if (next != null) {
      _index = next;
      _answerErrorMessage = null;
      _notify();
      return;
    }
    await _finish();
    _notify();
  }

  Future<void> _finish() async {
    final attempt = _attempt;
    if (attempt == null) return;

    _finishing = true;
    _finishErrorMessage = null;
    _notify();

    try {
      _result = await _repository.finishQuizAttempt(attempt.attemptId);
    } on CourseLearningFailure catch (failure) {
      if (failure.kind == CourseLearningFailureKind.attemptFinished) {
        await _readResult();
      } else {
        _finishErrorMessage = _messageFor(failure.kind);
      }
    } catch (_) {
      _finishErrorMessage = CourseLearningStrings.unexpectedError;
    } finally {
      _finishing = false;
    }
  }

  /// `already_answered`: the server holds an answer this screen never saw.
  /// Re-reads the attempt (starting resumes it) and moves to the first
  /// question it still lacks, finishing when there is none.
  Future<void> _resync() async {
    try {
      final attempt = await _repository.startQuizAttempt(quizId);
      _attempt = attempt;
      final next = _nextUnanswered(0);
      if (next == null) {
        await _finish();
      } else {
        _index = next;
      }
    } on CourseLearningFailure catch (failure) {
      _answerErrorMessage = _messageFor(failure.kind);
    } catch (_) {
      _answerErrorMessage = CourseLearningStrings.unexpectedError;
    }
  }

  /// `attempt_finished`: the attempt is already graded — read its result.
  Future<void> _readResult() async {
    final attempt = _attempt;
    if (attempt == null) return;
    try {
      _result = await _repository.getQuizAttempt(attempt.attemptId);
    } on CourseLearningFailure catch (failure) {
      _finishErrorMessage = _messageFor(failure.kind);
    } catch (_) {
      _finishErrorMessage = CourseLearningStrings.unexpectedError;
    }
  }

  /// The first question from [from] on that neither the server (a resumed
  /// answer) nor this screen has answered, or null when there is none.
  int? _nextUnanswered(int from) {
    final questions = _attempt?.questions ?? const <QuizQuestion>[];
    for (var i = from; i < questions.length; i++) {
      final question = questions[i];
      if (!question.answered && !_answers.containsKey(question.id)) return i;
    }
    return null;
  }

  /// 404 here is the quiz or the attempt, not the course [messageFor] names.
  static String _messageFor(CourseLearningFailureKind kind) =>
      kind == CourseLearningFailureKind.notFound
      ? CourseLearningStrings.quizNotFound
      : CourseLearningStrings.messageFor(kind);

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
