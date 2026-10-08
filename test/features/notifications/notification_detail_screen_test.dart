import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/course_learning/presentation/course_learning_strings.dart';
import 'package:aia_mobile/features/notifications/domain/app_notification.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_detail_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  test('sentAt reads year.month.day hour:minute, local and padded', () {
    expect(
      NotificationStrings.sentAt(DateTime(2026, 10, 1, 12, 57)),
      '2026.10.01 12:57',
    );
    expect(
      NotificationStrings.sentAt(DateTime(2026, 3, 4, 5, 6)),
      '2026.03.04 05:06',
    );
    final utc = DateTime.utc(2026, 10, 8, 7, 18, 50);
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    expect(
      NotificationStrings.sentAt(utc),
      '${local.year}.${two(local.month)}.${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}',
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
      find.text('«1 минутын AI видео» — 10/07 хүртэл илгээнэ үү.'),
      findsOneWidget,
    );
    expect(find.text('2026.10.01 12:57'), findsOneWidget);
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
    final bodyRect = tester.getRect(find.text(body));
    expect(bodyRect.bottom, greaterThan(875));

    await tester.drag(find.byType(Scrollable), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text(body)).bottom, lessThanOrEqualTo(875));
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
