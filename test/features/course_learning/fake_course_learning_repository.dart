import 'dart:async';
import 'dart:ui';

import 'package:aia_mobile/features/course_learning/domain/course_learning_path.dart';
import 'package:aia_mobile/features/course_learning/domain/course_learning_repository.dart';
import 'package:aia_mobile/features/course_learning/domain/course_module.dart';

/// A repository the tests drive by hand.
///
/// Same `hold`/`release` shape as `FakeCourseRepository`, even though the
/// real `SampleCourseLearningRepository` never actually awaits anything —
/// this lets a controller test still observe the brief `loading` state
/// `CourseLearningController.load()` reports before its `await` resolves.
class FakeCourseLearningRepository implements CourseLearningRepository {
  FakeCourseLearningRepository({this.path, this.hold = false});

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
