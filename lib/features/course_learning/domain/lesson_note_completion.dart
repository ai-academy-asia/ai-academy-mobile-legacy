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
/// Any other failure is rethrown, so a caller fails as a whole rather than
/// showing a lesson completed — or not — on a guess.
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
    if (failure.kind == CourseLearningFailureKind.locked) return false;
    rethrow;
  }
}
