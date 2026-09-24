import 'course_module.dart';

/// One course's full learning overview — the Figma "Course Learning" screen's
/// hero, progress row and module list, all at once.
///
/// **Sample data only** — see `CourseModule`'s doc comment. [percentComplete]
/// in particular is stored rather than computed from [modules]: the Figma
/// reference shows "30% complete" against two *completed* modules out of
/// five (a clean 40% if it were module count), so the two are evidently not
/// the same figure — `course_learning_api_requirements_v1.md` lists "course
/// progress %" as its own separate confirmed-needed data point, distinct from
/// "completed modules / total modules". Deriving one from the other would be
/// asserting a relationship nothing has confirmed.
class CourseLearningPath {
  const CourseLearningPath({
    required this.courseSlug,
    required this.courseTitle,
    required this.description,
    required this.illustrationAsset,
    required this.percentComplete,
    required this.modules,
  });

  /// Which course this path belongs to — `Course.slug`, the one identifier
  /// already confirmed by the real course contract.
  final String courseSlug;

  final String courseTitle;
  final String description;

  /// `assets/images/course_learning/how_ai_works.svg`, or another course's
  /// equivalent once more than one sample path exists.
  final String illustrationAsset;

  /// 0–100.
  final int percentComplete;

  final List<CourseModule> modules;
}
