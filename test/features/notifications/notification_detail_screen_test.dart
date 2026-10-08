import 'package:aia_mobile/core/theme/app_colors.dart';
import 'package:aia_mobile/core/theme/app_dimens.dart';
import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/home/presentation/widgets/home_palette.dart';
import 'package:aia_mobile/features/notifications/domain/app_notification.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_detail_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_notification_repository.dart';

/// Notification Detail (Issue #248): the full text of one notification.
void main() {
  setUpAll(loadAppFonts);

  /// Pushes the detail over a stand-in list, as a row tap does.
  Future<void> pumpDetail(
    WidgetTester tester,
    AppNotification notification,
  ) async {
    useLogicalViewport(tester, const Size(393, 875), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  NotificationDetailScreen.open(context, notification),
              child: const Text('list'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('list'));
    await tester.pumpAndSettle();
  }

  test('sentAt reads year.month.day · hour:minute, local and padded', () {
    expect(
      NotificationStrings.sentAt(DateTime(2026, 10, 8, 15, 18)),
      '2026.10.08 · 15:18',
    );
    expect(
      NotificationStrings.sentAt(DateTime(2026, 3, 4, 5, 6)),
      '2026.03.04 · 05:06',
    );
    final utc = DateTime.utc(2026, 10, 8, 7, 18, 50);
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    expect(
      NotificationStrings.sentAt(utc),
      '${local.year}.${two(local.month)}.${two(local.day)} '
      '· ${two(local.hour)}:${two(local.minute)}',
    );
  });

  testWidgets('the header, the full title, the date and the body', (
    tester,
  ) async {
    final createdAt = DateTime(2026, 10, 1, 12, 57);
    await pumpDetail(
      tester,
      sampleNotification(
        title: 'Шинэ даалгавар',
        body: '«1 минутын AI видео» — 10/07 хүртэл илгээнэ үү.',
        kind: 'assignment',
        createdAt: createdAt,
        data: {'assignment_id': 18},
      ),
    );

    expect(find.text(NotificationStrings.title), findsOneWidget);
    expect(find.text('Шинэ даалгавар'), findsOneWidget);
    expect(
      find.text(
        bindShortLastWords('«1 минутын AI видео» — 10/07 хүртэл илгээнэ үү.'),
      ),
      findsOneWidget,
    );
    expect(find.text('2026.10.01 · 12:57'), findsOneWidget);
  });

  testWidgets('the bell sits small on a pale-blue disc, centred', (
    tester,
  ) async {
    await pumpDetail(tester, sampleNotification());

    final disc = find.ancestor(
      of: find.byType(SvgPicture),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(disc, findsOneWidget);
    expect(
      (tester.widget<Container>(disc).decoration as BoxDecoration).color,
      HomePalette.liveFill,
    );
    expect(tester.getSize(disc), const Size(48, 48));
    expect(tester.getCenter(disc).dx, 393 / 2);

    final glyph = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(tester.getSize(find.byType(SvgPicture)), const Size(24, 24));
    expect(
      glyph.colorFilter,
      const ColorFilter.mode(HomePalette.accent, BlendMode.srcIn),
    );
  });

  testWidgets('title over time: one centred block, the title strongest', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      sampleNotification(
        title: 'Short title',
        createdAt: DateTime(2026, 10, 8, 15, 18),
      ),
    );

    final title = tester.widget<Text>(find.text('Short title'));
    expect(title.style?.fontSize, 18);
    expect(title.style?.height, 24 / 18);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(title.style?.color, AppColors.textPrimary);
    expect(title.textAlign, TextAlign.center);

    final date = tester.widget<Text>(find.text('2026.10.08 · 15:18'));
    expect(date.style?.fontSize, 14);
    expect(date.style?.color, AppColors.textSecondary);
    expect(date.textAlign, TextAlign.center);
    expect(
      tester.getRect(find.text('2026.10.08 · 15:18')).top -
          tester.getRect(find.text('Short title')).bottom,
      4,
    );
    expect(tester.getCenter(find.text('Short title')).dx, 393 / 2);
  });

  testWidgets('the body: 16/24 primary ink, left-aligned, on the page grey', (
    tester,
  ) async {
    await pumpDetail(tester, sampleNotification(body: 'A body to read'));
    final text = find.text(bindShortLastWords('A body to read'));

    final body = tester.widget<Text>(text);
    expect(body.style?.fontSize, 16);
    expect(body.style?.height, 24 / 16);
    expect(body.style?.color, AppColors.textPrimary);
    expect(body.textAlign, isNull);

    final ground = find.ancestor(
      of: text,
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == AppColors.background,
      ),
    );
    expect(ground, findsOneWidget);
    final decoration =
        tester.widget<DecoratedBox>(ground).decoration as BoxDecoration;
    expect(
      decoration.borderRadius,
      BorderRadius.circular(AppDimens.cardRadius),
    );
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNull);

    // Full width of the column, the text 16 inside it.
    final groundRect = tester.getRect(ground);
    expect(groundRect.left, 16);
    expect(groundRect.right, 393 - 16);
    expect(tester.getRect(text).left, 32);
    expect(tester.getRect(text).top - groundRect.top, 16);
  });

  testWidgets('a short body is one tidy section, close under the rule', (
    tester,
  ) async {
    await pumpDetail(tester, sampleNotification(body: 'Short.'));

    final text = find.text('Short.');
    expect(tester.getSize(text).height, 24, reason: 'one line');
    expect(tester.takeException(), isNull);
  });

  group('the last line never holds a short word alone', () {
    /// The last line of [body] as laid out on the detail screen at
    /// [viewportWidth].
    Future<String> lastLineOf(
      WidgetTester tester,
      String body,
      double viewportWidth,
    ) async {
      useLogicalViewport(
        tester,
        Size(viewportWidth, 875),
        padding: iPhonePadding,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: NotificationDetailScreen(
            notification: sampleNotification(body: body),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shown = bindShortLastWords(body);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(shown), matching: find.byType(RichText)),
      );
      // Laid out as the paragraph is: its own text, at its own width.
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      addTearDown(painter.dispose);
      final line = painter.getLineBoundary(
        TextPosition(offset: shown.length - 1),
      );
      return shown.substring(line.start, line.end).trim();
    }

    // The device case: a sentence a hair wider than its line. At 419 wide
    // the body column is 355, which drops exactly the last word.
    const sentence = '«1 минутын AI видео» — 10/07 хүртэл илгээнэ үү.';

    testWidgets('a sentence just over one line takes a word with it', (
      tester,
    ) async {
      expect(await lastLineOf(tester, sentence, 419), 'илгээнэ\u00A0үү.');
    });

    testWidgets('at every width from SE to Pro Max', (tester) async {
      for (var width = 320.0; width <= 440; width += 1) {
        final last = await lastLineOf(tester, sentence, width);
        expect(last, isNot('үү.'), reason: 'at $width');
        expect(last.length, greaterThan(3), reason: 'at $width');
      }
    });
  });

  group('bindShortLastWords', () {
    test('binds a short last word to the one before', () {
      expect(bindShortLastWords('илгээнэ үү.'), 'илгээнэ\u00A0үү.');
      expect(
        bindShortLastWords('send it by Friday ok'),
        'send it by Friday\u00A0ok',
      );
    });

    test('leaves a long last word, a single word and empty text alone', () {
      expect(bindShortLastWords('one two three'), 'one two three');
      expect(bindShortLastWords('word'), 'word');
      expect(bindShortLastWords(''), '');
    });

    test('never binds a pair too long to share a line safely', () {
      const long = 'pneumonoultramicroscopicsilicovolcanoconiosis ok';
      expect(bindShortLastWords(long), long);
    });

    test('each paragraph on its own; line breaks and spacing kept', () {
      expect(
        bindShortLastWords('First line is ok\n\nSecond one too  \n'),
        'First line is\u00A0ok\n\nSecond one\u00A0too  \n',
      );
    });

    test('changes nothing but the one space', () {
      const body = 'Сайн байна уу? Маргааш 10 цагт хичээл болно.\nБаярлалаа!';
      expect(bindShortLastWords(body).replaceAll('\u00A0', ' '), body);
    });
  });

  testWidgets('a long title and body are drawn whole, never truncated', (
    tester,
  ) async {
    final title = 'A notification title that runs on and on ' * 3;
    final body = 'A long announcement body that keeps going. ' * 8;
    await pumpDetail(tester, sampleNotification(title: title, body: body));

    expect(tester.takeException(), isNull);
    for (final text in [title, body]) {
      final widget = tester.widget<Text>(find.text(text));
      expect(widget.maxLines, isNull);
      expect(widget.overflow, isNull);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(text), matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.getSize(find.text(text)).height, greaterThan(28));
    }
  });

  testWidgets('a body longer than the screen scrolls to its last line', (
    tester,
  ) async {
    final body = '${'Paragraph line that fills the page.\n' * 60}The end.';
    await pumpDetail(tester, sampleNotification(body: body));

    expect(find.byType(Scrollable), findsOneWidget);
    final bodyRect = tester.getRect(find.text(bindShortLastWords(body)));
    expect(bodyRect.bottom, greaterThan(875));

    await tester.drag(find.byType(Scrollable), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text(bindShortLastWords(body))).bottom,
      lessThanOrEqualTo(875),
    );
  });

  testWidgets('the title is announced as a heading', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpDetail(tester, sampleNotification(title: 'Heading title'));

    expect(
      tester.getSemantics(find.text('Heading title')),
      matchesSemantics(label: 'Heading title', isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('back returns to where it was opened from', (tester) async {
    await pumpDetail(tester, sampleNotification());

    await tester.tap(find.bySemanticsLabel(CourseLearningStrings.back));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationDetailScreen), findsNothing);
    expect(find.text('list'), findsOneWidget);
  });
}
