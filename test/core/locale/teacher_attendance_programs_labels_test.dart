import 'dart:async';

import 'package:aia_mobile/core/locale/app_locale_controller.dart';
import 'package:aia_mobile/core/locale/l10n.dart';
import 'package:aia_mobile/core/locale/locale_preference.dart';
import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_attendance.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_submission.dart';
import 'package:aia_mobile/features/teacher/presentation/attendance_qr_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/manual_attendance_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_attendance_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_gradebook_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_pill_button.dart';
import 'package:aia_mobile/shared/widgets/app_back_button.dart';
import 'package:aia_mobile/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/teacher/fake_teacher_attendance_repository.dart';
import '../../features/teacher/fake_teacher_gradebook_repository.dart';
import '../../features/teacher/teacher_attendance_test.dart'
    show referenceRoster;
import '../../features/teacher/teacher_gradebook_screen_test.dart'
    show classRepository, roster;
import '../../features/teacher/teacher_home_screen_test.dart' show sampleClass;
import '../../support/screenshot.dart';

/// Issue #551 (L18 and L19): teacher attendance registration and Teacher
/// Programs (the former Gradebook) in the selected language. Mongolian reads
/// exactly as before. Fakes stand in for the API — no network, no real
/// attendance, review or announcement; the names are made-up fixtures.
void main() {
  setUpAll(loadAppFonts);
  final locale = AppLocaleController.instance;
  tearDown(() => locale.setPreference(LocalePreference.mongolian));

  /// Every key without a placeholder, its Mongolian exactly as the screens
  /// showed it before, and the approved English.
  const copy = <String, ({String mongolian, String english})>{
    'teacherAttendanceQrCaption': (
      mongolian: 'оюутан ирцэд бүртгэгдлээ',
      english: 'students checked in',
    ),
    'teacherAttendanceManualEntry': (
      mongolian: 'Гар аргаар бүртгэх',
      english: 'Record manually',
    ),
    'teacherAttendanceQrNotToday': (
      mongolian: 'QR кодыг зөвхөн хичээлийн өдөр үүсгэх боломжтой.',
      english: 'A QR code can only be created on the day of the class.',
    ),
    'teacherAttendanceQrExpired': (
      mongolian: 'QR кодын хугацаа дууссан.',
      english: 'The QR code has expired.',
    ),
    'teacherAttendanceQrLabel': (
      mongolian: 'Ирцийн QR код',
      english: 'Attendance QR code',
    ),
    'teacherStudentsHeading': (mongolian: 'Сурагчид', english: 'Students'),
    'teacherAttendanceConfirm': (
      mongolian: 'Баталгаажуулах',
      english: 'Confirm',
    ),
    'teacherAttendanceNoStudents': (
      mongolian: 'Энэ хичээлд бүртгэлтэй сурагч алга.',
      english: 'No students are enrolled in this class.',
    ),
    'teacherAttendanceSaveFailed': (
      mongolian: 'Хадгалагдсангүй',
      english: 'Not saved',
    ),
    'teacherAttendanceSaving': (mongolian: 'Хадгалж байна', english: 'Saving'),
    'teacherAttendanceConflictTitle': (
      mongolian: 'Ирц өөрчлөгдсөн байна',
      english: 'Attendance has changed',
    ),
    'teacherAttendanceConflictBody': (
      mongolian:
          'Жагсаалтыг нээснээс хойш энэ сурагчийн ирц серверт өөрчлөгдсөн. '
          'Аль утгыг хадгалахаа сонгоно уу.',
      english:
          "This student's attendance changed on the server after you opened "
          'the list. Choose which one to keep.',
    ),
    'teacherAttendanceMethodManual': (mongolian: 'гараар', english: 'manual'),
    'teacherAttendanceMethodNone': (
      mongolian: 'бүртгэлгүй',
      english: 'not recorded',
    ),
    'teacherAttendanceChooseStatus': (
      mongolian: 'Ирцийн төлөв',
      english: 'Attendance status',
    ),
    'teacherAttendancePresent': (mongolian: 'Ирсэн', english: 'Present'),
    'teacherAttendanceLate': (mongolian: 'Хоцорсон', english: 'Late'),
    'teacherAttendanceAbsent': (mongolian: 'Ирээгүй', english: 'Absent'),
    'teacherAttendanceExcused': (mongolian: 'Чөлөөтэй', english: 'Excused'),
    'teacherAttendanceSuccessTitle': (
      mongolian: 'Амжилттай баталгаажлаа',
      english: 'Confirmed successfully',
    ),
    'teacherProgramsTotalStudents': (
      mongolian: 'Нийт сурагч',
      english: 'Total students',
    ),
    'teacherProgramsDetails': (mongolian: 'Дэлгэрэнгүй', english: 'Details'),
    'teacherProgramsAnnounce': (
      mongolian: 'Зар тараах',
      english: 'Send announcement',
    ),
    'teacherProgramsStudentsInfo': (
      mongolian: 'Сурагчдын мэдээлэл',
      english: 'Student information',
    ),
    'teacherProgramsAnnounceUnavailable': (
      mongolian:
          'Багш зар тараах боломж одоогоор серверт нээгдээгүй байна. Зар '
          'илгээгдэхгүй.',
      english:
          "Teachers can't send announcements on the server yet. The "
          "announcement won't be sent.",
    ),
    'teacherProgramsNoStudents': (
      mongolian: 'Энэ ангид бүртгэлтэй сурагч алга.',
      english: 'No students are enrolled in this class.',
    ),
    'teacherProgramsAttendance': (
      mongolian: 'Хичээлийн ирц',
      english: 'Class attendance',
    ),
    'teacherProgramsExamScore': (
      mongolian: 'Шалгалтын дүн',
      english: 'Exam score',
    ),
    'teacherProgramsNoAssignments': (
      mongolian: 'Энэ ангид даалгавар алга.',
      english: 'This class has no assignments.',
    ),
    'teacherProgramsNotSubmitted': (
      mongolian: 'Энэ даалгаврыг илгээгээгүй байна.',
      english: "This assignment hasn't been submitted.",
    ),
    'teacherProgramsNoNote': (
      mongolian: 'Тайлбар бичээгүй.',
      english: 'No note added.',
    ),
    'teacherProgramsReplyLabel': (mongolian: 'Тайлбар', english: 'Comment'),
    'teacherProgramsEditReply': (
      mongolian: 'Хариултыг засах',
      english: 'Edit reply',
    ),
    'teacherProgramsFeedbackRequired': (
      mongolian: 'Хариултаа бичнэ үү.',
      english: 'Please write your reply.',
    ),
    'teacherProgramsFeedbackTooLong': (
      mongolian: 'Хариулт 5000 тэмдэгтээс хэтэрсэн байна.',
      english: 'Your reply must be 5,000 characters or fewer.',
    ),
    'teacherProgramsInvalidScore': (
      mongolian: 'Оноо буруу байна.',
      english: 'The score is invalid.',
    ),
    'teacherProgramsSubmissionNotFound': (
      mongolian: 'Энэ илгээлт олдсонгүй.',
      english: 'Submission not found.',
    ),
  };

  String text(String key, LocalePreference language) =>
      language == LocalePreference.mongolian
      ? copy[key]!.mongolian
      : copy[key]!.english;
  String en(String key) => text(key, LocalePreference.english);
  String mn(String key) => text(key, LocalePreference.mongolian);
  bool isMn(LocalePreference l) => l == LocalePreference.mongolian;

  // The placeholder messages: Mongolian as the strings classes interpolated
  // it before (`main` at 88704be), English as approved.
  String failedRows(int n, LocalePreference l) => isMn(l)
      ? '$n сурагчийн ирц хадгалагдсангүй. Дахин оролдоно уу.'
      : n == 1
      ? "1 student's attendance wasn't saved. Please try again."
      : "$n students' attendance wasn't saved. Please try again.";
  String conflictsPending(int n, LocalePreference l) => isMn(l)
      ? '$n сурагчийн ирц серверт өөрчлөгдсөн. Мөр дээр дарж шийдвэрлэнэ үү.'
      : n == 1
      ? "1 student's attendance changed on the server. Tap a row to resolve "
            'it.'
      : "$n students' attendance changed on the server. Tap a row to resolve "
            'it.';
  String conflictServer(String status, String method, LocalePreference l) =>
      isMn(l)
      ? 'Серверт: $status ($method)'
      : 'On the server: $status ($method)';
  String conflictMine(String status, LocalePreference l) =>
      isMn(l) ? 'Таны сонголт: $status' : 'Your choice: $status';
  String keepServer(String status, LocalePreference l) =>
      isMn(l) ? 'Серверийнхийг үлдээх: $status' : "Keep the server's: $status";
  String applyMine(String status, LocalePreference l) =>
      isMn(l) ? 'Миний сонголтыг хадгалах: $status' : 'Save my choice: $status';
  String checkFailed(String reason, LocalePreference l) => isMn(l)
      ? 'Сүүлийн ирцийг шалгаж чадсангүй — юу ч илгээгдсэнгүй. $reason'
      : "Couldn't check the latest attendance — nothing was sent. $reason";
  String pendingLabel(int n, LocalePreference l) => isMn(l)
      ? '$n даалгавар дүгнэгдэхийг хүлээж байна'
      : n == 1
      ? '1 assignment waiting to be graded'
      : '$n assignments waiting to be graded';
  String assignmentCaption(int n, LocalePreference l) =>
      isMn(l) ? 'Даалгавар $n' : 'Assignment $n';
  String scoreLabel(String max, LocalePreference l) =>
      isMn(l) ? 'Оноо (0–$max)' : 'Score (0–$max)';
  String scoreInvalid(String max, LocalePreference l) => isMn(l)
      ? '0-ээс $max хүртэлх оноо оруулна уу'
      : 'Enter a score from 0 to $max';

  String status(AttendanceStatus s, LocalePreference l) => text(switch (s) {
    AttendanceStatus.present => 'teacherAttendancePresent',
    AttendanceStatus.late => 'teacherAttendanceLate',
    AttendanceStatus.absent => 'teacherAttendanceAbsent',
    AttendanceStatus.excused => 'teacherAttendanceExcused',
  }, l);

  TeacherFailure refused(String code) =>
      TeacherFailure(TeacherFailureKind.rejected, code: code);

  /// The four reply refusals, each code with its key.
  const replyCodes = [
    ('feedback_required', 'teacherProgramsFeedbackRequired'),
    ('feedback_too_long', 'teacherProgramsFeedbackTooLong'),
    ('invalid_score', 'teacherProgramsInvalidScore'),
    ('submission_not_found', 'teacherProgramsSubmissionNotFound'),
  ];

  group('the keys', () {
    for (final language in LocalePreference.values) {
      test(language.name, () {
        final s = L10n.of(language);
        expect(
          {
            'teacherAttendanceQrCaption': s.teacherAttendanceQrCaption,
            'teacherAttendanceManualEntry': s.teacherAttendanceManualEntry,
            'teacherAttendanceQrNotToday': s.teacherAttendanceQrNotToday,
            'teacherAttendanceQrExpired': s.teacherAttendanceQrExpired,
            'teacherAttendanceQrLabel': s.teacherAttendanceQrLabel,
            'teacherStudentsHeading': s.teacherStudentsHeading,
            'teacherAttendanceConfirm': s.teacherAttendanceConfirm,
            'teacherAttendanceNoStudents': s.teacherAttendanceNoStudents,
            'teacherAttendanceSaveFailed': s.teacherAttendanceSaveFailed,
            'teacherAttendanceSaving': s.teacherAttendanceSaving,
            'teacherAttendanceConflictTitle': s.teacherAttendanceConflictTitle,
            'teacherAttendanceConflictBody': s.teacherAttendanceConflictBody,
            'teacherAttendanceMethodManual': s.teacherAttendanceMethodManual,
            'teacherAttendanceMethodNone': s.teacherAttendanceMethodNone,
            'teacherAttendanceChooseStatus': s.teacherAttendanceChooseStatus,
            'teacherAttendancePresent': s.teacherAttendancePresent,
            'teacherAttendanceLate': s.teacherAttendanceLate,
            'teacherAttendanceAbsent': s.teacherAttendanceAbsent,
            'teacherAttendanceExcused': s.teacherAttendanceExcused,
            'teacherAttendanceSuccessTitle': s.teacherAttendanceSuccessTitle,
            'teacherProgramsTotalStudents': s.teacherProgramsTotalStudents,
            'teacherProgramsDetails': s.teacherProgramsDetails,
            'teacherProgramsAnnounce': s.teacherProgramsAnnounce,
            'teacherProgramsStudentsInfo': s.teacherProgramsStudentsInfo,
            'teacherProgramsAnnounceUnavailable':
                s.teacherProgramsAnnounceUnavailable,
            'teacherProgramsNoStudents': s.teacherProgramsNoStudents,
            'teacherProgramsAttendance': s.teacherProgramsAttendance,
            'teacherProgramsExamScore': s.teacherProgramsExamScore,
            'teacherProgramsNoAssignments': s.teacherProgramsNoAssignments,
            'teacherProgramsNotSubmitted': s.teacherProgramsNotSubmitted,
            'teacherProgramsNoNote': s.teacherProgramsNoNote,
            'teacherProgramsReplyLabel': s.teacherProgramsReplyLabel,
            'teacherProgramsEditReply': s.teacherProgramsEditReply,
            'teacherProgramsFeedbackRequired':
                s.teacherProgramsFeedbackRequired,
            'teacherProgramsFeedbackTooLong': s.teacherProgramsFeedbackTooLong,
            'teacherProgramsInvalidScore': s.teacherProgramsInvalidScore,
            'teacherProgramsSubmissionNotFound':
                s.teacherProgramsSubmissionNotFound,
          },
          {for (final key in copy.keys) key: text(key, language)},
        );
        for (final n in [1, 2, 12]) {
          expect(s.teacherAttendanceFailedRows(n), failedRows(n, language));
          expect(
            s.teacherAttendanceConflictsPending(n),
            conflictsPending(n, language),
          );
          expect(s.teacherProgramsPendingLabel(n), pendingLabel(n, language));
          expect(
            s.teacherProgramsAssignmentCaption(n),
            assignmentCaption(n, language),
          );
        }
        expect(
          s.teacherAttendanceConflictServer('A', 'B'),
          conflictServer('A', 'B', language),
        );
        expect(
          s.teacherAttendanceConflictMine('A'),
          conflictMine('A', language),
        );
        expect(s.teacherAttendanceKeepServer('A'), keepServer('A', language));
        expect(s.teacherAttendanceApplyMine('A'), applyMine('A', language));
        expect(
          s.teacherAttendanceCheckFailed('R.'),
          checkFailed('R.', language),
        );
        expect(s.teacherProgramsScoreLabel('7.5'), scoreLabel('7.5', language));
        expect(
          s.teacherProgramsScoreInvalid('100'),
          scoreInvalid('100', language),
        );
      });

      test('the strings classes in ${language.name}', () async {
        await locale.setPreference(language);
        String t(String key) => text(key, language);

        // Attendance registration.
        expect(
          TeacherAttendanceStrings.qrTitle,
          isMn(language) ? 'Ирц бүртгэх' : 'Take attendance',
        );
        expect(
          TeacherAttendanceStrings.qrCountCaption,
          t('teacherAttendanceQrCaption'),
        );
        expect(
          TeacherAttendanceStrings.manualEntry,
          t('teacherAttendanceManualEntry'),
        );
        expect(
          TeacherAttendanceStrings.manualTitle,
          t('teacherAttendanceManualEntry'),
        );
        expect(
          TeacherAttendanceStrings.qrNotToday,
          t('teacherAttendanceQrNotToday'),
        );
        expect(
          TeacherAttendanceStrings.qrExpired,
          t('teacherAttendanceQrExpired'),
        );
        expect(TeacherAttendanceStrings.qrLabel, t('teacherAttendanceQrLabel'));
        expect(
          TeacherAttendanceStrings.studentsHeading,
          t('teacherStudentsHeading'),
        );
        expect(TeacherAttendanceStrings.confirm, t('teacherAttendanceConfirm'));
        expect(
          TeacherAttendanceStrings.noStudents,
          t('teacherAttendanceNoStudents'),
        );
        expect(
          TeacherAttendanceStrings.saveFailed,
          t('teacherAttendanceSaveFailed'),
        );
        expect(TeacherAttendanceStrings.saving, t('teacherAttendanceSaving'));
        expect(TeacherAttendanceStrings.failedRows(3), failedRows(3, language));
        expect(
          TeacherAttendanceStrings.conflictTitle,
          t('teacherAttendanceConflictTitle'),
        );
        expect(
          TeacherAttendanceStrings.conflictBody,
          t('teacherAttendanceConflictBody'),
        );
        for (final s in AttendanceStatus.values) {
          expect(TeacherAttendanceStrings.statusLabel(s), status(s, language));
        }
        expect(TeacherAttendanceStrings.methodLabel('qr'), 'QR');
        expect(
          TeacherAttendanceStrings.methodLabel('manual'),
          t('teacherAttendanceMethodManual'),
        );
        expect(
          TeacherAttendanceStrings.methodLabel(null),
          t('teacherAttendanceMethodNone'),
        );
        final late = status(AttendanceStatus.late, language);
        final present = status(AttendanceStatus.present, language);
        expect(
          TeacherAttendanceStrings.conflictServer(AttendanceStatus.late, 'qr'),
          conflictServer(late, 'QR', language),
        );
        expect(
          TeacherAttendanceStrings.conflictServer(
            AttendanceStatus.late,
            'manual',
          ),
          conflictServer(late, t('teacherAttendanceMethodManual'), language),
        );
        expect(
          TeacherAttendanceStrings.conflictMine(AttendanceStatus.present),
          conflictMine(present, language),
        );
        expect(
          TeacherAttendanceStrings.keepServer(AttendanceStatus.late),
          keepServer(late, language),
        );
        expect(
          TeacherAttendanceStrings.applyMine(AttendanceStatus.present),
          applyMine(present, language),
        );
        expect(
          TeacherAttendanceStrings.conflictsPending(1),
          conflictsPending(1, language),
        );
        expect(
          TeacherAttendanceStrings.checkFailed('R.'),
          checkFailed('R.', language),
        );
        expect(
          TeacherAttendanceStrings.chooseStatus,
          t('teacherAttendanceChooseStatus'),
        );
        expect(
          TeacherAttendanceStrings.successTitle,
          t('teacherAttendanceSuccessTitle'),
        );
        expect(
          TeacherAttendanceStrings.successDismiss,
          isMn(language) ? 'Ойлголоо' : 'Got it',
        );
        // Bilingual in both, as the reference draws it.
        expect(
          TeacherAttendanceStrings.qrHint,
          'Оюутнууд уг кодыг уншуулна уу · Students scan this code',
        );

        // Teacher Programs.
        expect(
          TeacherGradebookStrings.title,
          isMn(language) ? 'Хөтөлбөрүүд' : 'Programs',
        );
        expect(
          TeacherGradebookStrings.empty,
          isMn(language) ? 'Одоогоор хичээл алга байна' : 'No classes yet',
        );
        expect(
          TeacherGradebookStrings.totalStudents,
          t('teacherProgramsTotalStudents'),
        );
        expect(TeacherGradebookStrings.details, t('teacherProgramsDetails'));
        expect(TeacherGradebookStrings.announce, t('teacherProgramsAnnounce'));
        expect(
          TeacherGradebookStrings.studentsInfo,
          t('teacherProgramsStudentsInfo'),
        );
        expect(
          TeacherGradebookStrings.announceUnavailable,
          t('teacherProgramsAnnounceUnavailable'),
        );
        expect(
          TeacherGradebookStrings.studentsHeading,
          t('teacherStudentsHeading'),
        );
        expect(
          TeacherGradebookStrings.noStudents,
          t('teacherProgramsNoStudents'),
        );
        expect(
          TeacherGradebookStrings.pendingLabel(1),
          pendingLabel(1, language),
        );
        expect(
          TeacherGradebookStrings.pendingLabel(4),
          pendingLabel(4, language),
        );
        expect(
          TeacherGradebookStrings.attendance,
          t('teacherProgramsAttendance'),
        );
        expect(
          TeacherGradebookStrings.examScore,
          t('teacherProgramsExamScore'),
        );
        expect(
          TeacherGradebookStrings.assignmentCaption(2),
          assignmentCaption(2, language),
        );
        expect(
          TeacherGradebookStrings.noAssignments,
          t('teacherProgramsNoAssignments'),
        );
        expect(
          TeacherGradebookStrings.notSubmitted,
          t('teacherProgramsNotSubmitted'),
        );
        expect(TeacherGradebookStrings.noNote, t('teacherProgramsNoNote'));
        expect(
          TeacherGradebookStrings.replyLabel,
          t('teacherProgramsReplyLabel'),
        );
        expect(
          TeacherGradebookStrings.editReply,
          t('teacherProgramsEditReply'),
        );
        // A whole maximum without its decimal point, as before.
        expect(
          TeacherGradebookStrings.scoreLabel(100),
          scoreLabel('100', language),
        );
        expect(
          TeacherGradebookStrings.scoreLabel(7.5),
          scoreLabel('7.5', language),
        );
        expect(
          TeacherGradebookStrings.scoreInvalid(100.0),
          scoreInvalid('100', language),
        );
        for (final (code, key) in replyCodes) {
          expect(
            TeacherGradebookStrings.replyFailed(refused(code)),
            t(key),
            reason: code,
          );
        }
        expect(
          TeacherGradebookStrings.replyFailed(
            const TeacherFailure(TeacherFailureKind.network),
          ),
          TeacherHomeStrings.messageFor(TeacherFailureKind.network),
        );
        // The frames' own English, and the fixed marks: the same in both.
        expect(TeacherGradebookStrings.roleStudent, 'Student');
        expect(TeacherGradebookStrings.roleTeacher, 'Teacher');
        expect(TeacherGradebookStrings.submit, 'Submit');
        expect(
          TeacherGradebookStrings.announceHint,
          'Provide some details about your score',
        );
        expect(
          TeacherGradebookStrings.announcePlaceholder,
          'What do you like or dislike?',
        );
        expect(TeacherGradebookStrings.noFigure, '—');
        expect(TeacherGradebookStrings.badge(10), '9+');
      });
    }
  });

  // --- Pumps --------------------------------------------------------------

  /// [home] under the language rebuild scope, as the app root draws it.
  /// Timers run on: the QR screen polls, so callers settle with [pump]s.
  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(393, 1000),
    bool settle = true,
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      L10nRebuildScope(
        child: MaterialApp(theme: AppTheme.light, home: home),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Finder teacherPill(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(TeacherPillButton),
  );
  Finder appPill(String label) => find.widgetWithText(PillButton, label);

  /// [name]'s round status control on the manual screen.
  Finder control(String name) => find.descendant(
    of: find.ancestor(
      of: find.text(name),
      matching: find.byType(AttendanceStudentRow),
    ),
    matching: find.byType(AttendanceStatusControl),
  );

  /// The QR screen for session 41, then its manual screen.
  Future<FakeTeacherAttendanceRepository> openManual(
    WidgetTester tester, {
    Size size = const Size(393, 1000),
    FakeTeacherAttendanceRepository? repository,
  }) async {
    final repo =
        repository ??
        FakeTeacherAttendanceRepository(students: referenceRoster());
    await pumpApp(
      tester,
      AttendanceQrScreen(sessionId: 41, repository: repo),
      size: size,
      settle: false,
    );
    await tester.tap(teacherPill(TeacherAttendanceStrings.manualEntry));
    await tester.pumpAndSettle();
    expect(find.byType(ManualAttendanceScreen), findsOneWidget);
    return repo;
  }

  /// Saruul's absent changed to present, a scan meanwhile made her late:
  /// confirming opens the conflict sheet.
  Future<void> openConflict(
    WidgetTester tester, {
    Size size = const Size(393, 1000),
  }) async {
    final repo = await openManual(tester, size: size);
    await tester.tap(control('Саруул Батбаатар'));
    await tester.pump();
    repo.serverChange(2, AttendanceStatus.late, 'qr');
    await tester.tap(teacherPill(TeacherAttendanceStrings.confirm));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceConflictSheet), findsOneWidget);
  }

  Future<FakeTeacherGradebookRepository> openPrograms(
    WidgetTester tester, {
    FakeTeacherGradebookRepository? repository,
    Size size = const Size(393, 1000),
  }) async {
    final repo = repository ?? classRepository();
    await pumpApp(
      tester,
      TeacherGradebookScreen(repository: repo, showBottomNav: false),
      size: size,
    );
    return repo;
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(appPill(TeacherGradebookStrings.details));
    await tester.pumpAndSettle();
  }

  Future<void> openStudents(WidgetTester tester) async {
    await openSheet(tester);
    await tester.tap(find.text(TeacherGradebookStrings.studentsInfo));
    await tester.pumpAndSettle();
  }

  Future<FakeTeacherGradebookRepository> openStudent(
    WidgetTester tester,
    String name, {
    FakeTeacherGradebookRepository? repository,
    Size size = const Size(393, 1000),
  }) async {
    final repo = await openPrograms(tester, repository: repository, size: size);
    await openStudents(tester);
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    return repo;
  }

  Finder replyField() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.labelText == TeacherGradebookStrings.replyLabel,
  );

  /// Class 2 with a 100-point maximum on both assignments.
  FakeTeacherGradebookRepository scored() => classRepository()
    ..assignments = {
      2: const [
        TeacherAssignment(
          id: 2,
          title: LocalizedText(mn: 'Даалгавар 2'),
          maxScore: 100,
        ),
        TeacherAssignment(
          id: 3,
          title: LocalizedText(en: 'Assignment 3'),
          maxScore: 100,
        ),
      ],
    };

  // --- A language change ----------------------------------------------------

  group('a language change', () {
    testWidgets('the QR screen and the manual screen redraw at once', (
      tester,
    ) async {
      await openManual(tester);
      expect(find.text(mn('teacherStudentsHeading')), findsOneWidget);
      expect(find.text(mn('teacherAttendanceLate')), findsOneWidget);
      final state = tester.state(find.byType(ManualAttendanceScreen));

      await locale.setEnglish(true);
      await tester.pumpAndSettle();
      expect(find.text(en('teacherAttendanceManualEntry')), findsOneWidget);
      expect(find.text(en('teacherStudentsHeading')), findsOneWidget);
      expect(find.text(en('teacherAttendanceConfirm')), findsOneWidget);
      expect(find.text(en('teacherAttendanceLate')), findsOneWidget);
      expect(find.text(en('teacherAttendanceExcused')), findsOneWidget);
      expect(find.text(mn('teacherAttendanceLate')), findsNothing);
      expect(tester.state(find.byType(ManualAttendanceScreen)), same(state));

      // Back on the QR screen: its title and action too.
      await tester.tap(
        find.descendant(
          of: find.byType(ManualAttendanceScreen),
          matching: find.descendant(
            of: find.byType(AppBackButton),
            matching: find.byType(InkWell),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Take attendance'), findsOneWidget);
      expect(find.text(en('teacherAttendanceManualEntry')), findsOneWidget);
      expect(find.text(en('teacherAttendanceQrCaption')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the conflict sheet redraws; the success card reads in the '
        'language chosen', (tester) async {
      await openConflict(tester);
      final late = status(AttendanceStatus.late, LocalePreference.english);
      final present = status(
        AttendanceStatus.present,
        LocalePreference.english,
      );

      await locale.setEnglish(true);
      await tester.pumpAndSettle();
      expect(find.text(en('teacherAttendanceConflictTitle')), findsOneWidget);
      expect(
        find.text(conflictServer(late, 'QR', LocalePreference.english)),
        findsWidgets,
      );
      // Applying the teacher's choice saves it at once.
      await tester.tap(
        find.descendant(
          of: find.byType(AttendanceConflictSheet),
          matching: find.text(applyMine(present, LocalePreference.english)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(en('teacherAttendanceSuccessTitle')), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Programs: the cards, the sheet and a student redraw', (
      tester,
    ) async {
      await openPrograms(tester);
      expect(find.text('Хөтөлбөрүүд'), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pumpAndSettle();
      expect(find.text('Programs'), findsWidgets);
      expect(find.text(en('teacherProgramsTotalStudents')), findsOneWidget);
      await openStudents(tester);
      expect(find.text(en('teacherStudentsHeading')), findsOneWidget);
      await tester.tap(find.text('Student A'));
      await tester.pumpAndSettle();
      expect(find.text(en('teacherProgramsAttendance')), findsOneWidget);
      expect(find.text(en('teacherProgramsExamScore')), findsOneWidget);
      expect(replyField(), findsOneWidget);

      await locale.setEnglish(false);
      await tester.pumpAndSettle();
      expect(find.text(mn('teacherProgramsAttendance')), findsOneWidget);
    });

    testWidgets('a refused reply already shown keeps its language until the '
        'next submit', (tester) async {
      final repo = classRepository()
        ..reviewFailure = refused('feedback_too_long');
      await openStudent(tester, 'Student A', repository: repo);
      await tester.enterText(replyField(), 'Хариулт');
      await tester.pump();
      await tester.tap(appPill(TeacherGradebookStrings.submit));
      await tester.pumpAndSettle();
      expect(find.text(mn('teacherProgramsFeedbackTooLong')), findsOneWidget);

      await locale.setEnglish(true);
      await tester.pumpAndSettle();
      // Drawn now: switched.
      expect(find.text(en('teacherProgramsExamScore')), findsOneWidget);
      // Stored when the reply failed: unchanged until the next submit.
      expect(find.text(mn('teacherProgramsFeedbackTooLong')), findsOneWidget);

      await tester.tap(appPill(TeacherGradebookStrings.submit));
      await tester.pumpAndSettle();
      expect(find.text(en('teacherProgramsFeedbackTooLong')), findsOneWidget);
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
          name: 'QR attendance',
          reach: (tester) => pumpApp(
            tester,
            AttendanceQrScreen(
              sessionId: 41,
              repository: FakeTeacherAttendanceRepository(
                students: referenceRoster(),
              ),
            ),
            size: size,
            settle: false,
          ),
          labels: [
            (l) => isMn(l) ? 'Ирц бүртгэх' : 'Take attendance',
            (l) => text('teacherAttendanceManualEntry', l),
            (l) => text('teacherAttendanceQrCaption', l),
          ],
        ),
        (
          name: 'QR attendance on another day',
          reach: (tester) => pumpApp(
            tester,
            AttendanceQrScreen(
              sessionId: 41,
              repository: FakeTeacherAttendanceRepository()
                ..qrFailure = refused('session_not_today'),
            ),
            size: size,
            settle: false,
          ),
          labels: [(l) => text('teacherAttendanceQrNotToday', l)],
        ),
        (
          name: 'Manual attendance',
          reach: (tester) => openManual(tester, size: size),
          labels: [
            (l) => text('teacherAttendanceManualEntry', l),
            (l) => text('teacherStudentsHeading', l),
            (l) => text('teacherAttendanceConfirm', l),
            (l) => text('teacherAttendanceLate', l),
            (l) => text('teacherAttendanceExcused', l),
          ],
        ),
        (
          name: 'Manual attendance, no students',
          reach: (tester) => openManual(
            tester,
            size: size,
            repository: FakeTeacherAttendanceRepository(),
          ),
          labels: [(l) => text('teacherAttendanceNoStudents', l)],
        ),
        (
          name: 'Manual attendance, a row not saved',
          reach: (tester) async {
            final repo = FakeTeacherAttendanceRepository(
              students: referenceRoster(),
            )..failingStudents.add(2);
            await openManual(tester, size: size, repository: repo);
            await tester.tap(control('Саруул Батбаатар'));
            await tester.pump();
            await tester.tap(teacherPill(TeacherAttendanceStrings.confirm));
            await tester.pumpAndSettle();
          },
          labels: [
            (l) => failedRows(1, l),
            (l) => text('teacherAttendanceSaveFailed', l),
          ],
        ),
        (
          name: 'Manual attendance, the re-read failed',
          reach: (tester) async {
            final repo = await openManual(tester, size: size);
            await tester.tap(control('Саруул Батбаатар'));
            await tester.pump();
            repo.readFailure = const TeacherFailure(TeacherFailureKind.network);
            await tester.tap(teacherPill(TeacherAttendanceStrings.confirm));
            await tester.pumpAndSettle();
          },
          labels: [
            (l) => checkFailed(
              TeacherHomeStrings.messageFor(TeacherFailureKind.network),
              l,
            ),
          ],
        ),
        (
          name: 'The conflict sheet',
          reach: (tester) => openConflict(tester, size: size),
          labels: [
            (l) => text('teacherAttendanceConflictTitle', l),
            (l) => text('teacherAttendanceConflictBody', l),
            (l) => conflictServer(status(AttendanceStatus.late, l), 'QR', l),
            (l) => conflictMine(status(AttendanceStatus.present, l), l),
            (l) => keepServer(status(AttendanceStatus.late, l), l),
            (l) => applyMine(status(AttendanceStatus.present, l), l),
          ],
        ),
        (
          name: 'A conflict left to decide',
          reach: (tester) async {
            await openConflict(tester, size: size);
            await tester.tapAt(const Offset(160, 40));
            await tester.pumpAndSettle();
          },
          labels: [(l) => conflictsPending(1, l)],
        ),
        (
          name: 'The status picker',
          reach: (tester) async {
            await openManual(tester, size: size);
            await tester.tap(control('Анхбаяр Болд'));
            await tester.pumpAndSettle();
            expect(find.byType(AttendanceStatusPicker), findsOneWidget);
          },
          labels: [
            (l) => text('teacherAttendanceChooseStatus', l),
            for (final s in AttendanceStatus.values) (l) => status(s, l),
          ],
        ),
        (
          name: 'The attendance success card',
          reach: (tester) async {
            const page = Key('page');
            await pumpApp(
              tester,
              const Scaffold(body: SizedBox.expand(key: page)),
              size: size,
            );
            unawaited(
              showAttendanceSavedCard(tester.element(find.byKey(page))),
            );
            await tester.pumpAndSettle();
          },
          labels: [
            (l) => text('teacherAttendanceSuccessTitle', l),
            (l) => isMn(l) ? 'Ойлголоо' : 'Got it',
          ],
        ),
        (
          name: 'Programs',
          reach: (tester) => openPrograms(tester, size: size),
          labels: [
            (l) => isMn(l) ? 'Хөтөлбөрүүд' : 'Programs',
            (l) => text('teacherProgramsTotalStudents', l),
            (l) => text('teacherProgramsDetails', l),
          ],
        ),
        (
          name: 'Programs, no class',
          reach: (tester) => openPrograms(
            tester,
            size: size,
            repository: FakeTeacherGradebookRepository(),
          ),
          labels: [
            (l) => isMn(l) ? 'Одоогоор хичээл алга байна' : 'No classes yet',
          ],
        ),
        (
          name: 'A program\'s actions',
          reach: (tester) async {
            await openPrograms(tester, size: size);
            await openSheet(tester);
          },
          labels: [
            (l) => text('teacherProgramsAnnounce', l),
            (l) => text('teacherProgramsStudentsInfo', l),
          ],
        ),
        (
          name: 'The announcement composer',
          reach: (tester) async {
            await openPrograms(tester, size: size);
            await openSheet(tester);
            await tester.tap(find.text(TeacherGradebookStrings.announce));
            await tester.pumpAndSettle();
          },
          labels: [
            (l) => text('teacherProgramsAnnounce', l),
            (l) => text('teacherProgramsAnnounceUnavailable', l),
          ],
        ),
        (
          name: 'The students',
          reach: (tester) async {
            await openPrograms(tester, size: size);
            await openStudents(tester);
          },
          labels: [(l) => text('teacherStudentsHeading', l)],
        ),
        (
          name: 'The students, none enrolled',
          reach: (tester) async {
            final repo = classRepository()..students = {2: const []};
            await openPrograms(tester, size: size, repository: repo);
            await openStudents(tester);
          },
          labels: [(l) => text('teacherProgramsNoStudents', l)],
        ),
        (
          name: 'A student',
          reach: (tester) => openStudent(tester, 'Student A', size: size),
          labels: [
            (l) => text('teacherProgramsAttendance', l),
            (l) => text('teacherProgramsExamScore', l),
            (l) => text('teacherProgramsReplyLabel', l),
          ],
        ),
        (
          name: 'A student, a score out of range',
          reach: (tester) async {
            await openStudent(
              tester,
              'Student A',
              size: size,
              repository: scored(),
            );
            final score = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.labelText ==
                      TeacherGradebookStrings.scoreLabel(100),
            );
            await tester.enterText(score, '150');
            await tester.pump();
          },
          labels: [(l) => scoreLabel('100', l), (l) => scoreInvalid('100', l)],
        ),
        for (final (code, key) in replyCodes)
          (
            name: 'A reply refused with $code',
            reach: (tester) async {
              final repo = classRepository()..reviewFailure = refused(code);
              await openStudent(
                tester,
                'Student A',
                size: size,
                repository: repo,
              );
              await tester.enterText(replyField(), 'Хариулт');
              await tester.pump();
              await tester.tap(appPill(TeacherGradebookStrings.submit));
              await tester.pumpAndSettle();
            },
            labels: [(l) => text(key, l)],
          ),
        (
          name: 'A student, a class with no assignments',
          reach: (tester) => openStudent(
            tester,
            'Student A',
            size: size,
            repository: FakeTeacherGradebookRepository(
              classes: [sampleClass()],
              students: {2: roster},
            ),
          ),
          labels: [(l) => text('teacherProgramsNoAssignments', l)],
        ),
        (
          name: 'A student who submitted nothing',
          reach: (tester) => openStudent(tester, 'Student C', size: size),
          labels: [(l) => text('teacherProgramsNotSubmitted', l)],
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
          expect(label, findsWidgets, reason: value);
          // Every place the line is drawn — a status shows on its row and
          // in the picker.
          for (final element in label.evaluate()) {
            final one = find.byElementPredicate((e) => e == element);
            final rect = tester.getRect(one);
            expect(rect.left, greaterThanOrEqualTo(0), reason: value);
            expect(rect.right, lessThanOrEqualTo(width), reason: value);
            expect(rect.top, greaterThanOrEqualTo(0), reason: value);
            expect(rect.bottom, lessThanOrEqualTo(height), reason: value);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: one, matching: find.byType(RichText)).first,
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
        }
        expect(tester.takeException(), isNull);
        // Stops the QR screen's polling before the next test.
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
