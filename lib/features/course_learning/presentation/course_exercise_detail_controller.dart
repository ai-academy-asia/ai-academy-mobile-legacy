import 'package:flutter/foundation.dart';

import '../domain/course_exercise.dart';
import '../domain/course_learning_repository.dart';

/// Loads one module's exercise/lesson detail.
///
/// Same `ChangeNotifier`/`_disposed`-guard shape as `CourseLearningController`
/// — see that class's own doc comment for why there is no error state to
/// model: `CourseLearningRepository` has nothing to fail against yet.
class CourseExerciseDetailController extends ChangeNotifier {
  CourseExerciseDetailController({
    required this._repository,
    required this.moduleId,
  });

  final CourseLearningRepository _repository;

  /// Which module's exercise this controller loads. Fixed for the
  /// controller's lifetime, same reasoning as `CourseLearningController.
  /// courseSlug`.
  final int moduleId;

  bool _disposed = false;
  bool _loading = false;
  CourseExercise? _exercise;

  bool get loading => _loading;
  CourseExercise? get exercise => _exercise;

  Future<void> load() async {
    _loading = true;
    _notify();

    _exercise = await _repository.getExercise(moduleId);

    _loading = false;
    _notify();
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
