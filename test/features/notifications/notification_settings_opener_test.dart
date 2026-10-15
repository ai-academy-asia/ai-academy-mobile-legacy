import 'package:aia_mobile/features/notifications/push/notification_settings_opener.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opening this app's notification settings (Issue #429). Android goes through
/// `MainActivity`'s channel, mocked here; iOS's `app-settings:` link goes
/// through `url_launcher` and is not exercised (push is off on iOS today).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(notificationSettingsChannel, (
      call,
    ) async {
      calls.add(call.method);
      return reply(call);
    });
  }

  setUp(() => calls = []);
  tearDown(() {
    messenger.setMockMethodCallHandler(notificationSettingsChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('the channel is the one MainActivity answers on', () {
    expect(
      notificationSettingsChannel.name,
      'com.aiacademyasia.aia_mobile/notification_settings',
    );
  });

  test(
    'Android: asks MainActivity to "open", and reports its answer',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      answer((_) => true);
      expect(await openAppNotificationSettings(), isTrue);
      answer((_) => false);
      expect(await openAppNotificationSettings(), isFalse);
      answer((_) => null);
      expect(await openAppNotificationSettings(), isFalse);

      expect(calls, ['open', 'open', 'open']);
    },
  );

  test('Android: a platform error reaches the caller, which decides', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((_) => throw PlatformException(code: 'no_activity'));

    await expectLater(
      openAppNotificationSettings(),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'elsewhere there is nothing to open, and MainActivity is not asked',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      answer((_) => true);

      expect(await openAppNotificationSettings(), isFalse);
      expect(calls, isEmpty);
    },
  );
}
