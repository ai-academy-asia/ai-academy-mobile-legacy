import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/auth/presentation/home_route.dart';
import 'package:aia_mobile/features/home/presentation/home_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_badges.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_session_sheet.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_tabs.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_teacher_home_repository.dart';
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
  }) async {
    tallView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TeacherScheduleScreen(repository: repository, clock: tuesday),
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
    final dayWidth = (393 - TeacherWeekGridMetrics.timeColumnWidth) / 7;
    expect(
      block.dx - grid.dx,
      closeTo(TeacherWeekGridMetrics.timeColumnWidth + 2 * dayWidth + 1, 0.01),
    );
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

  testWidgets('"Цаг солих" opens "Багш нар", which sends and invents nothing', (
    tester,
  ) async {
    await pumpScreen(tester, weekRepository());

    await tester.tap(find.bySemanticsLabel(upcomingLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TeacherScheduleStrings.changeTime));
    await tester.pumpAndSettle();

    expect(find.byType(TeacherRequestScreen), findsOneWidget);
    expect(find.text(TeacherScheduleStrings.teachersTitle), findsOneWidget);
    expect(
      find.text(TeacherScheduleStrings.requestsUnavailable),
      findsOneWidget,
    );
    expect(find.byType(TeacherRequestRow), findsNothing);
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
          routes: {
            HomeRoutes.teacher: (_) => TeacherHomeScreen(
              repository: FakeTeacherHomeRepository(classes: [sampleClass()]),
              clock: tuesday,
            ),
            TeacherTabRoutes.schedule: (_) =>
                TeacherScheduleScreen(repository: schedule, clock: tuesday),
          },
        ),
      );
      await tester.pumpAndSettle();
      return schedule;
    }

    testWidgets('Хуваарь opens Teacher Schedule, and Нүүр returns Home', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text(TeacherHomeStrings.navSchedule));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherScheduleScreen), findsOneWidget);

      await tester.tap(find.text(TeacherHomeStrings.navHome));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherScheduleScreen), findsNothing);
      expect(find.byType(TeacherHomeScreen), findsOneWidget);
    });

    testWidgets('Дүнгийн хуудас and Профайл stay inert', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text(TeacherHomeStrings.navSchedule));
      await tester.pumpAndSettle();

      for (final label in [
        TeacherHomeStrings.navGrades,
        TeacherHomeStrings.navProfile,
        // The current tab does nothing either.
        TeacherHomeStrings.navSchedule,
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(TeacherScheduleScreen), findsOneWidget);
      }
    });
  });
}
