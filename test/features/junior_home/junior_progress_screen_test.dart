import 'dart:io';
import 'dart:ui' as ui;

import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/junior_home/data/sample_junior_progress.dart';
import 'package:aia_mobile/features/junior_home/domain/junior_progress.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_home_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_screen.dart';
import 'package:aia_mobile/features/junior_home/presentation/junior_progress_strings.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_home_palette.dart';
import 'package:aia_mobile/features/junior_home/presentation/widgets/junior_progress_calendar.dart';
import 'package:aia_mobile/shared/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// Junior "Сурлагын явц" against the frame's own design state.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpScreen(
    WidgetTester tester, {
    JuniorProgress? progress,
    Size size = const Size(393, 852),
  }) async {
    useLogicalViewport(tester, size, padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JuniorProgressScreen(progress: progress),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The whole page is in the tree — it is one non-lazy scroll view — so
  /// nothing below the fold needs scrolling to before it can be found.
  testWidgets('renders without overflowing a phone viewport', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(JuniorProgressScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draws every line of the frame\'s copy', (tester) async {
    await pumpScreen(tester);

    for (final text in [
      JuniorProgressStrings.contractTitle,
      JuniorProgressStrings.paymentTitle,
      '3 хоног дутуу',
      JuniorProgressStrings.payAction,
      JuniorProgressStrings.attendance,
      JuniorProgressStrings.exam,
      '1/20 · 10%',
      '0%',
      JuniorProgressStrings.nextLesson,
      '08/08 • 09:00 – 11:00',
      'Наймдугаар сар, 2026',
      JuniorProgressStrings.legendTitle,
      JuniorProgressStrings.legendHint,
      JuniorProgressStrings.lessonDay,
      JuniorProgressStrings.lessonMissed,
      JuniorProgressStrings.lessonAttended,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // The banner and the payment card both ask the child to show a parent.
    expect(find.text('Эцэг эхдээ үзүүлнэ үү 😊'), findsNWidgets(2));
  });

  testWidgets('a signed contract hides the banner', (tester) async {
    final reference = SampleJuniorProgress.reference;
    await pumpScreen(
      tester,
      progress: JuniorProgress(
        contractSigned: true,
        paymentDaysLeft: reference.paymentDaysLeft,
        attendedLessons: reference.attendedLessons,
        totalLessons: reference.totalLessons,
        attendancePercent: reference.attendancePercent,
        examPercent: reference.examPercent,
        nextLessonStart: reference.nextLessonStart,
        nextLessonEnd: reference.nextLessonEnd,
        month: reference.month,
        selectedDay: reference.selectedDay,
        days: reference.days,
      ),
    );

    expect(find.text(JuniorProgressStrings.contractTitle), findsNothing);
    expect(find.text(JuniorProgressStrings.paymentTitle), findsOneWidget);
  });

  group('bottom navigation', () {
    testWidgets('Сурлагын явц is the selected tab', (tester) async {
      await pumpScreen(tester);

      final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav.currentIndex, 1);
      expect(nav.items.map((item) => item.label), [
        JuniorHomeStrings.navHome,
        JuniorHomeStrings.navProgress,
        JuniorHomeStrings.navProfile,
      ]);
      // Already here: the selected tab does nothing; the other two navigate.
      expect(nav.items[1].onTap, isNull);
      expect(nav.items[0].onTap, isNotNull);
      expect(nav.items[2].onTap, isNotNull);

      Color labelColour(String text) =>
          tester.widget<Text>(find.text(text)).style!.color!;
      expect(labelColour(JuniorHomeStrings.navProgress), JuniorPalette.accent);
      expect(
        labelColour(JuniorHomeStrings.navHome),
        isNot(JuniorPalette.accent),
      );
      expect(
        labelColour(JuniorHomeStrings.navProfile),
        isNot(JuniorPalette.accent),
      );
    });
  });

  group('calendar', () {
    JuniorProgressCalendar calendar(WidgetTester tester) =>
        tester.widget(find.byType(JuniorProgressCalendar));

    testWidgets('is the real August 2026: 31 days, the 1st a Saturday', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(calendar(tester).month, DateTime(2026, 8));
      final grid = find.byType(JuniorProgressCalendar);
      for (var day = 1; day <= 31; day++) {
        expect(
          find.descendant(of: grid, matching: find.text('$day')),
          findsOneWidget,
          reason: 'day $day',
        );
      }
      expect(
        find.descendant(of: grid, matching: find.text('32')),
        findsNothing,
      );

      // Saturday is the last column: the 1st sits under the last weekday
      // letter, and the 2nd starts the next row under the first.
      final saturday = tester.getCenter(
        find.descendant(of: grid, matching: find.text('S')).last,
      );
      final sunday = tester.getCenter(
        find.descendant(of: grid, matching: find.text('S')).first,
      );
      final first = tester.getCenter(
        find.descendant(of: grid, matching: find.text('1')),
      );
      final second = tester.getCenter(
        find.descendant(of: grid, matching: find.text('2')),
      );
      expect(first.dx, moreOrLessEquals(saturday.dx, epsilon: 0.5));
      expect(second.dx, moreOrLessEquals(sunday.dx, epsilon: 0.5));
      expect(second.dy, greaterThan(first.dy));
    });

    testWidgets('the selected day and its weekday are drawn in blue', (
      tester,
    ) async {
      await pumpScreen(tester);
      final grid = find.byType(JuniorProgressCalendar);

      Color colourOf(String text) => tester
          .widget<Text>(find.descendant(of: grid, matching: find.text(text)))
          .style!
          .color!;
      expect(colourOf('7'), JuniorPalette.accent);
      expect(colourOf('8'), AppColors.textSecondary);
      // 7 August 2026 is a Friday.
      expect(colourOf('F'), JuniorPalette.accent);
      expect(colourOf('W'), AppColors.textSecondary);
    });

    testWidgets('marks each day with the supplied artwork', (tester) async {
      await pumpScreen(tester);
      final grid = find.byType(JuniorProgressCalendar);

      int svgCount(String asset) => tester
          .widgetList<SvgPicture>(
            find.descendant(of: grid, matching: find.byType(SvgPicture)),
          )
          .where(
            (svg) => (svg.bytesLoader as SvgAssetLoader).assetName == asset,
          )
          .length;

      // 8, 12, 16, 19, 24 and 27 are lesson days; 4 is the missed one;
      // the 1st is the attended one.
      expect(svgCount(JuniorProgressIcons.lessonDay), 6);
      expect(svgCount(JuniorProgressIcons.lessonMissed), 1);
      expect(svgCount(JuniorProgressIcons.lessonAttended), 1);
      // And nothing else draws artwork.
      expect(
        find.descendant(of: grid, matching: find.byType(SvgPicture)),
        findsNWidgets(8),
      );
    });

    testWidgets('an attended day draws its SVG on a ringed blue disc', (
      tester,
    ) async {
      await pumpScreen(tester);
      final grid = find.byType(JuniorProgressCalendar);

      final attended = find.descendant(
        of: grid,
        matching: find.byWidgetPredicate(
          (w) => w is JuniorDayMark && w.status == JuniorDayStatus.attended,
        ),
      );
      expect(attended, findsOneWidget);
      expect(tester.widget<JuniorDayMark>(attended).ringed, isTrue);

      final svg = tester.widget<SvgPicture>(
        find.descendant(of: attended, matching: find.byType(SvgPicture)),
      );
      expect(
        (svg.bytesLoader as SvgAssetLoader).assetName,
        JuniorProgressIcons.lessonAttended,
      );
      expect(svg.width, 16);
      expect(svg.height, 15);
      expect(
        find.descendant(of: attended, matching: find.byType(Icon)),
        findsNothing,
      );

      // A solid blue disc inside the ring.
      final discs = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: attended, matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>();
      expect(
        discs.any(
          (d) => d.color == JuniorPalette.accent && d.shape == BoxShape.circle,
        ),
        isTrue,
      );
      expect(
        find.bySemanticsLabel(JuniorProgressStrings.lessonAttended),
        findsWidgets,
      );
    });

    testWidgets('the attended SVG is pure vector and actually paints', (
      tester,
    ) async {
      final file = File('assets/icons/junior_lesson_attended.svg');
      final source = file.readAsStringSync();
      expect(source, contains('<path'));
      // A raster wrapped in a pattern parses but paints nothing in
      // flutter_svg — the reason the supplied export could not be used.
      expect(source, isNot(contains('<pattern')));
      expect(source, isNot(contains('<image')));
      expect(source, isNot(contains('base64')));

      final painted = await tester.runAsync(() async {
        final info = await vg.loadPicture(
          const SvgAssetLoader(JuniorProgressIcons.lessonAttended),
          null,
        );
        final image = await info.picture.toImage(16, 15);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        var count = 0;
        for (var i = 3; i < data!.lengthInBytes; i += 4) {
          if (data.getUint8(i) > 0) count++;
        }
        return count;
      });
      expect(painted, greaterThan(0));
    });
  });

  testWidgets('the legend draws all three marks', (tester) async {
    await pumpScreen(tester);

    final legendMarks = tester
        .widgetList<JuniorDayMark>(find.byType(JuniorDayMark))
        .where((mark) => mark.size == 24);
    expect(legendMarks.map((mark) => mark.status), [
      JuniorDayStatus.lesson,
      JuniorDayStatus.missed,
      JuniorDayStatus.attended,
    ]);
    // The legend's attended disc is the plain one, without the ring.
    expect(legendMarks.last.ringed, isFalse);

    final legendAssets = tester
        .widgetList<SvgPicture>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is JuniorDayMark && w.size == 24,
            ),
            matching: find.byType(SvgPicture),
          ),
        )
        .map((svg) => (svg.bytesLoader as SvgAssetLoader).assetName);
    expect(legendAssets, [
      JuniorProgressIcons.lessonDay,
      JuniorProgressIcons.lessonMissed,
      JuniorProgressIcons.lessonAttended,
    ]);
  });

  testWidgets('keeps a phone-width column on a desktop window', (tester) async {
    await pumpScreen(tester, size: const Size(1200, 900));

    final panelWidth = tester
        .getSize(find.byType(JuniorProgressCalendar))
        .width;
    expect(panelWidth, lessThanOrEqualTo(480));
    expect(tester.takeException(), isNull);
  });
}
