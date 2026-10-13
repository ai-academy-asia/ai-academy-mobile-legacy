import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_detail_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_notification_repository.dart';

/// The Notification list's rows at larger system text sizes (Issue #359).
/// A row was a fixed 71 tall, so from 1.5× its body spilled into the next
/// row (11px at 1.5×, 33px at 2.0×). Now 71 is a minimum: the row grows
/// with its text, the title and body keep one line each with an ellipsis,
/// and the age and unread dot stay centred in it.
void main() {
  setUpAll(loadAppFonts);

  const widths = [320.0, 375.0, 393.0];
  const scales = [1.0, 1.5, 2.0, 3.0];

  const unreadTitle = 'Хиймэл оюун ухааны сургалтын хуваарь шинэчлэгдлээ';
  const readTitle = 'Төлбөрийн хугацаа ойртож байна';

  NotificationCenter centerWith(DateTime now) => NotificationCenter(
    repository: FakeNotificationRepository(
      notifications: [
        sampleNotification(
          id: 3,
          title: unreadTitle,
          body:
              'Маргаашийн хичээл 3-р давхрын 304 тоот танхимд 09:00 цагаас '
              'эхэлнэ. Цагтаа ирээрэй.',
          createdAt: now.subtract(const Duration(days: 12, minutes: 1)),
        ),
        sampleNotification(
          id: 2,
          title: readTitle,
          body: 'Энэ сарын төлбөрөө 25-ны дотор төлнө үү.',
          createdAt: now.subtract(const Duration(days: 1, minutes: 1)),
          readAt: now.subtract(const Duration(hours: 20)),
        ),
      ],
    ),
  );

  /// Pumps the real screen and returns every error it raised.
  Future<List<String>> pump(
    WidgetTester tester, {
    required double width,
    required double scale,
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
          home: NotificationScreen(center: centerWith(DateTime.now())),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
    }
    return errors;
  }

  Finder tileOf(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(NotificationTile),
  );

  /// The lines [paragraph] lays out, from its own text, scaler, line limit
  /// and width.
  List<LineMetrics> linesOf(RenderParagraph paragraph) {
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: paragraph.maxLines,
      ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '…' : null,
    )..layout(maxWidth: paragraph.constraints.maxWidth);
    final lines = painter.computeLineMetrics();
    painter.dispose();
    return lines;
  }

  for (final width in widths) {
    for (final scale in scales) {
      final name = '${width.toInt()} wide, text ×$scale';

      testWidgets('$name: every row holds its title, body and age whole, '
          'on one line each, and the rows stack without overlap', (
        tester,
      ) async {
        final errors = await pump(tester, width: width, scale: scale);
        expect(errors, isEmpty);

        final tiles = [tileOf(unreadTitle), tileOf(readTitle)];
        final rects = [for (final tile in tiles) tester.getRect(tile)];
        expect(rects[1].top, moreOrLessEquals(rects[0].bottom));

        for (final (i, tile) in tiles.indexed) {
          final rect = rects[i];
          // 74 at the default size since Issue #366: the title's 22 line and
          // the body's [AppTypography.body] 24 (was 24 + 20).
          expect(rect.height, greaterThanOrEqualTo(74));
          if (scale == 1) expect(rect.height, 74);

          for (final element
              in find
                  .descendant(of: tile, matching: find.byType(RichText))
                  .evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            final text = paragraph.text.toPlainText();
            final lines = linesOf(paragraph);
            expect(lines, hasLength(1), reason: '"$text" keeps one line');
            final drawn = lines.single.height;
            expect(
              paragraph.size.height,
              greaterThanOrEqualTo(drawn - 0.01),
              reason: '"$text" drawn whole',
            );
            final box = paragraph.localToGlobal(Offset.zero) & paragraph.size;
            expect(box.left, greaterThanOrEqualTo(rect.left), reason: text);
            expect(box.right, lessThanOrEqualTo(rect.right), reason: text);
            expect(box.top, greaterThanOrEqualTo(rect.top), reason: text);
            // Above the row's 1pt rule.
            expect(
              box.bottom,
              lessThanOrEqualTo(rect.bottom - 1 + 0.01),
              reason: text,
            );
          }
        }

        // The unread row keeps its dot; the read one has none.
        bool hasDot(Finder tile) => find
            .descendant(
              of: tile,
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).shape == BoxShape.circle,
              ),
            )
            .evaluate()
            .isNotEmpty;
        expect(hasDot(tiles[0]), isTrue);
        expect(hasDot(tiles[1]), isFalse);
      });
    }
  }

  testWidgets('2.0× on the reference phone: the rows have grown past 74, the '
      'age centred in each', (tester) async {
    final errors = await pump(tester, width: 393, scale: 2);
    expect(errors, isEmpty);
    for (final title in [unreadTitle, readTitle]) {
      final row = tester.getRect(tileOf(title));
      expect(row.height, greaterThan(74));
      final age = tester.getRect(
        find.descendant(
          of: tileOf(title),
          matching: find.textContaining(RegExp(r'^\d+[dhm]$')),
        ),
      );
      // Centred in the row above its 1pt rule.
      expect(
        age.center.dy,
        moreOrLessEquals(row.top + (row.height - 1) / 2, epsilon: 0.5),
      );
    }
  });

  testWidgets('3.0×: a row is still one button that opens its notification', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final errors = await pump(tester, width: 320, scale: 3);
    expect(errors, isEmpty);

    final node = tester.getSemantics(tileOf(readTitle));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.label, contains(readTitle));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(tileOf(readTitle));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationDetailScreen), findsOneWidget);
    semantics.dispose();
  });

  group('screen-reader activation', () {
    Future<void> pumpDefault(WidgetTester tester) =>
        pump(tester, width: 393, scale: 1).then((errors) {
          expect(errors, isEmpty);
        });

    testWidgets('each row is exactly one node, read once, with a tap action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpDefault(tester);

      for (final title in [unreadTitle, readTitle]) {
        // Only the row's own node mentions its title, and only once.
        final mentions = find.semantics
            .byPredicate((node) => node.label.contains(title))
            .evaluate()
            .toList();
        expect(mentions, hasLength(1), reason: title);
        final node = mentions.single;
        expect(node.label.indexOf(title), node.label.lastIndexOf(title));
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      }
      semantics.dispose();
    });

    testWidgets('activating a row as a screen reader does opens its '
        'notification', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDefault(tester);

      tester.semantics.performAction(
        find.semantics.byPredicate((node) => node.label.contains(readTitle)),
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotificationDetailScreen), findsOneWidget);
      expect(find.text(readTitle), findsWidgets);
      semantics.dispose();
    });
  });
}
