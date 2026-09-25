/// The Quiz tab's content — sample data only, same status as every other
/// class in this feature. There is no quiz backend to call or to grade
/// against; [QuizQuestion.correctOptionIndex] is the sole "grading key",
/// read entirely on-device by `QuizTab` itself.
class CourseQuiz {
  const CourseQuiz({
    required this.title,
    required this.estimatedMinutesLabel,
    required this.questions,
  });

  final String title;

  /// Pre-formatted, e.g. "~5 min" — same reasoning as
  /// `CourseExerciseMaterial.sizeLabel`: no confirmed raw source to format
  /// from yet, and none needed for a sample estimate either way.
  final String estimatedMinutesLabel;

  final List<QuizQuestion> questions;
}

/// One single-select question. Sample data only — see [CourseQuiz].
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
  });

  final String prompt;
  final List<String> options;

  /// Index into [options] — which one is correct, checked locally when the
  /// quiz is submitted.
  final int correctOptionIndex;
}
