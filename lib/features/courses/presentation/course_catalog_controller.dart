import 'package:flutter/foundation.dart';

import '../../../core/api/api_failure.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';
import 'course_catalog_strings.dart';

/// Loads the public course catalog.
///
/// A plain [ChangeNotifier], the same shape as `LoginController` and
/// `ResetPasswordController`: no state-management package, a `_disposed`
/// guard on every notify, and a failure mapped to one fixed string per kind
/// rather than the raw exception reaching the screen.
///
/// There is no form here, so the state is simpler than either of those —
/// [loading], the [courses] most recently fetched, and [errorMessage] when the
/// fetch failed. All three are readable at once by design: a retry keeps
/// showing the previous list (if any) faded under a spinner would be nicer,
/// but this first pass keeps to what was asked — loading, loaded, empty, and
/// error are the four states, not five.
class CourseCatalogController extends ChangeNotifier {
  CourseCatalogController({required this._repository});

  final CourseRepository _repository;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  List<Course> _courses = const [];
  String? _errorMessage;

  bool get loading => _loading;
  List<Course> get courses => _courses;

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts.
  String? get errorMessage => _errorMessage;

  /// True once a fetch has *completed* successfully and returned nothing —
  /// the catalog is reachable, it is just empty. False before [load] has ever
  /// been called: an untouched controller has not established that yet, so it
  /// is not "empty", it is unknown. Never true while [loading] or while
  /// [errorMessage] is set.
  bool get isEmpty =>
      _hasLoadedOnce && !_loading && _errorMessage == null && _courses.isEmpty;

  /// Fetches the catalog. Safe to call again — from pull-to-refresh or a
  /// retry button — while a previous call is still in flight; the earlier
  /// call's result is simply superseded when it resolves.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      _courses = await _repository.getCourses();
    } on ApiFailure catch (failure) {
      _courses = const [];
      _errorMessage = _messageFor(failure.kind);
    } catch (_) {
      _courses = const [];
      _errorMessage = CourseCatalogStrings.unexpectedError;
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
      _notify();
    }
  }

  static String _messageFor(ApiFailureKind kind) => switch (kind) {
    ApiFailureKind.network => CourseCatalogStrings.networkError,
    ApiFailureKind.server => CourseCatalogStrings.serverError,
    // The list endpoint names no resource in its URL, so a 404 here has no
    // more specific story than "something went wrong" — unlike course detail,
    // which reads this kind to mean a particular slug does not exist.
    ApiFailureKind.notFound => CourseCatalogStrings.unexpectedError,
    ApiFailureKind.unexpected => CourseCatalogStrings.unexpectedError,
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
