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
}
