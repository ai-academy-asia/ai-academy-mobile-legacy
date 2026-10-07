import '../../cohorts/domain/cohort.dart';
import 'home_dashboard.dart';

/// Derives a cohort's next lesson from the schedule `GET /cohorts` already
/// returns — `meetingDays`, `startTime`/`endTime` and the `startDate`…
/// `endDate` window.
///
/// This is a rule, not data: no endpoint reports "the next lesson", but every
/// field needed to work it out is confirmed on [Cohort], so the dashboard
/// computes it rather than waiting for one. Pure and clock-injected, so both
/// the "next lesson" and the "live now" states are testable without a device
/// clock.
///
/// Returns the lesson currently under way if there is one — a lesson that has
/// started is still the next thing the student acts on, and it is what puts
/// the attendance action live. Null when the cohort has no parseable
/// schedule, or when [now] is past the cohort's end date.
NextLesson? nextLessonFor({required Cohort cohort, required DateTime now}) =>
    LessonSchedule.of(cohort)?.nextLesson(now);

/// A cohort's weekly schedule, parsed once from the fields `GET /cohorts`
/// confirms — `meetingDays`, `startTime`/`endTime` and the `startDate`…
/// `endDate` window — so every rule that reads it parses it the same way.
///
/// Both of its rules work from these fields alone, and neither reports
/// anything the schedule does not say: [nextLesson] for the dashboards'
/// "next lesson", [lessonDaysIn] for the Junior calendar's scheduled days.
/// Whether the student *attended* a given day is not in the schedule and is
/// not answered here.
class LessonSchedule {
  const LessonSchedule({
    required this.weekdays,
    required this.start,
    required this.end,
    this.firstDay,
    this.lastDay,
  });

  /// Null when the cohort has no parseable schedule: no recognised meeting
  /// day, or a start or end time that is not `H:mm`.
  static LessonSchedule? of(Cohort cohort) {
    final weekdays = _weekdays(cohort.meetingDays);
    if (weekdays.isEmpty) return null;

    final start = parseClockTime(cohort.startTime);
    final end = parseClockTime(cohort.endTime);
    if (start == null || end == null) return null;

    return LessonSchedule(
      weekdays: weekdays,
      start: start,
      end: end,
      firstDay: _date(cohort.startDate),
      lastDay: _date(cohort.endDate),
    );
  }

  /// `DateTime.monday` … `DateTime.sunday`.
  final Set<int> weekdays;

  /// Hour and minute a lesson starts and ends.
  final (int, int) start;
  final (int, int) end;

  /// The cohort's first and last day, as local midnights. Null leaves that
  /// end of the window open — the API sent something that is not a date.
  final DateTime? firstDay;
  final DateTime? lastDay;

  bool _scheduledOn(DateTime day) =>
      weekdays.contains(day.weekday) &&
      !(firstDay != null && day.isBefore(firstDay!)) &&
      !(lastDay != null && day.isAfter(lastDay!));

  /// The lesson currently under way if there is one — a lesson that has
  /// started is still the next thing the student acts on, and it is what
  /// puts the attendance action live — otherwise the next one to start.
  /// Null when [now] is past the cohort's last day.
  NextLesson? nextLesson(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    // Scanning starts at the cohort's first day when that is still ahead, so
    // a cohort beginning next month still names its opening lesson instead
    // of answering "nothing this week".
    final from = firstDay != null && firstDay!.isAfter(today)
        ? firstDay!
        : today;

    // A week is enough: any weekly schedule meets again within seven days,
    // and the eighth candidate would repeat the first.
    for (var offset = 0; offset <= 7; offset++) {
      final day = from.add(Duration(days: offset));

      if (lastDay != null && day.isAfter(lastDay!)) break;
      if (!_scheduledOn(day)) continue;

      final startsAt = DateTime(
        day.year,
        day.month,
        day.day,
        start.$1,
        start.$2,
      );
      final endsAt = DateTime(day.year, day.month, day.day, end.$1, end.$2);

      // Today's lesson is only still "next" until it has finished.
      if (now.isBefore(endsAt)) {
        return NextLesson(startsAt: startsAt, endsAt: endsAt);
      }
    }

    return null;
  }

  /// The days of [month] the cohort meets on, within its first…last day —
  /// e.g. `{4, 6, 11, 13, …}`. Only its year and month are read.
  ///
  /// The schedule's days, not attendance: a past day here was *scheduled*,
  /// which says nothing about whether the student came.
  Set<int> lessonDaysIn(DateTime month) {
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    return {
      for (var d = 1; d <= dayCount; d++)
        if (_scheduledOn(DateTime(month.year, month.month, d))) d,
    };
  }
}

/// `["mon", "wed"]` -> `{DateTime.monday, DateTime.wednesday}`.
///
/// Matches on the first three letters, so both the wire's short form and a
/// spelled-out day read the same. Anything unrecognised is dropped rather
/// than guessed at.
Set<int> _weekdays(List<String> meetingDays) {
  final weekdays = <int>{};
  for (final day in meetingDays) {
    final key = day.trim().toLowerCase();
    final weekday = _weekdayNumbers[key.length < 3 ? key : key.substring(0, 3)];
    if (weekday != null) weekdays.add(weekday);
  }
  return weekdays;
}

const Map<String, int> _weekdayNumbers = {
  'mon': DateTime.monday,
  'tue': DateTime.tuesday,
  'wed': DateTime.wednesday,
  'thu': DateTime.thursday,
  'fri': DateTime.friday,
  'sat': DateTime.saturday,
  'sun': DateTime.sunday,
};

/// `"18:00"` -> `(18, 0)`. Null for anything that is not `H:mm` (a trailing
/// `:ss` is ignored). Public so Teacher Schedule reads a session's times by
/// the same rule as a cohort's (Issue #231).
(int, int)? parseClockTime(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return null;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  return (hour, minute);
}

/// `"2026-08-06"` -> that local midnight. Null when the API sent something
/// that is not a date, which simply leaves that end of the window open.
DateTime? _date(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}
