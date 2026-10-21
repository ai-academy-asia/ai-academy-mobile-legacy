import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_tabs.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:aia_mobile/shared/widgets/track_badge.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_shell.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_session_sheet.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile/fake_current_user_repository.dart';
import 'fake_schedule_change_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass, tuesday;

/// Tuesday 6 October 2026, 09:00: Monday's 09:00–12:00 is over, Tuesday's
/// 14:00–17:00 is still ahead.
FakeTeacherScheduleRepository weekRepository() => FakeTeacherScheduleRepository(
  classes: [sampleClass()],
  sessions: {
    2: [
      sampleSession(id: 41, date: '2026-10-06'),
      sampleSession(id: 40, date: '2026-10-05', start: (9, 0), end: (12, 0)),
    ],
  },
  attendance: {
    40: const AttendanceCounts(present: 12, late: 2, absent: 9, excused: 1),
  },
);

const upcomingLabel = 'AI Engineer, 14:00-17:00';
const heldLabel = 'AI Engineer, 09:00-12:00';

void main() {
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeTeacherScheduleRepository repository, {
    bool settle = true,
    FakeScheduleChangeRepository? scheduleChangeRepository,
  }) async {
    tallView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TeacherScheduleScreen(
          repository: repository,
          clock: tuesday,
          scheduleChangeRepository:
              scheduleChangeRepository ?? FakeScheduleChangeRepository(),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('shows a spinner while the first load runs', (tester) async {
    final repository = weekRepository()..hold = true;
    await pumpScreen(tester, repository, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SessionBlock), findsNothing);

    repository.release();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SessionBlock), findsNWidgets(2));
  });

  testWidgets('a session with no end time no longer fails the week: it is '
      'drawn, announced by its start alone, and not held yet (Issue #479)', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeTeacherScheduleRepository(
        classes: [sampleClass()],
        sessions: {
          2: [
            sampleSession(id: 41, start: (18, 30), end: null),
            sampleSession(
              id: 40,
              date: '2026-10-05',
              start: (9, 0),
              end: (12, 0),
            ),
          ],
        },
      ),
    );

    expect(find.text(TeacherHomeStrings.retry), findsNothing);
    expect(find.byType(SessionBlock), findsNWidgets(2));
    expect(find.bySemanticsLabel('AI Engineer, 18:30'), findsOneWidget);
    final noEnd = tester
        .widgetList<SessionBlock>(find.byType(SessionBlock))
        .firstWhere((b) => b.entry.session.id == 41);
    expect(noEnd.held, isFalse);
  });

  testWidgets('the header names today and the strip draws its week', (
    tester,
  ) async {
    await pumpScreen(tester, weekRepository());

    expect(find.text('10-р сарын 6'), findsOneWidget);
    for (final weekday in TeacherScheduleStrings.weekdays) {
      expect(find.text(weekday), findsOneWidget, reason: weekday);
    }
    for (var day = 4; day <= 10; day++) {
      expect(find.text('$day'), findsOneWidget, reason: '$day');
    }
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('22:00'), findsOneWidget);
  });

  testWidgets('blocks come from the sessions: held light, upcoming bright', (
    tester,
  ) async {
    await pumpScreen(tester, weekRepository());

    final blocks = tester
        .widgetList<SessionBlock>(find.byType(SessionBlock))
        .toList();
    final byId = {for (final b in blocks) b.entry.session.id: b};
    expect(byId.keys, unorderedEquals([40, 41]));
    expect(byId[40]!.held, isTrue);
    expect(byId[41]!.held, isFalse);

    // Tuesday's block sits in the third day column, 14:00 down the grid.
    final grid = tester.getTopLeft(find.byType(TeacherWeekGrid));
    final block = tester.getTopLeft(find.bySemanticsLabel(upcomingLabel));
    // The hour column the grid draws: the reference's 64 with the app's
    // font, wider under this file's test font, whose glyphs are a full em
    // (Issue #355).
    final timeColumn = timeColumnWidthOf(
      tester.element(find.byType(TeacherWeekGrid)),
    );
    final dayWidth = (393 - timeColumn) / 7;
    expect(block.dx - grid.dx, closeTo(timeColumn + 2 * dayWidth + 1, 0.01));
    expect(
      block.dy - grid.dy,
      closeTo(
        TeacherWeekGridMetrics.topInset + 7 * TeacherWeekGridMetrics.hourHeight,
        0.01,
      ),
    );
  });

  testWidgets('a tap on a day selects it', (tester) async {
    final repository = weekRepository();
    await pumpScreen(tester, repository);

    await tester.tap(find.bySemanticsLabel('Пү 8'));
    await tester.pumpAndSettle();

    expect(find.text('10-р сарын 8'), findsOneWidget);
    // Same week: nothing is fetched again.
    expect(repository.sessionCalls, hasLength(1));
  });

  testWidgets('an upcoming session opens its sheet with "Цаг солих"', (
    tester,
  ) async {
    final repository = weekRepository();
    await pumpScreen(tester, repository);

    await tester.tap(find.bySemanticsLabel(upcomingLabel));
    await tester.pumpAndSettle();

    final sheet = find.byType(TeacherSessionSheet);
    expect(sheet, findsOneWidget);
    Finder inSheet(Finder f) => find.descendant(of: sheet, matching: f);
    expect(inSheet(find.text('Cohort 01')), findsOneWidget);
    expect(inSheet(find.text('AI Engineer')), findsOneWidget);
    expect(inSheet(find.text('24 Students')), findsOneWidget);
    expect(inSheet(find.text('Room 204')), findsOneWidget);
    expect(inSheet(find.text('14:00-17:00')), findsOneWidget);
    expect(inSheet(find.byType(TrackBadge)), findsOneWidget);
    expect(
      inSheet(find.text(TeacherScheduleStrings.changeTime)),
      findsOneWidget,
    );
    expect(find.byType(SessionAttendanceSummary), findsNothing);
    expect(repository.attendanceCalls, isEmpty);
  });

  testWidgets('an online class shows no room', (tester) async {
    final repository = weekRepository()
      ..classes = [sampleClass(classroom: null)];
    await pumpScreen(tester, repository);

    await tester.tap(find.bySemanticsLabel(upcomingLabel));
    await tester.pumpAndSettle();

    expect(find.text('Room 204'), findsNothing);
  });

  testWidgets('"Цаг солих" opens "Багш нар" with the server\'s eligible '
      'teachers, and sends nothing on its own (Issue #449)', (tester) async {
    final requests = FakeScheduleChangeRepository(
      teachers: sampleEligibleTeachers,
    );
    await pumpScreen(
      tester,
      weekRepository(),
      scheduleChangeRepository: requests,
    );

    await tester.tap(find.bySemanticsLabel(upcomingLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TeacherScheduleStrings.changeTime));
    await tester.pumpAndSettle();

    expect(find.byType(TeacherRequestScreen), findsOneWidget);
    expect(find.text(TeacherScheduleStrings.teachersTitle), findsOneWidget);
    expect(requests.loadCalls, hasLength(1));
    expect(find.text('Болд Бат'), findsOneWidget);
    expect(find.text('Сараа Ганбат'), findsOneWidget);
    expect(requests.sendCalls, isEmpty);
  });

  testWidgets('a held session opens its sheet with the attendance summary', (
    tester,
  ) async {
    final repository = weekRepository();
    await pumpScreen(tester, repository);

    await tester.tap(find.bySemanticsLabel(heldLabel));
    await tester.pumpAndSettle();

    expect(repository.attendanceCalls, [40]);
    expect(find.byType(SessionAttendanceSummary), findsOneWidget);
    expect(find.text('09:00-12:00'), findsOneWidget);
    // present 12 + late 2 of all 24 listed.
    expect(find.text('14'), findsOneWidget);
    expect(find.text(' / 24'), findsOneWidget);
    expect(find.text(TeacherScheduleStrings.attendedCaption), findsOneWidget);
    expect(find.text(TeacherScheduleStrings.changeTime), findsNothing);

    final bar = tester.getSize(find.byKey(const ValueKey('attendance-bar')));
    final fill = tester.getSize(find.byKey(const ValueKey('attendance-fill')));
    expect(fill.width / bar.width, closeTo(14 / 24, 0.01));
  });

  testWidgets('a held session whose attendance fails says so, and retries', (
    tester,
  ) async {
    final repository = weekRepository()
      ..attendanceFailure = const TeacherFailure(TeacherFailureKind.server);
    await pumpScreen(tester, repository);

    await tester.tap(find.bySemanticsLabel(heldLabel));
    await tester.pumpAndSettle();

    expect(find.text(HomeStrings.serverError), findsOneWidget);
    expect(find.text(TeacherScheduleStrings.attendedCaption), findsNothing);

    repository.attendanceFailure = null;
    await tester.tap(find.text(TeacherHomeStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.attendanceCalls, [40, 40]);
    expect(find.text(TeacherScheduleStrings.attendedCaption), findsOneWidget);
  });

  testWidgets('an empty week draws the grid and says so', (tester) async {
    await pumpScreen(
      tester,
      FakeTeacherScheduleRepository(classes: [sampleClass()]),
    );

    expect(find.byType(TeacherWeekGrid), findsOneWidget);
    expect(find.byType(SessionBlock), findsNothing);
    expect(find.text(TeacherScheduleStrings.empty), findsOneWidget);
  });

  testWidgets('a failure shows its message, and retry loads again', (
    tester,
  ) async {
    final repository = weekRepository()
      ..failure = const TeacherFailure(TeacherFailureKind.network);
    await pumpScreen(tester, repository);

    expect(find.text(HomeStrings.networkError), findsOneWidget);
    expect(find.byType(TeacherWeekGrid), findsNothing);

    repository.failure = null;
    await tester.tap(find.text(TeacherHomeStrings.retry));
    await tester.pumpAndSettle();

    expect(repository.classCalls, 2);
    expect(find.byType(SessionBlock), findsNWidgets(2));
  });

  testWidgets('pull to refresh asks again', (tester) async {
    final repository = weekRepository();
    await pumpScreen(tester, repository);

    await tester.fling(
      find.byType(TeacherWeekGrid),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repository.classCalls, 2);
  });

  testWidgets('the request rows draw the reference\'s three states', (
    tester,
  ) async {
    tallView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const TeacherRequestScreen(
          candidates: [
            TeacherRequestCandidate(
              name: 'A',
              status: TeacherRequestStatus.pending,
            ),
            TeacherRequestCandidate(
              name: 'B',
              status: TeacherRequestStatus.notSent,
            ),
            TeacherRequestCandidate(
              name: 'C',
              status: TeacherRequestStatus.rejected,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(TeacherRequestRow), findsNWidgets(3));
    expect(find.text(TeacherScheduleStrings.requestPending), findsOneWidget);
    expect(find.text(TeacherScheduleStrings.requestSend), findsOneWidget);
    expect(find.text(TeacherScheduleStrings.requestRejected), findsOneWidget);
    expect(find.text(TeacherScheduleStrings.teacherRole), findsNWidgets(3));
    expect(find.text(TeacherScheduleStrings.requestsUnavailable), findsNothing);
  });

  group('teacher tab bar', () {
    Future<FakeTeacherScheduleRepository> pumpApp(WidgetTester tester) async {
      tallView(tester);
      final schedule = weekRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          initialRoute: HomeRoutes.teacher,
          // The app's own: the tabs inside one persistent shell (#241).
          routes: {
            HomeRoutes.teacher: (_) => TeacherShell(
              schedule: TeacherScheduleScreen(
                repository: schedule,
                clock: tuesday,
                showBottomNav: false,
              ),
              profile: TeacherProfileScreen(
                repository: FakeCurrentUserRepository(),
              ),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      return schedule;
    }

    testWidgets('the Teacher landing route opens on Teacher Schedule, '
        'Хуваарь selected, with no Нүүр tab (Issue #370)', (tester) async {
      await pumpApp(tester);

      expect(find.byType(TeacherScheduleScreen), findsOneWidget);
      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex,
        TeacherTab.schedule.index,
      );
      expect(find.text('Нүүр'), findsNothing);
      expect(find.byType(TeacherHomeScreen, skipOffstage: false), findsNothing);
    });

    testWidgets('Профайл opens the Teacher Profile (Issue #243); the current '
        'tab does nothing', (tester) async {
      await pumpApp(tester);

      // The current tab does nothing.
      await tester.tap(find.text(TeacherHomeStrings.navSchedule));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherScheduleScreen), findsOneWidget);

      // Дүнгийн хуудас's switch is covered in
      // teacher_gradebook_screen_test.dart.
      await tester.tap(find.text(TeacherHomeStrings.navProfile));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherProfileScreen), findsOneWidget);
      expect(find.byType(TeacherScheduleScreen), findsNothing);
    });
  });

  // Issue #499: today is marked in the week strip only, whatever day is
  // selected — a faint wash on its cell, its number in the accent when not
  // selected; the selected day keeps its circle. The grid stays neutral: no
  // column fill (it hid held lessons) and no edge lines.
  group('today\'s column', () {
    const palette = AppPalette.light;

    /// The strip's cell for [dayOfMonth] — labelled "<weekday> <day>",
    /// unlike the header's date button.
    Finder stripCell(int dayOfMonth) => find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.button == true &&
          RegExp('^\\S+ $dayOfMonth\$').hasMatch(w.properties.label ?? ''),
    );

    /// The grid's painted layer (its hairlines only).
    RenderObject gridPaint(WidgetTester tester) => tester.renderObject(
      find
          .descendant(
            of: find.byType(TeacherWeekGrid),
            matching: find.byType(CustomPaint),
          )
          .first,
    );

    /// Whether [paint] is in [color] — compared as ARGB: a colour read back
    /// from a Paint compares float components, which need not be
    /// bit-identical to the token's.
    bool inColor(Paint paint, Color color) =>
        paint.color.toARGB32() == color.toARGB32();

    /// Any line in the accent's outline colour — what a today-edge was.
    PaintPattern anyEdge() => paints
      ..something(
        (method, arguments) =>
            method == #drawLine &&
            inColor(arguments[2] as Paint, palette.accentSubtleOutline),
      );

    /// [dayOfMonth]'s date number in the strip.
    Text number(WidgetTester tester, int dayOfMonth) => tester.widget<Text>(
      find.descendant(
        of: stripCell(dayOfMonth),
        matching: find.text('$dayOfMonth'),
      ),
    );

    /// Whether [dayOfMonth]'s strip cell carries the wash.
    bool cellWashed(WidgetTester tester, int dayOfMonth) => tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: stripCell(dayOfMonth),
            matching: find.byType(ColoredBox),
          ),
        )
        .any((box) => box.color == palette.scheduleToday);

    /// The grid marks nothing for today: no edge line, no fill.
    void expectNeutralGrid(WidgetTester tester) {
      expect(gridPaint(tester), isNot(anyEdge()));
      expect(gridPaint(tester), paintsExactlyCountTimes(#drawRect, 0));
    }

    testWidgets('today selected: its strip cell is washed and its number sits '
        'in the filled circle; the grid stays neutral', (tester) async {
      await pumpScreen(tester, weekRepository());

      expectNeutralGrid(tester);
      expect(cellWashed(tester, 6), isTrue);
      expect(number(tester, 6).style?.color, palette.onPrimary);
      expect(
        find.descendant(
          of: stripCell(6),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color == palette.accent,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('another day selected: today keeps its wash and its number '
        'turns accent; the selected day keeps the circle; the grid stays '
        'neutral', (tester) async {
      await pumpScreen(tester, weekRepository());
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();

      expectNeutralGrid(tester);
      expect(cellWashed(tester, 6), isTrue);
      expect(cellWashed(tester, 8), isFalse);
      expect(number(tester, 6).style?.color, palette.accentText);
      expect(number(tester, 8).style?.color, palette.onPrimary);
      expect(number(tester, 7).style?.color, palette.textStrong);
    });

    testWidgets('a week without today: the grid marks nothing either', (
      tester,
    ) async {
      tallView(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TeacherWeekGrid(
              // The week after Tuesday 6 October.
              weekStart: DateTime(2026, 10, 11),
              sessions: const [],
              now: DateTime(2026, 10, 6, 9),
              onSessionTap: (_) {},
            ),
          ),
        ),
      );

      expectNeutralGrid(tester);
    });

    testWidgets('a held lesson in today\'s column keeps its own fill: the '
        'grid paints no fill behind it', (tester) async {
      // 07:00–08:00 today is over at 09:00; 14:00–17:00 is still ahead.
      await pumpScreen(
        tester,
        FakeTeacherScheduleRepository(
          classes: [sampleClass()],
          sessions: {
            2: [
              sampleSession(
                id: 50,
                date: '2026-10-06',
                start: (7, 0),
                end: (8, 0),
              ),
              sampleSession(id: 41, date: '2026-10-06'),
            ],
          },
        ),
      );

      expect(gridPaint(tester), paintsExactlyCountTimes(#drawRect, 0));
      final held = find.byWidgetPredicate(
        (w) => w is SessionBlock && w.held && w.entry.session.id == 50,
      );
      expect(held, findsOneWidget);
      expect(
        find.descendant(
          of: held,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color == palette.scheduleHeld,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a lesson in today\'s column still opens its sheet', (
      tester,
    ) async {
      await pumpScreen(tester, weekRepository());

      await tester.tap(find.bySemanticsLabel(upcomingLabel));
      await tester.pumpAndSettle();

      expect(find.byType(TeacherSessionSheet), findsOneWidget);
    });
  });
}
