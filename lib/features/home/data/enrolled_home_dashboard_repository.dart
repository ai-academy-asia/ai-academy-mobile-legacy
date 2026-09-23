import '../../../core/api/api_failure.dart';
import '../../auth/data/http_current_user_repository.dart';
import '../../auth/domain/current_user_repository.dart';
import '../../cohorts/data/http_cohort_repository.dart';
import '../../cohorts/domain/cohort.dart';
import '../../cohorts/domain/cohort_repository.dart';
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
/// three existing repositories, each with its own confirmed contract.
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
///
/// ## What is deliberately missing
///
/// The reference also shows a module count ("2 of 5"), an attendance tally, a
/// payment state and an e-contract warning. **No endpoint in this API reports
/// any of them**, so every one of those sections is left null rather than
/// filled with the reference's sample numbers. Each is waiting on exactly one
/// thing:
///
///   * the module count — a lessons/modules endpoint. `progress_pct` names a
///     percentage, not a count, so [ModuleProgress.completed]/[.total] stay
///     null even once [ModuleProgress.percent] has a real value — see that
///     class's own doc comment.
///   * attendance — an attendance endpoint. `Course.hasAttendance` and
///     `attendanceMethod` hint one is planned; neither is a tally.
///   * payment — an invoice/payment endpoint. Only catalog *prices* exist.
///   * contract — a contract endpoint. `Course.hasContractTemplate` says a
///     template exists, not whether this student signed.
///
/// When one lands, it is set here and the section it feeds starts drawing;
/// nothing above this class changes.
class EnrolledHomeDashboardRepository implements HomeDashboardRepository {
  EnrolledHomeDashboardRepository({
    EnrolledCohortsRepository? enrolledCohorts,
    CohortRepository? cohorts,
    CurrentUserRepository? currentUser,
    DateTime Function()? clock,
  }) : _enrolledCohorts = enrolledCohorts ?? HttpEnrolledCohortsRepository(),
       _cohorts = cohorts ?? HttpCohortRepository(),
       _currentUser = currentUser ?? HttpCurrentUserRepository(),
       _clock = clock ?? DateTime.now;

  final EnrolledCohortsRepository _enrolledCohorts;
  final CohortRepository _cohorts;
  final CurrentUserRepository _currentUser;
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

    return HomeDashboard(
      program: EnrolledProgram(
        cohortId: cohort.id,
        cohortName: cohort.name,
        courseTitle:
            _preferMongolian(cohort.course.title.mn, cohort.course.title.en) ??
            cohort.name,
        status: cohort.status,
        uiMode: await _uiMode(),
        // Null exactly when the entry named this cohort with no
        // `progress_pct` — the module count still has no source, so
        // `ModuleProgress.completed`/`.total` stay unset either way; see the
        // class doc.
        progress: progressPct == null
            ? null
            : ModuleProgress(
                percent: progressPct.round().clamp(0, 100).toInt(),
              ),
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
