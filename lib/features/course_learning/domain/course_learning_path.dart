import 'course_module.dart';

/// One course's full learning overview — the Figma "Course Learning" screen's
/// hero, progress row and module list, all at once.
///
/// Filled by `HttpCourseLearningRepository` from
/// `GET /me/courses/{course_slug}/learning`, or by the sample repository where
/// no endpoint is wired yet.
///
/// [percentComplete] is stored rather than computed from [modules], and the
/// backend contract is now explicit about why: it is **server-computed** as
/// `floor(completed_lessons / total_lessons × 100)`, so it counts *lessons*,
/// not modules. That is what resolves the Figma reference's apparent
/// contradiction — "30% complete" beside two completed modules out of five,
/// which would be a clean 40% if the figure were module-based. The client
/// displays it and never derives it.
class CourseLearningPath {
  const CourseLearningPath({
    required this.courseSlug,
    required this.courseTitle,
    required this.description,
    required this.illustrationAsset,
    required this.percentComplete,
    required this.modules,
    this.continueModuleId,
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

  /// Which module "Continue learning" should open — `continue.module_id` from
  /// `course_learning_api_contract_v1.md` §2.1, where the selection is
  /// **server-side**: the first unlocked, uncompleted lesson's module, or the
  /// last one when everything is done.
  ///
  /// Nullable because the contract sends `continue: null` when nothing is
  /// unlocked, and because the sample path has no server to ask. The screen
  /// falls back to its own rule then — see `_continueLearningTarget`.
  final int? continueModuleId;
}
