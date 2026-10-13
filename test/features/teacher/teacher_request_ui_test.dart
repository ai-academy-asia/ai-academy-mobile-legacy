import 'dart:io';

import 'package:aia_mobile/core/theme/app_palette.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_request_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_pill_button.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_request_parts.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_session_sheet.dart';
import 'package:aia_mobile/shared/widgets/back_title_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass;

/// The schedule-change request's UI (Issue #372) — UI only: no verified
/// endpoint exists for any of the request's actions, so nothing here sends,
/// and the two request sheets are components nothing in the app opens yet.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 393.0];
  const scales = [1.0, 2.0, 3.0];

  final entry = ScheduledSession(
    session: sampleSession(),
    teacherClass: sampleClass(),
  );

  /// Pumps [child] at the foot of a sheet, as `showModalBottomSheet` draws
  /// the Teacher sheets, and returns every error it raised.
  Future<List<String>> pumpSheet(
    WidgetTester tester,
    Widget child, {
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
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: context.palette.barrier,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  child: Material(
                    color: context.palette.surfaceElevated,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  Finder pill(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(TeacherPillButton),
  );

  group('the class action sheet (screenshot 2)', () {
    testWidgets('an upcoming session draws "Цаг солих" and "Ирц бүртгэх" '
        'side by side, 176 wide each, 8 apart', (tester) async {
      final repository = FakeTeacherScheduleRepository();
      expect(
        await pumpSheet(
          tester,
          TeacherSessionSheet(
            entry: entry,
            held: false,
            repository: repository,
          ),
        ),
        isEmpty,
      );

      final change = tester.getRect(pill(TeacherScheduleStrings.changeTime));
      final attend = tester.getRect(
        pill(TeacherScheduleStrings.registerAttendance),
      );
      expect(change.height, 44);
      expect(attend.height, 44);
      expect(change.top, attend.top);
      expect(change.width, closeTo(176.5, 0.01));
      expect(attend.width, closeTo(176.5, 0.01));
      expect(attend.left - change.right, 8);
      // No attendance is read for a session still ahead.
      expect(repository.attendanceCalls, isEmpty);
    });

    testWidgets('"Ирц бүртгэх" is disabled: muted, a disabled button to '
        'assistive technology, and a tap does nothing', (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = FakeTeacherScheduleRepository();
      await pumpSheet(
        tester,
        TeacherSessionSheet(entry: entry, held: false, repository: repository),
      );

      final button = tester.widget<TeacherPillButton>(
        pill(TeacherScheduleStrings.registerAttendance),
      );
      expect(button.variant, TeacherPillVariant.disabled);
      expect(button.onPressed, isNull);

      expect(
        tester.getSemantics(pill(TeacherScheduleStrings.registerAttendance)),
        isSemantics(
          label: TeacherScheduleStrings.registerAttendance,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );

      await tester.tap(pill(TeacherScheduleStrings.registerAttendance));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherRequestScreen), findsNothing);
      expect(repository.attendanceCalls, isEmpty);
      semantics.dispose();
    });

    testWidgets('"Цаг солих" still opens "Багш нар", which keeps its '
        'unavailable state and sends nothing', (tester) async {
      await pumpSheet(
        tester,
        TeacherSessionSheet(
          entry: entry,
          held: false,
          repository: FakeTeacherScheduleRepository(),
        ),
      );

      await tester.tap(pill(TeacherScheduleStrings.changeTime));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherRequestScreen), findsOneWidget);
      expect(
        find.text(TeacherScheduleStrings.requestsUnavailable),
        findsOneWidget,
      );
      expect(find.byType(TeacherRequestRow), findsNothing);
    });

    testWidgets('a held session keeps its attendance summary and draws no '
        'action pills', (tester) async {
      final repository = FakeTeacherScheduleRepository();
      await pumpSheet(
        tester,
        TeacherSessionSheet(entry: entry, held: true, repository: repository),
      );
      expect(find.byType(SessionAttendanceSummary), findsOneWidget);
      expect(find.byType(TeacherPillPair), findsNothing);
      expect(
        find.text(TeacherScheduleStrings.registerAttendance),
        findsNothing,
      );
      expect(repository.attendanceCalls, [entry.session.id]);
    });

    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('${width.toInt()} wide, text ×$scale: no overflow, and '
            'both labels whole — the pair stacks when they cannot share a '
            'line', (tester) async {
          final errors = await pumpSheet(
            tester,
            TeacherSessionSheet(
              entry: entry,
              held: false,
              repository: FakeTeacherScheduleRepository(),
            ),
            width: width,
            height: 2400,
            scale: scale,
          );
          expect(errors, isEmpty);
          for (final label in [
            TeacherScheduleStrings.changeTime,
            TeacherScheduleStrings.registerAttendance,
          ]) {
            final text = tester.getRect(find.text(label));
            final box = tester.getRect(pill(label));
            expect(text.left, greaterThanOrEqualTo(box.left), reason: label);
            expect(text.right, lessThanOrEqualTo(box.right), reason: label);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.text(label),
                matching: find.byType(RichText),
              ),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          }
          if (scale == 1) {
            // Side by side at the default size.
            expect(
              tester.getRect(pill(TeacherScheduleStrings.changeTime)).top,
              tester
                  .getRect(pill(TeacherScheduleStrings.registerAttendance))
                  .top,
            );
          }
        });
      }
    }
  });

  group('the request-sent acknowledgement (screenshot 4)', () {
    testWidgets('the success disc, the title, and "Ойлголоо" that dismisses '
        'it', (tester) async {
      var dismissed = 0;
      await pumpSheet(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: TeacherRequestSentCard(onDismiss: () => dismissed++),
        ),
      );
      expect(
        find.text(TeacherScheduleStrings.requestSentTitle),
        findsOneWidget,
      );
      final button = tester.getRect(
        pill(TeacherScheduleStrings.requestSentDismiss),
      );
      expect(button.height, 44);
      expect(button.width, 393 - 32 - 32);
      await tester.tap(pill(TeacherScheduleStrings.requestSentDismiss));
      expect(dismissed, 1);
    });

    testWidgets('with no onDismiss "Ойлголоо" is inert', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSheet(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: TeacherRequestSentCard(onDismiss: null),
        ),
      );
      expect(
        tester
            .getSemantics(pill(TeacherScheduleStrings.requestSentDismiss))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
      semantics.dispose();
    });
  });

  group('the incoming-request sheet (screenshot 6)', () {
    Widget sheet({VoidCallback? onDecline, VoidCallback? onAccept}) =>
        TeacherIncomingRequestSheet(
          senderName: 'Хишгээ',
          teacherClass: sampleClass(),
          sessionLabel: '11-р сарын 17 • 14:00-17:00',
          onDecline: onDecline,
          onAccept: onAccept,
        );

    testWidgets('the sender, the class and its session, then "Татгалзах" and '
        '"Зөвшөөрөх"', (tester) async {
      final answers = <String>[];
      await pumpSheet(
        tester,
        sheet(
          onDecline: () => answers.add('decline'),
          onAccept: () => answers.add('accept'),
        ),
      );
      expect(find.text('Хишгээ'), findsOneWidget);
      expect(find.text(TeacherScheduleStrings.teacherRole), findsOneWidget);
      expect(find.text('AI Engineer'), findsOneWidget);
      expect(find.text('11-р сарын 17 • 14:00-17:00'), findsOneWidget);

      final decline = tester.widget<TeacherPillButton>(
        pill(TeacherScheduleStrings.requestDecline),
      );
      final accept = tester.widget<TeacherPillButton>(
        pill(TeacherScheduleStrings.requestAccept),
      );
      expect(decline.variant, TeacherPillVariant.danger);
      expect(accept.variant, TeacherPillVariant.filled);

      await tester.tap(pill(TeacherScheduleStrings.requestDecline));
      await tester.tap(pill(TeacherScheduleStrings.requestAccept));
      expect(answers, ['decline', 'accept']);
    });

    testWidgets('with no callbacks both answers are inert — never a faked '
        'decision', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSheet(tester, sheet());
      for (final label in [
        TeacherScheduleStrings.requestDecline,
        TeacherScheduleStrings.requestAccept,
      ]) {
        expect(
          tester
              .getSemantics(pill(label))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isFalse,
          reason: label,
        );
      }
      semantics.dispose();
    });

    testWidgets('393 wide: Room 204 and the date and times share one line, '
        'as the reference draws them', (tester) async {
      await pumpSheet(tester, sheet());
      final room = tester.getRect(find.text('Room 204'));
      final time = tester.getRect(find.text('11-р сарын 17 • 14:00-17:00'));
      expect(time.top, room.top);
      expect(time.left, greaterThan(room.right));
    });

    testWidgets('320 wide: the date and times wrap under the room, whole', (
      tester,
    ) async {
      expect(await pumpSheet(tester, sheet(), width: 320), isEmpty);
      final room = tester.getRect(find.text('Room 204'));
      final time = tester.getRect(find.text('11-р сарын 17 • 14:00-17:00'));
      expect(time.top, greaterThan(room.bottom));
    });

    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('${width.toInt()} wide, text ×$scale: no overflow, the '
            'answers whole', (tester) async {
          final errors = await pumpSheet(
            tester,
            sheet(),
            width: width,
            height: 2400,
            scale: scale,
          );
          expect(errors, isEmpty);
          for (final label in [
            TeacherScheduleStrings.requestDecline,
            TeacherScheduleStrings.requestAccept,
          ]) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.text(label),
                matching: find.byType(RichText),
              ),
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          }
        });
      }
    }
  });

  testWidgets('"Багш нар" sets its first row 40 below the shared header, as '
      'the reference does', (tester) async {
    useLogicalViewport(tester, const Size(393, 852), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const TeacherRequestScreen(
          candidates: [
            TeacherRequestCandidate(
              name: 'Баатар',
              status: TeacherRequestStatus.notSent,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final header = tester.getRect(find.byType(BackTitleHeader));
    final row = tester.getRect(find.byType(TeacherRequestRow));
    expect(header.bottom, 44 + 52);
    expect(row.top - header.bottom, 40);
  });

  test('nothing in the app opens the request sheets yet: no request data '
      'or endpoint exists to open them with', () {
    final opened = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('teacher_request_parts.dart')) continue;
      final source = file.readAsStringSync();
      for (final name in [
        'TeacherRequestSentCard(',
        'TeacherIncomingRequestSheet(',
      ]) {
        if (source.contains(name)) opened.add('${file.path}: $name');
      }
    }
    expect(opened, isEmpty);
  });

  group('goldens, against the Figma exports', () {
    for (final width in widths) {
      testWidgets('the request-sent acknowledgement, ${width.toInt()} wide', (
        tester,
      ) async {
        await pumpSheet(
          tester,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 50),
            child: TeacherRequestSentCard(onDismiss: () {}),
          ),
          width: width,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/teacher_request_sent_${width.toInt()}.png',
          ),
        );
      });

      testWidgets('the incoming-request sheet, ${width.toInt()} wide', (
        tester,
      ) async {
        await pumpSheet(
          tester,
          TeacherIncomingRequestSheet(
            senderName: 'Хишгээ',
            teacherClass: sampleClass(),
            sessionLabel: '11-р сарын 17 • 14:00-17:00',
            onDecline: () {},
            onAccept: () {},
          ),
          width: width,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/teacher_request_incoming_${width.toInt()}.png',
          ),
        );
      });
    }
  });
}
