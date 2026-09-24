import 'package:flutter/widgets.dart';

/// One module in a course's learning path, as the Figma "Course Learning"
/// overview screen lists it.
///
/// **Sample data only.** No backend endpoint for course modules exists yet —
/// `course_learning_api_requirements_v1.md` lists `GET
/// /courses/{course_id}/modules` under "requires backend confirmation," not
/// under confirmed endpoints. Every field here is this app's own choice for
/// local sample data, not a claim about what a real API will eventually send;
/// contrast with `Course`, whose fields each cite a confirmed response.
class CourseModule {
  const CourseModule({
    required this.id,
    required this.order,
    required this.title,
    required this.scheduleLabel,
    required this.iconAsset,
    required this.accentColor,
    required this.completed,
    required this.locked,
  });

  final int id;

  /// 1-based position — the Figma reference captions every card "Modules N"
  /// rather than naming it, so this is what fills that caption.
  final int order;

  final String title;

  /// The card's date/time line, e.g. "08/04 • Да • 09:00" or
  /// "08/04 • 09:00–11:00". Kept as one pre-formatted string rather than
  /// separate date/weekday/time fields: the two Figma examples do not agree
  /// on a shape (one names a weekday, the other a time range), so there is no
  /// single confirmed structure to split it into.
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

  final bool completed;

  /// True when the module is not yet reachable. Independent of [completed]:
  /// the Figma sample has modules 1–2 completed and 3–5 locked, with no
  /// module in between that is merely "available, not started" — so that
  /// third state has no confirmed visual yet and is not modelled here.
  final bool locked;
}
