import 'package:flutter/foundation.dart';

import '../domain/course_learning_failure.dart';
import '../domain/course_learning_path.dart';
import '../domain/course_learning_repository.dart';
import 'course_learning_strings.dart';

/// Loads one course's learning overview.
///
/// Same `ChangeNotifier`/`_disposed`-guard shape as `CourseDetailController`,
/// [errorMessage] included: `GET /me/courses/{course_slug}/learning` is a real
/// fallible source, so a failure has to reach the screen as copy rather than
/// as an exception thrown through `build`. (This controller had no error state
/// while the only repository behind it was the sample one —
/// `docs/ai/ARCHITECTURE.md` §2 records that adding a real repository here
/// means adding the error state too.)
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
  String? _errorMessage;

  bool get loading => _loading;
  CourseLearningPath? get path => _path;

  /// User-facing copy for the last failure, or null. Cleared at the start of
  /// every [load] so a retry does not show the previous attempt's message
  /// while the new one is in flight.
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _path = await _repository.getCourseLearning(courseSlug);
    } on CourseLearningFailure catch (failure) {
      // The path is dropped, not kept: a failed reload leaves the screen on
      // its error view rather than on data that may no longer be true, which
      // is what `CourseDetailController` does with a failed course.
      _path = null;
      _errorMessage = CourseLearningStrings.messageFor(failure.kind);
    } catch (_) {
      _path = null;
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
