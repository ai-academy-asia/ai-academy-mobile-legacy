import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_screen.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/back_button_header.dart';
import '../../support/screenshot.dart';
import 'fake_notification_repository.dart';

/// The Notification header's back button stays reachable at every width and
/// text size (Issue #325) — on the Notification Center, which shares its header
/// (the shared `BackTitleHeader`, Issue #327) with the detail screen. Before
/// the fix the centred title lay over the button and took its taps: the centre
/// and right edge at 320 wide and 2.5×, all of it at 3.0×; the right edge at
/// 393 wide and 3.0×.
void main() {
  setUpAll(loadAppFonts);

  backButtonHeaderChecks(
    title: NotificationStrings.title,
    // The real screen, on a fake feed with nothing in it.
    screen: () => NotificationScreen(
      center: NotificationCenter(repository: FakeNotificationRepository()),
    ),
  );
}
