import 'dart:async';
import 'dart:ui';

import 'package:aia_mobile/features/course_learning/domain/course_exercise.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_failure.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_path.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_module.dart';
import 'package:aia_mobile/features/course_learning/domain/course_quiz.dart';
import 'package:aia_mobile/features/course_learning/domain/lesson.dart';
import 'package:aia_mobile/features/course_learning/domain/material_download.dart';

/// A repository the tests drive by hand.
///
/// Same `hold`/`release` shape as `FakeCourseRepository`, even though the
/// real `SampleCourseLearningRepository` never actually awaits anything —
/// this lets a controller test still observe the brief `loading` state
/// `CourseLearningController.load()` reports before its `await` resolves.
/// [getCourseLearning], [getLessons], [getExercise], [saveNote],
/// [getMaterialDownload] and [submitAssignment] are tracked independently, same reasoning as `FakeCourseRepository`'s
/// `getCourses`/`getCourseDetail` split.
class FakeCourseLearningRepository implements CourseLearningRepository {
  FakeCourseLearningRepository({
    this.path,
    this.hold = false,
    this.failure,
    this.lessons,
    this.holdLessons = false,
    this.lessonsFailure,
    this.exercise,
    this.holdExercise = false,
    this.exerciseFailure,
    this.savedNote,
    this.holdSave = false,
    this.saveFailure,
    this.download,
    this.holdDownload = false,
    this.downloadFailure,
    this.submission,
    this.holdSubmit = false,
    this.submitFailure,
  });

  // --- getCourseLearning ---------------------------------------------------

  /// Returned on success. Defaults to [samplePath] if unset.
  CourseLearningPath? path;

  /// When true, [getCourseLearning] blocks until [release] is called.
  bool hold;

  /// Thrown by [getCourseLearning] instead of returning, so a controller test
  /// can drive the error state the real `HttpCourseLearningRepository`
  /// produces. Thrown *after* [hold] releases, so a test can watch `loading`
  /// go true and then observe the failure.
  CourseLearningFailure? failure;

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

    if (failure case final failure?) throw failure;

    return path ?? samplePath(courseSlug: courseSlug);
  }

  // --- getLessons --------------------------------------------------------

  /// Returned on success. Defaults to [sampleLessons] if unset.
  List<Lesson>? lessons;

  /// When true, [getLessons] blocks until [releaseLessons] is called.
  bool holdLessons;

  /// Thrown by [getLessons] instead of returning, after [holdLessons]
  /// releases. Settable between calls, so a retry can succeed.
  CourseLearningFailure? lessonsFailure;

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

    if (lessonsFailure case final failure?) throw failure;

    return lessons ?? sampleLessons(moduleId: moduleId);
  }

  // --- getExercise -----------------------------------------------------

  /// Returned on success. Defaults to [sampleExercise] if unset.
  CourseExercise? exercise;

  /// When true, [getExercise] blocks until [releaseExercise] is called.
  bool holdExercise;

  /// Thrown by [getExercise] instead of returning, after [holdExercise]
  /// releases. Settable between calls, so a retry can succeed.
  CourseLearningFailure? exerciseFailure;

  /// Every lesson id [getExercise] was called with, in order.
  final List<int> exerciseCalls = [];

  Completer<void>? _exerciseGate;

  void releaseExercise() {
    final gate = _exerciseGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<CourseExercise> getExercise(int lessonId) async {
    exerciseCalls.add(lessonId);

    if (holdExercise) {
      _exerciseGate = Completer<void>();
      await _exerciseGate!.future;
    }

    if (exerciseFailure case final failure?) throw failure;

    return exercise ?? sampleExercise(lessonId: lessonId);
  }

  // --- saveNote ----------------------------------------------------------

  /// Returned on success. Unset, the saved note is what
  /// `SampleCourseLearningRepository.saveNote` answers — the sample student,
  /// the saved text, "Just now" — which every sample-flow test and golden
  /// was written against.
  CourseExerciseNote? savedNote;

  /// When true, [saveNote] blocks until [releaseSave] is called.
  bool holdSave;

  /// Thrown by [saveNote] instead of returning, after [holdSave] releases.
  /// Settable between calls, so a retry can succeed.
  CourseLearningFailure? saveFailure;

  /// Every `(lessonId, content)` [saveNote] was called with, in order.
  final List<(int, String)> saveCalls = [];

  Completer<void>? _saveGate;

  void releaseSave() {
    final gate = _saveGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<CourseExerciseNote> saveNote(int lessonId, String content) async {
    saveCalls.add((lessonId, content));

    if (holdSave) {
      _saveGate = Completer<void>();
      await _saveGate!.future;
    }

    if (saveFailure case final failure?) throw failure;

    return savedNote ??
        sampleNote(message: content, timestampLabel: 'Just now');
  }

  // --- getMaterialDownload -----------------------------------------------

  /// Returned on success. Defaults to [sampleDownload] for the material
  /// asked for.
  MaterialDownload? download;

  /// When true, [getMaterialDownload] blocks until [releaseDownload] is
  /// called.
  bool holdDownload;

  /// Thrown by [getMaterialDownload] instead of returning, after
  /// [holdDownload] releases. Settable between calls, so a retry can succeed.
  CourseLearningFailure? downloadFailure;

  /// Every material id [getMaterialDownload] was called with, in order.
  final List<int> downloadCalls = [];

  Completer<void>? _downloadGate;

  void releaseDownload() {
    final gate = _downloadGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<MaterialDownload> getMaterialDownload(int materialId) async {
    downloadCalls.add(materialId);

    if (holdDownload) {
      _downloadGate = Completer<void>();
      await _downloadGate!.future;
    }

    if (downloadFailure case final failure?) throw failure;

    return download ?? sampleDownload(materialId: materialId);
  }

  // --- submitAssignment --------------------------------------------------

  /// Returned on success. Defaults to [sampleSubmission] carrying the link
  /// and description it was sent.
  AssignmentSubmission? submission;

  /// When true, [submitAssignment] blocks until [releaseSubmit] is called.
  bool holdSubmit;

  /// Thrown by [submitAssignment] instead of returning, after [holdSubmit]
  /// releases. Settable between calls, so a retry can succeed.
  CourseLearningFailure? submitFailure;

  /// Every `(assignmentId, link, description)` [submitAssignment] was called
  /// with, in order.
  final List<(int, String, String?)> submitCalls = [];

  Completer<void>? _submitGate;

  void releaseSubmit() {
    final gate = _submitGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<AssignmentSubmission> submitAssignment(
    int assignmentId, {
    required String link,
    String? description,
  }) async {
    submitCalls.add((assignmentId, link, description));

    if (holdSubmit) {
      _submitGate = Completer<void>();
      await _submitGate!.future;
    }

    if (submitFailure case final failure?) throw failure;

    return submission ??
        sampleSubmission(link: link, description: description);
  }
}

/// A §2.6 submission, as a submit answers — unreviewed unless a test passes
/// [feedback].
AssignmentSubmission sampleSubmission({
  int id = 301,
  int version = 1,
  String? link = 'https://github.com/student/loops',
  String? description,
  AssignmentMentorFeedback? feedback,
}) => AssignmentSubmission(
  id: id,
  version: version,
  status: feedback == null
      ? AssignmentSubmissionStatus.submitted
      : AssignmentSubmissionStatus.reviewed,
  submittedAt: DateTime.utc(2026, 8, 5, 3),
  link: link,
  description: description,
  feedback: feedback,
);

/// A §2.4 download answer for [materialId] — a stand-in pre-signed URL.
MaterialDownload sampleDownload({int materialId = 1}) => MaterialDownload(
  url: Uri.parse('https://files.example.test/materials/$materialId.pdf?sig=x'),
  expiresAt: DateTime.utc(2026, 8, 6, 1, 5),
  fileName: 'material-$materialId.pdf',
  sizeBytes: 10485760,
);

/// A minimal module, every field overridable, for a test that only cares
/// about one or two of them.
CourseModule sampleModule({
  int id = 1,
  int order = 1,
  String title = 'Prediction and Probabilities',
  String scheduleLabel = '08/04 • Да • 09:00',
  String iconAsset = 'assets/images/course_learning/module_ai.svg',
  Color accentColor = const Color(0xFF408CFF),
  int lessonCount = 3,
  int? completedLessons,
  bool completed = false,
  bool locked = false,
}) => CourseModule(
  id: id,
  order: order,
  title: title,
  scheduleLabel: scheduleLabel,
  iconAsset: iconAsset,
  accentColor: accentColor,
  lessonCount: lessonCount,
  // A completed module has completed every lesson, unless a test says
  // otherwise.
  completedLessons: completedLessons ?? (completed ? lessonCount : 0),
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
  int? continueModuleId,
  int? continueLessonId,
  String? certificateStatus,
}) => CourseLearningPath(
  courseSlug: courseSlug,
  courseTitle: courseTitle,
  description: description,
  illustrationAsset: 'assets/images/course_learning/how_ai_works.svg',
  percentComplete: percentComplete,
  // Null by default, matching the sample repository: a path with no server
  // answer is what every existing test was written against.
  continueModuleId: continueModuleId,
  continueLessonId: continueLessonId,
  certificateStatus: certificateStatus,
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
  LessonType type = LessonType.recording,
  String durationLabel = '24:15',
  bool completed = false,
  bool locked = false,
}) => Lesson(
  id: id,
  moduleId: moduleId,
  order: order,
  title: title,
  type: type,
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
  int lessonId = 2,
  int moduleId = 2,
  String moduleCaption = 'Modules 2',
  String title = 'Nesting loops',
  LessonType type = LessonType.recording,
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
  CourseAssignment? assignment,
  CourseQuiz? quiz,
  bool hasVideo = true,
  bool completed = false,
  // The sample's local simulations — what every existing screen test and
  // golden was written against.
  bool simulatesWrites = true,
}) => CourseExercise(
  lessonId: lessonId,
  moduleId: moduleId,
  moduleCaption: moduleCaption,
  title: title,
  type: type,
  durationLabel: durationLabel,
  recordingBadgeLabel: recordingBadgeLabel,
  summary: summary,
  hasVideo: hasVideo,
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
  assignment: assignment,
  quiz: quiz,
  completed: completed,
  simulatesWrites: simulatesWrites,
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
  String sizeLabel = '1 MB',
}) => CourseExerciseMaterial(id: id, name: name, sizeLabel: sizeLabel);

/// A minimal two-question quiz — enough to exercise "some answered, not
/// all", "all correct" and "some wrong" without a test having to reason
/// about three questions' worth of state.
CourseQuiz sampleQuiz({
  String title = 'Sample quiz',
  String resultTitle = 'Sample result',
  List<QuizQuestion> questions = const [
    QuizQuestion(
      prompt: 'Pick the right answer (first question)',
      options: ['Right', 'Wrong'],
      correctOptionIndex: 0,
      explanation: 'The first option is right.',
    ),
    QuizQuestion(
      prompt: 'Pick the right answer (second question)',
      options: ['Wrong', 'Right'],
      correctOptionIndex: 1,
      explanation: 'The second option is right.',
    ),
  ],
}) => CourseQuiz(title: title, resultTitle: resultTitle, questions: questions);

/// The sample module's own mentor response — mirrors production's default.
List<AssignmentMentorFeedback> sampleAssignmentFeedback() => const [
  AssignmentMentorFeedback(
    mentorInitials: 'БП',
    mentorName: 'Б.Пүрэв',
    mentorRole: 'Lead Mentor',
    message: 'Good foundation — improve validation accuracy.',
    timestampLabel: 'Today, 14:20',
  ),
  AssignmentMentorFeedback(
    mentorInitials: 'БП',
    mentorName: 'Б.Пүрэв',
    mentorRole: 'Lead Mentor',
    message: 'Nice work — accepted.',
    timestampLabel: 'Today, 16:40',
  ),
];

CourseExerciseNote sampleNote({
  String authorInitials = 'БП',
  String authorName = 'Болд Батаа',
  String authorLabel = 'Me',
  String message =
      '"Good foundation — improve validation '
      'accuracy before final submission. Look into '
      'hyperparameter tuning for the XGBoost '
      'model."',
  String timestampLabel = 'Today, 14:20',
}) => CourseExerciseNote(
  authorInitials: authorInitials,
  authorName: authorName,
  authorLabel: authorLabel,
  message: message,
  timestampLabel: timestampLabel,
);
