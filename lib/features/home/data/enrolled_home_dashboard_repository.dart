import '../../../core/api/api_failure.dart';
import '../../auth/data/http_current_user_repository.dart';
import '../../auth/domain/current_user_repository.dart';
import '../../cohorts/data/http_cohort_repository.dart';
import '../../cohorts/domain/cohort.dart';
import '../../cohorts/domain/cohort_course_resolver.dart';
import '../../cohorts/domain/cohort_repository.dart';
import '../../course_learning/data/http_course_learning_repository.dart';
import '../../course_learning/domain/course_learning_repository.dart';
import '../../courses/data/http_course_repository.dart';
import '../../courses/domain/course.dart';
import '../../courses/domain/course_repository.dart';
import '../../enrollments/data/http_enrolled_cohorts_repository.dart';
import '../../enrollments/domain/enrolled_cohorts_repository.dart';
import '../../enrollments/domain/enrollment_failure.dart';
import '../domain/home_dashboard.dart';
import '../domain/home_dashboard_repository.dart';
import '../domain/home_failure.dart';
import '../domain/lesson_schedule.dart';

/// Assembles the Home dashboard out of the endpoints the app already has.
///
/// No new API is invented here and no transport is written: this composes
/// existing repositories, each with its own confirmed contract.
///
///   * `GET /me/cohorts` — which cohorts the student is enrolled in, and, per
///     [EnrolledCohortSummary], the progress percentage an entry carries when
///     it carries one — the same figure `Enrollment.progressPct` reports at
///     enrollment time, read here from whichever entry names the current
///     cohort.
///   * `GET /cohorts` — the cohort itself: its name, course, status and the
///     schedule [nextLessonFor] derives the next lesson from.
///   * `GET /auth/me` — only for `profile.ui_mode`, which drives the track
///     badge. Nothing on a cohort or its course says which mode the student
///     uses; the account does.
///   * `GET /courses` — only to resolve [EnrolledProgram.courseSlug] against
///     the live catalog via [resolveCohortCourse], since the cohort's own
///     embedded course slug can be stale (see that function's own doc
///     comment). Best-effort, same treatment as [_uiMode]: a failure here
///     falls back to the cohort's own slug rather than failing the whole
///     dashboard over a resolution nicety.
///   * `GET /me/courses/{course_slug}/learning` — through
///     [CourseLearningRepository], once the slug is resolved, for
///     [EnrolledProgram.progress]: the server's `progress.percent`, and the
///     "Modules X of Y" count taken from the server's own per-module
///     `completed` flags (contract §2.1). Best-effort, like [_uiMode]: a
///     failure falls back to the `/me/cohorts` `progress_pct` above.
///
/// ## What is deliberately missing
///
/// The reference also shows an attendance tally, a payment state and an
/// e-contract warning. None is filled here, so each section is left null
/// rather than drawn with the reference's sample numbers:
///
///   * attendance — `mobile_api_v1_1.md` lists `GET /me/attendance`, but
///     documents no response shape to map.
///   * payment — likewise `GET /me/ledger` and `GET /me/invoices`: listed,
///     no documented response shape.
///   * contract — no endpoint. `Course.hasContractTemplate` says a template
///     exists, not whether this student signed.
///
/// The module count is missing only when the learning call fails: the
/// `/me/cohorts` fallback names a percentage, not a count, so
/// [ModuleProgress.completed]/[.total] stay null then.
///
/// When one lands, it is set here and the section it feeds starts drawing;
/// nothing above this class changes.
class EnrolledHomeDashboardRepository implements HomeDashboardRepository {
  EnrolledHomeDashboardRepository({
    EnrolledCohortsRepository? enrolledCohorts,
    CohortRepository? cohorts,
    CurrentUserRepository? currentUser,
    CourseRepository? courses,
    CourseLearningRepository? courseLearning,
    DateTime Function()? clock,
  }) : _enrolledCohorts = enrolledCohorts ?? HttpEnrolledCohortsRepository(),
       _cohorts = cohorts ?? HttpCohortRepository(),
       _currentUser = currentUser ?? HttpCurrentUserRepository(),
       _courses = courses ?? HttpCourseRepository(),
       _courseLearning = courseLearning ?? HttpCourseLearningRepository(),
       _clock = clock ?? DateTime.now;

  final EnrolledCohortsRepository _enrolledCohorts;
  final CohortRepository _cohorts;
  final CurrentUserRepository _currentUser;
  final CourseRepository _courses;
  final CourseLearningRepository _courseLearning;
  final DateTime Function() _clock;

  @override
  Future<HomeDashboard> getDashboard() async {
    final List<EnrolledCohortSummary> enrolled;
    final List<Cohort> cohorts;
    try {
      // Both are needed to say anything at all, and neither depends on the
      // other, so they go out together rather than one after the next.
      final results = await Future.wait([
        _enrolledCohorts.getEnrolledCohorts(),
        _cohorts.getCohorts(),
      ]);
      enrolled = results[0] as List<EnrolledCohortSummary>;
      cohorts = results[1] as List<Cohort>;
    } on EnrollmentFailure catch (failure) {
      throw HomeFailure(
        _kindForEnrollment(failure.kind),
        detail: failure.detail,
      );
    } on ApiFailure catch (failure) {
      throw HomeFailure(_kindForApi(failure.kind), detail: failure.detail);
    }

    final progressByCohortId = {
      for (final entry in enrolled) entry.cohortId: entry.progressPct,
    };
    final cohort = _currentCohort(cohorts, progressByCohortId.keys.toSet());
    if (cohort == null) return const HomeDashboard();

    final progressPct = progressByCohortId[cohort.id];
    final courseSlug =
        resolveCohortCourse(await _courseCatalog(), cohort.course)?.slug ??
        cohort.course.slug;

    return HomeDashboard(
      program: EnrolledProgram(
        cohortId: cohort.id,
        cohortName: cohort.name,
        courseTitle:
            _preferMongolian(cohort.course.title.mn, cohort.course.title.en) ??
            cohort.name,
        courseSlug: courseSlug,
        status: cohort.status,
        uiMode: await _uiMode(),
        // The learning path's own figures when that call answers; otherwise
        // the `/me/cohorts` percentage alone, and null exactly when that
        // entry carried no `progress_pct` either. See the class doc.
        progress:
            await _learningProgress(courseSlug) ??
            (progressPct == null
                ? null
                : ModuleProgress(
                    percent: progressPct.round().clamp(0, 100).toInt(),
                  )),
        nextLesson: nextLessonFor(cohort: cohort, now: _clock()),
      ),
    );
  }

  /// The cohort the dashboard is about.
  ///
  /// A student can be enrolled in several; the reference shows one. An
  /// in-progress cohort is the one they are studying in now, so that wins —
  /// otherwise the first enrolled cohort the API listed, which keeps the
  /// choice stable rather than arbitrary.
  Cohort? _currentCohort(List<Cohort> cohorts, Set<int> enrolledIds) {
    final enrolled = [
      for (final cohort in cohorts)
        if (enrolledIds.contains(cohort.id)) cohort,
    ];
    if (enrolled.isEmpty) return null;

    for (final cohort in enrolled) {
      if (cohort.status.toLowerCase() == 'active') return cohort;
    }
    return enrolled.first;
  }

  /// The account's `ui_mode`, for the track badge.
  ///
  /// Its own request, and its own failure handling: the badge is decoration,
  /// so an account fetch that fails — whatever the reason — leaves the badge
  /// off rather than taking the whole dashboard down with it when the cohort
  /// itself loaded fine. An empty `ui_mode` reads the same as none.
  Future<String?> _uiMode() async {
    try {
      final uiMode = (await _currentUser.getCurrentUser()).profile.uiMode;
      return uiMode.isEmpty ? null : uiMode;
    } catch (_) {
      return null;
    }
  }

  /// The course's progress as `GET /me/courses/{slug}/learning` reports it,
  /// or null when that call fails for any reason.
  ///
  /// Nothing here is computed from lessons: `percent` is the server's
  /// `progress.percent`, and the module count only tallies the server's own
  /// per-module `completed` flags. A path with no modules gives no count, so
  /// the card draws the percentage alone rather than "0 of 0".
  ///
  /// Its own failure handling, same reasoning as [_uiMode]: the cohort card
  /// still draws without it, on the `/me/cohorts` percentage.
  Future<ModuleProgress?> _learningProgress(String courseSlug) async {
    try {
      final path = await _courseLearning.getCourseLearning(courseSlug);
      final modules = path.modules;
      return ModuleProgress(
        percent: path.percentComplete,
        completed: modules.isEmpty
            ? null
            : modules.where((module) => module.completed).length,
        total: modules.isEmpty ? null : modules.length,
      );
    } catch (_) {
      return null;
    }
  }

  /// The public course catalog, for [resolveCohortCourse]. Its own request,
  /// its own failure handling — same reasoning as [_uiMode]: resolving a
  /// fresher slug is a nicety, so a failed `GET /courses` leaves
  /// [EnrolledProgram.courseSlug] on the cohort's own slug rather than
  /// taking the whole dashboard down.
  Future<List<Course>> _courseCatalog() async {
    try {
      return await _courses.getCourses();
    } catch (_) {
      return const [];
    }
  }
}

HomeFailureKind _kindForEnrollment(EnrollmentFailureKind kind) =>
    switch (kind) {
      EnrollmentFailureKind.sessionExpired => HomeFailureKind.sessionExpired,
      EnrollmentFailureKind.network => HomeFailureKind.network,
      EnrollmentFailureKind.server => HomeFailureKind.server,
      EnrollmentFailureKind.rejected => HomeFailureKind.unexpected,
      EnrollmentFailureKind.unexpected => HomeFailureKind.unexpected,
    };

HomeFailureKind _kindForApi(ApiFailureKind kind) => switch (kind) {
  ApiFailureKind.network => HomeFailureKind.network,
  ApiFailureKind.server => HomeFailureKind.server,
  ApiFailureKind.notFound => HomeFailureKind.unexpected,
  ApiFailureKind.unexpected => HomeFailureKind.unexpected,
};

/// Mongolian first — every other string in the app is — falling back to
/// English, and to null only when the API sent neither. Matches the same
/// helper in `cohort_card.dart` and `course_card.dart`.
String? _preferMongolian(String? mn, String? en) {
  if (mn != null && mn.isNotEmpty) return mn;
  if (en != null && en.isNotEmpty) return en;
  return null;
}
