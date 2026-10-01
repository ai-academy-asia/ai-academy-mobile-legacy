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

      // 8, 12, 16, 19, 24 and 27 are lesson days; 4 is the missed one.
      expect(svgCount(JuniorProgressIcons.lessonDay), 6);
      expect(svgCount(JuniorProgressIcons.lessonMissed), 1);
      expect(
        find.descendant(of: grid, matching: find.byType(SvgPicture)),
        findsNWidgets(7),
      );
      // The attended 1st is the one raster mark — see the next test.
      expect(
        find.descendant(of: grid, matching: find.byType(Image)),
        findsOneWidget,
      );
    });

    testWidgets('an attended day draws its PNG on a ringed blue disc', (
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

      final image = tester.widget<Image>(
        find.descendant(of: attended, matching: find.byType(Image)),
      );
      expect(
        (image.image as AssetImage).assetName,
        JuniorProgressIcons.lessonAttended,
      );
      expect(image.width, 16);
      expect(image.height, 15);
      expect(image.fit, BoxFit.contain);
      // Through Image, not flutter_svg, and no substitute glyph.
      expect(
        find.descendant(of: attended, matching: find.byType(SvgPicture)),
        findsNothing,
      );
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

    testWidgets('the attended PNG decodes, with its A and its sparkle', (
      tester,
    ) async {
      final bytes = File(JuniorProgressIcons.lessonAttended).readAsBytesSync();
      final pixels = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        return (image.width, image.height, data!);
      });
      final (width, height, data) = pixels!;
      // The design's 63 x 54 viewBox at 2x.
      expect((width, height), (126, 108));

      var light = 0, orange = 0, transparent = 0;
      for (var i = 0; i < data.lengthInBytes; i += 4) {
        final r = data.getUint8(i), g = data.getUint8(i + 1);
        final b = data.getUint8(i + 2), a = data.getUint8(i + 3);
        if (a == 0) {
          transparent++;
        } else if (a > 200 && r > 0xE0 && g > 0xE0 && b > 0xF0) {
          light++;
        } else if (a > 200 && r > 0xE0 && g < 0x80 && b < 0x60) {
          orange++;
        }
      }
      expect(light, greaterThan(500), reason: 'the near-white A');
      expect(orange, greaterThan(20), reason: 'the orange sparkle');
      expect(transparent, greaterThan(0), reason: 'a transparent ground');
    });
  });

  testWidgets('the legend draws all three marks', (tester) async {
    await pumpScreen(tester);

    final legend = find.byWidgetPredicate(
      (w) => w is JuniorDayMark && w.size == 24,
    );
    final legendMarks = tester.widgetList<JuniorDayMark>(legend);
    expect(legendMarks.map((mark) => mark.status), [
      JuniorDayStatus.lesson,
      JuniorDayStatus.missed,
      JuniorDayStatus.attended,
    ]);
    // The legend's attended disc is the plain one, without the ring.
    expect(legendMarks.last.ringed, isFalse);

    expect(
      tester
          .widgetList<SvgPicture>(
            find.descendant(of: legend, matching: find.byType(SvgPicture)),
          )
          .map((svg) => (svg.bytesLoader as SvgAssetLoader).assetName),
      [JuniorProgressIcons.lessonDay, JuniorProgressIcons.lessonMissed],
    );
    final attendedImage = tester.widget<Image>(
      find.descendant(of: legend.last, matching: find.byType(Image)),
    );
    expect(
      (attendedImage.image as AssetImage).assetName,
      JuniorProgressIcons.lessonAttended,
    );
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
