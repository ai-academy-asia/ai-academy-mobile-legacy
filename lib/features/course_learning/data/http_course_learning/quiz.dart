part of '../http_course_learning_repository.dart';

/// §2.7's quiz summary, or null — the lesson has none (`mobile_api_v1_1.md`:
/// a quiz with no questions is sent as `null` too).
///
/// Read: `id`, `title`, `question_count`, `attempts_left`, `open_attempt_id`
/// and `last_result`. Not read, because nothing draws them: `pass_percent`,
/// `attempts_used` and `is_required`.
///
/// The Result screen's heading is not sent (§2.7: "the result-screen caption
/// is a client string"). It is built the way the Figma Quiz Result frame
/// writes it — "Level 2 - Language Model Training", the module's own order
/// and title — from the lesson's `module`; with no module title, the quiz's
/// own title stands in.
CourseQuiz? _quizFrom(Object? quiz, {required Map<String, dynamic> module}) {
  if (quiz == null) return null;
  if (quiz is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'quiz: expected an object or null, got ${quiz.runtimeType}',
    );
  }
  final title = _requireLocalized(quiz, 'quiz.title');
  final moduleTitle = _optionalLocalized(module, 'module.title');
  return CourseQuiz(
    id: _requireInt(quiz, 'quiz.id'),
    title: title,
    resultTitle: moduleTitle == null
        ? title
        : 'Level ${_requireInt(module, 'module.order')} - $moduleTitle',
    questionCount: _requireInt(quiz, 'quiz.question_count'),
    attemptsLeft: _optionalInt(quiz, 'quiz.attempts_left'),
    openAttemptId: _optionalInt(quiz, 'quiz.open_attempt_id'),
    lastResult: _lastResultFrom(quiz['last_result']),
  );
}

/// §2.7's `quiz.last_result`, or null — no attempt has finished yet.
QuizLastResult? _lastResultFrom(Object? result) {
  if (result == null) return null;
  if (result is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'quiz.last_result: expected an object or null, got '
          '${result.runtimeType}',
    );
  }
  return QuizLastResult(
    attemptId: _requireInt(result, 'quiz.last_result.attempt_id'),
    correct: _requireInt(result, 'quiz.last_result.correct'),
    total: _requireInt(result, 'quiz.last_result.total'),
    percent: _requireInt(result, 'quiz.last_result.percent'),
    passed: _requireBool(result, 'quiz.last_result.passed'),
  );
}

/// §2.7's start answer — a new attempt or the resumed one, the same shape.
///
/// Read: `attempt_id` and each question's `id`, `prompt`, `options` and
/// whether `answer` is present. Not read: `started_at`, each question's
/// `order` (the list is kept in the server's order), and — added by
/// `mobile_api_v1_1.md` — `quiz_id`, `status` and a question's `image`, which
/// the Quiz frames have no place for.
QuizAttempt _attemptFromBody(String body) {
  final decoded = _decodeObject(body);
  return QuizAttempt(
    attemptId: _requireInt(decoded, 'attempt.attempt_id'),
    questions: [
      for (final entry in _requireList(decoded, 'attempt.questions'))
        _questionFrom(entry),
    ],
  );
}

QuizQuestion _questionFrom(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'a question was not a JSON object (got ${entry.runtimeType})',
    );
  }
  return QuizQuestion(
    id: _requireInt(entry, 'question.id'),
    prompt: _requireString(entry, 'question.prompt'),
    options: [
      for (final option in _requireList(entry, 'question.options'))
        _optionFrom(option),
    ],
    // Presence only: §2.7 says a resumed attempt's answered questions
    // "include their `answer`", but documents no shape for it.
    answered: entry['answer'] != null,
  );
}

QuizOption _optionFrom(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail: 'an option was not a JSON object (got ${entry.runtimeType})',
    );
  }
  return QuizOption(
    id: _requireInt(entry, 'option.id'),
    text: _requireString(entry, 'option.text'),
  );
}

/// §2.7's answer to one submitted option.
///
/// `explanation` is read gently — absent or empty is no explanation — since
/// the question bank's explanations are authored content (an ERD addition)
/// a question may simply not have.
QuizAnswerResult _answerFromBody(String body) {
  final decoded = _decodeObject(body);
  return QuizAnswerResult(
    questionId: _requireInt(decoded, 'answer.question_id'),
    optionId: _requireInt(decoded, 'answer.option_id'),
    correct: _requireBool(decoded, 'answer.correct'),
    correctOptionId: _requireInt(decoded, 'answer.correct_option_id'),
    explanation: _optionalString(decoded, 'answer.explanation') ?? '',
  );
}

/// §2.7's finish answer, also what `GET /me/quiz-attempts/{id}` reads.
///
/// Read: `attempt_id`, `correct`, `total`, `percent`, `passed` and each
/// question's `question_id`, `order` and `correct`. Not read:
/// `started_at`/`finished_at` (`mobile_api_v1_1.md` additions) — the Result
/// frame shows no time.
QuizAttemptResult _attemptResultFromBody(String body) {
  final decoded = _decodeObject(body);
  return QuizAttemptResult(
    attemptId: _requireInt(decoded, 'result.attempt_id'),
    correct: _requireInt(decoded, 'result.correct'),
    total: _requireInt(decoded, 'result.total'),
    percent: _requireInt(decoded, 'result.percent'),
    passed: _requireBool(decoded, 'result.passed'),
    questions: [
      for (final entry in _requireList(decoded, 'result.questions'))
        _questionResultFrom(entry),
    ],
  );
}

QuizQuestionResult _questionResultFrom(Object? entry) {
  if (entry is! Map<String, dynamic>) {
    throw CourseLearningFailure(
      CourseLearningFailureKind.server,
      detail:
          'a question result was not a JSON object (got ${entry.runtimeType})',
    );
  }
  return QuizQuestionResult(
    questionId: _requireInt(entry, 'result.question.question_id'),
    order: _requireInt(entry, 'result.question.order'),
    correct: _requireBool(entry, 'result.question.correct'),
  );
}
