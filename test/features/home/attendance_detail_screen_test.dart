import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/attendance/domain/course_attendance.dart';
import 'package:aia_mobile/features/home/domain/home_dashboard.dart';
import 'package:aia_mobile/features/home/domain/lesson_schedule.dart';
import 'package:aia_mobile/features/home/presentation/attendance_detail_screen.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_palette.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_progress.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_progress_calendar.dart';
import 'package:flutter/material.dart';
import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The Adult attendance screen (Issue #172): what it draws from the data it
/// is handed, and its month paging.
void main() {
  setUpAll(loadAppFonts);

  /// Tuesday/Saturday, 09:00–11:00.
  const schedule = LessonSchedule(
    weekdays: {DateTime.tuesday, DateTime.saturday},
    start: (9, 0),
    end: (11, 0),
  );
  final today = DateTime(2026, 9, 10, 12);

  /// The `corp.s01` shape (#170): past present/late/absent sessions, and
  /// future ones with a null status — mapped the way Home maps them.
  AttendanceSummary summaryFrom(List<AttendanceSession> sessions) =>
      AttendanceSummary(
        attended: 2,
        total: 3,
        percent: 66,
        attendedDates: {
          for (final s in sessions)
            if (s.countsAsAttended) s.date,
        },
        missedDates: {
          for (final s in sessions)
            if (s.countsAsMissed) s.date,
        },
      );

  final sessions = [
    AttendanceSession(date: DateTime(2026, 9, 1), status: 'present'),
    AttendanceSession(date: DateTime(2026, 9, 5), status: 'late'),
    AttendanceSession(date: DateTime(2026, 9, 8), status: 'absent'),
    AttendanceSession(date: DateTime(2026, 9, 12), status: null),
    AttendanceSession(date: DateTime(2026, 9, 15), status: null),
  ];

  Future<void> pump(
    WidgetTester tester, {
    AttendanceSummary? attendance,
    NextLesson? nextLesson,
    LessonSchedule? lessonSchedule = schedule,
  }) async {
    useLogicalViewport(tester, const Size(393, 1000), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AttendanceDetailScreen(
                      attendance: attendance ?? summaryFrom(sessions),
                      schedule: lessonSchedule,
                      nextLesson: nextLesson,
                      clock: () => today,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  JuniorProgressCalendar calendar(WidgetTester tester) => tester
      .widget<JuniorProgressCalendar>(find.byType(JuniorProgressCalendar));

  testWidgets('the header is the server summary, as "x/y · z%"', (
    tester,
  ) async {
    await pump(
      tester,
      attendance: const AttendanceSummary(attended: 8, total: 9, percent: 88),
    );

    expect(find.text(HomeStrings.attendanceLabel), findsOneWidget);
    expect(find.text('8/9 · 88%'), findsOneWidget);
  });

  testWidgets('shows the next lesson', (tester) async {
    await pump(
      tester,
      nextLesson: NextLesson(
        startsAt: DateTime(2026, 9, 12, 9),
        endsAt: DateTime(2026, 9, 12, 11),
      ),
    );

    expect(find.text(JuniorProgressStrings.nextLesson), findsOneWidget);
    expect(find.text('09/12 • 09:00 – 11:00'), findsOneWidget);
  });

  testWidgets('leaves the next lesson out when there is none', (tester) async {
    await pump(tester);

    expect(find.text(JuniorProgressStrings.nextLesson), findsNothing);
    // The rest of the panel still draws.
    expect(find.byType(JuniorProgressCalendar), findsOneWidget);
  });

  testWidgets('opens on today\'s month, today selected', (tester) async {
    await pump(tester);

    expect(find.text('Есдүгээр сар, 2026'), findsOneWidget);
    expect(calendar(tester).month, DateTime(2026, 9));
    expect(calendar(tester).selectedDay, 10);
    for (final letter in JuniorProgressStrings.weekdays.toSet()) {
      expect(find.text(letter), findsWidgets);
    }
  });

  testWidgets('marks each day from the data: lesson, missed, attended, and '
      'nothing for a null status', (tester) async {
    await pump(tester);

    final days = calendar(tester).days;
    expect(days[1], JuniorDayStatus.attended); // present (a Tuesday)
    expect(days[5], JuniorDayStatus.attended); // late (a Saturday)
    expect(days[8], JuniorDayStatus.missed); // absent
    // Null status: the schedule's own lesson mark, never attended or missed.
    expect(days[12], JuniorDayStatus.lesson);
    expect(days[15], JuniorDayStatus.lesson);
    // Not a lesson day, no session.
    expect(days[10], isNull);
    expect(days.values, isNot(contains(null)));
  });

  testWidgets('a null-status session on an unscheduled day is left unmarked', (
    tester,
  ) async {
    await pump(
      tester,
      lessonSchedule: null,
      attendance: summaryFrom([
        AttendanceSession(date: DateTime(2026, 9, 1), status: 'present'),
        AttendanceSession(date: DateTime(2026, 9, 16), status: null),
      ]),
    );

    expect(calendar(tester).days, {1: JuniorDayStatus.attended});
  });

  testWidgets('rings the missed mark in red, as the Adult frame does', (
    tester,
  ) async {
    await pump(tester);

    expect(calendar(tester).missedRing, HomePalette.overdueOutline);
  });

  testWidgets('pages back and forward a month, selecting today only in its '
      'own month', (tester) async {
    await pump(tester);

    await tester.tap(
      find.bySemanticsLabel(JuniorProgressStrings.previousMonth),
    );
    await tester.pumpAndSettle();
    expect(find.text('Наймдугаар сар, 2026'), findsOneWidget);
    expect(calendar(tester).month, DateTime(2026, 8));
    expect(calendar(tester).selectedDay, isNull);
    // August's marks are worked out for August.
    expect(calendar(tester).days[1], JuniorDayStatus.lesson); // a Saturday

    await tester.tap(find.bySemanticsLabel(JuniorProgressStrings.nextMonth));
    await tester.tap(find.bySemanticsLabel(JuniorProgressStrings.nextMonth));
    await tester.pumpAndSettle();
    expect(find.text('Аравдугаар сар, 2026'), findsOneWidget);
    expect(calendar(tester).selectedDay, isNull);

    await tester.tap(
      find.bySemanticsLabel(JuniorProgressStrings.previousMonth),
    );
    await tester.pumpAndSettle();
    expect(calendar(tester).month, DateTime(2026, 9));
    expect(calendar(tester).selectedDay, 10);
  });

  testWidgets('the legend uses the Adult frame\'s wording', (tester) async {
    await pump(tester);

    expect(find.text(JuniorProgressStrings.legendTitle), findsOneWidget);
    expect(find.text(JuniorProgressStrings.lessonDay), findsOneWidget);
    expect(find.text(HomeStrings.attendanceMissed), findsOneWidget);
    expect(find.text(JuniorProgressStrings.lessonMissed), findsNothing);
    expect(find.text(JuniorProgressStrings.lessonAttended), findsOneWidget);
  });

  testWidgets('the back control returns to Home', (tester) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(AttendanceDetailScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  group('first month (Issue #200)', () {
    Finder previous() =>
        find.bySemanticsLabel(JuniorProgressStrings.previousMonth);

    // The cohort started 6 August 2026; today is 10 September 2026.
    final startingInAugust = LessonSchedule(
      weekdays: schedule.weekdays,
      start: schedule.start,
      end: schedule.end,
      firstDay: DateTime(2026, 8, 6),
    );

    testWidgets('"<" stops at the cohort start month and is drawn '
        'disabled there', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, lessonSchedule: startingInAugust);

      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.caretLeft)).color,
        AppColors.textPrimary,
      );

      await tester.tap(previous());
      await tester.pumpAndSettle();
      expect(calendar(tester).month, DateTime(2026, 8));

      // At August: muted, announced as disabled, and inert.
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.caretLeft)).color,
        HomePalette.mutedInk,
      );
      expect(
        tester.getSemantics(previous()),
        matchesSemantics(
          label: JuniorProgressStrings.previousMonth,
          isButton: true,
          hasEnabledState: true,
        ),
      );
      await tester.tap(previous());
      await tester.pumpAndSettle();
      expect(calendar(tester).month, DateTime(2026, 8));
      expect(find.text('Наймдугаар сар, 2026'), findsOneWidget);

      // Forward still works, and "<" comes back.
      await tester.tap(find.bySemanticsLabel(JuniorProgressStrings.nextMonth));
      await tester.pumpAndSettle();
      expect(calendar(tester).month, DateTime(2026, 9));
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.caretLeft)).color,
        AppColors.textPrimary,
      );
      semantics.dispose();
    });

    testWidgets('with no start date paging back is unbounded, as before', (
      tester,
    ) async {
      await pump(tester);

      for (var i = 0; i < 14; i++) {
        await tester.tap(previous());
        await tester.pumpAndSettle();
      }

      expect(calendar(tester).month, DateTime(2025, 7));
    });
  });
}
