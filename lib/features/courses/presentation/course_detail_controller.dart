import 'package:flutter/foundation.dart';

import '../../../core/api/api_failure.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';
import 'course_detail_strings.dart';

/// Loads one course's full detail.
///
/// Same shape as `CourseCatalogController`: a plain [ChangeNotifier], a
/// `_disposed` guard, one fixed string per [ApiFailureKind]. The one real
/// difference is that [ApiFailureKind.notFound] is meaningful here — this
/// screen is reached with a specific slug, so "that course does not exist" is
/// worded differently from a generic failure, where the catalog's own
/// controller has no such story to tell.
class CourseDetailController extends ChangeNotifier {
  CourseDetailController({required this._repository, required this.slug});

  final CourseRepository _repository;

  /// Which course this controller loads. Fixed for the controller's lifetime
  /// — a different course is a different screen instance, not a re-target of
  /// this one.
  final String slug;

  bool _disposed = false;
  bool _loading = false;
  Course? _course;
  String? _errorMessage;

  bool get loading => _loading;
  Course? get course => _course;

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts.
  String? get errorMessage => _errorMessage;

  /// Fetches [slug]'s detail. Safe to call again from a retry button while a
  /// previous call is still in flight.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _course = await _repository.getCourseDetail(slug);
    } on ApiFailure catch (failure) {
      _course = null;
      _errorMessage = _messageFor(failure.kind);
    } catch (_) {
      _course = null;
      _errorMessage = CourseDetailStrings.unexpectedError;
    } finally {
      _loading = false;
      _notify();
    }
  }

  static String _messageFor(ApiFailureKind kind) => switch (kind) {
    ApiFailureKind.notFound => CourseDetailStrings.notFound,
    ApiFailureKind.network => CourseDetailStrings.networkError,
    ApiFailureKind.server => CourseDetailStrings.serverError,
    ApiFailureKind.unexpected => CourseDetailStrings.unexpectedError,
  };

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
