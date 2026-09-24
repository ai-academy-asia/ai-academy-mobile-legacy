import 'package:flutter/widgets.dart';

import '../domain/course_learning_path.dart';
import '../domain/course_learning_repository.dart';
import '../domain/course_module.dart';

/// Serves one hand-authored [CourseLearningPath], regardless of which
/// [getCourseLearning] is asked for.
///
/// **Placeholder pending a real learning API.** `course_learning_api_
/// requirements_v1.md` confirms no `Module`/`Lesson`/progress endpoint exists
/// yet, and explicitly recommends confirming the backend contract before
/// mocking one — this exists anyway because the issue this ships for asks for
/// the Course Learning *screens* now, against sample data, with the backend
/// call still to come. Content (module titles, schedule lines, which two are
/// "completed") is transcribed from the Figma reference for the one course it
/// shows ("How AI works"); every other slug gets the same content today,
/// which is the smallest thing that lets the screen render at all until a
/// real per-course source exists.
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

  static String _asset(String name) => 'assets/images/course_learning/$name';
}
