import 'package:flutter/material.dart';

import '../domain/course_learning_repository.dart';
import '../domain/lesson_access.dart';
import 'course_exercise_detail_screen.dart';

/// The one way any screen opens a lesson's content (Issue #410).
///
/// **The rule is [lessonOpens]:** the server leaves the lesson unlocked (its
/// module's first class date has come — the backend's `locked`), and it is
/// completed or the server's continue lesson ([resumeLessonId], `continue.
/// lesson_id`). Every entry point — a Junior Home node, Course Detail's
/// "Continue learning", a Lesson List row — passes what the server said of
/// the lesson; any other lesson is never pushed, whatever the control that
/// asked looked like, and the call answers false. A completed lesson that
/// is locked stays shut too.
///
/// This is client-side navigation prevention only. What actually keeps a
/// locked lesson's content from a student is the backend's own check on
/// each content endpoint (`ensure_module_open`); the backend enforces no
/// lesson order at all. The lesson screen shows the server's refusal if one
/// ever reaches it.
///
/// Completes once the lesson screen is closed, so a caller can refresh what
/// may have changed there; true when a lesson was opened.
Future<bool> openLesson(
  BuildContext context, {
  required int lessonId,
  required bool locked,
  required bool completed,
  required int? resumeLessonId,
  CourseLearningRepository? repository,
}) async {
  if (!lessonOpens(
    locked: locked,
    completed: completed,
    isResume: lessonId == resumeLessonId,
  )) {
    return false;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CourseExerciseDetailScreen(
        lessonId: lessonId,
        repository: repository,
      ),
    ),
  );
  return true;
}
