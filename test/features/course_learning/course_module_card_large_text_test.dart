import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_module_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// The Course Module List's module cards at larger system text sizes (Issue
/// #349). A card used to be a fixed 86 tall, so from 1.5× its last line —
/// the module's date and time — was clipped. 86 is now its minimum: at the
/// default size every card is exactly 86, and it grows when its text needs
/// the room.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.1, 1.3, 1.5, 2.0, 3.0];

  /// Pumps the real Course Module List and returns every error it raised.
  Future<List<String>> pumpList(
    WidgetTester tester, {
    required double width,
    required double scale,
  }) async {
    useLogicalViewport(tester, Size(width, 4000), padding: iPhonePadding);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CourseModuleListScreen(
            courseSlug: 'how-ai-works',
            repository: FakeCourseLearningRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  Finder within(Element card, Finder matching) => find.descendant(
    of: find.byElementPredicate((e) => e == card),
    matching: matching,
  );

  for (final width in widths) {
    for (final scale in scales) {
      testWidgets('${width.toInt()} wide, text ×$scale: every card holds '
          'its caption, title and date line whole, and is as tall as they '
          'need — never under 86', (tester) async {
        final errors = await pumpList(tester, width: width, scale: scale);
        expect(errors, isEmpty);

        final cards = find.byType(CourseModuleCard).evaluate().toList();
        expect(cards, isNotEmpty);
        for (final card in cards) {
          final module = (card.widget as CourseModuleCard).module;
          final rect = tester.getRect(
            find.byElementPredicate((e) => e == card),
          );
          expect(rect.height, greaterThanOrEqualTo(86), reason: module.title);
          if (scale == 1.0) expect(rect.height, 86, reason: module.title);

          final lines = [
            for (final element in within(
              card,
              find.byType(RichText),
            ).evaluate())
              element.renderObject! as RenderParagraph,
          ];
          for (final paragraph in lines) {
            final text = paragraph.text.toPlainText();
            final box = paragraph.localToGlobal(Offset.zero) & paragraph.size;
            // Inside the card, inside its 12 inset.
            expect(box.top, greaterThanOrEqualTo(rect.top + 12), reason: text);
            expect(
              box.bottom,
              lessThanOrEqualTo(rect.bottom - 12),
              reason: text,
            );
            // Drawn at its full height: nothing clipped.
            expect(
              paragraph.size.height,
              greaterThanOrEqualTo(
                paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
              ),
              reason: text,
            );
          }

          // The date line in particular: present, whole and on the card.
          final date = tester.getRect(
            within(card, find.text(module.scheduleLabel)),
          );
          expect(date.bottom, lessThanOrEqualTo(rect.bottom));

          // The title keeps its one line and ellipsis.
          final title = tester.widget<Text>(
            within(card, find.text(module.title)),
          );
          expect(title.maxLines, 1);
          expect(title.overflow, TextOverflow.ellipsis);

          // Grown exactly as far as the text needs: the text column and its
          // 12 above and below, inside the 1pt edge — or 86, whichever is
          // more. Measured off the layout, not assumed.
          final column = tester.getRect(
            within(card, find.byType(Column)).first,
          );
          expect(
            rect.height,
            moreOrLessEquals(
              (column.height + 2 * 12 + 2).clamp(86, double.infinity),
              epsilon: 0.01,
            ),
            reason: module.title,
          );
        }
      });
    }
  }

  testWidgets('393 wide, text ×1.5 — where the date line was first clipped: '
      'the cards have grown past 86', (tester) async {
    final errors = await pumpList(tester, width: 393, scale: 1.5);
    expect(errors, isEmpty);
    for (final card in find.byType(CourseModuleCard).evaluate()) {
      expect(
        tester.getSize(find.byElementPredicate((e) => e == card)).height,
        greaterThan(86),
      );
    }
  });

  testWidgets('the error capture keeps a layout error — it does not swallow '
      'one — so the grid above fails on any', (tester) async {
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.toString());
    try {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 10,
              height: 10,
              // A real area: Flutter reports no overflow of a 0-tall row.
              child: Row(children: [SizedBox(width: 50, height: 10)]),
            ),
          ),
        ),
      );
    } finally {
      FlutterError.onError = previous;
    }
    expect(errors, hasLength(1));
    expect(errors.single, contains('A RenderFlex overflowed'));
  });
}
