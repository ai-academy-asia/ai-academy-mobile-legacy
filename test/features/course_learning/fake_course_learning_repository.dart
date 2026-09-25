import 'dart:async';
import 'dart:ui';

import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_path.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_module.dart';
import 'package:aia_mobile/features/course_learning/domain/course_quiz.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';

/// A repository the tests drive by hand.
///
/// Same `hold`/`release` shape as `FakeCourseRepository`, even though the
/// real `SampleCourseLearningRepository` never actually awaits anything —
/// this lets a controller test still observe the brief `loading` state
/// `CourseLearningController.load()` reports before its `await` resolves.
/// [getCourseLearning], [getLessons] and [getExercise] are tracked
/// independently, same reasoning as `FakeCourseRepository`'s
/// `getCourses`/`getCourseDetail` split.
class FakeCourseLearningRepository implements CourseLearningRepository {
  FakeCourseLearningRepository({
    this.path,
    this.hold = false,
    this.lessons,
    this.holdLessons = false,
    this.exercise,
    this.holdExercise = false,
  });

  // --- getCourseLearning ---------------------------------------------------

  /// Returned on success. Defaults to [samplePath] if unset.
  CourseLearningPath? path;

  /// When true, [getCourseLearning] blocks until [release] is called.
  bool hold;

  /// Every slug [getCourseLearning] was called with, in order.
  final List<String> calls = [];

  Completer<void>? _gate;

  void release() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<CourseLearningPath> getCourseLearning(String courseSlug) async {
    calls.add(courseSlug);

    if (hold) {
      _gate = Completer<void>();
      await _gate!.future;
    }

    return path ?? samplePath(courseSlug: courseSlug);
  }

  // --- getLessons --------------------------------------------------------

  /// Returned on success. Defaults to [sampleLessons] if unset.
  List<Lesson>? lessons;

  /// When true, [getLessons] blocks until [releaseLessons] is called.
  bool holdLessons;

  /// Every module id [getLessons] was called with, in order.
  final List<int> lessonCalls = [];

  Completer<void>? _lessonsGate;

  void releaseLessons() {
    final gate = _lessonsGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<List<Lesson>> getLessons(int moduleId) async {
    lessonCalls.add(moduleId);

    if (holdLessons) {
      _lessonsGate = Completer<void>();
      await _lessonsGate!.future;
    }

    return lessons ?? sampleLessons(moduleId: moduleId);
  }

  // --- getExercise -----------------------------------------------------

  /// Returned on success. Defaults to [sampleExercise] if unset.
  CourseExercise? exercise;

  /// When true, [getExercise] blocks until [releaseExercise] is called.
  bool holdExercise;

  /// Every module id [getExercise] was called with, in order.
  final List<int> exerciseCalls = [];

  Completer<void>? _exerciseGate;

  void releaseExercise() {
    final gate = _exerciseGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<CourseExercise> getExercise(int moduleId) async {
    exerciseCalls.add(moduleId);

    if (holdExercise) {
      _exerciseGate = Completer<void>();
      await _exerciseGate!.future;
    }

    return exercise ?? sampleExercise(moduleId: moduleId);
  }
}

/// A minimal module, every field overridable, for a test that only cares
/// about one or two of them.
CourseModule sampleModule({
  int id = 1,
  int order = 1,
  String title = 'Prediction and Probabilities',
  String scheduleLabel = '08/04 • Да • 09:00',
  String iconAsset = 'assets/images/course_learning/module_ai.svg',
  Color accentColor = const Color(0xFF408CFF),
  bool completed = false,
  bool locked = false,
}) => CourseModule(
  id: id,
  order: order,
  title: title,
  scheduleLabel: scheduleLabel,
  iconAsset: iconAsset,
  accentColor: accentColor,
  completed: completed,
  locked: locked,
);

/// The Figma sample: two completed modules, three locked, 30% complete.
CourseLearningPath samplePath({
  String courseSlug = 'how-ai-works',
  String courseTitle = 'How AI works',
  String description =
      'Take a peek under the hood of generative AI and LLMs to understand how they work',
  int percentComplete = 30,
  List<CourseModule>? modules,
}) => CourseLearningPath(
  courseSlug: courseSlug,
  courseTitle: courseTitle,
  description: description,
  illustrationAsset: 'assets/images/course_learning/how_ai_works.svg',
  percentComplete: percentComplete,
  modules:
      modules ??
      [
        sampleModule(
          id: 1,
          order: 1,
          title: 'Prediction and Probabilities',
          completed: true,
        ),
        sampleModule(
          id: 2,
          order: 2,
          title: 'Language Model Training',
          iconAsset: 'assets/images/course_learning/module_training.svg',
          accentColor: const Color(0xFFFFC640),
          completed: true,
        ),
        sampleModule(
          id: 3,
          order: 3,
          title: 'Deep network models',
          iconAsset: 'assets/images/course_learning/module_neural_network.svg',
          accentColor: const Color(0xFFBF40FF),
          locked: true,
        ),
        sampleModule(
          id: 4,
          order: 4,
          title: 'Neurons and Layers',
          iconAsset: 'assets/images/course_learning/module_brain.svg',
          accentColor: const Color(0xFFFF409C),
          locked: true,
        ),
        sampleModule(
          id: 5,
          order: 5,
          title: 'Image Models',
          iconAsset: 'assets/images/course_learning/module_image.svg',
          accentColor: const Color(0xFF40FFA3),
          locked: true,
        ),
      ],
);

/// A minimal lesson, every field overridable, for a test that only cares
/// about one or two of them.
Lesson sampleLesson({
  int id = 2,
  int moduleId = 2,
  int order = 2,
  String title = 'Nesting loops',
  String durationLabel = '24:15',
  bool completed = false,
  bool locked = false,
}) => Lesson(
  id: id,
  moduleId: moduleId,
  order: order,
  title: title,
  durationLabel: durationLabel,
  completed: completed,
  locked: locked,
);

/// The sample module's own three lessons: one completed, one open, one
/// locked — mirrors [samplePath]'s own completed/locked mix at module level.
List<Lesson> sampleLessons({int moduleId = 2, List<Lesson>? lessons}) =>
    lessons ??
    [
      sampleLesson(
        id: 1,
        moduleId: moduleId,
        order: 1,
        title: 'Introduction to loops',
        durationLabel: '12:30',
        completed: true,
      ),
      sampleLesson(id: 2, moduleId: moduleId, order: 2),
      sampleLesson(
        id: 3,
        moduleId: moduleId,
        order: 3,
        title: 'Practice: matrix traversal',
        durationLabel: '18:40',
        locked: true,
      ),
    ];

/// The Figma "Nesting loops" sample, note included by default — pass
/// `note: null` for the empty/edit-state fixture.
CourseExercise sampleExercise({
  int moduleId = 2,
  String moduleCaption = 'Modules 2',
  String title = 'Nesting loops',
  String durationLabel = '24:15',
  String recordingBadgeLabel = 'Live Classroom Recording',
  String summary =
      'A nested loop is a loop placed entirely within the body '
      'of another loop. For every single iteration of the outer '
      'loop, the inner loop executes from start to finish. They '
      'are primarily used for processing multi-dimensional '
      'data structures like matrices, generating '
      'combinations, or handling complex sorting algorithms.',
  List<CourseExerciseSection> extraSections = const [
    CourseExerciseSection(
      title: 'Pre-training',
      body:
          'In the pre-training phase, the model is fed trillions of '
          'tokens (such as text scraped from the internet, books, '
          'and code) to learn fundamental knowledge about the '
          'world.',
      bullets: ['Self-Supervised Learning', 'Base Model Creation'],
    ),
  ],
  List<CourseExerciseMaterial>? materials,
  Object? note = _unset,
  List<AssignmentMentorFeedback>? assignmentFeedback,
  CourseExerciseMaterial? assignmentAttachment,
  CourseQuiz? quiz,
}) => CourseExercise(
  moduleId: moduleId,
  moduleCaption: moduleCaption,
  title: title,
  durationLabel: durationLabel,
  recordingBadgeLabel: recordingBadgeLabel,
  summary: summary,
  extraSections: extraSections,
  materials:
      materials ??
      [sampleMaterial(), sampleMaterial(id: 2, sizeLabel: '12 MB')],
  note: identical(note, _unset) ? sampleNote() : note as CourseExerciseNote?,
  assignmentFeedback: assignmentFeedback ?? sampleAssignmentFeedback(),
  // Unlike `note`/`assignmentFeedback`, these default to null (no override
  // sentinel needed): a test that does not care about the attachment/quiz
  // flow should see exactly what every other exercise does today — neither
  // — so only tests that explicitly want one pass `sampleAttachment()`/
  // `sampleQuiz()` in.
  assignmentAttachment: assignmentAttachment,
  quiz: quiz,
);

/// Sentinel distinguishing "the caller did not pass `note`" (default to
/// [sampleNote]) from "the caller explicitly passed `note: null`" (the
/// empty/edit-state fixture) — both are valid, different fixtures.
const Object _unset = Object();

CourseExerciseMaterial sampleMaterial({
  int id = 1,
  String name = 'Course material 1',
  String sizeLabel = '10 MB',
}) => CourseExerciseMaterial(id: id, name: name, sizeLabel: sizeLabel);

/// The Assignment tab's own attachment — mirrors production's default.
CourseExerciseMaterial sampleAttachment({
  int id = 3,
  String name = 'Assignment template.zip',
  String sizeLabel = '4 MB',
}) => CourseExerciseMaterial(id: id, name: name, sizeLabel: sizeLabel);

/// A minimal two-question quiz — enough to exercise "some answered, not
/// all", "all correct" and "some wrong" without a test having to reason
/// about three questions' worth of state.
///
/// Prompts deliberately avoid the literal text "Question 1"/"Question 2" —
/// `_QuizQuestionCard` already renders that as its own numbered label, and a
/// prompt with the same text would make `find.text('Question 1')` match two
/// widgets instead of one.
CourseQuiz sampleQuiz({
  String title = 'Sample quiz',
  String estimatedMinutesLabel = '~2 min',
  List<QuizQuestion> questions = const [
    QuizQuestion(
      prompt: 'Pick the right answer (first question)',
      options: ['Right', 'Wrong'],
      correctOptionIndex: 0,
    ),
    QuizQuestion(
      prompt: 'Pick the right answer (second question)',
      options: ['Wrong', 'Right'],
      correctOptionIndex: 1,
    ),
  ],
}) => CourseQuiz(
  title: title,
  estimatedMinutesLabel: estimatedMinutesLabel,
  questions: questions,
);

/// The sample module's two canned mentor responses: a resubmission request,
/// then an acceptance — mirrors production's own default sequence.
List<AssignmentMentorFeedback> sampleAssignmentFeedback() => const [
  AssignmentMentorFeedback(
    mentorInitials: 'ГЭ',
    mentorName: 'Ганбаатар Эрдэнэ',
    message: 'Please check the matrix traversal and resubmit.',
    timestampLabel: 'Yesterday, 16:40',
    requiresResubmission: true,
  ),
  AssignmentMentorFeedback(
    mentorInitials: 'ГЭ',
    mentorName: 'Ганбаатар Эрдэнэ',
    message: 'Nice work — accepted.',
    timestampLabel: 'Today, 09:15',
    requiresResubmission: false,
  ),
];

CourseExerciseNote sampleNote({
  String authorInitials = 'БП',
  String authorName = 'Болд Батаа',
  String authorLabel = 'Me',
  String message =
      'Good foundation — improve validation '
      'accuracy before final submission. Look into '
      'hyperparameter tuning for the XGBoost '
      'model.',
  String timestampLabel = 'Today, 14:20',
}) => CourseExerciseNote(
  authorInitials: authorInitials,
  authorName: authorName,
  authorLabel: authorLabel,
  message: message,
  timestampLabel: timestampLabel,
);
