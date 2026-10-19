import 'package:flutter/foundation.dart';

import '../../../core/api/api_failure.dart';
import '../../courses/data/http_course_repository.dart';
import '../../courses/domain/course.dart';
import '../../courses/domain/course_repository.dart';
import '../domain/cohort.dart';
import '../domain/cohort_course_resolver.dart';
import '../domain/cohort_listing.dart';
import '../domain/cohort_repository.dart';
import 'cohort_list_strings.dart';

/// Loads the public cohort list.
///
/// Same shape as `CourseCatalogController`: a plain [ChangeNotifier], a
/// `_disposed` guard, one fixed string per [ApiFailureKind], and
/// [isEmpty] that is false until the first fetch has actually completed —
/// an untouched controller has not established emptiness yet.
///
/// When [courseId] is given, [cohorts] (and therefore [isEmpty]) only ever
/// holds cohorts whose `courseId` matches it. The filter is applied client
/// side, after `GET /cohorts` returns — there is no confirmed per-course
/// query parameter on that endpoint, so the request itself is unchanged.
class CohortListController extends ChangeNotifier {
  CohortListController({
    required this._repository,
    this.courseId,
    CourseRepository? courseRepository,
  }) : _courseRepository = courseRepository ?? HttpCourseRepository();

  final CohortRepository _repository;

  /// `GET /courses`, fetched alongside the cohort list purely to resolve
  /// [courseSlugFor] — see that method's own doc comment.
  final CourseRepository _courseRepository;

  /// Restricts [cohorts] to this course. Null shows every cohort, the
  /// screen's original behaviour.
  final int? courseId;

  bool _disposed = false;
  bool _loading = false;
  bool _hasLoadedOnce = false;
  List<Cohort> _cohorts = const [];
  CohortListing _listing = const CohortListing();
  List<Course> _courses = const [];
  String? _errorMessage;

  bool get loading => _loading;
  List<Cohort> get cohorts => _cohorts;

  /// Whether a cohort with any of [ids] may be among the rows the last
  /// fetch skipped as malformed (Issue #445) — see
  /// [CohortListing.mayHideAny]. The student's own list asks it with the
  /// `GET /me/cohorts` ids and fails closed when it is true, rather than
  /// reading a missing cohort as "not enrolled".
  bool mayHideAny(Iterable<int> ids) => _listing.mayHideAny(ids);

  /// Set only when the most recent fetch failed. Cleared as soon as another
  /// fetch starts.
  String? get errorMessage => _errorMessage;

  /// True once a fetch has *completed* successfully and returned nothing.
  /// Never true while [loading] or while [errorMessage] is set.
  bool get isEmpty =>
      _hasLoadedOnce && !_loading && _errorMessage == null && _cohorts.isEmpty;

  /// Fetches the list. Safe to call again — retry or pull-to-refresh — while
  /// a previous call is still in flight.
  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _notify();

    try {
      // A malformed row is left out of the list (Issue #445): the browse
      // list shows every cohort that parsed. When every row fails there is
      // nothing to show, and "no classes" would be untrue — the server
      // error, with its retry, instead.
      final listing = await _repository.getCohorts();
      if (listing.cohorts.isEmpty && listing.skipped.isNotEmpty) {
        throw const ApiFailure(ApiFailureKind.server);
      }
      _listing = listing;
      final fetched = listing.cohorts;
      _cohorts = courseId == null
          ? fetched
          : fetched.where((cohort) => cohort.courseId == courseId).toList();
      // Best-effort, same reasoning as `EnrolledHomeDashboardRepository.
      // _courseCatalog`: powers `courseSlugFor` only, so a failed
      // `GET /courses` must not turn into a cohort-list error.
      _courses = await _fetchCourses();
    } on ApiFailure catch (failure) {
      _cohorts = const [];
      _listing = const CohortListing();
      _errorMessage = _messageFor(failure.kind);
    } catch (_) {
      _cohorts = const [];
      _listing = const CohortListing();
      _errorMessage = CohortListStrings.unexpectedError;
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
      _notify();
    }
  }

  Future<List<Course>> _fetchCourses() async {
    try {
      return await _courseRepository.getCourses();
    } catch (_) {
      return const [];
    }
  }

  /// The real course-catalog slug for [cohort]'s course, resolved against
  /// the already-fetched catalog via `resolveCohortCourse` — see that
  /// function's own doc comment for why `cohort.course.slug` can be stale.
  /// Falls back to `cohort.course.slug` when nothing resolves, reproducing
  /// today's existing 404 behaviour rather than guessing.
  String courseSlugFor(Cohort cohort) =>
      resolveCohortCourse(_courses, cohort.course)?.slug ?? cohort.course.slug;

  static String _messageFor(ApiFailureKind kind) => switch (kind) {
    ApiFailureKind.network => CohortListStrings.networkError,
    ApiFailureKind.server => CohortListStrings.serverError,
    ApiFailureKind.notFound => CohortListStrings.unexpectedError,
    ApiFailureKind.unexpected => CohortListStrings.unexpectedError,
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
