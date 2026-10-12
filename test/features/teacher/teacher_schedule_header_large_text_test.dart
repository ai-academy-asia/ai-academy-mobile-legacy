import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:aia_mobile/features/teacher/presentation/teacher_schedule_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_teacher_schedule_repository.dart';
import 'teacher_home_screen_test.dart' show sampleClass;

/// Teacher Schedule's date header and week strip at larger system text
/// sizes, up to 2.0× (Issue #353). Both were fixed heights — 46 and 68 —
/// so from 2.0× the date was clipped and the day numbers were cut in their
/// 30pt circles. Now both grow with their text, the date wraps beside the
/// bell, and the selected-day marker stays a circle while it fits its
/// column, becoming an upright rounded rectangle where it does not.
///
/// Beyond about 2.2× (on a 320-wide phone) the seven columns cannot hold
/// their labels at all; that needs a different day picker and is not
/// tested here.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0];

  /// 28 December: the longest header date, and the widest day numbers
  /// (27–31) in its week.
  final today = DateTime(2026, 12, 28, 9);
  final headerDate = TeacherScheduleStrings.headerDate(today);

  /// Pumps the real screen and returns every error it raised.
  Future<List<String>> pump(
    WidgetTester tester, {
    required double width,
    required double scale,
  }) async {
    useLogicalViewport(tester, Size(width, 852), padding: iPhonePadding);
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
              classes: [sampleClass()],
              sessions: const {},
            ),
            clock: () => today,
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  /// The week strip: the row the weekday labels sit in.
  Finder strip() => find
      .ancestor(
        of: find.text(TeacherScheduleStrings.weekdays.first),
        matching: find.byType(IntrinsicHeight),
      )
      .first;

  /// One day's cell: its tappable area, the column's full width.
  Finder cellOf(Finder label) =>
      find.ancestor(of: label, matching: find.byType(GestureDetector)).first;

  Finder inStrip(String text) =>
      find.descendant(of: strip(), matching: find.text(text));

  /// The day-number markers, by the day each one holds.
  Container markerOf(WidgetTester tester, int day) => tester.widget<Container>(
    find.ancestor(of: inStrip('$day'), matching: find.byType(Container)).first,
  );

  void expectWhole(WidgetTester tester, Finder text, {Rect? within}) {
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final label = paragraph.text.toPlainText();
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
      ),
      reason: '"$label" is drawn at its full height',
    );
    if (within != null) {
      final rect = tester.getRect(text);
      expect(
        rect.left,
        greaterThanOrEqualTo(within.left - 0.01),
        reason: label,
      );
      expect(rect.right, lessThanOrEqualTo(within.right + 0.01), reason: label);
      expect(rect.top, greaterThanOrEqualTo(within.top - 0.01), reason: label);
      expect(
        rect.bottom,
        lessThanOrEqualTo(within.bottom + 0.01),
        reason: label,
      );
    }
  }

  const days = [27, 28, 29, 30, 31, 1, 2];

  for (final width in widths) {
    for (final scale in scales) {
      final name = '${width.toInt()} wide, text ×$scale';

      testWidgets('$name: the date, weekday labels and day numbers are '
          'whole, nothing overflows, and the bell stays on the band', (
        tester,
      ) async {
        final errors = await pump(tester, width: width, scale: scale);
        expect(errors, isEmpty);

        // The header: the date whole and left of the bell, the bell on
        // screen.
        final date = find.text(headerDate);
        expectWhole(tester, date);
        final bell = tester.getRect(
          find.bySemanticsLabel(TeacherScheduleStrings.notifications),
        );
        expect(bell.right, lessThanOrEqualTo(width));
        expect(tester.getRect(date).right, lessThanOrEqualTo(bell.left));

        // The strip: every label and number whole, inside its own column.
        final stripRect = tester.getRect(strip());
        for (final (index, weekday)
            in TeacherScheduleStrings.weekdays.indexed) {
          final label = inStrip(weekday);
          final cell = tester.getRect(cellOf(label));
          expect(cell.top, moreOrLessEquals(stripRect.top));
          expect(cell.bottom, moreOrLessEquals(stripRect.bottom));
          expectWhole(tester, label, within: cell);
          expectWhole(tester, inStrip('${days[index]}'), within: cell);
        }

        // The selected day's marker holds its number and fits its column;
        // a circle exactly when it is square.
        final selected = markerOf(tester, 28);
        final decoration = selected.decoration! as BoxDecoration;
        final box = tester.getRect(
          find
              .ancestor(of: inStrip('28'), matching: find.byType(Container))
              .first,
        );
        final column = tester.getRect(cellOf(inStrip('28')));
        expect(box.width, lessThanOrEqualTo(column.width + 0.01));
        expectWhole(tester, inStrip('28'), within: box);
        if (box.width == box.height) {
          expect(decoration.shape, BoxShape.circle);
        } else {
          expect(box.height, greaterThan(box.width));
          expect(decoration.shape, BoxShape.rectangle);
          expect(decoration.borderRadius, isNotNull);
        }
      });
    }
  }

  testWidgets('default size: the 46 header row, the 68 strip and the 30 '
      'circle, as before', (tester) async {
    final errors = await pump(tester, width: 393, scale: 1);
    expect(errors, isEmpty);

    expect(tester.getSize(strip()).height, 68);
    final selected = tester.getSize(
      find.ancestor(of: inStrip('28'), matching: find.byType(Container)).first,
    );
    expect(selected, const Size.square(30));
    expect(
      (markerOf(tester, 28).decoration! as BoxDecoration).shape,
      BoxShape.circle,
    );
    // The header band: the status-bar inset, then the 46 row.
    final date = tester.getRect(find.text(headerDate));
    expect(
      date.center.dy,
      moreOrLessEquals(iPhonePadding.top + 46 / 2, epsilon: 0.5),
    );
  });

  testWidgets('320 wide, text ×2.0: the long date wraps beside the bell, '
      'and the selected marker is an upright rounded rectangle', (
    tester,
  ) async {
    final errors = await pump(tester, width: 320, scale: 2);
    expect(errors, isEmpty);

    final date = tester.renderObject<RenderParagraph>(find.text(headerDate));
    final oneLine = date.getMaxIntrinsicHeight(double.infinity);
    expect(date.size.height, greaterThan(oneLine), reason: 'wrapped');

    final marker = tester.getSize(
      find.ancestor(of: inStrip('28'), matching: find.byType(Container)).first,
    );
    expect(marker.height, greaterThan(marker.width));
    expect(
      (markerOf(tester, 28).decoration! as BoxDecoration).shape,
      BoxShape.rectangle,
    );
  });

  testWidgets('393 wide, text ×2.0: the marker grows but stays a circle', (
    tester,
  ) async {
    final errors = await pump(tester, width: 393, scale: 2);
    expect(errors, isEmpty);
    final marker = tester.getSize(
      find.ancestor(of: inStrip('28'), matching: find.byType(Container)).first,
    );
    expect(marker.width, marker.height);
    expect(marker.width, greaterThan(30));
    expect(
      (markerOf(tester, 28).decoration! as BoxDecoration).shape,
      BoxShape.circle,
    );
  });
}
