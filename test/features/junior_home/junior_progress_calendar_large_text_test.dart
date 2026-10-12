import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_progress.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_progress_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// The progress calendar at larger system text sizes (Issue #361). A day
/// cell was a fixed 58 tall — 4 + the 32 disc + 1 + the number's 16 line,
/// with 5 to spare — so from 1.5× the number's line overflowed it (3px at
/// 1.5×, 11px at 2.0×). Now 58 is a minimum: every cell, blank or not,
/// grows by what the scaled line needs, so the rows stay even. Where an
/// enlarged weekday letter or day number is wider than its narrow column
/// (320 at 3.0×) it is scaled to fit on one line, not wrapped or cut.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0, 3.0];

  /// The Junior screen's 16 page margin, 2 panel edge and 6 calendar inset
  /// — the narrower of the calendar's two homes (Adult attendance's card
  /// edge is thinner).
  const sideInset = 16.0 + 2 + 6;

  // August 2026 starts on a Saturday: six rows, with a full row of leading
  // blanks before the 1st and a 31st on its own row.
  final month = DateTime(2026, 8);
  const days = {
    3: JuniorDayStatus.attended,
    12: JuniorDayStatus.lesson,
    20: JuniorDayStatus.missed,
  };

  /// Pumps the calendar at the Junior screen's width and returns every
  /// error it raised.
  Future<List<String>> pump(
    WidgetTester tester, {
    required double width,
    required double scale,
    Color? missedRing,
  }) async {
    useLogicalViewport(tester, Size(width, 1600), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: sideInset),
              child: JuniorProgressCalendar(
                month: month,
                selectedDay: 31,
                days: days,
                missedRing: missedRing,
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

  Finder textIn(String text) => find.descendant(
    of: find.byType(JuniorProgressCalendar),
    matching: find.text(text),
  );

  /// The day cell around [day]'s number: its nearest decorated Container.
  Rect cellOf(WidgetTester tester, int day) => tester.getRect(
    find.ancestor(of: textIn('$day'), matching: find.byType(Container)).first,
  );

  /// The lines [paragraph] lays out at its own width.
  List<LineMetrics> linesOf(RenderParagraph paragraph) {
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: paragraph.maxLines,
    )..layout(maxWidth: paragraph.constraints.maxWidth);
    final lines = painter.computeLineMetrics();
    painter.dispose();
    return lines;
  }

  /// Checks [paragraph] holds its whole text on one line: its box is at
  /// least as large as the text laid out with no width limit, so nothing of
  /// it is wrapped or cut.
  void expectWhole(RenderParagraph paragraph) {
    final text = paragraph.text.toPlainText();
    expect(linesOf(paragraph), hasLength(1), reason: '"$text" on one line');
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
    )..layout();
    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(painter.width - 0.01),
      reason: '"$text" not cut',
    );
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(painter.height - 0.01),
      reason: '"$text" drawn whole',
    );
    painter.dispose();
  }

  for (final width in widths) {
    for (final scale in scales) {
      final name = '${width.toInt()} wide, text ×$scale';

      testWidgets('$name: no layout errors, every day number whole on one '
          'line inside its cell, and the rows even', (tester) async {
        final errors = await pump(tester, width: width, scale: scale);
        expect(errors, isEmpty);

        // Text that fits is the plain Text, as before; only where it cannot
        // (the W and the two-digit days at 320 / 3.0×) is it scaled to fit.
        // (The marks' SVGs bring FittedBoxes of their own: only those over
        // text count.)
        final fitted = find.ancestor(
          of: find.descendant(
            of: find.byType(JuniorProgressCalendar),
            matching: find.byType(RichText),
          ),
          matching: find.byType(FittedBox),
        );
        if (scale == 1) expect(fitted, findsNothing);
        if (width == 320 && scale == 3) expect(fitted, findsWidgets);

        final cells = [for (var d = 1; d <= 31; d++) cellOf(tester, d)];
        final height = cells.first.height;
        expect(height, greaterThanOrEqualTo(58));
        if (scale == 1) expect(height, 58);

        for (final (i, cell) in cells.indexed) {
          final day = i + 1;
          expect(cell.height, height, reason: 'day $day as tall as the rest');

          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: textIn('$day'),
              matching: find.byType(RichText),
            ),
          );
          expectWhole(paragraph);
          final box = tester.getRect(textIn('$day'));
          expect(box.top, greaterThanOrEqualTo(cell.top), reason: '$day');
          expect(box.bottom, lessThanOrEqualTo(cell.bottom + 0.01));
          expect(box.left, greaterThanOrEqualTo(cell.left - 0.01));
          expect(box.right, lessThanOrEqualTo(cell.right + 0.01));
        }

        // The weekday letters: whole, each inside its own column (over its
        // column's day cells), all above the first row.
        final calendar = tester.getRect(find.byType(JuniorProgressCalendar));
        final letters = find
            .descendant(
              of: find.byType(JuniorProgressCalendar),
              matching: find.byType(RichText),
            )
            .evaluate()
            .take(DateTime.daysPerWeek)
            .toList();
        // August 2026's 2nd is a Sunday: days 2…8 fill the columns in order.
        for (final (c, letter) in letters.indexed) {
          final paragraph = letter.renderObject! as RenderParagraph;
          expectWhole(paragraph);
          // As drawn: through the FittedBox's scale.
          final box = MatrixUtils.transformRect(
            paragraph.getTransformTo(null),
            Offset.zero & paragraph.size,
          );
          final column = cells[c + 1];
          expect(box.left, greaterThanOrEqualTo(column.left - 0.01));
          expect(box.right, lessThanOrEqualTo(column.right + 0.01));
          expect(box.top, greaterThanOrEqualTo(calendar.top - 0.01));
          expect(box.bottom, lessThanOrEqualTo(cells[1].top));
        }
      });
    }
  }

  testWidgets('1.0× on the reference phone: the default layout is unchanged '
      '— 58-tall cells, the disc 4 from the top, the number 1 under it', (
    tester,
  ) async {
    final errors = await pump(tester, width: 393, scale: 1);
    expect(errors, isEmpty);

    final cell = cellOf(tester, 12);
    expect(cell.height, 58);
    final disc = tester.getRect(
      find.descendant(
        of: find
            .ancestor(of: textIn('12'), matching: find.byType(Container))
            .first,
        matching: find.byType(JuniorDayMark),
      ),
    );
    expect(disc.top - cell.top, 4);
    expect(disc.size, const Size.square(32));
    final number = tester.getRect(textIn('12'));
    expect(number.top - disc.bottom, 1);
    expect(number.height, 16);
    expect(cell.bottom - number.bottom, 5);

    // Six rows of 58 with 6 between, under the 16 weekday line and its 12.
    expect(
      tester.getSize(find.byType(JuniorProgressCalendar)).height,
      16 + 12 + 6 * 58 + 5 * 6,
    );
  });

  testWidgets('2.0×: the cells grow by exactly the number line\'s growth, '
      'and the disc and the 5 under the number keep their places', (
    tester,
  ) async {
    final errors = await pump(
      tester,
      width: 393,
      scale: 2,
      missedRing: Colors.red,
    );
    expect(errors, isEmpty);

    final cell = cellOf(tester, 20);
    // The number's 16 line is 32 at 2.0×: 16 more than at 1.0×.
    expect(cell.height, 58 + 16);
    final number = tester.getRect(textIn('20'));
    expect(number.height, 32);
    expect(cell.bottom - number.bottom, 5);
  });
}
