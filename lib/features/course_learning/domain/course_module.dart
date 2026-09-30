import 'package:flutter/widgets.dart';

/// One module in a course's learning path, as the Figma "Course Learning"
/// overview screen lists it.
///
/// Fields split two ways now that `GET /me/courses/{course_slug}/learning`
/// backs this screen. [id], [order], [title], [lessonCount],
/// [completedLessons], [completed] and [locked] come straight off the wire —
/// the contract sends each one, and is explicit that the client must **not**
/// derive [completed] or [locked] for itself.
/// [scheduleLabel] is formatted from the response's raw `schedule` object.
/// [iconAsset] and [accentColor] have no wire field at all and never will:
/// the contract states the backend sends no icon, image or colour, and that
/// the client maps [order] onto its own bundled palette (see
/// `data/course_module_visuals.dart`).
class CourseModule {
  const CourseModule({
    required this.id,
    required this.order,
    required this.title,
    required this.scheduleLabel,
    required this.iconAsset,
    required this.accentColor,
    required this.lessonCount,
    required this.completedLessons,
    required this.completed,
    required this.locked,
  });

  final int id;

  /// 1-based position — the Figma reference captions every card "Modules N"
  /// rather than naming it, so this is what fills that caption.
  final int order;

  final String title;

  /// The card's date/time line, e.g. "08/04 • Да • 09:00". Kept as one
  /// pre-formatted string: the API sends `{date, start_time}` and the client
  /// composes the label, weekday included (see
  /// `HttpCourseLearningRepository`'s `_scheduleLabel`). Empty for a module
  /// with no scheduled session, which the contract sends as `schedule: null`.
  /// Still a plain string rather than structured fields partly because the
  /// Figma frames show a second shape too — "08/04 • 09:00–11:00", which the
  /// sample data reproduces — and the API sends no end time to build it from.
  final String scheduleLabel;

  /// One of `assets/images/course_learning/module_*.svg`. Ignored while
  /// [locked] — a locked card draws a plain lock glyph instead, matching the
  /// Figma reference's own smaller "locked icon container".
  final String iconAsset;

  /// [iconAsset]'s own accent colour, sampled from that SVG's fill — used to
  /// tint the icon's tile background, the same soft-tint treatment
  /// `ProgramCard`'s status pill already uses (`color.withValues(alpha:
  /// ...)`) rather than a flat colour.
  final Color accentColor;

  /// How many lessons the module holds — `lesson_count`. Not drawn by the
  /// Figma module card; carried so the module's own counts are not dropped
  /// between the wire and the screen.
  final int lessonCount;

  /// How many of them the student has completed — `completed_lessons`.
  /// Server-sent, like [completed]; never tallied here.
  final int completedLessons;

  final bool completed;

  /// True when the module is not yet reachable. Independent of [completed]:
  /// the Figma sample has modules 1–2 completed and 3–5 locked, with no
  /// module in between that is merely "available, not started" — so that
  /// third state has no confirmed visual yet and is not modelled here.
  final bool locked;
}
