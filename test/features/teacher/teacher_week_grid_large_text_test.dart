import 'package:aia_mobile/core/models/localized_text.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/cohorts/domain/cohort.dart';
import 'package:aia_mobile/features/teacher/domain/teacher_class.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_session_sheet.dart';
import 'package:aia_mobile/features/teacher/presentation/widgets/teacher_week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import '../cohorts/fake_cohort_repository.dart';
import 'fake_teacher_schedule_repository.dart';

/// The Teacher Schedule week grid at narrow widths and larger system text
/// sizes (Issue #355). Hour labels used to wrap mid-number from 2.0×
/// ("07:0 / 0"), and a session block's two-line time — drawn whenever the
/// block was 48 tall, whatever its width — broke mid-number, hid the title
/// and overflowed the block, even at the default size on 320- and 375-wide
/// phones. Now the hour column grows with its labels, and a block shows its
/// time and title only where they fit, measured; otherwise no text.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0];
  const mongolian = 'Хиймэл оюун ухааны инженерчлэлийн ахисан түвшний сургалт';

  /// The title the grid is checked with. At the default size the grid
  /// always shows, so the long Mongolian title. Above it that title leaves
  /// the grid illegible and the screen shows the day list instead (Issue
  /// #357, covered there), so the grid's own checks use a title it keeps —
  /// its first word fits every block.
  String titleAt(double scale) => scale == 1 ? mongolian : 'AI Engineer';

  TeacherClass classWith(String title) => TeacherClass(
    cohort: sampleCohort(
      id: 2,
      name: 'Cohort 01',
      course: CohortCourse(
        id: 8,
        slug: 'ai-engineering',
        title: LocalizedText(mn: title),
      ),
      startTime: '09:00',
      endTime: '10:00',
      startDate: '2026-09-01',
      endDate: '2026-12-20',
      meetingDays: const ['mon', 'tue', 'wed'],
    ),
    track: 'adult',
  );

  /// A 45-minute, a 1-hour and a 3-hour session, Monday to Wednesday.
  final sessions = [
    sampleSession(id: 1, date: '2026-10-05', start: (9, 0), end: (9, 45)),
    sampleSession(id: 2, date: '2026-10-06', start: (9, 0), end: (10, 0)),
    sampleSession(id: 3, date: '2026-10-07', start: (9, 0), end: (12, 0)),
  ];

  /// The screen-reader labels — the full title and times, always.
  List<String> labelsFor(String title) => [
    '$title, 09:00-09:45',
    '$title, 09:00-10:00',
    '$title, 09:00-12:00',
  ];

  /// Pumps the real screen, the week before the sessions, tall enough to lay
  /// out the whole grid; returns every error it raised.
  Future<List<String>> pump(
    WidgetTester tester, {
    required double width,
    required double scale,
  }) async {
    useLogicalViewport(tester, Size(width, 2400), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TeacherScheduleScreen(
            repository: FakeTeacherScheduleRepository(
              classes: [classWith(titleAt(scale))],
              sessions: {2: sessions},
            ),
            clock: () => DateTime(2026, 10, 4, 7),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  RenderParagraph paragraphOf(Element element) =>
      element.renderObject! as RenderParagraph;

  /// The lines [paragraph] lays out, from its own text, scaler, line limit
  /// and width.
  List<LineMetrics> linesOf(RenderParagraph paragraph) {
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      textAlign: paragraph.textAlign,
      maxLines: paragraph.maxLines,
      ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    )..layout(maxWidth: paragraph.constraints.maxWidth);
    final lines = painter.computeLineMetrics();
    painter.dispose();
    return lines;
  }

  Rect rectOf(RenderParagraph paragraph) =>
      paragraph.localToGlobal(Offset.zero) & paragraph.size;

  for (final width in widths) {
    for (final scale in scales) {
      final name = '${width.toInt()} wide, text ×$scale';

      testWidgets('$name: hour labels on one line, block text whole and '
          'inside its block, times never broken, labels read in full', (
        tester,
      ) async {
        final errors = await pump(tester, width: width, scale: scale);
        expect(errors, isEmpty);

        final grid = find.byType(TeacherWeekGrid);
        final gridRect = tester.getRect(grid);
        final timeColumn = timeColumnWidthOf(tester.element(grid));

        // Hour labels: one line each, inside the hour column, clear of the
        // next row's label.
        final hours = [
          for (var hour = 7; hour < 23; hour++)
            paragraphOf(tester.element(find.text(hourLabel(hour)))),
        ];
        for (final (i, label) in hours.indexed) {
          final text = label.text.toPlainText();
          expect(linesOf(label), hasLength(1), reason: text);
          final rect = rectOf(label);
          expect(rect.left, greaterThanOrEqualTo(gridRect.left), reason: text);
          expect(
            rect.right,
            lessThanOrEqualTo(gridRect.left + timeColumn),
            reason: text,
          );
          if (i + 1 < hours.length) {
            expect(
              rect.bottom,
              lessThanOrEqualTo(rectOf(hours[i + 1]).top),
              reason: '$text clears the next label',
            );
          }
        }

        // The strip's days line up with the grid's day columns.
        final firstDay = tester.getRect(
          find
              .ancestor(
                of: find.text(TeacherScheduleStrings.weekdays.first),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(
          firstDay.left,
          moreOrLessEquals(gridRect.left + timeColumn, epsilon: 0.01),
        );

        // Every block: its text inside it, the time as exactly its two
        // lines, the title in whole lines; and read out in full.
        final blocks = find.byType(SessionBlock).evaluate().toList();
        expect(blocks, hasLength(3));
        for (final block in blocks) {
          final blockFinder = find.byElementPredicate((e) => e == block);
          final blockRect = tester.getRect(blockFinder);
          for (final element
              in find
                  .descendant(of: blockFinder, matching: find.byType(RichText))
                  .evaluate()) {
            final paragraph = paragraphOf(element);
            final text = paragraph.text.toPlainText();
            final rect = rectOf(paragraph);
            expect(rect.left, greaterThanOrEqualTo(blockRect.left - 0.01));
            expect(rect.right, lessThanOrEqualTo(blockRect.right + 0.01));
            expect(rect.top, greaterThanOrEqualTo(blockRect.top - 0.01));
            expect(rect.bottom, lessThanOrEqualTo(blockRect.bottom + 0.01));
            final lines = linesOf(paragraph);
            if (text.contains('\n-')) {
              expect(lines, hasLength(2), reason: '"$text" never breaks');
            }
            // Whole lines only: every line it draws fits inside its box (a
            // title's box is the space the time leaves).
            final drawn = lines.fold<double>(0, (sum, l) => sum + l.height);
            expect(
              drawn,
              lessThanOrEqualTo(paragraph.size.height + 0.01),
              reason: text,
            );
          }
        }
        for (final label in labelsFor(titleAt(scale))) {
          expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
        }
      });

      testWidgets('$name: the smallest block still opens its session', (
        tester,
      ) async {
        await pump(tester, width: width, scale: scale);
        await tester.tap(
          find.bySemanticsLabel(labelsFor(titleAt(scale)).first),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TeacherSessionSheet), findsOneWidget);
      });
    }
  }

  testWidgets('default size on the reference phone: the 64 hour column, '
      'the 3-hour block with its title and time as before', (tester) async {
    final errors = await pump(tester, width: 393, scale: 1);
    expect(errors, isEmpty);
    expect(timeColumnWidthOf(tester.element(find.byType(TeacherWeekGrid))), 64);
    // The 3-hour block keeps its two-line time and title.
    expect(find.text('09:00\n-12:00'), findsOneWidget);
    final long = find.descendant(
      of: find.bySemanticsLabel(labelsFor(mongolian).last),
      matching: find.text(mongolian),
    );
    expect(long, findsOneWidget);
  });

  testWidgets('a time that cannot fit its block is hidden, not broken', (
    tester,
  ) async {
    // 320 wide at 1.0: a block's 26pt is narrower than "09:00".
    final errors = await pump(tester, width: 320, scale: 1);
    expect(errors, isEmpty);
    expect(find.textContaining('\n-'), findsNothing);
  });

  testWidgets('the hour column grows at 2.0×, keeping HH:mm', (tester) async {
    await pump(tester, width: 393, scale: 2);
    final timeColumn = timeColumnWidthOf(
      tester.element(find.byType(TeacherWeekGrid)),
    );
    expect(timeColumn, greaterThan(64));
    expect(find.text('07:00'), findsOneWidget);
  });
}
