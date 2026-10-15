import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// The channel `MainActivity` answers on Android (Issue #429). The name is
/// pinned by `android_notification_config_test.dart` on both sides.
const MethodChannel notificationSettingsChannel = MethodChannel(
  'com.aiacademyasia.aia_mobile/notification_settings',
);

/// Opens this app's notification settings in the OS. True when they opened.
///
/// Android: `MainActivity`'s `open` method — the app's notification settings
/// on API 26+, its app-details screen below that. iOS: `app-settings:`
/// through `url_launcher`, so the protected `AppDelegate.swift` is untouched.
/// Anywhere else there is nothing to open. A platform error propagates; the
/// caller decides what failure means.
Future<bool> openAppNotificationSettings() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return await notificationSettingsChannel.invokeMethod<bool>('open') ??
          false;
    case TargetPlatform.iOS:
      return launchUrl(Uri.parse('app-settings:'));
    default:
      return false;
  }
}

/// Whether this app's default notification channel, "Мэдэгдэл"
/// (`aia_default`), is blocked in the OS (Issue #433) — pushes then arrive and
/// are never shown, though the permission reads granted.
///
/// Android only: `MainActivity`'s `isDefaultChannelBlocked`, which reads the
/// channel's importance and never changes it — false below API 26 or while the
/// channel does not exist. Elsewhere there are no such channels: false. A
/// platform error propagates; the caller decides what failure means.
Future<bool> isDefaultNotificationChannelBlocked() async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  return await notificationSettingsChannel.invokeMethod<bool>(
        'isDefaultChannelBlocked',
      ) ??
      false;
}
