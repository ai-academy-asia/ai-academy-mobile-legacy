import 'dart:async';

import 'package:aia_mobile/features/notifications/push/notification_permission_switch.dart';
import 'package:aia_mobile/features/notifications/push/push_messaging.dart';
import 'package:aia_mobile/features/notifications/push/push_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_push.dart';
import 'notification_switch_cases.dart';

/// Every value the switch is actually drawn with (Issue #433): with the
/// permission granted but the "Мэдэгдэл" channel blocked, no frame may draw
/// it on — not even while the channel read is still out.
void main() {
  late FakePushMessaging messaging;
  late PushNotifications push;

  Future<List<bool>> pumpSwitch(WidgetTester tester) async {
    push = await attachedPush(messaging);
    addTearDown(() async {
      await push.detach();
      await messaging.close();
    });
    final drawn = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationPermissionSwitch(
          push: push,
          builder: (context, value, onChanged) {
            drawn.add(value);
            return const SizedBox();
          },
        ),
      ),
    );
    return drawn;
  }

  testWidgets('Profile opens, granted but blocked: never drawn on, across '
      'every frame while the channel read is held open', (tester) async {
    messaging = FakePushMessaging()
      ..status = PushPermission.granted
      ..channelBlocked = true
      ..channelGate = Completer<void>();
    final drawn = await pumpSwitch(tester);

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(messaging.calls, contains('notificationChannelBlocked'));
    expect(drawn, isNot(contains(true)));

    messaging.channelGate!.complete();
    await tester.pumpAndSettle();

    expect(drawn, isNotEmpty);
    expect(drawn, isNot(contains(true)));
  });

  testWidgets('granted and unblocked: drawn off until both are known, then on '
      '— never back off', (tester) async {
    messaging = FakePushMessaging()..channelGate = Completer<void>();
    final drawn = await pumpSwitch(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(drawn, isNot(contains(true)));

    messaging.channelGate!.complete();
    await tester.pumpAndSettle();

    expect(drawn.last, isTrue);
    expect(drawn.skipWhile((on) => !on), everyElement(isTrue));
  });
}
