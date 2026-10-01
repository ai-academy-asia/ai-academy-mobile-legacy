import 'course_exercise.dart';
import 'course_learning_path.dart';
import 'lesson.dart';
import 'material_download.dart';
import 'uploaded_file.dart';

/// A course's learning overview — modules, progress, the lot — plus each
/// module's own lessons and each lesson's content.
///
/// `HttpCourseLearningRepository` serves all three from
/// `course_learning_api_contract_v1.md` §2.1–2.3, saves a lesson's note
/// through §2.5, fetches a material's download link through §2.4, submits
/// an assignment through §2.6 and uploads a student file through §2.8,
/// throwing `CourseLearningFailure`;
/// `SampleCourseLearningRepository` serves hand-authored content for tests
/// and the dev preview.
///
/// Three content reads on one interface, same shape as `CourseRepository`'s
/// `getCourses()`/`getCourseDetail(slug)` split: one for the overview list,
/// one for a module's own lessons, one for a lesson's exercise detail — plus
/// the Exercise Detail screen's actions: the note save, a material's download
/// link and an assignment submission — and the file upload a submission will
/// attach.
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

  /// A fresh download link for one lesson material — §2.4
  /// `GET /me/materials/{material_id}/download`. [materialId] is
  /// `CourseExerciseMaterial.id`.
  Future<MaterialDownload> getMaterialDownload(int materialId);

  /// Submits — or resubmits, the same call — a [link], an uploaded file, or
  /// both to assignment [assignmentId] and returns the new latest submission
  /// — §2.6 `POST /me/assignments/{assignment_id}/submissions`.
  /// [assignmentId] is `CourseAssignment.id`; [fileId] is the
  /// `UploadedFile.id` an earlier [uploadFile] answered with. §2.6 wants a
  /// link or a file; sending neither is the server's `submission_empty`.
  Future<AssignmentSubmission> submitAssignment(
    int assignmentId, {
    String? link,
    String? description,
    int? fileId,
  });

  /// Uploads [bytes] as a student file named [fileName] and returns it as
  /// stored — §2.8 `POST /me/files`. The returned `UploadedFile.id` is what a
  /// submission later sends as `file_id`. The backend alone decides which
  /// types and sizes it accepts.
  Future<UploadedFile> uploadFile({
    required String fileName,
    required List<int> bytes,
  });
}
