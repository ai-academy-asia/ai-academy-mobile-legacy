/// One lesson inside a module — the unit `CourseModule` breaks down into,
/// per the Figma flow's Module → Lesson step.
///
/// Filled by `HttpCourseLearningRepository` from
/// `GET /me/modules/{module_id}/lessons` (`course_learning_api_contract_v1.md`
/// §2.2), or by the sample repository. Every field is the server's: [id],
/// [order], [title], [type], [completed] and [locked] come straight off the
/// wire, [moduleId] is the response's `module.id`, and [durationLabel] is
/// `duration_seconds` formatted for the row.
class Lesson {
  const Lesson({
    required this.id,
    required this.moduleId,
    required this.order,
    required this.title,
    required this.type,
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

  /// What kind of lesson this is — the contract's `type`.
  final LessonType type;

  /// e.g. `"24:15"` — `duration_seconds` as the row draws it, `M:SS` under an
  /// hour and `H:MM:SS` from one up. Kept pre-formatted, the same treatment
  /// `CourseExercise.durationLabel` and `CourseModule.scheduleLabel` get, so
  /// `LessonListItem` stays exactly as it is.
  final String durationLabel;

  /// Server-sent; never derived.
  final bool completed;

  /// True when the lesson is not yet reachable. Server-sent — the contract
  /// has it follow the lesson's module, but the client reads it per lesson
  /// rather than deriving it. Same independence from [completed] that
  /// `CourseModule.locked` documents.
  final bool locked;
}

/// A lesson's `type`, per `course_learning_api_contract_v1.md` §2.2.
///
/// The contract lists three values; the client maps them to a badge and the
/// server sends no badge text. [unknown] holds anything else — a value the
/// backend adds later must not take the whole lesson list down with it.
enum LessonType {
  /// `"recording"` — a live-class recording.
  recording,

  /// `"video"`.
  video,

  /// `"reading"`.
  reading,

  /// Any value this build does not know.
  unknown;

  /// Reads the wire value. Anything but the three documented strings is
  /// [unknown].
  static LessonType fromApi(String value) => switch (value) {
    'recording' => recording,
    'video' => video,
    'reading' => reading,
    _ => unknown,
  };
}
