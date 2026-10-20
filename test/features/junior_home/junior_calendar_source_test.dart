import 'package:aia_mobile/features/home/domain/lesson_schedule.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// [JuniorCalendarSource.marksIn] — the one rule the Junior and Adult
/// attendance calendars mark a month with.
void main() {
  /// Tuesday/Saturday lessons. September 2026 starts on a Tuesday.
  const schedule = LessonSchedule(
    weekdays: {DateTime.tuesday, DateTime.saturday},
    start: (9, 0),
    end: (11, 0),
  );
  final september = DateTime(2026, 9);

  test('lesson days, then missed, then attended, each winning its day', () {
    final source = JuniorCalendarSource(
      schedule: schedule,
      attendedDates: {DateTime(2026, 9, 1), DateTime(2026, 9, 8)},
      // The 8th is both: attended wins.
      missedDates: {DateTime(2026, 9, 5), DateTime(2026, 9, 8)},
    );

    final marks = source.marksIn(september);

    expect(marks[1], JuniorDayStatus.attended);
    expect(marks[5], JuniorDayStatus.missed);
    expect(marks[8], JuniorDayStatus.attended);
    expect(marks[12], JuniorDayStatus.lesson);
    expect(marks[2], isNull);
  });

  test('a missed session on an unscheduled day is still marked', () {
    final source = JuniorCalendarSource(missedDates: {DateTime(2026, 9, 3)});

    expect(source.marksIn(september), {3: JuniorDayStatus.missed});
  });

  test('another month\'s sessions mark nothing in this one', () {
    final source = JuniorCalendarSource(
      attendedDates: {DateTime(2026, 8, 1)},
      missedDates: {DateTime(2026, 10, 3)},
    );

    expect(source.marksIn(september), isEmpty);
  });

  test('without missed dates nothing is marked missed — never inferred', () {
    final source = JuniorCalendarSource(
      schedule: schedule,
      attendedDates: {DateTime(2026, 9, 1)},
    );

    expect(
      source.marksIn(september).values,
      isNot(contains(JuniorDayStatus.missed)),
    );
  });

  group('first month (Issue #200)', () {
    JuniorCalendarSource startingOn(DateTime firstDay) => JuniorCalendarSource(
      schedule: LessonSchedule(
        weekdays: schedule.weekdays,
        start: schedule.start,
        end: schedule.end,
        firstDay: firstDay,
      ),
    );

    test('is each student\'s own cohort start month', () {
      expect(startingOn(DateTime(2023, 8, 14)).firstMonth, DateTime(2023, 8));
      expect(startingOn(DateTime(2024, 2, 1)).firstMonth, DateTime(2024, 2));
      expect(startingOn(DateTime(2025, 9, 30)).firstMonth, DateTime(2025, 9));
    });

    test('allows paging back only after the start month', () {
      final source = startingOn(DateTime(2023, 8, 14));

      expect(source.hasMonthBefore(DateTime(2023, 9)), isTrue);
      expect(source.hasMonthBefore(DateTime(2024, 1)), isTrue);
      expect(source.hasMonthBefore(DateTime(2023, 8)), isFalse);
      // Any day of the month reads as the month.
      expect(source.hasMonthBefore(DateTime(2023, 8, 31)), isFalse);
      expect(source.hasMonthBefore(DateTime(2023, 7)), isFalse);
      expect(source.hasMonthBefore(DateTime(2022, 12)), isFalse);
    });

    test('across a year boundary', () {
      final source = startingOn(DateTime(2024, 12, 3));

      expect(source.hasMonthBefore(DateTime(2025, 1)), isTrue);
      expect(source.hasMonthBefore(DateTime(2024, 12)), isFalse);
    });

    test('no start date or no schedule leaves paging unbounded', () {
      expect(const JuniorCalendarSource().firstMonth, isNull);
      expect(
        const JuniorCalendarSource().hasMonthBefore(DateTime(1990, 1)),
        isTrue,
      );
      expect(
        const JuniorCalendarSource(
          schedule: schedule,
        ).hasMonthBefore(DateTime(1990, 1)),
        isTrue,
      );
    });
  });

  group('last month (Issue #457)', () {
    JuniorCalendarSource running(DateTime? firstDay, DateTime? lastDay) =>
        JuniorCalendarSource(
          schedule: LessonSchedule(
            weekdays: schedule.weekdays,
            start: schedule.start,
            end: schedule.end,
            firstDay: firstDay,
            lastDay: lastDay,
          ),
        );

    test('is each student\'s own cohort end month', () {
      expect(
        running(DateTime(2023, 8, 14), DateTime(2024, 5, 31)).lastMonth,
        DateTime(2024, 5),
      );
      expect(running(null, DateTime(2026, 1, 1)).lastMonth, DateTime(2026, 1));
    });

    test('allows paging forward only before the end month', () {
      final source = running(DateTime(2023, 8, 14), DateTime(2024, 5, 31));

      expect(source.hasMonthAfter(DateTime(2023, 8)), isTrue);
      expect(source.hasMonthAfter(DateTime(2024, 4)), isTrue);
      expect(source.hasMonthAfter(DateTime(2024, 5)), isFalse);
      // Any day of the month reads as the month.
      expect(source.hasMonthAfter(DateTime(2024, 5, 1)), isFalse);
      expect(source.hasMonthAfter(DateTime(2024, 6)), isFalse);
      expect(source.hasMonthAfter(DateTime(2025, 1)), isFalse);
    });

    test('every month from start through end is reachable, both ways', () {
      final source = running(DateTime(2024, 11, 4), DateTime(2025, 2, 20));
      final forward = <DateTime>[DateTime(2024, 11)];
      while (source.hasMonthAfter(forward.last)) {
        final m = forward.last;
        forward.add(DateTime(m.year, m.month + 1));
      }
      expect(forward, [
        DateTime(2024, 11),
        DateTime(2024, 12),
        DateTime(2025, 1),
        DateTime(2025, 2),
      ]);

      final back = <DateTime>[DateTime(2025, 2)];
      while (source.hasMonthBefore(back.last)) {
        final m = back.last;
        back.add(DateTime(m.year, m.month - 1));
      }
      expect(back, forward.reversed.toList());
    });

    test('across a year boundary', () {
      final source = running(DateTime(2024, 9, 1), DateTime(2025, 1, 15));

      expect(source.hasMonthAfter(DateTime(2024, 12)), isTrue);
      expect(source.hasMonthAfter(DateTime(2025, 1)), isFalse);
    });

    test('a one-month course blocks both arrows', () {
      final source = running(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

      expect(source.hasMonthBefore(DateTime(2026, 10)), isFalse);
      expect(source.hasMonthAfter(DateTime(2026, 10)), isFalse);
    });

    test('no end date or no schedule leaves forward paging unbounded', () {
      expect(const JuniorCalendarSource().lastMonth, isNull);
      expect(
        const JuniorCalendarSource().hasMonthAfter(DateTime(2999, 12)),
        isTrue,
      );
      final noEnd = running(DateTime(2023, 8, 14), null);
      expect(noEnd.lastMonth, isNull);
      expect(noEnd.hasMonthAfter(DateTime(2999, 12)), isTrue);
    });

    test('an end before the start is ignored; the start bound stays', () {
      final source = running(DateTime(2025, 9, 1), DateTime(2025, 3, 31));

      expect(source.lastMonth, isNull);
      expect(source.hasMonthAfter(DateTime(2025, 9)), isTrue);
      expect(source.hasMonthBefore(DateTime(2025, 9)), isFalse);
    });

    test('opens on today\'s month while the course runs, else the nearest '
        'course month', () {
      final source = running(DateTime(2025, 11, 3), DateTime(2026, 2, 27));

      expect(source.openingMonth(DateTime(2025, 11, 3)), DateTime(2025, 11));
      expect(source.openingMonth(DateTime(2026, 1, 20)), DateTime(2026, 1));
      expect(source.openingMonth(DateTime(2026, 2, 28)), DateTime(2026, 2));
      // Not started yet: its first month. Ended: its last.
      expect(source.openingMonth(DateTime(2025, 9, 9)), DateTime(2025, 11));
      expect(source.openingMonth(DateTime(2026, 10, 6)), DateTime(2026, 2));
    });

    test('an unknown bound clamps nothing on its side', () {
      expect(
        const JuniorCalendarSource().openingMonth(DateTime(2026, 10, 6)),
        DateTime(2026, 10),
      );
      expect(
        running(DateTime(2025, 9, 1), null).openingMonth(DateTime(2030, 4, 2)),
        DateTime(2030, 4),
      );
      expect(
        running(null, DateTime(2025, 3, 31)).openingMonth(DateTime(2020, 4, 2)),
        DateTime(2020, 4),
      );
    });

    test('an end day earlier in the start month still bounds that month', () {
      final source = running(DateTime(2025, 9, 20), DateTime(2025, 9, 5));

      expect(source.lastMonth, DateTime(2025, 9));
      expect(source.hasMonthAfter(DateTime(2025, 9)), isFalse);
    });
  });
}
