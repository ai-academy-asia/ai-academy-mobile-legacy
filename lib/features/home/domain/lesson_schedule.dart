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
NextLesson? nextLessonFor({required Cohort cohort, required DateTime now}) {
  final weekdays = _weekdays(cohort.meetingDays);
  if (weekdays.isEmpty) return null;

  final start = _timeOfDay(cohort.startTime);
  final end = _timeOfDay(cohort.endTime);
  if (start == null || end == null) return null;

  final firstDay = _date(cohort.startDate);
  final lastDay = _date(cohort.endDate);

  final today = DateTime(now.year, now.month, now.day);

  // Scanning starts at the cohort's first day when that is still ahead, so a
  // cohort beginning next month still names its opening lesson instead of
  // answering "nothing this week".
  final from = firstDay != null && firstDay.isAfter(today) ? firstDay : today;

  // A week is enough: any weekly schedule meets again within seven days, and
  // the eighth candidate would repeat the first.
  for (var offset = 0; offset <= 7; offset++) {
    final day = from.add(Duration(days: offset));

    if (firstDay != null && day.isBefore(firstDay)) continue;
    if (lastDay != null && day.isAfter(lastDay)) break;
    if (!weekdays.contains(day.weekday)) continue;

    final startsAt = DateTime(day.year, day.month, day.day, start.$1, start.$2);
    final endsAt = DateTime(day.year, day.month, day.day, end.$1, end.$2);

    // Today's lesson is only still "next" until it has finished.
    if (now.isBefore(endsAt)) {
      return NextLesson(startsAt: startsAt, endsAt: endsAt);
    }
  }

  return null;
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

/// `"18:00"` -> `(18, 0)`. Null for anything that is not `H:mm`.
(int, int)? _timeOfDay(String value) {
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
