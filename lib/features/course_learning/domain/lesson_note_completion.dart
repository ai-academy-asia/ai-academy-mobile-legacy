import 'course_exercise.dart';
import 'course_learning_failure.dart';
import 'course_learning_repository.dart';

/// Whether [note] completes its lesson — **the one completion rule**
/// (Issue #415, product-approved): the student has a saved, non-empty note
/// on that lesson. Only a note read back from the backend counts — never a
/// text field's unsaved content, never a local flag — and opening a lesson
/// never completes it. The lesson's own `completed` (server progress) and
/// the course percentage are left as the server sends them.
bool noteCompletesLesson(CourseExerciseNote? note) =>
    note != null && note.message.trim().isNotEmpty;

/// The ids of [lessons] a saved note completes, read from the backend for
/// every lesson it leaves unlocked, all at once (Issue #415).
///
/// A locked lesson is not asked for — its content, note included, answers
/// `409 lesson_locked` — and so is never completed here; one that answers
/// `locked` anyway (its class moved later meanwhile) is treated the same.
///
/// One lesson's failed read is that lesson's alone (Issue #535, MOB-08):
/// a lesson whose note cannot be read is not completed — completion is
/// never shown unconfirmed — while every other lesson keeps what its own
/// note says, and the caller loads. Only `sessionExpired` is rethrown: a
/// refused session is the student's, not the lesson's, and the repository
/// has already forgotten it, so the caller fails as a whole as before.
Future<Set<int>> lessonsCompletedByNote(
  CourseLearningRepository repository,
  Iterable<({int id, bool locked})> lessons,
) async {
  final readable = [
    for (final lesson in lessons)
      if (!lesson.locked) lesson.id,
  ];
  final completes = await Future.wait([
    for (final id in readable) _completes(repository, id),
  ]);
  return {
    for (final (i, id) in readable.indexed)
      if (completes[i]) id,
  };
}

Future<bool> _completes(CourseLearningRepository repository, int id) async {
  try {
    return noteCompletesLesson(await repository.getLessonNote(id));
  } on CourseLearningFailure catch (failure) {
    if (failure.kind == CourseLearningFailureKind.sessionExpired) rethrow;
    return false;
  }
}
