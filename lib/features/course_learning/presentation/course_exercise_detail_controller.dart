import 'package:flutter/foundation.dart';

import '../domain/course_exercise.dart';
import '../domain/course_learning_failure.dart';
import '../domain/course_learning_repository.dart';
import 'course_learning_strings.dart';

/// Loads one lesson's content.
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

  bool get loading => _loading;
  CourseExercise? get exercise => _exercise;

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
