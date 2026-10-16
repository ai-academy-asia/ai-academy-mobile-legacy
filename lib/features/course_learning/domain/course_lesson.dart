import 'course_module.dart';
import 'lesson.dart';

/// One lesson as Course Detail lists it (Issue #437): every lesson of the
/// course in one list, each still carrying the module it belongs to.
class CourseLesson {
  const CourseLesson({
    required this.lesson,
    required this.module,
    required this.number,
  });

  /// The lesson as `GET /me/modules/{module_id}/lessons` sent it, with its
  /// completion read back from its note (Issue #415).
  final Lesson lesson;

  /// The module the lesson is in — its artwork and accent draw the card's
  /// tile, and its lock is the lesson's too.
  final CourseModule module;

  /// The lesson's position in the whole course, from 1: modules in the order
  /// the server lists them, then each module's lessons in theirs.
  final int number;

  /// Locked when the server locks the lesson or its module — the same reading
  /// Junior Home's lesson path makes of the same data.
  bool get locked => lesson.locked || module.locked;
}

/// Every lesson of [modules], in course order and numbered from 1:
/// [lessonsByModule] holds each module's lessons as the server listed them.
/// A module with no entry contributes none.
List<CourseLesson> courseLessonsOf(
  List<CourseModule> modules,
  Map<int, List<Lesson>> lessonsByModule,
) {
  final result = <CourseLesson>[];
  for (final module in modules) {
    for (final lesson in lessonsByModule[module.id] ?? const <Lesson>[]) {
      result.add(
        CourseLesson(lesson: lesson, module: module, number: result.length + 1),
      );
    }
  }
  return result;
}
