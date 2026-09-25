/// This exercise's quiz — shown as a preview/result card on Exercise Detail
/// (`QuizPreviewCard`) and, once started, on its own two full screens
/// (`CourseQuizScreen`, `CourseQuizResultScreen`). Sample data only, same
/// status as every other class in this feature: there is no quiz backend to
/// call or to grade against — [QuizQuestion.correctOptionIndex] is the sole
/// "grading key", read entirely on-device.
class CourseQuiz {
  const CourseQuiz({
    required this.title,
    required this.resultTitle,
    required this.questions,
  });

  /// The preview card's own title, e.g. "Nesting loops quiz".
  final String title;

  /// The Result screen's heading, e.g. "Level 2 - Language Model Training" —
  /// the reference shows a different, more general caption here than the
  /// preview card's [title] (the module's own name rather than this one
  /// exercise's), so it is kept as its own field rather than reusing [title].
  final String resultTitle;

  final List<QuizQuestion> questions;
}

/// One single-select question with its own explanation, shown after an
/// answer is picked — sample data only, see [CourseQuiz].
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });

  final String prompt;
  final List<String> options;

  /// Index into [options] — which one is correct, checked locally the
  /// moment the student picks an answer.
  final int correctOptionIndex;

  /// Shown under the correct/incorrect feedback title once the question is
  /// answered.
  final String explanation;
}

/// How many of [answers] (question index → chosen option index) match their
/// question's own [QuizQuestion.correctOptionIndex] — the one grading
/// function `CourseQuizScreen` and `CourseQuizResultScreen` both call, so
/// the score shown mid-quiz and the one shown on the Result screen can never
/// disagree.
int quizScore(CourseQuiz quiz, Map<int, int> answers) {
  var correct = 0;
  for (var i = 0; i < quiz.questions.length; i++) {
    if (answers[i] == quiz.questions[i].correctOptionIndex) correct++;
  }
  return correct;
}

