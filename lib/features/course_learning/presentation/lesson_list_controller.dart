import 'package:flutter/foundation.dart';

import '../domain/course_learning_repository.dart';
import '../domain/lesson.dart';

/// Loads one module's lessons.
///
/// Same `ChangeNotifier`/`_disposed`-guard shape as `CourseLearningController`
/// — no error state, for the same reason: `CourseLearningRepository` has
/// nothing to fail against until a real HTTP call sits behind it.
class LessonListController extends ChangeNotifier {
  LessonListController({required this._repository, required this.moduleId});

  final CourseLearningRepository _repository;

  /// Which module's lessons this controller loads. Fixed for the
  /// controller's lifetime, same reasoning as `CourseLearningController.
  /// courseSlug`.
  final int moduleId;

  bool _disposed = false;
  bool _loading = false;
  List<Lesson> _lessons = const [];

  bool get loading => _loading;
  List<Lesson> get lessons => _lessons;

  Future<void> load() async {
    _loading = true;
    _notify();

    _lessons = await _repository.getLessons(moduleId);

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
