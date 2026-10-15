import 'dart:ui' show Tristate;

import 'package:aia_mobile/features/auth/domain/auth_session_store.dart';
import 'package:aia_mobile/features/notifications/domain/push_token_repository.dart';
import 'package:aia_mobile/features/notifications/presentation/notification_center.dart';
import 'package:aia_mobile/features/notifications/push/push_messaging.dart';
import 'package:aia_mobile/features/notifications/push/push_notifications.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_notification_repository.dart';
import 'fake_push.dart';

/// A [PushNotifications] with push on: [messaging] attached, nothing else
/// real. Detach it at the end of the test.
Future<PushNotifications> attachedPush(FakePushMessaging messaging) async {
  final push = PushNotifications(
    tokens: FakePushTokens(),
    sessionStore: AuthSessionStore(),
    permissionMemory: FakePermissionMemory(),
    center: NotificationCenter(repository: FakeNotificationRepository()),
    platform: PushPlatform.android,
  );
  await push.attach(messaging);
  return push;
}

/// The app going to the OS (its settings, say) and coming back.
void leaveAndReturn(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// The Notification switch with push on (Issue #429), the same on every
/// Profile: it shows the OS notification permission and a tap opens the OS's
/// settings. [pumpWith] draws the Profile with that [PushNotifications]; the
/// switch is found by its semantics [label]. With push off, each Profile's own
/// "off and inert" test still holds.
void notificationPermissionSwitchCases({
  required String label,
  required Future<void> Function(WidgetTester tester, PushNotifications push)
  pumpWith,
}) {
  group('Notification switch: the OS notification permission (Issue #429)', () {
    late FakePushMessaging messaging;
    late PushNotifications push;

    Future<void> pump(WidgetTester tester, PushPermission permission) async {
      messaging = FakePushMessaging()..status = permission;
      push = await attachedPush(messaging);
      addTearDown(() async {
        await push.detach();
        await messaging.close();
      });
      await pumpWith(tester, push);
    }

    SemanticsNode node(WidgetTester tester) =>
        tester.getSemantics(find.bySemanticsLabel(label).last);
    bool isOn(WidgetTester tester) =>
        node(tester).flagsCollection.isToggled == Tristate.isTrue;
    bool isInert(WidgetTester tester) =>
        node(tester).flagsCollection.isEnabled == Tristate.isFalse;

    for (final (permission, on) in const [
      (PushPermission.granted, true),
      (PushPermission.denied, false),
      (PushPermission.notDetermined, false),
    ]) {
      testWidgets('${permission.name}: ${on ? 'on' : 'off'}, and live — read '
          'when Profile opens', (tester) async {
        await pump(tester, permission);

        expect(isOn(tester), on);
        expect(isInert(tester), isFalse);
        expect(messaging.calls, contains('permission'));
        expect(messaging.calls, isNot(contains('requestPermission')));
      });
    }

    testWidgets('a tap opens the OS notification settings and changes nothing '
        'itself', (tester) async {
      await pump(tester, PushPermission.denied);

      await tester.tap(find.bySemanticsLabel(label).last);
      await tester.pumpAndSettle();

      expect(
        messaging.calls.where((c) => c == 'openNotificationSettings'),
        hasLength(1),
      );
      expect(isOn(tester), isFalse);
      expect(messaging.calls, isNot(contains('requestPermission')));
    });

    testWidgets('back from the OS settings it is read again: allowed there, '
        'the switch turns on', (tester) async {
      await pump(tester, PushPermission.denied);
      expect(isOn(tester), isFalse);

      messaging.status = PushPermission.granted;
      leaveAndReturn(tester);
      await tester.pumpAndSettle();

      expect(isOn(tester), isTrue);
    });

    testWidgets('settings that cannot open do not crash the Profile', (
      tester,
    ) async {
      await pump(tester, PushPermission.denied);
      messaging.settingsError = PlatformException(code: 'no_activity');

      await tester.tap(find.bySemanticsLabel(label).last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(isOn(tester), isFalse);
    });
  });
}
