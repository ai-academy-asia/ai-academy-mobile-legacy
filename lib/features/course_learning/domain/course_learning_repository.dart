import 'course_exercise.dart';
import 'course_learning_path.dart';
import 'lesson.dart';

/// A course's learning overview — modules, progress, the lot — plus each
/// module's own lessons and each lesson's content.
///
/// `HttpCourseLearningRepository` serves all three from
/// `course_learning_api_contract_v1.md` §2.1–2.3, and saves a lesson's note
/// through §2.5, throwing `CourseLearningFailure`;
/// `SampleCourseLearningRepository` serves hand-authored content for tests
/// and the dev preview.
///
/// Three reads on one interface, same shape as `CourseRepository`'s
/// `getCourses()`/`getCourseDetail(slug)` split: one for the overview list,
/// one for a module's own lessons, one for a lesson's exercise detail — plus
/// the one write the Exercise Detail screen makes, the note save.
abstract interface class CourseLearningRepository {
  /// [courseSlug] is `Course.slug` — the one identifier this feature borrows
  /// from the confirmed course contract rather than inventing its own.
  Future<CourseLearningPath> getCourseLearning(String courseSlug);

  /// One module's lessons — the Lesson List screen's data.
  /// [moduleId] is `CourseModule.id`.
  Future<List<Lesson>> getLessons(int moduleId);

  /// One lesson's content — the Exercise Detail screen's data.
  /// [lessonId] is `Lesson.id`: §2.3 makes exercise content per lesson.
  Future<CourseExercise> getExercise(int lessonId);

  /// Creates or replaces the student's note on [lessonId] with [content] and
  /// returns the note as saved — §2.5 `PUT /me/lessons/{lesson_id}/note`,
  /// one call for both, so there is no separate "create".
  Future<CourseExerciseNote> saveNote(int lessonId, String content);
}
