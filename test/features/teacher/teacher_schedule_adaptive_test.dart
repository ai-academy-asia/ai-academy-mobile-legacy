import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_failure.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_session.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_home_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_day_session_list.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_session_sheet.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../cohorts/fake_cohort_repository.dart';
import 'fake_teacher_schedule_repository.dart';

/// The Teacher Schedule's adaptive large-text layout (Issue #357). At the
/// default text size the week grid always shows. Above it, once the week
/// strip's labels no longer fit their columns, or any session of the week
/// on screen cannot show its time or a whole first title word in its block,
/// the screen shows the selected day as a list of class cards instead —
/// with previous- and next-day controls, the same loading, failure and
/// refresh states, and the same session sheet.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0, 2.5, 3.0];

  const mongolian = 'Хиймэл оюун ухааны инженерчлэлийн ахисан түвшний сургалт';
  const room = 'Төв байр, 3-р давхар, 304 тоот';

  TeacherClass classOf({
    required int id,
    required String title,
    String? classroom,
  }) => TeacherClass(
    cohort: sampleCohort(
      id: id,
      name: 'Cohort $id',
      course: CohortCourse(
        id: id,
        slug: 'course-$id',
        title: LocalizedText(mn: title),
      ),
      classroom: classroom == null
          ? null
          : CohortClassroom(id: id, name: classroom, centerName: 'Төв'),
      enrolledCount: 124,
      startTime: '09:00',
      endTime: '10:00',
      startDate: '2026-09-01',
      endDate: '2026-12-20',
      meetingDays: const ['mon', 'tue', 'wed'],
    ),
    track: 'adult',
  );

  final long = classOf(id: 2, title: mongolian, classroom: room);
  final short = classOf(id: 5, title: 'AI Engineer', classroom: 'Room 204');

  /// The week of 4–10 October 2026: a 45-minute, a 1-hour and a 3-hour
  /// session of the long-titled class, and a short-titled one overlapping
  /// the 3-hour session. The week after is empty.
  Map<int, List<TeacherSession>> longWeek() => {
    2: [
      sampleSession(id: 1, date: '2026-10-05', start: (9, 0), end: (9, 45)),
      sampleSession(id: 2, date: '2026-10-06', start: (9, 0), end: (10, 0)),
      sampleSession(id: 3, date: '2026-10-07', start: (9, 0), end: (12, 0)),
    ],
    5: [
      sampleSession(
        id: 4,
        cohortId: 5,
        date: '2026-10-07',
        start: (10, 0),
        end: (11, 0),
      ),
    ],
  };

  /// The same shapes, only the short title — a week the grid can keep.
  Map<int, List<TeacherSession>> shortWeek() => {
    5: [
      sampleSession(
        id: 11,
        cohortId: 5,
        date: '2026-10-05',
        start: (9, 0),
        end: (9, 45),
      ),
      sampleSession(
        id: 12,
        cohortId: 5,
        date: '2026-10-06',
        start: (9, 0),
        end: (10, 0),
      ),
      sampleSession(
        id: 13,
        cohortId: 5,
        date: '2026-10-07',
        start: (9, 0),
        end: (12, 0),
      ),
    ],
  };

  /// Wednesday 7 October, 10:30: Monday's and Tuesday's sessions are over,
  /// Wednesday's are under way.
  DateTime wednesday() => DateTime(2026, 10, 7, 10, 30);

  /// Pumps the real screen and returns every error it raised.
  Future<List<String>> pump(
    WidgetTester tester, {
    required double width,
    required double scale,
    FakeTeacherScheduleRepository? repository,
    // Tall enough that the day list builds every card at 3.0× — it is a
    // lazy list, and the cards grew with the type scale (Issue #366).
    double height = 2600,
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
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: TeacherScheduleScreen(
            repository:
                repository ??
                FakeTeacherScheduleRepository(
                  classes: [long, short],
                  sessions: longWeek(),
                ),
            clock: wednesday,
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  bool inDayList(WidgetTester tester) {
    final list = find.byType(TeacherDaySessionList).evaluate().isNotEmpty;
    final grid = find.byType(TeacherWeekGrid).evaluate().isNotEmpty;
    expect(list, isNot(grid), reason: 'exactly one of grid and list');
    // The strip shows with the grid, the day steps with the list.
    expect(
      find.bySemanticsLabel(TeacherScheduleStrings.nextDay).evaluate().isEmpty,
      !list,
    );
    return list;
  }

  /// Whether [word], in [paragraph]'s own style and text size, fits the
  /// width [paragraph] is laid out in — read off the rendered paragraph.
  bool fitsLine(RenderParagraph paragraph, String word) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: paragraph.text.style),
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: 1,
    )..layout();
    final fits = painter.width <= paragraph.constraints.maxWidth;
    painter.dispose();
    return fits;
  }

  /// Whenever the grid shows above the default size it is legible: every
  /// block shows its time, or a title whose first line holds its first word.
  void expectLegibleGrid(WidgetTester tester) {
    for (final block in find.byType(SessionBlock).evaluate()) {
      final title = (block.widget as SessionBlock)
          .entry
          .teacherClass
          .cohort
          .course
          .title
          .preferred!;
      final texts = find
          .descendant(
            of: find.byElementPredicate((e) => e == block),
            matching: find.byType(RichText),
          )
          .evaluate()
          .map((e) => e.renderObject! as RenderParagraph)
          .toList();
      final showsTime = texts.any((p) => p.text.toPlainText().contains('\n-'));
      final titleLine = texts.where((p) => p.text.toPlainText() == title);
      final showsWord =
          titleLine.isNotEmpty &&
          fitsLine(titleLine.first, title.split(' ').first);
      expect(showsTime || showsWord, isTrue, reason: title);
    }
  }

  /// In the day list nothing is clipped: every line whole, inside the
  /// screen.
  void expectWholeList(WidgetTester tester, double width) {
    for (final element
        in find
            .descendant(
              of: find.byType(TeacherDaySessionList),
              matching: find.byType(RichText),
            )
            .evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final text = paragraph.text.toPlainText();
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
        ),
        reason: '"$text" whole',
      );
      final rect = MatrixUtils.transformRect(
        paragraph.getTransformTo(null),
        Offset.zero & paragraph.size,
      );
      expect(rect.left, greaterThanOrEqualTo(-0.01), reason: text);
      expect(rect.right, lessThanOrEqualTo(width + 0.01), reason: text);
    }
  }

  group('mode', () {
    for (final width in widths) {
      for (final scale in scales) {
        final name = '${width.toInt()} wide, text ×$scale';

        testWidgets('$name, long-titled week: '
            '${scale == 1 ? 'the grid, whatever the content' : 'the day list'}'
            ', without overflow', (tester) async {
          final errors = await pump(tester, width: width, scale: scale);
          expect(errors, isEmpty);
          if (scale == 1) {
            expect(inDayList(tester), isFalse);
            expect(find.byType(SessionBlock), findsNWidgets(4));
          } else {
            // Its 45-minute block can show neither "09:00" nor "Хиймэл".
            expect(inDayList(tester), isTrue);
            expectWholeList(tester, width);
          }
        });

        testWidgets('$name, short-titled week: the grid while it is legible, '
            'the day list once the strip no longer fits', (tester) async {
          final errors = await pump(
            tester,
            width: width,
            scale: scale,
            repository: FakeTeacherScheduleRepository(
              classes: [short],
              sessions: shortWeek(),
            ),
          );
          expect(errors, isEmpty);
          if (inDayList(tester)) {
            expect(scale, greaterThan(1));
            expectWholeList(tester, width);
          } else {
            expectLegibleGrid(tester);
          }
          // The measured switch points, recorded (Issue #357).
          // The grid to 2.0× on every width; from 2.5× its strip no longer
          // fits (the hour column has widened to 93 by then), so the list.
          final expectedList = scale >= 2.5;
          expect(inDayList(tester), expectedList);
        });
      }
    }

    testWidgets('the mode follows the week: the long-titled week is a list, '
        'the empty week after it the grid again', (tester) async {
      final repository = FakeTeacherScheduleRepository(
        classes: [long, short],
        sessions: longWeek(),
      );
      await pump(tester, width: 393, scale: 1.5, repository: repository);
      expect(inDayList(tester), isTrue);

      // Wednesday → Sunday 11 October, the next week, step by step.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.bySemanticsLabel(TeacherScheduleStrings.nextDay));
        await tester.pumpAndSettle();
      }
      expect(
        repository.sessionCalls.map((call) => call.$2),
        contains(DateTime(2026, 10, 11)),
      );
      expect(inDayList(tester), isFalse);
      expect(find.text(TeacherScheduleStrings.empty), findsOneWidget);

      // The grid's strip selects a day of the empty week; back into the
      // long-titled week through the date's previous week, the list again.
      await tester.tap(find.bySemanticsLabel('Ня 11'));
      await tester.pumpAndSettle();
      expect(inDayList(tester), isFalse);
    });

    testWidgets('the selected date carries across a change of mode', (
      tester,
    ) async {
      await pump(tester, width: 393, scale: 1.5);
      expect(inDayList(tester), isTrue);
      await tester.tap(find.bySemanticsLabel(TeacherScheduleStrings.nextDay));
      await tester.pumpAndSettle();
      expect(
        find.text(TeacherScheduleStrings.headerDate(DateTime(2026, 10, 8))),
        findsOneWidget,
      );

      // Back to the default size: the grid, with Thursday 8 still selected.
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await tester.pumpAndSettle();
      expect(inDayList(tester), isFalse);
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Пү 8')),
        isSemantics(isSelected: true, isButton: true),
      );
      semantics.dispose();
    });
  });

  group('the day list', () {
    // 393 wide at 3.0×: the list on every week.
    Future<FakeTeacherScheduleRepository> open(
      WidgetTester tester, {
      FakeTeacherScheduleRepository? repository,
    }) async {
      final fake =
          repository ??
          FakeTeacherScheduleRepository(
            classes: [long, short],
            sessions: longWeek(),
          );
      final errors = await pump(tester, width: 393, scale: 3, repository: fake);
      expect(errors, isEmpty);
      expect(inDayList(tester), isTrue);
      return fake;
    }

    String dayHeader(int day) =>
        TeacherScheduleStrings.headerDate(DateTime(2026, 10, day));

    Iterable<String> listedTimes(WidgetTester tester) => tester
        .widgetList<TeacherDaySessionCard>(find.byType(TeacherDaySessionCard))
        .map(
          (c) => '${c.entry.session.startLabel}-${c.entry.session.endLabel}',
        );

    testWidgets('lists the day\'s sessions earliest first, overlapping ones '
        'included', (tester) async {
      await open(tester);
      expect(find.text(dayHeader(7)), findsOneWidget);
      expect(listedTimes(tester), ['09:00-12:00', '10:00-11:00']);
      expect(find.text(mongolian), findsOneWidget);
      expect(find.text(room), findsOneWidget);
    });

    testWidgets('previous and next step a day, across week boundaries in '
        'both directions', (tester) async {
      final repository = await open(tester);

      await tester.tap(find.bySemanticsLabel(TeacherScheduleStrings.nextDay));
      await tester.pumpAndSettle();
      expect(find.text(dayHeader(8)), findsOneWidget);
      expect(find.text(TeacherScheduleStrings.emptyDay), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.bySemanticsLabel(TeacherScheduleStrings.previousDay),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text(dayHeader(6)), findsOneWidget);
      expect(listedTimes(tester), ['09:00-10:00']);

      // Sunday 4 → Saturday 3: the week before loads.
      for (var i = 0; i < 3; i++) {
        await tester.tap(
          find.bySemanticsLabel(TeacherScheduleStrings.previousDay),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text(dayHeader(3)), findsOneWidget);
      expect(
        repository.sessionCalls.map((call) => call.$2),
        contains(DateTime(2026, 9, 27)),
      );
      // Forward past Saturday 10 → Sunday 11: the week after loads.
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.bySemanticsLabel(TeacherScheduleStrings.nextDay));
        await tester.pumpAndSettle();
      }
      expect(find.text(dayHeader(11)), findsOneWidget);
      expect(
        repository.sessionCalls.map((call) => call.$2),
        contains(DateTime(2026, 10, 11)),
      );
    });

    testWidgets('an empty day says so; the date picker is still there', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel(TeacherScheduleStrings.nextDay));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherDaySessionCard), findsNothing);
      expect(find.text(TeacherScheduleStrings.emptyDay), findsOneWidget);
      expect(find.text(TeacherScheduleStrings.empty), findsNothing);
      expect(
        find.bySemanticsLabel(
          '${TeacherScheduleStrings.pickDate}, ${dayHeader(8)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a finished session says "Дууссан" and is muted; one under '
        'way is neither', (tester) async {
      await open(tester);
      // Wednesday's sessions are under way.
      expect(find.text(TeacherScheduleStrings.finished), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TeacherDaySessionCard),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );

      await tester.tap(
        find.bySemanticsLabel(TeacherScheduleStrings.previousDay),
      );
      await tester.pumpAndSettle();
      expect(find.text(TeacherScheduleStrings.finished), findsOneWidget);
      final muted = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(TeacherDaySessionCard),
          matching: find.byType(Opacity),
        ),
      );
      expect(muted.opacity, lessThan(1));
    });

    testWidgets('each card is one button read with its title, room, time '
        'and state, and opens its own session\'s sheet', (tester) async {
      await open(tester);
      final semantics = tester.ensureSemantics();

      SemanticsNode nodeOf(int index) =>
          tester.getSemantics(find.byType(TeacherDaySessionCard).at(index));
      final first = nodeOf(0);
      expect(first.flagsCollection.isButton, isTrue);
      expect(first.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(first.label, contains(mongolian));
      expect(first.label, contains(room));
      expect(first.label, contains('09:00-12:00'));
      expect(first.label, isNot(contains(TeacherScheduleStrings.finished)));

      // Below the first, tall card at 3.0×: scrolled into view first.
      await tester.ensureVisible(find.byType(TeacherDaySessionCard).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TeacherDaySessionCard).at(1));
      await tester.pumpAndSettle();
      final sheet = tester.widget<TeacherSessionSheet>(
        find.byType(TeacherSessionSheet),
      );
      expect(sheet.entry.session.id, 4);
      expect(sheet.held, isFalse);
      await tester.tapAt(const Offset(196, 80));
      await tester.pumpAndSettle();

      // Tuesday's, finished: its label says so, and its sheet is the held
      // one, with the attendance summary.
      await tester.tap(
        find.bySemanticsLabel(TeacherScheduleStrings.previousDay),
      );
      await tester.pumpAndSettle();
      expect(nodeOf(0).label, contains(TeacherScheduleStrings.finished));
      await tester.tap(find.byType(TeacherDaySessionCard));
      await tester.pumpAndSettle();
      final held = tester.widget<TeacherSessionSheet>(
        find.byType(TeacherSessionSheet),
      );
      expect(held.entry.session.id, 2);
      expect(held.held, isTrue);
      expect(find.byType(SessionAttendanceSummary), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('loading shows the spinner, then the day', (tester) async {
      final repository = FakeTeacherScheduleRepository(
        classes: [long, short],
        sessions: longWeek(),
        hold: true,
      );
      useLogicalViewport(tester, const Size(393, 2600), padding: iPhonePadding);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TeacherScheduleScreen(repository: repository, clock: wednesday),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The strip cannot fit at 3.0×: the day list's controls already.
      expect(
        find.bySemanticsLabel(TeacherScheduleStrings.nextDay),
        findsOneWidget,
      );

      repository.release();
      await tester.pumpAndSettle();
      expect(find.byType(TeacherDaySessionCard), findsNWidgets(2));
    });

    testWidgets('a failure shows its message, and retry loads again', (
      tester,
    ) async {
      final repository = FakeTeacherScheduleRepository(
        classes: [long, short],
        sessions: longWeek(),
        failure: const TeacherFailure(TeacherFailureKind.network),
      );
      await pump(tester, width: 393, scale: 3, repository: repository);
      expect(find.text(TeacherHomeStrings.retry), findsOneWidget);
      expect(find.byType(TeacherDaySessionCard), findsNothing);

      repository.failure = null;
      await tester.tap(find.text(TeacherHomeStrings.retry));
      await tester.pumpAndSettle();
      expect(find.byType(TeacherDaySessionCard), findsNWidgets(2));
    });

    testWidgets('pulling down refreshes the day', (tester) async {
      final repository = await open(tester);
      final before = repository.classCalls;
      // RefreshIndicator arms at a quarter of the viewport's height, so the
      // pull is sized to the test's tall viewport (see [pump]).
      await tester.fling(
        find.byType(TeacherDaySessionList),
        const Offset(0, 1000),
        1000,
      );
      await tester.pumpAndSettle();
      expect(repository.classCalls, before + 1);
      expect(find.byType(TeacherDaySessionCard), findsNWidgets(2));
    });

    testWidgets('golden: the day list at 2.0× on the reference phone', (
      tester,
    ) async {
      await pump(tester, width: 393, scale: 2, height: 852);
      expect(inDayList(tester), isTrue);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../goldens/teacher_schedule_day_list.png'),
      );
    });
  });
}
