/// A lesson's quiz as the lesson detail summarises it —
/// `course_learning_api_contract_v1.md` §2.7's `quiz` object, shown as the
/// preview/result card on Exercise Detail (`QuizPreviewCard`).
///
/// A summary only: the questions arrive with an attempt ([QuizAttempt]), and
/// **the answer key never reaches the client** — correctness is revealed one
/// answered question at a time ([QuizAnswerResult]) and the score is the
/// server's ([QuizAttemptResult]). Nothing here grades on the device.
class CourseQuiz {
  const CourseQuiz({
    required this.id,
    required this.title,
    required this.resultTitle,
    required this.questionCount,
    required this.attemptsLeft,
    required this.openAttemptId,
    required this.lastResult,
  });

  /// `quiz.id` — what `POST /me/quizzes/{quiz_id}/attempts` is sent with.
  final int id;

  /// The preview card's own title, e.g. "Nesting loops quiz".
  final String title;

  /// The Result screen's heading, e.g. "Level 2 - Language Model Training".
  /// §2.7: "`resultTitle` is not sent; the result-screen caption is a client
  /// string" — built by the repository, not read off the wire.
  final String resultTitle;

  /// `question_count` — the preview card's "Total N questions".
  final int questionCount;

  /// `attempts_left`: null when attempts are unlimited, else how many remain.
  /// `0` hides "Дахин quiz өгөх" (§2.7 Q23).
  final int? attemptsLeft;

  /// `open_attempt_id` — an unfinished attempt, or null. Held, not drawn:
  /// starting the quiz resumes it either way (§2.7 Q21), and the design has
  /// no "continue quiz" state of its own.
  final int? openAttemptId;

  /// `last_result` — the most recent finished attempt, or null if none has
  /// finished. What the preview card shows on load (§2.7 Q24).
  final QuizLastResult? lastResult;

  /// Whether another attempt may be started — false only when the server
  /// says none are left.
  bool get canRetake => attemptsLeft != 0;
}

/// §2.7's `quiz.last_result`.
class QuizLastResult {
  const QuizLastResult({
    required this.attemptId,
    required this.correct,
    required this.total,
    required this.percent,
    required this.passed,
  });

  final int attemptId;
  final int correct;
  final int total;

  /// The server's own percentage — shown as is, never recomputed.
  final int percent;

  /// Held, not drawn: the design has no passed/failed treatment.
  final bool passed;
}

/// One started (or resumed) attempt — §2.7's `POST /me/quizzes/{id}/attempts`
/// answer.
class QuizAttempt {
  const QuizAttempt({required this.attemptId, required this.questions});

  /// What the answer and finish calls are sent with.
  final int attemptId;

  /// In the server's order.
  final List<QuizQuestion> questions;
}

/// One single-select question. Carries no answer key.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.answered,
  });

  final int id;
  final String prompt;

  /// In the server's order — the client derives A/B/C/D from position.
  final List<QuizOption> options;

  /// True when a resumed attempt already holds an answer for this question.
  /// Answers are final, so it cannot be answered again. Only the presence of
  /// §2.7's `answer` is read: its shape is not documented anywhere this
  /// client has (contract, `mobile_api_v1_1.md`, Postman), so its contents
  /// are not modelled.
  final bool answered;
}

class QuizOption {
  const QuizOption({required this.id, required this.text});

  /// What `POST /me/quiz-attempts/{id}/answers` is sent as `option_id`.
  final int id;
  final String text;
}

/// §2.7's answer to one submitted option: correctness, the right option and
/// the explanation — revealed only for the question just answered.
class QuizAnswerResult {
  const QuizAnswerResult({
    required this.questionId,
    required this.optionId,
    required this.correct,
    required this.correctOptionId,
    required this.explanation,
  });

  final int questionId;

  /// The option the student picked, as the server recorded it.
  final int optionId;
  final bool correct;
  final int correctOptionId;
  final String explanation;
}

/// A finished attempt's server-graded result — §2.7's `finish` answer, also
/// readable at `GET /me/quiz-attempts/{attempt_id}`.
class QuizAttemptResult {
  const QuizAttemptResult({
    required this.attemptId,
    required this.correct,
    required this.total,
    required this.percent,
    required this.passed,
    required this.questions,
  });

  final int attemptId;
  final int correct;
  final int total;

  /// The server's own percentage — shown as is, never recomputed.
  final int percent;

  /// Held, not drawn: the design has no passed/failed treatment.
  final bool passed;

  /// Per question, in the server's order.
  final List<QuizQuestionResult> questions;
}

class QuizQuestionResult {
  const QuizQuestionResult({
    required this.questionId,
    required this.order,
    required this.correct,
  });

  final int questionId;
  final int order;

  /// Unanswered questions count as wrong (§2.7).
  final bool correct;
}
