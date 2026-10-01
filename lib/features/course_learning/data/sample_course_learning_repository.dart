import '../domain/course_exercise.dart';
import '../domain/course_learning_failure.dart';
import '../domain/course_learning_path.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_module.dart';
import '../domain/course_quiz.dart';
import '../domain/lesson.dart';
import '../domain/material_download.dart';
import '../domain/uploaded_file.dart';
import 'course_module_visuals.dart';

/// Serves one hand-authored [CourseLearningPath], one hand-authored lesson
/// list, and one hand-authored [CourseExercise], regardless of which
/// [getCourseLearning]/[getLessons]/[getExercise] is asked for.
///
/// **Placeholder pending a real learning API.** `course_learning_api_
/// requirements_v1.md` confirms no `Module`/`Lesson`/progress endpoint exists
/// yet, and explicitly recommends confirming the backend contract before
/// mocking one — this exists anyway because the issue this ships for asks for
/// the Course Learning *screens* now, against sample data, with the backend
/// call still to come. Content (module titles, schedule lines, which two are
/// "completed"; the "Nesting loops" exercise's copy, materials and note) is
/// transcribed from the Figma reference for the one course/exercise it shows;
/// every other slug/module id gets the same content today, which is the
/// smallest thing that lets the screens render at all until a real per-course
/// source exists. The assignment attachment is hand-authored sample content
/// that demonstrates the Assignment tab's download-gated Submit. The quiz's
/// four questions are transcribed from the Figma quiz-flow reference
/// verbatim (Mongolian prompts/options, English explanations, exactly as
/// captioned there) — its own separate frame from the "Nesting loops"
/// Exercise Detail screen, which is why its subject (general AI/ML) does not
/// match this exercise's own. Its attempt is simulated locally (see
/// [startQuizAttempt]), as its note save is.
///
/// No longer reached by the app's own navigation: only tests construct it,
/// the quiz goldens among them.
class SampleCourseLearningRepository implements CourseLearningRepository {
  /// The sample lesson Exercise Detail's sample content stands for —
  /// "Nesting loops", id 2 in [getLessons].
  static const int previewLessonId = 2;

  @override
  Future<CourseLearningPath> getCourseLearning(String courseSlug) async {
    return CourseLearningPath(
      courseSlug: courseSlug,
      courseTitle: 'How AI works',
      description:
          'Take a peek under the hood of generative AI and LLMs to understand how they work',
      illustrationAsset: _asset('how_ai_works.svg'),
      percentComplete: 30,
      // The sample's own stand-in for the server's `continue.module_id` — the
      // screen no longer picks one itself. Module 2 is the one it picked
      // before: the most recently completed of the sample's five.
      continueModuleId: 2,
      modules: [
        _module(
          id: 1,
          order: 1,
          title: 'Prediction and Probabilities',
          scheduleLabel: '08/04 • Да • 09:00',
          completed: true,
        ),
        _module(
          id: 2,
          order: 2,
          title: 'Language Model Training',
          scheduleLabel: '08/04 • 09:00–11:00',
          completed: true,
        ),
        _module(
          id: 3,
          order: 3,
          title: 'Deep network models',
          scheduleLabel: '08/04 • 09:00–11:00',
          locked: true,
        ),
        _module(
          id: 4,
          order: 4,
          title: 'Neurons and Layers',
          scheduleLabel: '08/04 • 09:00–11:00',
          locked: true,
        ),
        _module(
          id: 5,
          order: 5,
          title: 'Image Models',
          scheduleLabel: '08/04 • 09:00–11:00',
          locked: true,
        ),
      ],
    );
  }

  @override
  Future<List<Lesson>> getLessons(int moduleId) async {
    return [
      Lesson(
        id: 1,
        moduleId: moduleId,
        order: 1,
        title: 'Introduction to loops',
        type: LessonType.recording,
        durationLabel: '12:30',
        completed: true,
        locked: false,
      ),
      Lesson(
        id: 2,
        moduleId: moduleId,
        order: 2,
        // Matches getExercise's own sample title — every lesson opens the
        // same exercise detail today (see CourseLearningRepository's doc
        // comment on that gap), so the one lesson a student can actually
        // open shows content consistent with what it opens.
        title: 'Nesting loops',
        type: LessonType.recording,
        durationLabel: '24:15',
        completed: false,
        locked: false,
      ),
      Lesson(
        id: 3,
        moduleId: moduleId,
        order: 3,
        title: 'Practice: matrix traversal',
        type: LessonType.recording,
        durationLabel: '18:40',
        completed: false,
        locked: true,
      ),
    ];
  }

  @override
  Future<CourseExercise> getExercise(int lessonId) async {
    return CourseExercise(
      lessonId: lessonId,
      // "Modules 2" below — the sample's one module.
      moduleId: 2,
      moduleCaption: 'Modules 2',
      title: 'Nesting loops',
      type: LessonType.recording,
      durationLabel: '24:15',
      recordingBadgeLabel: 'Live Classroom Recording',
      summary:
          'A nested loop is a loop placed entirely within the body '
          'of another loop. For every single iteration of the outer '
          'loop, the inner loop executes from start to finish. They '
          'are primarily used for processing multi-dimensional '
          'data structures like matrices, generating '
          'combinations, or handling complex sorting algorithms.',
      extraSections: const [
        CourseExerciseSection(
          title: 'Pre-training',
          body:
              'In the pre-training phase, the model is fed trillions of '
              'tokens (such as text scraped from the internet, books, '
              'and code) to learn fundamental knowledge about the '
              'world.',
          bullets: [
            'Self-Supervised Learning: The model’s primary '
                'objective is to predict the next word in a sentence. '
                'It analyzes sequences, calculates its error through '
                'a loss function, and adjusts its internal weights via '
                'backpropagation so its future predictions are more '
                'accurate.',
            'Base Model Creation: The output of pre-training is a '
                '"base model". While this model contains a vast '
                'amount of information, it merely completes text '
                'rather than answering questions or following '
                'instructions.',
          ],
        ),
      ],
      materials: const [
        CourseExerciseMaterial(
          id: 1,
          name: 'Course material 1',
          sizeLabel: '10 MB',
        ),
        CourseExerciseMaterial(
          id: 2,
          name: 'Course material 1',
          sizeLabel: '12 MB',
        ),
      ],
      completed: false,
      // The sample's assignment submit and material download are local
      // simulations — what the Figma states were built against. (Its note
      // save is too: see [saveNote].)
      simulatesWrites: true,
      note: const CourseExerciseNote(
        authorInitials: 'БП',
        authorName: 'Болд Батаа',
        authorLabel: 'Me',
        // Quoted, as the reference frame draws it.
        message:
            '"Good foundation — improve validation '
            'accuracy before final submission. Look into '
            'hyperparameter tuning for the XGBoost '
            'model."',
        timestampLabel: 'Today, 14:20',
      ),
      assignmentFeedback: const [
        AssignmentMentorFeedback(
          mentorInitials: 'БП',
          mentorName: 'Б.Пүрэв',
          mentorRole: 'Lead Mentor',
          // Quoted, as the reference frame draws it.
          message:
              '"Good foundation — improve validation accuracy before final '
              'submission. Look into hyperparameter tuning for the XGBoost '
              'model."',
          timestampLabel: 'Today, 14:20',
        ),
      ],
      assignmentAttachment: const CourseExerciseMaterial(
        id: 3,
        name: 'Assignment template.zip',
        sizeLabel: '1 MB',
      ),
      quiz: CourseQuiz(
        id: _sampleQuizId,
        title: 'Nesting loops quiz',
        resultTitle: 'Level 2 - Language Model Training',
        questionCount: _sampleQuestions.length,
        attemptsLeft: null,
        openAttemptId: null,
        lastResult: null,
      ),
    );
  }

  /// A local simulation: nothing is stored, so a saved note lasts as long as
  /// the screen holding it. Authored by the sample's own student — the same
  /// "БП" / "Болд Батаа" as the note [getExercise] serves — and labelled
  /// "Just now", honest about there being no real clock reading behind it.
  @override
  Future<CourseExerciseNote> saveNote(int lessonId, String content) async {
    return CourseExerciseNote(
      authorInitials: 'БП',
      authorName: 'Болд Батаа',
      authorLabel: 'Me',
      message: content,
      timestampLabel: 'Just now',
    );
  }

  /// The sample's materials are names and sizes only — there is no stored
  /// file behind any of them, so there is no link to hand out. Never reached
  /// from the sample exercise itself: with [CourseExercise.simulatesWrites]
  /// set, the Course materials tab keeps its local "downloaded" toggle and
  /// asks for no link.
  @override
  Future<MaterialDownload> getMaterialDownload(int materialId) async {
    throw CourseLearningFailure(
      CourseLearningFailureKind.notFound,
      detail: 'sample material $materialId has no stored file',
    );
  }

  /// The sample carries no backend assignment (its `assignment` is null), so
  /// there is nothing to submit to. Never reached from the sample exercise
  /// itself: its Assignment tab keeps its local submit → pending → submitted
  /// simulation.
  @override
  Future<AssignmentSubmission> submitAssignment(
    int assignmentId, {
    String? link,
    String? description,
    int? fileId,
  }) async {
    throw CourseLearningFailure(
      CourseLearningFailureKind.notFound,
      detail: 'sample assignment $assignmentId is not on the backend',
    );
  }

  /// The sample has no backend to store a file on, so nothing is uploaded:
  /// this fails, as `unexpected`, rather than answer with a stored file that
  /// does not exist. Never reached from the sample exercise itself: its
  /// Assignment tab keeps its simulated file area.
  @override
  Future<UploadedFile> uploadFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    throw CourseLearningFailure(
      CourseLearningFailureKind.unexpected,
      detail: 'the sample has nowhere to upload "$fileName" to',
    );
  }

  // --- Quiz ----------------------------------------------------------------
  //
  // A local simulation of §2.7's attempt, the same way [saveNote] simulates
  // §2.5: the sample has no server to grade against, so it grades here. The
  // answer key stays inside this class — it is never part of a model, and the
  // screens only ever see what the server would send.

  /// Question id → option id answered, for the one attempt this instance
  /// runs. Cleared by each [startQuizAttempt], so every start is fresh.
  final Map<int, int> _quizAnswers = {};

  /// A fresh attempt at the sample quiz — the questions without their key.
  @override
  Future<QuizAttempt> startQuizAttempt(int quizId) async {
    _quizAnswers.clear();
    return QuizAttempt(
      attemptId: _sampleAttemptId,
      questions: [
        for (final (index, question) in _sampleQuestions.indexed)
          QuizQuestion(
            id: _questionId(index),
            prompt: question.prompt,
            options: [
              for (final (optionIndex, text) in question.options.indexed)
                QuizOption(id: _optionId(index, optionIndex), text: text),
            ],
            answered: false,
          ),
      ],
    );
  }

  @override
  Future<QuizAnswerResult> answerQuizQuestion(
    int attemptId, {
    required int questionId,
    required int optionId,
  }) async {
    final index = questionId - 1;
    final question = _sampleQuestions[index];
    final correctOptionId = _optionId(index, question.correctOptionIndex);
    _quizAnswers[questionId] = optionId;
    return QuizAnswerResult(
      questionId: questionId,
      optionId: optionId,
      correct: optionId == correctOptionId,
      correctOptionId: correctOptionId,
      explanation: question.explanation,
    );
  }

  @override
  Future<QuizAttemptResult> finishQuizAttempt(int attemptId) async =>
      _sampleResult();

  @override
  Future<QuizAttemptResult> getQuizAttempt(int attemptId) async =>
      _sampleResult();

  /// Graded the way §2.7 describes the server doing it: an unanswered
  /// question counts as wrong, and the percentage is rounded down.
  QuizAttemptResult _sampleResult() {
    final questions = [
      for (final (index, question) in _sampleQuestions.indexed)
        QuizQuestionResult(
          questionId: _questionId(index),
          order: index + 1,
          correct:
              _quizAnswers[_questionId(index)] ==
              _optionId(index, question.correctOptionIndex),
        ),
    ];
    final correct = questions.where((q) => q.correct).length;
    final total = questions.length;
    final percent = total == 0 ? 0 : correct * 100 ~/ total;
    return QuizAttemptResult(
      attemptId: _sampleAttemptId,
      correct: correct,
      total: total,
      percent: percent,
      passed: percent >= _samplePassPercent,
      questions: questions,
    );
  }

  static const int _sampleQuizId = 1;
  static const int _sampleAttemptId = 1;

  /// §2.7's own example `pass_percent`.
  static const int _samplePassPercent = 70;

  static int _questionId(int index) => index + 1;
  static int _optionId(int questionIndex, int optionIndex) =>
      (questionIndex + 1) * 10 + optionIndex + 1;

  static String _asset(String name) => 'assets/images/course_learning/$name';
}

/// One sample question, with the key the sample grades against.
typedef _SampleQuestion = ({
  String prompt,
  List<String> options,
  int correctOptionIndex,
  String explanation,
});

/// The four questions of the Figma quiz-flow reference, verbatim.
const List<_SampleQuestion> _sampleQuestions = [
  (
    prompt: 'AI гэж юу вэ?',
    options: ['Хиймэл оюун', 'Тоглоом', 'Робот', 'Мэдэхгүй'],
    correctOptionIndex: 0,
    explanation:
        'Artificial intelligence (AI) is a branch of computer '
        'science focused on building systems capable of performing '
        'tasks that typically require human intelligence. This '
        'includes learning from data, recognizing patterns, '
        'understanding language, solving problems, and making '
        'decisions.',
  ),
  (
    prompt: 'Machine Learning гэж юу вэ?',
    options: [
      'Өгөгдлөөс сурах чадвар',
      'Хатуу код бичих арга',
      'Тоглоомын хөдөлгүүр',
      'Мэдэхгүй',
    ],
    correctOptionIndex: 0,
    explanation:
        'Machine learning is a subset of AI where systems learn '
        'patterns from data instead of following hardcoded rules, '
        'improving their performance as they see more examples.',
  ),
  (
    prompt: 'Neural Network загвар юуг дуурайдаг вэ?',
    options: ['Хүний тархи', 'Компьютерийн CPU', 'Интернет сүлжээ', 'Мэдэхгүй'],
    correctOptionIndex: 0,
    explanation:
        'Artificial neural networks are loosely inspired by the '
        'human brain — layers of interconnected nodes ("neurons") '
        'pass signals to one another to recognize patterns.',
  ),
  (
    prompt: 'Pre-training үе шатанд загварт юу өгдөг вэ?',
    options: [
      'Их хэмжээний текст өгөгдөл',
      'Зөвхөн нэг зураг',
      'Хэрэглэгчийн нууц үг',
      'Мэдэхгүй',
    ],
    correctOptionIndex: 0,
    explanation:
        'During pre-training, a model is exposed to massive '
        'amounts of text data so it can learn general language '
        'patterns before being fine-tuned for a specific task.',
  ),
];

/// Every sample module's lesson count — the length of the one hand-authored
/// lesson list [SampleCourseLearningRepository.getLessons] serves.
const int _sampleLessonCount = 3;

/// One sample module, with its icon and accent taken from the shared palette
/// instead of spelled out per entry.
///
/// The palette is where the real API path gets them too — the backend sends no
/// icon or colour, so both paths map `order` onto
/// `course_module_visuals.dart`. Going through it here as well is what keeps
/// the sample screens and the live screens drawing the same five accents; the
/// values were previously written out module by module in this file, which is
/// exactly the shape that drifts once a second caller exists.
CourseModule _module({
  required int id,
  required int order,
  required String title,
  required String scheduleLabel,
  bool completed = false,
  bool locked = false,
}) {
  final visuals = moduleVisualsFor(order);
  return CourseModule(
    id: id,
    order: order,
    title: title,
    scheduleLabel: scheduleLabel,
    iconAsset: visuals.iconAsset,
    accentColor: visuals.accentColor,
    // Sample counts sized to the sample's own three-lesson list.
    lessonCount: _sampleLessonCount,
    completedLessons: completed ? _sampleLessonCount : 0,
    completed: completed,
    locked: locked,
  );
}
