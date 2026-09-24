import 'course_exercise.dart';
import 'course_learning_path.dart';
import 'lesson.dart';

/// A course's learning overview — modules, progress, the lot — plus each
/// module's own lessons and exercise/lesson content.
///
/// Deliberately not modelled after `CourseRepository`'s `ApiFailure`
/// contract: there is no backend endpoint behind this yet (see
/// `CourseModule`'s doc comment), so there is nothing that can fail the way a
/// real HTTP call can. The only implementation today is
/// `SampleCourseLearningRepository`; a screen depends on this interface
/// anyway so that swapping in a real one later needs no screen changes.
///
/// Three methods on one interface, same shape as `CourseRepository`'s
/// `getCourses()`/`getCourseDetail(slug)` split: one for the overview list,
/// one for a module's own lessons, one for a lesson's exercise detail.
abstract interface class CourseLearningRepository {
  /// [courseSlug] is `Course.slug` — the one identifier this feature borrows
  /// from the confirmed course contract rather than inventing its own.
  Future<CourseLearningPath> getCourseLearning(String courseSlug);

  /// One module's lessons — the Lesson List screen's data.
  /// [moduleId] is `CourseModule.id`.
  Future<List<Lesson>> getLessons(int moduleId);

  /// One module's exercise/lesson detail — the Exercise Detail screen's data.
  /// [moduleId] is `CourseModule.id`.
  ///
  /// Still keyed by module rather than by `Lesson.id`: `CourseExercise`
  /// predates `Lesson` and models one exercise per module (see that class's
  /// own doc comment on the current Module↔Lesson cardinality gap this
  /// screen does not resolve). Every lesson in a module currently opens the
  /// same exercise detail, the same way every module in a course currently
  /// opens the same [getCourseLearning] result — re-keying this to
  /// `Lesson.id` is follow-up work once a real per-lesson exercise contract
  /// exists.
  Future<CourseExercise> getExercise(int moduleId);
}
