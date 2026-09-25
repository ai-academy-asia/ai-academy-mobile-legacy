import 'package:flutter/widgets.dart';

import '../domain/course_exercise.dart';
import '../domain/course_learning_path.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_module.dart';
import '../domain/course_quiz.dart';
import '../domain/lesson.dart';

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
/// match this exercise's own.
class SampleCourseLearningRepository implements CourseLearningRepository {
  @override
  Future<CourseLearningPath> getCourseLearning(String courseSlug) async {
    return CourseLearningPath(
      courseSlug: courseSlug,
      courseTitle: 'How AI works',
      description:
          'Take a peek under the hood of generative AI and LLMs to understand how they work',
      illustrationAsset: _asset('how_ai_works.svg'),
      percentComplete: 30,
      modules: [
        CourseModule(
          id: 1,
          order: 1,
          title: 'Prediction and Probabilities',
          scheduleLabel: '08/04 • Да • 09:00',
          iconAsset: _asset('module_ai.svg'),
          accentColor: const Color(0xFF408CFF),
          completed: true,
          locked: false,
        ),
        CourseModule(
          id: 2,
          order: 2,
          title: 'Language Model Training',
          scheduleLabel: '08/04 • 09:00–11:00',
          iconAsset: _asset('module_training.svg'),
          accentColor: const Color(0xFFFFC640),
          completed: true,
          locked: false,
        ),
        CourseModule(
          id: 3,
          order: 3,
          title: 'Deep network models',
          scheduleLabel: '08/04 • 09:00–11:00',
          iconAsset: _asset('module_neural_network.svg'),
          accentColor: const Color(0xFFBF40FF),
          completed: false,
          locked: true,
        ),
        CourseModule(
          id: 4,
          order: 4,
          title: 'Neurons and Layers',
          scheduleLabel: '08/04 • 09:00–11:00',
          iconAsset: _asset('module_brain.svg'),
          accentColor: const Color(0xFFFF409C),
          completed: false,
          locked: true,
        ),
        CourseModule(
          id: 5,
          order: 5,
          title: 'Image Models',
          scheduleLabel: '08/04 • 09:00–11:00',
          iconAsset: _asset('module_image.svg'),
          accentColor: const Color(0xFF40FFA3),
          completed: false,
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
        durationLabel: '24:15',
        completed: false,
        locked: false,
      ),
      Lesson(
        id: 3,
        moduleId: moduleId,
        order: 3,
        title: 'Practice: matrix traversal',
        durationLabel: '18:40',
        completed: false,
        locked: true,
      ),
    ];
  }

  @override
  Future<CourseExercise> getExercise(int moduleId) async {
    return CourseExercise(
      moduleId: moduleId,
      moduleCaption: 'Modules 2',
      title: 'Nesting loops',
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
      note: const CourseExerciseNote(
        authorInitials: 'БП',
        authorName: 'Болд Батаа',
        authorLabel: 'Me',
        message:
            'Good foundation — improve validation '
            'accuracy before final submission. Look into '
            'hyperparameter tuning for the XGBoost '
            'model.',
        timestampLabel: 'Today, 14:20',
      ),
      assignmentFeedback: const [
        AssignmentMentorFeedback(
          mentorInitials: 'БП',
          mentorName: 'Б.Пүрэв',
          mentorRole: 'Lead Mentor',
          message:
              'Good foundation — improve validation accuracy before final '
              'submission. Look into hyperparameter tuning for the XGBoost '
              'model.',
          timestampLabel: 'Today, 14:20',
        ),
      ],
      assignmentAttachment: const CourseExerciseMaterial(
        id: 3,
        name: 'Assignment template.zip',
        sizeLabel: '1 MB',
      ),
      quiz: const CourseQuiz(
        title: 'Nesting loops quiz',
        resultTitle: 'Level 2 - Language Model Training',
        questions: [
          QuizQuestion(
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
          QuizQuestion(
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
          QuizQuestion(
            prompt: 'Neural Network загвар юуг дуурайдаг вэ?',
            options: [
              'Хүний тархи',
              'Компьютерийн CPU',
              'Интернет сүлжээ',
              'Мэдэхгүй',
            ],
            correctOptionIndex: 0,
            explanation:
                'Artificial neural networks are loosely inspired by the '
                'human brain — layers of interconnected nodes ("neurons") '
                'pass signals to one another to recognize patterns.',
          ),
          QuizQuestion(
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
        ],
      ),
    );
  }

  static String _asset(String name) => 'assets/images/course_learning/$name';
}
