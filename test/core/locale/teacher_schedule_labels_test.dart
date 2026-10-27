import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/incoming_request_sheet.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_attendance_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_day_session_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/teacher/fake_schedule_change_repository.dart';
import '../../features/teacher/fake_teacher_schedule_repository.dart';
import '../../features/teacher/teacher_home_screen_test.dart'
    show sampleClass, tuesday;
import '../../support/screenshot.dart';

/// Issue #547 (L17): Teacher Schedule, its session sheets, "Багш нар" and
/// the time-change request sheets in the selected language. Mongolian reads
/// exactly as before. Fakes stand in for the API — no network, no real
/// request or attendance; the names are made-up fixtures.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// Every key, its Mongolian exactly as Teacher Schedule showed it before,
  /// and the approved English.
  const copy = <String, ({String mongolian, String english})>{
    'teacherHomeEmpty': (
      mongolian: 'Одоогоор хичээл алга байна',
      english: 'No classes yet',
    ),
    'teacherSchedulePickDate': (
      mongolian: 'Огноо сонгох',
      english: 'Choose a date',
    ),
    'teacherScheduleEmptyDay': (
      mongolian: 'Энэ өдөр хичээл байхгүй байна.',
      english: 'No classes on this day.',
    ),
    'teacherSchedulePreviousDay': (
      mongolian: 'Өмнөх өдөр',
      english: 'Previous day',
    ),
    'teacherScheduleNextDay': (
      mongolian: 'Дараагийн өдөр',
      english: 'Next day',
    ),
    'teacherScheduleFinished': (mongolian: 'Дууссан', english: 'Finished'),
    'teacherScheduleChangeTime': (
      mongolian: 'Цаг солих',
      english: 'Change time',
    ),
    'teacherScheduleTakeAttendance': (
      mongolian: 'Ирц бүртгэх',
      english: 'Take attendance',
    ),
    'teacherScheduleAttendedCaption': (
      mongolian: 'оюутан ирцэд бүртгэгдсэн',
      english: 'students checked in',
    ),
    'teacherClassRoom': (mongolian: 'Анги', english: 'Room'),
    'teacherClassTime': (mongolian: 'Цаг', english: 'Time'),
    'teacherRequestTeachersTitle': (mongolian: 'Багш нар', english: 'Teachers'),
    'teacherRequestSend': (mongolian: 'Хүсэлт илгээх', english: 'Send request'),
    'teacherRequestPending': (mongolian: 'Хүлээгдэж байна', english: 'Pending'),
    'teacherRequestDeclined': (mongolian: 'Татгалзсан', english: 'Declined'),
    'teacherRequestsEmpty': (
      mongolian: 'Энэ цагт орлон заах боломжтой багш алга',
      english: 'No teacher is available to cover at this time',
    ),
    'teacherRequestsUnavailable': (
      mongolian:
          'Одоогоор цаг солих хүсэлт илгээх боломжгүй байна. Дараа дахин '
          'оролдоно уу.',
      english:
          "Time-change requests can't be sent right now. Please try again "
          'later.',
    ),
    'teacherRequestDecline': (mongolian: 'Татгалзах', english: 'Decline'),
    'teacherRequestAccept': (mongolian: 'Зөвшөөрөх', english: 'Accept'),
    'teacherRequestSentTitle': (
      mongolian: 'Хүсэлт илгээгдлээ',
      english: 'Request sent',
    ),
    'teacherConfirmationDismiss': (mongolian: 'Ойлголоо', english: 'Got it'),
    'teacherSessionUntitled': (mongolian: 'Хичээл', english: 'Class'),
    'teacherSessionCovering': (mongolian: 'Орлон заах', english: 'Covering'),
    'teacherSessionCovered': (mongolian: 'Орлон заагдсан', english: 'Covered'),
    'teacherRequestAccepted': (
      mongolian: 'Хүсэлтийг зөвшөөрсөн',
      english: 'Request accepted',
    ),
    'teacherRequestRejected': (
      mongolian: 'Хүсэлтээс татгалзсан',
      english: 'Request declined',
    ),
    'teacherRequestCancelled': (
      mongolian: 'Хүсэлт цуцлагдсан',
      english: 'Request cancelled',
    ),
    'teacherRequestExpired': (
      mongolian: 'Хүсэлтийн хугацаа дууссан',
      english: 'Request expired',
    ),
    'teacherRequestRecipientBusy': (
      mongolian: 'Энэ багш тухайн цагт өөр хичээлтэй байна',
      english: 'This teacher has another class at that time',
    ),
    'teacherRequestAlreadyPending': (
      mongolian: 'Энэ хичээлд илгээсэн хүсэлт хүлээгдэж байна',
      english: 'A request for this class is already pending',
    ),
    'teacherRequestSessionCovered': (
      mongolian: 'Энэ хичээлийг өөр багш орлон заахаар болсон байна',
      english: 'Another teacher is already covering this class',
    ),
    'teacherRequestSessionStarted': (
      mongolian: 'Хичээл эхэлсэн тул цаг солих боломжгүй',
      english: "This class has started, so its time can't be changed",
    ),
    'teacherRequestSessionNotFound': (
      mongolian: 'Хичээл олдсонгүй',
      english: 'Class not found',
    ),
    'teacherRequestRecipientNotFound': (
      mongolian: 'Багш олдсонгүй',
      english: 'Teacher not found',
    ),
    'teacherRequestScheduleConflict': (
      mongolian: 'Тухайн цагт танд өөр хичээл байгаа тул зөвшөөрөх боломжгүй',
      english: "You have another class at that time, so you can't accept",
    ),
    'teacherRequestAlreadyResolved': (
      mongolian: 'Хүсэлт аль хэдийн шийдвэрлэгдсэн байна',
      english: 'This request has already been resolved',
    ),
    'teacherRequestNotFound': (
      mongolian: 'Хүсэлт олдсонгүй',
      english: 'Request not found',
    ),
    'teacherRequestNotRecipient': (
      mongolian: 'Энэ хүсэлтэд хариулах эрх танд алга',
      english: "You don't have permission to answer this request",
    ),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;
  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);

  /// "Covered · [name]", with the name as the server sent it.
  String coveredBy(String name, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? 'Орлон заагдсан · $name'
      : 'Covered · $name';

  /// The ten documented refusals, each code with its key.
  const codes = [
    ('recipient_busy', 'teacherRequestRecipientBusy'),
    ('request_pending', 'teacherRequestAlreadyPending'),
    ('session_already_covered', 'teacherRequestSessionCovered'),
    ('session_started', 'teacherRequestSessionStarted'),
    ('session_not_found', 'teacherRequestSessionNotFound'),
    ('recipient_not_found', 'teacherRequestRecipientNotFound'),
    ('schedule_conflict', 'teacherRequestScheduleConflict'),
    ('request_already_resolved', 'teacherRequestAlreadyResolved'),
    ('request_not_found', 'teacherRequestNotFound'),
    ('not_recipient', 'teacherRequestNotRecipient'),
  ];

  TeacherFailure refused(String? code) =>
      TeacherFailure(TeacherFailureKind.rejected, code: code);

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final s = L10n.of(language);
        expect(
          {
            'teacherHomeEmpty': s.teacherHomeEmpty,
            'teacherSchedulePickDate': s.teacherSchedulePickDate,
            'teacherScheduleEmptyDay': s.teacherScheduleEmptyDay,
            'teacherSchedulePreviousDay': s.teacherSchedulePreviousDay,
            'teacherScheduleNextDay': s.teacherScheduleNextDay,
            'teacherScheduleFinished': s.teacherScheduleFinished,
            'teacherScheduleChangeTime': s.teacherScheduleChangeTime,
            'teacherScheduleTakeAttendance': s.teacherScheduleTakeAttendance,
            'teacherScheduleAttendedCaption': s.teacherScheduleAttendedCaption,
            'teacherClassRoom': s.teacherClassRoom,
            'teacherClassTime': s.teacherClassTime,
            'teacherRequestTeachersTitle': s.teacherRequestTeachersTitle,
            'teacherRequestSend': s.teacherRequestSend,
            'teacherRequestPending': s.teacherRequestPending,
            'teacherRequestDeclined': s.teacherRequestDeclined,
            'teacherRequestsEmpty': s.teacherRequestsEmpty,
            'teacherRequestsUnavailable': s.teacherRequestsUnavailable,
            'teacherRequestDecline': s.teacherRequestDecline,
            'teacherRequestAccept': s.teacherRequestAccept,
            'teacherRequestSentTitle': s.teacherRequestSentTitle,
            'teacherConfirmationDismiss': s.teacherConfirmationDismiss,
            'teacherSessionUntitled': s.teacherSessionUntitled,
            'teacherSessionCovering': s.teacherSessionCovering,
            'teacherSessionCovered': s.teacherSessionCovered,
            'teacherRequestAccepted': s.teacherRequestAccepted,
            'teacherRequestRejected': s.teacherRequestRejected,
            'teacherRequestCancelled': s.teacherRequestCancelled,
            'teacherRequestExpired': s.teacherRequestExpired,
            'teacherRequestRecipientBusy': s.teacherRequestRecipientBusy,
            'teacherRequestAlreadyPending': s.teacherRequestAlreadyPending,
            'teacherRequestSessionCovered': s.teacherRequestSessionCovered,
            'teacherRequestSessionStarted': s.teacherRequestSessionStarted,
            'teacherRequestSessionNotFound': s.teacherRequestSessionNotFound,
            'teacherRequestRecipientNotFound':
                s.teacherRequestRecipientNotFound,
            'teacherRequestScheduleConflict': s.teacherRequestScheduleConflict,
            'teacherRequestAlreadyResolved': s.teacherRequestAlreadyResolved,
            'teacherRequestNotFound': s.teacherRequestNotFound,
            'teacherRequestNotRecipient': s.teacherRequestNotRecipient,
          },
          {for (final key in copy.keys) key: text(key, language)},
        );
        // The placeholder: the covering teacher's name, inserted as sent.
        for (final name in ['Анар Бат', 'Ann Lee', ' Bold ']) {
          expect(s.teacherSessionCoveredBy(name), coveredBy(name, language));
        }
      });

      test('the strings classes in ${language.name}', () async {
        await locale.setPreference(language);
        String t(String key) => text(key, language);

        expect(TeacherScheduleStrings.pickDate, t('teacherSchedulePickDate'));
        expect(TeacherScheduleStrings.empty, t('teacherHomeEmpty'));
        expect(TeacherScheduleStrings.emptyDay, t('teacherScheduleEmptyDay'));
        expect(
          TeacherScheduleStrings.previousDay,
          t('teacherSchedulePreviousDay'),
        );
        expect(TeacherScheduleStrings.nextDay, t('teacherScheduleNextDay'));
        expect(TeacherScheduleStrings.finished, t('teacherScheduleFinished'));
        expect(
          TeacherScheduleStrings.changeTime,
          t('teacherScheduleChangeTime'),
        );
        expect(
          TeacherScheduleStrings.registerAttendance,
          t('teacherScheduleTakeAttendance'),
        );
        expect(
          TeacherScheduleStrings.attendedCaption,
          t('teacherScheduleAttendedCaption'),
        );
        expect(
          TeacherScheduleStrings.teachersTitle,
          t('teacherRequestTeachersTitle'),
        );
        expect(TeacherScheduleStrings.requestSend, t('teacherRequestSend'));
        expect(
          TeacherScheduleStrings.requestPending,
          t('teacherRequestPending'),
        );
        expect(
          TeacherScheduleStrings.requestRejected,
          t('teacherRequestDeclined'),
        );
        expect(TeacherScheduleStrings.requestsEmpty, t('teacherRequestsEmpty'));
        expect(
          TeacherScheduleStrings.requestsUnavailable,
          t('teacherRequestsUnavailable'),
        );
        expect(
          TeacherScheduleStrings.requestDecline,
          t('teacherRequestDecline'),
        );
        expect(TeacherScheduleStrings.requestAccept, t('teacherRequestAccept'));
        expect(
          TeacherScheduleStrings.requestSentTitle,
          t('teacherRequestSentTitle'),
        );
        expect(
          TeacherScheduleStrings.requestSentDismiss,
          t('teacherConfirmationDismiss'),
        );
        expect(
          TeacherScheduleStrings.incomingUntitled,
          t('teacherSessionUntitled'),
        );
        expect(TeacherScheduleStrings.covering, t('teacherSessionCovering'));
        // Blank names read as "covered", with no name.
        for (final blank in ['', '  ']) {
          expect(
            TeacherScheduleStrings.coveredBy(blank),
            t('teacherSessionCovered'),
          );
        }
        expect(
          TeacherScheduleStrings.coveredBy('Анар Бат'),
          coveredBy('Анар Бат', language),
        );
        // The covering and covered labels, as a session carries them.
        expect(
          TeacherScheduleStrings.assignmentLabel(
            ScheduledSession(
              session: sampleSession(id: 1, date: '2026-10-06'),
              teacherClass: sampleClass(),
              coveredBy: 'Анар Бат',
            ),
          ),
          coveredBy('Анар Бат', language),
        );
        expect(
          TeacherScheduleStrings.sessionTitle(
            ScheduledSession.covering(
              session: sampleSession(id: 1, date: '2026-10-06'),
              covering: const CoveringSession(requestId: 1),
            ),
          ),
          t('teacherSessionUntitled'),
        );

        // The four resolved statuses; none while pending.
        for (final (status, key) in [
          ('accepted', 'teacherRequestAccepted'),
          ('rejected', 'teacherRequestRejected'),
          ('cancelled', 'teacherRequestCancelled'),
          ('expired', 'teacherRequestExpired'),
        ]) {
          expect(
            TeacherScheduleStrings.incomingStatus(status),
            t(key),
            reason: status,
          );
        }
        expect(TeacherScheduleStrings.incomingStatus('pending'), isNull);

        // The ten codes, the code-less refusal, and the shared lines.
        for (final (code, key) in codes) {
          expect(
            TeacherScheduleStrings.requestFailure(refused(code)),
            t(key),
            reason: code,
          );
        }
        expect(
          TeacherScheduleStrings.requestFailure(refused(null)),
          t('teacherRequestsUnavailable'),
        );
        expect(
          TeacherScheduleStrings.requestFailure(
            const TeacherFailure(TeacherFailureKind.network),
          ),
          TeacherHomeStrings.messageFor(TeacherFailureKind.network),
        );

        // What Schedule reuses from Teacher Home.
        expect(TeacherHomeStrings.room, t('teacherClassRoom'));
        expect(TeacherHomeStrings.time, t('teacherClassTime'));
        expect(TeacherHomeStrings.empty, t('teacherHomeEmpty'));
        // Gradebook's empty line is the same key (approved, ahead of L19).
        expect(TeacherGradebookStrings.empty, t('teacherHomeEmpty'));

        // English in both languages, unchanged.
        expect(TeacherScheduleStrings.teacherRole, 'Teacher');
        expect(TeacherHomeStrings.students(24), '24 Students');
        // Attendance registration keeps its Mongolian until its own Issue.
        expect(TeacherAttendanceStrings.successDismiss, 'Ойлголоо');
        expect(TeacherAttendanceStrings.successTitle, 'Амжилттай баталгаажлаа');
      });
    }
  });

  // --- Pumps --------------------------------------------------------------

  /// [home] under the language rebuild scope, as the app root draws it.
  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(393, 1400),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    // A fresh tree: nothing carried over from an earlier pump.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(theme: AppTheme.light, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The teacher's week of 4–10 October 2026, seen on Tuesday 6 October:
  /// Monday's 09:00–12:00 is held (41 of 24 recorded), Tuesday's 14:00–17:00
  /// is ahead; plus [assigned].
  FakeTeacherScheduleRepository week({
    List<AssignedSession> assigned = const [],
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
  );

  Widget schedule(FakeTeacherScheduleRepository repository) =>
      TeacherScheduleScreen(
        repository: repository,
        clock: tuesday,
        scheduleChangeRepository: FakeScheduleChangeRepository(
          teachers: sampleEligibleTeachers,
        ),
        showBottomNav: false,
      );

  /// A session this teacher covers on Thursday, whose title's first word
  /// does not fit a week-grid column at 2.0× text: the screen shows the day
  /// list in either language (Issue #357), not only where the weekday row
  /// no longer fits.
  final thursdayCover = AssignedSession.covering(
    sessionId: 88,
    session: sampleSession(
      id: 88,
      cohortId: 9,
      date: '2026-10-08',
      start: (9, 0),
      end: (10, 0),
    ),
    covering: const CoveringSession(
      requestId: 13,
      courseTitle: 'Corporate Leaders',
    ),
  );

  /// [repository]'s schedule at 2.0× text on a 320 pt phone, as the day list.
  Future<void> pumpDayList(
    WidgetTester tester,
    FakeTeacherScheduleRepository repository,
  ) async {
    await pumpApp(tester, schedule(repository), size: const Size(320, 2400));
    expect(find.byType(TeacherDaySessionList), findsOneWidget);
  }

  /// Tuesday's own session covered by another teacher, and a session this
  /// teacher covers on the same day.
  final coveredWeek = [
    const AssignedSession.regular(sessionId: 41, coveredBy: 'Анар Бат'),
    AssignedSession.covering(
      sessionId: 77,
      session: sampleSession(
        id: 77,
        cohortId: 9,
        date: '2026-10-06',
        start: (9, 0),
        end: (10, 0),
      ),
      covering: const CoveringSession(
        requestId: 12,
        courseTitle: 'Corporate Leaders',
        cohortName: 'CL-2026-10',
      ),
    ),
  ];

  Widget changeScreen(FakeScheduleChangeRepository repository) =>
      TeacherScheduleChangeScreen(sessionId: 41, repository: repository);

  /// A screen with one button that opens incoming request 12.
  Widget incoming(FakeScheduleChangeRepository repository) => Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showIncomingScheduleChangeRequest(
            context,
            requestId: 12,
            repository: repository,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );

  Future<void> openIncoming(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // --- A language change ----------------------------------------------------

  group('a language change', () {
    testWidgets('redraws the open session sheet at once, keeping the screen '
        'and its sheet', (tester) async {
      final repository = week();
      await pumpApp(tester, schedule(repository));
      await tester.tap(find.bySemanticsLabel('AI Engineer, 14:00-17:00'));
      await tester.pumpAndSettle();
      expect(find.text(mn('teacherScheduleChangeTime')), findsOneWidget);
      expect(find.text(mn('teacherScheduleTakeAttendance')), findsOneWidget);
      final state = tester.state(find.byType(TeacherScheduleScreen));
      final loads = repository.classCalls;

      await locale.setEnglish(true);
      await tester.pumpAndSettle();

      expect(find.text(en('teacherScheduleChangeTime')), findsOneWidget);
      expect(find.text(en('teacherScheduleTakeAttendance')), findsOneWidget);
      expect(find.text(mn('teacherScheduleChangeTime')), findsNothing);
      expect(find.text('24 Students'), findsOneWidget);
      expect(tester.state(find.byType(TeacherScheduleScreen)), same(state));
      expect(repository.classCalls, loads);

      await locale.setEnglish(false);
      await tester.pumpAndSettle();
      expect(find.text(mn('teacherScheduleChangeTime')), findsOneWidget);
    });

    testWidgets('redraws the held sheet\'s caption and the empty week', (
      tester,
    ) async {
      await pumpApp(tester, schedule(week()));
      await tester.tap(find.bySemanticsLabel('AI Engineer, 09:00-12:00'));
      await tester.pumpAndSettle();
      expect(find.text(mn('teacherScheduleAttendedCaption')), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pumpAndSettle();
      expect(find.text(en('teacherScheduleAttendedCaption')), findsOneWidget);

      await pumpApp(
        tester,
        schedule(FakeTeacherScheduleRepository(classes: [sampleClass()])),
      );
      expect(find.text(en('teacherHomeEmpty')), findsOneWidget);
      await locale.setEnglish(false);
      await tester.pumpAndSettle();
      expect(find.text(mn('teacherHomeEmpty')), findsOneWidget);
    });

    testWidgets('redraws the covering and covered labels', (tester) async {
      // The day list draws both labels in words.
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpDayList(tester, week(assigned: coveredWeek));
      expect(
        find.text(coveredBy('Анар Бат', LocalePreference.mongolian)),
        findsWidgets,
      );
      expect(find.text(mn('teacherSessionCovering')), findsWidgets);

      await locale.setEnglish(true);
      await tester.pumpAndSettle();
      expect(
        find.text(coveredBy('Анар Бат', LocalePreference.english)),
        findsWidgets,
      );
      expect(find.text(en('teacherSessionCovering')), findsWidgets);
      expect(find.text(mn('teacherSessionCovering')), findsNothing);
    });

    testWidgets('"Change time" → "Teachers": the rows, then the sent card, '
        'in the language chosen', (tester) async {
      await pumpApp(tester, schedule(week()));
      await tester.tap(find.bySemanticsLabel('AI Engineer, 14:00-17:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mn('teacherScheduleChangeTime')));
      await tester.pumpAndSettle();
      expect(find.text(mn('teacherRequestTeachersTitle')), findsOneWidget);
      expect(find.text(mn('teacherRequestSend')), findsNWidgets(2));

      await locale.setEnglish(true);
      await tester.pumpAndSettle();
      expect(find.text(en('teacherRequestTeachersTitle')), findsOneWidget);
      expect(find.text(en('teacherRequestSend')), findsNWidgets(2));
      expect(find.text('Teacher'), findsNWidgets(2));

      await tester.tap(find.text(en('teacherRequestSend')).first);
      await tester.pumpAndSettle();
      expect(find.text(en('teacherRequestSentTitle')), findsOneWidget);
      expect(find.text(en('teacherConfirmationDismiss')), findsOneWidget);
      await tester.tap(find.text(en('teacherConfirmationDismiss')));
      await tester.pumpAndSettle();
      expect(find.text(en('teacherRequestPending')), findsOneWidget);
    });

    testWidgets('the incoming sheet: its actions switch; a refusal already '
        'shown keeps its language until the next answer', (tester) async {
      final repository = FakeScheduleChangeRepository(
        request: sampleIncomingRequest(),
        decisionFailure: refused('schedule_conflict'),
      );
      await pumpApp(tester, incoming(repository));
      await openIncoming(tester);
      await tester.tap(find.text(mn('teacherRequestAccept')));
      await tester.pumpAndSettle();
      expect(find.text(mn('teacherRequestScheduleConflict')), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pumpAndSettle();
      // Drawn now: switched.
      expect(find.text(en('teacherRequestDecline')), findsOneWidget);
      expect(find.text(en('teacherRequestAccept')), findsOneWidget);
      // Stored when the answer failed: unchanged until the next answer.
      expect(find.text(mn('teacherRequestScheduleConflict')), findsOneWidget);

      repository.decisionFailure = null;
      await tester.tap(find.text(en('teacherRequestDecline')));
      await tester.pumpAndSettle();
      expect(find.text(en('teacherRequestRejected')), findsOneWidget);
      expect(find.text(mn('teacherRequestScheduleConflict')), findsNothing);
    });
  });

  // --- Large text -------------------------------------------------------------

  const width = 320.0;
  const height = 2400.0;
  const size = Size(width, height);

  /// Each state: how to reach it, and the labels it draws by language.
  final states =
      <
        ({
          String name,
          Future<void> Function(WidgetTester) reach,
          List<String Function(LocalePreference)> labels,
        })
      >[
        (
          name: 'Schedule, a day with no class',
          reach: (tester) => pumpDayList(
            tester,
            FakeTeacherScheduleRepository(
              classes: [sampleClass()],
              assigned: [thursdayCover],
            ),
          ),
          labels: [(l) => text('teacherScheduleEmptyDay', l)],
        ),
        (
          name: 'Schedule, a finished class',
          reach: (tester) async {
            await pumpDayList(tester, week(assigned: [thursdayCover]));
            await tester.tap(
              find.bySemanticsLabel(TeacherScheduleStrings.previousDay),
            );
            await tester.pumpAndSettle();
          },
          labels: [(l) => text('teacherScheduleFinished', l)],
        ),
        (
          name: 'Schedule, covering and covered classes',
          reach: (tester) => pumpDayList(tester, week(assigned: coveredWeek)),
          labels: [
            (l) => text('teacherSessionCovering', l),
            (l) => coveredBy('Анар Бат', l),
          ],
        ),
        (
          name: 'Schedule, an upcoming class\'s sheet',
          reach: (tester) async {
            await pumpDayList(tester, week(assigned: [thursdayCover]));
            await tester.tap(find.text('AI Engineer'));
            await tester.pumpAndSettle();
          },
          labels: [
            (l) => text('teacherScheduleChangeTime', l),
            (l) => text('teacherScheduleTakeAttendance', l),
          ],
        ),
        (
          name: 'Schedule, a held class\'s sheet',
          reach: (tester) async {
            await pumpDayList(tester, week(assigned: [thursdayCover]));
            await tester.tap(
              find.bySemanticsLabel(TeacherScheduleStrings.previousDay),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('AI Engineer'));
            await tester.pumpAndSettle();
          },
          labels: [(l) => text('teacherScheduleAttendedCaption', l)],
        ),
        (
          name: '"Teachers", one row in each state',
          reach: (tester) => pumpApp(
            tester,
            const TeacherRequestScreen(
              candidates: [
                TeacherRequestCandidate(
                  name: 'Болд Бат',
                  status: TeacherRequestStatus.notSent,
                ),
                TeacherRequestCandidate(
                  name: 'Сараа Ганбат',
                  status: TeacherRequestStatus.pending,
                ),
                TeacherRequestCandidate(
                  name: 'Анар Бат',
                  status: TeacherRequestStatus.rejected,
                ),
              ],
            ),
            size: size,
          ),
          labels: [
            (l) => text('teacherRequestTeachersTitle', l),
            (l) => text('teacherRequestSend', l),
            (l) => text('teacherRequestPending', l),
            (l) => text('teacherRequestDeclined', l),
          ],
        ),
        (
          name: '"Teachers", no teacher free',
          reach: (tester) => pumpApp(
            tester,
            changeScreen(FakeScheduleChangeRepository()),
            size: size,
          ),
          labels: [(l) => text('teacherRequestsEmpty', l)],
        ),
        (
          name: '"Teachers", requests unavailable',
          reach: (tester) => pumpApp(
            tester,
            changeScreen(
              FakeScheduleChangeRepository(loadFailure: refused(null)),
            ),
            size: size,
          ),
          labels: [(l) => text('teacherRequestsUnavailable', l)],
        ),
        (
          name: 'The request-sent card',
          reach: (tester) async {
            await pumpApp(
              tester,
              changeScreen(
                FakeScheduleChangeRepository(teachers: sampleEligibleTeachers),
              ),
              size: size,
            );
            await tester.tap(
              find.text(TeacherScheduleStrings.requestSend).first,
            );
            await tester.pumpAndSettle();
          },
          labels: [
            (l) => text('teacherRequestSentTitle', l),
            (l) => text('teacherConfirmationDismiss', l),
          ],
        ),
        for (final (code, key) in codes.take(6))
          (
            name: 'A send refused with $code',
            reach: (tester) async {
              await pumpApp(
                tester,
                changeScreen(
                  FakeScheduleChangeRepository(
                    teachers: sampleEligibleTeachers,
                    sendFailure: refused(code),
                  ),
                ),
                size: size,
              );
              await tester.tap(
                find.text(TeacherScheduleStrings.requestSend).first,
              );
              await tester.pumpAndSettle();
            },
            labels: [(l) => text(key, l)],
          ),
        (
          name: 'The incoming sheet',
          reach: (tester) async {
            await pumpApp(
              tester,
              incoming(
                FakeScheduleChangeRepository(request: sampleIncomingRequest()),
              ),
              size: size,
            );
            await openIncoming(tester);
          },
          labels: [
            (l) => text('teacherRequestDecline', l),
            (l) => text('teacherRequestAccept', l),
          ],
        ),
        (
          name: 'The incoming sheet, a class with no title',
          reach: (tester) async {
            await pumpApp(
              tester,
              incoming(
                FakeScheduleChangeRepository(
                  request: sampleIncomingRequest(
                    courseTitle: null,
                    cohortName: null,
                  ),
                ),
              ),
              size: size,
            );
            await openIncoming(tester);
          },
          labels: [(l) => text('teacherSessionUntitled', l)],
        ),
        for (final (status, key) in [
          ('accepted', 'teacherRequestAccepted'),
          ('rejected', 'teacherRequestRejected'),
          ('cancelled', 'teacherRequestCancelled'),
          ('expired', 'teacherRequestExpired'),
        ])
          (
            name: 'The incoming sheet, $status',
            reach: (tester) async {
              await pumpApp(
                tester,
                incoming(
                  FakeScheduleChangeRepository(
                    request: sampleIncomingRequest(status: status),
                  ),
                ),
                size: size,
              );
              await openIncoming(tester);
            },
            labels: [(l) => text(key, l)],
          ),
        for (final (code, key) in codes.skip(6))
          (
            name: 'An incoming request refused with $code',
            reach: (tester) async {
              final repository = code == 'request_not_found'
                  // A read refused: the request is gone or not theirs.
                  ? FakeScheduleChangeRepository(
                      requestFailures: [refused(code)],
                    )
                  // An answer refused.
                  : FakeScheduleChangeRepository(
                      request: sampleIncomingRequest(),
                      decisionFailure: refused(code),
                    );
              await pumpApp(tester, incoming(repository), size: size);
              await openIncoming(tester);
              if (code != 'request_not_found') {
                await tester.tap(
                  find.text(TeacherScheduleStrings.requestAccept),
                );
                await tester.pumpAndSettle();
              }
            },
            labels: [(l) => text(key, l)],
          ),
      ];

  for (final state in states) {
    for (final language in LocalePreference.values) {
      testWidgets('${state.name}, ${language.name}, 2.0× text on a 320 pt '
          'phone: no overflow, every line whole and inside the screen, '
          'nothing cut short', (tester) async {
        await locale.setPreference(language);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await state.reach(tester);
        expect(tester.takeException(), isNull);

        for (final labelOf in state.labels) {
          final value = labelOf(language);
          final label = find.text(value);
          expect(label, findsOneWidget, reason: value);
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          final rect = tester.getRect(label);
          expect(rect.left, greaterThanOrEqualTo(0), reason: value);
          expect(rect.right, lessThanOrEqualTo(width), reason: value);
          expect(rect.top, greaterThanOrEqualTo(0), reason: value);
          expect(rect.bottom, lessThanOrEqualTo(height), reason: value);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)).first,
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: value);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
            ),
            reason: value,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
