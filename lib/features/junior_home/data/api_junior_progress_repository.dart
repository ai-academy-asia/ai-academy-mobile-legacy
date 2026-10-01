import '../../home/data/enrolled_home_dashboard_repository.dart';
import '../../home/domain/home_dashboard.dart';
import '../../home/domain/home_dashboard_repository.dart';
import '../domain/junior_progress.dart';
import '../domain/junior_progress_repository.dart';

/// Junior "Сурлагын явц" over the real API.
///
/// **A mapper, not a client.** Every figure comes from
/// [HomeDashboardRepository] — the adult dashboard's own composition of
/// `GET /me/cohorts`, `/cohorts`, `/courses`, `/me/courses/{slug}/learning`,
/// `/me/ledger` and `/me/attendance` — so the student, cohort and course are
/// chosen exactly as adult Home and Junior Home choose them, and payment,
/// attendance and the next lesson follow the rules that repository already
/// documents. No request, parse or rule is added here:
///
///  * payment — the dashboard's `PaymentStat`: due in N days, overdue, or
///    absent when nothing is owed, no due date is set, or the ledger failed;
///  * attendance — the dashboard's `AttendanceStat`, the server's `summary`;
///  * next lesson — `EnrolledProgram.nextLesson`;
///  * calendar — opens on today's month with today selected; its marks, for
///    that month and any the student pages to, come from a
///    [JuniorCalendarSource]: the cohort's scheduled days
///    (`EnrolledProgram.schedule`) as lesson days, and the days of attended
///    sessions (`AttendanceSummary.attendedDates`) as attended. No day is
///    marked missed: no missed/absent status has been confirmed.
///
/// What the API does not report stays out (see `JuniorProgress`): the
/// contract banner, the exam result, and any missed day.
class ApiJuniorProgressRepository implements JuniorProgressRepository {
  ApiJuniorProgressRepository({
    HomeDashboardRepository? dashboard,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _dashboard = dashboard ?? EnrolledHomeDashboardRepository(clock: clock);

  final HomeDashboardRepository _dashboard;
  final DateTime Function() _clock;

  @override
  Future<JuniorProgress?> getProgress() async {
    final dashboard = await _dashboard.getDashboard();
    final program = dashboard.program;
    if (program == null) return null;

    final now = _clock();
    final month = DateTime(now.year, now.month);
    final attendance = dashboard.stats
        .whereType<AttendanceStat>()
        .firstOrNull
        ?.attendance;
    final calendar = JuniorCalendarSource(
      schedule: program.schedule,
      attendedDates: attendance?.attendedDates ?? const {},
    );

    return JuniorProgress(
      month: month,
      selectedDay: now.day,
      days: calendar.marksIn(month),
      calendar: calendar,
      contract: dashboard.contract,
      payment: dashboard.stats.whereType<PaymentStat>().firstOrNull?.payment,
      attendance: attendance,
      // BACKEND GAP: no exam/grade endpoint — see `JuniorProgress`.
      examPercent: null,
      nextLesson: program.nextLesson,
    );
  }
}
