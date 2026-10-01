import 'package:flutter/foundation.dart';

import '../domain/course_learning_failure.dart';
import '../domain/course_learning_repository.dart';
import '../domain/lesson.dart';
import 'course_learning_strings.dart';

/// Loads one module's lessons.
///
/// Same `ChangeNotifier`/`_disposed`-guard shape as `CourseLearningController`,
/// [errorMessage] included: `GET /me/modules/{module_id}/lessons` is a real
/// fallible source, so a failure reaches the screen as copy rather than as an
/// exception thrown through `build`.
class LessonListController extends ChangeNotifier {
  LessonListController({required this._repository, required this.moduleId});

  final CourseLearningRepository _repository;

  /// Which module's lessons this controller loads. Fixed for the
  /// controller's lifetime, same reasoning as `CourseLearningController.
  /// courseSlug`.
  final int moduleId;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  List<Lesson> _lessons = const [];
  String? _errorMessage;

  bool get loading => _loading;
  List<Lesson> get lessons => _lessons;

  /// User-facing copy for the last failure, or null. Cleared at the start of
  /// every [load] so a retry does not show the previous attempt's message
  /// while the new one is in flight.
  String? get errorMessage => _errorMessage;

  /// True once a fetch has *completed* successfully and returned no lessons —
  /// the module is reachable, it just has none. The same rule
  /// `CourseCatalogController.isEmpty` keeps: false before [load] has ever
  /// been called, and never true while [loading] or while [errorMessage] is
  /// set.
  bool get isEmpty =>
      _hasLoadedOnce && !_loading && _errorMessage == null && _lessons.isEmpty;

  /// Fetches the lessons. Safe to call again — that is the retry.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _lessons = await _repository.getLessons(moduleId);
    } on CourseLearningFailure catch (failure) {
      // Dropped, not kept, for the reason `CourseLearningController` gives:
      // a failed reload shows its error rather than data that may be stale.
      _lessons = const [];
      _errorMessage = CourseLearningStrings.messageFor(failure.kind);
    } catch (_) {
      _lessons = const [];
      _errorMessage = CourseLearningStrings.unexpectedError;
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
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
