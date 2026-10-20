import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_schedule_change_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass, tuesday;

/// The week grid opens on the selected day's first session (Issue #465):
/// Tuesday 6 October 2026 at 09:00, the week of Sunday 4 – Saturday 10,
/// on a phone-sized screen.
/// [session] as one of the teacher's own, in [sampleClass].
ScheduledSession own(TeacherSession session) =>
    ScheduledSession(session: session, teacherClass: sampleClass());

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    List<TeacherSession> sessions,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TeacherScheduleScreen(
          repository: FakeTeacherScheduleRepository(
            classes: [sampleClass()],
            sessions: {2: sessions},
          ),
          clock: tuesday,
          scheduleChangeRepository: FakeScheduleChangeRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder gridScrollable() => find
      .descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      )
      .first;

  ScrollPosition grid(WidgetTester tester) =>
      tester.state<ScrollableState>(gridScrollable()).position;

  /// The grid's visible window on screen.
  Rect window(WidgetTester tester) => tester.getRect(gridScrollable());

  /// The block of the session starting at [start] on [date].
  Finder block(String date, (int, int) start) => find.byWidgetPredicate(
    (w) =>
        w is SessionBlock &&
        w.entry.session.date == DateTime.parse(date) &&
        w.entry.session.start == start,
  );

  /// [finder] wholly inside the grid's visible window.
  void expectShown(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    final view = window(tester);
    expect(rect.top, greaterThanOrEqualTo(view.top), reason: '$finder top');
    expect(
      rect.bottom,
      lessThanOrEqualTo(view.bottom),
      reason: '$finder bottom',
    );
  }

  Future<void> selectDay(WidgetTester tester, int dayOfMonth) async {
    await tester.tap(find.text('$dayOfMonth'));
    await tester.pumpAndSettle();
  }

  testWidgets('a first lesson at 19:00: the grid opens on it, the 18:00 '
      'hour above it in view', (tester) async {
    await pumpScreen(tester, [
      sampleSession(id: 1, date: '2026-10-06', start: (19, 0), end: (21, 0)),
    ]);

    expect(grid(tester).pixels, greaterThan(0));
    expectShown(tester, block('2026-10-06', (19, 0)));
    expectShown(tester, find.text('18:00'));
    // Exactly where the grid's own geometry puts the block, an hour above,
    // as far as the grid can scroll.
    final top = firstSessionTop(
      [own(sampleSession(id: 1, date: '2026-10-06', start: (19, 0)))],
      weekStart: DateTime(2026, 10, 4),
      day: DateTime(2026, 10, 6),
    )!;
    expect(
      grid(tester).pixels,
      (top - TeacherWeekGridMetrics.hourHeight).clamp(
        0,
        grid(tester).maxScrollExtent,
      ),
    );
  });

  testWidgets('several lessons: the earliest of the selected day, not '
      'another day\'s earlier one', (tester) async {
    await pumpScreen(tester, [
      sampleSession(id: 1, date: '2026-10-06', start: (20, 0), end: (21, 0)),
      sampleSession(id: 2, date: '2026-10-06', start: (17, 0), end: (18, 0)),
      // Wednesday's 08:00 is earlier in the day, but not on Tuesday.
      sampleSession(id: 3, date: '2026-10-07', start: (8, 0), end: (9, 0)),
    ]);

    expect(grid(tester).pixels, greaterThan(0));
    expectShown(tester, block('2026-10-06', (17, 0)));
    expectShown(tester, find.text('16:00'));
  });

  testWidgets('a morning lesson already in view moves nothing', (tester) async {
    await pumpScreen(tester, [
      sampleSession(id: 1, date: '2026-10-06', start: (9, 0), end: (11, 0)),
    ]);

    expect(grid(tester).pixels, 0);
    expectShown(tester, block('2026-10-06', (9, 0)));
  });

  testWidgets('no lesson on the selected day: the grid stays at its top', (
    tester,
  ) async {
    await pumpScreen(tester, [
      sampleSession(id: 1, date: '2026-10-08', start: (19, 0), end: (21, 0)),
    ]);

    expect(grid(tester).pixels, 0);
  });

  testWidgets('choosing another day positions the grid for that day', (
    tester,
  ) async {
    await pumpScreen(tester, [
      sampleSession(id: 1, date: '2026-10-06', start: (19, 0), end: (21, 0)),
      sampleSession(id: 2, date: '2026-10-07', start: (8, 0), end: (10, 0)),
      sampleSession(id: 3, date: '2026-10-08', start: (20, 0), end: (21, 0)),
    ]);
    final evening = grid(tester).pixels;
    expect(evening, greaterThan(0));

    // Wednesday's 08:00 is above the view: the grid goes back up, to the
    // 07:00 line an hour above it.
    await selectDay(tester, 7);
    expect(grid(tester).pixels, TeacherWeekGridMetrics.topInset);
    expectShown(tester, block('2026-10-07', (8, 0)));

    // Thursday's 20:00 is below it again.
    await selectDay(tester, 8);
    expect(grid(tester).pixels, greaterThan(0));
    expectShown(tester, block('2026-10-08', (20, 0)));
  });

  testWidgets('a day in another week is positioned once that week loads', (
    tester,
  ) async {
    await pumpScreen(tester, [
      sampleSession(id: 1, date: '2026-10-06', start: (9, 0), end: (10, 0)),
      sampleSession(id: 2, date: '2026-10-13', start: (19, 0), end: (21, 0)),
    ]);
    expect(grid(tester).pixels, 0);

    // Next week's Tuesday, from the header's date picker.
    await tester.tap(
      find.bySemanticsLabel(RegExp('^${TeacherScheduleStrings.pickDate}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('13'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expectShown(tester, block('2026-10-13', (19, 0)));
    expect(grid(tester).pixels, greaterThan(0));
  });

  testWidgets('after positioning, the teacher\'s own scrolling is kept: a '
      'refresh or a rebuild does not pull the grid back', (tester) async {
    await pumpScreen(tester, [
      sampleSession(id: 1, date: '2026-10-06', start: (19, 0), end: (21, 0)),
    ]);
    expect(grid(tester).pixels, greaterThan(0));

    // The teacher scrolls back up to the top…
    grid(tester).jumpTo(0);
    await tester.pumpAndSettle();
    // …then pulls to refresh, which reloads the week and rebuilds.
    await tester.fling(gridScrollable(), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(grid(tester).pixels, 0);

    // Scrolled partway down by hand, the same day: still left alone.
    await tester.drag(gridScrollable(), const Offset(0, -120));
    await tester.pumpAndSettle();
    final kept = grid(tester).pixels;
    await selectDay(tester, 6); // the day already selected: no change
    expect(grid(tester).pixels, kept);
  });

  group('firstSessionTop', () {
    test('is where the grid places the day\'s earliest block', () {
      final week = DateTime(2026, 10, 4);
      final sessions = [
        own(sampleSession(id: 1, date: '2026-10-06', start: (19, 30))),
        own(sampleSession(id: 2, date: '2026-10-06', start: (18, 15))),
      ];
      // 07:00 first: 18:15 is 11 h 15 min down, at 64 per hour.
      expect(
        firstSessionTop(sessions, weekStart: week, day: DateTime(2026, 10, 6)),
        TeacherWeekGridMetrics.topInset + 11.25 * 64,
      );
      expect(
        firstSessionTop(sessions, weekStart: week, day: DateTime(2026, 10, 7)),
        isNull,
      );
    });

    test('follows the grid when an earlier session widens its hours', () {
      final week = DateTime(2026, 10, 4);
      final sessions = [
        // Monday 06:00 makes the grid start at 06:00 for the whole week.
        own(sampleSession(id: 1, date: '2026-10-05', start: (6, 0))),
        own(sampleSession(id: 2, date: '2026-10-06', start: (19, 0))),
      ];
      expect(
        firstSessionTop(sessions, weekStart: week, day: DateTime(2026, 10, 6)),
        TeacherWeekGridMetrics.topInset + 13 * 64,
      );
    });
  });
}
