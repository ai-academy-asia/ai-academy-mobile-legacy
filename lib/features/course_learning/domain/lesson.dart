/// One lesson inside a module — the unit `CourseModule` breaks down into,
/// per the Figma flow's Module → Lesson step.
///
/// **Sample data only**, same status as `CourseModule` (see that class's own
/// doc comment): no backend endpoint for lessons exists yet —
/// `course_learning_api_requirements_v1.md` lists `GET
/// /modules/{module_id}/lessons` under "requires backend confirmation," not
/// under confirmed endpoints. Kept deliberately small — this app's own
/// `CourseModule` fields it mirrors, plus [durationLabel] for the one thing a
/// lesson row shows that a module row does not (each lesson is one video).
class Lesson {
  const Lesson({
    required this.id,
    required this.moduleId,
    required this.order,
    required this.title,
    required this.durationLabel,
    required this.completed,
    required this.locked,
  });

  final int id;

  /// `CourseModule.id` — which module this lesson belongs to.
  final int moduleId;

  /// 1-based position within its module, the same role `CourseModule.order`
  /// plays within a course.
  final int order;

  final String title;

  /// e.g. `"24:15"` — the same pre-formatted-string treatment
  /// `CourseExercise.durationLabel` already uses, for the same reason: one
  /// confirmed shape has not been shown yet, so there is nothing to split
  /// into separate fields.
  final String durationLabel;

  final bool completed;

  /// True when the lesson is not yet reachable. Same independence from
  /// [completed] that `CourseModule.locked` documents.
  final bool locked;
}
