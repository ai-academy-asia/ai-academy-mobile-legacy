import 'course_exercise.dart';
import 'course_learning_path.dart';

/// A course's learning overview — modules, progress, the lot — plus each
/// module's own exercise/lesson content.
///
/// Deliberately not modelled after `CourseRepository`'s `ApiFailure`
/// contract: there is no backend endpoint behind this yet (see
/// `CourseModule`'s doc comment), so there is nothing that can fail the way a
/// real HTTP call can. The only implementation today is
/// `SampleCourseLearningRepository`; a screen depends on this interface
/// anyway so that swapping in a real one later needs no screen changes.
///
/// Two methods on one interface, same shape as `CourseRepository`'s
/// `getCourses()`/`getCourseDetail(slug)` split: one for the overview list,
/// one for a single item's own detail.
abstract interface class CourseLearningRepository {
  /// [courseSlug] is `Course.slug` — the one identifier this feature borrows
  /// from the confirmed course contract rather than inventing its own.
  Future<CourseLearningPath> getCourseLearning(String courseSlug);

  /// One module's exercise/lesson detail — the Exercise Detail screen's data.
  /// [moduleId] is `CourseModule.id`.
  Future<CourseExercise> getExercise(int moduleId);
}
