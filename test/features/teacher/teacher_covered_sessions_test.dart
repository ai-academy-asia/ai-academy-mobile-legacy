import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_attendance_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_controller.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_class_card.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_day_session_list.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_session_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_schedule_change_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass, tuesday;

/// Covered sessions in Teacher Schedule (Issue #455): the week merges the
/// teacher's own sessions — with who covers them — and the sessions they
/// cover, from `GET /teacher/sessions`; on fakes only, nothing reaches the
/// network. The clock is Tuesday 6 October 2026: the week is 4–10 October.
void main() {
  const coveringTitle = 'Corporate Leaders';

  /// A session this teacher covers, on [date] from [start] to [end].
  AssignedSession cover({
    int id = 77,
    String date = '2026-10-08',
    (int, int) start = (10, 0),
    (int, int) end = (11, 0),
    String? title = coveringTitle,
    String? originalTeacher = 'Анар Бат',
  }) => AssignedSession.covering(
    sessionId: id,
    session: sampleSession(
      id: id,
      cohortId: 9,
      date: date,
      start: start,
      end: end,
    ),
    covering: CoveringSession(
      requestId: 12,
      courseTitle: title,
      cohortName: 'CL-2026-10',
      room: 'Room 204',
      originalTeacher: originalTeacher,
    ),
  );

  /// The teacher's week: 40 (Mon 09:00–12:00, held) and 41 (Tue 14:00–17:00)
  /// of their own class, plus [assigned].
  FakeTeacherScheduleRepository week({
    List<AssignedSession> assigned = const [],
    TeacherFailure? assignedFailure,
  }) => FakeTeacherScheduleRepository(
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
    assigned: assigned,
    assignedFailure: assignedFailure,
  );

  group('the week', () {
    Future<TeacherScheduleController> loaded(
      FakeTeacherScheduleRepository repository,
    ) async {
      final controller = TeacherScheduleController(
        repository: repository,
        clock: tuesday,
      );
      await controller.load();
      return controller;
    }

    test(
      'asks the range once, from the week\'s first to its last day',
      () async {
        final repository = week();
        await loaded(repository);

        expect(repository.assignedCalls, [
          (DateTime(2026, 10, 4), DateTime(2026, 10, 10)),
        ]);
      },
    );

    test('a covering session joins the week in date and time order', () async {
      final controller = await loaded(
        week(
          assigned: [
            cover(id: 77, date: '2026-10-06', start: (8, 0), end: (9, 0)),
            cover(id: 78, date: '2026-10-09'),
          ],
        ),
      );

      expect(
        [for (final e in controller.sessions!) e.session.id],
        [
          40, // Mon 09:00
          77, // Tue 08:00
          41, // Tue 14:00
          78, // Fri 10:00
        ],
      );
      final covering = controller.sessions![1];
      expect(covering.isCovering, isTrue);
      expect(covering.teacherClass, isNull);
      expect(covering.title, coveringTitle);
    });

    test('an own session another teacher covers carries their name; the '
        'rest are unchanged', () async {
      final controller = await loaded(
        week(
          assigned: [
            const AssignedSession.regular(sessionId: 41, coveredBy: 'Болд Бат'),
            const AssignedSession.regular(sessionId: 40),
          ],
        ),
      );

      final byId = {for (final e in controller.sessions!) e.session.id: e};
      expect(byId[41]!.coveredBy, 'Болд Бат');
      expect(byId[41]!.teacherClass, isNotNull);
      expect(byId[40]!.coveredBy, isNull);
      expect(controller.sessions, hasLength(2));
    });

    test('a session is drawn once even if both reads name it', () async {
      final controller = await loaded(
        week(
          assigned: [
            // Never sent by the backend — a cover of the teacher's own
            // session — but drawn once if it were.
            cover(id: 41, date: '2026-10-06'),
          ],
        ),
      );

      expect([for (final e in controller.sessions!) e.session.id], [40, 41]);
      expect(
        controller.sessions!.firstWhere((e) => e.session.id == 41).isCovering,
        isFalse,
      );
    });

    test('a covering session outside the week is not drawn', () async {
      final controller = await loaded(
        week(assigned: [cover(id: 79, date: '2026-10-11')]),
      );

      expect([for (final e in controller.sessions!) e.session.id], [40, 41]);
    });

    test(
      'covers alone fill a week with no running class of their own',
      () async {
        final controller = await loaded(
          FakeTeacherScheduleRepository(assigned: [cover()]),
        );

        expect([for (final e in controller.sessions!) e.session.id], [77]);
        expect(controller.isEmpty, isFalse);
      },
    );

    test(
      'a failed range read fails the week — never one missing its covers',
      () async {
        final controller = await loaded(
          week(
            assignedFailure: const TeacherFailure(TeacherFailureKind.server),
          ),
        );

        expect(controller.sessions, isNull);
        expect(
          controller.errorMessage,
          TeacherHomeStrings.messageFor(TeacherFailureKind.server),
        );
      },
    );
  });

  group('the schedule screen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      FakeTeacherScheduleRepository repository, {
      bool attendanceOpen = true,
    }) async {
      tester.view.physicalSize = const Size(393, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TeacherScheduleScreen(
            repository: repository,
            clock: tuesday,
            attendanceOpen: (_, _) => attendanceOpen,
            scheduleChangeRepository: FakeScheduleChangeRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder inSheet(Finder finder) =>
        find.descendant(of: find.byType(TeacherSessionSheet), matching: finder);

    testWidgets('a covering block reads "Орлон заах" in its slot', (
      tester,
    ) async {
      await pumpScreen(tester, week(assigned: [cover()]));

      expect(
        find.bySemanticsLabel('Орлон заах, $coveringTitle, 10:00-11:00'),
        findsOneWidget,
      );
      // Ordinary blocks read exactly as before.
      expect(find.bySemanticsLabel('AI Engineer, 14:00-17:00'), findsOneWidget);
      expect(find.bySemanticsLabel('AI Engineer, 09:00-12:00'), findsOneWidget);
    });

    testWidgets('a covered block names the covering teacher', (tester) async {
      await pumpScreen(
        tester,
        week(
          assigned: [
            const AssignedSession.regular(sessionId: 41, coveredBy: 'Болд Бат'),
          ],
        ),
      );

      expect(
        find.bySemanticsLabel(
          'Орлон заагдсан · Болд Бат, AI Engineer, 14:00-17:00',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a covering session\'s sheet: its label and card, and no '
        'handover, attendance or QR action', (tester) async {
      final repository = week(assigned: [cover()]);
      await pumpScreen(tester, repository);

      await tester.tap(
        find.bySemanticsLabel('Орлон заах, $coveringTitle, 10:00-11:00'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TeacherSessionSheet), findsOneWidget);
      expect(
        inSheet(find.text(TeacherScheduleStrings.covering)),
        findsOneWidget,
      );
      expect(inSheet(find.text(coveringTitle)), findsOneWidget);
      expect(inSheet(find.text('Room 204')), findsOneWidget);
      expect(find.text(TeacherScheduleStrings.changeTime), findsNothing);
      expect(
        find.text(TeacherScheduleStrings.registerAttendance),
        findsNothing,
      );
      expect(find.text(TeacherAttendanceStrings.manualEntry), findsNothing);
      expect(repository.attendanceCalls, isEmpty);
    });

    testWidgets('a held covering session reads no attendance and offers no '
        'manual marking', (tester) async {
      final repository = week(
        assigned: [
          cover(id: 76, date: '2026-10-05', start: (7, 0), end: (8, 0)),
        ],
      );
      await pumpScreen(tester, repository);

      await tester.tap(
        find.bySemanticsLabel('Орлон заах, $coveringTitle, 07:00-08:00'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TeacherSessionSheet), findsOneWidget);
      expect(find.text(TeacherAttendanceStrings.manualEntry), findsNothing);
      expect(repository.attendanceCalls, isEmpty);
    });

    testWidgets('a covered session\'s sheet keeps attendance but not '
        '"Цаг солих"', (tester) async {
      await pumpScreen(
        tester,
        week(
          assigned: [
            const AssignedSession.regular(sessionId: 41, coveredBy: 'Болд Бат'),
          ],
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(
          'Орлон заагдсан · Болд Бат, AI Engineer, 14:00-17:00',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        inSheet(find.text(TeacherScheduleStrings.coveredBy('Болд Бат'))),
        findsOneWidget,
      );
      expect(find.text(TeacherScheduleStrings.changeTime), findsNothing);
      expect(
        inSheet(find.text(TeacherScheduleStrings.registerAttendance)),
        findsOneWidget,
      );
    });

    testWidgets('a session covered by a teacher with a blank name: '
        '"Орлон заагдсан" alone, still no "Цаг солих" (Issue #537)', (
      tester,
    ) async {
      expect(TeacherScheduleStrings.coveredBy(''), 'Орлон заагдсан');
      expect(TeacherScheduleStrings.coveredBy('   '), 'Орлон заагдсан');
      await pumpScreen(
        tester,
        week(
          assigned: [
            const AssignedSession.regular(sessionId: 41, coveredBy: ''),
          ],
        ),
      );

      await tester.tap(
        find.bySemanticsLabel('Орлон заагдсан, AI Engineer, 14:00-17:00'),
      );
      await tester.pumpAndSettle();

      expect(inSheet(find.text('Орлон заагдсан')), findsOneWidget);
      expect(find.text(TeacherScheduleStrings.changeTime), findsNothing);
      expect(
        inSheet(find.text(TeacherScheduleStrings.registerAttendance)),
        findsOneWidget,
      );
    });

    testWidgets('an ordinary session\'s sheet keeps both its actions', (
      tester,
    ) async {
      await pumpScreen(tester, week(assigned: [cover()]));

      await tester.tap(find.bySemanticsLabel('AI Engineer, 14:00-17:00'));
      await tester.pumpAndSettle();

      expect(inSheet(find.byType(AssignmentCapsule)), findsNothing);
      expect(
        inSheet(find.text(TeacherScheduleStrings.changeTime)),
        findsOneWidget,
      );
      expect(
        inSheet(find.text(TeacherScheduleStrings.registerAttendance)),
        findsOneWidget,
      );
    });

    testWidgets('a held covered session keeps its attendance summary', (
      tester,
    ) async {
      final repository = week(
        assigned: [
          const AssignedSession.regular(sessionId: 40, coveredBy: 'Болд Бат'),
        ],
      );
      await pumpScreen(tester, repository);

      await tester.tap(
        find.bySemanticsLabel(
          'Орлон заагдсан · Болд Бат, AI Engineer, 09:00-12:00',
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.attendanceCalls, [40]);
      expect(
        inSheet(find.text(TeacherAttendanceStrings.manualEntry)),
        findsOneWidget,
      );
    });

    testWidgets('a failed range read shows the error with its retry', (
      tester,
    ) async {
      final repository = week(
        assignedFailure: const TeacherFailure(TeacherFailureKind.network),
      );
      await pumpScreen(tester, repository);

      expect(
        find.text(TeacherHomeStrings.messageFor(TeacherFailureKind.network)),
        findsOneWidget,
      );
      expect(find.text(TeacherHomeStrings.retry), findsOneWidget);
      expect(find.bySemanticsLabel('AI Engineer, 14:00-17:00'), findsNothing);

      repository.assignedFailure = null;
      await tester.tap(find.text(TeacherHomeStrings.retry));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('AI Engineer, 14:00-17:00'), findsOneWidget);
    });
  });

  group('the day list card (large text)', () {
    Future<void> pumpCard(
      WidgetTester tester,
      ScheduledSession entry, {
      bool held = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeacherDaySessionCard(
                entry: entry,
                held: held,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a covering session: "Орлон заах" over the brief card', (
      tester,
    ) async {
      final item = cover();
      await pumpCard(
        tester,
        ScheduledSession.covering(
          session: item.session!,
          covering: item.covering!,
        ),
      );

      expect(find.text(TeacherScheduleStrings.covering), findsOneWidget);
      expect(find.text(coveringTitle), findsOneWidget);
      expect(find.text('CL-2026-10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a held covered session: "Дууссан" and its label', (
      tester,
    ) async {
      await pumpCard(
        tester,
        ScheduledSession(
          session: sampleSession(id: 40, date: '2026-10-05'),
          teacherClass: sampleClass(),
          coveredBy: 'Болд Бат',
        ),
        held: true,
      );

      expect(find.text(TeacherScheduleStrings.finished), findsOneWidget);
      expect(
        find.text(TeacherScheduleStrings.coveredBy('Болд Бат')),
        findsOneWidget,
      );
    });

    testWidgets('a covering session naming no course takes its cohort as the '
        'title, once', (tester) async {
      final item = cover(title: null);
      await pumpCard(
        tester,
        ScheduledSession.covering(
          session: item.session!,
          covering: item.covering!,
        ),
      );

      // The cohort name stands in as the title, not as a caption too.
      expect(find.text('CL-2026-10'), findsOneWidget);
    });

    testWidgets('an ordinary session carries no label', (tester) async {
      await pumpCard(
        tester,
        ScheduledSession(
          session: sampleSession(id: 41),
          teacherClass: sampleClass(),
        ),
      );

      expect(find.byType(AssignmentCapsule), findsNothing);
    });
  });
}
