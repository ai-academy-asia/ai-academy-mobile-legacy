import 'package:flutter/foundation.dart';

import '../domain/course_learning_path.dart';
import '../domain/course_learning_repository.dart';

/// Loads one course's learning overview.
///
/// Same `ChangeNotifier`/`_disposed`-guard shape as `CourseDetailController`,
/// minus that controller's `errorMessage`: `CourseLearningRepository` has
/// nothing to fail against — there is no HTTP call behind it yet (see
/// `CourseModule`'s doc comment) — so there is no failure state to model
/// until a real, fallible source exists.
class CourseLearningController extends ChangeNotifier {
  CourseLearningController({
    required this._repository,
    required this.courseSlug,
  });

  final CourseLearningRepository _repository;

  /// Which course this controller loads. Fixed for the controller's
  /// lifetime, same reasoning as `CourseDetailController.slug`.
  final String courseSlug;

  bool _disposed = false;
  bool _loading = false;
  CourseLearningPath? _path;

  bool get loading => _loading;
  CourseLearningPath? get path => _path;

  Future<void> load() async {
    _loading = true;
    _notify();

    _path = await _repository.getCourseLearning(courseSlug);

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
