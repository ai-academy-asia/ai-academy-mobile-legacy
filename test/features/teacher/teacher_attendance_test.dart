import 'dart:async';

import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_attendance.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/attendance_qr_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/manual_attendance_controller.dart';
import 'package:aia_mobile/features/teacher/presentation/manual_attendance_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_attendance_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_confirmation_card.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_pill_button.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_session_sheet.dart';
import 'package:aia_mobile/shared/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../support/screenshot.dart';
import 'fake_teacher_attendance_repository.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass;
import 'teacher_schedule_screen_test.dart' show upcomingLabel, weekRepository;

/// Teacher attendance registration (Issue #374): the QR screen's token and
/// polling lifecycle, the manual screen's changed-rows-only writes and
/// retries, the success card only after confirmed writes, and the session
/// sheet's date rule. Fakes only — no production call, no real record.

/// A test-only QR payload: what the code encodes is unconfirmed, so the
/// production default draws none ([attendanceQrPayload]).
String testPayload(String token) => 'test-payload:$token';

List<StudentAttendance> referenceRoster() => [
  student(1, 'Болд Батаа', AttendanceStatus.present, method: 'qr'),
  student(2, 'Саруул Батбаатар', AttendanceStatus.absent),
  student(3, 'Ганчимэг Батбаяр', AttendanceStatus.present, method: 'qr'),
  student(4, 'Доржпалам Сүхбаатар', AttendanceStatus.absent),
  student(5, 'Анхбаяр Болд', AttendanceStatus.late, method: 'qr'),
  student(6, 'Мөнхцэцэг Батсүх', AttendanceStatus.present, method: 'qr'),
  student(7, 'Сүхбаатар Тэмүүжин', AttendanceStatus.excused, method: 'manual'),
  student(8, 'Дэлгэрмаа Содбилэг', AttendanceStatus.present, method: 'qr'),
  student(9, 'Мөнхбат Даваасүрэн', AttendanceStatus.absent),
];

void main() {
  setUpAll(loadAppFonts);

  Future<List<String>> pumpApp(
    WidgetTester tester,
    Widget home, {
    double width = 393,
    double height = 852,
    double scale = 1,
  }) async {
    useLogicalViewport(tester, Size(width, height), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: home,
        ),
      );
      await tester.pump();
      await tester.pump();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  Finder pill(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(TeacherPillButton),
  );

  group('the session sheet\'s entry rule', () {
    final session = sampleSession(date: '2026-10-06');

    test('open only on the session\'s date in Ulaanbaatar', () {
      // 10:00 in Ulaanbaatar on the 6th.
      expect(attendanceOpenOn(session, DateTime.utc(2026, 10, 6, 2)), isTrue);
      // 00:00 on the 6th in Ulaanbaatar is 16:00 UTC on the 5th.
      expect(attendanceOpenOn(session, DateTime.utc(2026, 10, 5, 16)), isTrue);
      expect(
        attendanceOpenOn(session, DateTime.utc(2026, 10, 5, 15, 59)),
        isFalse,
      );
      expect(attendanceOpenOn(session, DateTime.utc(2026, 10, 7, 1)), isFalse);
    });

    testWidgets('on the date, "Ирц бүртгэх" is live and opens the QR screen', (
      tester,
    ) async {
      final attendance = FakeTeacherAttendanceRepository(
        students: referenceRoster(),
      );
      await pumpApp(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TeacherSessionSheet(
              entry: ScheduledSession(
                session: session,
                teacherClass: sampleClass(),
              ),
              held: false,
              repository: FakeTeacherScheduleRepository(),
              attendanceOpen: true,
              attendanceRepository: attendance,
            ),
          ),
        ),
      );
      final button = tester.widget<TeacherPillButton>(
        pill(TeacherScheduleStrings.registerAttendance),
      );
      expect(button.variant, TeacherPillVariant.filled);
      expect(button.onPressed, isNotNull);

      await tester.tap(pill(TeacherScheduleStrings.registerAttendance));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AttendanceQrScreen), findsOneWidget);
      expect(attendance.readCalls, [session.id]);
      // The production default: what the QR encodes is not confirmed, so no
      // token is asked for.
      expect(attendance.qrCalls, isEmpty);
    });

    group('through the schedule screen, with its real default rule', () {
      // `weekRepository`'s upcoming session: 2026-10-06, 14:00-17:00. Both
      // clocks are UTC instants hours before it ends in every time zone, so
      // the tap always opens the upcoming sheet; only the Ulaanbaatar date
      // differs. Nothing here passes a rule: a screen that stopped applying
      // `attendanceOpenOn` fails one case or the other.
      Future<FakeTeacherAttendanceRepository> openSheetAt(
        WidgetTester tester,
        DateTime now,
      ) async {
        final attendance = FakeTeacherAttendanceRepository(
          students: referenceRoster(),
        );
        useLogicalViewport(tester, const Size(393, 1400));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: TeacherScheduleScreen(
              repository: weekRepository(),
              attendanceRepository: attendance,
              clock: () => now,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel(upcomingLabel));
        await tester.pumpAndSettle();
        expect(find.byType(TeacherSessionSheet), findsOneWidget);
        return attendance;
      }

      testWidgets('on the session\'s date in Ulaanbaatar (09:00, the 6th): '
          'live, and it opens the QR screen', (tester) async {
        final attendance = await openSheetAt(
          tester,
          DateTime.utc(2026, 10, 6, 1),
        );
        expect(
          tester
              .widget<TeacherPillButton>(
                pill(TeacherScheduleStrings.registerAttendance),
              )
              .variant,
          TeacherPillVariant.filled,
        );
        await tester.tap(pill(TeacherScheduleStrings.registerAttendance));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AttendanceQrScreen), findsOneWidget);
        expect(attendance.readCalls, [41]);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('the day before (09:00, the 5th): disabled, opens nothing', (
        tester,
      ) async {
        final attendance = await openSheetAt(
          tester,
          DateTime.utc(2026, 10, 5, 1),
        );
        final button = tester.widget<TeacherPillButton>(
          pill(TeacherScheduleStrings.registerAttendance),
        );
        expect(button.variant, TeacherPillVariant.disabled);
        expect(button.onPressed, isNull);
        await tester.tap(pill(TeacherScheduleStrings.registerAttendance));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AttendanceQrScreen), findsNothing);
        expect(attendance.readCalls, isEmpty);
      });
    });

    testWidgets('any other day it stays disabled and opens nothing', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TeacherSessionSheet(
              entry: ScheduledSession(
                session: session,
                teacherClass: sampleClass(),
              ),
              held: false,
              repository: FakeTeacherScheduleRepository(),
            ),
          ),
        ),
      );
      final button = tester.widget<TeacherPillButton>(
        pill(TeacherScheduleStrings.registerAttendance),
      );
      expect(button.variant, TeacherPillVariant.disabled);
      await tester.tap(pill(TeacherScheduleStrings.registerAttendance));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AttendanceQrScreen), findsNothing);
    });
  });

  group('after a session ends, on its date (Issue #376)', () {
    final ended = sampleSession(id: 50, date: '2026-10-05');
    const counts = AttendanceCounts(
      present: 12,
      late: 2,
      absent: 9,
      excused: 1,
    );

    Future<(FakeTeacherScheduleRepository, FakeTeacherAttendanceRepository)>
    pumpSheet(
      WidgetTester tester, {
      required bool held,
      required bool attendanceOpen,
    }) async {
      final schedule = FakeTeacherScheduleRepository(
        attendance: {ended.id: counts},
      );
      final attendance = FakeTeacherAttendanceRepository(
        students: referenceRoster(),
      );
      await pumpApp(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TeacherSessionSheet(
              entry: ScheduledSession(
                session: ended,
                teacherClass: sampleClass(),
              ),
              held: held,
              repository: schedule,
              attendanceOpen: attendanceOpen,
              attendanceRepository: attendance,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (schedule, attendance);
    }

    testWidgets('ended, today: the summary stays and "Гар аргаар бүртгэх" '
        'opens manual attendance; the summary re-reads on return', (
      tester,
    ) async {
      final (schedule, attendance) = await pumpSheet(
        tester,
        held: true,
        attendanceOpen: true,
      );
      expect(find.byType(SessionAttendanceSummary), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(schedule.attendanceCalls, [ended.id]);
      // The QR path is not offered here.
      expect(
        find.text(TeacherScheduleStrings.registerAttendance),
        findsNothing,
      );

      await tester.tap(pill(TeacherAttendanceStrings.manualEntry));
      await tester.pumpAndSettle();
      expect(find.byType(ManualAttendanceScreen), findsOneWidget);
      expect(attendance.readCalls, [ended.id]);

      // Marking by hand stores, the success card returns to the sheet.
      await tester.tap(
        find.descendant(
          of: find.byType(AttendanceStudentRow).at(1),
          matching: find.byType(AttendanceStatusControl),
        ),
      );
      await tester.pump();
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pumpAndSettle();
      expect(attendance.markCalls, [(ended.id, 2, AttendanceStatus.present)]);
      await tester.tap(find.text('Ойлголоо'));
      await tester.pumpAndSettle();
      expect(find.byType(ManualAttendanceScreen), findsNothing);
      expect(find.byType(SessionAttendanceSummary), findsOneWidget);
      expect(schedule.attendanceCalls, [ended.id, ended.id]);
      // Never a QR token: QR stays the upcoming sheet's.
      expect(attendance.qrCalls, isEmpty);
    });

    testWidgets('ended, a previous date: the summary only — no manual action', (
      tester,
    ) async {
      await pumpSheet(tester, held: true, attendanceOpen: false);
      expect(find.byType(SessionAttendanceSummary), findsOneWidget);
      expect(find.text(TeacherAttendanceStrings.manualEntry), findsNothing);
      expect(
        find.text(TeacherScheduleStrings.registerAttendance),
        findsNothing,
      );
    });

    testWidgets('a future date: no summary, "Ирц бүртгэх" disabled, no manual '
        'action', (tester) async {
      await pumpSheet(tester, held: false, attendanceOpen: false);
      expect(find.byType(SessionAttendanceSummary), findsNothing);
      expect(find.text(TeacherAttendanceStrings.manualEntry), findsNothing);
      expect(
        tester
            .widget<TeacherPillButton>(
              pill(TeacherScheduleStrings.registerAttendance),
            )
            .variant,
        TeacherPillVariant.disabled,
      );
    });

    group('through the schedule screen, with its real default rule', () {
      // A 00:00-01:00 session on the 5th. At 14:00 UTC on the 5th it has
      // ended in every time zone (UTC-12 to UTC+14) and it is 22:00 on the
      // 5th in Ulaanbaatar; at 14:00 UTC on the 6th it is the next day there.
      // No rule is injected.
      final early = sampleSession(
        id: 51,
        date: '2026-10-05',
        start: (0, 0),
        end: (1, 0),
      );

      Future<void> openEndedSheetAt(WidgetTester tester, DateTime now) async {
        useLogicalViewport(tester, const Size(393, 1400));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: TeacherScheduleScreen(
              repository: FakeTeacherScheduleRepository(
                classes: [sampleClass()],
                sessions: {
                  2: [early],
                },
                attendance: {early.id: counts},
              ),
              attendanceRepository: FakeTeacherAttendanceRepository(
                students: referenceRoster(),
              ),
              clock: () => now,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final block = find.bySemanticsLabel('AI Engineer, 00:00-01:00');
        await tester.ensureVisible(block);
        await tester.pumpAndSettle();
        await tester.tap(block);
        await tester.pumpAndSettle();
        expect(find.byType(SessionAttendanceSummary), findsOneWidget);
      }

      testWidgets('ended earlier today in Ulaanbaatar: manual attendance is '
          'offered', (tester) async {
        await openEndedSheetAt(tester, DateTime.utc(2026, 10, 5, 14));
        await tester.tap(pill(TeacherAttendanceStrings.manualEntry));
        await tester.pumpAndSettle();
        expect(find.byType(ManualAttendanceScreen), findsOneWidget);
      });

      testWidgets('ended on a previous Ulaanbaatar date: it is not', (
        tester,
      ) async {
        await openEndedSheetAt(tester, DateTime.utc(2026, 10, 6, 14));
        expect(find.text(TeacherAttendanceStrings.manualEntry), findsNothing);
      });
    });
  });

  group('the QR screen\'s lifecycle', () {
    testWidgets('issues a token, re-issues it every 4 minutes, and polls the '
        'counts every 15 seconds; disposing stops both', (tester) async {
      final repo = FakeTeacherAttendanceRepository();
      await pumpApp(
        tester,
        AttendanceQrScreen(
          sessionId: 41,
          repository: repo,
          qrPayload: testPayload,
        ),
      );
      expect(repo.qrCalls, [41]);
      expect(repo.readCalls, [41]);
      expect(
        tester.widget<QrImageView>(find.byType(QrImageView)).key,
        const ValueKey('test-payload:token-1'),
      );

      await tester.pump(const Duration(seconds: 15));
      expect(repo.readCalls, hasLength(2));
      await tester.pump(const Duration(seconds: 15));
      expect(repo.readCalls, hasLength(3));

      await tester.pump(
        const Duration(minutes: 4) - const Duration(seconds: 30),
      );
      expect(repo.qrCalls, hasLength(2));
      expect(
        tester.widget<QrImageView>(find.byType(QrImageView)).key,
        const ValueKey('test-payload:token-2'),
      );

      await tester.pumpWidget(const SizedBox());
      final qr = repo.qrCalls.length;
      final reads = repo.readCalls.length;
      await tester.pump(const Duration(minutes: 10));
      expect(repo.qrCalls, hasLength(qr));
      expect(repo.readCalls, hasLength(reads));
    });

    testWidgets('session_not_today: says so, draws no code, stops asking', (
      tester,
    ) async {
      final repo = FakeTeacherAttendanceRepository()
        ..qrFailure = const TeacherFailure(
          TeacherFailureKind.rejected,
          code: 'session_not_today',
        );
      await pumpApp(
        tester,
        AttendanceQrScreen(
          sessionId: 41,
          repository: repo,
          qrPayload: testPayload,
        ),
      );
      expect(find.text(TeacherAttendanceStrings.qrNotToday), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      await tester.pump(const Duration(minutes: 6));
      expect(repo.qrCalls, [41]);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a refresh that fails keeps the code until it expires, then '
        'says so and offers a retry', (tester) async {
      final repo = FakeTeacherAttendanceRepository();
      await pumpApp(
        tester,
        AttendanceQrScreen(
          sessionId: 41,
          repository: repo,
          qrPayload: testPayload,
        ),
      );
      repo.qrFailure = const TeacherFailure(TeacherFailureKind.network);
      await tester.pump(const Duration(minutes: 4));
      expect(repo.qrCalls, hasLength(2));
      expect(find.byType(QrImageView), findsOneWidget);

      await tester.pump(const Duration(minutes: 1));
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text(TeacherAttendanceStrings.qrExpired), findsOneWidget);

      repo.qrFailure = null;
      await tester.tap(find.text('Дахин оролдох'));
      await tester.pump();
      expect(repo.qrCalls, hasLength(3));
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('until the payload is confirmed: no token is issued, the '
        'counts still poll, and manual entry is open', (tester) async {
      final repo = FakeTeacherAttendanceRepository();
      await pumpApp(
        tester,
        AttendanceQrScreen(sessionId: 41, repository: repo),
      );
      expect(find.text(TeacherAttendanceStrings.qrPending), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('14'), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      expect(repo.qrCalls, isEmpty);
      expect(repo.readCalls, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    });

    test('the production default encodes no QR', () {
      expect(attendanceQrPayload, isNull);
    });

    testWidgets('a counts read that fails before any arrive offers a retry', (
      tester,
    ) async {
      final repo = FakeTeacherAttendanceRepository()
        ..readFailure = const TeacherFailure(TeacherFailureKind.network);
      await pumpApp(
        tester,
        AttendanceQrScreen(sessionId: 41, repository: repo),
      );
      expect(find.text('Дахин оролдох'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the manual controller', () {
    Future<ManualAttendanceController> loaded(
      FakeTeacherAttendanceRepository repo,
    ) async {
      final controller = ManualAttendanceController(
        repository: repo,
        sessionId: 41,
      );
      await controller.load();
      return controller;
    }

    test('loads all four statuses as themselves; nothing changed', () async {
      final controller = await loaded(
        FakeTeacherAttendanceRepository(students: referenceRoster()),
      );
      expect(controller.rows!.map((r) => r.current).toSet(), {
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.late,
        AttendanceStatus.excused,
      });
      expect(controller.hasChanges, isFalse);
      expect(await controller.submit(), AttendanceSubmitResult.nothingSent);
    });

    test('sends only changed rows — unchanged late, excused and QR records '
        'are never written', () async {
      final repo = FakeTeacherAttendanceRepository(students: referenceRoster());
      final controller = await loaded(repo);
      final rows = controller.rows!;
      controller.choose(rows[1], AttendanceStatus.present); // absent → present
      controller.choose(rows[5], AttendanceStatus.absent); // present → absent
      controller.choose(rows[8], AttendanceStatus.excused); // absent → excused
      // Changed and changed back: nothing to send.
      controller.choose(rows[3], AttendanceStatus.present);
      controller.choose(rows[3], AttendanceStatus.absent);

      expect(await controller.submit(), AttendanceSubmitResult.allSaved);
      expect(repo.markCalls, [
        (41, 2, AttendanceStatus.present),
        (41, 6, AttendanceStatus.absent),
        (41, 9, AttendanceStatus.excused),
      ]);
      expect(controller.hasChanges, isFalse);
    });

    test('a partial failure keeps the stored rows and retries only the '
        'failed ones', () async {
      final repo = FakeTeacherAttendanceRepository(students: referenceRoster())
        ..failingStudents.add(6);
      final controller = await loaded(repo);
      final rows = controller.rows!;
      controller.choose(rows[1], AttendanceStatus.present);
      controller.choose(rows[5], AttendanceStatus.late);
      controller.choose(rows[8], AttendanceStatus.present);

      expect(await controller.submit(), AttendanceSubmitResult.someFailed);
      expect(controller.failedCount, 1);
      expect(rows[5].write, AttendanceWrite.failed);
      expect(rows[1].changed, isFalse);
      expect(rows[8].changed, isFalse);

      repo.failingStudents.clear();
      repo.markCalls.clear();
      expect(await controller.submit(), AttendanceSubmitResult.allSaved);
      expect(repo.markCalls, [(41, 6, AttendanceStatus.late)]);
      expect(controller.failedCount, 0);
    });

    test('a confirm while one runs sends nothing, and rows cannot change '
        'mid-write', () async {
      final repo = FakeTeacherAttendanceRepository(students: referenceRoster())
        ..markGate = Completer<void>();
      final controller = await loaded(repo);
      final rows = controller.rows!;
      controller.choose(rows[1], AttendanceStatus.present);

      final first = controller.submit();
      expect(controller.submitting, isTrue);
      expect(await controller.submit(), AttendanceSubmitResult.nothingSent);
      controller.choose(rows[2], AttendanceStatus.absent);
      expect(rows[2].changed, isFalse);

      repo.markGate!.complete();
      expect(await first, AttendanceSubmitResult.allSaved);
      expect(repo.markCalls, hasLength(1));
    });

    test('a failed load says why', () async {
      final controller = await loaded(
        FakeTeacherAttendanceRepository()
          ..readFailure = const TeacherFailure(TeacherFailureKind.server),
      );
      expect(controller.rows, isNull);
      expect(controller.errorMessage, isNotNull);
    });

    test('initials: the first letter of the first two words', () {
      expect(initialsOf('Болд Батаа'), 'ББ');
      expect(initialsOf('  Саруул   Батбаатар Х '), 'СБ');
      expect(initialsOf('Мөнхбат'), 'М');
    });
  });

  group('server changes before saving (Issue #378)', () {
    Future<(FakeTeacherAttendanceRepository, ManualAttendanceController)>
    loaded() async {
      final repo = FakeTeacherAttendanceRepository(students: referenceRoster());
      final controller = ManualAttendanceController(
        repository: repo,
        sessionId: 41,
      );
      await controller.load();
      return (repo, controller);
    }

    AttendanceRow rowOf(ManualAttendanceController c, int id) =>
        c.rows!.firstWhere((r) => r.student.studentId == id);

    test('a QR check-in after the roster loaded: that row is not sent, the '
        'others are; the roster is read again first', () async {
      final (repo, c) = await loaded();
      c.choose(rowOf(c, 2), AttendanceStatus.present); // absent → present
      c.choose(rowOf(c, 6), AttendanceStatus.absent); // present → absent
      repo.serverChange(2, AttendanceStatus.late, 'qr'); // student 2 scans

      expect(await c.submit(), AttendanceSubmitResult.conflicts);
      expect(repo.readCalls, [41, 41]);
      expect(repo.markCalls, [(41, 6, AttendanceStatus.absent)]);
      final conflict = rowOf(c, 2).conflict!;
      expect(conflict.status, AttendanceStatus.late);
      expect(conflict.method, 'qr');
      expect(rowOf(c, 2).current, AttendanceStatus.present);
      expect(c.canConfirm, isFalse);
      // A conflicted row cannot be edited past the decision.
      c.choose(rowOf(c, 2), AttendanceStatus.excused);
      expect(rowOf(c, 2).current, AttendanceStatus.present);
    });

    test('keep the server\'s value: the QR record stands, nothing is sent '
        'for it, and the confirm completes for the writes it made', () async {
      final (repo, c) = await loaded();
      c.choose(rowOf(c, 2), AttendanceStatus.present);
      c.choose(rowOf(c, 6), AttendanceStatus.absent);
      repo.serverChange(2, AttendanceStatus.late, 'qr');
      await c.submit();

      c.keepServer(rowOf(c, 2));
      expect(rowOf(c, 2).current, AttendanceStatus.late);
      expect(rowOf(c, 2).changed, isFalse);
      expect(await c.submit(), AttendanceSubmitResult.allSaved);
      expect(repo.markCalls, [(41, 6, AttendanceStatus.absent)]);
      expect(repo.students[1].status, AttendanceStatus.late);
      expect(repo.students[1].method, 'qr');
    });

    test('keeping the server\'s value when nothing else was written reports '
        'no success — there was no write', () async {
      final (repo, c) = await loaded();
      c.choose(rowOf(c, 2), AttendanceStatus.present);
      repo.serverChange(2, AttendanceStatus.late, 'qr');
      expect(await c.submit(), AttendanceSubmitResult.conflicts);
      c.keepServer(rowOf(c, 2));
      expect(await c.submit(), AttendanceSubmitResult.nothingSent);
      expect(repo.markCalls, isEmpty);
    });

    test(
      'apply my choice: sent on the next confirm, after another re-read',
      () async {
        final (repo, c) = await loaded();
        c.choose(rowOf(c, 2), AttendanceStatus.present);
        repo.serverChange(2, AttendanceStatus.late, 'qr');
        await c.submit();

        c.applyMine(rowOf(c, 2));
        expect(c.canConfirm, isTrue);
        expect(await c.submit(), AttendanceSubmitResult.allSaved);
        expect(repo.readCalls, hasLength(3));
        expect(repo.markCalls, [(41, 2, AttendanceStatus.present)]);
        expect(repo.students[1].method, 'manual');
      },
    );

    test('apply my choice, but the record moves again: a new conflict, '
        'still not sent', () async {
      final (repo, c) = await loaded();
      c.choose(rowOf(c, 2), AttendanceStatus.present);
      repo.serverChange(2, AttendanceStatus.late, 'qr');
      await c.submit();
      c.applyMine(rowOf(c, 2));
      repo.serverChange(2, AttendanceStatus.excused, 'manual');

      expect(await c.submit(), AttendanceSubmitResult.conflicts);
      expect(repo.markCalls, isEmpty);
      expect(rowOf(c, 2).conflict!.status, AttendanceStatus.excused);
    });

    test('a manual change by someone else is a conflict too', () async {
      final (repo, c) = await loaded();
      c.choose(rowOf(c, 5), AttendanceStatus.present); // late (qr) → present
      repo.serverChange(5, AttendanceStatus.excused, 'manual');
      expect(await c.submit(), AttendanceSubmitResult.conflicts);
      expect(repo.markCalls, isEmpty);
    });

    test('with a conflict and a failure: stored rows are never resent; the '
        'retry sends only the failed row and the resolved one', () async {
      final (repo, c) = await loaded();
      repo.failingStudents.add(6);
      c.choose(rowOf(c, 2), AttendanceStatus.present);
      c.choose(rowOf(c, 6), AttendanceStatus.absent);
      c.choose(rowOf(c, 9), AttendanceStatus.present);
      repo.serverChange(2, AttendanceStatus.late, 'qr');

      expect(await c.submit(), AttendanceSubmitResult.conflicts);
      expect(rowOf(c, 6).write, AttendanceWrite.failed);
      expect(rowOf(c, 9).changed, isFalse);

      repo
        ..failingStudents.clear()
        ..markCalls.clear();
      c.applyMine(rowOf(c, 2));
      expect(await c.submit(), AttendanceSubmitResult.allSaved);
      expect(repo.markCalls, [
        (41, 2, AttendanceStatus.present),
        (41, 6, AttendanceStatus.absent),
      ]);
    });

    test(
      'a write that landed though its answer was lost is not sent again',
      () async {
        final (repo, c) = await loaded();
        repo.failingStudents.add(2);
        c.choose(rowOf(c, 2), AttendanceStatus.present);
        expect(await c.submit(), AttendanceSubmitResult.someFailed);
        // It had reached the server after all.
        repo
          ..serverChange(2, AttendanceStatus.present, 'manual')
          ..failingStudents.clear()
          ..markCalls.clear();
        expect(await c.submit(), AttendanceSubmitResult.allSaved);
        expect(repo.markCalls, isEmpty);
      },
    );

    test('a failed re-read sends nothing and says so', () async {
      final (repo, c) = await loaded();
      c.choose(rowOf(c, 2), AttendanceStatus.present);
      repo.readFailure = const TeacherFailure(TeacherFailureKind.network);
      expect(await c.submit(), AttendanceSubmitResult.checkFailed);
      expect(repo.markCalls, isEmpty);
      expect(c.checkError, isNotNull);
      expect(c.submitting, isFalse);

      repo.readFailure = null;
      expect(await c.submit(), AttendanceSubmitResult.allSaved);
      expect(c.checkError, isNull);
      expect(repo.markCalls, [(41, 2, AttendanceStatus.present)]);
    });

    test('untouched rows show the server\'s latest after a confirm', () async {
      final (repo, c) = await loaded();
      c.choose(rowOf(c, 6), AttendanceStatus.absent);
      repo.serverChange(4, AttendanceStatus.late, 'qr');
      await c.submit();
      expect(rowOf(c, 4).current, AttendanceStatus.late);
      expect(rowOf(c, 4).changed, isFalse);
    });

    test('a changed student no longer on the roster is not sent', () async {
      final (repo, c) = await loaded();
      c.choose(rowOf(c, 2), AttendanceStatus.present);
      repo.students = [
        for (final s in repo.students)
          if (s.studentId != 2) s,
      ];
      expect(await c.submit(), AttendanceSubmitResult.someFailed);
      expect(repo.markCalls, isEmpty);
      expect(rowOf(c, 2).write, AttendanceWrite.failed);
    });
  });

  group('the manual screen', () {
    Future<FakeTeacherAttendanceRepository> openManualFromQr(
      WidgetTester tester, {
      double width = 393,
      double scale = 1,
    }) async {
      final repo = FakeTeacherAttendanceRepository(students: referenceRoster());
      await pumpApp(
        tester,
        AttendanceQrScreen(sessionId: 41, repository: repo),
        width: width,
        scale: scale,
      );
      await tester.tap(pill(TeacherAttendanceStrings.manualEntry));
      await tester.pumpAndSettle();
      expect(find.byType(ManualAttendanceScreen), findsOneWidget);
      return repo;
    }

    Finder control(String name) => find.descendant(
      of: find.ancestor(
        of: find.text(name),
        matching: find.byType(AttendanceStudentRow),
      ),
      matching: find.byType(AttendanceStatusControl),
    );

    testWidgets('lists the real roster; Баталгаажуулах waits for a change', (
      tester,
    ) async {
      await openManualFromQr(tester);
      expect(
        find.text(TeacherAttendanceStrings.studentsHeading),
        findsOneWidget,
      );
      expect(find.text('Болд Батаа'), findsOneWidget);
      // late and excused are named, not just coloured.
      expect(find.text('Хоцорсон'), findsOneWidget);
      expect(find.text('Чөлөөтэй'), findsOneWidget);
      expect(
        tester
            .widget<TeacherPillButton>(pill(TeacherAttendanceStrings.confirm))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('confirming shows "Амжилттай баталгаажлаа" only after the '
        'writes; Ойлголоо returns to the QR screen, which re-reads the count', (
      tester,
    ) async {
      final repo = await openManualFromQr(tester);
      repo.markGate = Completer<void>();
      await tester.tap(control('Саруул Батбаатар'));
      await tester.pump();
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pump();
      expect(find.text(TeacherAttendanceStrings.saving), findsOneWidget);
      expect(find.byType(TeacherConfirmationCard), findsNothing);

      repo.markGate!.complete();
      await tester.pumpAndSettle();
      expect(repo.markCalls, [(41, 2, AttendanceStatus.present)]);
      expect(find.text('Амжилттай баталгаажлаа'), findsOneWidget);

      final readsBefore = repo.readCalls.length;
      await tester.tap(find.text('Ойлголоо'));
      await tester.pumpAndSettle();
      expect(find.byType(ManualAttendanceScreen), findsNothing);
      expect(find.byType(AttendanceQrScreen), findsOneWidget);
      expect(repo.readCalls.length, greaterThan(readsBefore));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failed row is named and retried alone; no success card '
        'until it is stored', (tester) async {
      final repo = await openManualFromQr(tester);
      repo.failingStudents.add(9);
      await tester.tap(control('Саруул Батбаатар'));
      await tester.ensureVisible(control('Мөнхбат Даваасүрэн'));
      await tester.pumpAndSettle();
      await tester.tap(control('Мөнхбат Даваасүрэн'));
      await tester.pump();
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pumpAndSettle();
      expect(find.text(TeacherAttendanceStrings.failedRows(1)), findsOneWidget);
      expect(find.text(TeacherAttendanceStrings.saveFailed), findsOneWidget);
      expect(find.byType(TeacherConfirmationCard), findsNothing);

      repo.failingStudents.clear();
      repo.markCalls.clear();
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pumpAndSettle();
      expect(repo.markCalls, [(41, 9, AttendanceStatus.present)]);
      expect(find.text('Амжилттай баталгаажлаа'), findsOneWidget);
      await tester.tap(find.text('Ойлголоо'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('back is held while a write is in flight — the back button '
        'and the system gesture — and open again once it finishes', (
      tester,
    ) async {
      final repo = await openManualFromQr(tester);
      repo
        ..markGate = Completer<void>()
        ..failingStudents.add(2);
      await tester.tap(control('Саруул Батбаатар'));
      await tester.pump();
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pump();
      expect(find.text(TeacherAttendanceStrings.saving), findsOneWidget);

      // The saving spinner never settles: pump through a page transition's
      // length instead.
      const transition = Duration(milliseconds: 600);
      // The circle itself: AppBackButton's box spans the row, so its centre
      // is the title, not the button.
      final manualBack = find.descendant(
        of: find.descendant(
          of: find.byType(ManualAttendanceScreen),
          matching: find.byType(AppBackButton),
        ),
        matching: find.byType(InkWell),
      );
      // The app's back button.
      await tester.tap(manualBack);
      await tester.pump();
      await tester.pump(transition);
      expect(find.byType(ManualAttendanceScreen), findsOneWidget);
      // The system back (Android button, iOS edge swipe's route pop).
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(transition);
      expect(find.byType(ManualAttendanceScreen), findsOneWidget);
      // The write was not cancelled: it is still the one call, in flight.
      expect(repo.markCalls, [(41, 2, AttendanceStatus.present)]);

      // It finishes — failed here, so no success card — and back works.
      repo.markGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(TeacherAttendanceStrings.failedRows(1)), findsOneWidget);
      expect(find.byType(TeacherConfirmationCard), findsNothing);
      await tester.tap(manualBack);
      await tester.pumpAndSettle();
      expect(find.byType(ManualAttendanceScreen), findsNothing);
      expect(find.byType(AttendanceQrScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a QR scan after loading: the sheet shows the server\'s '
        'record and the teacher\'s choice; keeping the server sends nothing '
        'and shows no success', (tester) async {
      final repo = await openManualFromQr(tester);
      await tester.tap(control('Саруул Батбаатар'));
      await tester.pump();
      repo.serverChange(2, AttendanceStatus.late, 'qr');
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceConflictSheet), findsOneWidget);
      expect(find.text('Серверт: Хоцорсон (QR)'), findsWidgets);
      expect(find.text('Таны сонголт: Ирсэн'), findsWidgets);
      await tester.tap(find.text('Серверийнхийг үлдээх: Хоцорсон'));
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceConflictSheet), findsNothing);
      expect(repo.markCalls, isEmpty);
      expect(find.byType(TeacherConfirmationCard), findsNothing);
      // The row now shows the server's late.
      expect(find.text('Хоцорсон'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('applying the teacher\'s choice sends it and then shows '
        'success', (tester) async {
      final repo = await openManualFromQr(tester);
      await tester.tap(control('Саруул Батбаатар'));
      await tester.pump();
      repo.serverChange(2, AttendanceStatus.late, 'qr');
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Миний сонголтыг хадгалах: Ирсэн'));
      await tester.pumpAndSettle();

      expect(repo.markCalls, [(41, 2, AttendanceStatus.present)]);
      expect(find.text('Амжилттай баталгаажлаа'), findsOneWidget);
      await tester.tap(find.text('Ойлголоо'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('dismissing the sheet decides nothing: the row stays flagged, '
        'confirm waits, and tapping the row asks again', (tester) async {
      final repo = await openManualFromQr(tester);
      await tester.tap(control('Саруул Батбаатар'));
      await tester.pump();
      repo.serverChange(2, AttendanceStatus.late, 'qr');
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(196, 100));
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceConflictSheet), findsNothing);
      expect(
        find.text(TeacherAttendanceStrings.conflictsPending(1)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TeacherPillButton>(pill(TeacherAttendanceStrings.confirm))
            .onPressed,
        isNull,
      );
      expect(repo.markCalls, isEmpty);

      await tester.tap(find.text('Саруул Батбаатар'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceConflictSheet), findsOneWidget);
      await tester.tap(find.text('Миний сонголтыг хадгалах: Ирсэн'));
      await tester.pumpAndSettle();
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pumpAndSettle();
      expect(repo.markCalls, [(41, 2, AttendanceStatus.present)]);
      expect(find.text('Амжилттай баталгаажлаа'), findsOneWidget);
      await tester.tap(find.text('Ойлголоо'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failed re-read: nothing sent, the reason shown, confirm '
        'can be tried again', (tester) async {
      final repo = await openManualFromQr(tester);
      await tester.tap(control('Саруул Батбаатар'));
      await tester.pump();
      repo.readFailure = const TeacherFailure(TeacherFailureKind.network);
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pumpAndSettle();
      expect(repo.markCalls, isEmpty);
      expect(
        find.textContaining('Сүүлийн ирцийг шалгаж чадсангүй'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TeacherPillButton>(pill(TeacherAttendanceStrings.confirm))
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a late student\'s control opens the four statuses — never '
        'flipped silently', (tester) async {
      final repo = await openManualFromQr(tester);
      await tester.tap(control('Анхбаяр Болд'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceStatusPicker), findsOneWidget);
      await tester.tap(find.text('Чөлөөтэй').last);
      await tester.pumpAndSettle();
      await tester.tap(pill(TeacherAttendanceStrings.confirm));
      await tester.pumpAndSettle();
      expect(repo.markCalls, [(41, 5, AttendanceStatus.excused)]);
      await tester.tap(find.text('Ойлголоо'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('layout', () {
    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets('${width.toInt()} wide, text ×$scale: the QR and manual '
            'screens and the success card lay out without overflow', (
          tester,
        ) async {
          final repo = FakeTeacherAttendanceRepository(
            students: referenceRoster(),
          );
          expect(
            await pumpApp(
              tester,
              AttendanceQrScreen(
                sessionId: 41,
                repository: repo,
                qrPayload: testPayload,
              ),
              width: width,
              scale: scale,
            ),
            isEmpty,
          );
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details.toString());
          try {
            await tester.tap(pill(TeacherAttendanceStrings.manualEntry));
            await tester.pumpAndSettle();
            await tester.tap(
              find.descendant(
                of: find.byType(AttendanceStudentRow).first,
                matching: find.byType(AttendanceStatusControl),
              ),
            );
            await tester.pump();
            await tester.tap(pill(TeacherAttendanceStrings.confirm));
            await tester.pumpAndSettle();
            expect(find.byType(TeacherConfirmationCard), findsOneWidget);
          } finally {
            FlutterError.onError = previous;
          }
          expect(errors, isEmpty);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });

  group('the conflict sheet\'s layout', () {
    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets('${width.toInt()} wide, text ×$scale: no overflow', (
          tester,
        ) async {
          expect(
            await pumpApp(
              tester,
              const Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: AttendanceConflictSheet(
                    name: 'Доржпалам Сүхбаатар',
                    conflict: AttendanceConflict(
                      status: AttendanceStatus.late,
                      method: 'qr',
                    ),
                    mine: AttendanceStatus.present,
                  ),
                ),
              ),
              width: width,
              scale: scale,
            ),
            isEmpty,
          );
        });
      }
    }
  });

  group('goldens, against the three references', () {
    testWidgets('QR attendance (test payload — the real one is unconfirmed)', (
      tester,
    ) async {
      await pumpApp(
        tester,
        AttendanceQrScreen(
          sessionId: 41,
          repository: FakeTeacherAttendanceRepository(),
          qrPayload: testPayload,
        ),
        height: 946,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/teacher_attendance_qr.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('QR attendance as shipped: payload awaiting confirmation', (
      tester,
    ) async {
      await pumpApp(
        tester,
        AttendanceQrScreen(
          sessionId: 41,
          repository: FakeTeacherAttendanceRepository(),
        ),
        height: 946,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/teacher_attendance_qr_pending.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });

    for (final width in [320.0, 393.0]) {
      testWidgets('manual attendance, ${width.toInt()} wide', (tester) async {
        final repo = FakeTeacherAttendanceRepository(
          students: referenceRoster(),
        );
        await pumpApp(
          tester,
          ManualAttendanceScreen(sessionId: 41, repository: repo),
          width: width,
          height: 969,
        );
        // One change, so "Баталгаажуулах" is live as the reference draws it.
        await tester.tap(
          find.descendant(
            of: find.byType(AttendanceStudentRow).at(1),
            matching: find.byType(AttendanceStatusControl),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/teacher_attendance_manual_${width.toInt()}.png',
          ),
        );
      });
    }

    testWidgets('the success card', (tester) async {
      const page = Key('page');
      await pumpApp(tester, const Scaffold(body: SizedBox.expand(key: page)));
      unawaited(showAttendanceSavedCard(tester.element(find.byKey(page))));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/teacher_attendance_saved.png'),
      );
    });
  });
}
