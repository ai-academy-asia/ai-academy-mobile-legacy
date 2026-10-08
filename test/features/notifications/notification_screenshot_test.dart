import 'package:aia_mobile/core/theme/app_theme.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_detail_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/screenshot.dart';
import 'fake_notification_repository.dart';

/// A deterministic capture of the Notification Center — unread, read,
/// unread, as the Figma "Notification" frame draws them (Issue #246) — at
/// the frame's own 393 x 875, for comparing against its PNG (1179 x 2625,
/// 3x). Test values, not the frame's.
///
/// Also Notification Detail (Issue #248), which no frame draws: a long,
/// two-paragraph body, for review rather than comparison.
///
/// Run `flutter test --update-goldens <this file>` to refresh, then compare
/// `test/goldens/notification.png` against the reference.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('Notification at the reference frame', (tester) async {
    useLogicalViewport(tester, const Size(393, 875), padding: iPhonePadding);
    final now = DateTime.now();
    final repository = FakeNotificationRepository(
      notifications: [
        sampleNotification(
          id: 3,
          title: 'Test title one',
          body: 'Test body one',
          createdAt: now.subtract(const Duration(days: 1, minutes: 1)),
        ),
        sampleNotification(
          id: 2,
          title: 'Test title two',
          body: 'Test body two',
          createdAt: now.subtract(const Duration(days: 7, minutes: 1)),
          readAt: now.subtract(const Duration(days: 6)),
        ),
        sampleNotification(
          id: 1,
          title: 'Test title three',
          body: 'Test body three',
          createdAt: now.subtract(const Duration(days: 8, minutes: 1)),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: NotificationScreen(
          center: NotificationCenter(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/notification.png'),
    );
  });

  testWidgets('Notification Detail with a long body', (tester) async {
    useLogicalViewport(tester, const Size(393, 875), padding: iPhonePadding);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: NotificationDetailScreen(
          notification: sampleNotification(
            title: 'Test title for a notification',
            body:
                'Test body, first paragraph. It runs past one line so the '
                'detail shows what the row cuts off.\n\n'
                'Test body, second paragraph, also longer than a single '
                'line of the list.',
            kind: 'announcement',
            createdAt: DateTime(2026, 10, 8, 15, 18),
            data: {'cohort_id': 3},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/notification_detail.png'),
    );
  });
}
