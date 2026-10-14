import 'package:flutter/material.dart';

import '../domain/course_learning_repository.dart';
import 'course_exercise_detail_screen.dart';

/// The one way any screen opens a lesson's content (Issue #410).
///
/// **The rule is the server's `locked`, and only that.** The backend locks
/// a lesson — every lesson of a module alike — while the module's first
/// class date is still ahead, and answers its content with `409
/// lesson_locked`. Every entry point — a Junior Home node, Course Detail's
/// "Continue learning", a Lesson List row — passes the server's flag for the
/// lesson it would open; a locked lesson is never pushed, whatever the
/// control that asked looked like, and the call answers false. A completed
/// lesson that is locked stays shut too.
///
/// This is client-side navigation prevention only. What actually keeps a
/// locked lesson's content from a student is the backend's own check on
/// each content endpoint (`ensure_module_open`); the lesson screen shows
/// the server's refusal if one ever reaches it.
///
/// Completes once the lesson screen is closed, so a caller can refresh what
/// may have changed there; true when a lesson was opened.
Future<bool> openLesson(
  BuildContext context, {
  required int lessonId,
  required bool locked,
  CourseLearningRepository? repository,
}) async {
  if (locked) return false;
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
