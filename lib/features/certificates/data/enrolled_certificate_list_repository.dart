import '../../../core/api/api_failure.dart';
import '../../cohorts/data/http_cohort_repository.dart';
import '../../cohorts/domain/cohort.dart';
import '../../cohorts/domain/cohort_course_resolver.dart';
import '../../cohorts/domain/cohort_repository.dart';
import '../../course_learning/data/http_course_learning_repository.dart';
import '../../course_learning/domain/course_certificate.dart';
import '../../course_learning/domain/course_learning_failure.dart';
import '../../course_learning/domain/course_learning_repository.dart';
import '../../courses/data/http_course_repository.dart';
import '../../courses/domain/course.dart';
import '../../courses/domain/course_repository.dart';
import '../../enrollments/data/http_enrolled_cohorts_repository.dart';
import '../../enrollments/domain/enrolled_cohorts_repository.dart';
import '../../enrollments/domain/enrollment_failure.dart';
import '../domain/certificate_entry.dart';
import '../domain/certificate_list_repository.dart';

/// Builds the Certificate screen's cards out of the endpoints the app already
/// has (Issue #155) — no new API, and the same sources Home's
/// `EnrolledHomeDashboardRepository` composes:
///
///   * `GET /me/cohorts` — which cohorts the student is enrolled in, and the
///     `progress_pct` an entry carries when it carries one;
///   * `GET /cohorts` — each cohort's name and course. A certificate is
///     usually earned once a cohort has ended, so this relies on the public
///     catalog still listing ended cohorts: verified live on 2026-10-08
///     (8 cohorts listed, 3 past their `end_date`, statuses `closed`/`open`).
///     Whether an *archived* cohort drops out is `UNKNOWN` — no such status
///     was seen;
///   * `GET /courses` — to resolve the course's live slug
///     ([resolveCohortCourse]); best-effort, falling back to the cohort's own
///     embedded slug, as Home does;
///   * per course, §2.9 `GET /me/courses/{course_slug}/certificate` — the
///     certificate status, and the issued certificate when there is one;
///   * per course not yet issued, §2.1 `GET /me/courses/{course_slug}/learning`
///     — the server's `progress.percent`; best-effort, falling back to
///     `progress_pct`, then to no figure.
///
/// One card per enrolled cohort, in `/cohorts` order. **Eligibility is never
/// computed here**: the card's state is the server's `status`.
///
/// **A course that answers 403 or 404 is left out**, and the other cards
/// still draw (PR #245 review): `not_enrolled` — an enrolment that no longer
/// holds — or `course_not_found` — a stale or removed course — says this
/// course has no certificate for this student, and there is no designed
/// "unavailable" card to show instead. Any other certificate failure — the
/// session, the network, the server, anything unexpected — still fails the
/// whole list: a card drawn without its status could hide an issued
/// certificate behind a "Continue learning", so the screen offers a retry
/// instead. Every failure is reported as a [CourseLearningFailure], whose
/// copy the screen already has.
class EnrolledCertificateListRepository implements CertificateListRepository {
  EnrolledCertificateListRepository({
    EnrolledCohortsRepository? enrolledCohorts,
    CohortRepository? cohorts,
    CourseRepository? courses,
    CourseLearningRepository? courseLearning,
  }) : _enrolledCohorts = enrolledCohorts ?? HttpEnrolledCohortsRepository(),
       _cohorts = cohorts ?? HttpCohortRepository(),
       _courses = courses ?? HttpCourseRepository(),
       _courseLearning = courseLearning ?? HttpCourseLearningRepository();

  final EnrolledCohortsRepository _enrolledCohorts;
  final CohortRepository _cohorts;
  final CourseRepository _courses;
  final CourseLearningRepository _courseLearning;

  @override
  Future<List<CertificateEntry>> getCertificates() async {
    final List<EnrolledCohortSummary> enrolled;
    final List<Cohort> cohorts;
    try {
      final results = await Future.wait([
        _enrolledCohorts.getEnrolledCohorts(),
        _cohorts.getCohorts(),
      ]);
      enrolled = results[0] as List<EnrolledCohortSummary>;
      cohorts = results[1] as List<Cohort>;
    } on EnrollmentFailure catch (failure) {
      throw CourseLearningFailure(
        _kindForEnrollment(failure.kind),
        detail: failure.detail,
      );
    } on ApiFailure catch (failure) {
      throw CourseLearningFailure(
        _kindForApi(failure.kind),
        detail: failure.detail,
      );
    }

    final progressByCohortId = {
      for (final entry in enrolled) entry.cohortId: entry.progressPct,
    };
    final mine = [
      for (final cohort in cohorts)
        if (progressByCohortId.containsKey(cohort.id)) cohort,
    ];
    if (mine.isEmpty) return const [];

    final catalog = await _courseCatalog();
    final entries = await Future.wait([
      for (final cohort in mine)
        _entryFor(cohort, catalog, progressByCohortId[cohort.id]),
    ]);
    return [for (final entry in entries) ?entry];
  }

  /// The card for [cohort], or null when its course answers 403/404 — see
  /// the class doc.
  Future<CertificateEntry?> _entryFor(
    Cohort cohort,
    List<Course> catalog,
    double? progressPct,
  ) async {
    final courseSlug =
        resolveCohortCourse(catalog, cohort.course)?.slug ?? cohort.course.slug;
    final CourseCertificate certificate;
    try {
      certificate = await _courseLearning.getCourseCertificate(courseSlug);
    } on CourseLearningFailure catch (failure) {
      if (_courseUnavailable.contains(failure.kind)) return null;
      // Anything else fails the list — see the class doc.
      rethrow;
    }
    final progressPercent = certificate.isIssued
        ? null
        : await _learningPercent(courseSlug) ??
              progressPct?.round().clamp(0, 100).toInt();

    return CertificateEntry(
      cohortId: cohort.id,
      cohortName: cohort.name,
      courseTitle: cohort.course.title.preferred ?? cohort.name,
      courseSlug: courseSlug,
      certificate: certificate,
      progressPercent: progressPercent,
    );
  }

  Future<int?> _learningPercent(String courseSlug) async {
    try {
      return (await _courseLearning.getCourseLearning(
        courseSlug,
      )).percentComplete;
    } catch (_) {
      return null;
    }
  }

  /// The public course catalog, for [resolveCohortCourse]. Best-effort: an
  /// empty catalog falls back to each cohort's own slug.
  Future<List<Course>> _courseCatalog() async {
    try {
      return await _courses.getCourses();
    } catch (_) {
      return const [];
    }
  }
}

/// The certificate answers that leave one course out rather than failing the
/// list: §2's `403 not_enrolled` and `404 course_not_found`.
const Set<CourseLearningFailureKind> _courseUnavailable = {
  CourseLearningFailureKind.notEnrolled,
  CourseLearningFailureKind.notFound,
};

CourseLearningFailureKind _kindForEnrollment(EnrollmentFailureKind kind) =>
    switch (kind) {
      EnrollmentFailureKind.sessionExpired =>
        CourseLearningFailureKind.sessionExpired,
      EnrollmentFailureKind.network => CourseLearningFailureKind.network,
      EnrollmentFailureKind.server => CourseLearningFailureKind.server,
      EnrollmentFailureKind.rejected => CourseLearningFailureKind.unexpected,
      EnrollmentFailureKind.unexpected => CourseLearningFailureKind.unexpected,
    };

CourseLearningFailureKind _kindForApi(ApiFailureKind kind) => switch (kind) {
  ApiFailureKind.network => CourseLearningFailureKind.network,
  ApiFailureKind.server => CourseLearningFailureKind.server,
  ApiFailureKind.notFound => CourseLearningFailureKind.unexpected,
  ApiFailureKind.unexpected => CourseLearningFailureKind.unexpected,
};
