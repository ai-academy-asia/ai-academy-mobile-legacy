import '../../../core/api/api_failure.dart';
import '../../attendance/data/http_attendance_repository.dart';
import '../../attendance/domain/attendance_repository.dart';
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
import '../../payments/data/http_ledger_repository.dart';
import '../../payments/domain/ledger_repository.dart';
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
///   * `GET /me/ledger` — through [LedgerRepository], for the payment card.
///     See [_paymentStat] for exactly when it draws and what it says.
///   * `GET /me/attendance?course={slug}` — through [AttendanceRepository],
///     for the attendance card: `summary.attended` of `summary.total_past`,
///     at the server's `summary.percent`.
///
/// The last three are best-effort, like [_uiMode]: each is decoration on a
/// dashboard that is still worth showing without it, so a failure leaves its
/// own section off rather than failing the whole screen. They are
/// independent, so they go out together.
///
/// With both statistic cards present they are drawn as the reference's
/// side-by-side tiles; a card on its own is drawn as a full-width row,
/// never as a lone half-width tile.
///
/// ## What is deliberately missing
///
/// The e-contract warning. **No endpoint reports whether this student signed
/// a contract** — `Course.hasContractTemplate` and the course-level
/// `/courses/{id}/templates/contract` say a template exists, nothing more —
/// so [HomeDashboard.contract] stays null and the banner does not draw. It is
/// set here the day a source exists; nothing above this class changes.
///
/// The module count is missing only when the learning call fails: the
/// `/me/cohorts` fallback names a percentage, not a count, so
/// [ModuleProgress.completed]/[.total] stay null then.
class EnrolledHomeDashboardRepository implements HomeDashboardRepository {
  EnrolledHomeDashboardRepository({
    EnrolledCohortsRepository? enrolledCohorts,
    CohortRepository? cohorts,
    CurrentUserRepository? currentUser,
    CourseRepository? courses,
    CourseLearningRepository? courseLearning,
    LedgerRepository? ledger,
    AttendanceRepository? attendance,
    DateTime Function()? clock,
  }) : _enrolledCohorts = enrolledCohorts ?? HttpEnrolledCohortsRepository(),
       _cohorts = cohorts ?? HttpCohortRepository(),
       _currentUser = currentUser ?? HttpCurrentUserRepository(),
       _courses = courses ?? HttpCourseRepository(),
       _courseLearning = courseLearning ?? HttpCourseLearningRepository(),
       _ledger = ledger ?? HttpLedgerRepository(),
       _attendance = attendance ?? HttpAttendanceRepository(),
       _clock = clock ?? DateTime.now;

  final EnrolledCohortsRepository _enrolledCohorts;
  final CohortRepository _cohorts;
  final CurrentUserRepository _currentUser;
  final CourseRepository _courses;
  final CourseLearningRepository _courseLearning;
  final LedgerRepository _ledger;
  final AttendanceRepository _attendance;
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

    // Independent of one another, and each handles its own failure.
    final uiMode = _uiMode();
    final learningProgress = _learningProgress(courseSlug);
    final payment = _paymentStat(cohort.id);
    final attendance = _attendanceSummary(courseSlug);

    return HomeDashboard(
      program: EnrolledProgram(
        cohortId: cohort.id,
        cohortName: cohort.name,
        courseTitle:
            _preferMongolian(cohort.course.title.mn, cohort.course.title.en) ??
            cohort.name,
        courseSlug: courseSlug,
        status: cohort.status,
        uiMode: await uiMode,
        // The learning path's own figures when that call answers; otherwise
        // the `/me/cohorts` percentage alone, and null exactly when that
        // entry carried no `progress_pct` either. See the class doc.
        progress:
            await learningProgress ??
            (progressPct == null
                ? null
                : ModuleProgress(
                    percent: progressPct.round().clamp(0, 100).toInt(),
                  )),
        nextLesson: nextLessonFor(cohort: cohort, now: _clock()),
        schedule: LessonSchedule.of(cohort),
      ),
      stats: _stats(await payment, await attendance),
    );
  }

  /// Payment first, then attendance — the reference's order. Two cards sit
  /// side by side as tiles; one alone takes the full width as a row.
  static List<HomeStat> _stats(
    PaymentStatus? payment,
    AttendanceSummary? attendance,
  ) {
    final layout = payment != null && attendance != null
        ? HomeStatLayout.tile
        : HomeStatLayout.row;
    return [
      if (payment != null) PaymentStat(payment, layout: layout),
      if (attendance != null) AttendanceStat(attendance, layout: layout),
    ];
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

  /// What the student owes next on [cohortId]'s enrollment, from
  /// `GET /me/ledger` — or null, which leaves the payment card off.
  ///
  /// The card has two states, and the verified ledger fields support both
  /// without computing any money:
  ///
  ///   * **overdue** — `balance` is above zero and `next_due_date` has
  ///     passed.
  ///   * **due in N days** — `balance` is above zero and `next_due_date` is
  ///     today or later; N is the calendar days until it.
  ///
  /// Null when there is no entry for this cohort, when `balance` is zero
  /// (nothing is owed — the card has no "paid" state to show), when
  /// `next_due_date` is null (no day to count to), or when the call fails.
  Future<PaymentStatus?> _paymentStat(int cohortId) async {
    try {
      final entries = await _ledger.getLedger();
      final entry = entries.where((e) => e.cohortId == cohortId).firstOrNull;
      final due = entry?.nextDueDate;
      if (entry == null || entry.balance <= 0 || due == null) return null;

      final now = _clock();
      // Whole calendar days, measured in UTC so a daylight-saving change
      // cannot make a day 23 or 25 hours long.
      final days = DateTime.utc(
        due.year,
        due.month,
        due.day,
      ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
      return days < 0
          ? const PaymentStatus.overdue()
          : PaymentStatus.dueIn(days);
    } catch (_) {
      return null;
    }
  }

  /// The student's attendance in [courseSlug], from
  /// `GET /me/attendance?course=` — or null when that call fails, which
  /// leaves the attendance card off. Every figure is the server's `summary`;
  /// none is worked out here.
  Future<AttendanceSummary?> _attendanceSummary(String courseSlug) async {
    try {
      final attendance = await _attendance.getCourseAttendance(courseSlug);
      return AttendanceSummary(
        attended: attendance.attended,
        total: attendance.totalPast,
        percent: attendance.percent,
        attendedDates: {
          for (final session in attendance.sessions)
            if (session.countsAsAttended) session.date,
        },
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
