import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_week_grid.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass;

ScheduledSession entry(TeacherSession session) =>
    ScheduledSession(session: session, teacherClass: sampleClass());

void main() {
  group('weeks', () {
    test('a week starts on its Sunday', () {
      // Tuesday 6 October 2026 → Sunday 4 October.
      expect(weekStartOf(DateTime(2026, 10, 6, 15)), DateTime(2026, 10, 4));
      expect(weekStartOf(DateTime(2026, 10, 4)), DateTime(2026, 10, 4));
      expect(weekStartOf(DateTime(2026, 10, 10, 23)), DateTime(2026, 10, 4));
      // Across a month end.
      expect(weekStartOf(DateTime(2026, 11, 2)), DateTime(2026, 11, 1));
      expect(weekStartOf(DateTime(2026, 10, 31)), DateTime(2026, 10, 25));
    });

    test('the header names the selected date', () {
      expect(
        TeacherScheduleStrings.headerDate(DateTime(2026, 11, 17)),
        '11-р сарын 17',
      );
    });
  });

  group('a session', () {
    test('is over once its end has passed', () {
      final session = sampleSession();
      expect(session.isOverAt(DateTime(2026, 10, 6, 13, 59)), isFalse);
      expect(session.isOverAt(DateTime(2026, 10, 6, 15)), isFalse);
      expect(session.isOverAt(DateTime(2026, 10, 6, 17)), isTrue);
      expect(session.isOverAt(DateTime(2026, 10, 7)), isTrue);
    });
  });

  group('attendance', () {
    test('present and late are attended; absent and excused are not', () {
      const counts = AttendanceCounts(
        present: 12,
        late: 2,
        absent: 9,
        excused: 1,
      );
      expect(counts.attended, 14);
      expect(counts.total, 24);
      expect(counts.fraction, closeTo(14 / 24, 1e-9));
    });

    test('an empty roster is 0, not a division by zero', () {
      const counts = AttendanceCounts(
        present: 0,
        late: 0,
        absent: 0,
        excused: 0,
      );
      expect(counts.fraction, 0);
    });
  });

  group('placement', () {
    final week = DateTime(2026, 10, 4);

    test('sits a session in its day\'s column, at its real times', () {
      final placements = placeSessions(
        [entry(sampleSession())], // Tuesday 14:00–17:00
        weekStart: week,
        firstHour: 7,
      );

      final placement = placements.single;
      expect(placement.day, 2);
      expect(
        placement.top,
        TeacherWeekGridMetrics.topInset + 7 * TeacherWeekGridMetrics.hourHeight,
      );
      expect(placement.height, 3 * TeacherWeekGridMetrics.hourHeight);
      expect(placement.lanes, 1);
    });

    test('reads minutes as fractions of an hour', () {
      final placement = placeSessions(
        [entry(sampleSession(start: (9, 30), end: (10, 45)))],
        weekStart: week,
        firstHour: 7,
      ).single;
      expect(
        placement.top,
        TeacherWeekGridMetrics.topInset +
            2.5 * TeacherWeekGridMetrics.hourHeight,
      );
      expect(placement.height, 1.25 * TeacherWeekGridMetrics.hourHeight);
    });

    test('overlapping sessions share the column side by side', () {
      final placements = placeSessions(
        [
          entry(sampleSession(id: 1, start: (9, 0), end: (12, 0))),
          entry(sampleSession(id: 2, start: (10, 0), end: (11, 0))),
          entry(sampleSession(id: 3, start: (14, 0), end: (15, 0))),
        ],
        weekStart: week,
        firstHour: 7,
      );

      final byId = {for (final p in placements) p.entry.session.id: p};
      expect(byId[1]!.lanes, 2);
      expect(byId[2]!.lanes, 2);
      expect({byId[1]!.lane, byId[2]!.lane}, {0, 1});
      expect(byId[3]!.lanes, 1);
      expect(byId[3]!.lane, 0);
    });

    test('leaves out a session outside the week', () {
      final placements = placeSessions(
        [entry(sampleSession(date: '2026-10-11'))],
        weekStart: week,
        firstHour: 7,
      );
      expect(placements, isEmpty);
    });

    test('the grid widens to hold an early or late session', () {
      expect(hourSpan([]), (7, 23));
      expect(
        hourSpan([
          entry(sampleSession(start: (6, 30), end: (8, 0))),
          entry(sampleSession(start: (22, 0), end: (23, 30))),
        ]),
        (6, 24),
      );
    });
  });
}
