import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_module_list_screen.dart';
import 'package:aia_mobile/features/course_learning/presentation/widgets/course_module_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_course_learning_repository.dart';

/// Course Detail's cards at larger system text sizes (Issue #349). A card
/// used to be a fixed 86 tall, so from 1.5× its last line was clipped. 86 is
/// now its minimum, and it grows when its text needs the room — at the
/// default size, since Issue #366's type scale, to its content's 94. Since
/// Issue #437 the cards are the course's lessons ([CourseLessonCard], the
/// module card's design): number, title, duration — and, on the lesson to
/// continue with, the "Эндээс үргэлжлүүлнэ" pill.
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
            // Module 2's three lessons — completed, the one to continue
            // with, and locked — so every kind of card is measured.
            repository: FakeCourseLearningRepository(
              path: samplePath(continueModuleId: 2, continueLessonId: 2),
              lessons: const [],
              lessonsByModule: {2: sampleLessons()},
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

  Finder within(Element card, Finder matching) => find.descendant(
    of: find.byElementPredicate((e) => e == card),
    matching: matching,
  );

  for (final width in widths) {
    for (final scale in scales) {
      testWidgets('${width.toInt()} wide, text ×$scale: every card holds '
          'its number, title and duration line whole, and is as tall as '
          'they need — never under 86', (tester) async {
        final errors = await pumpList(tester, width: width, scale: scale);
        expect(errors, isEmpty);

        final cards = find.byType(CourseLessonCard).evaluate().toList();
        expect(cards, isNotEmpty);
        expect(
          cards.where((card) => (card.widget as CourseLessonCard).current),
          hasLength(1),
        );
        for (final card in cards) {
          final widget = card.widget as CourseLessonCard;
          final lesson = widget.entry.lesson;
          final rect = tester.getRect(
            find.byElementPredicate((e) => e == card),
          );
          expect(rect.height, greaterThanOrEqualTo(86), reason: lesson.title);
          // Its content's 94 at the default size since Issue #366's type
          // scale, while the title takes one line; 86 stays the minimum. The
          // current card adds its pill, and a title may take a second line.
          final titleParagraph =
              tester.renderObject(within(card, find.text(lesson.title)))
                  as RenderParagraph;
          final titleOnOneLine =
              titleParagraph.getMaxIntrinsicWidth(double.infinity) <=
              titleParagraph.size.width + 0.01;
          if (scale == 1.0 && !widget.current && titleOnOneLine) {
            expect(rect.height, 94, reason: lesson.title);
          }

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

          // The duration line in particular: present, whole and on the card.
          final duration = tester.getRect(
            within(card, find.text(lesson.durationLabel)),
          );
          expect(duration.bottom, lessThanOrEqualTo(rect.bottom));

          // The title keeps at most two lines and an ellipsis.
          final title = tester.widget<Text>(
            within(card, find.text(lesson.title)),
          );
          expect(title.maxLines, 2);
          expect(title.overflow, TextOverflow.ellipsis);

          // Grown exactly as far as the text needs: the text column and its
          // 12 above and below, inside the edge (1pt; the current card's
          // 2pt) — or 86, whichever is more. Measured off the layout, not
          // assumed.
          final edge = widget.current ? 2.0 : 1.0;
          final column = tester.getRect(
            within(card, find.byType(Column)).first,
          );
          expect(
            rect.height,
            moreOrLessEquals(
              (column.height + 2 * 12 + 2 * edge).clamp(86, double.infinity),
              epsilon: 0.01,
            ),
            reason: lesson.title,
          );
        }
      });
    }
  }

  testWidgets('393 wide, text ×1.5 — where the last line was first clipped: '
      'the cards have grown past 86', (tester) async {
    final errors = await pumpList(tester, width: 393, scale: 1.5);
    expect(errors, isEmpty);
    for (final card in find.byType(CourseLessonCard).evaluate()) {
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
