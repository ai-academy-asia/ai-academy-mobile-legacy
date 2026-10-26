import 'package:aia_mobile/core/theme/app_icons.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/shared/widgets/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';

/// `PillButton.wrapLabel` (Issue #532): off — every existing caller — the
/// pill is exactly as before; on, a label too long for one line wraps and
/// the pill grows to hold it.
void main() {
  setUpAll(loadAppFonts);

  /// [pill] given [width] of a phone, at [scale] text.
  Future<void> pump(
    WidgetTester tester,
    PillButton pill, {
    double width = 256,
    double scale = 1,
  }) async {
    useLogicalViewport(tester, const Size(320, 852), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: pill),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RenderParagraph paragraph(WidgetTester tester, String label) =>
      tester.renderObject<RenderParagraph>(
        find
            .descendant(
              of: find.byType(PillButton),
              matching: find.byType(RichText),
            )
            .first,
      );

  Text text(WidgetTester tester) => tester.widget<Text>(
    find.descendant(of: find.byType(PillButton), matching: find.byType(Text)),
  );

  /// Long enough to need two lines of a 256pt pill at 2.0× text.
  const long = 'Дахин уншуулах';

  group('off (the default)', () {
    testWidgets('one line and an ellipsis, as every caller has always had', (
      tester,
    ) async {
      await pump(
        tester,
        PillButton(label: long, height: 44, onPressed: () {}),
        scale: 2,
      );

      final label = text(tester);
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(label.textAlign, isNull);
      expect(paragraph(tester, long).didExceedMaxLines, isTrue);
      // No wrapping padding in the tree.
      expect(
        find.descendant(
          of: find.byType(PillButton),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Padding &&
                w.padding == const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('at the default size the pill is exactly its height', (
      tester,
    ) async {
      await pump(tester, PillButton(label: long, height: 44, onPressed: () {}));
      expect(tester.getSize(find.byType(PillButton)).height, 44);
    });
  });

  group('on', () {
    for (final (name, label) in [
      ('Mongolian', long),
      ('English', 'Check your connection and scan again'),
    ]) {
      testWidgets('$name: a label too long for one line wraps, centred and '
          'whole, and the pill grows to hold it', (tester) async {
        await pump(
          tester,
          PillButton(
            label: label,
            height: 44,
            wrapLabel: true,
            onPressed: () {},
          ),
          scale: 2,
        );

        final para = paragraph(tester, label);
        expect(para.didExceedMaxLines, isFalse);
        expect(
          para.size.height,
          greaterThanOrEqualTo(
            para.getMaxIntrinsicHeight(para.size.width) - 0.01,
          ),
        );
        // More than one line, inside the pill and its 10pt of air.
        final lineTops = {
          for (final box in para.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          ))
            box.top.round(),
        };
        expect(lineTops.length, greaterThan(1));
        final pill = tester.getRect(find.byType(PillButton));
        final box = tester.getRect(find.byType(RichText).last);
        expect(pill.height, greaterThan(44));
        expect(box.top, greaterThanOrEqualTo(pill.top + 10 - 0.01));
        expect(box.bottom, lessThanOrEqualTo(pill.bottom - 10 + 0.01));
        expect(box.left, greaterThanOrEqualTo(pill.left));
        expect(box.right, lessThanOrEqualTo(pill.right));
        expect(text(tester).textAlign, TextAlign.center);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a label that fits draws exactly as with it off', (
      tester,
    ) async {
      Future<(Size, Rect)> measure(bool wrap) async {
        await pump(
          tester,
          PillButton(
            label: 'Дахин оролдох',
            height: 44,
            wrapLabel: wrap,
            onPressed: () {},
          ),
        );
        return (
          tester.getSize(find.byType(PillButton)),
          tester.getRect(find.byType(RichText).last),
        );
      }

      final off = await measure(false);
      final on = await measure(true);
      expect(on.$1, off.$1);
      expect(on.$2, off.$2);
    });

    testWidgets('with a leading icon, the icon stays and the label wraps '
        'beside it', (tester) async {
      await pump(
        tester,
        PillButton(
          label: long,
          height: 40,
          icon: AppIcons.qrCode,
          wrapLabel: true,
          onPressed: () {},
        ),
        scale: 2,
      );
      expect(find.byIcon(AppIcons.qrCode), findsOneWidget);
      expect(paragraph(tester, long).didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
