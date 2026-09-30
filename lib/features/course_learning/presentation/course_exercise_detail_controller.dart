import 'package:flutter/foundation.dart';

import '../domain/course_exercise.dart';
import '../domain/course_learning_failure.dart';
import '../domain/course_learning_repository.dart';
import 'course_learning_strings.dart';

/// Loads one lesson's content, and saves the student's note on it.
///
/// Same `ChangeNotifier`/`_disposed`-guard shape as `CourseLearningController`,
/// [errorMessage] included: `GET /me/lessons/{lesson_id}` is a real fallible
/// source, so a failure reaches the screen as copy rather than as an
/// exception thrown through `build`.
class CourseExerciseDetailController extends ChangeNotifier {
  CourseExerciseDetailController({
    required this._repository,
    required this.lessonId,
  });

  final CourseLearningRepository _repository;

  /// Which lesson this controller loads — `Lesson.id`. Fixed for the
  /// controller's lifetime, same reasoning as `CourseLearningController.
  /// courseSlug`.
  final int lessonId;

  bool _disposed = false;
  bool _loading = false;
  CourseExercise? _exercise;
  String? _errorMessage;
  bool _savingNote = false;
  String? _noteSaveErrorMessage;

  bool get loading => _loading;
  CourseExercise? get exercise => _exercise;

  /// True while a [saveNote] is in flight.
  bool get savingNote => _savingNote;

  /// User-facing copy for the last failed [saveNote], or null. Kept apart
  /// from [errorMessage]: a failed save leaves the loaded lesson on screen.
  String? get noteSaveErrorMessage => _noteSaveErrorMessage;

  /// User-facing copy for the last failure, or null. Cleared at the start of
  /// every [load] so a retry does not show the previous attempt's message
  /// while the new one is in flight.
  String? get errorMessage => _errorMessage;

  /// Fetches the lesson. Safe to call again — that is the retry.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _exercise = await _repository.getExercise(lessonId);
    } on CourseLearningFailure catch (failure) {
      // Dropped, not kept, for the reason `CourseLearningController` gives:
      // a failed reload shows its error rather than data that may be stale.
      _exercise = null;
      _errorMessage = CourseLearningStrings.messageFor(failure.kind);
    } catch (_) {
      _exercise = null;
      _errorMessage = CourseLearningStrings.unexpectedError;
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Saves [content] as the lesson's note. On success the loaded exercise
  /// holds the note the repository returned — the server's author and
  /// timestamp, not a local copy — and this answers true. On failure the
  /// exercise is untouched, [noteSaveErrorMessage] says why, and this
  /// answers false. Ignored (false) with no lesson loaded or a save already
  /// in flight.
  Future<bool> saveNote(String content) async {
    if (_exercise == null || _savingNote) return false;

    _savingNote = true;
    _noteSaveErrorMessage = null;
    _notify();

    try {
      final note = await _repository.saveNote(lessonId, content);
      // Re-read, not captured before the await: a reload may have replaced
      // the exercise meanwhile, and the saved note belongs on the current one.
      final current = _exercise;
      if (current != null) _exercise = current.withNote(note);
      return true;
    } on CourseLearningFailure catch (failure) {
      _noteSaveErrorMessage = CourseLearningStrings.messageFor(failure.kind);
      return false;
    } catch (_) {
      _noteSaveErrorMessage = CourseLearningStrings.unexpectedError;
      return false;
    } finally {
      _savingNote = false;
      _notify();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
